---
id: T-1494
name: "Pickup: fw pickup send --remote signature mismatch — broken cross-project delivery (from 003-NTB-ATC-Plugin)"
description: >
  Auto-created from pickup envelope. Source: 003-NTB-ATC-Plugin, task T-062. Type: bug-report.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [pickup, bug-report]
components: [lib/pickup.sh, tests/unit/pickup_send_remote_session.bats]
related_tasks: []
created: 2026-04-26T11:09:01Z
last_update: 2026-04-26T17:35:30Z
date_finished: 2026-04-26T17:35:30Z
source_task_id_in_origin: T-062
source_project_in_origin: "003-NTB-ATC-Plugin"
---

# T-1494: Pickup: fw pickup send --remote signature mismatch — broken cross-project delivery (from 003-NTB-ATC-Plugin)

## Context

`lib/pickup.sh:498` calls `termlink remote push "$remote" "$filepath"` with a single HOST arg, but `termlink remote push` requires `<HUB> <SESSION> [FILE]` — three positional args. Result: `--remote` silently misroutes or errors; cross-project delivery via the documented path never works.

**Direct repro from yesterday (T-1499 mediation):** I tried `fw pickup send --remote local-test` to deliver the relay-back to consumer 003-NTB-ATC-Plugin. It errored with "Provide a file path or --message". I worked around by calling `termlink remote push local-test tl-bubfbc3w P-040-feature-proposal.yaml` directly. That manual workaround is exactly what `--remote` should do — but with a session arg.

Source envelope: P-006 (003-NTB-ATC-Plugin / T-062, 2026-04-22). Proposed fix (a) from the envelope: split into `--hub HOST` + `--session NAME`. Fixes (b) (`--target PROJECT_PATH` for local cross-project) and (c) (post-delivery move to sent/) are out of scope here — file as separate tasks if wanted.

## Acceptance Criteria

### Agent
- [x] `fw pickup send` accepts `--session SESSION` argument (CLI + parser)
- [x] When `--remote HUB` is given, `--session SESSION` is required (clear error if missing)
- [x] Call site at `lib/pickup.sh:498` passes both `$remote` (hub) and `$session` to `termlink remote push`
- [x] Help text (`fw pickup send --help`) documents the new `--session` flag and the requirement
- [x] Bats unit test covers: (1) `--remote without --session` errors, (2) both args present builds correct command line

## Verification

bash -n lib/pickup.sh
bin/fw pickup send --help 2>&1 | grep -q -- "--session"
bats tests/unit/pickup_send_remote_session.bats

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

### 2026-04-26T11:09:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1494-pickup-fw-pickup-send---remote-signature.md
- **Context:** Initial task creation

### 2026-04-26T17:33:30Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.4)

- **Scan ID:** R-0f97a67a
- **Timestamp:** 2026-04-26T17:35:31Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-04-26T17:35:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
