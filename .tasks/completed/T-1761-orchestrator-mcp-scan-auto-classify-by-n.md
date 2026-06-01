---
id: T-1761
name: "orchestrator-mcp-scan auto-classify by naming convention (eliminate T-1755/T-1760
  toil)"
description: >
  orchestrator-mcp-scan auto-classify by naming convention (eliminate T-1755/T-1760
  toil)

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: ["drift-defense", "deferred"]
components: ["agents/audit/orchestrator-mcp-scan.sh"]
related_tasks: ["T-1755", "T-1760", "T-1646"]
arc_id: orchestrator-rethink
created: 2026-05-06T06:08:25Z
last_update: 2026-06-01T08:20:30Z
date_finished: 2026-06-01T08:20:30Z
bvp_scores_proposed:
  - ts: '2026-05-19T18:27:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 3
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=3 (body:portability-abstraction)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T20:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 3
      F1: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=3 (body:portability-abstraction); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 3
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=3 (body:portability-abstraction); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-29T23:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 3
      F1: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=3 (body:portability-abstraction); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-01T08:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 3
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=3 (body:portability-abstraction)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 1
      tier: 4
      effort: 4
    rationale: blast_radius=1 (no-signal); tier=4 (no-signal); effort=4 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1761: orchestrator-mcp-scan auto-classify by naming convention (eliminate T-1755/T-1760 toil)

## Context

Captured from T-1760 Evolution: a heuristic that auto-classifies new `termlink_agent_*` tools by read-shape naming convention would eliminate the T-1755/T-1760 batch-classification toil (3 tasks in one day). Deferred to inception because leverage is marginal at current cadence — implementation cost (~30-45 min, +tests) ≈ savings per batch (~15 min). Worth revisiting if upstream batch frequency increases or if a misclassification incident raises the cost of getting it wrong.

## Acceptance Criteria

### Agent
- [x] Inception: evaluate naming-convention heuristic vs marginal status quo; produce go/no-go in research artifact `docs/reports/T-1761-auto-classify-heuristic.md`

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

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

## Evolution

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
-->

## Recommendation

**Recommendation:** GO (revised 2026-05-31 — DEFER triggers fired)

**Rationale:** Both re-evaluation triggers from the original DEFER have crossed:
- **Cadence:** T-2073 was the 4th batch (13 days after T-1867 — under the 14-day trigger); T-2150 was the 5th batch (3 days after T-2073). Filing-time "pulse" assumption was wrong; cadence is sustained.
- **Cost ratio:** 7 batches × ~15 min ≈ **105 min** cumulative toil, vs ~30-45 min implementation. We have spent 2.3× the implementation cost on the toil.
- **Misclassification record:** 196 tools classified across 7 batches, zero `_typing`-style misclassifications. The naming convention is robust enough that manual review is mostly rubber-stamping.

See `docs/reports/T-1761-auto-classify-heuristic.md` §Re-evaluation for full analysis and three implementation shapes (auto-classify with `--apply` opt-in, ratchet command, hybrid namespace-scoped auto).

**Evidence:**
- Research artifact: `docs/reports/T-1761-auto-classify-heuristic.md` (§Re-evaluation appended 2026-05-31)
- Batches catalogued: T-1755, T-1755 f/u, T-1760, T-1867, T-2073, T-2073 f/u, T-2150 — 7 in 25 days
- Cumulative toil ≈ 105 min vs implementation estimate ≈ 30-45 min
- Audit just flipped WARN → PASS in T-2150's commit `b2f69e89` (most recent batch)

**Handoff:** Use `fw task review T-1761` for the human decision.

## Decision

**Decision**: GO

**Rationale**: Both re-evaluation triggers from the original DEFER have crossed:

**Date**: 2026-06-01T08:20:29Z

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

### 2026-05-06T06:08:25Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1761-orchestrator-mcp-scan-auto-classify-by-n.md
- **Context:** Initial task creation

### 2026-06-01T08:20:29Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Both re-evaluation triggers from the original DEFER have crossed:

## Reviewer Verdict (v1.5)

- **Scan ID:** R-fb69c1a9
- **Timestamp:** 2026-06-01T08:20:30Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-01T08:20:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
