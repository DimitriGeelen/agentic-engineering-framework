---
id: T-1996
name: "G-069 regression: _discover_project_root climbs past FRAMEWORK_ROOT to stray
  .framework.yaml"
description: >
  test_project_root_discovery::test_g069_stray_filesystem_root_marker_does_not_capture_framework
  FAILS on master. _discover_project_root(fake_framework) returns the tmp dir above
  FRAMEWORK_ROOT when a stray .framework.yaml is planted there, instead of stopping
  at the FRAMEWORK_ROOT bound. This defeats the G-069 path-isolation safety mechanism
  (the bound that prevents discovery returning Path('/') or capturing a higher project).
  Source bug in web/shared.py _discover_project_root walk. Found during T-1995 full-suite
  triage; pre-existing, source change needed.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-22T19:35:47Z
last_update: '2026-08-16T22:24:51Z'
date_finished: 2026-05-22T21:51:02+02:00
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
  - ts: '2026-05-22T19:37:16Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:05Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 3
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=3 
      (body:fw-recall-or-memory-link); F-ORCH=0 (no-signal); F3=0 (no-signal); 
      F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:51Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 3
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=3 
      (body:fw-recall-or-memory-link); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-29T09:45:04Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1996: G-069 regression: _discover_project_root climbs past FRAMEWORK_ROOT to stray .framework.yaml

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

<!-- RE-SCOPED after investigation (see ## RCA): the G-069 bound is NOT broken.
     _discover_project_root returns None correctly in isolation. The failure is
     test-isolation pollution — same class as T-1995's render-path fix. -->
### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Root cause written to `## RCA`: `test_orchestrator_workflow_coverage.py` does `del sys.modules["web.shared"]` + reimport, REPLACING the module object. The G-069 test's import-time-bound `_discover_project_root` then reads the orphaned old module while `patch("web.shared.FRAMEWORK_ROOT")` targets the new one — they desync, so the bound's `cur == framework_root` never matches and the walk climbs to the stray marker
- [x] Fix the polluter: `test_orchestrator_workflow_coverage.py` uses `importlib.reload` (reuses the module object, like every sibling reload test) instead of `del sys.modules` (which replaces it)
- [x] `tests/unit/test_project_root_discovery.py::test_g069_stray_filesystem_root_marker_does_not_capture_framework` passes in the full `bin/fw test unit` run, not just isolation (full suite: 2 failed, 1079 passed — was 3; G-069 now green)
- [x] No regression: `test_orchestrator_workflow_coverage.py` itself stays green (10 passed), and the rest of `test_project_root_discovery.py` stays green (7 passed)
- [x] Confirmed this is a test-harness fix, NOT a source change to `web/shared.py` — the G-069 safety bound works correctly (verified in isolation: `_discover_project_root` returns `None`)

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

python3 -m pytest tests/unit/test_orchestrator_workflow_coverage.py "tests/unit/test_project_root_discovery.py::test_g069_stray_filesystem_root_marker_does_not_capture_framework" -q 2>&1 | tail -1 | grep -q "11 passed"

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

**Symptom:** `test_project_root_discovery.py::test_g069_stray_filesystem_root_marker_does_not_capture_framework`
red in the full `bin/fw test unit` run; green in isolation. Filed (wrongly) as a
G-069 *source* regression in `_discover_project_root`.

**Root cause:** NOT a source bug — the G-069 bound is correct (`_discover_project_root`
returns `None` in isolation; traced live). The failure is test-isolation pollution.
`test_orchestrator_workflow_coverage.py` (sorts alphabetically before
`test_project_root_discovery`) refreshed its constants with
`del sys.modules["web.shared"]` + reimport. Unlike `importlib.reload` (which
re-executes the module body in the *same* module object), `del`+reimport creates a
**new** module object. The discovery test binds `_discover_project_root` at its own
import time (from the *old* module). After the polluter ran, `patch("web.shared.FRAMEWORK_ROOT", …)`
patched the *new* module in `sys.modules`, but the test called the old function whose
`__globals__` is the old module dict — so it read the real unpatched `FRAMEWORK_ROOT`,
`in_framework`/`cur == framework_root` never matched, and the walk climbed to the
stray marker.

**Why structurally allowed:** `del sys.modules[mod]` is invisible to both pytest's
fixture teardown and `monkeypatch` restore; nothing flags a test that swaps out a
widely-imported module object. Victims only surface under full-suite ordering and look
like flakes. Same family as T-1995's render-path pollution (there: a dangling module
*global*; here: a swapped module *object*).

**Prevention:** the polluter now uses `importlib.reload` (module identity preserved),
matching every sibling reload test (`test_arcs_routes`, `test_orchestrator_dispatch_substrate`).
Broader class — `del sys.modules["web.*"]` in a test fixture — is a candidate for a
future lint/grep guard ([[L-420]] candidate); deferred, single instance found.

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

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-22T19:35:47Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1996-g-069-regression-discoverprojectroot-cli.md
- **Context:** Initial task creation

### 2026-05-22T19:37:16Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2ba3d4c2
- **Timestamp:** 2026-06-02T15:00:46Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#5 (Agent)** — Confirmed this is a test-harness fix, NOT a source change to `web/shared.py` — the G-069 safety bound works correctly (verified in isolation: `_discover_project_root` returns `None`)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/shared.py in: Confirmed this is a test-harness fix, NOT a source change to `web/shared.py` — the G-069 safety bound works correctly (verified in isolation: `_discov`

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `python3 -m pytest tests/unit/test_orchestrator_workflow_coverage.py "tests/unit/test_project_root_discovery.py::test_g069_stray_filesystem_root_marker_does_not_capture_framework" -q 2>&1 | tail -1 | g`
