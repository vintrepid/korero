defmodule Korero.Classification.SubjectAuthorizer do
  @moduledoc """
  Host authorization of a stable TagAsh subject before classification.

  Implementations use a trusted source registry and native Ash reads/actions
  with the supplied actor and tenant. Neither reference kinds nor identities
  may be resolved into arbitrary modules. Return `:ok` only for subjects the
  actor may access for the requested operation. Classification never grants
  that access or executes the subject's work.
  """

  @callback authorize_subject(String.t(), map()) :: :ok | {:error, term()}
end
