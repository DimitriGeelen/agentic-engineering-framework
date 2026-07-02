---
id: T-2410
name: "check-active-task hook: false positives block legitimate fw commands"
description: >
  Bug report: check-active-task PreToolUse hook produces false positives blocking
  legitimate fw commands when focus is on a completed task.

status: started-work
workflow_type: build
owner: human
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
created: 2026-06-15T19:55:42Z
last_update: '2026-07-02T16:15:08Z'
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
bvp_scores_proposed:
  - ts: '2026-06-15T21:12:52Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-07-02T16:15:08Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F-AUTONOMY: 0
      audit_severity: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F-AUTONOMY=0 (no-signal); audit_severity=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-15T21:15:04Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 4
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=4 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-07-02T13:45:04Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2410: check-active-task hook: false positives block legitimate fw commands

## Context

The check-active-task PreToolUse hook produces two false positives, both when the focused task is work-completed under CLAUDECODE=1.

Case 1 (task-ID substring match in free text): `fw inception start` / `fw work-on` were BLOCKED as "Cannot modify completed task T-065" only because that completed task ID appeared inside an unrelated `--rationale` string. The byte-identical command with the ID reworded out of the prose succeeded. The hook scans the whole command string for any task-ID token and treats a mention as a modification target.

Case 2 (non-mutating subcommand blocked under completed focus): `fw upstream --help` and `fw upstream status` (read-only, reference no task) were BLOCKED as "Cannot modify files under a completed task" purely due to focus state.

Suggested fix: match task IDs only in argument positions that denote a target (the task-ref arg), not anywhere in free text such as `--rationale`/`--body`; and exempt read-only/query subcommands (`upstream status`/`--help`, `list`) regardless of focus status, like the existing `work-on`/`task` unblock exemptions.

Reported from field install /mame/project. A GitHub-mirror issue (#19) was filed in error; this is the canonical onedev-side report.

## Acceptance Criteria

### Agent
- [x] check-active-task matches task IDs only in target-arg positions, not in free-text args (regression test for the --rationale case) — `tests/unit/check_active_task_fp_fix.bats:CONTROL case1`. Note: the existing T-1730 focus-drift regex anchors are already scoped (`fw task update T-NNNN`, `fw context add-* --task T-NNNN`, `git commit … T-NNNN:`); the reported `fw inception start --rationale "T-065 …"` doesn't actually trip them — pinned as regression guard.
- [x] read-only fw subcommands (upstream status/--help, list) are exempt from the completed-focus block (regression test) — two layers:
      (a) universal `--help`/`--version` early exit in `agents/context/check-active-task.sh` after the fw-hook fast-path, and
      (b) `upstream status|list|info|show|help` added to fw safe-sub-list in `agents/context/lib/safe-commands.sh`. Mutating sub-verbs (e.g. `upstream pin`) still block under work-completed focus — pinned by `CONTROL: fw upstream pin … still blocks`.
- [x] `bash -n` passes on both edited files (L-408)
- [x] 7/7 new bats PASS; 35/35 existing hook bats PASS (no regression).

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

bash -n agents/context/check-active-task.sh
bash -n agents/context/lib/safe-commands.sh
bats tests/unit/check_active_task_fp_fix.bats
bats tests/unit/check_active_task_memory_exempt.bats
bats tests/unit/check_active_task_switch_focus.bats
bats tests/integration/check_active_task.bats

## Recommendation

**Recommendation:** GO

**Rationale:** Two narrow, targeted fixes. (a) Universal `--help`/`--version`
exemption — read-only by convention in every CLI tool; eliminates an entire
class of false positives where help reads were blocked under work-completed
focus. (b) `upstream` added to fw safe-sub-list for read-only sub-verbs
(`status|list|info|show|help`) — mutating sub-verbs (`pin`/`set`/`sync`) still
hit the gate. Conservative: doesn't widen the safe-list further than necessary.
Pinned by 7/7 new bats with CONTROL cases proving the exemptions don't leak
(mutating `fw upstream pin` still blocks).

Case 1 (task-ID in --rationale) doesn't reproduce on current code — the T-1730
regex anchors are already scope-correct. Test is a regression guard.

**Evidence:**
- `agents/context/check-active-task.sh:69-79` — universal `--help`/`--version` exemption
- `agents/context/lib/safe-commands.sh:100-114` — upstream sub-verb gate
- 7/7 new bats PASS (incl. 3 CONTROL cases)
- 35/35 existing hook bats PASS (no regression)
- `bash -n` exit 0 on both files

## RCA

**Symptom:** Operator-reported in field install (`/mame/project`):
1. `fw upstream --help` and `fw upstream status` blocked under work-completed
   focus with "Cannot modify files under a completed task" — pure read needs
   shouldn't require a started task.
2. `fw inception start --rationale "T-065 was the proof of concept"` reportedly
   blocked as "modifying T-065" — though under current code this does NOT
   actually reproduce (regex anchors are scope-correct).

**Root cause:**
1. `is_bash_safe_command` in `lib/safe-commands.sh` exempts `doctor|metrics|
   audit|version|resume|help|status|fabric|gaps|promote` and a few sub-verb
   helpers but had no entry for `upstream` — so any `fw upstream <anything>`
   fell through to the work-completed-focus block.
2. No universal `--help`/`--version` short-circuit. Any new fw verb not in
   the safe-list would block its `--help` form by default — repeat of the
   same class.

**Why structurally allowed:** the safe-list is verb-by-verb enumeration; new
verbs (`upstream` added without updating the list) silently fall into the
"unsafe" bucket. The hook's correct behavior on read-only intent was coupled
to manual list maintenance.

**Prevention:** the `--help`/`--version` exemption breaks the coupling for
help-reads regardless of which verb. The verb-list remains enumeration but
adding any new fw verb no longer leaks at the help affordance. bats CONTROL
cases pin that mutating sub-verbs (`upstream pin`) still gate properly.

## RCA-old

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

### 2026-06-15T19:55:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2410-check-active-task-hook-false-positives-b.md
- **Context:** Initial task creation

### 2026-06-15T21:12:52Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e3674cb9
- **Timestamp:** 2026-06-15T21:16:08Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
