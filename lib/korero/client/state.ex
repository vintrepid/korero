defmodule Korero.Client.State do
  @moduledoc """
  URL-backed workspace state extracted from Calvin's Inbox.

  This selects only from an already authorized client projection. Criteria are
  requests, never authority: host Ash actions must enforce actor visibility.
  No role names, application-specific folders or participant bypass live here.
  """

  @criteria ~w(participant workflow folder cursor direction)

  def criteria(params) do
    Map.new(@criteria, fn key -> {key, value(params, key)} end)
  end

  def current_params(client) do
    pagination = Map.get(client, :pagination, %{})
    filter = Map.get(client, :filter, %{})

    %{
      "participant" => filter[:participant_param],
      "workflow" => filter[:workflow],
      "folder" => Map.get(client, :folder, "inbox"),
      "cursor" => pagination[:cursor],
      "direction" => pagination[:direction]
    }
  end

  def select(client, params) do
    folder = valid_folder(client, value(params, "folder"))
    folder_threads = Enum.filter(client.threads, &(folder in &1.folder_keys))

    {threads, later_threads} =
      if folder == "inbox" do
        Enum.split_with(folder_threads, &(not &1.deferred?))
      else
        {folder_threads, []}
      end

    selected_id = value(params, "thread")

    selected =
      Enum.find(folder_threads, &(&1.id == selected_id)) ||
        List.first(threads) || List.first(later_threads)

    %{
      current_folder: folder,
      folder_threads: folder_threads,
      visible_threads: threads,
      later_threads: later_threads,
      selected_thread_id: selected && selected.id,
      selected_thread: selected
    }
  end

  def url_params(filter, extra \\ []) do
    [
      participant: Map.get(filter, :configurable?, false) && filter[:participant_param],
      workflow: filter[:workflow]
    ]
    |> Keyword.merge(extra)
    |> Enum.reject(fn {_key, value} -> value in [nil, false, ""] end)
  end

  def path(base_path, filter, extra \\ []) do
    uri = URI.parse(base_path)

    unless is_nil(uri.scheme) and is_nil(uri.host) and is_nil(uri.query) and
             is_nil(uri.fragment) and String.starts_with?(base_path, "/") and
             not String.starts_with?(base_path, "//") do
      raise ArgumentError, "Inbox path must be a local absolute path without a query or fragment"
    end

    case URI.encode_query(url_params(filter, extra)) do
      "" -> base_path
      query -> base_path <> "?" <> query
    end
  end

  def valid_folder(client, "hidden"), do: valid_folder(client, "trash")

  def valid_folder(client, requested) do
    keys = Enum.map(client.folders, & &1.key)

    cond do
      requested in keys -> requested
      "inbox" in keys -> "inbox"
      keys != [] -> List.first(keys)
      true -> "inbox"
    end
  end

  defp value(params, key) do
    atom_key =
      Enum.find(
        [:participant, :workflow, :folder, :cursor, :direction, :thread],
        &(Atom.to_string(&1) == key)
      )

    Map.get(params, key) || Map.get(params, atom_key)
  end
end
