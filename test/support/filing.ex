defmodule Korero.Test.FilingPrecheckIdentities do
  @moduledoc false
  use Spark.Dsl.Transformer

  @impl true
  def transform(dsl) do
    {:ok,
     Enum.reduce(Ash.Resource.Info.identities(dsl), dsl, fn identity, acc ->
       Spark.Dsl.Transformer.replace_entity(
         acc,
         [:identities],
         %{identity | pre_check_with: Korero.Test.FilingDomain},
         &(&1.name == identity.name)
       )
     end)}
  end
end

defmodule Korero.Test.FilingIdentities do
  @moduledoc false
  use Spark.Dsl.Extension, transformers: [Korero.Test.FilingPrecheckIdentities]
end

defmodule Korero.Test.OwnFilingCreate do
  @moduledoc false
  use Ash.Policy.SimpleCheck

  @impl true
  def describe(_opts), do: "creating filing state owned by the authenticated actor"

  @impl true
  def match?(%{id: user_id}, %{changeset: %Ash.Changeset{} = changeset}, _opts)
      when not is_nil(user_id) do
    Ash.Changeset.get_attribute(changeset, :user_id) == user_id
  end

  def match?(_actor, _context, _opts), do: false
end

defmodule Korero.Test.InboxItemState do
  @moduledoc false
  use Ash.Resource,
    domain: Korero.Test.FilingDomain,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [Korero.Test.FilingIdentities],
    fragments: [Korero.InboxItemState]

  ets do
    private? true
  end

  policies do
    policy action_type(:create) do
      authorize_if Korero.Test.OwnFilingCreate
    end

    policy action_type([:read, :update, :destroy]) do
      authorize_if expr(user_id == ^actor(:id))
    end
  end
end

defmodule Korero.Test.InboxPreference do
  @moduledoc false
  use Ash.Resource,
    domain: Korero.Test.FilingDomain,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [Korero.Test.FilingIdentities],
    fragments: [Korero.InboxPreference]

  ets do
    private? true
  end

  policies do
    policy action_type(:create) do
      authorize_if Korero.Test.OwnFilingCreate
    end

    policy action_type([:read, :update, :destroy]) do
      authorize_if expr(user_id == ^actor(:id))
    end
  end
end

defmodule Korero.Test.InboxFolder do
  @moduledoc false
  use Ash.Resource,
    domain: Korero.Test.FilingDomain,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [Korero.Test.FilingIdentities],
    fragments: [Korero.InboxFolder]

  ets do
    private? true
  end

  policies do
    policy action_type(:create) do
      authorize_if Korero.Test.OwnFilingCreate
    end

    policy action_type([:read, :update, :destroy]) do
      authorize_if expr(user_id == ^actor(:id))
    end
  end
end

defmodule Korero.Test.FilingDomain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource Korero.Test.InboxItemState
    resource Korero.Test.InboxFolder
    resource Korero.Test.InboxPreference
  end
end
