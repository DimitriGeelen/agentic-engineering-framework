---
id: T-1998
name: "full-suite order-dependent unit reds — web.shared module-state pollution (3
  tests green in isolation, red in full suite)"
description: >
  full-suite order-dependent unit reds — web.shared module-state pollution (3 tests
  green in isolation, red in full suite)

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-22T21:24:48Z
last_update: 2026-05-22T21:29:47Z
date_finished: 2026-05-22T21:29:47Z
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
cost_estimate_proposed:
  - ts: '2026-05-22T21:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-22T21:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
---

# T-1998: full-suite order-dependent unit reds — web.shared module-state pollution (3 tests green in isolation, red in full suite)

## Context

A fresh full-suite run (`/tmp/full_suite.txt`) shows **3 failed, 1078 passed, 1 skipped** —
all three pass in isolation but fail in full-suite ordering (L-421 module-state pollution):

1. `test_arcs_routes.py::test_arcs_index_empty`
2. `test_file_route_extensions.py::test_route_serves_md_file`
3. `test_project_root_discovery.py::test_g069_stray_filesystem_root_marker_does_not_capture_framework`

T-1995/T-1996/T-1997 fixed the same *class* but the 5-file subset I ran masked the full-suite
ordering — these reds only surface across the whole `tests/unit/` collection. Root cause is
`importlib.reload(web.shared)` in route-test fixtures leaving `web.shared` module globals
(PROJECT_ROOT, and the rebound `_discover_project_root` function object) diverged from what
import-time `from web.shared import …` bindings in victim test modules captured.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Root cause of the full-suite order-dependence identified empirically (bisected polluter → victim), documented in `## RCA`
- [x] `test_project_root_discovery.py::test_g069_stray_filesystem_root_marker_does_not_capture_framework` passes in full-suite ordering
- [x] `test_arcs_routes.py::test_arcs_index_empty` passes in full-suite ordering
- [x] `test_file_route_extensions.py::test_route_serves_md_file` passes in full-suite ordering
- [x] Full unit suite is green: `python3 -m pytest tests/unit -q` reports 0 failed

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

# Full unit suite must be green (deterministic order — no randomizer installed).
# L-387 capture pattern: a passing run prints no "failed" token, so assert "passed" present AND "failed" absent.
out=$(python3 -m pytest tests/unit -q -p no:cacheprovider 2>&1); echo "$out" | tail -3 | grep -q "passed" && ! echo "$out" | tail -3 | grep -q "failed"

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

**Symptom:** Post-compaction `/resume` surfaced `/tmp/full_suite.txt` showing **3 failed, 1078
passed** (`test_arcs_index_empty`, `test_route_serves_md_file`, G-069 discovery test), contradicting
the prior session's belief that the suite was green.

**Root cause:** No current bug. `/tmp/full_suite.txt` mtime is **21:33:00**, which predates all three
fix commits — T-1995 (`0412fb33` @ 21:36), T-1996 (`b87fe682` @ 21:43), T-1997 (`1df1cbdf` @ 21:51).
The file is a stale capture of the *pre-fix* state. The current committed tree passes the full suite
deterministically: `python3 -m pytest tests/unit -q` → **1081 passed, 1 skipped, 0 failed**. Bisection
confirmed no live polluter survives (arcs_routes→g069 and orchestrator→g069 both green), and no
`pytest-randomly`/random-order plugin is installed, so collection order is deterministic — the green
is reproducible, not luck.

**Why structurally allowed:** Two compounding factors. (1) The prior session validated greenness on a
5-file subset, never on the full `tests/unit/` collection — so the earlier order-dependent reds were
real *at the time of the subset run* but were then fixed; the stale `/tmp` file just froze that moment.
(2) Post-compaction context recovery presented a `/tmp/*.txt` tool-result at face value with no freshness
check. A `/tmp` artifact carries no provenance; mtime-vs-fix-commit-timestamp is the only honest signal.

**Prevention:** Behavioural — when a resume/handover surfaces a `/tmp` test-output artifact, check its
mtime against recent fix-commit timestamps before treating it as current; never re-run the suite from
the committed tree as the source of truth. Captured as a learning (L-422). The deterministic-order
check (`pip list | grep randomly`) is the cheap guard against "green by luck" misreads.

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

### 2026-05-22T21:24:48Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1998-full-suite-order-dependent-unit-reds--we.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d16b3cd8
- **Timestamp:** 2026-05-22T21:30:27Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-22T21:29:47Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
