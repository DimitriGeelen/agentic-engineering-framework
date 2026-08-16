---
id: T-2455
name: "fw vendor self _self_vendor_libs skips lib .py files — permanent audit self-vendor
  FAIL vendor self cannot clear"
description: >
  fw vendor self _self_vendor_libs skips lib .py files — permanent audit self-vendor
  FAIL vendor self cannot clear

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [lib/upgrade.sh]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-06-21T14:58:22Z
last_update: '2026-08-16T22:25:06Z'
date_finished: 2026-06-21T15:10:19Z
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
  - ts: '2026-08-16T22:25:06Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=1 (body:episodic-only); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2455: fw vendor self _self_vendor_libs skips lib .py files — permanent audit self-vendor FAIL vendor self cannot clear

## Context

`fw vendor self`'s `_self_vendor_libs` helper (lib/upgrade.sh) synced only `*.sh + *.md`
under `lib/`, but the audit's libs-class drift scanner (agents/audit/audit.sh
`check_self_vendor_drift`) scans `*.sh + *.py + fw + *.md`. Every `lib/**/*.py` was thus
un-vendorable: when source `.py` drifted, the **pre-push audit FAILed and `fw vendor self`
could not clear it**, blocking all pushes. Surfaced post-compact when T-2449's edit to
`lib/reviewer/static_scan.py` left the vendored copy stale and the next push hit an
unresolvable self-vendor FAIL. Found while unblocking the T-2454 handover push. (OBS-085)

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `_self_vendor_libs` find filter includes `*.py` — parity with the audit's `*.sh + *.py + fw + *.md` libs-class scan set (the asymmetry was the bug); stale "`*.sh + *.md` parity" comment corrected
- [x] `fw vendor self` now syncs all 40 `lib/**/*.py`: the 1 divergent reviewer scanner re-synced + 5 previously-missing lib modules created in vendored (the four govd fabric modules plus the integrate module — enumerated in the RCA below)
- [x] `fw vendor self --check` reports in-sync AND audit-replication of `check_self_vendor_drift` shows 0 out-of-sync across bin/lib/agents/web (FAIL cleared, push unblocked)
- [x] Regression test `tests/unit/t2455_self_vendor_libs_py_filter.bats` (4/4): real-run `.py` sync, dry-run non-mutation, source-parity pin (helper filter ↔ audit filter both include `*.py`), clean-state silence
- [x] No regression: sibling `.md`/agents/web helper tests behaviourally unchanged; pre-existing worktree-environment FAILs (t2240 `.git`-is-a-file, t2244 t2, t2267 `_self_vendor_web` — a function untouched here) proven baseline-identical via `git stash` of the edit

### Human
None — internal tooling change (vendor-sync helper); all criteria are agent-verifiable:
deterministic, reversible (git revert), internal scope, no render surface.

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

# T-2455 — env-independent (do NOT add the worktree-env-coupled t2240/t2244/t2267 here):
out=$(bats tests/unit/t2455_self_vendor_libs_py_filter.bats 2>&1); echo "$out" | grep -qE "^ok 4 " && ! echo "$out" | grep -q "^not ok"
grep -qE 'find "\$FRAMEWORK_ROOT/lib".*-name "\*\.py"' lib/upgrade.sh
out=$(bin/fw vendor self --check 2>&1); echo "$out" | grep -q "in sync"

## RCA

**Symptom:** `git push` blocked by a pre-push audit FAIL — "Self-vendor drift: libs class — 1 file(s)
out of sync (`lib/reviewer/static_scan.py`)" — that `fw vendor self` (the FAIL's own recommended fix
command) could **not** clear: `fw vendor self --check` reported "in sync" while the audit reported drift.
A permanent, self-contradictory push block.

**Root cause:** filter-set asymmetry between the sync helper and the audit check. `_self_vendor_libs`
(lib/upgrade.sh) enumerated `\( -name "*.sh" -o -name "*.md" \)` — **no `*.py`** — while the audit's
`check_self_vendor_drift` enumerates `\( -name "*.sh" -o -name "*.py" -o -name "fw" -o -name "*.md" \)`.
So every `lib/**/*.py` (40 files) was scanned-for-drift but never synced. When T-2449 edited source
`lib/reviewer/static_scan.py`, the vendored copy stayed stale; the audit flagged it; `vendor self`
skipped it (wrong filter) → unresolvable.

**Why structurally allowed:** the helper carried a comment asserting "Audit's libs-class drift scanner
scans the same `*.sh + *.md` set, so coverage parity is mechanical." That parity claim was **stale** —
the audit set had grown to include `*.py` and `fw` (it scans bin too) but the helper filter was never
updated to match. The sibling helpers `_self_vendor_agents` and `_self_vendor_web` already included `*.py`;
only the libs helper lagged. No test pinned the helper-filter ↔ audit-filter parity for `.py`, so the
asymmetry was invisible until a `.py` file happened to drift. T-2436 (OBS-076) fixed the FAIL *message*'s
agreement with `vendor self` but not the underlying enumeration gap.

**Prevention:** (1) the fix adds `*.py` to the libs filter, restoring set parity; (2) `t2455 t3` is a
**source-parity pin** — it greps BOTH `lib/upgrade.sh` (helper) AND `agents/audit/audit.sh` (scanner) to
assert both include `*.py`, so a future edit dropping it from either side reds the test; (3) the corrected
comment documents the exact audit set to scan so the next reader maintains parity by intent, not accident.

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

### 2026-06-21T14:58:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2455-fw-vendor-self-selfvendorlibs-skips-lib-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a2c402eb
- **Timestamp:** 2026-06-21T15:10:21Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-21T15:10:19Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
