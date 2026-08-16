---
id: T-2674
name: "wire is_valid_owner predicate at task creation"
description: >
  create-task.sh accepts any --owner string unvalidated; is_valid_owner() exists (lib/enums.sh:103)
  but is never called at creation. Watchtower hard-whitelists {human, claude-code},
  so a free-form owner (e.g. --owner orchestrator) renders broken there. Live conformance
  hole surfaced via T-2666's task-creation corpus map + 832's round-#3 pair-draft
  verdict (rail 316): 'owner-validation and status-predicate are two independent holes
  with separate root causes -- file separately'. This task covers ONLY owner; see
  companion task for the status predicate.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [process-layer, corpus, healing-class]
components: []
related_tasks: [T-2666]
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
created: 2026-07-29T10:13:38Z
last_update: '2026-08-16T22:24:11Z'
date_finished: 2026-07-29T11:34:23Z
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
  - ts: '2026-07-29T10:15:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-29T10:15:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:11Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2674: wire is_valid_owner predicate at task creation

## Context

Level-C fix from T-2666's task-creation corpus map (832 rail-316 verdict: owner and status
are two independent holes — this is the owner leg; T-2675 is the status leg).
`is_valid_owner()` exists (lib/enums.sh:101) but create-task.sh never calls it — any
`--owner` string is written verbatim. Pre-fix survey: enum says `owners: [human, claude-code]`
(status-transitions.yaml:31-33) but live reality is 532 tasks with `owner: agent` (the
`fw work-on` default), so the enum must be reconciled with reality BEFORE the gate goes hard,
or every agent-side create breaks. Watchtower loads owners from the same YAML
(web/blueprints/tasks.py:_load_enums) with one stale hard-code at task_detail.html:246.

## Acceptance Criteria

### Agent
- [x] `owners:` in status-transitions.yaml extended with `agent` (enum reconciled with live reality); compiled `VALID_OWNERS` (lib/enums.sh) includes agent
- [x] create-task.sh calls `is_valid_owner "$OWNER"` after required-field resolution, following the existing `is_valid_type`/`is_valid_horizon` pattern — invalid owner dies with the valid-owner list, exit non-zero, no task file written
- [x] Reject path proven: `--owner orchestrator` create fails with actionable message; accept path proven: `--owner human|claude-code|agent` all still create
- [x] Fallback lists updated to match the extended enum: lib/enums.sh fallback, web/blueprints/tasks.py `_ENUM_CACHE` fallback, and task_detail.html:246 hard-coded owner list
- [x] bats test pins the gate (reject + accept), green
- [x] concerns.yaml entry for the owner-validation hole updated with resolution evidence (predicate now CALLED — G-019 prevention bar)

### Human
- [ ] [REVIEW] Owner dropdown on the task detail page reads correctly with the third value
  **Steps:**
  1. Open http://192.168.10.107:3001/tasks/T-2674 in a browser
  2. Look at the Owner row in the metadata table — the inline dropdown should offer human / claude-code / agent, with agent selected
  3. Optionally flip owner to human and back — both writes should succeed
  **Expected:** Three options render cleanly in the dropdown; no layout break in the metadata table; owner change round-trips
  **If not:** Note what the dropdown shows; check `curl -s http://192.168.10.107:3001/tasks/T-2674 | grep -A6 'name="owner"'` and report the markup

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

out=$(bats tests/unit/create_task_owner_gate.bats 2>&1); echo "$out" | grep -q "^ok" && ! echo "$out" | grep -q "^not ok"
grep -q "^  - agent$" status-transitions.yaml
grep -q "is_valid_owner" agents/task-create/create-task.sh

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

**Symptom:** `fw task create --owner <anything>` writes the string verbatim; free-form owners render broken/unsettable in Watchtower (G-040 asymmetry: bash permissive, Python strict).

**Root cause:** T-1180 shipped the enum + `is_valid_owner()` but never wired the call into create-task.sh — producer/consumer split: the predicate existed on one side only. Compounding: the enum itself had drifted from reality (`agent` is fw work-on's default and the majority live owner, 500+ tasks, yet absent from `owners:`), so a naive hard gate would have broken every agent-side create.

**Why structurally allowed:** G-040 was marked resolved on the strength of the enum existing — resolution verified the artifact (predicate defined), not the behavior (predicate called). Same proxy-vs-reality class as T-1828. No test exercised the creation-side reject path, so the missing call was invisible for 3+ months. Third leg: `status-transitions.yaml` was absent from do_vendor's includes list, so vendored consumers' enums were frozen at seed time (T-2656 enumeration-divergence class) — invisible because nothing diffs vendored data files.

**Prevention:** `tests/unit/create_task_owner_gate.bats` pins reject + accept paths (a future regression fails CI, not field use); `status-transitions.yaml` in do_vendor includes means every `fw upgrade` refreshes consumer enums; concern G-040 resolution text now records that "predicate defined" ≠ "predicate called" for the next reader.

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

## Recommendation

**Recommendation:** GO

**Rationale:** The creation-side owner gate is wired, live-verified end-to-end, and pinned by tests; the only open item is the [REVIEW] Human AC on the task-detail dropdown rendering, which is already confirmed working via curl markup inspection — the human check is visual confirmation only.

**Evidence:**
- Reject path live: `--owner orchestrator` → "Invalid owner 'orchestrator' / Valid owners: human claude-code agent", no file written
- `tests/unit/create_task_owner_gate.bats` 4/4 green (reject + all three accept paths)
- `tests/unit/upgrade_fresh_machine_simulation.bats` green (consumer-facing hygiene, T-1633 rule — do_vendor includes touched)
- tests/web task subset 12/12 green
- Live dropdown at /tasks/T-2674 renders human/claude-code/agent with agent selected (post-restart)
- Vendored parity: create-task.sh, enums.sh, tasks.py, task_detail.html, bin/fw, status-transitions.yaml all synced to .agentic-framework/
- G-040 resolution annotated; OBS-099 filed for the residual in-repo self-vendor root-file leg

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

### 2026-07-29T10:13:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2674-wire-isvalidowner-predicate-at-task-crea.md
- **Context:** Initial task creation

### 2026-07-29T11:24:58Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-94459766
- **Timestamp:** 2026-07-29T11:34:25Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#4 (Agent)** — Fallback lists updated to match the extended enum: lib/enums.sh fallback, web/blueprints/tasks.py `_ENUM_CACHE` fallback, and task_detail.html:246 hard-coded owner list
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/blueprints/tasks.py in: Fallback lists updated to match the extended enum: lib/enums.sh fallback, web/blueprints/tasks.py `_ENUM_CACHE` fallback, and task_detail.html:246 har`

### 2026-07-29T11:34:23Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
