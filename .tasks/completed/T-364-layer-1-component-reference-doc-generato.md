---
id: T-364
name: "Layer 1: Component reference doc generator"
description: >
  Build fw docs generate [component-id|--all]: generates markdown reference page per
  component from card data, source headers, CLAUDE.md sections, episodic memory, learnings.
  Output to docs/generated/components/*.md. Mechanical extraction, no AI. See docs/reports/T-362-auto-doc-generation.md

status: work-completed
workflow_type: build
owner: human
horizon: null
components: [bin/fw]
related_tasks: []
created: 2026-03-08T22:03:27Z
last_update: '2026-06-11T22:24:19Z'
date_finished: 2026-03-08T22:17:24Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:19Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-364: Layer 1: Component reference doc generator

## Context

From T-362 GO. Design: `docs/reports/T-362-auto-doc-generation.md`.

## Acceptance Criteria

### Agent
- [x] `agents/docgen/generate_component.py` generates markdown from card data
- [x] `agents/docgen/generate-component.sh` wraps Python with --all and single-card modes
- [x] `fw docs --all` generates 127 reference docs in docs/generated/components/
- [x] `fw docs <card>` generates a single doc
- [x] Generated docs include: purpose, source header, CLAUDE.md excerpt, deps, used-by, related tasks/learnings
- [x] Code fence balance handled (no broken markdown from CLAUDE.md extraction)

### Human
- [x] [RUBBER-STAMP] Spot-check 3 generated docs for readability
  **Steps:**
  1. Read docs/generated/components/budget-gate.md
  2. Read docs/generated/components/agents-git-git.md
  3. Read docs/generated/components/agents-healing-healing.md
  **Expected:** Each has purpose, deps, source excerpt, and is well-formatted
  **If not:** Note which section is broken

## Verification

test -x agents/docgen/generate-component.sh
test -f agents/docgen/generate_component.py
test -f docs/generated/components/budget-gate.md
test -f docs/generated/components/agents-healing-healing.md
grep -q "docs" bin/fw
python3 -c "import glob; docs=glob.glob('docs/generated/components/*.md'); assert len(docs)>=120, f'Only {len(docs)} docs'; print(f'{len(docs)} docs generated')"

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

### 2026-03-08T22:03:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-364-layer-1-component-reference-doc-generato.md
- **Context:** Initial task creation

### 2026-03-08T22:10:28Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-08T22:17:24Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-03-10T22:04:13Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e598db16
- **Timestamp:** 2026-06-02T15:02:23Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
