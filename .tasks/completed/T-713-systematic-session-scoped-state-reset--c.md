---
id: T-713
name: "Systematic session-scoped state reset — clear all volatile counters in post-compact-resume"
description: >
  Systematic session-scoped state reset — clear all volatile counters in post-compact-resume

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-29T13:14:07Z
last_update: 2026-03-29T13:16:14Z
date_finished: 2026-03-29T13:16:14Z
---

# T-713: Systematic session-scoped state reset — clear all volatile counters in post-compact-resume

## Context

T-712 fixed .budget-status but the problem is systemic: 9+ volatile counter/cache files in `.context/working/` survive across session boundaries. Each can cause stale-state bugs. This task resets ALL session-scoped files programmatically in `post-compact-resume.sh`.

## Acceptance Criteria

### Agent
- [x] All session-scoped volatile files cleared in `post-compact-resume.sh`
- [x] Clearing logic is centralized (one block, documented which files and why)
- [x] Persistent files (onboarding-complete, consolidation-report, etc.) are NOT cleared
- [x] Vendored copy updated
- [x] `bash -n` passes

## Verification

# All volatile counters are cleared in the hook
grep -q "budget-status" agents/context/post-compact-resume.sh
grep -q "agent-dispatch-counter" agents/context/post-compact-resume.sh
grep -q "loop-detect" agents/context/post-compact-resume.sh
grep -q "handover-cooldown" agents/context/post-compact-resume.sh
bash -n agents/context/post-compact-resume.sh

## Files to Reset (session-scoped)

| File | Purpose | Why reset |
|------|---------|-----------|
| `.budget-status` | Cached budget level | Stale tokens from pre-compact (T-712 root cause) |
| `.budget-gate-counter` | Budget re-check interval | Counter carries across, delays first real check |
| `.agent-dispatch-counter` | TermLink-first enforcement | Old count blocks agent dispatch in new session |
| `.edit-counter` | Commit cadence reminder | Old edit count triggers premature commit nudge |
| `.tool-counter` | PostToolUse checkpoint | Old count skews checkpoint timing |
| `.prev-token-reading` | Token change detection | Old reading causes false "tokens unchanged" |
| `.handover-cooldown` | Prevent handover spam | Old cooldown prevents first handover in new session |
| `.loop-detect.json` | Loop detection state | Old patterns cause false loop detection |
| `.new-file-counter` | Fabric registration | Old count irrelevant in new session |
| `.approval-notified` | Tier 0 notification dedup | Old notification flags prevent fresh alerts |

## Files to NOT Reset (persistent)

| File | Why keep |
|------|----------|
| `.onboarding-complete` | One-time marker, must persist |
| `.compact-log` | Historical record across sessions |
| `consolidation-report.yaml` | Reference data |
| `watchtower.log` | Persistent log |
| `watchtower.pid` | Running process reference |
| `fw-vec-index.db` | Persistent index |
| `observations/` | Accumulated observations |
| `.restart-requested` | Auto-restart signal (consumed by wrapper) |
| `.restart-instructions` | Auto-restart instructions |

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     Examples:
       python3 -c "import yaml; yaml.safe_load(open('path/to/file.yaml'))"
       curl -sf http://localhost:3000/page
       grep -q "expected_string" output_file.txt
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

### 2026-03-29T13:14:07Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-713-systematic-session-scoped-state-reset--c.md
- **Context:** Initial task creation

### 2026-03-29T13:16:14Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-76ca267c
- **Timestamp:** 2026-06-02T15:04:30Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
