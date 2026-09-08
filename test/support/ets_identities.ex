defmodule Inbox.Test.PrecheckIdentities do
  @moduledoc false
  use Spark.Dsl.Transformer

  @impl true
  def transform(dsl) do
    identity = Ash.Resource.Info.identity(dsl, :unique_request_key)
    identity = %{identity | pre_check_with: Inbox.Test.Domain}

    {:ok,
     Spark.Dsl.Transformer.replace_entity(
       dsl,
       [:identities],
       identity,
       &(&1.name == :unique_request_key)
     )}
  end
end

defmodule Inbox.Test.EtsIdentities do
  @moduledoc false
  use Spark.Dsl.Extension, transformers: [Inbox.Test.PrecheckIdentities]
end
