---
id: T-1636
name: "Orchestrator routing: refactor composite cache key to RoutingKey newtype before
  adding more dimensions"
description: >
  T-1064 supplementary review flagged the composite cache key 'method::task_type'
  (single string concat) as adequate now but a string-concat-hell trap once more routing
  dimensions land (priority class, tenant, etc.). Refactor to a RoutingKey newtype
  before that happens. Cross-repo: lives in /opt/termlink, dispatch via fw termlink
  dispatch --project /opt/termlink. Not blocking — future cleanup, captured horizon:later.
  Origin: T-1064 review notes 2026-04-30.

status: captured
workflow_type: refactor
owner: agent
horizon: later
tags: [from-T-1064, termlink, routing, cleanup]
components: []
related_tasks: [T-1064, T-1641]
created: 2026-05-01T10:44:54Z
last_update: '2026-05-28T22:54:09Z'
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
      F1: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 3
      effort: 4
    rationale: blast_radius=0 (no-signal); tier=3 (no-signal); effort=4 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1636: Orchestrator routing: refactor composite cache key to RoutingKey newtype before adding more dimensions

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

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

### 2026-05-01T10:44:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1636-orchestrator-routing-refactor-composite-.md
- **Context:** Initial task creation

## Scoping Note (added 2026-05-01 by /loop continuation)

Probed /opt/termlink today: the `routing_key` composite-string approach
lives in one file (`crates/termlink-hub/src/router.rs`, ~20 references
around lines 1104–1478) and is consumed as `&str` by `bypass.rs::registry::check`
and `route_cache.rs::lookup`. The persisted route cache stores keys as
strings on disk, so any newtype MUST serialize back to `method::task_type`
to avoid invalidating existing cache files.

**Original supplementary-review intent (T-1064):** "*if future routing
dimensions land (e.g. priority class, tenant), refactor to a `RoutingKey`
newtype before string-concat hell.*" Read carefully: this is an "at the
moment of adding the next dimension" refactor, **not** a pre-emptive one.
Doing it now (with only `method` + `task_type`) would be busywork and
might pick the wrong newtype shape because the next dimension's
constraints aren't visible yet.

**Disposition:** stays horizon:later. Promote to `now` (and split into
inception + build if needed) **only when** a new routing dimension is
being added to TermLink — at that point, the newtype shape will be
discoverable and the migration is justified.
