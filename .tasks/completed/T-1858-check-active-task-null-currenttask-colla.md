---
id: T-1858
name: "check-active-task null current_task collapses focus_session into task slot
  — misleading block message"
description: >
  check-active-task null current_task collapses focus_session into task slot — misleading
  block message

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [bug, fix, hook, governance-gate, focus-state, structural-fix]
components: [agents/context/check-active-task.sh]
related_tasks: [T-1730, T-560, T-1729]
created: 2026-05-15T18:07:58Z
last_update: '2026-08-16T22:24:46Z'
date_finished: 2026-05-15T20:24:12+02:00
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:01Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:46Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1858: check-active-task null current_task collapses focus_session into task slot — misleading block message

## Context

When `focus.yaml` has `current_task: null` AND `focus_session: <S-id>`, the python helper at `agents/context/check-active-task.sh:152-166` prints `" <session-id>"` (leading space, empty task). The shell then reads `read -r CURRENT_TASK FOCUS_SESSION < <(...)` which — under default IFS — strips leading whitespace and shifts the session ID into the `CURRENT_TASK` slot, leaving `FOCUS_SESSION` empty.

Net effect:
1. The "BLOCKED: No active task" branch (line 177) is skipped because `CURRENT_TASK` is non-empty.
2. The session-stamp staleness branch (line 191) is skipped because `FOCUS_SESSION` is empty.
3. The G-013 active-file check (line 309-321) fires with the session ID and emits: `BLOCKED: Task <SESSION-ID> is not active (may be completed or missing).`
4. Agent advice `bin/fw work-on T-XXX` is incorrect — the issue is not a missing task, it's a malformed focus.yaml.

Observed live during session resume on 2026-05-15: `focus.yaml` had `current_task: null` + `focus_session: S-2026-0501-1642`. Every Bash invocation (including read-only `termlink inbox status`) was blocked with the misleading "Task S-2026-0501-1642 is not active" message. Agent attempted `bin/fw context focus --clear` (rejected — not a task ID), confirming the misdirection cost real time.

T-1730 closed the *target-vs-focus drift* class (different command target than focused task). T-560 closed the *stale-session-stamp* class (focus set in prior session). Neither covered the *null-task + session-only* case — the python output shape collapses under IFS, producing a third unrecognized failure mode.

## Acceptance Criteria

### Agent
- [x] **A1** Python helper output format hardened: replace `print(f'{task} {session}')` with a delimiter that survives empty `task` — either explicit tab `\t`, or two `print` lines and `read -r` from process substitution line-by-line, or `mapfile`. Empty `task` MUST produce empty `CURRENT_TASK` regardless of `session` value.
- [x] **A2** When `current_task` is empty/null/missing, hook MUST emit the "BLOCKED: No active task" message (line 177) regardless of `focus_session` value.
- [x] **A3** Bats unit test pins the exact failure mode: focus.yaml fixture with `current_task: null` + `focus_session: S-foo` → hook stderr contains "No active task" AND does NOT contain "S-foo".
- [x] **A4** Bats unit test pins the inverse: focus.yaml fixture with `current_task: T-XXX` + `focus_session: S-foo` → hook reads `CURRENT_TASK=T-XXX` (existing pass-through behaviour preserved).
- [x] **A5** Verification commands in `## Verification` exercise both new tests; existing `tests/unit/focus_drift_gate.bats` (T-1730) still passes.
- [x] **A6** RCA section filled (symptom / root cause / why structurally allowed / prevention).

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

bats tests/unit/focus_drift_gate.bats
bash -c 'TMPR=$(mktemp -d); mkdir -p "$TMPR/.context/working" "$TMPR/.tasks/active"; touch "$TMPR/.framework.yaml"; printf "current_task: null\nfocus_session: S-CANARY\n" > "$TMPR/.context/working/focus.yaml"; out=$(echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"termlink inbox status\"}}" | PROJECT_ROOT="$TMPR" CLAUDECODE=1 bash agents/context/check-active-task.sh 2>&1 || true); rm -rf "$TMPR"; echo "$out" | grep -q "No active task" && ! echo "$out" | grep -q "S-CANARY is not active"'

## RCA

**Symptom:** Session resume on 2026-05-15 — agent ran read-only `termlink inbox status` to triage messages; the Bash gate refused with `BLOCKED: Task S-2026-0501-1642 is not active (may be completed or missing)`. `S-2026-0501-1642` was actually a *session* ID stored in `focus_session:`, not a task ID. Agent's first reflex (`bin/fw context focus --clear`) was rejected as "Task not found: --clear", confirming the message had misdirected the response. Cost: one full cycle of misdiagnosis before `focus.yaml` was inspected directly.

**Root cause:** `agents/context/check-active-task.sh:152` used a single-line space-separated python output (`print(f'{task} {session}')`) piped into `read -r CURRENT_TASK FOCUS_SESSION`. When `current_task` was empty/null but `focus_session` was set, python emitted ` S-XXX\n` (leading space). Default-IFS `read` strips leading whitespace and assigns the only non-empty token to the first variable — shifting the session ID into the `CURRENT_TASK` slot and leaving `FOCUS_SESSION` empty. Downstream:
- Line 175 "No active task" branch was skipped (CURRENT_TASK looked non-empty).
- Line 191 "STALE FOCUS — Task From Previous Session" branch was skipped (FOCUS_SESSION looked empty).
- Line 309-321 G-013 active-file check fired with the session ID as the search target → misleading message.

**Why structurally allowed:** T-1730 closed the *Bash matcher gap* and *target-vs-focus drift* class; T-560 closed the *stale-session-stamp* class. Both assume `current_task` and `focus_session` parse into the slots their YAML keys imply. Neither tested the python→shell hand-off shape when one field is empty. The collapse is a wire-format defect at the helper boundary, invisible to the gate logic itself.

**Prevention:**
1. Helper now emits one value per line; reader uses two `read` calls (line 156-178). Empty values can no longer collapse into adjacent slots.
2. `tests/unit/focus_drift_gate.bats` tests #16 (null-task + session preserves "No active task" branch, session ID does NOT appear as a task) and #17 (normal case still passes) pin both directions. Any future refactor that re-introduces single-line space-delimited shape fails CI.

## Evolution

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
-->

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-15T18:07:58Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1858-check-active-task-null-currenttask-colla.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ad020767
- **Timestamp:** 2026-06-02T15:00:04Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **destructive-action** (high) — Destructive operation in verification or AC
     - matched: `rm -rf`
