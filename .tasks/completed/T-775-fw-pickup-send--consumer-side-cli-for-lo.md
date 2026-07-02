---
id: T-775
name: "fw pickup send — consumer-side CLI for local and TermLink push"
description: >
  Consumer-side CLI command: serialize pickup envelope YAML, write to local inbox
  or push via termlink remote push. Supports --type, --summary, --detail, --priority,
  --remote flags.

status: work-completed
workflow_type: build
owner: claude-code
horizon: null
components: []
related_tasks: [T-772, T-774]
created: 2026-03-30T13:21:40Z
last_update: '2026-06-11T22:24:29Z'
date_finished: 2026-03-30T14:11:45Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:29Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 4
      F-RECALL: 2
      F-ORCH: 3
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=4 
      (body:cross-machine); F-RECALL=2 (body:lightly-promoted); F-ORCH=3 
      (body:typed-io-or-gate); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-775: fw pickup send — consumer-side CLI for local and TermLink push

## Context

Consumer-side CLI for the pickup pipeline (T-772 GO). Depends on T-774 (lib/pickup.sh). Design: `docs/reports/T-772-cross-project-pickup.md`

## Acceptance Criteria

### Agent
- [x] `fw pickup send` subcommand registered in `bin/fw`
- [x] Accepts flags: `--type`, `--summary`, `--detail`, `--priority`, `--source-project`, `--task-id`, `--tags`
- [x] Local mode: writes YAML envelope to `.context/pickup/inbox/P-NNN-type.yaml`
- [x] `--remote` flag: pushes via `termlink remote push` (requires TermLink)
- [x] Auto-generates pickup_id (P-NNN) and dedup_hash
- [x] Validates required fields before writing
- [x] `fw pickup send --help` shows usage — 9 new send tests, 37 total

## Verification

cd /opt/999-Agentic-Engineering-Framework && bin/fw pickup send --help

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

### 2026-03-30T13:21:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-775-fw-pickup-send--consumer-side-cli-for-lo.md
- **Context:** Initial task creation

### 2026-03-30T14:08:15Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-30T14:11:45Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e9e0e234
- **Timestamp:** 2026-06-02T15:04:50Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#3 (Agent)** — Local mode: writes YAML envelope to `.context/pickup/inbox/P-NNN-type.yaml`
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/pickup/inbox/P-NNN-type.yaml in: Local mode: writes YAML envelope to `.context/pickup/inbox/P-NNN-type.yaml``
