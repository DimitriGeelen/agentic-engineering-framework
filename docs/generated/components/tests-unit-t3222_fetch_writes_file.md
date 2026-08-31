# t3222_fetch_writes_file

> Pins that curl and wget are admitted by the Bash safe-list only when they do not write a file. Both sat in the list unconditionally, so `curl -o FILE` and `wget -O FILE` — which write with no shell redirect, and are therefore invisible to has_bash_write_pattern — ran with no active task. Covers 22 spellings in both directions, including the stdout forms (`-o -`, `-O -`) that must stay safe and the framework's own documented verification idiom `curl -sf "$(bin/fw watchtower url)/page"`. Two legs carry the design decision: one asserts a commit whose MESSAGE mentions `curl -o` is still admitted (why the check is clause-scoped rather than in the whole-string write scanner), and one asserts a commit chained to a fetch-write is now refused with no change to the T-3221 commit predicate. Mutation control restores the unconditional arm from live source; a no-widening sweep asserts the fix admits nothing the pre-fix version blocked.


**Type:** script | **Subsystem:** testing | **Location:** `tests/unit/t3222_fetch_writes_file.bats`

**Tags:** `gate`, `regression`, `mutation-control`, `no-widening`, `task-gate`, `allowlist`, `T-3222`

## What It Does

T-3222 — `curl` and `wget` sat on the Bash safe-list unconditionally, so
`curl -o FILE` and `wget -O FILE` were admitted WITH NO ACTIVE TASK.
That contradicted the admission rule the list states for itself — "only verbs
that cannot write a file WITHOUT a shell redirect", the basis on which it
excludes `awk` and `uniq`. Both write a file with no redirect, so
has_bash_write_pattern (which looks for redirects) never saw them.
Reported as a side finding by peer 832-Workflow-designer on their T-638, while
they were fixing the sibling defect this repo closed as T-3221. Confirmed here
against the live hook before anything was changed.
WHERE THE CHECK LIVES, and why that is the interesting part. The obvious home

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [safe-commands](/docs/generated/agents-context-lib-safe-commands) | calls | Allowlist of safe bash commands for task gate bypass — git status, ls, cat, grep etc. that dont need an active task. |
| [check-active-task](/docs/generated/agents-context-check-active-task) | calls | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3222_fetch_writes_file.yaml`*
*Last verified: 2026-08-30*
