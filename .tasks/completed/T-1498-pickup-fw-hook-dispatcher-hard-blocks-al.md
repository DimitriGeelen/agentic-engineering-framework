---
id: T-1498
name: "Pickup: fw hook dispatcher hard-blocks all tool calls when target script is
  missing (downstream T-007) (from 003-NTB-ATC-Plugin)"
description: >
  Auto-created from pickup envelope. Source: 003-NTB-ATC-Plugin, task T-007. Type:
  bug-report.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [pickup, bug-report]
components: []
related_tasks: []
created: 2026-04-26T11:13:09Z
last_update: '2026-06-11T22:23:50Z'
date_finished: 2026-04-26T17:43:04Z
source_task_id_in_origin: T-007
source_project_in_origin: "003-NTB-ATC-Plugin"
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:50Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 1
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=0
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=1 (body:hand-wired-dispatch); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1498: Pickup: fw hook dispatcher hard-blocks all tool calls when target script is missing (downstream T-007) (from 003-NTB-ATC-Plugin)

## Context

Pickup envelope P-003 (003-NTB-ATC-Plugin / T-007, 2026-04-15) reported two failure modes of the same class:

**Mode (1):** `PreToolUse:Bash` hook errors `Hook script not found or not executable` and hard-blocks every subsequent Bash call — user session unrecoverable without manual hook removal.

**Mode (2):** `fw task review T-002` errored with `bash: /tmp/tl-dispatch/fabric-purpose-fill/run.sh: No such file or directory` — TermLink dispatch registered but target script never materialized.

**Mode (1) is already fixed in T-1360 / G-053-B:** `bin/fw:4046-4056` degrades to allow on missing hook script, logs to `.context/working/.hook-crashes.log`, exits 0. No more hard-block cascade.

**Fix (c) audit/doctor coverage already exists:** `bin/fw:1171-1177` — `fw doctor` checks every registered hook's `script_path`, reports `script not found` / `script not executable` / `stale Homebrew Cellar path` warnings.

**Mode (2) is a separate concern** — TermLink dispatch artifact lifecycle, not the hook dispatcher. The current envelope did not provide enough state context (when was `/tmp/tl-dispatch/...` created? cleaned up? race?) to write a proper RCA. If mode (2) recurs, file as a fresh task with reproducible repro.

The proposed fix (b) "dispatch machinery should materialize before calling or fail with clear non-blocking error" is generic and worth filing as inception only if the symptom repeats.

## Acceptance Criteria

### Agent
- [x] Confirm graceful hook-missing fallback at `bin/fw:4046-4056` (T-1360 / G-053-B)
- [x] Confirm `fw doctor` checks hook script existence at `bin/fw:1171-1177`
- [x] Document mode (2) as out-of-scope (TermLink dispatch, not hook dispatcher) — to be filed separately if it recurs

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

grep -q "Hook script not found.*degrading to allow" bin/fw
grep -q "script not found:" bin/fw
grep -q "script not executable:" bin/fw

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

### 2026-04-26T11:13:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1498-pickup-fw-hook-dispatcher-hard-blocks-al.md
- **Context:** Initial task creation

### 2026-04-26T17:43:04Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e1179bd2
- **Timestamp:** 2026-06-02T14:57:53Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-26T17:43:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
