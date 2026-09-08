defmodule Inbox do
  @moduledoc """
  An Ash-native task and job queue built on Oban.

  Add `Inbox.Task` as a fragment of a host-owned Ash resource. Use that
  resource's native Ash actions and generated code interfaces. The host supplies
  storage, authorization, and its existing Oban instance. Inbox supplies Oban
  and AshOban, and the fragment makes native, typed AshOban triggers available
  on the host resource. Hosts explicitly select executable actions and jobs;
  human tasks are not automatically executed or completed.

  Inbox does not start a second job engine, install a Logger integration, or
  infer attached domain actions from task references. See the README for an
  opt-in host trigger and the execution and authorization boundaries.
  """
end
