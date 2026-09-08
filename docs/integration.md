# Integration and architecture

Korero is an independent Ash-native task and job queue built on Oban. It combines
a reusable task lifecycle with AshOban's typed host-action execution. Applications
keep their own Ash resources, policies, and Oban instance; `Korero.Task` adds the
shared behavior without creating another job engine.

## Installation

Korero is available independently from Git, or through the AshLotus distribution:

```elixir
{:korero, github: "vintrepid/korero", tag: "v0.1.0-alpha.2"}
```

When using AshLotus, declare only `ash_lotus`; it supplies Korero. Pre-1.0 APIs
may change between releases. Git pins make builds reproducible, not interfaces
permanent.

## Status

`0.1.0-alpha.2` is experimental. It provides standalone task lifecycle,
assignment, priority, scheduling fields, idempotent requests, and optimistic
revisions, and opt-in native AshOban triggers. Oban owns job delivery and retries;
hosts explicitly select which Ash actions are executable. Korero does not yet
dispatch attached domain actions, implement scheduling dependencies, record
task-level attempts, replicate tasks, provide a shared UI, or integrate a
semantic journal. No worker starts merely because Korero is a dependency, and
human tasks are not automatically executed or completed.

The task's current Ash record is authoritative. Messages own communication
state, tasks own work, and an attached resource owns its own domain lifecycle.
Reading a message never completes its attached task. History is not replayed to
rebuild current state.

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
policy, not an Korero default. Real hosts should grant a dedicated worker only its
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
