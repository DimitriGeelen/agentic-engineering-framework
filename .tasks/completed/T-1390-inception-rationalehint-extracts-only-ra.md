---
id: T-1390
name: "Inception rationale_hint extracts only Rationale body, not full Recommendation
  block (T-1388 B4)"
description: >
  Inception rationale_hint extracts only Rationale body, not full Recommendation block
  (T-1388 B4)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [web/blueprints/inception.py]
related_tasks: []
created: 2026-04-22T22:24:09Z
last_update: '2026-06-11T22:23:47Z'
date_finished: 2026-04-22T22:27:16Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:47Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1390: Inception rationale_hint extracts only Rationale body, not full Recommendation block (T-1388 B4)

## Context

B4 bugfix from T-1388 (F4). `web/blueprints/inception.py:334` constructs `rationale_hint` from the full `## Recommendation` section body (with `**bold**` stripped). When the human hits "Record Decision" without editing, the entire Recommendation blob — including "Recommendation: GO" header + "Rationale: ..." + "Evidence: ..." — becomes the stored rationale. Result: Decision Record shows "Rationale: Recommendation: GO\n\nRationale: ..." (double-prefix + entire evidence embedded).

Evidence: `docs/screenshots/T-1388-evidence-2-decided-locked.png` (T-1284 Decision Record shows the symptom).

Fix: extract only the content under `**Rationale:**` marker (up to the next `**...:**` marker or end of section). Falls back to the full section if no structured markers found (preserves old behavior for unstructured recommendations).

## Acceptance Criteria

### Agent
- [x] `rationale_hint` in `web/blueprints/inception.py` extracts only the `**Rationale:**` body when the `## Recommendation` section follows the structured format
- [x] Falls back to full section body when no `**Rationale:**` marker is present (no regression for free-form recommendations)
- [x] Evidence bullets are NOT included in the pre-populated rationale (live-verified on T-1388 — textarea contains only Rationale body, no "Recommendation: GO" prefix, no Evidence bullets)
- [x] 7 unit tests in `tests/web/test_inception_rationale_extraction.py` (structured, no-evidence, unstructured, empty, multi-paragraph, build-decomposition-stop)
- [x] Sanity-inverse verified: reverting the fix → ImportError (function genuinely new, not no-op)

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
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.

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

### 2026-04-22T22:24:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1390-inception-rationalehint-extracts-only-ra.md
- **Context:** Initial task creation

### 2026-04-22T22:27:16Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0627f84f
- **Timestamp:** 2026-06-02T14:57:09Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#1 (Agent)** — `rationale_hint` in `web/blueprints/inception.py` extracts only the `**Rationale:**` body when the `## Recommendation` section follows the structured format
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/blueprints/inception.py in: `rationale_hint` in `web/blueprints/inception.py` extracts only the `**Rationale:**` body when the `## Recommendation` section follows the structured `
- **AC#4 (Agent)** — 7 unit tests in `tests/web/test_inception_rationale_extraction.py` (structured, no-evidence, unstructured, empty, multi-paragraph, build-decomposition-stop)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tests/web/test_inception_rationale_extraction.py in: 7 unit tests in `tests/web/test_inception_rationale_extraction.py` (structured, no-evidence, unstructured, empty, multi-paragraph, build-decomposition`
