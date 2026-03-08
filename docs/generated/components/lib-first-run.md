# first-run

> First-run experience walkthrough after fw init. Guides new users through governance cycle: create task, make commit, run audit. Auto-triggered when TTY detected.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/first-run.sh`

**Tags:** `lib`, `fw-subcommand`, `onboarding`

## What It Does

fw first-run — Guided walkthrough after fw init
Shows the user the key framework commands by running them one at a time.
Opt-out: fw init --no-first-run
Steps:
1. fw doctor (verify setup)
2. fw context init (start session)
3. Explain next steps (create task, commit, audit, handover)

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `?` | uses |

## Related

### Tasks
- T-304: Build opt-out first-run experience after fw init

---
*Auto-generated from Component Fabric. Card: `lib-first-run.yaml`*
*Last verified: 2026-03-04*
