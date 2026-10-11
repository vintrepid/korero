defmodule Korero.ClientTest do
  use ExUnit.Case, async: true

  alias Korero.Client.{Cursor, State, Threads}

  test "copied client state restores authorized folder/thread and keeps deferred work separate" do
    client = client()
    state = State.select(client, %{"folder" => "inbox", "thread" => "later"})
    assert state.selected_thread_id == "later"
    assert Enum.map(state.visible_threads, & &1.id) == ["now"]
    assert Enum.map(state.later_threads, & &1.id) == ["later"]

    state =
      State.select(client, %{"folder" => "unavailable-private-folder", "thread" => "unauthorized"})

    assert state.current_folder == "inbox"
    assert state.selected_thread_id == "now"
    refute Enum.any?(state.folder_threads, &(&1.id == "unauthorized"))
  end

  test "legacy hidden folder links restore Trash while empty pages stay empty" do
    state = State.select(client(), %{"folder" => "hidden"})
    assert state.current_folder == "trash"
    assert state.folder_threads == []
    assert state.selected_thread == nil
  end

  test "URL navigation preserves filters and pagination at a configurable mount" do
    filter = %{configurable?: true, participant_param: "self", workflow: "reading"}

    path =
      State.path("/work/inbox", filter,
        folder: "inbox",
        thread: "a+b",
        cursor: "opaque",
        direction: "previous"
      )

    assert URI.parse(path).path == "/work/inbox"

    assert URI.decode_query(URI.parse(path).query) == %{
             "participant" => "self",
             "workflow" => "reading",
             "folder" => "inbox",
             "thread" => "a+b",
             "cursor" => "opaque",
             "direction" => "previous"
           }

    query = State.path("/inbox", %{filter | configurable?: false}, folder: "inbox")
    refute Map.has_key?(URI.decode_query(URI.parse(query).query), "participant")

    assert State.criteria(%{"participant" => "all", "unknown" => "module"})["participant"] ==
             "all"

    refute Map.has_key?(State.criteria(%{"unknown" => "module"}), "unknown")
  end

  test "a host mount cannot become an external or script navigation target" do
    for path <- [
          "https://example.com/inbox",
          "//example.com/inbox",
          "javascript:alert(1)",
          "/inbox?secret=yes",
          "/inbox#fragment"
        ] do
      assert_raise ArgumentError, fn -> State.path(path, %{}) end
    end
  end

  test "cursor boundaries are bounded and scoped to a known source and exact folder" do
    at = ~U[2026-12-31 23:59:59Z]
    cursor = Cursor.encode(at, "message", "source-1", "inbox")

    assert {:ok, %{at: ^at, kind: "message", id: "source-1"}} =
             Cursor.decode(cursor, "inbox", ["message"])

    assert {:error, :invalid_cursor} = Cursor.decode(cursor, "trash", ["message"])
    assert {:error, :invalid_cursor} = Cursor.decode(cursor, "inbox", ["task"])

    assert {:error, :invalid_cursor} =
             Cursor.decode(String.duplicate("a", 1_025), "inbox", ["message"])

    assert {:error, :invalid_cursor} = Cursor.decode("%not-a-cursor", "inbox", ["message"])
    assert {:ok, nil} = Cursor.decode(nil, "inbox", ["message"])
  end

  test "active, archived and Trash do not merge; purged sources never appear" do
    items = [
      item("active", %{visibility: :active, folder_keys: ["inbox"]}),
      item("archived", %{visibility: :archived, folder_keys: ["archive"]}),
      item("trashed", %{visibility: :trashed, folder_keys: ["trash"], hidden?: true}),
      item("purged", %{visibility: :purged, folder_keys: []})
    ]

    threads = Threads.build(items)
    assert length(threads) == 3

    assert Enum.sort(
             Enum.flat_map(threads, &Enum.map(&1.entries, fn entry -> entry.source_id end))
           ) == ["active", "archived", "trashed"]

    assert Enum.uniq(Enum.map(threads, & &1.id)) |> length() == 3
    assert Enum.all?(threads, &(length(&1.entries) == 1))
  end

  test "reading a plain message cannot erase active work in its thread" do
    unread = item("message", %{unread?: false, needs_action?: false, priority: :none})
    task = item("task", %{unread?: false, needs_action?: true, priority: :urgent})
    assert [thread] = Threads.build([unread, task])
    assert thread.needs_action?
    refute thread.unread?
    assert thread.priority == :urgent
    assert length(thread.entries) == 2
  end

  test "queue priority wins over date and one thread retains all authorized occurrences" do
    older =
      item("urgent", %{thread_key: "urgent", priority: :urgent, sent_at: ~U[2025-12-31 23:59:59Z]})

    newer =
      item("normal", %{thread_key: "normal", priority: :normal, sent_at: ~U[2026-01-01 00:00:01Z]})

    assert Enum.map(Threads.build([newer, older]), & &1.thread_key) == ["urgent", "normal"]
  end

  defp client do
    %{
      folders: [
        %{key: "inbox", label: "Inbox", count: 2},
        %{key: "trash", label: "Trash", count: 0}
      ],
      threads: [
        %{id: "now", folder_keys: ["inbox"], deferred?: false},
        %{id: "later", folder_keys: ["inbox"], deferred?: true}
      ]
    }
  end

  defp item(id, overrides) do
    Map.merge(
      %{
        source_kind: "message",
        source_id: id,
        thread_key: "one",
        visibility: :active,
        app: "Example",
        channel: "app",
        subject: "A conversation",
        preview: "Text",
        from: "Synthetic sender",
        to: "Synthetic recipient",
        sent_at: ~U[2026-01-01 00:00:00Z],
        status: "open",
        unread?: false,
        needs_action?: false,
        priority: :normal,
        classification: "Task",
        workflow_status: "queued",
        deferred?: false,
        scheduled_for: nil,
        starred?: false,
        hidden?: false,
        folder_keys: ["inbox"],
        draft_response: nil
      },
      overrides
    )
  end
end
