---
id: T-2177
name: "Reviewer FAIL fix batch D — tighten skip-as-pass + swallowed-errors detectors
  against assert-absent idiom and --dry-run + assertion FPs"
description: >
  T-2173 / T-2174 §ACD pivot. Fresh-scan revealed 14/19 cached FAILs (Clusters 1+2)
  are detector FPs. skip-as-pass detector at lib/reviewer/static_scan.py:626-629 matches
  --dry-run textually, firing on legitimate simulation-with-assertion (cmd --dry-run
  | grep -q PATTERN); also matches --skip-X substrings inside grep PATTERN arguments.
  swallowed-errors detector matches || true unconditionally, firing on the canonical
  assert-pattern-absent idiom (cmd | grep -q PAT && exit 1 || true) where the || true
  is structurally necessary under set -e. Tighten heuristics to: (a) skip-as-pass
  requires --dry-run/--skip without a subsequent output assertion on the same line;
  (b) detect quoted-argument context to avoid matching --skip-X inside grep patterns;
  (c) swallowed-errors excludes the cmd && exit 1 || true assert-absent idiom; (d)
  preserve true positives (pytest --collect-only, pytest.mark.skip, @unittest.skip,
  plain || true at end of cmd). Ship as a single PR to lib/reviewer/static_scan.py
  + bats tests in tests/unit/. Expected: re-scanning Cluster 1+2 tasks (12 of 19 cached
  FAILs) drops them to PASS without breaking any currently-PASSing task.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [reviewer-quality, detector-fp, fail-fix, T-2173-child]
components: []
related_tasks: [T-2173, T-2174, T-2175, T-2176, T-1443]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-02T11:52:20Z
last_update: 2026-06-02T12:55:54Z
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
  - ts: '2026-06-02T12:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-02T12:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2177: Reviewer FAIL fix batch D — tighten skip-as-pass + swallowed-errors detectors against assert-absent idiom and --dry-run + assertion FPs

## Context

T-2173 / T-2174 §ACD pivot identified 14/19 cached FAILs (Clusters 1+2) as detector FPs from over-broad `--dry-run` / `--skip` / `|| true` regex matches at `lib/reviewer/static_scan.py:485-535` (swallowed-errors) and `:626-655` (skip-as-pass). The existing `_NEGATIVE_ASSERTION_RE` (T-1815) covers `&& exit N || true` but leaks adjacent idioms. The `_SKIP_AS_PASS_RE` has no equivalent suppression at all. This task closes both leaks structurally and adds bats coverage so the heuristics survive future regex edits. Origin context: [[feedback_cached_verdict_text_blind_spot]].

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `detect_skip_as_pass` suppresses findings when the same line carries an output assertion (`| grep`, `&& grep`, `| test`, `&& test`, `| cmp`, `&& cmp`, `| diff`, `&& diff`, `| jq`, `&& jq`, `| awk`, `| sed`). Rationale: a `--dry-run` followed by an assertion is simulation-with-check, not skip-as-pass. Empirical FP: T-2072 line 9 `out=$(bin/fw pickup promote-deferred --dry-run 2>&1); echo "$?" | grep -q "^0$"`. **Shipped:** `_OUTPUT_ASSERTION_RE` in `lib/reviewer/static_scan.py:639-641`; T-2072 fresh-scan no longer fires skip-as-pass.
- [x] `detect_skip_as_pass` suppresses findings when the matched token appears inside single or double quotes (textual argument to grep/awk/sed/etc., not a CLI flag). Pattern lifted from existing `_GREP_LITERAL_RE` in swallowed-errors (L-264-(a)) — same shape adapted for skip tokens. Empirical FP: T-1516 line 2 `grep -E 'manual fix.*--skip-sovereignty|deserves RCA'`. **Shipped:** `_QUOTED_SUBSTR_RE` strip-then-search at `lib/reviewer/static_scan.py:632-634`; T-1516 fresh-scan moves FAIL→PASS.
- [x] All existing true positives preserved: bare `pytest --collect-only`, `make test SKIP=true`, `pytest.mark.skip(...)`, `@unittest.skip(...)`, `--xfail`, plain `--skip` flag without assertion or quoting. **Verified:** all 4 pre-existing skip-as-pass tests pass; 4 new positive tests cover bare flags / collect-only / pytest.mark.skip / dry-run-with-devnull-only.
- [x] Unit tests in `tests/unit/test_reviewer_static_scan.py` cover each new suppression heuristic (positive: still fires on bare skip; negative: suppressed on assertion / quoted) AND each preserved TP — minimum 6 new test cases. **Shipped:** 9 new tests (5 negative for new suppression, 4 positive for TP regression guard). Full suite: 95 passed.
- [x] Fresh re-scan of T-1516 and T-2072 (`bin/fw reviewer T-XXX --no-write --json`) shows skip-as-pass no longer fires on those lines (FAIL→PASS or FAIL→CONCERN with no `skip-as-pass` in findings). **Verified:** T-1516 FAIL→PASS (only finding cleared); T-2072 FAIL→CONCERN (skip-as-pass cleared, mock-only-integration remains, unrelated).
- [x] Regression sweep: 50 randomly-sampled cached-PASS tasks re-scanned — zero now flag skip-as-pass. Additionally: 7 of 8 Cluster 1 tasks dropped skip-as-pass (T-1514, T-1516, T-1734, T-1738, T-1903, T-2072, T-2124); T-1594 retained — its `bin/fw mirror sync --dry-run --quiet` has no output assertion so the detector correctly preserves it as a real skip-as-pass (author needs to add an assertion, not detector to relax further).
- [x] Commit message references T-2177 and ships `lib/reviewer/static_scan.py` + `tests/unit/test_reviewer_static_scan.py` in a single commit (atomic detector + test pairing). **Verified at commit time.**


## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.

# Detector source edited
grep -q "skip-as-pass" lib/reviewer/static_scan.py
grep -q "_NEGATIVE_ASSERTION_RE" lib/reviewer/static_scan.py
# Unit tests pass (skip-as-pass + swallowed-errors)
out=$(python3 -m pytest tests/unit/test_reviewer_static_scan.py -k "skip_as_pass or swallowed" -q 2>&1); echo "$out" | grep -qE "passed"
# Full reviewer test suite still passes
out=$(python3 -m pytest tests/unit/test_reviewer_static_scan.py -q 2>&1); echo "$out" | grep -qE "passed"
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
# Single pipe only — no intermediate tail/awk/sed stages between capture and grep
# (T-2090): `echo "$out" | tail -3 | grep -q PAT` re-introduces the SIGPIPE risk
# the capture step closed off — the middle stage is what `grep -q` slams its
# stdin on. `echo "$out"` is small and immediate; grep scans the whole captured
# string anyway, so the tail-3 was cosmetic. Drop it: `echo "$out" | grep -q PAT`.
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

## Evolution

### 2026-06-02 — Empirical scope reduction from T-2174 §ACD framing

- **What changed:** T-2174 §ACD pivot framed Clusters 1 (skip-as-pass × 8) + 2 (swallowed-errors × 6) as "74% detector FPs requiring detector tightening". Fresh per-task scans at T-2177 filing-time confirm:
  - **Cluster 1 (skip-as-pass):** Real FPs. T-1516 (quoted `--skip-sovereignty` inside grep PATTERN) + T-2072 (`--dry-run` followed by `; ... | grep -q` output assertion). Detector tightening is the right fix.
  - **Cluster 2 (swallowed-errors):** Mostly stale-cache. T-1581 fresh-scan returns CONCERN (l387 only) — `_NEGATIVE_ASSERTION_RE` (T-1815) already suppresses the `&& exit N || true` assert-absent idiom correctly. T-1694 fresh-scan returns FAIL — but the `test -d X && cmd | grep || true` pattern is a **genuine TP** because `|| true` masks both precondition failure and grep no-match.
- **Plan impact:** Scope reduced to skip-as-pass tightening only. The swallowed-errors leg dissolves: existing detector is correct; stale-cache cases route to T-2176 (Fix C write-back), and T-1694-class genuine TPs were mis-classified in T-2174's analysis.
- **Triggered:** AC list halved (no swallowed-errors detector edit, no extended `_NEGATIVE_ASSERTION_RE` regex); Verification block trimmed; one task less to bats-cover. This is a second §ACD pivot — T-2174 already pivoted away from mechanical retro-edits; T-2177 now pivots further away from over-broad detector edits. Same lesson, finer grain. The honest answer here makes [[feedback_cached_verdict_text_blind_spot]] more rigorous: re-run the detector AND inspect each finding before recommending a fix class.

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

### 2026-06-02T11:52:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2177-reviewer-fail-fix-batch-d--tighten-skip-.md
- **Context:** Initial task creation

### 2026-06-02T12:55:54Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)
