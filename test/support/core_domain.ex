defmodule Korero.Test.CoreDomain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource Korero.Test.Channel
    resource Korero.Test.MessageTask
    resource Korero.Test.RunnerTask
    resource Korero.Test.Classification
    resource Korero.Test.OtherClassification
    resource Korero.Test.TagContext
    resource Korero.Test.Tag
    resource Korero.Test.TagAssignment
  end
end
