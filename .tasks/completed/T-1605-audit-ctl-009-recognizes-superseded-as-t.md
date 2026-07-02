---
id: T-1605
name: "Audit CTL-009 recognizes SUPERSEDED as terminal decision (clears 2 FAILs on
  T-570/T-578)"
description: >
  Audit CTL-009 recognizes SUPERSEDED as terminal decision (clears 2 FAILs on T-570/T-578)

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-29T19:51:18Z
last_update: '2026-06-11T22:23:53Z'
date_finished: 2026-04-29T19:58:41Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:53Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1605: Audit CTL-009 recognizes SUPERSEDED as terminal decision (clears 2 FAILs on T-570/T-578)

## Context

`bin/fw audit` reports CTL-009 FAIL for T-570 and T-578: both are completed inception tasks that recorded `**Decision**: SUPERSEDED` (work moved to a successor task) but the CTL-009 grep pattern only recognizes `GO`, `NO-GO`, and `DEFER`. SUPERSEDED is a legitimate terminal state — the inception was closed because its question was answered by another arc, not because the work was rejected. Two FAILs in audit, zero substantive risk. Add SUPERSEDED to the grep alternation.

## Acceptance Criteria

### Agent
- [x] `agents/audit/audit.sh` CTL-009 grep recognizes `Decision**: SUPERSEDED` and `Decision: SUPERSEDED`
- [x] `bin/fw audit` no longer reports CTL-009 FAIL for T-570 and T-578
- [x] No regression: GO/NO-GO/DEFER detection still works (verified — uses `inception-decision` keyword from decide pipeline, unchanged by this fix)

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

# Shell commands that MUST pass before work-completed.
grep -q "SUPERSEDED" agents/audit/audit.sh
# Confirm CTL-009 no longer fires for T-570/T-578 — content-asserted no FAIL match
bash -c 'bin/fw audit 2>&1 | grep "CTL-009.*T-570\|CTL-009.*T-578" | grep -v "PASS"; test $? -ne 0'

## Recommendation

- **Recommendation:** GO
- **Rationale:** One-line grep alternation extension. Adds SUPERSEDED to the CTL-009 decision-state recognizer. T-570 and T-578 (manually-annotated SUPERSEDED inceptions where work moved to a successor task) no longer trip a FAIL. GO/NO-GO/DEFER detection unchanged — those route through the `inception-decision` keyword from the decide pipeline.
- **Evidence:**
  - `agents/audit/audit.sh:1811` grep alternation now includes `Decision\*\*: SUPERSEDED` and `Decision: SUPERSEDED`
  - `bin/fw audit` no longer emits `[FAIL] CTL-009: Inception T-570/T-578 has 4 commits but no decision or bypass log`
  - GO inceptions (e.g. T-1067) continue to pass via the `inception-decision` log keyword they contain in Updates

## RCA

**Symptom:** `bin/fw audit` emitted `[FAIL] CTL-009` for two completed inception tasks (T-570, T-578) that had recorded a terminal decision (SUPERSEDED) but in a state-string the audit grep didn't recognize.

**Root cause:** CTL-009's decision-state grep alternation only knew GO/NO-GO/DEFER. SUPERSEDED is a legitimate fourth terminal state (used when an inception's question is answered by another arc, not when its work is rejected). The audit author didn't anticipate this state.

**Why structurally allowed:** The set of valid terminal decision states isn't centralized. Each consumer (audit, decide CLI, Watchtower) carries its own list. Adding SUPERSEDED to one place doesn't propagate. CTL-009 was the only consumer that didn't list it.

**Prevention:** Long-term: centralize the decision-state vocabulary in `lib/inception.sh` and have audit + Watchtower import the list. Short-term: the matching audit warns on SUPERSEDED tasks now passes; future custom states would re-trigger the same FAIL until added. Captured as informal note in CTL-009 comments — full vocabulary-centralization is a separate refactor (out of scope here).

## Decisions

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
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

## Updates

### 2026-04-29T19:51:18Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1605-audit-ctl-009-recognizes-superseded-as-t.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-03476684
- **Timestamp:** 2026-06-02T14:58:36Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-29T19:58:41Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
