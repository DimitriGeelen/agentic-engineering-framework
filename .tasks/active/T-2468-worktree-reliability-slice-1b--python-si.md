---
id: T-2468
name: "Worktree reliability slice 1b — python-side hook root-resolver parity (check-arc-id / check-inception-* read env PROJECT_ROOT)"
description: >
  The bash hooks now share fw_reanchor_from_cwd (T-2465). The python hooks (check-arc-id.py, check-inception-decisions.py, check-inception-recommendation.py, check-inception-schema.py) still read project_root = os.environ['PROJECT_ROOT'] (line 141 in check-arc-id.py) — misanchored to MAIN in worktree sessions, so they check main's .context/arcs / tasks. Add a python-side parity resolver (read stdin cwd → walk up to project root → override env PROJECT_ROOT), wire the 4 hooks, add python/bats tests. T-2464 GO Candidate C, slice 1b.

status: captured
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
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-06-23T13:19:20Z
last_update: 2026-06-23T13:19:20Z
date_finished: null
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
---

# T-2468: Worktree reliability slice 1b — python-side hook root-resolver parity (check-arc-id / check-inception-* read env PROJECT_ROOT)

## Context

T-2464 GO Candidate C, slice 1b. The bash hooks now share `fw_reanchor_from_cwd` (T-2465).
The python hooks still read `project_root = os.environ['PROJECT_ROOT']`, which is misanchored
to MAIN in worktree sessions — so they inspect main's `.context/arcs` / `.tasks` / bypass-log
instead of the worktree. This adds a python-side parity resolver and wires the 4 hooks.
RCA: `docs/reports/T-2464-worktree-reliability-rca.md`.

## Acceptance Criteria

### Agent
- [x] `lib/hook_paths.py:reanchor_project_root(payload, fallback)` added — python parity with `lib/paths.sh:fw_reanchor_from_cwd` (reads stdin `cwd`, walks up to project root, no-op for non-worktree)
- [x] 4 python hooks wired to re-derive project_root from stdin `cwd`: `check-arc-id.py`, `check-inception-decisions.py`, `check-inception-recommendation.py`, `check-inception-schema.py` (global re-anchor for the module-level PROJECT_ROOT case)
- [x] `tests/unit/test_hook_paths.py` (8 tests) pass — re-anchor / walk-up / no-op cases
- [x] No regression: arc_id_validation_guard (15) + check_inception_decisions_hook (20) + check_inception_recommendation (7) + check_inception_schema (10) + create_task_inception_recommendation_gate (11) all green; `py_compile` clean on all 5 files
- [x] Restored `+x` on 10 hook wrappers that lost it (pre-existing, blocked the direct-invocation tests; `bin/fw` execs via `bash` so live dispatch was unaffected) — prevention is T-2467


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
python3 -m py_compile lib/hook_paths.py agents/context/check-arc-id.py agents/context/check-inception-decisions.py agents/context/check-inception-recommendation.py agents/context/check-inception-schema.py
python3 tests/unit/test_hook_paths.py
bats tests/unit/arc_id_validation_guard.bats
bats tests/unit/check_inception_decisions_hook.bats
bats tests/unit/check_inception_recommendation.bats
bats tests/unit/check_inception_schema.bats

## RCA

**Symptom:** In a worktree session the python PreToolUse hooks (arc_id / inception-decisions /
inception-recommendation / inception-schema) resolve project state against the MAIN repo —
they check main's `.context/arcs`, task dirs, and `.gate-bypass-log.yaml` instead of the
worktree the tool ran in. Same OBS-080 class as the bash hooks (T-2463/T-2465).

**Root cause:** each python hook does `project_root = os.environ['PROJECT_ROOT']`, and bin/fw
exports PROJECT_ROOT resolved from the hook's process cwd — MAIN — when wired by main's
absolute path. The stdin payload carries the authoritative per-call `cwd`, but the hooks
never consulted it.

**Why structurally allowed:** the T-2465 shared resolver was bash-only; python hooks had no
parity path, so they kept reading the env var. No test exercised a python hook under a
worktree-style invocation (PROJECT_ROOT=main, stdin cwd=worktree).

**Prevention:** `lib/hook_paths.py:reanchor_project_root` — one python helper mirroring the
bash `fw_reanchor_from_cwd`; all 4 hooks call it. `tests/unit/test_hook_paths.py` pins the
contract. Same shape both languages now. (Also surfaced + restored a batch `+x` loss on hook
wrappers — root prevention tracked in T-2467.)


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

### 2026-06-23T13:19:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2468-worktree-reliability-slice-1b--python-si.md
- **Context:** Initial task creation
