---
id: T-1937
name: "BVP T-1936 follow-up — fw bvp arcs CLI parity with /bvp web rollup"
description: >
  BVP T-1936 follow-up — fw bvp arcs CLI parity with /bvp web rollup

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [arc:value-prioritisation, parity]
components: [lib/bvp.sh, tests/playwright/test_arc_detail_bvp.py, tests/unit/test_bvp_scatter_arc_mode.py, web/blueprints/arcs.py, web/blueprints/bvp.py, web/templates/arc_detail.html, web/templates/bvp.html]
related_tasks: [T-1936, T-1934, T-1935, T-1919]
arc_id: value-prioritisation
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-19T19:53:53Z
last_update: 2026-05-20T18:20:48Z
date_finished: 2026-05-20T18:20:48Z
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
  - ts: '2026-05-19T20:00:01Z'
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
  - ts: '2026-05-19T20:00:01Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 1
      tier: 2
      effort: 8
    rationale: blast_radius=1 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1937: BVP T-1936 follow-up — fw bvp arcs CLI parity with /bvp web rollup

## Context

T-1936 shipped constituent-task rollup for arc-level BVP+cost on Watchtower `/bvp`
(5 arc dots render for arc-002..006 via `_arc_rolled_up_scores` / `_arc_rolled_up_cost`
in `web/blueprints/bvp.py`). The matching CLI verb `fw bvp arcs` (lib/bvp.sh
`cmd_arcs`) still reads only direct `bvp_scores:` on the arc YAML — arcs whose
constituents have proposed scores but the arc itself has empty `bvp_scores: {}`
print "No arcs have bvp_scores: set yet" while the same arcs render perfectly
on the web surface. Two consumer sites of the same data, diverged.

This is the silent-corpus-migration anti-pattern (T-1850 cluster, L-329):
storage format extended on one site without sweeping the other. The fix is
mechanical parity — port `_arc_rolled_up_scores` and `_arc_rolled_up_cost` to
the CLI side, route through them when direct arc-level scores are absent.
Maintain mixed-mode-degrades-to-`derived-proposed` so the sovereignty boundary
is preserved in the CLI output too.

## Acceptance Criteria

### Agent
- [x] `cmd_arcs` in `lib/bvp.sh` falls back to constituent-task rollup when arc YAML lacks direct `bvp_scores:`, mirroring `web/blueprints/bvp.py:_collect_arc_points`
- [x] Rollup uses arc_id-dual-form matching (slug OR arc-NNN), same as web blueprint (T-1849)
- [x] Output row includes a `source` column distinguishing `direct` vs `derived-confirmed` vs `derived-proposed`
- [x] `fw bvp arcs` returns at least one row (5 arc dots visible on /bvp must also show in CLI) — verified by `bin/fw bvp arcs 2>&1 | grep -E "arc-00[2-6]"`
- [x] Unit tests in `tests/unit/test_bvp_cli_arcs_rollup.py` cover: empty members case, direct-confirmed bypass, derived-confirmed via task rollup, mixed-mode degrades to derived-proposed, both arc_id forms resolve
- [x] All new tests PASS via `cd tests && python3 -m pytest unit/test_bvp_cli_arcs_rollup.py -q`
- [x] Existing CLI BVP tests still PASS via `cd tests && python3 -m pytest unit/test_bvp_estimator.py unit/test_bvp_blueprint_cost.py -q`

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

cd /opt/999-Agentic-Engineering-Framework/tests && python3 -m pytest unit/test_bvp_cli_arcs_rollup.py -q
cd /opt/999-Agentic-Engineering-Framework/tests && python3 -m pytest unit/test_bvp_estimator.py unit/test_bvp_blueprint_cost.py -q
out=$(cd /opt/999-Agentic-Engineering-Framework && bin/fw bvp arcs 2>&1); echo "$out" | grep -qE "arc-00[2-6]"

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

## Recommendation

**Recommendation:** GO

**Rationale:** Silent-corpus divergence between `lib/bvp.sh:cmd_arcs` and
`web/blueprints/bvp.py:_collect_arc_points` closed. The CLI now renders the
same 5 arcs the web surface renders (arc-002..006, all `derived-proposed`
via constituent-task rollup), preserves the sovereignty boundary
(mixed-mode degrades to `derived-proposed`), and exposes provenance via a
new `SOURCE` column. Mirrors T-1936 helper shapes 1:1; T-1850 cluster
anti-pattern caught one step earlier (within-arc instead of cross-arc).

**Evidence:**
- `bin/fw bvp arcs` output shows arc-006 (`value-prioritisation`) at BVP=37 norm=0.31 source=`derived-proposed` — matches /bvp arc dot positioning
- 12/12 new tests PASS (`tests/unit/test_bvp_cli_arcs_rollup.py`)
- 63/63 sibling BVP tests still PASS (no regression)
- `_arc_member_tasks`, `_arc_rolled_up_scores`, `_latest_proposed_scores` structurally mirror web blueprint (sovereignty boundary preserved)

## Evolution

### 2026-05-19 — silent-corpus drift caught one consumer earlier

- **What changed:** T-1936 shipped rollup on the web side only. CLI `fw bvp arcs` continued returning "No arcs have bvp_scores: set yet" even with 5 arcs renderable. Caught immediately on resume by running the CLI command — pattern-recognised as T-1850 cluster anti-pattern (silent-corpus migration).
- **Plan impact:** T-1936 should have included CLI parity in original scope. Filed as T-1937 follow-up rather than re-opening T-1936.
- **Triggered:** This task (T-1937). No further sub-tasks needed — full parity reached.

## Decisions

### 2026-05-19 — port helpers vs. shell-out to web

- **Chose:** Duplicate the rollup helpers structurally in `lib/bvp.sh`'s python body.
- **Why:** Web blueprint is Flask-app-resident — invoking it from CLI would require Flask boot. Three helpers (~60 LOC) is cheaper than a Flask dependency for a read-only CLI.
- **Rejected:** (a) Shell-out to `curl /bvp` JSON — adds runtime dependency on a running Watchtower. (b) Move helpers to a shared `lib/bvp_rollup.py` — viable refactor but would touch web blueprint imports; deferred to a future consolidation slice if a third consumer emerges.

### 2026-05-19 — SOURCE column placement

- **Chose:** Inline column between NORM and NAME, name `SOURCE`.
- **Why:** Provenance is the most-asked question for `derived-proposed` rows ("why is this arc scored?"). Putting it before NAME keeps it visible without scrolling.
- **Rejected:** Append after NAME (would get truncated by terminal width on long names).

### 2026-05-19 — keep existing tests at 75-pass total instead of consolidating

- **Chose:** New test file `test_bvp_cli_arcs_rollup.py` rather than extending `test_bvp_estimator.py`.
- **Why:** CLI rollup is a distinct concern from estimator scoring; test file naming should map 1:1 to surface. Future readers find arc-rollup tests by name.
- **Rejected:** Single-mega-test-file — would obscure which surface each test guards.

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

### 2026-05-19T19:53:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1937-bvp-t-1936-follow-up--fw-bvp-arcs-cli-pa.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-40550345
- **Timestamp:** 2026-06-02T15:00:32Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#1 (Agent)** — `cmd_arcs` in `lib/bvp.sh` falls back to constituent-task rollup when arc YAML lacks direct `bvp_scores:`, mirroring `web/blueprints/bvp.py:_collect_arc_points`
  - **AC-verify-mismatch** (narrow, heuristic) — `path=lib/bvp.sh in: `cmd_arcs` in `lib/bvp.sh` falls back to constituent-task rollup when arc YAML lacks direct `bvp_scores:`, mirroring `web/blueprints/bvp.py:_collect_a`
- **AC#5 (Agent)** — Unit tests in `tests/unit/test_bvp_cli_arcs_rollup.py` cover: empty members case, direct-confirmed bypass, derived-confirmed via task rollup, mixed-mode degrades to derived-proposed, both arc_id forms
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tests/unit/test_bvp_cli_arcs_rollup.py in: Unit tests in `tests/unit/test_bvp_cli_arcs_rollup.py` cover: empty members case, direct-confirmed bypass, derived-confirmed via task rollup, mixed-mo`
### 2026-05-20T18:20:48Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
