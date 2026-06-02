---
id: T-699
name: "fw stats — observability instrumentation via SQLite event logging"
description: >
  Log framework operations to local SQLite, expose fw stats command. Pattern from KCP (RFC-0017). Answers 'what do agents actually use?' No equivalent exists today. Score: 18/20 (D1:4 D2:5 D3:4 D4:5). Source: T-697 pattern harvest #10.

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: [observability, kcp-pattern]
components: []
related_tasks: []
created: 2026-03-29T08:57:13Z
last_update: 2026-04-13T06:23:25Z
date_finished: 2026-03-29T14:04:54Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-699: fw stats — observability instrumentation via SQLite event logging

## Context

KCP pattern harvest (T-697 #10) proposed SQLite-based event logging for framework operations. Scored 18/20. Would answer "what do agents actually use?" and provide operational telemetry. New subsystem — needs inception evaluation before build.

## Acceptance Criteria

### Agent
- [x] Current observability gaps inventoried
- [x] Alternatives evaluated (SQLite vs YAML append vs structured log)
- [x] Recommendation written with rationale

### Human
- [x] [REVIEW] Review findings and approve go/no-go decision
  **Steps:**
  1. Read `docs/reports/T-699-fw-stats.md`
  2. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-699 go|defer|no-go --rationale "your rationale"`
  **Expected:** Decision recorded
  **If not:** Ask for clarification

## Verification

# Task file has recommendation
grep -q "Recommendation" .tasks/active/T-699-fw-stats--observability-instrumentation-.md 2>/dev/null || grep -q "Recommendation" .tasks/completed/T-699-fw-stats--observability-instrumentation-.md 2>/dev/null

## Recommendation

- **Recommendation:** DEFER
- **Rationale:** The framework already has 5 observability stores with 2,400+ data points (607 metrics snapshots, 578 audit YAMLs, 666 episodic summaries, 426 handovers, 132 learnings). The "what do agents use?" question is answerable from git log in <1 second. SQLite would be a significant architectural shift (file-based → stateful database) for hypothetical queries nobody has asked. Zero demand from users or audits.
- **Evidence:**
  - Research artifact: `docs/reports/T-699-fw-stats.md`
  - 4 alternatives evaluated: SQLite, structured log, enhanced metrics-history, status quo
  - Command frequency derivable from git: `fw init` 33x, `fw upgrade` 10x, `fw doctor` 9x
  - Task creation rate derivable: 413 Feb, 644 Mar
  - SQLite instrumentation cost: ~30 commands need logging wrappers
- **Next steps after DEFER:** Revisit if Watchtower needs sub-second queries across 1000+ metrics snapshots

## Decisions

**Decision**: DEFER

**Rationale**: - Recommendation: DEFER
- Rationale: The framework already has 5 observability stores with 2,400+ data points (607 metrics snapshots, 578 audit YAMLs, 666 episodic summaries, 426 handovers, 132 lea...

**Date**: 2026-03-29T20:27:12Z

## Updates

### 2026-03-29T08:57:13Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-699-fw-stats--observability-instrumentation-.md
- **Context:** Initial task creation

### 2026-03-29T14:01:50Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-29T14:04:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-03-29T20:27:12Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** DEFER
- **Rationale:** - Recommendation: DEFER
- Rationale: The framework already has 5 observability stores with 2,400+ data points (607 metrics snapshots, 578 audit YAMLs, 666 episodic summaries, 426 handovers, 132 lea...

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d47f4743
- **Timestamp:** 2026-06-02T15:04:25Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `grep -q "Recommendation" .tasks/active/T-699-fw-stats--observability-instrumentation-.md 2>/dev/null || grep -q "Recommendation" .tasks/completed/T-699-fw-stats--observability-instrumentation-.md 2>/d`
