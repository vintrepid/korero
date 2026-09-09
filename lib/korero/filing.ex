defmodule Korero.Filing do
  @moduledoc """
  Shared ownership and retention rules for personal Inbox organization.

  Filing never grants source access and never completes attached work. Hosts
  authorize source references separately and provide the resource policies.
  """

  @doc false
  def own(changeset, %{actor: %{id: user_id}}) when not is_nil(user_id) do
    case changeset.action_type do
      :create ->
        Ash.Changeset.force_change_attribute(changeset, :user_id, user_id)

      :update ->
        if changeset.data.user_id == user_id,
          do: changeset,
          else: Ash.Changeset.add_error(changeset, "personal filing belongs to another user")
    end
  end

  def own(changeset, _context),
    do: Ash.Changeset.add_error(changeset, "personal filing requires an authenticated owner")

  @doc "Whether the configured number of elapsed days has passed; nil means never."
  def expired?(%DateTime{} = trashed_at, days, %DateTime{} = now)
      when is_integer(days) and days >= 0 do
    DateTime.compare(trashed_at, DateTime.add(now, -days * 86_400, :second)) != :gt
  end

  def expired?(_trashed_at, _days, _now), do: false

  @doc "Derives system views from independent visibility, queue, and bookmark state."
  def folder_keys(%{visibility: :purged}), do: []
  def folder_keys(%{visibility: :trashed}), do: ["trash"]

  def folder_keys(item) do
    active? = item.visibility == :active

    [
      if(active? and item.queued?, do: "inbox"),
      if(item.sent?, do: "sent"),
      if(item.starred?, do: "starred"),
      if(active? and item.scheduled?, do: "scheduled"),
      if(active? and item.draft?, do: "drafts"),
      if(not active? or not item.queued?, do: "archive"),
      item.project_key,
      if(item.folder_id, do: "personal:" <> item.folder_id)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end
end
