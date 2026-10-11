defmodule Korero.Test.PrecheckCoreIdentities do
  @moduledoc false
  use Spark.Dsl.Transformer

  @impl true
  def transform(dsl) do
    {:ok,
     Enum.reduce(Ash.Resource.Info.identities(dsl), dsl, fn identity, acc ->
       Spark.Dsl.Transformer.replace_entity(
         acc,
         [:identities],
         %{identity | pre_check_with: Korero.Test.CoreDomain},
         &(&1.name == identity.name)
       )
     end)}
  end
end
