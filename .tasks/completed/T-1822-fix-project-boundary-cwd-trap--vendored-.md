---
id: T-1822
name: "fix project-boundary cwd-trap — vendored .agentic-framework/ cwd traps consumer agent (session-fatal)"
description: >
  B-1 (HIGH/session-fatal) reported by termlink-agent on 2026-05-14. After cd into .agentic-framework/ from a consumer root (normal diagnostic move), every subsequent cd back, git -C, pushd, or Write to the outer consumer is BLOCKED by check-project-boundary.sh. Root cause: the hook resolves PROJECT_ROOT from cwd; .agentic-framework/ ships FRAMEWORK.md so cwd-inside-vendored-copy makes the hook decide we ARE in the framework repo, and everything outside .agentic-framework/ becomes 'another project'. PROJECT_ROOT env doesn't propagate. Symmetric twin of T-1542 (T-1542 is the write-side; this is the read/cd side). Suggested fix: when cwd is inside a vendored copy AND a parent dir has .framework.yaml (i.e. consumer-vendored not standalone-framework), prefer the OUTER as PROJECT_ROOT. Files: agents/context/check-project-boundary.sh.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [project-boundary, fw-upgrade-incident-2026-05-14, T-559, T-1542, bug]
components: [lib/paths.sh, tests/unit/lib_paths.bats]
related_tasks: [T-559, T-1542, T-1634]
arc_id: project-shape-resilience
created: 2026-05-14T07:30:21Z
last_update: 2026-05-14T14:00:15Z
date_finished: 2026-05-14T14:00:15Z
---

# T-1822: fix project-boundary cwd-trap — vendored .agentic-framework/ cwd traps consumer agent (session-fatal)

## Context

Reported by termlink-agent on 2026-05-14 during framework-upgrade incident. Session-fatal for any consumer agent doing diagnostic work that requires entering the vendored `.agentic-framework/` directory. Symmetric twin of T-1542 (write-side guard) — same root-cause family on the read/cd side.

## Acceptance Criteria

### Agent
- [x] `lib/paths.sh` detects vendored case: when `FRAMEWORK_ROOT` basename is `.agentic-framework` AND its parent contains `.framework.yaml`, sets `PROJECT_ROOT` to the parent.
- [x] Standalone framework checkouts (FRAMEWORK_ROOT not named `.agentic-framework`, or parent has no `.framework.yaml`) keep the existing git-toplevel resolution — no regression.
- [x] Unit test added in `tests/unit/lib_paths.bats` exercising both branches (vendored + standalone) via fixture directories under `/tmp` (tests 6, 7, 8).
- [x] Existing PROJECT_ROOT-sensitive tests still pass (`fw test unit -- tests/unit/lib_paths.bats` → 8/8 ok).
- [x] Reproduction from termlink-agent's report no longer traps: with vendored `.agentic-framework/` (own `.git`, parent `.framework.yaml`), `cd $PROJECT_ROOT_OUTER` from inside `.agentic-framework/` is allowed by the boundary hook — verified live `PROJECT_ROOT=/tmp/.../consumer` resolves to parent.

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

bash -n lib/paths.sh
bash -c 'out=$(bin/fw test unit -- tests/unit/lib_paths.bats 2>&1); echo "$out" | grep -q "^not ok" && exit 1; [ "$(echo "$out" | grep -c "^ok ")" -eq 8 ]'
bash -c 'TMPDIR=$(mktemp -d); mkdir -p "$TMPDIR/consumer/.agentic-framework/lib"; touch "$TMPDIR/consumer/.framework.yaml"; cp lib/paths.sh "$TMPDIR/consumer/.agentic-framework/lib/paths.sh"; unset PROJECT_ROOT FRAMEWORK_ROOT; cd "$TMPDIR/consumer/.agentic-framework" && source lib/paths.sh && [ "$PROJECT_ROOT" = "$TMPDIR/consumer" ] && echo "VENDORED-CASE-OK: $PROJECT_ROOT" || { echo "FAIL: PROJECT_ROOT=$PROJECT_ROOT expected=$TMPDIR/consumer"; exit 1; }'

## RCA

**Symptom:** After a consumer agent `cd`s into the vendored `.agentic-framework/` for a diagnostic move, every subsequent `cd` / `git -C` / Write back to the outer consumer is blocked by `check-project-boundary.sh`. Session-fatal — termlink-agent reported total loss of control. Symmetric twin of T-1542 (write-side).

**Root cause:** `lib/paths.sh` resolved `PROJECT_ROOT` via `git -C $FRAMEWORK_ROOT rev-parse --show-toplevel`. After `fw vendor`, the vendored `.agentic-framework/` is a git clone with its OWN `.git`. So when an agent's cwd is inside the vendored copy, `FRAMEWORK_ROOT` resolves to the vendored directory and git-toplevel collapses to that same directory — making the OUTER consumer (the real project) look like "another project" to the boundary hook.

**Why structurally allowed:** No unit test ever exercised the "vendored consumer + cwd-inside-vendored" shape. All test fixtures used standalone framework or env-var-set PROJECT_ROOT. The git-toplevel heuristic was correct for every shape we'd tested. T-559 added boundary protection, T-1542 added the write-side twin — but read-side cwd resolution sat untouched.

**Prevention:**
1. `tests/unit/lib_paths.bats` tests 6, 7, 8 lock in the vendored-detection branch + standalone preservation + defensive non-collapse — any future regression of the heuristic fails CI.
2. Pairs with T-1542 (write-side guard) — both legs of the cwd-trap pattern now have structural tests.
3. Learning candidate: file an L-entry on "vendored .git is a footgun for path-resolution heuristics — basename + sentinel-file is more robust than git-toplevel for shared-tooling projects."

## Evolution

### 2026-05-14 — location of fix moved from boundary hook to path resolution
- **What changed:** Original report from termlink-agent suggested fixing `agents/context/check-project-boundary.sh`. Investigation showed the hook was working correctly — it was receiving a wrong `PROJECT_ROOT`. The bug was upstream in `lib/paths.sh` where `git rev-parse --show-toplevel` collapsed to the vendored `.git`.
- **Plan impact:** Fix is one-file in `lib/paths.sh` rather than logic changes to the boundary hook. Smaller blast radius — boundary hook stays untouched, every other consumer of `PROJECT_ROOT` (25+ agent scripts) gets the correct value automatically.
- **Triggered:** No new sub-task; the surface-level diagnosis from the incident report needed reframing, not new work.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-05-14T07:30:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1822-fix-project-boundary-cwd-trap--vendored-.md
- **Context:** Initial task creation

### 2026-05-14T07:32:07Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.4)

- **Scan ID:** R-cf7a260d
- **Timestamp:** 2026-05-14T14:00:16Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-14T14:00:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
