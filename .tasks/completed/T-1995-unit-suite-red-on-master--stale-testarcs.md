---
id: T-1995
name: "Unit suite red on master — stale test_arc_system + test_render_artefact_paths
  ordering pollution"
description: >
  bin/fw test unit is red on master, pre-existing & independent of any single feature
  (found during T-1988 arc-007 S1). (1) tests/unit/test_arc_system.py::test_arc_show_renders_metadata_and_tasks
  expects 'id: alpha' but arc system now emits 'id: arc-001' + 'slug: alpha' (T-1969
  dual-form drift — stale test). (2) tests/unit/test_render_artefact_paths.py passes
  in isolation (12/12) but 9 fail under cross-file ordering pollution in the web/render
  subset (a prior test mutates shared global state). Fix: update stale arc assertion;
  reset the module-level cache between render-path tests. Does NOT block S0/S1.

status: started-work
workflow_type: test
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-22T19:02:48Z
last_update: 2026-05-22T19:20:50Z
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── BVP scoring fields (T-1918, arc-006). See docs/reports/T-1915-bvp-inception.md for semantics. ──
# bvp_scores:                     # confirmed per-driver scores 0-5, set by `fw bvp confirm` (T-1924).
#                                 # Sovereignty boundary — only set after human or agent confirmation.
#                                 # Shape: {D1: <int 0-5>, D2: <int 0-5>, D3: <int 0-5>, D4: <int 0-5>, [<free-driver-id>: <int>]...}
# bvp_scores_proposed:            # estimator-proposed scores (T-1922 worker). Persists when ≥2 delta
#                                 # from bvp_scores: on any driver (M3 v2-delta). Shape: list of timestamped entries.
# cost_estimate:                  # F8 composite: 0.6×blast_radius + 0.3×tier + 0.1×effort.
#                                 # Q2 fallback: T-shirt S/M/L/XL mapped to 2/4/6/8 when blast_radius is not yet computable.
bvp_scores_proposed:
  - ts: '2026-05-22T19:05:40Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-22T19:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 1
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=1 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1995: Unit suite red on master — stale test_arc_system + test_render_artefact_paths ordering pollution

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `tests/unit/test_arc_system.py::test_arc_show_renders_metadata_and_tasks` updated to expect the current arc-display output (`id: arc-001` + `slug: alpha`, per T-1969 dual-form) and passes
- [x] `tests/unit/test_render_artefact_paths.py` passes inside the full `bin/fw test unit` run, not only in isolation — the cross-file ordering pollution is fixed (autouse fixture re-pins `web.shared.PROJECT_ROOT` per test)
- [x] Root-cause identified for the render-path pollution: which prior test mutates shared global state, and the fix prevents recurrence (not just reorders tests) — see ## RCA
- [x] Scope-root-not-symptom: the same T-1852 arc-close-precondition staleness lived in `test_arc_headline_demo.py` (8) + `test_arc_close_agent_gate.py` (7); both fixed (`--start` before close). All five touched files green together (49 passed)
- [x] Remaining post-fix reds are independent pre-existing failures (different subsystems, zero source changes by this task), triaged + filed as separate tasks — see ## Evolution

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.

     ── Prefix routing (T-1811, T-1878): default to [REVIEWER] if Expected is grep-able ──
     If your Expected clause is grep-able / file-exists / structural (a deterministic
     shell check), prefer [REVIEWER] — that AC should be an Agent AC with the reviewer
     command in `## Verification` instead of a Human AC here. Only keep [REVIEW] if
     verification genuinely needs human taste (tone, feel, layout rhythm).
     See CLAUDE.md §AC Classification Guidance for the conversion rule.

     [REVIEW] example (genuine human judgment):
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error

     [REVIEWER] example (static-scan-verifiable — convert to Agent AC + Verification):
       - [ ] [REVIEWER] Block message names both bypass mechanisms
         **Steps:**
         1. Run `bin/fw reviewer T-XXX`
         **Expected:** Verdict: PASS; no findings on `block-message-completeness`
         **If not:** Inspect hook block-message string and add missing mechanism
       Conversion: this AC should be moved to ### Agent and
       `bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"` added to ## Verification.
-->

## Verification

python3 -m pytest tests/unit/test_arc_system.py tests/unit/test_render_artefact_paths.py tests/unit/test_render_page_guard.py tests/unit/test_arc_headline_demo.py tests/unit/test_arc_close_agent_gate.py -q 2>&1 | tail -1 | grep -q "49 passed"

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# Pipefail/SIGPIPE hint (L-387): P-011 runs each command under `set -eo pipefail`.
# `cmd | grep -q PATTERN` exits 141 (SIGPIPE) when grep matches and closes stdin
# while the upstream is still writing — verification then "fails" even though
# the pattern was present. Safe pattern: capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Or:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
# Origin: L-387, captured 4× (T-1716, T-1838, T-1862, T-1863) before this hint.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

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

**Symptom:** `bin/fw test unit` red on master. Two visible classes at filing:
(1) `test_arc_system` assertions, (2) `test_render_artefact_paths` failing only
under cross-file ordering (12/12 in isolation).

**Root cause:**
- *Arc tests:* the arc subsystem evolved (T-1969 dual-form `id:`/`slug:`, T-1852
  draft→in-progress→closed state machine, T-1851 `constituent_tasks` deprecation)
  but the tests still asserted the pre-evolution shape. The same staleness lived
  at three sites, not one — `test_arc_system`, `test_arc_headline_demo`,
  `test_arc_close_agent_gate` — all create-then-close arcs that now bail at the
  `draft` state-machine check before reaching the gate they exercise.
- *Render tests:* `_auto_link_files` reads the module-global `web.shared.PROJECT_ROOT`
  at call time (existence-gated linkifier). Four tests
  (`test_arcs_routes`, `test_orchestrator_dispatch_substrate`,
  `test_orchestrator_outcome_quality`, `test_arc_membership_web_surfaces`) do
  `monkeypatch.setenv("PROJECT_ROOT", tmp); importlib.reload(web.shared)`.
  `monkeypatch` restores the *env var* at teardown but NOT the already-recomputed
  module global, so `web.shared.PROJECT_ROOT` is left dangling at a deleted tmp
  dir. The render test's import-time pin runs once at collection and can't recover.

**Why structurally allowed:** module-global state mutated via `importlib.reload`
is invisible to `monkeypatch`'s restore machinery — a teardown gap with no lint.
Tests pass in isolation, so the rot only shows under full-suite ordering and was
easy to ignore as "flaky".

**Prevention:** autouse fixture re-pins `web.shared.PROJECT_ROOT` per test in
both render-test modules (order-independent, not a reorder). Arc tests now assert
the canonical post-evolution shape and `--start` before close, so a future arc
schema change fails them loudly with a clear message.

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

### 2026-05-22 — scope grew from 2 files to 5 (one root cause), 3 reds carved out
- **What changed:** The "stale test_arc_system" headline was one of three sites
  sharing the T-1852 arc-close-precondition root cause. Fixing only the named
  file would have left `test_arc_headline_demo` (8) + `test_arc_close_agent_gate`
  (7) red — the exact T-1871 recursion the scope-root-not-symptom rule warns
  against. Fixed all three under this task (15 arc tests + 12 render + autouse).
- **Plan impact:** AC #4 ("`bin/fw test unit` exits 0 end-to-end") was written
  assuming the two named files were the only reds. Full-suite run after the fix:
  **3 failed, 1078 passed, 1 skipped**. The 3 remaining are independent,
  pre-existing, and in untouched subsystems (zero source changes by this task).
  AC #4 reworded to scope-honest; the green-suite goal moves to the carved-out tasks.
- **Triggered (one bug = one task — split by proven root cause, not by symptom count):**
  - `test_project_root_discovery::test_g069_stray_filesystem_root_marker_does_not_capture_framework`
    — well-diagnosed source regression: `_discover_project_root` climbs past
    `FRAMEWORK_ROOT` to a stray higher `.framework.yaml`, defeating the G-069
    path-isolation safety bound. Distinct (tests the discovery fn directly, no
    env var). → [[T-1996]]
  - `test_arcs_routes::test_arcs_index_empty` (empty-state not rendering) +
    `test_file_route_extensions::test_route_serves_md_file` (/file 404). Both use
    env-var `PROJECT_ROOT`+reload; not yet proven independent of each other —
    filed as one triage task to investigate a possible shared
    PROJECT_ROOT-after-reload cause and split if they diverge. → [[T-1997]]

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-22T19:02:48Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1995-unit-suite-red-on-master--stale-testarcs.md
- **Context:** Initial task creation

### 2026-05-22T19:05:39Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
