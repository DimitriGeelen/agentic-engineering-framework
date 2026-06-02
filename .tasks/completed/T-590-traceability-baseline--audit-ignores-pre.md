---
id: T-590
name: "Traceability baseline — audit ignores pre-ingestion commits on imported projects"
description: >
  fw audit counts ALL commits for traceability, yielding 0% on ingested projects (e.g. OpenClaw with 2,847 upstream commits). Fix: traceability-baseline.yaml with baseline_commit SHA. Audit checks only commits after baseline. CLI: fw traceability baseline sets to current HEAD. Follows existing enforcement-baseline.sha256 pattern. Source: T-024 comparative analysis.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-23T21:50:53Z
last_update: 2026-03-24T21:06:24Z
date_finished: 2026-03-24T21:06:24Z
---

# T-590: Traceability baseline — audit ignores pre-ingestion commits on imported projects

## Context

Audit counts ALL commits for traceability, yielding 0% on ingested projects (e.g. OpenClaw: 2,847 upstream commits, 0 with T-XXX). Fix: baseline SHA file, audit only counts commits after baseline.

## Acceptance Criteria

### Agent
- [x] `.context/project/traceability-baseline` file stores baseline commit SHA
- [x] `fw traceability baseline` CLI command creates the baseline (sets to current HEAD)
- [x] Audit Section 3 (git traceability) uses baseline when present
- [x] Audit CTL-008 (hourly task reference check) uses baseline when present
- [x] Cron metrics Python code uses baseline when present
- [x] Without baseline file, audit behaves as before (backward compatible)

## Verification

grep -q "traceability-baseline" agents/audit/audit.sh
grep -q "traceability" bin/fw

## Decisions

## Updates

### 2026-03-23T21:50:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-590-traceability-baseline--audit-ignores-pre.md
- **Context:** Initial task creation

### 2026-03-24T21:00:50Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-24T21:06:24Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e08632dd
- **Timestamp:** 2026-06-02T15:03:45Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
