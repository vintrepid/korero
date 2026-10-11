defmodule Korero.Phoenix.ComponentsTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  test "extracted workspace renders host route state and escapes message text" do
    client = %{
      filter: %{
        configurable?: true,
        participant_param: "self",
        workflow: "reading",
        participant_options: [],
        workflow_options: []
      },
      folders: [%{key: "inbox", label: "Inbox", count: 1}],
      pagination: %{has_next?: true, next_cursor: "opaque"},
      threads: [thread()]
    }

    state = Korero.Client.State.select(client, %{"folder" => "inbox"})

    html =
      render_component(&Korero.Phoenix.Components.workspace/1,
        client: client,
        state: state,
        inbox_path: "/work",
        can_compose?: true
      )

    doc = LazyHTML.from_fragment(html)
    assert html =~ ~s(id="inbox-workspace"), html

    assert LazyHTML.query(doc, "#inbox-workspace") |> LazyHTML.to_tree() != []
    assert LazyHTML.query(doc, "#inbox-new-message") |> LazyHTML.to_tree() != []
    [link] = LazyHTML.query(doc, "#inbox-thread-one") |> LazyHTML.to_tree()
    {"a", attrs, _children} = link
    href = attrs |> Map.new() |> Map.fetch!("href")
    assert URI.parse(href).path == "/work"
    assert URI.decode_query(URI.parse(href).query)["thread"] == "one"
    assert LazyHTML.query(doc, "#inbox-focus script") |> LazyHTML.to_tree() == []
    assert LazyHTML.query(doc, "#inbox-next-page") |> LazyHTML.to_tree() != []
  end

  defp thread do
    entry = %{
      source_kind: "message",
      source_id: "synthetic",
      from: "Sender",
      sent_at: ~U[2026-01-01 00:00:00Z],
      body: "<script>private()</script>",
      app: "Example",
      channel: "app"
    }

    %{
      id: "one",
      from: "Sender",
      sent_at: entry.sent_at,
      subject: "Invitation",
      preview: "Read together",
      app: "Example",
      channel: "app",
      priority: :normal,
      classification: "Task",
      unread?: true,
      needs_action?: true,
      deferred?: false,
      folder_keys: ["inbox"],
      entries: [entry]
    }
  end
end
