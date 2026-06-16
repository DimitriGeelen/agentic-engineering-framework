---
id: T-2420
name: "PreToolUse hook: detect `### Human` outside `## Acceptance Criteria` (T-2418
  GO)"
description: >
  Implement T-2418 GO. Add PreToolUse Write/Edit hook `check-task-ac-structure` for
  .tasks/{active,completed}/T-*.md that refuses save when `### Human` heading exists
  outside the `## Acceptance Criteria` section. Override env-var FW_ALLOW_AC_STRUCTURE_DRIFT=1
  (logged Tier-2 per T-1890 contract). Also: corpus sweep — find existing offenders,
  decide grandfathering vs migration.

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
created: 2026-06-16T12:01:29Z
last_update: 2026-06-16T12:19:24Z
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
  - ts: '2026-06-16T12:15:04Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-16T12:15:06Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2420: PreToolUse hook: detect `### Human` outside `## Acceptance Criteria` (T-2418 GO)

## Context

Implements T-2418 GO. T-2417's close cascade lost a Human AC because `## Build summary` was inserted between `### Agent` and `### Human`, closing the `## Acceptance Criteria` block before the parser reached the Human AC (`sed -n '/^## Acceptance Criteria/,/^## /p'` in `update-task.sh`). PreToolUse hook prevents the structural error at write-time across all 1900+ tasks.

## Acceptance Criteria

### Agent
- [x] Hook script `agents/context/check-task-ac-structure.py` exists, executable, and parses task files for the `### Human` outside `## Acceptance Criteria` structural error.
- [x] Hook wrapper `agents/context/check-task-ac-structure.sh` execs the python script (same pattern as check-inception-decisions.sh).
- [x] Override env-var `FW_ALLOW_AC_STRUCTURE_DRIFT=1` bypasses with Tier-2 log entry to `.context/working/.gate-bypass-log.yaml` per T-1890 contract.
- [x] Hook exits 0 when: no `### Human` heading; OR `### Human` is positioned between `## Acceptance Criteria` and the next `## ` heading; OR file is not under `.tasks/{active,completed}/T-*.md`.
- [x] Hook exits 2 (block) under agent control (`$CLAUDECODE=1`) when `### Human` appears outside the AC block.
- [x] Hook exits 0 with stderr NOTE when not under agent control (matches check-inception-decisions pattern).
- [x] bats test suite `tests/unit/check_task_ac_structure.bats` covers: malformed blocks under CLAUDECODE; correct structure passes; no-Human passes; override env-var allows + logs; non-task path passes through; Edit + MultiEdit synth paths; outside-agent advisory mode. 10/10 tests pass.
- [x] Corpus sweep ran (25 offenders / 2385 tasks = 1.0%); grandfather-via-no-worse-than decision recorded in `## Decisions`.

### Human
- [ ] [REVIEW] Hook wired in `.claude/settings.json` (PreToolUse Write|Edit matcher) — agent cannot self-apply due to B-005.
  **Steps:**
  1. Open `.claude/settings.json` and locate the `PreToolUse` matcher block with `"matcher": "Write|Edit"` (around line 63 — same block that has `check-inception-decisions`).
  2. Add a new hook entry after the existing `check-inception-schema` entry (just before the closing `]` of that hooks array):
     ```json
     ,
     {
       "type": "command",
       "command": "/opt/999-Agentic-Engineering-Framework/bin/fw hook check-task-ac-structure"
     }
     ```
  3. Save and refresh enforcement baseline: `cd /opt/999-Agentic-Engineering-Framework && bin/fw enforcement baseline`
  4. Live-fire test: in a fresh Claude Code session, ask the agent to write a task file with `### Human` placed after a `## ` heading. Hook should block with `TASK AC STRUCTURE ERROR — T-2420 guard`.
  **Expected:** Hook fires on the next agent Write/Edit of a malformed `.tasks/{active,completed}/T-*.md` file; `fw doctor` reports no enforcement baseline FAIL.
  **If not:** Re-check JSON syntax (`python3 -m json.tool .claude/settings.json`); confirm the hook line shape matches its siblings.
## Recommendation

**Recommendation:** GO

**Rationale:** The hook closes a multi-year-horizon structural silent-failure class (1900+ task files vulnerable; 25 historical offenders found). Implementation mirrors the T-1984 check-inception-decisions pattern, which has been stable since 2026-04 — same dispatcher, same wrapper shape, same Tier-2 bypass contract. The no-worse-than grandfather logic means existing offenders cause no new friction; only writes that introduce OR worsen malformation are blocked. All 10 bats tests pass. The remaining Human AC is the structural wiring step that B-005 reserves for the operator.

**Evidence:**
- Hook script: `agents/context/check-task-ac-structure.py` (197 lines) + `check-task-ac-structure.sh` wrapper
- Test suite: `tests/unit/check_task_ac_structure.bats` — 10/10 pass
- Corpus sweep: 25 offenders / 2385 tasks (1.0%) — 7 active, 18 completed
- Grandfather logic verified: bats t9 confirms edits to pre-existing offenders pass when count unchanged
- Override mechanism verified: bats t4 + smoke test confirm `FW_ALLOW_AC_STRUCTURE_DRIFT=1` allows + logs Tier-2 entry
- Cross-fixture smoke run: malformed Write blocks with full block-message stderr (exit 2); correct Write allows (exit 0)

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
python3 -c "import ast; ast.parse(open('agents/context/check-task-ac-structure.py').read())"
bash -n agents/context/check-task-ac-structure.sh
out=$(bats tests/unit/check_task_ac_structure.bats 2>&1); echo "$out" | grep -q "^ok 10 "

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

### 2026-06-16 — grandfather vs migrate for the 25 historical offenders
- **Chose:** Grandfather via no-worse-than logic encoded in the hook itself.
- **Why:** The hook compares old vs new content's malformed-Human count. It only blocks when this edit INTRODUCES or WORSENS the count. Pre-existing offenders (7 in active/, 18 in completed/) cause zero new friction — legitimate updates to those files pass through unchanged. New files cannot become malformed. Edits that fix existing malformation also pass. This makes the rollout zero-risk and removes the case for retroactive file rewrites.
- **Rejected:**
  - **Migrate all 25 (retroactive fix):** would require 25 file edits, would touch completed-task archive (architectural smell), and the partial-complete bug those files exposed is already history — the parser saw 0/0 Human ACs at THEIR close, no future re-completion is expected.
  - **Migrate active/7 only:** would still touch 7 files for marginal benefit; the no-worse-than logic handles future edits to those 7 cleanly.
  - **Block hard regardless of old count:** would create spurious blocks on every legitimate edit to a grandfathered file, forcing the agent to bypass via `FW_ALLOW_AC_STRUCTURE_DRIFT=1` repeatedly. False-positive cost dominates.

### 2026-06-16 — match check-inception-decisions pattern (not roll own)
- **Chose:** Mirror the T-1984 hook layout: .py impl + .sh wrapper, parse-old-then-new, agent-vs-human exit-code gating, Tier-2 bypass log shape, block-message format.
- **Why:** That pattern has shipped 2026-04 (T-1984), survived 6+ revision rounds, and is the closest neighbour by use-case (validates structural facts inside task files at Write/Edit). Mirroring it minimises divergent maintenance and gives reviewers a familiar shape.
- **Rejected:** Custom output shape (no benefit, breaks reviewer expectations); shellscript-only (would require re-implementing the section parser in bash — fragile).

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-06-16T12:01:29Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2420-pretooluse-hook-detect--human-outside--a.md
- **Context:** Initial task creation

### 2026-06-16T12:19:24Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-752fcad4
- **Timestamp:** 2026-06-16T12:26:15Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
