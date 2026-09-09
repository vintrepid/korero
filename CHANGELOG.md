# Changelog

## Unreleased

- Add host-composed personal filing, folders, and Trash-retention preferences.
- Keep archive, soft Trash, emptied tombstones, and stars separate from task
  completion and source communication state; protect updates with revisions.
- Share smart-folder and elapsed-day retention behavior without imposing a
  repository, source authorization policy, or background worker on hosts.

## 0.1.0-alpha.2 — 2026-09-08

- Rename the public library and OTP app from `inbox` to `korero`, and modules
  from `Inbox` to `Korero`, without pre-1.0 compatibility aliases.
- Introduce the conversation, email-client, and task-runner product direction;
  the current artifact remains a reusable library foundation.
- Move technical contracts and Oban integration instructions into their own guide.
- Preserve all 17 native lifecycle and worker behavior tests. Prior release
  history remains available; publication does not freeze the API.

## 0.1.0-alpha.1 — 2026-09-08

- Introduce the host-owned `Inbox.Task` Ash fragment and AshStateMachine lifecycle.
- Build on Oban and AshOban with opt-in native host-action triggers, using the
  host's existing job engine and authorization policies.
- Preserve standalone completion, paired references, idempotent requests,
  optimistic revisions, and fail-closed attached completion.
- Exercise lifecycle behavior with isolated native Ash resource tests.
