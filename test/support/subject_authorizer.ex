defmodule Korero.Test.SubjectAuthorizer do
  @moduledoc false
  @behaviour Korero.Classification.SubjectAuthorizer

  @impl true
  def authorize_subject(reference, %{actor: actor, tenant: tenant, operation: operation}) do
    send(self(), {:subject_authorized, actor.id, reference, tenant, operation})

    if reference in actor.subjects,
      do: :ok,
      else: {:error, "subject access denied"}
  end
end
