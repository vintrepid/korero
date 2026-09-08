defmodule Korero do
  @moduledoc """
  A conversation and task-runner library foundation built on Ash and Oban.

  Korero's direction is an integrated conversation, email-client, and task-runner
  experience. The current library supplies task lifecycle and native job-action
  integration, not a finished email client or shared user interface.

  Add `Korero.Task` as a fragment of a host-owned Ash resource. Use that
  resource's native Ash actions and generated code interfaces. The host supplies
  storage, authorization, and its existing Oban instance. Korero supplies Oban
  and AshOban, and the fragment makes native, typed AshOban triggers available
  on the host resource. Hosts explicitly select executable actions and jobs;
  human tasks are not automatically executed or completed.

  Korero does not start a second job engine, install a Logger integration, or
  infer attached domain actions from task references. See the README for a
  product overview, and the integration guide for an opt-in host trigger and
  the execution and authorization boundaries.
  """
end
