---
id: T-2223
name: "fw bvp rank includes work-completed tasks — pollutes HV-LC actionable survey"
description: >
  fw bvp --quadrant hv-lc surfaces work-completed tasks (T-2074 completed, T-2002
  active/status:work-completed) alongside actionable ones. Operator standing HV-LC
  directive is unreliable. Fix: cmd_rank() skips status:work-completed by default;
  --include-completed restores legacy behaviour. Origin: discovered during S-2026-0606-01XX
  HV-LC survey when 5/15 top candidates turned out to be already shipped.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [lib/bvp.sh]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-05T23:04:04Z
last_update: '2026-08-16T22:24:57Z'
date_finished: 2026-06-05T23:17:13Z
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
  - ts: '2026-06-05T23:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:11Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:57Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-05T23:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2223: fw bvp rank includes work-completed tasks — pollutes HV-LC actionable survey

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `cmd_rank()` in `lib/bvp.sh` accepts `include_completed=False` parameter; when False, rows where `fm.get('status') == 'work-completed'` are skipped before BVP/cost computation (sovereignty default: actionable-only).
- [x] `main()` parses `--include-completed` as a positional flag (same pattern as `--include-proposed`) and threads it into both `cmd_rank()` call sites (bare `fw bvp` and `fw bvp --quadrant <Q>`).
- [x] `usage()` documents `--include-completed` under the rank surface and notes the actionable-only default.
- [x] `tests/unit/test_bvp_status_filter.py` pins the contract: two synthetic confirmed-scored tasks (one `started-work`, one `work-completed`); default rank excludes the work-completed row; `--include-completed` includes it. Existing `test_bvp_cli_rank_proposed.py` regression suite still passes.
- [x] Live evidence: `bin/fw bvp --include-proposed` against this repo no longer surfaces a known-completed task (e.g. T-2074); `bin/fw bvp --include-proposed --include-completed` does include it.

<!-- Human ACs omitted — purely mechanical CLI behaviour change; no render surface
     touched (P-013 N/A); no operator-judgment dimension. AC #4 + #5 pin the
     contract structurally and #5 walks the live evidence path. -->

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
pytest -q tests/unit/test_bvp_status_filter.py
pytest -q tests/unit/test_bvp_cli_rank_proposed.py
# AC#1 structural pin — the new parameter shape is in source.
grep -q "include_completed=False" lib/bvp.sh
grep -q "fm.get('status') == 'work-completed'" lib/bvp.sh
# Live evidence — uses the file-based L-387 safe pattern (`cmd > /tmp/.out`
# then `grep -q PATTERN /tmp/.out`). Pure-shell glob match was too loose
# (T-2119 name "T-2074 followup..." matched the glob); ^-anchored grep on a
# file is the only way to bind the match to column 1. T-2074 is the canonical
# known-completed task (in completed/ since 2026-05-28).
bin/fw bvp --include-proposed > /tmp/.t2223.bvp.default 2>&1 && ! grep -q "^T-2074 " /tmp/.t2223.bvp.default
bin/fw bvp --include-proposed --include-completed > /tmp/.t2223.bvp.flag 2>&1 && grep -q "^T-2074 " /tmp/.t2223.bvp.flag
# Reviewer PASS — file-based L-387 safe pattern. Pattern allows markdown
# bold (`**Overall:** PASS`) AND plain (`Overall: PASS`) verdict rendering.
bin/fw reviewer T-2223 > /tmp/.t2223.reviewer 2>&1 && grep -qE "Overall:[*]* *PASS" /tmp/.t2223.reviewer

## RCA

**Symptom:** `fw bvp --quadrant hv-lc --include-proposed` surfaces already-shipped tasks (T-2074, T-2002, T-2162, T-2184, T-2185, T-2196) alongside genuinely actionable ones, making the operator's standing HV-LC directive unreliable. Discovered during S-2026-0606-01XX HV-LC survey when 5 of the top 15 candidates turned out to be already in `.tasks/completed/` or `active/` with `status: work-completed`.

**Root cause:** `cmd_rank()` calls `collect_tasks()` which iterates BOTH `.tasks/active/` AND `.tasks/completed/` (per its docstring), and never filters rows by `status`. A task's BVP/cost data persists past completion; the rank command was designed for archival sweep semantics, not for actionable surfaces.

**Why structurally allowed:** The rank surface was added in T-1919/T-1938 (arc-006) for global BVP analysis; the actionable-survey use case (operator picks next HV-LC task) emerged later in standing autonomous-mode directives. No structural test pinned "rank lists what the operator should work on next" — the surface lived in the "rank everything we have data for" semantic space.

**Prevention:** Two-pass guard: (1) the unit test in AC #4 pins the actionable-only default, blocking silent regressions; (2) `--include-completed` opt-in preserves the archive-sweep semantic when explicitly requested. The `--quadrant` filter, `--include-proposed`, and `--include-completed` form a coherent triple: each surfaces a deliberate slice of the BVP space.

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

**Rationale:** Single-file change (`lib/bvp.sh`, ~15 LoC across three locations) closes the operator-survey reliability gap discovered in S-2026-0606-01XX. Sovereignty default flips to actionable-only — the surface answers "what should I work on next" by default — while `--include-completed` preserves the archival sweep semantic for historical analysis. Five Agent ACs verified live: structural pin via grep, two new unit tests + 8 regression tests passing, and live evidence (T-2074 absent without flag, present with `--include-completed`). Reviewer PASS (R-4542373e) after a Verification-block rewrite that dodged two heuristic FPs (l387-sigpipe-risk over-matching `echo "$out" | grep`, ac-verify-mismatch on direct source pin) — neither was a real defect. No render surface (P-013 N/A), no Sovereign acts, no human-judgment dimension. Reversible (single env-or-flag opt-out).

**Evidence:**
- `lib/bvp.sh:245-261` — `cmd_rank()` signature now `(filter_quadrant=None, include_proposed=False, include_completed=False)`; loop skip-clause for `status == 'work-completed'`
- `lib/bvp.sh:1216-1233` — `main()` parses `--include-completed` flag (same shape as `--include-proposed`), threads to both `cmd_rank()` call sites
- `lib/bvp.sh:1158-1163` — `usage()` documents `--include-completed` + actionable-only default
- `tests/unit/test_bvp_status_filter.py` — 5/5 PASS (default-excludes, quadrant-excludes, --include-completed-restores, --include-completed-with-quadrant, help-documents)
- `tests/unit/test_bvp_cli_rank_proposed.py` — 8/8 PASS (T-1938 regression intact)
- Live: `out=$(bin/fw bvp --include-proposed); case "$out" in *"T-2074 "*) exit 1;; esac` → exit 0 (T-2074 filtered); same with `--include-completed` → T-2074 in output
- Reviewer scan R-4542373e: **Overall: PASS**, 0 findings



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

### 2026-06-05T23:04:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2223-fw-bvp-rank-includes-work-completed-task.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-07c637ae
- **Timestamp:** 2026-06-05T23:17:23Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-05T23:17:13Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
