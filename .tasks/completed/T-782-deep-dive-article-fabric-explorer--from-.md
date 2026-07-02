---
id: T-782
name: "Deep-dive article: Fabric Explorer — from static DAG to interactive architecture
  browser"
description: >
  Write a deep-dive article about the upgraded component browser (D3.js Fabric Explorer
  replacing Cytoscape). Covers architecture, interactions, path from evaluation to
  integration.

status: work-completed
workflow_type: build
owner: human
horizon: null
components: []
related_tasks: [T-726, T-730]
created: 2026-03-30T13:32:46Z
last_update: '2026-06-11T22:24:29Z'
date_finished: 2026-03-30T13:35:26Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:29Z'
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

# T-782: Deep-dive article: Fabric Explorer — from static DAG to interactive architecture browser

## Context

D3.js Fabric Explorer replaced Cytoscape in T-726 (inception) and T-730 (build). Article covers the upgrade journey.

## Acceptance Criteria

### Agent
- [x] Article written at `docs/articles/deep-dives/19-fabric-explorer.md`
- [x] Covers: problem, old vs new, architecture, key interactions, integration story
- [x] Committed

### Human
- [ ] [REVIEW] Voice and tone match writing style
  **Steps:**
  1. Read the article at `docs/deep-dives/18-fabric-explorer.md`
  2. Compare to published posts at blog.dimitrigeelen.com
  3. Check for anti-patterns: emojis, exclamation marks, "we", hedging
  **Expected:** Reads like a peer-to-peer governance discussion, not a product pitch
  **If not:** Note specific paragraphs for agent revision

## Verification

test -f docs/articles/deep-dives/19-fabric-explorer.md
test -s docs/articles/deep-dives/19-fabric-explorer.md

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Recommendation

**Recommendation:** DEFER

**Rationale:** Article exists at the right path, covers required topics, committed (3 mechanical Agent ACs check). Note: Human AC steps reference `docs/deep-dives/18-fabric-explorer.md` while Agent AC writes to `docs/articles/deep-dives/19-fabric-explorer.md` — minor path drift in the AC text but both numbers exist in the article series. Voice/tone match remains the Human's call (same class as T-446/T-470/T-505/T-706).

**Evidence:**
- docs/articles/deep-dives/19-fabric-explorer.md committed
- Covers problem, old vs new, architecture, key interactions, integration story
- Path discrepancy in Human AC steps (docs/deep-dives/18 vs docs/articles/deep-dives/19) — non-blocking, noted for human pass

## Updates

### 2026-03-30T13:32:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-782-deep-dive-article-fabric-explorer--from-.md
- **Context:** Initial task creation

### 2026-03-30T13:35:26Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-04-06T22:29:22Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-aed45425
- **Timestamp:** 2026-06-02T15:04:52Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
