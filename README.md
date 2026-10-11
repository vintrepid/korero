# Korero

*Kōrero* is Māori for talk, discussion, conversation, or story.

Kōrero is being built as a complete, task-oriented communication workspace
you can drop into your app—UI included.

A task runner with the familiarity of an Inbox. Messages are a simple kind of
task; reading them is separate from completing the work they request.

Email is only the beginning. SMS, messages, files, and other communication
belong together, organized around topics, interests, and events—not separated
into silos by file type or delivery channel. Folders evolve into a way to
explore those connections: a Finder for what things are about.

**Early alpha:** native Ash task lifecycle and registered command dispatch,
per-app/per-user channels, TagAsh-backed classification and shared Inbox
components are being extracted copy-first from Calvin. Apps own their message
implementations, permissions and credentials. No email account or worker is
automatically configured. The broader communication workspace is still evolving.

```elixir
{:korero, github: "vintrepid/korero", tag: "v0.1.0-alpha.2"}
```

Also supplied through AshLotus. See the [integration guide](docs/integration.md)
for today's capabilities and [product architecture](docs/product-architecture.md)
for the complete package we're building. Pre-1.0 APIs may change.
