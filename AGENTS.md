# Korero Agent Rules

1. Korero owns the complete, embeddable communication/work experience: UI,
   messages, tasks, channel adapters, and artifact/classification navigation.
   It is not merely a queue engine requiring every host to build its own client.
   The released alpha is still the task/execution foundation; distinguish
   current capabilities from this product contract. Never include host data,
   private paths, credentials, or client policy.
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
8. Keep the dependency graph acyclic. Korero must not depend on AshLotus or a host.
9. Use the public package/app name `korero` and `Korero` module namespace. Keep
   the README a short product introduction; technical contracts and integration
   instructions belong in `docs/integration.md`. Pre-1.0 publication does not
   freeze the API or imply production readiness.
10. Organize across topics, interests, relationships, and events, not exclusive
    folders for email, SMS, tasks, or file types. Classification is many-to-many
    and never grants access. Preserve source identities, participant visibility,
    provenance, and explicit sharing boundaries across every derived view.
11. Korero supplies its own composable UI and installer; hosts provide identity,
    policies, routing/layout/theme configuration, persistence, credentials, and
    typed business actions. Keep domain work in Ash actions, thin LiveViews,
    reusable semantic styling, and Ash-aware Cinder lists. Do not copy shared
    client logic into each host or make the UI the authority for authorization.
