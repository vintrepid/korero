defmodule Korero.Client.Threads do
  @moduledoc """
  Visibility-separated, task-priority projection extracted from Calvin's UnifiedInbox.

  Inputs must already be authorized by the host's Ash read action. Active,
  archived and trashed occurrences of a conversation stay separate. This
  projection neither acknowledges a message nor changes task lifecycle.
  Host-specific mirror/broadcast normalization belongs before this projection.
  """

  @summary_fields ~w(app channel subject preview from to sent_at status unread? needs_action? priority classification workflow_status deferred? scheduled_for visibility starred? hidden?)a

  def build(items) do
    items
    |> Enum.reject(&(&1.visibility == :purged))
    |> Enum.group_by(&{&1.thread_key, &1.visibility})
    |> Enum.map(fn {{thread_key, visibility}, entries} ->
      entries = Enum.sort_by(entries, &datetime_value(&1.sent_at))
      latest = List.last(entries)
      summary = Enum.find(entries, &(Map.get(&1, :draft_response) not in [nil, ""])) || latest

      summary
      |> Map.take(@summary_fields)
      |> Map.merge(%{
        id: Base.url_encode64("#{thread_key}:#{visibility_key(visibility)}", padding: false),
        thread_key: thread_key,
        entries: entries,
        sent_at: latest.sent_at,
        folder_keys: entries |> Enum.flat_map(& &1.folder_keys) |> Enum.uniq(),
        unread?: Enum.any?(entries, & &1.unread?),
        needs_action?: Enum.any?(entries, & &1.needs_action?),
        priority: entries |> Enum.map(& &1.priority) |> Enum.min_by(&priority_rank/1),
        classification: summary.classification,
        deferred?: Enum.any?(entries, & &1.deferred?),
        starred?: Enum.any?(entries, & &1.starred?),
        scheduled_for:
          entries
          |> Enum.map(& &1.scheduled_for)
          |> Enum.reject(&is_nil/1)
          |> Enum.min(DateTime, fn -> nil end),
        hidden?: Enum.all?(entries, & &1.hidden?)
      })
    end)
    |> Enum.sort_by(fn thread ->
      {priority_rank(thread.priority), -datetime_value(thread.sent_at)}
    end)
  end

  defp visibility_key(:active), do: false
  defp visibility_key(:trashed), do: true
  defp visibility_key(:archived), do: :archive

  defp priority_rank(:urgent), do: 0
  defp priority_rank(:high), do: 1
  defp priority_rank(:normal), do: 2
  defp priority_rank(:low), do: 3
  defp priority_rank(_priority), do: 4

  defp datetime_value(nil), do: 0
  defp datetime_value(%DateTime{} = datetime), do: DateTime.to_unix(datetime, :microsecond)

  defp datetime_value(%NaiveDateTime{} = datetime),
    do: datetime |> DateTime.from_naive!("Etc/UTC") |> datetime_value()
end
