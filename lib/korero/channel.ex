defmodule Korero.Channel do
  @moduledoc """
  Native Ash fragment for one person's channel configuration in one application.

  Hosts supply storage, policies and `c:Korero.Scope.korero_app_key/0`. The fragment
  derives immutable scope from that resource and the authenticated actor. Reads
  are scope-filtered and writes reject foreign scope independently of UI filters.
  Policies still remain authoritative; there is no authorization bypass.

  `provider_key` is a trusted host adapter's opaque registry key, never a module
  name to resolve. `credential_ref` is a reference into the host's secret store,
  not credentials. No provider is contacted and no email account is implicitly
  configured merely because an application has a mailer.
  """

  use Spark.Dsl.Fragment, of: Ash.Resource

  code_interface do
    define :configure
    define :read
    define :update_configuration
  end

  actions do
    read :read do
      primary? true
      prepare &Korero.Scope.for_actor/2
    end

    create :configure do
      primary? true
      accept [:key, :kind, :label, :address, :provider_key, :credential_ref, :enabled]
      upsert? true
      upsert_identity :unique_owner_channel
      upsert_fields []
    end

    update :update_configuration do
      require_atomic? false
      accept [:label, :address, :provider_key, :credential_ref, :enabled]
    end
  end

  changes do
    change &Korero.Scope.own/2, on: [:create, :update]
    change optimistic_lock(:revision), on: :update
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :app_key, :string, allow_nil?: false, public?: true, writable?: false
    attribute :user_id, :uuid, allow_nil?: false, public?: true, writable?: false
    attribute :key, :string, allow_nil?: false, public?: true, constraints: [allow_empty?: false]

    attribute :kind, :atom,
      allow_nil?: false,
      public?: true,
      constraints: [one_of: [:app, :email, :sms]]

    attribute :label, :string,
      allow_nil?: false,
      public?: true,
      constraints: [allow_empty?: false]

    attribute :address, :string, public?: true, sensitive?: true
    attribute :provider_key, :string, public?: true, constraints: [allow_empty?: false]

    attribute :credential_ref, :string,
      public?: true,
      sensitive?: true,
      constraints: [allow_empty?: false, match: ~r/^[a-z][a-z0-9_-]*:[^\s]+$/]

    attribute :enabled, :boolean, allow_nil?: false, default: true, public?: true
    attribute :revision, :integer, allow_nil?: false, default: 1, public?: true
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_owner_channel, [:app_key, :user_id, :key]
  end
end
