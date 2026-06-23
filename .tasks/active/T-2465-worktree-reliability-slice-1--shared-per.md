---
id: T-2465
name: "Worktree reliability slice 1 — shared per-call hook root-resolver"
description: >
  Centralize T-2463 root-resolution into one shared per-call resolver all hooks call; add suite-level worktree-invocation test. T-2464 GO Candidate C slice 1.

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
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-06-23T13:08:26Z
last_update: 2026-06-23T13:08:26Z
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

# T-2465: Worktree reliability slice 1 — shared per-call hook root-resolver

## Context

T-2464 GO Candidate C, slice 1. Generalize T-2463's inline worktree root-resolution into one
shared per-call resolver in `lib/paths.sh` that framework hooks call, replacing the per-hook
re-implementation that caused the 7+ point-fix whack-a-mole. RCA: `docs/reports/T-2464-worktree-reliability-rca.md`.
Python-hook parity (check-arc-id / check-inception-*) is split to T-2468 (distinct mechanism).

## Acceptance Criteria

### Agent
- [x] `fw_reanchor_from_cwd` + `fw_reanchor_from_hook_stdin` added to `lib/paths.sh` (shared resolver; no-op for non-worktree sessions; keeps `_FW_PATHS_DERIVED_BY` consistent with T-2289)
- [x] `check-active-task.sh` refactored to call the shared resolver (inline T-2463 block removed) — behavior-preserving
- [x] `check-visual-verification.sh` adopts the shared resolver (2nd bash hook that reads worktree-sensitive focus/tasks)
- [x] Dedicated unit tests for the resolver primitive: `tests/unit/t2465_reanchor_from_cwd.bats` (10 tests) pass
- [x] No regression: all check-active-task suites green (56 tests across unit+integration), `lib_paths.bats` green (11), `bash -n` clean on all edited scripts
- [x] Python-hook parity scoped as follow-up T-2468 (the 4 python hooks read env `PROJECT_ROOT` — same class, python mechanism)


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
bash -n lib/paths.sh
bash -n agents/context/check-active-task.sh
bash -n agents/context/check-visual-verification.sh
bats tests/unit/t2465_reanchor_from_cwd.bats
bats tests/unit/check_active_task_cwd_resolution.bats
bats tests/unit/lib_paths.bats
bats tests/integration/check_active_task.bats

## RCA

**Symptom:** Worktree sessions blocked every non-safe Bash/Write/Edit with "No active task"
even with the worktree's own focus set (T-2463 / OBS-080). Generalized: framework hooks read
MAIN's `focus.yaml` / `.tasks` / `.context/arcs` instead of the worktree the tool ran in.

**Root cause:** Every hook is wired into Claude Code `settings.json` by MAIN's absolute path
(`<main>/bin/fw hook …`). When a hook fires in a worktree (or spawned) session, `bin/fw`
resolves `PROJECT_ROOT` from the hook's process cwd / inherited env — the MAIN repo. Each hook
that needed the correct root re-implemented resolution locally (T-2463 added an inline block to
just one hook), so the fix never centralized and the same defect kept resurfacing on new
surfaces (T-2446/T-2389/T-2392/T-2289/T-2054/T-2462 — 7+ point-fixes).

**Why structurally allowed:** No shared per-call resolver existed. `bin/fw`'s PROJECT_ROOT
resolution is process-cwd/env based, and there was no path that consulted the authoritative
per-call stdin `cwd` Claude Code passes to hooks. So "figure out the real root" was copy-pasted
per hook, or simply absent.

**Prevention:** One shared resolver — `fw_reanchor_from_cwd` / `fw_reanchor_from_hook_stdin` in
`lib/paths.sh` — that every hook calls. Unit tests (`t2465_reanchor_from_cwd.bats`, 10) pin the
contract (re-anchor / no-op cases / `_FW_PATHS_DERIVED_BY` consistency). Future hooks call one
function instead of reinventing resolution. T-2468 extends the same contract to the python
hooks. Slice 2 (T-2466) adds a `fw worktree` lifecycle so "is the fix live on this host" is
observable rather than surprising.

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

### 2026-06-23T13:08:26Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2465-worktree-reliability-slice-1--shared-per.md
- **Context:** Initial task creation
