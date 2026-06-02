---
id: T-617
name: "Upgrade audit trail — record when/what in .framework.yaml and .context"
description: >
  fw upgrade has no audit trail. Cannot answer when upgrade ran or what version upgraded from. Add: timestamp in .framework.yaml, upgrade history in .context/audits/upgrades.yaml. From T-614 investigation.

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: [governance, upgrade, audit]
components: [lib/upgrade.sh]
related_tasks: []
created: 2026-03-25T20:17:23Z
last_update: 2026-03-26T15:47:28Z
date_finished: 2026-03-25T22:39:57Z
---

# T-617: Upgrade audit trail — record when/what in .framework.yaml and .context

## Context

`fw upgrade` has no audit trail. Cannot answer "when did this project last upgrade?" or "what version did it upgrade from?". Add `last_upgrade` timestamp and `upgraded_from` to `.framework.yaml`, plus append history to `.context/audits/upgrades.yaml`.

## Acceptance Criteria

### Agent
- [x] `lib/upgrade.sh` writes `last_upgrade` ISO timestamp to consumer `.framework.yaml` after successful upgrade
- [x] `lib/upgrade.sh` writes `upgraded_from` (previous version) to consumer `.framework.yaml`
- [x] `lib/upgrade.sh` appends entry to consumer `.context/audits/upgrades.yaml` with timestamp, from_version, to_version
- [x] `bash -n lib/upgrade.sh` passes (syntax check)
- [x] Dry-run mode does NOT write audit trail

### Human
- [x] [RUBBER-STAMP] Run `fw upgrade /opt/001-sprechloop --dry-run` and verify no `.framework.yaml` changes
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw upgrade /opt/001-sprechloop --dry-run`
  2. Check `.framework.yaml` was not modified: `cd /opt/001-sprechloop && git diff .framework.yaml`
  **Expected:** No diff — dry-run doesn't touch files
  **If not:** Check `lib/upgrade.sh` dry_run guard around audit trail writes

## Verification

bash -n lib/upgrade.sh
grep -q 'last_upgrade' lib/upgrade.sh
grep -q 'upgraded_from' lib/upgrade.sh
grep -q 'upgrades.yaml' lib/upgrade.sh

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

### 2026-03-25T20:17:23Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-617-upgrade-audit-trail--record-whenwhat-in-.md
- **Context:** Initial task creation

### 2026-03-25T22:20:32Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-25T22:39:57Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3c2f3bf8
- **Timestamp:** 2026-06-02T15:03:55Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#3 (Agent)** — `lib/upgrade.sh` appends entry to consumer `.context/audits/upgrades.yaml` with timestamp, from_version, to_version
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/audits/upgrades.yaml in: `lib/upgrade.sh` appends entry to consumer `.context/audits/upgrades.yaml` with timestamp, from_version, to_version`
