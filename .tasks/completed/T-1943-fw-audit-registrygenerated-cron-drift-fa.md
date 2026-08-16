---
id: T-1943
name: "fw audit registry→generated cron drift FAIL (T-1942 audit-side sibling for
  daily cron detection)"
description: >
  fw audit registry→generated cron drift FAIL (T-1942 audit-side sibling for daily
  cron detection)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [arc:value-prioritisation, future-prevention, drift, cron, audit]
components: [C-004, tests/unit/test_audit_cron_registry_generated_drift.bats]
related_tasks: [T-1942, T-1771, T-1935, T-1941, T-1767]
arc_id: value-prioritisation
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-19T22:28:18Z
last_update: '2026-08-16T22:24:49Z'
date_finished: 2026-05-19T23:17:58Z
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
  - ts: '2026-05-19T22:30:01Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 1
      tier: 2
      effort: 8
    rationale: blast_radius=1 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-19T23:15:01Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); 
      F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:49Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      estimator-fidelity: 0
      D1: 4
      D2: 4
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: estimator-fidelity=0 (no-signal); D1=4 (body:structural-gate); 
      D2=4 (body:fw-audit-or-doctor); D3=2 (body:default-change); D4=2 
      (body:env-class-handled); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-1943: fw audit registry→generated cron drift FAIL (T-1942 audit-side sibling for daily cron detection)

## Context

T-1771 wired `fw audit` to detect generated→deployed cron drift as a FAIL (cron drift
means "tasks won't run", strictly more serious than fabric drift). T-1942 wired the
sibling registry→generated check into `fw doctor` as WARN.

For symmetry, `fw audit` should also detect the registry→generated leg as a FAIL — so the
daily cron catches it without an operator running doctor. Same drift class, same
"tasks may not run" consequence (the new cron entry never reaches the OS scheduler),
so the same FAIL severity applies.

This task ports the T-1942 dry-run logic into agents/audit/audit.sh adjacent to the
existing T-1771 block, sharing the same wording/exit semantics. Closes the three-leg
sync taxonomy at both audit and doctor surfaces.

## Acceptance Criteria

### Agent
- [x] `fw audit` detects registry→generated drift: when cron-registry.yaml is edited
      but `fw cron generate` is never run, audit emits a FAIL with actionable
      `Run: fw cron generate`
- [x] Drift check uses content comparison (dry-run vs on-disk source) — catches
      add/remove AND modify-in-place edits
- [x] On clean state, audit emits the existing `Cron registry in sync` PASS (no
      regression)
- [x] FAIL severity matches T-1771's generated→deployed FAIL (same "tasks won't run"
      class)
- [x] New unit test pins both directions via the existing test_audit_cron_drift.bats
      pattern (or sibling file): drifted-registry → FAIL count > 0; in-sync → PASS,
      no FAIL line
- [x] Test uses `FW_CRON_INSTALL_DIR` tmp override (existing pattern from
      test_audit_cron_drift.bats)

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

bats tests/unit/test_audit_cron_registry_generated_drift.bats
out=$(bin/fw audit --section structure 2>&1); echo "$out" | grep -qE "Cron"

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
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

## RCA

**Symptom:** A registry edit to `.context/cron-registry.yaml` (e.g., T-1935 bvp-cost-estimator-sweep entry) sat 3+ days drifted from the generated `.context/cron/agentic-audit.crontab` while `fw doctor` reported "Cron registry in sync". The new cron entry never reached the OS scheduler — silent execution failure. T-1771 had wired audit-side FAIL for generated→deployed drift, but registry→generated stayed uncovered at both doctor and audit surfaces.

**Root cause:** `fw audit`'s T-1771 cron-drift block compared only `cron_source` (generated file) against `cron_target` (deployed file). When the registry was ahead of the generated file but the generated file matched the deployed file (both stale-matching), the diff returned 0, the PASS line emitted, and no autonomous monitoring fired.

**Why structurally allowed:** Three-step sync chains (registry → generated → deployed) have THREE drift classes, not two. T-1771 covered ONE (generated→deployed). Auditing only the chain's endpoints misses middle-link drift. L-364 documented the chain in text but the enforcement only covered two of three pairings.

**Prevention:** T-1942 wired doctor WARN for registry→generated drift. T-1943 (this task) wires the same drift class into `fw audit` as FAIL — daily-cron detection without requiring operator-triggered `fw doctor`. Both surfaces use the same dry-run-and-diff approach against the on-disk generated file. L-364 strengthened with explicit three-class taxonomy and the rule "a sync-chain with N transitions has N drift classes; auditing only the endpoints misses middle-link drift". CLAUDE.md §Verification Gate updated with dual-clause cron-touching task verification command.

<!-- REQUIRED-original-template-below: REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
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

### 2026-05-19 — Two-surface coverage for the same drift class
- **What changed:** T-1942 alone wasn't enough — doctor is operator-triggered, audit is
  cron-triggered. The same drift class needs to surface at both cadences (immediate
  feedback for the operator + autonomous detection for the daily monitor) or
  drift goes unnoticed when nobody runs doctor.
- **Plan impact:** Future drift checks must be added at BOTH surfaces simultaneously,
  not just doctor. The two-surface pattern is the contract.
- **Triggered:** Adjacent extension; no new sub-tasks. Audit→doctor symmetry should be
  audited as a general rule, possibly via a structural lint — captured as future work.

<!-- REQUIRED-removed: template followed by real content above. Original template:
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

**Rationale:** Symmetric counterpart to T-1942: T-1942 wired doctor (WARN), T-1943 wires
audit (FAIL). Same drift class, same "tasks won't run" consequence as the existing T-1771
generated→deployed FAIL — so identical severity is appropriate. The dry-run Python heredoc
is reused verbatim across `fw doctor`, `fw audit`, and `fw cron generate`, so any future
fix to the generate logic propagates to all three (no triple-maintenance trap).

**Evidence:**
- `agents/audit/audit.sh:1013-1064` — new T-1943 block adjacent to the existing T-1771
  block, FAIL semantics
- `tests/unit/test_audit_cron_registry_generated_drift.bats` — 3 tests PASS (add/clean/
  modify-in-place)
- `tests/unit/test_audit_cron_drift.bats` — regression fix (test 1 now actually runs
  `fw cron generate` instead of stubbing the source file; otherwise the new T-1943 check
  correctly flags the stub as drift). All 5 existing T-1771 tests PASS
- Three surfaces now cover the three drift classes:
  - registry → generated → audit FAIL (T-1943) + doctor WARN (T-1942)
  - generated → deployed → audit FAIL (T-1771) + doctor WARN
  - deployed → executable → exec-time check (L-365, advisory)

## Decisions

### 2026-05-19 — FAIL severity (matching T-1771) vs WARN (matching T-1942)
- **Chose:** FAIL.
- **Why:** Audit's existing T-1771 cron-drift block uses FAIL on substantive drift
  because "tasks won't run" is more serious than fabric drift. Registry→generated drift
  has the same consequence (the new cron entry never reaches the OS scheduler), so
  same severity. Doctor uses WARN because it's operator-triggered and the operator
  can immediately remediate; audit runs autonomously, so FAIL is the right escalation
  level to surface in the daily summary.
- **Rejected:** WARN parity with doctor (would have under-signalled in autonomous mode).

### 2026-05-19 — Shared Python heredoc vs extracted helper
- **Chose:** Shared verbatim heredoc across doctor, audit, and `fw cron generate`.
- **Why:** Three call sites of ~30 lines each is the threshold where extraction
  starts paying off, but the extraction itself adds a new contract surface (the helper
  needs its own tests, documentation, error-handling). Inline-duplicate is acceptable
  while the logic is small and stable. Tag as future work if a 4th consumer emerges.
- **Rejected:** Extract to `lib/cron.sh _generate_dry_run` (premature abstraction).

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

### 2026-05-19T22:28:18Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1943-fw-audit-registrygenerated-cron-drift-fa.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a7823c21
- **Timestamp:** 2026-06-02T15:00:35Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-19T23:17:58Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
