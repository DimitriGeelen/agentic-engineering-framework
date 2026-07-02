---
id: T-604
name: "Cron copy-on-change — git-tracked cron definitions with drift detection and
  sudo degradation"
description: >
  T-603 GO: Implement Option F. Move cron definitions to PROJECT_ROOT/.context/cron/
  as source of truth (git-tracked). fw audit schedule install copies to /etc/cron.d/
  with sudo. Audit detects drift (project ≠ installed) and prints remediation command.
  Graceful degradation: root→auto, sudo→auto, no-sudo→print command. Cross-platform:
  same pattern for cron.d, launchd, systemd timers. Related: T-603, T-602, T-559.

status: work-completed
workflow_type: build
owner: human
horizon: null
components: []
related_tasks: []
created: 2026-03-24T09:51:08Z
last_update: '2026-06-11T22:24:25Z'
date_finished: 2026-04-12T07:56:42Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:25Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=0 (no-signal); D2=4 (body:fw-audit-or-doctor); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-604: Cron copy-on-change — git-tracked cron definitions with drift detection and sudo degradation

## Context

T-603 GO (Option F). Cron definitions move from inline heredoc in audit.sh to git-tracked files in `PROJECT_ROOT/.context/cron/`. Install copies to `/etc/cron.d/` with sudo degradation. Audit detects drift.

## Acceptance Criteria

### Agent
- [x] Cron definition template exists at `.context/cron/agentic-audit.crontab` (git-tracked)
- [x] `schedule install` generates cron file in `.context/cron/` then copies to `/etc/cron.d/`
- [x] `schedule install` uses sudo when not root, prints manual command when sudo unavailable
- [x] `schedule status` shows drift warning when project file ≠ installed file
- [x] `schedule status` prints remediation command on drift
- [x] `schedule remove` removes installed copy, keeps project source file
- [x] Vendored copy synced (`.agentic-framework/agents/audit/audit.sh`)
- [x] Run `fw audit schedule install` and verify cron installed from project file (reclassified from Human RUBBER-STAMP per T-954)

### Human

## Verification

# Project cron source file exists
test -f .context/cron/agentic-audit.crontab
# Installed cron matches project source
diff -q .context/cron/agentic-audit.crontab /etc/cron.d/agentic-audit-999-agentic-engineering-framework
grep -q "schedule" agents/audit/audit.sh

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

### 2026-03-24T09:51:08Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-604-cron-copy-on-change--git-tracked-cron-de.md
- **Context:** Initial task creation

### 2026-03-24T09:52:42Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-27T17:34:07Z — status-update [task-update-agent]
- **Change:** horizon: now → next

### 2026-04-12T07:56:02Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-12T07:56:42Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-aa9fa87e
- **Timestamp:** 2026-06-02T15:03:50Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#7 (Agent)** — Vendored copy synced (`.agentic-framework/agents/audit/audit.sh`)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=agentic-framework/agents/audit/audit.sh in: Vendored copy synced (`.agentic-framework/agents/audit/audit.sh`)`
