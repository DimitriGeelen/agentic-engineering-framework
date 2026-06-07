---
id: T-2244
name: "audit self-vendor drift FAIL — F2 N×M daily-cron backstop"
description: >
  audit self-vendor drift FAIL — F2 N×M daily-cron backstop

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-07T21:21:10Z
last_update: 2026-06-07T23:08:03Z
date_finished: 2026-06-07T23:08:03Z
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
  - ts: '2026-06-07T21:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-07T21:30:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2244: audit self-vendor drift FAIL — F2 N×M daily-cron backstop

## Context

The F2 N×M chain closed two of the three self-vendor drift surfaces:
- **T-2240 + T-2241** — pre-push gate (developer-triggered, BLOCK level)
- **T-2243** — `fw doctor` Check 2b (any-time inspection, WARN level)

The third surface — the daily-cron'd backstop — is still uncovered. `agents/audit/audit.sh` has zero references to `.agentic-framework/`, `self_vendor`, or `self-vendor`. If a developer pushes with `FW_SKIP_SELF_VENDOR_CHECK=1` (bypass logged Tier-2) and forgets to follow up, the divergence sits unflagged until someone notices manually. Daily audit cron is the BCP backstop: it catches drift that slipped past the developer-facing gates.

Scope: add a new `check_self_vendor_drift()` function to `agents/audit/audit.sh` modeled directly on `bin/fw` Check 2b (T-2243). Per-class counters (libs + templates), FAIL level (audit's daily cron uses FAIL to surface in the report email and Watchtower). One bats test mirroring the T-2243 shape.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `agents/audit/audit.sh` carries a `check_self_vendor_drift()` function that walks both classes (`.agentic-framework/{bin,lib,agents,web}` + `.agentic-framework/.tasks/templates/`) and emits a FAIL line per class with non-zero drift count, OR a PASS line when both classes are clean. Function is invoked from the main audit flow.
- [x] FAIL message names `fw vendor self` (templates+libs syncer) or `fw vendor` (full sync) as remediation — same vocabulary as the pre-push gate and `fw doctor` Check 2b so the operator's mental model stays consistent across all three surfaces.
- [x] Bats test `tests/unit/t2244_audit_self_vendor_drift.bats` exercises two deterministic drift states: (1) libs-only drift → FAIL line names libs class + names the mutated file + names `fw vendor self` remediation, (2) templates-only drift → same for templates class. 2/2 PASS. (PASS-state coverage skipped — framework repo carries ~64 day-to-day libs drifts day-to-day so the global "no drift" assertion is not reliable; the PASS path is exercised organically every time both classes are clean in production.)
- [x] [REVIEWER] Reviewer PASS — verified via `bin/fw reviewer T-2244`.

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

# Verify the new check function exists in audit.sh. Direct file grep — no pipe,
# no SIGPIPE risk (audit.sh is 4857 lines; L-387 capture-then-grep pattern
# SIGPIPEs on large files per T-2243 close-gate lesson).
grep -q "check_self_vendor_drift" agents/audit/audit.sh

# Bats coverage for both classes (libs + templates)
bats tests/unit/t2244_audit_self_vendor_drift.bats

# Reviewer verdict (L-387 capture-then-grep is safe for fw reviewer — output is small)
out=$(bin/fw reviewer T-2244 2>&1); echo "$out" | grep -qE "Overall:.*PASS"

## Recommendation

**Recommendation:** GO

**Rationale:** F2 N×M closure third surface shipped. T-2240 (pre-push BLOCK) and T-2243 (doctor WARN) already cover developer-triggered + any-time inspection. T-2244 adds the daily-cron'd backstop at audit's structure section — catches drift that slipped past developer gates (FW_SKIP_SELF_VENDOR_CHECK=1 bypass + forgot to follow up, or non-developer-driven divergence). Per-class counter split mirrors T-2243 implementation exactly, so operator's mental model stays consistent across all three surfaces. Function emits class-named FAIL lines with `fw vendor self` remediation — verified manually via live audit invocation (40 libs class + 1 templates class drift correctly emitted in test fixture state). 2/2 bats PASS deterministically (libs-only drift → libs FAIL; templates-only drift → templates FAIL). Setup/teardown back up + restore both sentinel files; --quiet omitted from test invocation because that flag suppresses the FAIL output the assertions need. PASS-state global assertion skipped per L-389 (framework repo carries day-to-day libs drift; production exercises PASS path organically when both classes are clean).

**Evidence:**
- `agents/audit/audit.sh:1502-1567` — `check_self_vendor_drift()` function added, invoked at structure section bottom
- `tests/unit/t2244_audit_self_vendor_drift.bats` — 2 deterministic tests (t2 libs class, t3 templates class), 2/2 PASS
- Live audit invocation in fixture state emits both `[FAIL] Self-vendor drift: libs class — 40 file(s) out of sync (T-2244)` AND `[FAIL] Self-vendor drift: templates class — 1 file(s) out of sync (T-2244)` with `fw vendor self` remediation
- F2 N×M chain complete: T-2240 pre-push BLOCK (developer-triggered) + T-2243 doctor WARN (any-time inspection) + T-2244 audit FAIL (daily cron backstop)

## RCA

**Symptom:** F2 N×M self-vendor drift class had only 2 of 3 surfaces covered. Daily-cron'd backstop was uncovered — divergence sat unflagged when developer bypassed pre-push gate (`FW_SKIP_SELF_VENDOR_CHECK=1`) without follow-up, or when divergence was introduced by non-developer-driven processes (cron, automation, mis-merged branch).

**Root cause:** `agents/audit/audit.sh` had zero references to `.agentic-framework/`, `self_vendor`, or `self-vendor`. The pre-push gate (T-2240) and doctor inspection (T-2243) were both developer-triggered surfaces — neither caught drift introduced when no developer was present, or by developers who bypassed and never followed up.

**Why structurally allowed:** The F2 N×M chain was planned as three surfaces but shipped two-of-three first: pre-push BLOCK (T-2240) + doctor WARN (T-2243). The audit FAIL leg was filed (this task) but not coupled to the prior two — they shipped independently, leaving a window where the chain was incomplete. The class-counter pattern split (libs + templates) added in T-2241 had to be retroactively mirrored when this task landed.

**Prevention:** Three coupled surfaces now in place, each at a different cadence: pre-push (developer-event), doctor (any-time inspection), audit (daily cron). Each names the SAME remediation verb (`fw vendor self`) so operator mental model stays unified. Bats test t2244 with deterministic libs+templates fixtures locks the FAIL emission shape — regression of either class breaks bats immediately. Audit's daily cron is the BCP backstop: if the other two are bypassed, the FAIL line surfaces in the audit report email within 24h.

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

### 2026-06-07T21:21:10Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2244-audit-self-vendor-drift-fail--f2-nm-dail.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-89896da1
- **Timestamp:** 2026-06-07T23:24:16Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-07T23:08:03Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
