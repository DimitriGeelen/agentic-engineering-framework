---
id: T-1526
name: "Inception decision rewriter swallows H3 entries below ## Decision (T-1519 sister
  bug)"
description: >
  Inception decision rewriter swallows H3 entries below ## Decision (T-1519 sister
  bug)

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [lib/inception.sh]
related_tasks: []
created: 2026-04-26T22:01:34Z
last_update: '2026-06-11T22:23:50Z'
date_finished: 2026-04-26T22:04:14Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:50Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1526: Inception decision rewriter swallows H3 entries below ## Decision (T-1519 sister bug)

## Context

`lib/inception.sh:431-453` rewrites the `## Decision` section line-by-line. The state machine sets `in_decision = True` on `## Decision` and only exits on a subsequent line that `startswith('## ')` (H2). Any `### timestamp` H3 entries appearing while `in_decision` is True get SWALLOWED.

This is the same shape as T-1519 (verdict regex `(?=^## |\Z)` ate `### Updates` entries below verdict). The narrow surface for this one is malformed tasks lacking `## Updates` — where update-task.sh appends `### timestamp` entries at EOF after `## Decision`. Standard templates always include `## Updates`, so the field-impact is small, but the class is identical: terminate at the wrong heading depth and lose data on rewrite.

Fix: exit `in_decision` on any heading H2 or deeper (`re.match(r'^#{2,} ', line)` or equivalent shell-side check). Decision-block bodies only contain `**Bold**` lines, not headings, so widening the terminator never breaks duplicate-collapse.

## Acceptance Criteria

### Agent
- [x] Decision rewriter exits `in_decision` on any H2-or-deeper heading (H2 OR H3 OR more)
- [x] Duplicate `## Decision` collapse still works (test: two `## Decision` blocks → one block kept)
- [x] Synthetic test: task with `## Decision` then `### 2026-04-26 — entry` then EOF → after re-decide, the `### entry` H3 is preserved

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
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
python3 -m pytest tests/unit/test_inception_decide_preserves_h3.py -q

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

### 2026-04-26T22:01:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1526-inception-decision-rewriter-swallows-h3-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-fc1a23dc
- **Timestamp:** 2026-06-02T14:58:05Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-26T22:04:14Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
