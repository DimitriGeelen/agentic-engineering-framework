---
id: T-241
name: "Wire discovery findings into session-start and Watchtower"
description: >
  Wire discovery findings into three surfacing channels: (1) session-start context
  injection via resume agent, (2) Watchtower discoveries page with trend charts,
  (3) cron output for standalone monitoring. Addresses GAP-T7 (no session-start
  surfacing) and GAP-T8 (no visual trends). Research: docs/reports/T-200-discovery-layer-design.md

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [discovery, surfacing, watchtower]
components: []
related_tasks: [T-200, T-194, T-238, T-239, T-240]
created: 2026-02-21T23:39:01Z
last_update: 2026-02-22T06:45:49Z
date_finished: null
---

# T-241: Wire discovery findings into session-start and Watchtower

## Context

Discoveries are useless if they don't reach the human. This task wires findings from T-239 (omission) and T-240 (trends) into three surfacing channels, addressing GAP-T7 (session-start blind to trends) and GAP-T8 (no visual trends in Watchtower).

**Research:** `docs/reports/T-200-discovery-layer-design.md` — see "Phase 1a-ext: Temporal Infrastructure Gap Analysis"
**Origin:** T-194 Phase 4 inception → T-200 GO decision
**Depends on:** T-239 (omission discoveries), T-240 (trend discoveries)

### Channel 1: Session-Start Injection (GAP-T7)
- `resume.sh` and/or `SessionStart` hook reads latest discovery findings
- Injects 2-3 line summary into session context: "3 discoveries: episodic quality at 58% [TODO], T-227 human review 48h old, velocity declining"
- Only surfaces WARN/FAIL level findings (not INFO)

### Channel 2: Watchtower Discoveries Page (GAP-T8)
- New page or section at `:3000/discoveries` or integrated into existing dashboard
- Shows current findings from all discovery jobs (D1-D8)
- Time-series sparklines/charts for key metrics (velocity, audit health, episodic quality) using metrics-history.yaml
- Color-coded severity (green/yellow/red)

### Channel 3: Cron Output
- Discovery findings written to `.context/audits/discoveries/LATEST.yaml`
- Same structured YAML format as audit findings
- Readable by `fw audit` and by session-start injection

## Acceptance Criteria

### Agent
- [x] `resume.sh` or SessionStart hook reads discovery findings and injects summary
- [x] Discovery findings page accessible in Watchtower (`:3000/discoveries` or equivalent)
- [x] At least one time-series visualization (sparkline or chart) using metrics-history.yaml
- [x] Discovery findings persisted to `.context/audits/discoveries/LATEST.yaml`
- [x] Only WARN/FAIL findings surfaced at session-start (not INFO)
- [x] Existing tests pass

### Human
- [ ] Discovery page layout and readability at :3000
- [ ] Session-start summary is concise and actionable

## Verification

python3 -c "import yaml; yaml.safe_load(open('.context/audits/discoveries/LATEST.yaml'))"
curl -sf http://localhost:3000/discoveries
grep -q "discoveries" agents/context/post-compact-resume.sh
grep -q "Discovery Findings" agents/resume/resume.sh

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

### 2026-02-21T23:39:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-241-wire-discovery-findings-into-session-sta.md
- **Context:** Initial task creation

### 2026-02-22T06:45:24Z — status-update [task-update-agent]
- **Change:** horizon: later → now

### 2026-02-22T06:45:49Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
