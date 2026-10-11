defmodule Korero do
  @moduledoc """
  An embeddable task runner and communication workspace built on Ash and Oban.

  Korero owns the complete product, including its shared UI: conversations,
  messages, tasks, channel adapters, files, and navigation through topics,
  interests, relationships, and events. Email and SMS are delivery channels,
  not exclusive filing structures. Classification never grants access.

  Messages are degenerate tasks: compose the task and message fragments on one
  resource without conflating work completion, delivery or acknowledgement.
  Applications and their users configure their own channels and credentials;
  an application's notification mailer is not a user's email account.

  The extraction supplies native task lifecycle, trusted versioned dispatch,
  personal channels, a TagAsh-backed classifier, and composable Inbox workspace
  presentation and URL state copied from Calvin. Calvin's implementation stays
  alongside it. Full rich-text, provider and domain adapters are not implicitly
  installed. Hosts configure identity, permissions, storage, theme, message
  implementations and typed business-specific commands.

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
