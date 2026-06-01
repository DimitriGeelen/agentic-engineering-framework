---
id: T-1541
name: "Pickup: fw task verify T-XXX silently exits 1 on every task — BRE backtick metachar in pattern strips entire verification block (from 003-NTB-ATC-Plugin)"
description: >
  Auto-created from pickup envelope. Source: 003-NTB-ATC-Plugin, task T-214. Type: bug-report.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [pickup, bug-report]
components: []
related_tasks: []
created: 2026-04-27T12:50:02Z
last_update: 2026-04-27T13:31:28Z
date_finished: 2026-04-27T13:31:28Z
source_task_id_in_origin: T-214
source_project_in_origin: "003-NTB-ATC-Plugin"
---

# T-1541: Pickup: fw task verify T-XXX silently exits 1 on every task — BRE backtick metachar in pattern strips entire verification block (from 003-NTB-ATC-Plugin)

## Context

`fw task verify T-XXX` returns exit 1 with no output for every task, regardless of whether the task has a populated `## Verification` block. Root cause is in `bin/fw` (currently line 1937, was line 1892 in the consumer's vendored copy): the BRE pattern `^\`\`\`` is interpreted by GNU grep 3.11 as `^` plus three start-of-buffer assertions, causing every line to match and `grep -v` to strip everything. Under `set -euo pipefail`, the empty-result exit 1 propagates and aborts the script before the `if [ -z "$verification" ]` diagnostic branch can run.

The completion gate (`update-task.sh:197`) uses a robust pattern (`-E` + raw backticks + `|| true`) and is unaffected. Same-class sibling: T-203 in 003-NTB-ATC-Plugin tracks silent-exit-1 in `fw task review`.

5-second repro (confirmed on this host, GNU grep 3.11):
`printf 'foo\nbar\nbaz\n' | grep -v '^\`\`\`'; echo "exit=$?"` → no output, exit=1.

Source: pickup envelope `.context/pickup/auto-deferred/P-041-bugfix-fw-task-verify-from-ntb-atc.yaml` (003-NTB-ATC-Plugin T-214).

## Acceptance Criteria

### Agent
- [x] `bin/fw` line 1937 fixed: replace fragile pattern with `grep -vE '^\s*\`\`\`'` or align with `update-task.sh:254` (collapsed `grep -vE` + `|| true`)
- [x] `|| true` guards the verification extraction pipeline against future regex tweaks under `set -euo pipefail`
- [x] Sweep `bin/fw` and `agents/*/*.sh` for sibling pattern (`var=$(... | grep -v ... | grep -v ...)` under `set -e + pipefail` without `|| true`); document findings even if no other instance is fixed in this task
- [x] Bats regression test: task with populated `## Verification` block → `fw task verify T-XXX` exits 0 with PASS lines printed
- [x] Bats regression test: task with no `## Verification` block → `fw task verify T-XXX` exits 0 with "No verification commands found"
- [x] Bats regression test: task with one failing verification command → `fw task verify T-XXX` exits 1 with FAIL line
- [x] Bug-fix learning captured (per CLAUDE.md Bug-Fix Learning Checkpoint): same class as T-203; field-discovered via consumer pickup

## Verification

# Production fix works on a real task with a populated verification block
bin/fw task verify T-1540 >/dev/null
# Regression suite passes (5 cases: populated/empty/failing/fenced/grep-pattern-isolation)
bats tests/unit/task_verify_extraction.bats
# Learning captured
grep -q "T-1541" .context/project/learnings.yaml

## Decisions

### 2026-04-27 — Collapse the 4-grep pipeline rather than minimal one-line fix

- **Chose:** Replace the 4 separate `grep -v` filters with a single `grep -vE '^##|^\s*```|^\s*#|^\s*$' || true`, mirroring the canonical pattern in `agents/task-create/update-task.sh:254`.
- **Why:** The minimal one-line fix (just replace `grep -v '^\`\`\`'` with `grep -vE '^\s*\`\`\`'`) leaves three sibling pipelines without `|| true` — any future regex tweak could re-introduce the silent-exit-1 hazard. Collapsing into one ERE with the guard kills the whole class of failure on this code path. Plus: alignment with `update-task.sh` removes the asymmetry that allowed only one of the two extractors to be broken.
- **Rejected:** Minimal one-line fix — leaves the sibling-fragility hazard.

## Recommendation

**Recommendation:** GO

**Rationale:** Production bug confirmed (5-second repro reproduces locally), one-line root cause identified at `bin/fw:1937`, fix collapsed to canonical pattern matching `update-task.sh:254`, 5 bats regression tests cover populated/empty/failing/fenced/grep-pattern-isolation cases (all PASS), sibling sweep documented (no other BRE-backtick instance exists; ~10 silent-exit-1 hazards in unrelated regex shapes documented but not in scope per "one bug = one task"), L-299 learning captured, same-class pair with T-203 (003-NTB-ATC-Plugin) noted for cross-project tracking.

**Evidence:**
- `bin/fw:1937` — 4-grep pipeline replaced with 1-grep ERE + `|| true`
- `tests/unit/task_verify_extraction.bats` — 5/5 PASS
- `bin/fw task verify T-1540` — 6/6 PASS (was exit 1 with no output before)
- L-299 in `.context/project/learnings.yaml`
- Sibling sweep in commit message (no direct equivalent of the BRE-backtick trap exists elsewhere)

## Updates

### 2026-04-27T12:50:02Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1541-pickup-fw-task-verify-t-xxx-silently-exi.md
- **Context:** Initial task creation

### 2026-04-27T13:22:52Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now

## Reviewer Verdict (v1.4)

- **Scan ID:** R-ea4a5ca6
- **Timestamp:** 2026-04-27T13:31:29Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 2
     - evidence: `bin/fw task verify T-1540 >/dev/null`

### 2026-04-27T13:31:28Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
