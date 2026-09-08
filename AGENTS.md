# Inbox Agent Rules

1. Inbox is an independent, application-neutral Ash task and job queue built on
   Oban and AshOban. Never include host application data, private paths,
   credentials, or client policy.
2. Host resources own their domain, data layer, table, tenancy, and authorization.
   Expose reusable lifecycle through native Ash fragments and actions, not copied
   resource implementations or a separate persistence boundary.
3. Message communication state, generic Task lifecycle, and an attached domain
   resource's lifecycle remain distinct. Reading a message never completes work.
4. Attached task completion fails closed until a typed, authorized target-action
   contract exists. Never resolve module names from target-reference strings.
5. Current Ash records are authoritative; history is not replayed to rebuild them.
   Do not claim that logs, queue delivery, or external effects prove a transaction.
6. Use native AshOban triggers and typed host actions with the host's existing
   Oban instance. Do not start a second engine, infer executable actions from
   strings, or automatically run or complete human tasks. The host chooses
   worker credentials; its action policies remain authoritative. Oban owns job
   delivery and retries, not task/domain completion or exactly-once effects.
   Scheduling dependencies, task-level attempts, attached-resource dispatch,
   replication, and journal integration remain separate future boundaries.
7. Tests assert behavior through Ash actions, with isolated synthetic resources.
   Prefer lifecycle, idempotency, authorization, and concurrency invariants over
   assertions about DSL shape or configuration. Read these rules before tests.
8. Keep the dependency graph acyclic. Inbox must not depend on AshLotus or a host.
