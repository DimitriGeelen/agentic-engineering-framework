# seed_self_gating_ac

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/seed_self_gating_ac.bats`

## What It Does

T-2862 — no seeded Agent AC may name the command that closes its own task.
Origin: lib/seeds/tasks/greenfield/T-002-define-project-goals.md shipped
- [ ] Go/no-go decision recorded: `fw inception decide T-002 go --rationale "..."`
as an Agent AC. The decide preflight refuses while any Agent AC is unchecked,
and that AC *was* the decision — so every greenfield project's first inception
was un-completable by construction. `fw init` seeds these files into every new
project, which makes a seed defect a defect in every consumer at once.
The property pinned here is deliberately narrower than "no AC mentions a
command": an AC may legitimately name `fw task update ... --status
work-completed` when it refers to a DIFFERENT task the learner creates (the

---
*Auto-generated from Component Fabric. Card: `tests-unit-seed_self_gating_ac.yaml`*
*Last verified: 2026-08-08*
