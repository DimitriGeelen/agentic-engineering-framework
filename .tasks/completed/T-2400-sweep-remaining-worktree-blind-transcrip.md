---
id: T-2400
name: "sweep remaining worktree-blind transcript-dir reconstruction sites onto fw_claude_project_dirs"
description: >
  sweep remaining worktree-blind transcript-dir reconstruction sites onto fw_claude_project_dirs

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [capture-reader, agents/handover/discard-manifest.sh]
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
created: 2026-06-14T17:30:38Z
last_update: 2026-06-14T17:39:50Z
date_finished: 2026-06-14T17:39:50Z
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

# T-2400: sweep remaining worktree-blind transcript-dir reconstruction sites onto fw_claude_project_dirs

## Context

T-2392 added the shared `fw_claude_project_dirs` resolver (lib/paths.sh) and fixed
the loop gauge's worktree-blindness (checkpoint.sh, budget-gate.sh, session-metrics.sh).
This sweeps the REMAINING single-dir transcript-dir reconstruction sites that share
the same worktree-blindness class (they search only the PROJECT_ROOT-keyed dir, so
in a worktree session — where Claude Code keys the dir on the main-repo launch cwd —
they read nothing). Applies the L-397 / L-483 silent-corpus lesson corpus-wide.

**Confirmed-affected (3):**
- `agents/capture/read-transcript.py` `find_transcript()` — newest-pick (`/capture`).
- `agents/handover/discard-manifest.sh` `_jsonl_dir()` — newest-pick (handover discard).
- `lib/costs.sh` `_costs_jsonl_dir()` — **union** scan (aggregates ALL sessions; needs
  union across candidate dirs, not newest-pick — different shape from the other two).

**Cleared as false alarms (not reconstruction):** `session-silent-scanner.sh` (walks
ALL `$HOME/.claude/projects/*/`), `check-active-task.sh` (memory-path glob).

## Acceptance Criteria

### Agent
- [x] `agents/handover/discard-manifest.sh` `_jsonl_dir()` returns the dir of the
      globally-newest transcript across `fw_claude_project_dirs` candidates
      (preserves the `FW_DISCARD_JSONL_DIR` test seam + the Python single-dir glob).
- [x] `agents/capture/read-transcript.py` `find_transcript()` searches all candidate
      dirs (PROJECT_ROOT-keyed AND primary-worktree/main-repo-keyed via
      `git rev-parse --git-common-dir`) and picks the globally-newest transcript.
- [x] bats pins the two migrated newest-pick sites (worktree-keyed stale +
      main-keyed live → picks the live transcript); existing t2380 + t2392 stay
      green (no regression).
- [x] `bash -n` clean on discard-manifest.sh; read-transcript.py parses
      (`python3 -c "import ast; ast.parse(...)"`) and `--dry-run` still works.

> **Scope cut — costs.sh deferred (see Decisions):** the third site (`lib/costs.sh`)
> needs *union* semantics (it aggregates ALL sessions, not newest-pick), which forces
> rewriting 4 existence-agnostic encoding tests across t2380 + lib_costs. It is the
> lowest-value surface (informational cost report; worktree-blindness there is a
> convenience gap, not a correctness/loop issue). Deferred to keep this task
> high-value/low-cost. Tracked as a follow-up.

<!-- No Human ACs — every criterion is agent-verifiable (function behaviour + bats
     + syntax checks). -->

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

bash -n agents/handover/discard-manifest.sh
python3 -c "import ast; ast.parse(open('agents/capture/read-transcript.py').read())"
bats tests/unit/t2400_sweep_worktree_blind_sites.bats

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

### 2026-06-14 — costs.sh leg deferred
- **Chose:** ship the two newest-pick legs (read-transcript.py, discard-manifest.sh)
  now; defer the `lib/costs.sh` union leg to a follow-up.
- **Why:** costs.sh aggregates ALL sessions → needs *union* semantics (not the
  newest-pick the other two + T-2392 use), which forces rewriting 4 existence-agnostic
  encoding tests across t2380 + lib_costs. It is the lowest-value of the three
  surfaces (informational `fw costs`; worktree-blindness there yields a "No JSONL
  directory" annoyance, not a correctness/loop failure). Deferring keeps this task
  high-value/low-cost per the standing directive, and avoids destabilising 4 passing
  tests under budget. The union change (and its bats) is the clean unit for a
  dedicated follow-up. Recorded openly (no silent cap).
- **Rejected:** (a) keep a dead singular `_costs_jsonl_dir` alongside a union plural
  — a confusing "looks-used-but-isn't" smell; (b) force the union + test rewrites now
  — disproportionate cost for the lowest-value surface.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-06-14T17:30:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/arc012-continuous-run-s4s5/.tasks/active/T-2400-sweep-remaining-worktree-blind-transcrip.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-95172dfb
- **Timestamp:** 2026-06-14T17:39:51Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-14T17:39:50Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
