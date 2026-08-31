# t3221_commit_exemption_clause

> Pins the commit-checkpoint exemption in the Bash task gate. Both exemption branches (T-2054 null-focus, T-3179 partial-complete) once admitted any command whose raw text CONTAINED "git commit" — so a trailing `; rm -rf` rode through, a `| tee` write the gate had already flagged was admitted anyway, and an unknown binary passed because a quoted argument said the words. This suite probes the SHIPPED hook through its real stdin JSON contract rather than re-implementing the predicate, and carries two controls that decide whether a green run means anything: a mutation control that rebuilds the pre-fix hook from live source (so reverting the fix reddens the suite), and a 16-command no-widening sweep asserting the fixed hook admits nothing the pre-fix one blocked.


**Type:** script | **Subsystem:** testing | **Location:** `tests/unit/t3221_commit_exemption_clause.bats`

**Tags:** `gate`, `regression`, `mutation-control`, `no-widening`, `task-gate`, `T-3221`

## What It Does

T-3221 — the `git commit` exemptions in check-active-task.sh matched a
MENTION of a commit, not a commit.
Two branches admit a Bash command with no active task (T-2054, focus null
after `--status work-completed`) or with a partial-complete one (T-3179).
Both tested whether the raw command string CONTAINED the words, unanchored to
any clause — so a trailing `; rm -rf …` rode through, and an arbitrary binary
was admitted because a quoted ARGUMENT said "please git commit this".
Reported by peer 832-Workflow-designer (their T-638); confirmed in-tree
against the live hook before anything was changed.
WHAT THIS FILE ASSERTS, and why it is built the way it is:

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-active-task](/docs/generated/agents-context-check-active-task) | calls | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [safe-commands](/docs/generated/agents-context-lib-safe-commands) | calls | Allowlist of safe bash commands for task gate bypass — git status, ls, cat, grep etc. that dont need an active task. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3221_commit_exemption_clause.yaml`*
*Last verified: 2026-08-30*
