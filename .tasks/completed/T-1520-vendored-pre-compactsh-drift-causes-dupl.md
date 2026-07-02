---
id: T-1520
name: "Vendored pre-compact.sh drift causes duplicate handover artefact (RCA: missing
  T-1476 dedup)"
description: >
  Vendored pre-compact.sh drift causes duplicate handover artefact (RCA: missing T-1476
  dedup)

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-26T21:35:01Z
last_update: '2026-06-11T22:23:50Z'
date_finished: 2026-04-26T21:38:52Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:50Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1520: Vendored pre-compact.sh drift causes duplicate handover artefact (RCA: missing T-1476 dedup)

## Context

`/compact` produced TWO handover commits in S-2026-0426-2325, and the source handover file `S-2026-0426-2325.md` has every section from "Inception Phases" onwards duplicated (260 vs 534, 481 vs 538, 530 vs 587, 600 vs 660, 636 vs 696, 646 vs 706).

**RCA:** PreCompact hook is registered at both:
1. Project-level `.claude/settings.json` → `/opt/.../bin/fw hook pre-compact` (uses framework SOURCE, has T-1476/T-1478 dual-layer dedup)
2. User-level `~/.claude/settings.json` → `.agentic-framework/bin/fw hook pre-compact` (uses VENDORED copy, missing dedup)

Diff `agents/context/pre-compact.sh` vs `.agentic-framework/agents/context/pre-compact.sh` confirms 39 lines (the entire flock + time-window dedup block) absent from vendored copy.

20+ vendored files across `lib/`, `agents/`, `web/blueprints/` show drift from source (`fw upgrade .` not run since pre-T-1476).

**Fix:** `fw upgrade .` syncs vendored copy from source. Re-test by triggering a manual handover and confirming no duplicate sections.

## Acceptance Criteria

### Agent
- [x] `diff agents/context/pre-compact.sh .agentic-framework/agents/context/pre-compact.sh` returns empty (no drift)
- [x] After fresh handover invocation, source handover file has each unique H2 section appearing exactly once
- [x] Truncated/cleaned LATEST.md has no duplicate sections

### Human
<!-- Optional verification by human. Agent ACs above are deterministic. -->

## Verification

diff -q agents/context/pre-compact.sh .agentic-framework/agents/context/pre-compact.sh
test "$(grep -c '^## Gaps Register' .context/handovers/LATEST.md)" = "1"
test "$(grep -c '^## Suggested First Action' .context/handovers/LATEST.md)" = "1"
test "$(grep -c '^## Recent Commits' .context/handovers/LATEST.md)" = "1"

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

### 2026-04-26T21:35:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1520-vendored-pre-compactsh-drift-causes-dupl.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3a87ddce
- **Timestamp:** 2026-06-02T14:58:02Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-26T21:38:52Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
