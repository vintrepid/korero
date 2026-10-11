defmodule Korero.Client.Cursor do
  @moduledoc """
  Bounded, folder-bound keyset cursors extracted from Calvin's InboxQuery.

  A cursor is not a capability. Source kinds are supplied by a trusted host
  adapter; the host still authorizes its query and applies the decoded boundary.
  """

  def encode(%DateTime{} = at, kind, id, folder) do
    %{"at" => DateTime.to_iso8601(at), "kind" => kind, "id" => id, "folder" => folder}
    |> Jason.encode!()
    |> Base.url_encode64(padding: false)
  end

  def decode(cursor, _folder, _source_kinds) when cursor in [nil, ""], do: {:ok, nil}

  def decode(cursor, folder, source_kinds)
      when is_binary(cursor) and byte_size(cursor) <= 1_024 do
    with {:ok, json} <- Base.url_decode64(cursor, padding: false),
         {:ok, %{"at" => at, "kind" => kind, "id" => id, "folder" => ^folder}} <-
           Jason.decode(json),
         true <- kind in source_kinds,
         true <- is_binary(id) and byte_size(id) in 1..128,
         true <- is_binary(at),
         {:ok, at, 0} <- DateTime.from_iso8601(at) do
      {:ok, %{at: at, kind: kind, id: id}}
    else
      _invalid -> {:error, :invalid_cursor}
    end
  end

  def decode(_cursor, _folder, _source_kinds), do: {:error, :invalid_cursor}
end
