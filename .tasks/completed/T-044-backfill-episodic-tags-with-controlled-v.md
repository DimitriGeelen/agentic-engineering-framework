---
id: T-044
name: Backfill episodic tags with controlled vocabulary
description: >
  One agent pass over 42 episodic files to normalize tags to controlled vocabulary.
  Four dimensions: component (context-fabric, audit, git-agent, healing-loop, cli,
  observation, handover, resume, metrics), directive (D1-D4), activity (bootstrap,
  experiment, fix, refactor, specification, integration), practice (P-001 through
  P-007). Also standardize episodic schema: backfill missing fields (enrichment_status,
  created, completed, duration_days, source_file, generated_by) on older files. Design
  authority: 025-ArtifactDiscovery.md. Relevant sections: Q4 Tag Backfill, Design
  Decision Task Hierarchy (controlled tag vocabulary).
status: work-completed
workflow_type: build
owner: claude-code
priority: medium
tags: []
agents:
  primary:
  supporting: []
created: 2026-02-14T11:33:56Z
last_update: '2026-08-16T22:24:17Z'
date_finished: 2026-02-14T12:27:34Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:36Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:17Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=1 (body:episodic-only); F-AUTONOMY=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-044: Backfill episodic tags with controlled vocabulary

## Design Record

**Design authority:** [025-ArtifactDiscovery.md](../../025-ArtifactDiscovery.md)
**Relevant sections:** Q4 Tag Backfill, Design Decision Task Hierarchy (controlled tag vocabulary)

**Key decisions:**
- Backfill episodic files only — task frontmatter is operational record, leave as-is
- Four tag dimensions: component, directive, activity, practice
- Component tags: context-fabric, audit, git-agent, healing-loop, cli, observation, handover, resume, metrics
- Directive tags: D1-antifragility, D2-reliability, D3-usability, D4-portability
- Activity tags: bootstrap, experiment, fix, refactor, specification, integration
- Practice tags: P-001 through P-007
- Also standardize episodic schema (backfill missing fields on older files)

## Specification Record

### Acceptance Criteria
- [ ] All 42 episodic files have tags normalized to controlled vocabulary
- [ ] Every episodic file has at least one component tag and one directive tag
- [ ] Missing fields backfilled: enrichment_status, created, completed, duration_days, source_file, generated_by
- [ ] No episodic files broken by the changes (YAML still valid)
- [ ] Tag vocabulary documented (in design doc or separate reference)

## Test Files

[References to test scripts and test artifacts]

## Updates

### 2026-02-14T11:33:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-044-backfill-episodic-tags-with-controlled-v.md
- **Context:** Initial task creation

### 2026-02-14T12:27:25Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-14T12:27:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-bad770aa
- **Timestamp:** 2026-06-02T14:54:13Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
