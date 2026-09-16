defmodule Korero.InboxPreference do
  @moduledoc """
  Host-composed participant retention settings. Trash defaults to thirty days;
  nil means keep indefinitely. Changing the setting applies on the next sweep,
  including existing Trash. Sweeps empty Trash softly and never erase sources.
  """

  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [:read]

    create :configure do
      primary? true
      accept [:trash_retention_days]
      upsert? true
      upsert_identity :unique_owner
      upsert_fields [:trash_retention_days]
    end
  end

  changes do
    change &Korero.Filing.own/2, on: :create
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :user_id, :uuid, allow_nil?: false, public?: true, writable?: false

    attribute :trash_retention_days, :integer,
      default: 30,
      public?: true,
      constraints: [min: 0, max: 36_500]

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_owner, [:user_id]
  end
end
