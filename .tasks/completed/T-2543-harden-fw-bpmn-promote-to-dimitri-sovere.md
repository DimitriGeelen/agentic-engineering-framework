---
id: T-2543
name: "harden fw bpmn promote to Dimitri sovereignty bar: gate-level owner-enforcement + audit line + propose-not-clobber"
description: >
  harden fw bpmn promote to Dimitri sovereignty bar: gate-level owner-enforcement + audit line + propose-not-clobber

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/task-create/create-task.sh, tests/unit/create_task.bats, tests/unit/test_bpmn_promote.py, tools/bpmn_promote.py]
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
created: 2026-07-18T10:34:41Z
last_update: 2026-07-18T10:43:30Z
date_finished: 2026-07-18T10:43:30Z
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

# T-2543: harden fw bpmn promote to Dimitri sovereignty bar: gate-level owner-enforcement + audit line + propose-not-clobber

## Context

Dimitri's go/no-go bar for the write-out promote work (relayed via 832, rail offset 60) is
STRICTER than 832's §3b contract that T-2542 built against. T-2542 shipped caller-level
enforcement (promote hard-codes owner:human) + provenance + reconcile. Dimitri requires three
things to be **gates, not conventions** — "if any can only be a convention, it flips to NO-GO":
(1) owner:human/captured un-overridable **AT THE GATE** — `fw task create` itself refuses a
non-human/captured promote-origin create, keyed off an origin marker, so a future *caller* bug
can't reopen the hole; (2) `--write` leaves a persistent audit line (no silent `.tasks/` writes);
(3) changed→**propose-not-clobber** (never auto-mutate a materialized task). This task closes the
gap from T-2542's caller-level enforcement to Dimitri's gate-level bar. Rail offset 60.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] **Gate-level enforcement:** `create-task.sh` refuses a promote-origin create (marked via env `FW_TASK_ORIGIN=bpmn-promote`) unless `owner=human` AND status=captured (no `--start`) — a promote-origin create with `--owner agent` OR `--start` exits non-zero with an actionable message naming the violation. Non-promote-origin creates are UNAFFECTED (normal `fw task create` behaviour unchanged)
- [x] **promote routes through the gate:** `bpmn_promote.create_via_gate` sets `FW_TASK_ORIGIN=bpmn-promote` so its creates are enforced by the gate (defense-in-depth: promote still passes owner:human, but the gate is now the backstop — a caller bug is refused, not silently written)
- [x] **Audit line:** each `--write` materialization (create) appends a persistent, structured line to `.context/working/.bpmn-promote-audit.jsonl` (ts, uid, task_id, sha, action, source_diagram) — no silent `.tasks/` writes
- [x] **propose-not-clobber:** a changed proposal (sha differs from recorded) is NEVER auto-written — no silent provenance refresh; it is flagged for human review regardless of captured/touched state (T-2542's `changed+captured→refresh` auto-mutation is removed)
- [x] Unit tests cover: gate refuses agent-owner promote-origin, gate refuses `--start` promote-origin, gate allows human+captured promote-origin, non-promote-origin unaffected, audit line written on `--write` create, changed→no-write. `tests/unit/create_task.bats` stays green
- [x] `agents/bpmn/AGENT.md` roadmap notes the gate-level hardening + vendored copy synced

**Evidence (live-verified 2026-07-18):** 28/28 create_task.bats (4 new gate tests) + 15/15 promote
pytest green. Live e2e: promote-origin `--owner agent` → gate BLOCKED, no task written; `promote --write`
created 3 tasks + wrote 3 structured audit lines to `.bpmn-promote-audit.jsonl`; stale-sha proposal →
`[PROPOSE]` not clobbered (content intact), others no-op.

### Human
All acceptance criteria are agent-verifiable (gate behaviour + audit line + reconcile are
deterministic; unit + bats tests). No render surface, no subjective judgment.

## Verification

bats tests/unit/create_task.bats
python3 -m pytest tests/unit/test_bpmn_promote.py -q

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

### 2026-07-18T10:34:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2543-harden-fw-bpmn-promote-to-dimitri-sovere.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-29861bda
- **Timestamp:** 2026-07-18T10:43:41Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `bats tests/unit/create_task.bats`

### 2026-07-18T10:43:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
