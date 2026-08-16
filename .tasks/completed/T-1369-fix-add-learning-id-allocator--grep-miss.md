---
id: T-1369
name: "fix add-learning ID allocator — grep misses indented id: entries, every new
  L-XXX collides with historical"
description: >
  fix add-learning ID allocator — grep misses indented id: entries, every new L-XXX
  collides with historical

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [C-002, tests/unit/add_learning_id_allocator.bats]
related_tasks: []
created: 2026-04-20T20:52:00Z
last_update: '2026-08-16T22:24:30Z'
date_finished: 2026-04-20T22:06:27Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:46Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 3
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=2 (body:learning-ref,body:concern-ref); D2=0 (no-signal); D3=0
      (no-signal); D4=0 (no-signal); F-RECALL=3 (body:fw-recall-or-memory-link);
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:30Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 3
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=2 (body:learning-ref,body:concern-ref); D2=0 (no-signal); D3=0
      (no-signal); D4=0 (no-signal); F-RECALL=3 (body:fw-recall-or-memory-link);
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-1369: fix add-learning ID allocator — grep misses indented id: entries, every new L-XXX collides with historical

## Context

`agents/context/lib/learning.sh:50` computes `max_id` by greping `^- id: L-` but the FIRST 234 entries in learnings.yaml use indented format (`  id: L-XXX` — the `id:` key is not the first key of the list item; `- application:` or `- context:` opens the item). grep misses all 234 old entries. Every recent addition collides with a historical ID.

Evidence: file has 264 list entries, ~30 unique IDs (234 duplicates). First-pass L-001..L-234 indented format; second-pass L-001..L-027 dash-prefix format re-uses every ID. My L-027 (T-1368) collides with an unrelated old entry from T-207.

Same pattern-class as G-052 (task-ID allocator race, T-1279 fixed). Here it's a grep-pattern bug, not a race.

## Acceptance Criteria

### Agent
- [x] `do_add_learning` greps both formats via `-E "^[- ]+id: PREFIX-"` — line 50 of agents/context/lib/learning.sh
- [x] Bats test tests/unit/add_learning_id_allocator.bats (3 cases: legacy-only, dash-only, mixed) — all pass; sanity-inverse-verified (reverting fix fails 2 of 3)
- [x] G-055 registered in concerns.yaml with status: mitigated
- [x] Live verification: `fw context add-learning` in framework repo now issues L-235 (next true max+1), confirming the fix in production

## Decisions

### 2026-04-20 — Accept historical L-ID duplicates
- **Chose:** leave the 234 historical L-ID duplicates in learnings.yaml as-is; document in G-055; ensure future IDs start from max+1
- **Why:** cross-references to collided L-IDs (L-001..L-027 range) exist in 20+ artifacts (tasks, handovers, reports, episodic files, controls.yaml). Renumbering would require touching all of them, dramatically expanding blast radius for no semantic benefit — the collisions are "harmless namespace pollution," not silently-wrong data
- **Rejected:** full renumbering via script — cost >> benefit; G-055 mitigation is sufficient for the go-forward state

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

# Shell commands that MUST pass before work-completed. One per line.
bats tests/unit/add_learning_id_allocator.bats
grep -qi "learning ID allocator" .context/project/concerns.yaml
# Verify the allocator change: both patterns matched
grep -qE 'grep -E "\^\[- \]\+id: \$' agents/context/lib/learning.sh

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

### 2026-04-20T20:52:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1369-fix-add-learning-id-allocator--grep-miss.md
- **Context:** Initial task creation

### 2026-04-20T22:06:27Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ad0aedd6
- **Timestamp:** 2026-06-02T14:57:00Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
