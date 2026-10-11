defmodule Korero.Test.TagContext do
  @moduledoc "Synthetic native Ash contract for the TagAsh context backend."
  use Ash.Resource,
    domain: Korero.Test.CoreDomain,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [Korero.Test.CoreIdentities]

  ets do
    private? true
  end

  actions do
    defaults [:read]

    create :upsert do
      accept [:owner_ref, :key, :name]
      upsert? true
      upsert_identity :unique_owner_key
      upsert_fields [:name]
    end
  end

  policies do
    policy action_type(:create) do
      authorize_if actor_attribute_equals(:tag_writer?, true)
    end

    policy action_type(:read) do
      authorize_if actor_present()
    end
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :owner_ref, :string, allow_nil?: false, public?: true
    attribute :key, :string, allow_nil?: false, public?: true
    attribute :name, :string, allow_nil?: false, public?: true
  end

  identities do
    identity :unique_owner_key, [:owner_ref, :key]
  end
end
