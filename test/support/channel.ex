defmodule Korero.Test.Channel do
  @moduledoc false
  @behaviour Korero.Scope
  use Ash.Resource,
    primary_read_warning?: false,
    domain: Korero.Test.CoreDomain,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [Korero.Test.CoreIdentities],
    fragments: [Korero.Channel]

  ets do
    private? true
  end

  policies do
    policy action_type(:create) do
      authorize_if Korero.Test.OwnChannel
    end

    policy action_type([:read, :update]) do
      authorize_if expr(user_id == ^actor(:id))
    end
  end

  @impl true
  def korero_app_key, do: "example"
end
