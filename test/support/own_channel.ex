defmodule Korero.Test.OwnChannel do
  @moduledoc false
  use Ash.Policy.SimpleCheck

  @impl true
  def describe(_opts), do: "channel is scoped to the acting user and host application"

  @impl true
  def match?(actor, %{changeset: changeset}, _opts) do
    with {:ok, scope} <- Korero.Scope.resolve(changeset.resource, actor) do
      Ash.Changeset.get_attribute(changeset, :user_id) == scope.user_id and
        Ash.Changeset.get_attribute(changeset, :app_key) == scope.app_key
    else
      _invalid -> false
    end
  end

  def match?(_actor, _context, _opts), do: false
end
