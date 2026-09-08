# Security Policy

Inbox is experimental. The host owns authorization, tenancy, retention,
encryption, data-layer transactions, uniqueness, and access to task contents.
The fragment does not add an allow-all policy or an authorization boundary.
Choose explicit host policies before exposing its actions to users.

Task references are opaque registry keys and identifiers, never module names
to resolve or execute. Keep credentials, document bodies, and provider payloads
out of task identifiers and delivery arguments. Inbox has no generic external
effect runner and does not claim exactly-once or transactional delivery.

Hosts explicitly select AshOban triggers, queues, worker actors, and policies.
Keep worker authorization enabled and grant only the required reads/actions;
Inbox installs no authorization bypass. Revalidate persisted actors and tenants
when jobs run. A completed Oban job does not itself complete a human task or
an attached domain resource. Duplicate execution and external effects require
host-owned idempotency and transaction design.

Report vulnerabilities through [GitHub private vulnerability reporting](https://github.com/vintrepid/inbox/security/advisories/new).
Do not include credentials, private host data, or
exploit material in public issues.

Decimal is constrained to `>= 3.0.0 and < 4.0.0`. The
[upstream advisory](https://github.com/ericmj/decimal/security/advisories/GHSA-rhv4-8758-jx7v)
identifies 3.0.0 as patched for CVE-2026-32686, while the current advisory feed
marks every version affected. The audit therefore acknowledges only
`EEF-CVE-2026-32686`; all other advisories remain failures.
