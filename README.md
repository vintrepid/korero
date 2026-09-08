# Korero

*Kōrero* is Māori for talk, discussion, conversation, or story.

Korero brings conversation and work together: an email-client and task-runner
direction where messages can lead to tasks, and tasks can drive explicit,
authorized actions. The aim is one place to follow both the conversation and
the work it creates, without confusing a read message with completed work.

Today, Korero is the reusable library foundation for that experience, **not a
finished email client**. Built on Ash, Oban, and AshOban, it provides task
lifecycle, assignment, priority, idempotent requests, optimistic revisions, and
opt-in background execution of typed Ash actions.

Applications keep their own resources, storage, authorization, and existing Oban
instance. Korero does not start a second job engine or automatically complete
human tasks. Messages, tasks, and attached domain resources retain distinct
lifecycles; external effects are not made exactly-once by queue delivery.

Install the experimental Git alpha:

```elixir
{:korero, github: "vintrepid/korero", tag: "v0.1.0-alpha.2"}
```

Add `fragments: [Korero.Task]` to a host-owned Ash resource, then use its native
actions. Korero is also supplied through the AshLotus distribution.

See the [integration guide](docs/integration.md) for setup, host-action triggers,
authorization, verification, and current limitations.

This is a pre-1.0 Git release, not a Hex publication or production-readiness
claim. APIs may change; publication does not freeze them.
