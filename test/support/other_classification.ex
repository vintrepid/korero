defmodule Korero.Test.OtherClassification do
  @moduledoc false
  @behaviour Korero.Scope
  @behaviour Korero.Classification
  use Ash.Resource,
    domain: Korero.Test.CoreDomain,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [Korero.Classification]

  resource do
    require_primary_key? false
  end

  policies do
    policy always() do
      authorize_if actor_present()
    end
  end

  @impl true
  def korero_app_key, do: "other_app"

  @impl true
  def korero_subject_authorizer, do: Korero.Test.SubjectAuthorizer

  @impl true
  def korero_tag_resources, do: Korero.Test.Classification.korero_tag_resources()
end
