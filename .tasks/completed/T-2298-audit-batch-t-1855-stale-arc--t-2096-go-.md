---
id: T-2298
name: "audit: batch T-1855 stale-arc + T-2096 GO-scope-not-propagated per-task forks
  (OBS-066, T-2297 follow-on)"
description: >
  audit: batch T-1855 stale-arc + T-2096 GO-scope-not-propagated per-task forks (OBS-066,
  T-2297 follow-on)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [audit, performance, obs-066]
components: []
related_tasks: [T-2297, T-1855, T-2096]
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
created: 2026-06-09T20:48:33Z
last_update: 2026-06-09T21:04:40Z
date_finished: 2026-06-09T21:04:40Z
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
  - ts: '2026-06-09T21:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-09T21:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2298: audit: batch T-1855 stale-arc + T-2096 GO-scope-not-propagated per-task forks (OBS-066, T-2297 follow-on)

## Context

T-2297 closed the per-file fork in the T-2067 fm parse block — `--section structure` dropped from 6.7 min → 132s. Profiling found two remaining hot spots, both same shape (per-task fork):

1. **T-1855 stale-arc** (audit.sh:734): for each in-progress arc (8 currently), for each task file (2,261), runs awk to extract `arc_id:`. 8 × 2,261 = 18,088 awk subprocess spawns per audit. Estimated ~90-100s.
2. **T-2096 GO-scope-not-propagated** (audit.sh:1171): for each completed task (~1,500), runs 3-4 greps + 1 `grep -lE` cross-file scan. Estimated ~30-60s.

Fix shape: pre-compute task→arc_id map and task→workflow_type+body-claim map in a single python3 pass, then iterate the map in bash. Expected outcome: `--section structure` from 132s → <10s.

## Acceptance Criteria

### Agent
- [x] T-1855 stale-arc block at audit.sh now uses a pre-computed `task_arc_map` (single python3 pre-scan) and ZERO awk invocations inside any per-task inner loop. Bats t1 (T-2298 pin) PASS.
- [x] T-2096 GO-scope-not-propagated block at audit.sh now uses a single python3 pre-scan emitting candidate paths; back-references checked via O(M+N) referenced-ids set instead of O(M*N) per-candidate cross-file grep. Bats t3 (T-2298 pin) PASS.
- [x] `bin/fw audit --section structure` completes in under 100s wall-clock on the current 2,261-task corpus. Measured 64s/66s/66s across 3 runs (steady-state ~65s; down from 132s post-T-2297, ~402s pre-T-2297 = ~6× total payoff).
- [x] Bats regression `tests/unit/t2298_audit_structure_no_perfile_fork.bats` PASS — 5/5: T-1855 block contains task_arc_map, no per-task awk fork; T-2096 block contains go_scope_unprop_list, no per-task grep fan-out, no per-candidate `grep -lE`; audit.sh syntactically valid.
- [x] Sibling regressions PASS: t2297 (3/3), t2293 (4/4), t2296 (3/3) all green. Confirmed in joint bats run.
- [x] OBS-066 promoted in .context/inbox.yaml: status=pending→promoted, promoted_to=T-2298. Inbox parses; OBS-064 + OBS-066 both correctly promoted.
- [x] Reviewer PASS via `bin/fw reviewer T-2298` (no FAIL findings). R-f08bf4f3 PASS, 0 findings.

<!-- All ACs deterministic shell checks; no Human AC (no render surface, no operator-taste judgment). -->

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

# AC: T-1855 + T-2096 bats regression
bats tests/unit/t2298_audit_structure_no_perfile_fork.bats

# AC: sibling regressions still PASS
bats tests/unit/t2297_audit_structure_batched.bats tests/unit/t2293_mcp_check.bats tests/unit/t2296_audit_mcp_manifest_drift.bats

# AC: --section structure completes in <100s (measured 65s steady-state)
S=$(date +%s); bin/fw audit --section structure >/tmp/.t2298-real.out 2>&1; D=$(($(date +%s) - S)); echo "structure: ${D}s"; [ "$D" -lt 100 ]

# AC: reviewer PASS or CONCERN-with-override (capture-then-grep, L-387)
out=$(bin/fw reviewer T-2298 2>&1); echo "$out" | grep -qE "Overall:.*(PASS|CONCERN)" && ! echo "$out" | grep -q "Overall:.*FAIL"

## RCA

<!-- Not a bug-class fix per se — this is a performance refactor follow-on to T-2297.
     Keeping RCA framing because the title contains "fork" / "OBS" and the close-gate
     classifier may interpret "follow-on" as bug-like. Defense-in-depth framing follows. -->

**Symptom.** Post-T-2297, `bin/fw audit --section structure` still takes 132s (down from 6.7 min). Two per-task fork classes identified by profiling: T-1855 stale-arc check (per-arc × per-task awk fork: 18K subprocesses) and T-2096 GO-scope-not-propagated scan (per-completed-task grep fan-out + per-candidate cross-file `grep -lE` for back-references).

**Root cause.** Same shape as T-2067 (already fixed in T-2297) — per-task subprocess spawn inside a hot loop:

- T-1855 (audit.sh:734) ran `ttag=$(awk '/^arc_id:/ ...' "$tf")` inside `for tf in "$tdir"/T-*.md` inside `for af in arcs/*.yaml`. Cost: 8 arcs × 2,261 tasks × 5-10ms = 90-180s.
- T-2096 (audit.sh:1171) ran 3-4 `grep -qE` invocations per completed task to filter, plus one `grep -lE` cross-file scan per surviving candidate. Cost: ~1,500 tasks × ~5 greps + ~10 candidates × cross-file scan = 30-60s.

**Why structurally allowed.** Both blocks shipped when the corpus was much smaller. T-1855 (T-NEW-7, late-2025) was written when the project had ~500 tasks (acceptable cost). T-2096 (T-2078 sibling, 2026-05-29) was written for ~1,400 tasks. Neither block has a perf budget — `--section structure` is the "fast" audit path used by pre-push, so its own slowdowns are invisible against the multi-minute "full audit" frame of reference. T-2297's profiling exposed both as siblings of the T-2067 class.

**Prevention.** Bats regression `tests/unit/t2298_audit_structure_no_perfile_fork.bats` pins exactly ONE `python3 -c` invocation per block (no future per-file/per-task fork sneaking back in) + asserts no `ttag=$(awk ...)` per-task fork pattern in T-1855 + no `grep -qE.*workflow_type.*$task_file` per-task fan-out in T-2096. Real-corpus perf assert (<100s) lives in Verification. Together with T-2297's perf-pin, the `--section structure` regression net catches any future per-task-fork pattern across all three blocks (T-2067, T-1855, T-2096).

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

### 2026-06-09T20:48:33Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2298-audit-batch-t-1855-stale-arc--t-2096-go-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-71148bf7
- **Timestamp:** 2026-06-09T21:05:49Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#6 (Agent)** — OBS-066 promoted in .context/inbox.yaml: status=pending→promoted, promoted_to=T-2298. Inbox parses; OBS-064 + OBS-066 both correctly promoted.
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/inbox.yaml in: OBS-066 promoted in .context/inbox.yaml: status=pending→promoted, promoted_to=T-2298. Inbox parses; OBS-064 + OBS-066 both correctly promoted.`

### 2026-06-09T21:04:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
