# Integration and architecture

Korero owns a complete embeddable communication/workspace experience, including
the UI. Its primary model is a task runner; messages are degenerate tasks.
This guide documents the current extraction branch; the broader product and UI
ownership contract is in [product architecture](product-architecture.md).

Applications retain their identity, policies, persistence, theme, provider
credentials, and business actions. They should not have to rebuild the shared
client UI. `Korero.Task` currently adds the reusable task contract and native
AshOban execution without creating another job engine.

## Installation

Korero is available independently from Git, or through the AshLotus distribution:

```elixir
{:korero, github: "vintrepid/korero", tag: "v0.1.0-alpha.2"}
```

When using AshLotus, it supplies Korero; follow its documented top-level Ash
override exception when another direct dependency also declares Ash. Pre-1.0 APIs
may change between releases. Git pins make builds reproducible, not interfaces
permanent.

## Status

`0.1.0-alpha.2` is experimental. It provides standalone task lifecycle,
assignment, priority, scheduling fields, idempotent requests, and optimistic
revisions, and opt-in native AshOban triggers. Oban owns job delivery and retries;
hosts explicitly select which Ash actions are executable. Korero does not yet
dispatch attached domain actions, implement scheduling dependencies, record
task-level attempts, replicate tasks, or integrate a
semantic journal. No worker starts merely because Korero is a dependency, and
human tasks are not automatically executed or completed.

The task's current Ash record is authoritative. Messages own communication
state, tasks own work, and an attached resource owns its own domain lifecycle.
Reading a message never completes its attached task. History is not replayed to
rebuild current state. The extraction adds shared presentation, URL state,
trusted dispatch, personal channel configuration and TagAsh classification;
it does not replace Calvin's production adapters or infer provider accounts.

## Shared client extraction

`Korero.Client.Threads.build/1` groups already-authorized occurrences by source
thread and visibility, preserving separate active/archive/trash occurrences and
task priority. `Korero.Client.State.select/2` chooses only authorized folders and
loaded threads. `State.path/3` and `State.criteria/1` keep workflow, participant,
folder and cursor filters in the URL. `Korero.Client.Cursor` supplies bounded,
folder-bound keyset cursor serialization; a cursor is never an access grant.

`Korero.Phoenix.Components.workspace/1` supplies the shared navigation/queue/focus
client extracted copy-first from Calvin. Pass `client`, selected `state` and a
local `inbox_path`; import `../../deps/korero/priv/korero.css` in the host's CSS.
Host slots supply typed business actions, message composition, rich text and
classification. The host supplies an actor-authorized, bounded source projection,
layout, subscriptions and a thin LiveView adapter. No source query, role bypass,
credential, or host-specific execution heuristic was copied into presentation.
Calvin's current files/routes remain intact; switching its adapters is a separate
verified integration, not a destructive extraction step.

## Native installer

With Igniter present, `mix korero.install` creates host-owned Task, Message,
Channel and personal filing resources, registers the domain/repository and
schedules `ash.codegen install_korero`. It never migrates a database or starts
workers. Apply and review the generated production migration with the host's
normal Ash workflow.

To mount an existing authenticated host adapter for the shared client:

```sh
mix korero.install --live-view MyAppWeb.InboxLive \
  --on-mount MyAppWeb.LiveUserAuth:live_user_required --path /inbox
```

User resource, repository, domain and router are configurable. Existing files
are preserved; repeat installation does not claim unverified routes are private.
Use `--task-resource`, `--message-resource` and `--channel-resource` to map existing
host models. Task and message can name the same combined resource; the installer
preserves it and does not generate parallel models for the same work.
An installer cannot invent identity policies, channel providers or a placeholder
client and call them a completed integration. AshLotus delegates to this native
installer rather than maintaining another implementation.

## Message envelopes

`Korero.Message` is an optional Ash fragment for the mutable envelope of a
host-owned message. It adds `subject`, `distribution_keys`, and the
`edit_envelope` action. Distribution keys are opaque participant identities;
the host decides what they mean, who may add them, how recipients are loaded,
and whether a recipient can read or receive the message. Repeating an edit does
not duplicate a distribution key, and omitting the subject leaves it unchanged.

The host still owns message content, sender and primary-recipient relationships,
storage, policies, canonical links, delivery adapters, and delivery audit. The
fragment deliberately performs no email, text, or app delivery and does not
complete an attached task.

A message is a degenerate task: a host can compose `Korero.Task` and
`Korero.Message` on the same resource. Envelope edits remain communication
changes, not completion. Existing hosts may keep separate communication and
work occurrences without migrating them merely to use the client.

## Personal channels

`Korero.Channel` is a native Ash fragment for app-and-user-owned configuration.
The host resource implements `c:Korero.Scope.korero_app_key/0`, returning a stable
application key such as `"example"`; it supplies storage and authorization policies.
The fragment derives `user_id` from the authenticated UUID actor, never a form.
The `(app_key, user_id, key)` identity is immutable. Native reads always apply
that scope; updates reject another actor or application even when a caller
has disabled host policies.
Set `primary_read_warning?: false` on this host resource: its primary-read
scope preparation is intentional, including relationship reads.

`configure` creates idempotently and preserves existing configuration on retry.
Use `update_configuration` for deliberate changes with optimistic revision
checks. Channel kind is `:app`, `:email`, or `:sms`; the record stores its label,
address, enabled status, trusted provider registry key, and an optional opaque
secret-store reference like `"vault:credential-identity"`. It stores no provider
password or token. Provider keys are not executable modules. Host delivery must
reload and authorize the selected user's channel and resolve its secret reference
through the host's trusted secret store. An app's notification mailer is not
implicitly a person's email account. No delivery adapter or worker is started
by this fragment.

## Classification with TagAsh

`Korero.Classification` is a native Ash action fragment. Its host resource
implements `korero_app_key/0` and `korero_subject_authorizer/0`; the latter returns
a trusted `Korero.Classification.SubjectAuthorizer` module. That callback must
authorize the stable `TagAsh.SubjectRef` through the host's source registry and
native Ash policies for every read or classification mutation. It receives the
actor, application key, tenant, and requested operation. It must not resolve
reference strings into modules.

The `classify` action accepts a subject reference, context key, tag name and
slug. It calls TagAsh's native context/tag upsert and assignment attach actions,
with authorization enabled and the actor and tenant preserved. Context ownership
is an opaque reference derived from application and actor identity; neither a
different owner nor an existing tag ID can be supplied as input. Assignments
record human provenance. `classifications` reauthorizes the subject and filters
assignments by that exact app/user context before returning tag summaries.
Tags never grant visibility or execute/complete work.

By default the backend is `TagAsh.Resources.Context`, `Tag`, and `SubjectTag`.
A trusted host can provide `korero_tag_resources/0` returning a map with
`:context`, `:tag`, and `:assignment` resources honoring those native action
contracts, for example to add tenancy and policies. This is not a new tagging
engine. Direct access to TagAsh's default resources requires host safeguards;
Korero's facade does not install authorization on those resources. Classification
does not promise a cross-resource transaction or encrypt subject metadata.

## Attached execution boundary

The existing attached-task completion rejection remains intentional. A safe
runner requires a trusted versioned task-type/target registry, typed target
arguments derived from authorized source records, source/target/assignee checks,
and a declared host transaction across its touched resources. The target action
must enforce its own policies. A generic bypass flag or a persisted module/action
string is not that contract. Host delivery must be durable post-commit work;
neither job success nor SMTP acceptance proves exactly-once effects or completion
of the invitation's requested reading.

`Korero.Runner` adds native `run_task` dispatch. Implement
`korero_task_resource/0` and `korero_task_actions/0` on its host resource. The
second callback returns a trusted static map, for example
`%{{"reading.article_invitation", 1} => {MyApp.Commands, :run_invitation}}`.
Callers supply only `task_id` and optionally `expected_revision`; the registered
generic Ash command must accept `task_id`, and must accept/enforce
`expected_revision` when stale-intent checks are requested. Korero authorizes the
task read and forwards actor and tenant with authorization enabled. Unknown
type/version and stale revision fail closed. No module/action string is resolved.
The selected command must reauthorize task/source/target **inside its own declared
transaction**, enforce revisions and persist immutable idempotent outcomes.
Dispatch alone changes neither the task nor its target.

## Host resource

Korero supplies Ash 3.33+, AshStateMachine 0.2.13+, Oban 2.23+, and AshOban
0.8.14+ within the dependency ranges in `mix.exs`. A host resource supplies its
static domain, storage, authorization, and tenancy:

```elixir
defmodule MyApp.Work.Task do
  use Ash.Resource,
    otp_app: :my_app,
    domain: MyApp.Work,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [Korero.Task]

  postgres do
    table "workflow_tasks"
    repo MyApp.Repo

    custom_indexes do
      index [:status, :next_action_at, :priority]
      index [:target_resource, :target_key, :status]
    end
  end

  policies do
    policy always() do
      authorize_if actor_attribute_equals(:role, :operator)
    end
  end
end
```

Register the resource in the host domain and generate migrations with
`mix ash.codegen add_workflow_tasks`. The host must supply AshPostgres when
using this example. Configure and migrate the host's Oban repository as well;
Korero does not supply a repository or migrations. Set Ash's string counting
policy in host configuration:

```elixir
config :ash, default_string_length_count: :codepoints
```

Hosts using `Ash.Policy.Authorizer` also choose an Ash-supported SAT solver,
such as `simple_sat` or `picosat_elixir`. Korero's authorization tests use a
test-only `simple_sat` dependency; no solver or policy is chosen for hosts.

The fragment includes the `AshStateMachine` and `AshOban` extensions, fields,
identity, actions, and generated code interfaces. Do not duplicate those
definitions in the host.
Persist the `unique_request_key` identity and optimistic `revision` field in a
data layer that can enforce the required uniqueness and conditional writes.
Database-backed hosts must validate those concurrency guarantees themselves;
private ETS tests are not a database concurrency certification.

## Native actions

```elixir
task =
  MyApp.Work.Task.request!(
    %{request_key: "request:one", title: "Review the report", priority: 1},
    actor: actor
  )

task = MyApp.Work.Task.start!(task, %{}, actor: actor)
task = MyApp.Work.Task.complete!(task, %{}, actor: actor)
```

Tasks begin `:queued`. Open states are `:queued`, `:in_progress`, `:deferred`,
and `:blocked`; `:completed` and `:cancelled` are terminal. Assignment does not
start work. Deferral requires `next_action_at`; scheduling fields describe
intent and do not automatically enqueue or run anything. `open` returns open
tasks ordered by priority (nulls last), then creation time.

Tasks may be created without a request key. The `request` action requires a
stable request key to identify one occurrence.
Retries preserve its original values; reusing the key for a different task
type, source, or target returns an error. Ordinary `create` does not accept a
request key. Request-source and target references each require both their
resource registry key and opaque identity; they are not executable module names.

For transport retries, `Korero.Task.complete_by_request_key/4` and
`Korero.Task.cancel_by_request_key/4` take the host resource module, request key,
attributes, and Ash options. They invoke that resource's native read/transition
interfaces and return an already matching terminal result unchanged. Missing
requests return `{:error, :task_not_found}`. These helpers do not bypass host
authorization or tenancy.

Attached completion deliberately fails closed. A real typed, authorized
target-action contract must exist before it can safely complete domain work.
Cancelling a queue task does not claim to reverse or cancel its target's state.
External effects are not made atomic or exactly-once by a task transition.

## Opt-in Oban execution

Define typed triggers on the host resource. This example explicitly selects
standalone machine tasks and invokes the existing `:start` action; it does not
complete work or dispatch a target reference. Add these sections to the resource
above:

```elixir
actions do
  read :runnable do
    pagination keyset?: true, required?: false
  end

  update :enqueue_machine do
    require_atomic? false
    accept []
    validate attribute_equals(:task_type, "machine_job")
    validate attribute_equals(:status, :queued)
    validate absent([:target_resource, :target_key])
    change run_oban_trigger(:start_machine)
  end
end

oban do
  triggers do
    trigger :start_machine do
      action :start
      read_action :runnable
      worker_read_action :read
      where expr(
        task_type == "machine_job" and status == :queued and
          is_nil(target_resource) and is_nil(target_key)
      )
      scheduler_cron false
      queue :korero
      worker_module_name MyApp.Work.StartMachineWorker
      default_actor %{role: :operator}
    end
  end
end
```

The literal actor above is a host-chosen example credential matching the example
policy, not a Korero default. Real hosts should grant a dedicated worker only its
required reads/actions, or configure an `AshOban.ActorPersister` to reload the
requesting actor at execution time. Worker authorization must remain enabled;
policies, tenancy, and actor validity are evaluated when the job runs. Never
serialize credentials into job arguments. Korero installs no policy bypass.

Use the host's existing Oban child with its repository and the `:korero` queue
configured; do not add a second child:

```elixir
{Oban, AshOban.config([MyApp.Work], Application.fetch_env!(:my_app, Oban))}
```

Request and enqueue through native Ash actions:

```elixir
task = MyApp.Work.Task.create!(%{title: "Prepare a report", task_type: "machine_job"}, actor: actor)

task
|> Ash.Changeset.for_update(:enqueue_machine, %{}, actor: actor)
|> Ash.update!()
```

`run_oban_trigger` inserts into the default Oban instance. Hosts using a named
instance may explicitly use `AshOban.build_trigger/3` with their existing named
`Oban.insert/2` inside a host-owned action. Keep worker module names stable across
deployments so persisted jobs remain executable. `scheduler_cron false` disables
automatic polling; AshOban otherwise defaults triggers to a minute schedule.

The generated worker rereads the record and its filter before running `:start`.
Human, attached, or no-longer-queued tasks do not match. A successful job here
leaves the task `:in_progress`, not `:completed`. Queue persistence, transaction
coupling, retry-safe effects, and production concurrency require host integration
validation. Neither Oban delivery nor task completion proves exactly-once external
effects. See the [native AshOban guide](https://hexdocs.pm/ash_oban/getting-started-with-ash-oban.html)
for trigger, actor, and host configuration details.

## Personal organization

`Korero.InboxItemState`, `Korero.InboxFolder`, and `Korero.InboxPreference`
are optional native Ash fragments for host-persisted personal organization.
The host supplies an authenticated actor with a UUID `id`, its domain/data
layer, relationships, read policies, and authorization of every source and
folder reference. Source identity strings are opaque registry keys, never
module names. A user can organize only sources they are authorized to access.

- Item identity is `(user_id, source_kind, source_id)`. `ensure_source` derives
  its owner from the actor and preserves existing state on retry, including an
  emptied tombstone. `trash`, `archive`, `restore`, `star`, `unstar`, `file`, and
  `empty` are typed resource actions protected by optimistic revisions.
- Archive retains filed material. Trash removes it from all ordinary views.
  Empty moves Trash to `purged` but retains the row and source content; normal
  restore cannot undo it. Physical deletion and privileged recovery are not
  implemented. A stale empty command cannot overwrite a concurrent restore.
- Stars are personal bookmarks, independent of read status or task completion.
  Filing into a personal folder archives that user's item; clearing its folder
  leaves visibility unchanged. No filing action completes a task or mutates
  another participant's communication.
- Preferences default to thirty elapsed days in Trash, with `nil` meaning
  indefinitely and a validated range of zero through 36,500 days. Hosts run
  bounded background retention using current preferences and the `empty`
  action. `Korero.Filing.expired?/3` supplies the exact boundary rule; the
  fragments themselves do not start a retention worker.
- `Korero.Filing.folder_keys/1` derives system views from independent queue,
  visibility, sent, starred, scheduled, and draft facts. Trash and purged items
  never leak into other system, project, or personal views.

System folders are queries, not user-editable rows. Personal folders provide
simple named destinations; hierarchies and many-to-many topic/interest/event
classification remain future separate resources. Neither folders nor tags
grant access, and neither substitutes for the attached resource's lifecycle.

## Verification

```sh
mix deps.get
mix format --check-formatted
mix compile --warnings-as-errors
mix test
mix docs
mix hex.audit
```

Tests use isolated, private ETS-backed host resources and exercise native Ash
actions. The Oban integration test builds a real AshOban job and uses
[`Oban.Testing.perform_job`](https://hexdocs.pm/oban/Oban.Testing.html#perform_job/2)
to execute its generated worker with host authorization, including eligibility
rechecks. It does not certify durable enqueue or database transactions. No
database, external provider, or host application is needed for this suite.
