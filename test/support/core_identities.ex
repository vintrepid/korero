defmodule Korero.Test.CoreIdentities do
  @moduledoc false
  use Spark.Dsl.Extension, transformers: [Korero.Test.PrecheckCoreIdentities]
end
