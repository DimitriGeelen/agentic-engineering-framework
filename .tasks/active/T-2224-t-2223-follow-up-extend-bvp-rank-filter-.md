---
id: T-2224
name: "T-2223 follow-up: extend bvp rank filter to also skip .tasks/completed/ dir
  (L-390 drift)"
description: >
  T-2223 filtered by status:work-completed but missed L-390 drift cases — tasks moved
  via git mv to .tasks/completed/ without updating frontmatter status field. T-2196
  is the evidence (in completed/, status:started-work). Fix: extend cmd_rank() loop
  skip-clause to also check path.parent.name == 'completed' when include_completed
  is False. Single AC + sibling test case to test_bvp_status_filter.py. ~5 LoC, ~10
  min.

status: started-work
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
created: 2026-06-05T23:26:19Z
last_update: 2026-06-06T06:04:33Z
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
  - ts: '2026-06-05T23:30:02Z'
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
  - ts: '2026-06-05T23:30:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2224: T-2223 follow-up: extend bvp rank filter to also skip .tasks/completed/ dir (L-390 drift)

## Context

T-2223 shipped the actionable-only default for `fw bvp` rank by filtering
`fm.get('status') == 'work-completed'`. The fresh HV-LC survey one session later
still showed T-2196 at #2 — because T-2196 lives in `.tasks/completed/` but its
frontmatter `status:` field is `started-work` (L-390 drift: tasks moved via
`git mv` without status update). Status-field filter doesn't catch directory
drift. This task closes the directory leg: when `include_completed=False`,
ALSO skip any task whose path lives under `.tasks/completed/`.

Same surface, same default, same opt-in flag — composes orthogonally with T-2223.

## Acceptance Criteria

### Agent
- [x] `cmd_rank()` skip-clause extended to OR-test `path.parent.name == 'completed'` alongside the status check, gated by `include_completed=False`.
- [x] `--include-completed` flag continues to restore directory-drift rows (parity with status-drift).
- [x] New unit test pins the directory leg: a task in `.tasks/completed/` with `status:started-work` is excluded by default and restored under `--include-completed`.
- [x] T-2223's existing 5 tests still pass (regression net — the status leg is untouched).
- [x] Reviewer PASS — `bin/fw reviewer T-2224` returns Overall PASS.

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

# T-2224 verification — directory leg.
pytest -q tests/unit/test_bvp_status_filter.py
pytest -q tests/unit/test_bvp_cli_rank_proposed.py
# AC#1 structural pin — the directory check is in source.
grep -q "path.parent.name == 'completed'" lib/bvp.sh
# Reviewer PASS — file-based L-387 safe pattern. Allows markdown bold
# (`**Overall:** PASS`) AND plain (`Overall: PASS`) rendering.
bin/fw reviewer T-2224 > /tmp/.t2224.reviewer 2>&1 && grep -qE "Overall:[*]* *PASS" /tmp/.t2224.reviewer

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

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Recommendation

- **Recommendation:** **GO** — directory leg of the bvp rank filter shipped; closes the L-390 drift class that T-2223 left open.
- **Rationale:** T-2223 stopped status-field work-completed pollution but the very next HV-LC survey still showed T-2196 at #2 because it lives in `.tasks/completed/` with frontmatter `status: started-work` (canonical L-390 case). The same `--include-completed` flag composes orthogonally — opt-in restores full archival sweep, default lists actionable rows only. ~5 LoC + 2 sibling test cases. All 5 acceptance criteria pass; reviewer R-004dc73d PASS with zero findings.
- **Evidence:**
  - `lib/bvp.sh:267-276` — skip-clause extended with `path.parent.name == 'completed'` OR-test, gated by `include_completed=False`.
  - `tests/unit/test_bvp_status_filter.py` — 7/7 PASS (5 status leg + 2 directory leg). Sibling test file unchanged (5/5 PASS, regression net intact). Combined: **15/15** across T-1938 + T-2223 + T-2224.
  - Live HV-LC survey before fix: T-2196 at #2 (BVP 98). After fix: T-2196 absent from default rank; restored at #6 under `--include-completed`.
  - Reviewer R-004dc73d — Overall PASS, Needs Human: no, Findings: none.
  - Sovereignty parity preserved: T-2223 (`--include-completed` for status leg) + T-2224 (same flag for directory leg) + T-1938 (`--include-proposed` for advisory scores) — three opt-ins, three orthogonal axes, single confirmed-actionable default.

## Updates

### 2026-06-05T23:26:19Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2224-t-2223-follow-up-extend-bvp-rank-filter-.md
- **Context:** Initial task creation

### 2026-06-06T06:04:33Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-004dc73d
- **Timestamp:** 2026-06-06T06:09:00Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
