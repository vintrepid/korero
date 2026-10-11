defmodule Korero.Test.Tag do
  @moduledoc "Synthetic native Ash contract for the TagAsh tag backend."
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
      accept [:context_id, :name, :slug]
      upsert? true
      upsert_identity :unique_context_slug
      upsert_fields [:name]
    end
  end

  policies do
    policy always() do
      authorize_if actor_present()
    end
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :slug, :string, allow_nil?: false, public?: true
  end

  relationships do
    belongs_to :context, Korero.Test.TagContext, allow_nil?: false, attribute_writable?: true
  end

  identities do
    identity :unique_context_slug, [:context_id, :slug]
  end
end
