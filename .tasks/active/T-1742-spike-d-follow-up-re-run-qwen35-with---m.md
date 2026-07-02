---
id: T-1742
name: "Spike D follow-up: re-run qwen35 with --max-tokens 4096 to recover 7 parse-fails"
description: >
  Spike D (T-1741) qwen35 produced 7 parse-fails out of 50 (14%) at max_tokens=2048
  — qwen35 is also a reasoning model, may exceed budget. Re-run only qwen35 with --max-tokens
  4096 against the T-1736 50-prompt benchmark, re-compute T-1741 metrics. Marginal
  off-ramp: even if all 7 parse-fails are correct, ceiling is ~+14pp accuracy; realistic
  +4-8pp. Doesn't fix DEFER F1 architectural ceiling. Filed captured/later per L-349
  — human triage decides whether to run.

status: captured
workflow_type: build
owner: agent
horizon: later
tags: [spike, follow-up]
components: []
related_tasks: [T-1741, T-1737]
arc_id: orchestrator-rethink
created: 2026-05-05T09:25:26Z
last_update: '2026-07-02T16:15:03Z'
date_finished:
bvp_scores_proposed:
  - ts: '2026-05-19T18:27:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T20:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F1: 1
    rationale: "D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); D4=2
      (body:env-class-handled); F1=1 (body/tag hits for 'F1': 1)"
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F1: 1
      F2: 0
    rationale: "D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); D4=2
      (body:env-class-handled); F1=1 (body/tag hits for 'F1': 1); F2=0 (no-signal)"
    rubric_sha: e4a00f38e801
  - ts: '2026-06-05T18:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T16:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F1: 1
      F2: 0
    rationale: "D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); D4=2
      (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F1=1
      (body/tag hits for 'F1': 1); F2=0 (no-signal)"
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:25Z'
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
  - ts: '2026-06-13T18:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-07-02T16:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F-AUTONOMY: 0
      audit_severity: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F-AUTONOMY=0 (no-signal); audit_severity=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 5
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=5 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1742: Spike D follow-up: re-run qwen35 with --max-tokens 4096 to recover 7 parse-fails

## Context

**Status: captured/later — likely OBSOLETE per L-355.**

Spike D (T-1741) found 7/50 parse-fails for qwen35 at max_tokens=2048. This task
proposes re-running with max_tokens=4096 to recover those. **L-355 (architectural
ceiling)** now indicates this is unlikely to be worthwhile: even if all 7
parse-fails are recovered as correct labels, the upper bound on qwen35 binary
accuracy is ~93% (43/50 + 7/7 = 50/50 in best case; realistically ~83-86%), still
short of the 90% binary threshold. The 3-class formulation has a separate DEFER F1
ceiling that more tokens cannot fix.

**Decision criteria for promotion:**
- Run only if a future agent specifically needs to know whether the 7 parse-fails
  were correct (e.g. to validate a benchmark fixture) — not as a path to clearing
  the threshold.
- If T-1744 GO promotes T-1727 as the orchestrator's first consumer, this spike
  becomes irrelevant and can be moved to NO-GO.
- If T-1744 NO-GO and a different LLM-augmented consumer is sought, this spike
  is still unlikely to identify a viable model — see L-355.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [ ] [First criterion]
- [ ] [Second criterion]

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

### 2026-05-05T09:25:26Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1742-spike-d-follow-up-re-run-qwen35-with---m.md
- **Context:** Initial task creation
