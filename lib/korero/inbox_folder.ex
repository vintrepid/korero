defmodule Korero.InboxFolder do
  @moduledoc """
  Host-composed personal filing destinations, separate from system queries.

  Inbox, Sent, Starred, Upcoming, Drafts, Archive, and Trash are computed views;
  they are not mutable folder rows. Personal folders do not grant access or
  replace future many-to-many topic classification. Folder hierarchies and
  ontology relationships remain future work rather than workflow states.
  """

  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:name]
    end

    update :rename do
      require_atomic? false
      accept [:name]
    end
  end

  changes do
    change &Korero.Filing.own/2, on: [:create, :update]
    change optimistic_lock(:revision), on: :update
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :user_id, :uuid, allow_nil?: false, public?: true, writable?: false

    attribute :name, :ci_string,
      allow_nil?: false,
      public?: true,
      constraints: [allow_empty?: false, trim?: true, max_length: 100]

    attribute :revision, :integer, allow_nil?: false, default: 1, public?: true
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_owner_name, [:user_id, :name]
  end
end
