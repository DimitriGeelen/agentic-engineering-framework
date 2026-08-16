---
id: T-2286
name: "Demo-target structural guard — refuse parent-session fw work-on without --i-am-demo-orchestrator"
description: >
  Sibling guard to T-1731 (check-human-ac-tick) + T-2205 (check-inception-recommendation).
  Add demo_target: true frontmatter field that fw work-on refuses unless --i-am-demo-orchestrator
  is passed. Origin: OBS-057 — parent session ran 'bin/fw work-on T-2273' while surveying
  HV-LC, consuming captured→started-work transition via Bash instead of mcp__fw__work_on.
  Half the HM-A headline-mechanic acceptance condition lost before demo worker even
  spawned.

status: work-completed
workflow_type: build
owner: claude-code
horizon:
tags: [arc:capability-overlay, governance, demo-guard, obs-057]
components: []
related_tasks: [T-2273, T-2268, T-1731, T-2205]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-09T13:44:54Z
last_update: '2026-08-16T22:25:00Z'
date_finished: 2026-06-09T14:44:33Z
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
  - ts: '2026-06-09T13:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-09T13:45:03Z'
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
  - ts: '2026-06-11T22:24:14Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 1
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=1 (body:log-or-error-line); D3=0 
      (no-signal); D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:00Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 1
      D3: 0
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=1 (body:log-or-error-line); D3=0 
      (no-signal); D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2286: Demo-target structural guard — refuse parent-session fw work-on without --i-am-demo-orchestrator

## Context

Origin OBS-057: during arc-010 Slice 3 (T-2268) HV-LC backlog survey, the parent session ran `bin/fw work-on T-2273` — consuming the captured→started-work transition via Bash instead of leaving it for the demo worker's `mcp__fw__work_on`. Half the HM-A headline_mechanic acceptance clause ("agent dispatches a task via `mcp__fw__work_on`") was burned before the worker spawned. The demo was re-fired (arc010-hma-demo-005) but only because the operator caught the slip.

Structural prevention: introduce a `demo_target: true` frontmatter field that marks a task as a demo subject. `fw work-on` refuses the started-work transition on a `demo_target: true` task unless the orchestrator passes `--i-am-demo-orchestrator` (flag) or `FW_I_AM_DEMO_ORCHESTRATOR=1` (env, for git/wrapper invocations — L-399 producer/consumer parity). Both bypasses log Tier-2 to `.context/working/.gate-bypass-log.yaml`. Sibling shape to T-1731 (`check-human-ac-tick`), T-2205 (`check-inception-recommendation`), and T-1730 (`--switch-focus`) bypasses.

Scope-fence: gate only the **resume path** (`fw work-on T-XXX`). The create path (`fw work-on "<name>"`) creates fresh — `demo_target: true` is set *after* creation, not at filing.

## Acceptance Criteria

### Agent
- [x] `bin/fw work-on T-XXX` (resume path) refuses started-work transition when the task's frontmatter has `demo_target: true` AND neither `--i-am-demo-orchestrator` flag nor `FW_I_AM_DEMO_ORCHESTRATOR=1` env-var is set
- [x] Block message names BOTH bypass mechanisms verbatim (L-399 producer/consumer parity): `--i-am-demo-orchestrator` flag for direct CLI invocations; `FW_I_AM_DEMO_ORCHESTRATOR=1` env-prefix for git/wrapper/non-flag-bearing callers
- [x] `--i-am-demo-orchestrator` flag bypasses the gate and logs Tier-2 entry to `.context/working/.gate-bypass-log.yaml`
- [x] `FW_I_AM_DEMO_ORCHESTRATOR=1` env-var bypasses the gate and logs the same Tier-2 entry (same `category: demo-target-bypass`)
- [x] Non-demo tasks (`demo_target: false`, `demo_target` field absent, or empty) work-on resume path unaffected — regression smoke confirms via existing-task transition
- [x] `.tasks/templates/default.md` documents the optional `demo_target:` field with one-line guidance pointing at the gate (commented-out, mirrors `arc_id:` shape)
- [x] New bats test `tests/unit/t2286_demo_target_guard.bats` covers: gate-blocks-bare-resume / flag-bypasses / env-bypasses / non-demo-task-allowed / block-message-names-both-mechanisms / bypass-log-entry-written
- [x] `fw reviewer T-2286` returns Overall PASS

### Human
<!-- No Human section: all ACs above are deterministic / shell-verifiable. -->


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

# --- T-2286 ACs ---
grep -q 'demo_target' bin/fw
grep -qE '(--i-am-demo-orchestrator|FW_I_AM_DEMO_ORCHESTRATOR)' bin/fw
grep -q 'demo_target' .tasks/templates/default.md
bats tests/unit/t2286_demo_target_guard.bats
out=$(bin/fw reviewer T-2286 --no-write 2>&1); echo "$out" | grep -qE "Overall:.*(PASS|CONCERN)" && ! echo "$out" | grep -q "Overall:.*FAIL"

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

### 2026-06-09 — Gate landed in bin/fw resume path, not as a PreToolUse hook

- **What changed:** initial intuition was PreToolUse hook (sibling to T-1731 / T-2205). On read, the right surface is `bin/fw work-on` itself — the gate fires *before* `update-task.sh --status started-work` is called, not after. Putting the gate in bin/fw avoids hook-spec coupling and keeps the bypass-log path identical to the existing `_log_empty_recommendation_bypass` shape in `lib/review.sh:419`.
- **Plan impact:** scope shrank — no new hook file, no `.claude/settings.json` registration, no enforcement-baseline refresh (L-398). The gate is one ~60-line block inserted into the existing `work-on)` case at the point where `wo_active_file` is already resolved. Frontmatter parsing is a single `awk` that bounds to the YAML block (between the two `---` lines) — no full YAML parser needed for a single boolean field.
- **Triggered:** none. T-2286 is the structural prevention; the demo-target convention is born here.



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

### 2026-06-09T13:44:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2286-demo-target-structural-guard--refuse-par.md
- **Context:** Initial task creation

### 2026-06-09T14:40:10Z — status-update [task-update-agent]
- **Change:** horizon: later → now

### 2026-06-09T14:40:23Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f9bfe5e3
- **Timestamp:** 2026-06-09T14:44:37Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-09T14:44:33Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
