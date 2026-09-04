---
id: T-2486
name: "fix OBS-087 exec-bit: fw resolver/outcome/pause die on Permission denied"
description: >
  fix OBS-087 exec-bit: fw resolver/outcome/pause die on Permission denied

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [lib/outcome.sh, lib/pause.sh, lib/resolver.sh]
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
created: 2026-06-24T16:18:36Z
last_update: 2026-09-03T23:58:23Z
date_finished: 2026-09-03T23:58:23Z
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
  - ts: '2026-07-07T08:00:11Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 5
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=5 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-17T12:36:21Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 5
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=5 (lines=133,acs=3)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-16T22:25:07Z'
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

# T-2486: fix OBS-087 exec-bit: fw resolver/outcome/pause die on Permission denied

## Context

OBS-087 (T-2484 Spike 2): `fw resolver`, `fw outcome`, `fw pause` die on `Permission denied`
because `lib/{resolver,outcome,pause}.sh` are committed at git mode 100644, but `bin/fw` invokes
them via `exec "$FW_LIB_DIR/<x>.sh"` (requires +x). `lib/ask.sh` is the lone exec-style verb at
100755, which is why it works. This is why the orchestrator never dispatched (the dispatch CLI
was unrunnable). Fix = restore +x on the 3 files to match `ask.sh`; close the class with a
regression test covering every exec-style verb. GO slice 1 of T-2484.

## Acceptance Criteria

### Agent
- [x] `lib/resolver.sh`, `lib/outcome.sh`, `lib/pause.sh` are executable, committed at git mode 100755 (matching `lib/ask.sh`) — verified `git ls-files -s`
- [x] `bin/fw resolver workflows` and `bin/fw outcome list T-2485` run with no `Permission denied` (exit 0) — both confirmed live
- [x] Regression test `tests/unit/t2486_exec_bit.bats` asserts EVERY `exec "$FW_LIB_DIR/*.sh"` target in `bin/fw` is executable, and passes (3/3)

### Human (removed — all criteria are deterministic, reversible, internal tooling; Agent-verifiable)

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
test -x lib/resolver.sh && test -x lib/outcome.sh && test -x lib/pause.sh
[ "$(git ls-files -s lib/resolver.sh | cut -d' ' -f1)" = 100755 ]
[ "$(git ls-files -s lib/outcome.sh | cut -d' ' -f1)" = 100755 ]
[ "$(git ls-files -s lib/pause.sh | cut -d' ' -f1)" = 100755 ]
bin/fw resolver workflows >/dev/null 2>&1
bats tests/unit/t2486_exec_bit.bats

## RCA

**Symptom:** `fw resolver run` / `fw outcome backprop` / `fw pause` fail with `Permission denied`.
The orchestrator dispatch substrate — fully implemented in `lib/{resolver,spawn,outcome}.py` —
was unrunnable from the CLI for its entire existence; `fw orchestrator status` read "no dispatches
captured yet" because nothing could invoke the resolver (it only ran via `python3 lib/*.py`).

**Root cause:** `bin/fw` routes these verbs via `exec "$FW_LIB_DIR/<x>.sh"`, which requires the
target to be executable. `lib/resolver.sh`, `lib/outcome.sh`, `lib/pause.sh` are committed at git
mode **100644** (verified `git ls-files -s` — not a worktree perms glitch). `lib/ask.sh` is the
only exec-style verb committed 100755, so it is the lone survivor. Verbs invoked via `bash …` or
`source …` (e.g. `inception`, `review`) are unaffected, which masked the class.

**Why structurally allowed:** no gate verifies that exec-routed `lib/*.sh` keep their executable
bit, and the dispatch verbs were never exercised end-to-end (0 dispatches in the framework's
history), so the breakage never surfaced. The framework was blind because the feature was never
used — the canonical G-019 "sustained blindness" signature.

**Prevention (distinct from the fix):** `tests/unit/t2486_exec_bit.bats` asserts that **every**
`exec "$FW_LIB_DIR/*.sh"` target referenced in `bin/fw` is executable — closing the class for all
exec-style verbs (including any added later), not just the three found broken today.

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

### 2026-06-24T16:18:36Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2486-fix-obs-087-exec-bit-fw-resolveroutcomep.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-04b5d84e
- **Timestamp:** 2026-09-03T23:58:26Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 35
     - evidence: `bin/fw resolver workflows >/dev/null 2>&1`

### 2026-09-03T23:58:23Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
