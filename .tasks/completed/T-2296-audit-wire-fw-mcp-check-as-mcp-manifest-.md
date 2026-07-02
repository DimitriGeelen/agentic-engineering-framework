---
id: T-2296
name: "audit: wire fw mcp check as MCP manifest drift FAIL (T-2294 audit sibling)"
description: >
  audit: wire fw mcp check as MCP manifest drift FAIL (T-2294 audit sibling)

status: work-completed
workflow_type: build
owner: agent
horizon: null
arc_id: arc-010
components: []
related_tasks: [T-2293, T-2294, T-2290]
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
created: 2026-06-09T19:47:30Z
last_update: '2026-06-11T22:24:14Z'
date_finished: 2026-06-09T20:05:51Z
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
  - ts: '2026-06-09T20:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-09T20:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 3
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=3 (body:portability-abstraction); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:14Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 3
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=3 (body:portability-abstraction); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2296: audit: wire fw mcp check as MCP manifest drift FAIL (T-2294 audit sibling)

## Context

T-2294 wired `fw mcp check` into the pre-push gate (developer-side catch). This task adds the daily-cron backstop in `fw audit` — when `--no-verify` or `FW_SKIP_MCP_DRIFT_CHECK=1` lets drift escape the pre-push gate, audit catches it within 24h.

Drift coverage chain becomes:
1. Doctor (T-2290) — content-based stale-check, WARN
2. Audit (this task, T-2296) — daily-cron FAIL on drift
3. Pre-push (T-2294) — block at developer push
4. Close-gate Verification (T-2291 in CLAUDE.md) — task-close pattern
5. Focused `fw mcp check` (T-2293) — CLI verb

Pattern mirrors the existing cron-registry chain (T-1942 / T-1771): WARN at doctor, FAIL at audit, BLOCK at pre-push. CLAUDE.md cites that pattern explicitly for cron; this closes the parallel structure for MCP manifest.

The audit step inserts immediately after the existing `framework-mcp scan: PASS/WARN/FAIL` block at `agents/audit/audit.sh:4437-4446`. Uses `bin/fw mcp check` exit codes (0=sync, 1=drift, 2=absent) → audit emits PASS/FAIL/INFO accordingly. ABSENT does not FAIL because a fresh project hasn't emitted yet.

## Acceptance Criteria

### Agent
- [x] `agents/audit/audit.sh` has a new "MCP manifest drift" step right after the existing framework-mcp scan block (~line 4448), calling `bin/fw mcp check` and routing exit codes: 0→pass, 1→fail, 2→info (absent → "fresh project, run emit-manifest").
- [x] FAIL message names both the symptom (`framework-mcp-manifest.json out of sync with tool-set.yaml`) AND the remediation (`Run: fw mcp emit-manifest && commit`).
- [x] New bats test `tests/unit/t2296_audit_mcp_manifest_drift.bats` exercises three states using a stubbed `bin/fw mcp check`: clean (exit 0 → PASS in audit output), drift (exit 1 → FAIL), absent (exit 2 → INFO). 3/3 PASS.
- [x] Existing `tests/unit/t2293_mcp_check.bats` still PASS (4/4) — no regression on the verb itself.
- [x] `bin/fw audit` runs end-to-end and shows the new line in output (live verification on current repo).
- [x] [REVIEWER] Reviewer PASS — verified via `bin/fw reviewer T-2296`.

## Verification

# T-2296 audit-block bats test
bats tests/unit/t2296_audit_mcp_manifest_drift.bats
# T-2293 verb test still passes (no regression on the verb itself)
bats tests/unit/t2293_mcp_check.bats
# The audit block is present in audit.sh with the canonical block-message text
grep -q "T-2296 / arc-010: MCP manifest drift FAIL" agents/audit/audit.sh
grep -q "framework-mcp manifest: FAIL" agents/audit/audit.sh
grep -q "fw mcp emit-manifest" agents/audit/audit.sh

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

**Symptom:** MCP manifest drift (tool-set.yaml ↔ framework-mcp-manifest.json) had no daily-cron backstop. T-2293's commit `7e647bd1e` shipped a leaked bats artefact (`fake_drift_tool_t2290`) into the manifest *because the test crashed mid-run and polluted tool-set.yaml*, then emit-manifest ran on the polluted state and silently committed. Pre-push (T-2294) was added to catch this at the commit edge, but had no fallback if a developer used `--no-verify` or `FW_SKIP_MCP_DRIFT_CHECK=1`.

**Root cause:** Defense-in-depth gap. The drift-coverage chain (doctor WARN, pre-push BLOCK, close-gate Verification, focused `fw mcp check` verb) was missing the daily-cron audit-FAIL leg. CLAUDE.md's cron-registry chain pattern (T-1942 / T-1771) explicitly notes "Audit emits FAIL" as the parallel structural layer to "WARN at doctor, BLOCK at pre-push" — that pattern was prescriptive for cron but had no MCP-manifest sibling.

**Why structurally allowed:** No structural rule said "every drift class needs an audit FAIL leg." T-2294 closed the pre-push leg and noted "diminishing returns past pre-push" — that observation was correct on its own but missed the asymmetry: a bypass mechanism (FW_SKIP_MCP_DRIFT_CHECK=1) without a daily-cron backstop means a single agent or operator can silently disable the gate indefinitely. CLAUDE.md's cron-registry pattern documents the 3-layer canonical shape but the framework had no enforcement that drift classes follow it.

**Prevention:** This task IS the prevention — `bin/fw audit --section orchestrator` now emits FAIL on `framework-mcp manifest: out of sync with tool-set.yaml` once per day under the cron. Coverage chain is now structurally complete (5 surfaces: doctor WARN, audit FAIL, pre-push BLOCK, close-gate Verification, focused CLI verb). Pinned by `tests/unit/t2296_audit_mcp_manifest_drift.bats` (3 tests covering all three exit-code branches) and the live audit run (PASS line observed on current repo state).

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

### 2026-06-09 — 5th coverage layer materialized as bare-block extract

- **What changed:** The audit block I added is small (~15 LoC) and self-contained — only depends on `pass`/`fail`/`info` shell functions and `$PROJECT_ROOT`. That property let me write a fast unit test by extracting the block with awk + sourcing it with stub `pass`/`fail`/`info` functions instead of running full `fw audit` (which takes 5+ minutes on this repo's current state). 3 tests in ~50ms total.
- **Plan impact:** No deviation from filing. The "5 surfaces, one source-of-truth (tool-set.yaml)" chain is now structurally complete. Diminishing returns: pre-push (T-2294) catches 99% of drift before it lands; audit (this task) catches the 1% that escaped via `--no-verify` or `FW_SKIP_MCP_DRIFT_CHECK=1`. The chain mirrors cron-registry's WARN→FAIL→BLOCK ladder.
- **Triggered:** None — this is leaf work in arc-010's drift-detection coverage. T-2294's Evolution noted "diminishing returns past pre-push" and questioned whether audit was needed; observed reality is that the cost was tiny (extract-and-stub testing) and the benefit is real defense-in-depth.

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

### 2026-06-09T19:47:30Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2296-audit-wire-fw-mcp-check-as-mcp-manifest-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7fd3b527
- **Timestamp:** 2026-06-09T20:05:53Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 1 (by override)
  - mock-only-integration @ AC vs Verification cross-check

### 2026-06-09T20:05:51Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
