defmodule Korero do
  @moduledoc """
  An embeddable communication and task workspace built on Ash and Oban.

  Korero owns the complete product, including its shared UI: conversations,
  messages, tasks, channel adapters, files, and navigation through topics,
  interests, relationships, and events. Email and SMS are delivery channels,
  not exclusive filing structures. Classification never grants access.

  The current alpha supplies task lifecycle and native job-action integration;
  the shared UI and wider communication/classification experience remain to be
  extracted and implemented. Hosts configure identity, permissions, storage,
  theme, provider credentials, and business-specific actions rather than
  rebuilding the client.

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
