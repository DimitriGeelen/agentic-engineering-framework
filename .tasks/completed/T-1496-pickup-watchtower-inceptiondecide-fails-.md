---
id: T-1496
name: "Pickup: Watchtower /inception/decide fails: CLAUDECODE env inheritance blocks
  finalizer (downstream T-012) (from 003-NTB-ATC-Plugin)"
description: >
  Auto-created from pickup envelope. Source: 003-NTB-ATC-Plugin, task T-012. Type:
  bug-report.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [pickup, bug-report]
components: []
related_tasks: []
created: 2026-04-26T11:13:01Z
last_update: '2026-06-11T22:23:50Z'
date_finished: 2026-04-26T17:40:17Z
source_task_id_in_origin: T-012
source_project_in_origin: "003-NTB-ATC-Plugin"
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:50Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1496: Pickup: Watchtower /inception/decide fails: CLAUDECODE env inheritance blocks finalizer (downstream T-012) (from 003-NTB-ATC-Plugin)

## Context

Pickup envelope P-001 (003-NTB-ATC-Plugin / T-012, 2026-04-15) reported that Watchtower's POST /inception/T-XXX/decide records the decision block but the finalizer is blocked because the Flask subprocess inherits CLAUDECODE=1 from the parent Claude Code shell, tripping the T-1259 agent-invocation guard at `lib/inception.sh:204`.

**The fix already landed under T-1262 — this pickup is a duplicate of work already done in this framework.**

Evidence (verified 2026-04-26):
1. `web/subprocess_utils.py:50` strips CLAUDECODE from the subprocess env: `subprocess_env = {k: v for k, v in os.environ.items() if k != "CLAUDECODE"}` — defense in depth.
2. `web/blueprints/inception.py:498` passes `--from-watchtower` on the decide call: `["inception", "decide", task_id, decision, "--rationale", rationale, "--from-watchtower"]`.
3. `lib/inception.sh:299-301` honors the flag: `if [ "${CLAUDECODE:-}" = "1" ] && [ "$i_am_human" = false ] && [ "$from_watchtower" = false ]; then` — guard exempts both `--i-am-human` (script/test) and `--from-watchtower` (Flask) per CLAUDE.md instruction-precedence rules.

The downstream project (003-NTB-ATC-Plugin) needs `fw upgrade` to pick up the fix, but no further framework work is required.

## Acceptance Criteria

### Agent
- [x] Verify CLAUDECODE strip in `web/subprocess_utils.py` (line 50)
- [x] Verify `--from-watchtower` pass-through in `web/blueprints/inception.py` (line 498)
- [x] Verify guard exemption in `lib/inception.sh` (line 301)
- [x] Confirm fix is in framework history (T-1262)

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

grep -q 'CLAUDECODE' web/subprocess_utils.py
grep -q 'from-watchtower' web/blueprints/inception.py
grep -q 'from_watchtower' lib/inception.sh
ls .tasks/completed/T-1262-* >/dev/null 2>&1 || ls .tasks/active/T-1262-* >/dev/null 2>&1

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

### 2026-04-26T11:13:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1496-pickup-watchtower-inceptiondecide-fails-.md
- **Context:** Initial task creation

### 2026-04-26T17:40:17Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8b5f7524
- **Timestamp:** 2026-06-02T14:57:53Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 4
     - evidence: `ls .tasks/completed/T-1262-* >/dev/null 2>&1 || ls .tasks/active/T-1262-* >/dev/null 2>&1`
### 2026-04-26T17:40:17Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
