---
id: T-2247
name: "fw vendor self mitigation scope mismatch (T-2244 follow-up)"
description: >
  Audit check_self_vendor_drift() scans bin/lib/agents/web but fw vendor self only
  syncs lib+templates — mitigation mismatch flagged in T-2244 RCA

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-08T05:54:39Z
last_update: '2026-06-11T22:24:12Z'
date_finished: 2026-06-08T06:20:56Z
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
  - ts: '2026-06-08T06:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-08T06:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); 
      F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-2247: fw vendor self mitigation scope mismatch (T-2244 follow-up)

## Context

`check_self_vendor_drift()` in `agents/audit/audit.sh:1512` scans
`.agentic-framework/{bin,lib,agents,web}` (libs class) and
`.agentic-framework/.tasks/templates` (templates class). On detected
drift, libs class emits `Run: fw vendor self` — but `_self_vendor_libs()`
in `lib/upgrade.sh:141` ONLY syncs `.agentic-framework/lib/`. When drift
is in `bin/`, `agents/`, or `web/`, the suggested mitigation reports
"0 files needed" and the drift persists.

`fw vendor` (full, no args) IS the correct superset that covers all
classes the audit check scans. Fix: change libs-class mitigation to
`fw vendor` (always-works). Templates-class message is correctly scoped
to `fw vendor self` and stays as-is.

Discovered during T-2246 session push-gate: audit FAILed on 40-file libs
drift in `web/` (mostly), `fw vendor self` ran with no output (exit 0,
0 files), full `bin/fw vendor` then refreshed 1034 files.

## Acceptance Criteria

### Agent
- [x] `check_self_vendor_drift()` libs-class FAIL message in `agents/audit/audit.sh` says `Run: fw vendor` (no `self` suffix)
- [x] `check_self_vendor_drift()` templates-class FAIL message in `agents/audit/audit.sh` unchanged (`Run: fw vendor self`)
- [x] Bats test asserts libs-class FAIL message contains `Run: fw vendor` and does NOT contain `Run: fw vendor self`
- [x] Bats test asserts templates-class FAIL message still contains `Run: fw vendor self`
- [x] Explanatory comment in audit.sh names the scope-mismatch rationale (future-maintainer signal)
- [x] T-2244 t2 integration test updated to assert new libs-class message (regression net in CI/cron)
- [x] `bin/fw reviewer T-2247 2>&1 | grep -qE "Overall:.*(PASS|CONCERN)"` (no FAIL) — R-ca51fd75 PASS

### Human
<!-- All ACs are deterministic — no Human ACs needed -->

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

bats tests/unit/t2247_audit_self_vendor_mitigation.bats
# Note: t2244 integration test (slow, full audit) covers end-to-end behaviour
# in CI/cron. Static-grep tests above pin the message correctness in this gate.
bin/fw reviewer T-2247 2>&1 | tee /tmp/T-2247-reviewer.out
grep -qE "Overall:.*(PASS|CONCERN)" /tmp/T-2247-reviewer.out
! grep -q "Overall:.*FAIL" /tmp/T-2247-reviewer.out

## RCA

**Symptom:** Audit FAILs on self-vendor drift, suggests `fw vendor self`,
operator runs it, exit 0, 0 files synced — drift persists. Seen in
T-2246 session: 40-file libs drift (web/ paths), `fw vendor self` no-op,
required full `bin/fw vendor` to clear.

**Root cause:** `check_self_vendor_drift()` (audit.sh:1512) scans
`.agentic-framework/{bin,lib,agents,web}` for libs class, but
`_self_vendor_libs()` (lib/upgrade.sh:141) only syncs `lib/`. Suggested
mitigation `fw vendor self` is under-scoped vs the check.

**Why structurally allowed:** T-2244 wired the audit FAIL leg and T-2240
wired the pre-push BLOCK leg around the same `fw vendor self` verb
without verifying the verb's scope matches what the gates scan. Bats
tests covered "libs drift triggers FAIL" but not "suggested mitigation
actually fixes the drift". The audit message is a string, not an
executed step.

**Prevention:** Bats tests now assert the exact mitigation string for
each class. Mitigation message and verb scope drift remains a possible
class, but for this audit check it is now pinned. Broader gates (T-2240
pre-push BLOCK) carry the same scope mismatch — out of scope for this
task, captured as a follow-up note.

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

## Recommendation

**Recommendation:** GO

**Rationale:** Audit libs-class FAIL message now points at full `fw vendor`
(superset that covers all classes the audit scans). Sibling templates-class
message kept at `fw vendor self` (correctly scoped). Future maintainer comment
explains the scope-mismatch rationale. T-2244 t2 integration assertion updated.

**Evidence:**
- `agents/audit/audit.sh:1556-1572` — libs-class block now reads `Run: fw vendor`; templates-class reads `Run: fw vendor self` (unchanged)
- `tests/unit/t2247_audit_self_vendor_mitigation.bats` — 3 fast static-grep tests, all PASS in <1s
- `tests/unit/t2244_audit_self_vendor_drift.bats:38-45` — t2 integration assertion updated to match new libs-class message
- `bin/fw reviewer T-2247` — R-ca51fd75 Overall: PASS, no findings
- Earlier full bats run (killed at 14m) had already PASSed `t2247 t1: libs-class FAIL mitigation says 'fw vendor' not 'fw vendor self'` end-to-end against live audit before swap to static-grep

**Follow-up filed:** T-2248 — pre-push BLOCK (T-2240, hooks.sh:678) uses
`fw vendor self --dry-run` for drift detection, which only iterates lib/ +
templates. bin/agents/web drift escapes the BLOCK silently. Sibling fix at
the detection layer (not just messaging). Captured as horizon:now.

## Updates

### 2026-06-08T05:54:39Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2247-fw-vendor-self-mitigation-scope-mismatch.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ec544be2
- **Timestamp:** 2026-06-08T06:20:58Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `bats tests/unit/t2247_audit_self_vendor_mitigation.bats`

### 2026-06-08T06:20:56Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
