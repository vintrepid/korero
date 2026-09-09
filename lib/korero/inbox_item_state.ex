defmodule Korero.InboxItemState do
  @moduledoc """
  A participant's organization of a communication/work item, independent of its source.

  Compose this fragment into a host-owned Ash resource. The host must enforce
  read ownership and authorize source and folder references on writes. Source
  identifiers are opaque; this fragment never looks up a module from a string.

  Archive is retained filing. Trash is reversible soft deletion. Emptying Trash
  moves the participant's state to `purged`, retaining both the filing row and
  source content; ordinary restore deliberately cannot resurrect emptied items.
  Physical erasure and privileged recovery remain future explicit contracts.
  Stars are personal bookmarks, not tasks or immutable preservation guarantees.
  """

  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [:read]

    create :ensure_source do
      primary? true
      accept [:source_kind, :source_id]
      upsert? true
      upsert_identity :unique_owner_source
      upsert_fields []
    end

    update :trash do
      require_atomic? false
      accept []
      change &__MODULE__.trash/2
    end

    update :archive do
      require_atomic? false
      accept []
      validate attribute_in(:visibility, [:active, :archived])
      change set_attribute(:visibility, :archived)
    end

    update :restore do
      require_atomic? false
      accept []
      change set_attribute(:visibility, :active)
      change set_attribute(:trashed_at, nil)
      change set_attribute(:emptied_at, nil)
    end

    update :star do
      require_atomic? false
      accept []
      change set_attribute(:starred, true)
    end

    update :unstar do
      require_atomic? false
      accept []
      change set_attribute(:starred, false)
    end

    update :file do
      require_atomic? false
      accept []
      argument :folder_id, :uuid, allow_nil?: true
      change &__MODULE__.file/2
    end

    update :empty do
      description "Removes this item from Trash without deleting any source content."
      require_atomic? false
      accept []
      validate attribute_in(:visibility, [:trashed, :purged])
      change &__MODULE__.empty/2
    end
  end

  changes do
    change &Korero.Filing.own/2, on: [:create, :update]
    change &__MODULE__.reject_purged/2, on: :update
    change optimistic_lock(:revision), on: :update
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :user_id, :uuid, allow_nil?: false, public?: true, writable?: false

    attribute :source_kind, :string,
      allow_nil?: false,
      public?: true,
      constraints: [allow_empty?: false]

    attribute :source_id, :string,
      allow_nil?: false,
      public?: true,
      constraints: [allow_empty?: false]

    attribute :visibility, :atom,
      allow_nil?: false,
      default: :active,
      public?: true,
      constraints: [one_of: [:active, :archived, :trashed, :purged]]

    attribute :starred, :boolean, allow_nil?: false, default: false, public?: true
    attribute :folder_id, :uuid, public?: true
    attribute :trashed_at, :utc_datetime_usec, public?: true
    attribute :emptied_at, :utc_datetime_usec, public?: true
    attribute :revision, :integer, allow_nil?: false, default: 1, public?: true
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_owner_source, [:user_id, :source_kind, :source_id]
  end

  @doc false
  def reject_purged(
        %{data: %{visibility: :purged}, action: %{name: action}} = changeset,
        _context
      )
      when action != :empty,
      do: Ash.Changeset.add_error(changeset, "an emptied item cannot be restored or refiled")

  def reject_purged(changeset, _context), do: changeset

  @doc false
  def trash(changeset, _context) do
    changeset
    |> Ash.Changeset.force_change_attribute(:visibility, :trashed)
    |> Ash.Changeset.force_change_attribute(
      :trashed_at,
      changeset.data.trashed_at || DateTime.utc_now()
    )
  end

  @doc false
  def empty(changeset, _context) do
    changeset
    |> Ash.Changeset.force_change_attribute(:visibility, :purged)
    |> Ash.Changeset.force_change_attribute(
      :emptied_at,
      changeset.data.emptied_at || DateTime.utc_now()
    )
  end

  @doc false
  def file(changeset, _context) do
    folder_id = Ash.Changeset.get_argument(changeset, :folder_id)
    changeset = Ash.Changeset.force_change_attribute(changeset, :folder_id, folder_id)

    if folder_id do
      changeset
      |> Ash.Changeset.force_change_attribute(:visibility, :archived)
      |> Ash.Changeset.force_change_attribute(:trashed_at, nil)
      |> Ash.Changeset.force_change_attribute(:emptied_at, nil)
    else
      changeset
    end
  end
end
