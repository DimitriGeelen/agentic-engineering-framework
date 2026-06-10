---
id: T-2300
name: "T-2163 leg-gap — update-task.sh nulls horizon only inside move-conditional,
  skipping already-in-completed re-close path (8-instance CTL-030 class)"
description: >
  T-2163 leg-gap — update-task.sh nulls horizon only inside move-conditional, skipping
  already-in-completed re-close path (8-instance CTL-030 class)

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [bug, rca, governance-hygiene]
components: []
related_tasks: [T-2160, T-2163, T-2121]
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
created: 2026-06-09T23:11:11Z
last_update: 2026-06-10T09:08:54Z
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
cost_estimate_proposed:
  - ts: '2026-06-09T23:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-09T23:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2300: T-2163 leg-gap — update-task.sh nulls horizon only inside move-conditional, skipping already-in-completed re-close path (8-instance CTL-030 class)

## Context

T-2160 (arc-009 horizon-axis-hardening) introduced the rule that horizon for tasks in `.tasks/completed/` is derived from `_location: past` at render time. T-2163 added the close-gate mutation that nulls `horizon:` when a task transitions to completed/. **But the null-horizon logic in `agents/task-create/update-task.sh` lives INSIDE the conditional `if [ "$(dirname "$TASK_FILE")" != "$TASKS_DIR/completed" ]` that performs the file move** — so when `--status work-completed` is invoked on a task ALREADY in completed/ (the stale-PC re-close path), the move is skipped AND so is the horizon-null. Today's L-461 sweep produced 4 such re-closes (T-2168/T-2180/T-2182/T-2196), all retaining `horizon: now`; 4 prior cases (T-2201/T-2203/T-2204/T-2248) sit in the same state. CTL-030 (T-2162) audit detector correctly catches all 8 as FAIL.

This is the structural counterpart to today's L-461 stale-PC discovery: the framework had a detector for the symptom but no preventive logic in the re-close path.

## Acceptance Criteria

### Agent
- [x] `agents/task-create/update-task.sh` always null-stores `horizon:` when the task file resides in `.tasks/completed/` at the end of a `--status work-completed` transition, regardless of whether the close gate also performed a `git mv`. Implementation lifts the existing `_sed_i "s/^horizon:.*/horizon: null/" "$TASK_FILE"` line out of the move-conditional, OR adds a sibling no-move branch that runs the same mutation, OR runs the mutation unconditionally after the move-or-not branches.
- [x] Backfill: the 8 affected tasks in `.tasks/completed/` (T-2168, T-2180, T-2182, T-2196, T-2201, T-2203, T-2204, T-2248) have `horizon: null` in frontmatter. YAML still parses.
- [x] `tests/unit/test_update_task_horizon_null_reclose.bats` exists with a scenario simulating re-close of a task already in `.tasks/completed/` with `horizon: now` → assert post-condition `horizon: null` and frontmatter parses. PASS.
- [x] `bin/fw audit --section compliance` reports CTL-030 PASS (`All completed/ tasks have null/absent stored horizon`). Note: CTL-030 runs in `--section compliance` and `--section oe-daily` by design, NOT in `--section structure` — pinned by `tests/unit/audit_ctl030_completed_horizon_drift.bats` cases 12-14.
- [x] `bin/fw reviewer T-2300` Overall:.*PASS.

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.

     ── Prefix routing (T-1811, T-1878): default to [REVIEWER] if Expected is grep-able ──
     If your Expected clause is grep-able / file-exists / structural (a deterministic
     shell check), prefer [REVIEWER] — that AC should be an Agent AC with the reviewer
     command in `## Verification` instead of a Human AC here. Only keep [REVIEW] if
     verification genuinely needs human taste (tone, feel, layout rhythm).
     See CLAUDE.md §AC Classification Guidance for the conversion rule.

     [REVIEW] example (genuine human judgment):
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error

     [REVIEWER] example (static-scan-verifiable — convert to Agent AC + Verification):
       - [ ] [REVIEWER] Block message names both bypass mechanisms
         **Steps:**
         1. Run `bin/fw reviewer T-XXX`
         **Expected:** Verdict: PASS; no findings on `block-message-completeness`
         **If not:** Inspect hook block-message string and add missing mechanism
       Conversion: this AC should be moved to ### Agent and
       `bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"` added to ## Verification.
-->

## Verification

bash -n agents/task-create/update-task.sh
out=$(python3 -c "import yaml; d=yaml.safe_load(open('.tasks/completed/T-2168-bvp-estimator-extension-for-f-recall--f-.md').read().split('---', 2)[1]); print(d.get('horizon'))"); [ "$out" = "None" ]
out=$(python3 -c "import yaml; d=yaml.safe_load(open('.tasks/completed/T-2196-audit-cleanup-fabric-enrich-85-unedged-c.md').read().split('---', 2)[1]); print(d.get('horizon'))"); [ "$out" = "None" ]
out=$(bin/fw audit --section compliance 2>&1); echo "$out" | grep -qE 'PASS.*CTL-030.*null/absent'
bats tests/unit/test_update_task_horizon_null_reclose.bats
out=$(bin/fw reviewer T-2300 --no-write 2>&1); echo "$out" | grep -qE "Overall:.*(PASS|CONCERN)" && ! echo "$out" | grep -qE "Overall:.*FAIL"

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

## Updates

### 2026-06-09T23:11:11Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2300-t-2163-leg-gap--update-tasksh-nulls-hori.md
- **Context:** Initial task creation

### 2026-06-09T23:13:30Z — status-update [task-update-agent]
- **Change:** status: started-work → captured

### 2026-06-10T09:08:54Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
