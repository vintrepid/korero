# Security Policy

Korero is experimental. The host owns authorization, tenancy, retention,
encryption, data-layer transactions, uniqueness, and access to task contents.
The fragment does not add an allow-all policy or an authorization boundary.
Choose explicit host policies before exposing its actions to users.

Task references are opaque registry keys and identifiers, never module names
to resolve or execute. Keep credentials, document bodies, and provider payloads
out of task identifiers and delivery arguments. Korero has no generic external
effect runner and does not claim exactly-once or transactional delivery.

Hosts explicitly select AshOban triggers, queues, worker actors, and policies.
Keep worker authorization enabled and grant only the required reads/actions;
Korero installs no authorization bypass. Revalidate persisted actors and tenants
when jobs run. A completed Oban job does not itself complete a human task or
an attached domain resource. Duplicate execution and external effects require
host-owned idempotency and transaction design.

Report vulnerabilities through [GitHub private vulnerability reporting](https://github.com/vintrepid/korero/security/advisories/new).
Do not include credentials, private host data, or
exploit material in public issues.

Ash is constrained to `>= 3.34.6` within the 3.x line, covering the October 2026
private-argument, related-policy, atom-filter and field-policy fixes. Decimal is
constrained to `~> 3.1.2`, including the rounding-allocation fix. Host Git overrides
must include these fixes too; Hex audit cannot certify an old Git fork.

No dependency advisories are ignored. Run `mix precommit` to audit the locked
dependencies before loading applications, then verify the native contracts.

Classification reauthorizes each subject through a trusted host source registry.
Raw TagAsh resources require separate host safeguards and must not be exposed as
untrusted APIs or administration routes. Personal tag context, folder membership,
or classification never grants source visibility or permission to execute work.
