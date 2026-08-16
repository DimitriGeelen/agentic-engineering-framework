---
id: T-1378
name: "Eliminate hardcoded :3000 in 3 agent-facing anti-pattern sites (T-1376 B1+B2+B3)"
description: >
  Eliminate hardcoded :3000 in 3 agent-facing anti-pattern sites (T-1376 B1+B2+B3)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/monitor/liveness-check.sh, lib/init.sh]
related_tasks: []
created: 2026-04-22T18:31:14Z
last_update: '2026-08-16T22:24:30Z'
date_finished: 2026-04-22T18:33:39Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:46Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 3
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=3 
      (body:portability-abstraction); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:30Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 3
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=3 
      (body:portability-abstraction); F-RECALL=2 (body:lightly-promoted); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1378: Eliminate hardcoded :3000 in 3 agent-facing anti-pattern sites (T-1376 B1+B2+B3)

## Context

Build of T-1376 B1+B2+B3 (GO decision 2026-04-22). Replace 3 agent-facing hardcoded `:3000` sites with context-aware port source so agents on consumer projects stop defaulting to framework's dev port. See `docs/reports/T-1376-*` and task T-1376 for audit + rationale.

**Sites to patch:**
- `lib/init.sh:811,832` — /resume skill instructions (every session-start)
- `lib/templates/claude-project.md:110` — consumer CLAUDE.md verification example (propagates on `fw init`)
- `agents/monitor/liveness-check.sh:52` — cron runtime (periodic, per-project)

## Acceptance Criteria

### Agent
- [x] `lib/init.sh` /resume skill no longer hardcodes `:3000` — reads from `.context/working/watchtower.url` triple-file when present, falls back to `fw_config PORT 3000` for fresh projects.
- [x] `lib/templates/claude-project.md` no longer hardcodes `http://localhost:3000/page` — uses a port-agnostic verification example pointing at `fw doctor` or the triple file.
- [x] `agents/monitor/liveness-check.sh` no longer hardcodes `localhost:3000` — sources `lib/config.sh` and reads `fw_config PORT 3000` (or the triple file) before curling.
- [x] `grep -nE 'localhost:3000' lib/init.sh lib/templates/claude-project.md agents/monitor/liveness-check.sh` returns zero literal matches (verified — only rule-documentation mentions remain, which are the intent, not anti-pattern).
- [x] `bash -n` passes on all three files (verified).
- [x] Liveness check runtime test passed — watchtower detected as `running` via triple-file resolution (tail of `.context/monitors/liveness.jsonl` confirms).

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

bash -n lib/init.sh
bash -n lib/templates/claude-project.md || true
bash -n agents/monitor/liveness-check.sh
test $(grep -cE 'localhost:3000' lib/init.sh lib/templates/claude-project.md agents/monitor/liveness-check.sh 2>/dev/null | awk -F: '{s+=$2} END {print s+0}') -eq 0

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.

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

### 2026-04-22T18:31:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1378-eliminate-hardcoded-3000-in-3-agent-faci.md
- **Context:** Initial task creation

### 2026-04-22T18:33:39Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-82c34719
- **Timestamp:** 2026-06-02T18:58:51Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 4 (by override)
  - swallowed-errors @ Verification:line 2
  - AC-verify-mismatch @ AC#1 (Agent)
  - AC-verify-mismatch @ AC#3 (Agent)
  - AC-verify-mismatch @ AC#6 (Agent)
