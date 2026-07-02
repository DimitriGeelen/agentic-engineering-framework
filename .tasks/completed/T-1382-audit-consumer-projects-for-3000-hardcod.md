---
id: T-1382
name: "Audit consumer projects for :3000 hardcodes — T-1376 recurrence prevention
  cross-consumer sweep"
description: >
  Audit consumer projects for :3000 hardcodes — T-1376 recurrence prevention cross-consumer
  sweep

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-22T19:38:02Z
last_update: '2026-06-11T22:23:46Z'
date_finished: 2026-04-22T19:41:04Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:46Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=0
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-1382: Audit consumer projects for :3000 hardcodes — T-1376 recurrence prevention cross-consumer sweep

## Context

Post T-1380 B5, audit whether consumer projects still teach the `:3000` hardcode. Found in /003-NTB-ATC-Plugin and /opt/002-Claude-Partner-Network: `.claude/commands/resume.md` + `CLAUDE.md` contain the pre-T-1378 templates. `lib/upgrade.sh:694-709` explicitly skips existing `resume.md` (only regenerates via `fw init --force`), so the fix does not propagate on normal upgrade. This is the identified gap.

## Acceptance Criteria

### Agent
- [x] Audit report `docs/reports/T-1382-consumer-3000-audit.md` exists documenting findings for each consumer (what's stale, why, blast radius)
- [x] Gap registered (G-056) in `.context/project/concerns.yaml` — `lib/upgrade.sh` does not propagate template updates to existing consumer `.claude/commands/resume.md`
- [x] Report identifies which fixes propagate automatically (vendored `.agentic-framework/*`) vs. manual (consumer CLAUDE.md, resume.md)
- [x] Report names follow-up candidates: (a) patch upgrade.sh to resync resume.md when template changed, (b) send pickups to each consumer TermLink agent

## Verification

test -f docs/reports/T-1382-consumer-3000-audit.md
grep -q 'lib/upgrade.sh' docs/reports/T-1382-consumer-3000-audit.md
grep -qE 'upgrade.*resume\.md|resume\.md.*upgrade' .context/project/concerns.yaml

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

### 2026-04-22T19:38:02Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1382-audit-consumer-projects-for-3000-hardcod.md
- **Context:** Initial task creation

### 2026-04-22T19:41:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-fd2d248a
- **Timestamp:** 2026-06-02T14:57:05Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
