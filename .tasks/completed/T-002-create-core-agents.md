---
id: T-002
name: Create core agents (task-create, audit)
description: >
  Build the first two agents for the framework: a task creation agent
  and an audit agent. Hybrid approach: bash scripts for mechanical parts,
  markdown definitions for intelligent parts, CLAUDE.md integration.
status: work-completed
workflow_type: build
owner: human
priority: high
tags: [agents, tooling, bootstrap]
agents:
  primary: claude-code
  supporting: []
created: 2026-02-13T14:00:00Z
last_update: '2026-06-11T22:23:35Z'
date_finished: 2026-02-13T14:30:00Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:35Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-002: Create core agents (task-create, audit)

## Design Record

Hybrid agent architecture:
1. **Bash scripts** — Mechanical operations (file creation, validation, git)
2. **Agent definitions** (markdown) — Intelligence layer (what to ask, how to judge)
3. **CLAUDE.md** — Integration point for Claude Code

This follows framework design: "Commands are the universal interface boundary" + "automate downward"

Agents to create:
- `task-create` — Guided task creation with ID generation, template population
- `audit` — Framework compliance checking against specs

## Specification Record

Acceptance criteria:
- [x] `agents/` directory structure exists
- [x] `task-create` agent: bash script + definition file
- [x] `audit` agent: bash script + definition file
- [x] Both agents tested and working
- [x] CLAUDE.md updated with agent invocation guidance
- [x] Agents documented in framework structure

## Test Files

- Manual testing during creation
- Run both agents and verify outputs

## Updates

### 2026-02-13 14:00 — task-created [claude-code]
- **Action:** Created T-002 to track agent creation work
- **Output:** .tasks/active/T-002-create-core-agents.md
- **Context:** Following audit that identified D3 Usability and D2 Reliability gaps. Agents provide structural solutions.

### 2026-02-13 14:30 — agents-created [claude-code]
- **Action:** Created both agents with hybrid architecture
- **Output:**
  - agents/task-create/AGENT.md + create-task.sh
  - agents/audit/AGENT.md + audit.sh
  - CLAUDE.md updated with Quick Reference
- **Context:** Both agents tested successfully. Audit shows 8 pass, 4 warn, 0 fail. Task creation generates proper IDs and files.

### 2026-02-13 14:30 — status-change: work-completed [claude-code]
- **Action:** All acceptance criteria met, marking complete
- **Output:** Task ready to move to completed/
- **Context:** First agents created. Addresses D3 (usability) and enables D2 (reliability via audit).

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a67afff2
- **Timestamp:** 2026-06-02T14:53:57Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
