---
id: T-2391
name: "bin/fw: validate inherited PROJECT_ROOT; reject stale /root from tmux-server
  env"
description: >
  Bug A from T-2390 re-drive 2. The tmux-server daemon (PID 6177, child of init) carries
  a stale PROJECT_ROOT=/root in its env; every 'termlink spawn --backend tmux' session
  inherits it. bin/fw resolves PROJECT_ROOT only when empty (if [ -z ]), so it uses
  the poison verbatim and find_project_root never runs. This blinds budget-gate/checkpoint
  in spawned sessions (arc-012 loop never arms). The T-2390 CLAUDE_PROJECT_DIR-preference
  fix is dead code (inside the [ -z ] guard; CLAUDE_PROJECT_DIR also unset). Fix:
  validate an inherited PROJECT_ROOT and re-resolve when stale (PWD not under it /
  equals $HOME). High blast-radius (every fw invocation) -> needs careful design +
  bats. Validity criterion is non-trivial: framework repo has no .framework.yaml;
  /root may have stray .tasks. See T-2390 ## Re-drive 2 Bug A. Cheaper sibling mitigation:
  restart tmux server with clean env.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [bin/fw, tests/unit/t2391_project_root_inherited_stale.bats]
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
created: 2026-06-14T10:01:16Z
last_update: '2026-08-16T22:25:04Z'
date_finished: 2026-06-14T15:45:43Z
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
  - ts: '2026-08-16T22:25:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2391: bin/fw: validate inherited PROJECT_ROOT; reject stale /root from tmux-server env

## Context

Bug A from T-2390 re-drive 2. `bin/fw` resolves `PROJECT_ROOT` only when empty
(`if [ -z "${PROJECT_ROOT:-}" ]`, bin/fw:157). A long-lived parent — the tmux-server
daemon (PID 6177) — carries a stale `PROJECT_ROOT=/root` (= `$HOME`) in its env;
every `termlink spawn --backend tmux` session inherits it, so the `-z` guard is
false and the poison is used verbatim. `find_project_root()` never runs and the
T-2390 `CLAUDE_PROJECT_DIR`-preference block (bin/fw:170) is dead code in that
path. Net effect: budget-gate/checkpoint hooks in spawned sessions resolve `/root`,
the gauge is blind, and the arc-012 continuous loop never arms.

Fix: validate an inherited `PROJECT_ROOT` and re-resolve when **stale** —
narrowly, to avoid breaking the documented "env wins" contract operators rely on
for explicit cross-dir targeting (`test_project_root_discovery.py::test_resolve_project_root_env_wins_unconditionally`).
Staleness signature: `=$HOME` (the daemon-poison case) OR not a directory OR no
project marker (`.framework.yaml`/`.tasks`). A legitimate inherited value (real
project, marker present, ≠ `$HOME`) is kept untouched — env still wins.

Scope note: **necessary but not sufficient** to live-fire continuous mode —
Bug B (T-2392, in-hook token gauge reads 0 via a wrong `transcript_path`) is a
separate blocker that needs an instrumented live run.

## Acceptance Criteria

### Agent
- [x] `_project_root_is_stale()` helper added to `bin/fw`: returns stale (exit 0) when a non-empty inherited `PROJECT_ROOT` equals canonical `$HOME`, is not a directory, or carries no `.framework.yaml`/`.tasks` marker; returns not-stale (exit 1) otherwise
- [x] Resolution guard changed from `[ -z PROJECT_ROOT ]` to `[ -z PROJECT_ROOT ] || _project_root_is_stale "$PROJECT_ROOT"` so a stale inherited value routes through the existing `CLAUDE_PROJECT_DIR`→`find_project_root` resolution
- [x] Poison fixed: `PROJECT_ROOT=$HOME` (with a stray `.tasks` marker) re-resolves to the cwd's real project, not `$HOME` (bats t1; live-proven from worktree with `PROJECT_ROOT=/root`)
- [x] `CLAUDE_PROJECT_DIR` preference is now reachable for the inherited-poison case (no longer dead code): stale `PROJECT_ROOT` + valid `CLAUDE_PROJECT_DIR` resolves to `CLAUDE_PROJECT_DIR` (bats t2)
- [x] No regression — env still wins for legitimate overrides: an inherited `PROJECT_ROOT` pointing at a real project (marker present, ≠ `$HOME`) is KEPT even from an unrelated cwd (bats t3 cross-dir + t4 same-dir)
- [x] Markerless and non-existent inherited dirs re-resolve (bats t5, t6)
- [x] `bash -n bin/fw` clean (L-408); existing `t2390_project_root_claude_dir.bats` (3/3) and `test_project_root_discovery.py` (7/7) stay green

### Human

_(none — all criteria are agent-verifiable: deterministic bash resolution + bats.)_

## Verification

bash -n bin/fw
bats tests/unit/t2391_project_root_inherited_stale.bats
bats tests/unit/t2390_project_root_claude_dir.bats
python3 -m pytest tests/unit/test_project_root_discovery.py -q

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

## RCA

**Symptom:** Spawned (`termlink spawn --backend tmux`) sessions resolve
`PROJECT_ROOT=/root`; budget-gate/checkpoint hooks write to / read from the wrong
project, the token gauge is blind, and the arc-012 continuous loop never arms
(T-2389/T-2390 live-fires, 3× NO-GO).

**Root cause:** `bin/fw` only *computes* `PROJECT_ROOT` when the inherited env var
is empty (`if [ -z "${PROJECT_ROOT:-}" ]`). It never *validates* a non-empty
inherited value. The tmux-server daemon (PID 6177, child of init) carries
`PROJECT_ROOT=/root` (= `$HOME`) — proven via `/proc/6177/environ` — which every
spawned session inherits, so the guard short-circuits and the poison is used
verbatim. The T-2390 `CLAUDE_PROJECT_DIR`-preference fix lives *inside* the same
`[ -z ]` guard, so it is dead code whenever a (poisoned) value is inherited.

**Why structurally allowed:** "resolve when empty" silently conflated *unset* with
*valid*. There was no notion of a stale-but-non-empty inherited root, and nothing
distinguished the daemon-poison signature (`=$HOME`) from a legitimate operator
override. T-2390 added the better resolver but gated it on the wrong condition.

**Prevention:** `_project_root_is_stale()` makes the staleness criterion explicit
and testable; `t2391_project_root_inherited_stale.bats` pins both the fix (poison
re-resolves) AND the non-regression boundary (legitimate cross-dir override still
wins) so the next change to this block can't silently re-trust the env. Learning
captured for the "resolve-when-empty conflates unset with valid" class.

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

### 2026-06-14T10:01:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/arc012-continuous-run-s4s5/.tasks/active/T-2391-binfw-validate-inherited-projectroot-rej.md
- **Context:** Initial task creation

### 2026-06-14T15:38:25Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2c65f34b
- **Timestamp:** 2026-06-14T15:45:45Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-14T15:45:43Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
