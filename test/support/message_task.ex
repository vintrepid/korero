defmodule Korero.Test.MessageTask do
  @moduledoc false
  use Ash.Resource,
    domain: Korero.Test.CoreDomain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [Korero.Test.CoreIdentities],
    fragments: [Korero.Task, Korero.Message]

  ets do
    private? true
  end
end
