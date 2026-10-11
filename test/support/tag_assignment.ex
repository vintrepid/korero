defmodule Korero.Test.TagAssignment do
  @moduledoc "Synthetic native Ash contract for the TagAsh assignment backend."
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

    read :for_subject do
      argument :subject_ref, :string, allow_nil?: false
      filter expr(subject_ref == ^arg(:subject_ref))
      prepare build(limit: 1_000)
    end

    create :attach do
      accept [:subject_ref, :tag_id, :metadata]
      upsert? true
      upsert_identity :unique_subject_tag
      upsert_fields [:metadata]
    end
  end

  policies do
    policy always() do
      authorize_if actor_present()
    end
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :subject_ref, :string, allow_nil?: false, public?: true
    attribute :metadata, :map, default: %{}, public?: true
  end

  relationships do
    belongs_to :tag, Korero.Test.Tag, allow_nil?: false, attribute_writable?: true
  end

  identities do
    identity :unique_subject_tag, [:subject_ref, :tag_id]
  end
end
