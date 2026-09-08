# Changelog

## 0.1.0-alpha.1 — 2026-09-08

- Introduce the host-owned `Inbox.Task` Ash fragment and AshStateMachine lifecycle.
- Build on Oban and AshOban with opt-in native host-action triggers, using the
  host's existing job engine and authorization policies.
- Preserve standalone completion, paired references, idempotent requests,
  optimistic revisions, and fail-closed attached completion.
- Exercise lifecycle behavior with isolated native Ash resource tests.
