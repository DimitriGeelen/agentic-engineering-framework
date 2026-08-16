---
id: T-105
name: Improve fw harvest for cross-project learning
description: >
  fw harvest (lib/harvest.sh) handles patterns, learnings, and decisions but misses
  the highest-value knowledge sources. Gaps to fix: (1) Episodic memory not harvested
  — .context/episodic/T-*.yaml files contain rich completed-task data (summary, outcomes,
  challenges, decisions, metrics). These are the densest knowledge artifacts and harvest.sh
  never touches them. Add harvest_episodics() that copies/anonymizes relevant episodics
  to framework. (2) Practices not harvested — .context/project/practices.yaml (graduated
  learnings with 3+ applications) never read. Add harvest_practices(). (3) CLAUDE.md
  improvements not harvested — project may extend CLAUDE.md with project-specific
  protocols that have framework value. Add diff detection between project CLAUDE.md
  and template to surface additions. (4) Consider adding provenance tracking — when
  a learning is harvested, record which project(s) it came from and how many projects
  have seen the same pattern (feeds graduation pipeline). INDEPENDENT — no dependencies
  on other tasks, can be done in parallel. Files: lib/harvest.sh.
status: work-completed
workflow_type: build
owner: agent
tags: [fw-harvest, cross-project, learning, episodic]
related_tasks: []
created: 2026-02-17T08:54:11Z
last_update: '2026-08-16T22:24:21Z'
date_finished:
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:38Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 4
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=4 
      (body:cross-machine); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:21Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 4
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=4 
      (body:cross-machine); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-105: Improve fw harvest for cross-project learning

## Context

[Link to design docs, specs, or predecessor tasks]

## Updates

### 2026-02-17T09:25:00Z — work-completed [claude-code]
- **Action:** Added 3 new harvest functions to lib/harvest.sh (343→509 lines):
  1. `harvest_episodics()` — copies T-*.yaml from project to framework with provenance
  2. `harvest_practices()` — harvests graduated practices, dedup by name
  3. `harvest_claude_additions()` — compares project CLAUDE.md sections against template
  Updated `do_harvest()` with new counters, calls, summary, and harvest log fields.
- **Output:** Syntax check passed (`bash -n`)
- **Context:** All 4 gaps addressed (episodic, practices, CLAUDE.md diff, provenance via harvest comments)

### 2026-02-17T08:54:11Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-105-improve-fw-harvest-for-cross-project-lea.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3c7972a1
- **Timestamp:** 2026-06-02T14:54:53Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
