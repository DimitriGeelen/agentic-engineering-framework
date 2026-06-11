---
id: T-1882
name: "Promote CTL-028 status-drift check to compliance section (pre-push catches
  before ship)"
description: >
  Promote CTL-028 status-drift check to compliance section (pre-push catches before
  ship)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [arc-grooming, audit, prevention, governance]
components: [C-004, tests/unit/audit_ctl028_completed_status_consistency.bats]
related_tasks: ["T-1846", "T-1687", "T-1870", "T-1881"]
arc_id: arc-grooming
created: 2026-05-17T18:25:53Z
last_update: '2026-06-11T22:24:02Z'
date_finished: 2026-05-17T18:33:03Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:02Z'
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
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1882: Promote CTL-028 status-drift check to compliance section (pre-push catches before ship)

## Context

CTL-028 (T-1870, L-390) detects tasks moved to `.tasks/completed/` via `git mv` without
running through `fw task update --status work-completed`. It catches the metadata-drift
class where status remains `started-work` despite the file living in `completed/`.

**Gap:** CTL-028 is currently gated by the `oe-daily` section. Pre-push audit runs
`--section structure,compliance,quality,discovery` — none of which trigger CTL-028.
The daily cron at 07:00 catches drift, but the window is up to 24h. A drift can ship
to remote and propagate before detection.

**Origin:** T-1846 was renamed `active/` → `completed/` in commit c15b9b81 (2026-05-15)
without status transition. CTL-028 fired daily WARN starting 2026-05-16 07:00 but the
drift was only spotted today (2026-05-17, ~2 days later) during arc-grooming review.
T-1687 commit 78d00388 fixed the metadata. This task closes the detection-window gap.

**Fix:** promote CTL-028 from `oe-daily` to `compliance` section. Pre-push audit already
includes compliance, so any future `git mv → completed/` without state-machine transition
fails (WARN-level) before push. CTL-028 stays in oe-daily output too (compliance is a
subset trigger).

## Acceptance Criteria

### Agent
- [x] CTL-028 fires when audit runs with `--section compliance` (was: only fired with `--section oe-daily`)
- [x] CTL-028 still fires when audit runs with `--section oe-daily` (no regression)
- [x] `COMPLETED_SCAN` is populated when compliance section is requested (dependency wiring)
- [x] Regression tests added to `tests/unit/audit_ctl028_completed_status_consistency.bats` — 4 new T-1882 cases exercise compliance / oe-daily / pre-push-profile / structure-only paths; all 8 PASS
- [x] Pre-push audit (`bin/fw audit --section structure,compliance,quality,discovery`) emits CTL-028 line in output
- [x] No new audit warnings/failures introduced on the live tree (regression check)

## Verification
cd /opt/999-Agentic-Engineering-Framework && bats tests/unit/audit_ctl028_completed_status_consistency.bats
# Regression: live audit still passes (pipefail-safe per L-387 — capture-then-grep)
cd /opt/999-Agentic-Engineering-Framework && out=$(bin/fw audit --section compliance 2>&1); echo "$out" | grep -q "CTL-028"
cd /opt/999-Agentic-Engineering-Framework && out=$(bin/fw audit --section oe-daily 2>&1); echo "$out" | grep -q "CTL-028"
cd /opt/999-Agentic-Engineering-Framework && out=$(bin/fw audit --section structure,compliance,quality,discovery 2>&1); echo "$out" | grep -q "CTL-028"

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

### 2026-05-17 — Existing test file already covers fixture pattern
- **What changed:** Filed-task ACs proposed a new test file `audit_ctl028_compliance_section.bats`. Reading the existing test suite revealed `audit_ctl028_completed_status_consistency.bats` already has the 4-test scaffold (fixture, scan helper, audit.sh integration). Splitting into two files would duplicate the `_write_task` helper + setup/teardown.
- **Plan impact:** AC #4 amended — append 4 new cases (compliance, oe-daily-regression, pre-push-profile, structure-only-negative) to the existing file rather than creating a new one. Cleaner co-location of all CTL-028 tests.
- **Triggered:** Test count went 4 → 8 in one file. Naming convention `CTL-028 T-1882: …` prefixes the new cases so future readers can grep for the slice.

### 2026-05-17 — Negative test added for gate granularity
- **What changed:** Original plan only verified positive paths (CTL-028 fires from compliance, oe-daily, pre-push). Realised a negative test was needed: confirm `--section structure` alone does NOT fire CTL-028. Without this, a future refactor could silently widen the gate and the regression would slip.
- **Plan impact:** AC #4 now covers 4 paths not 2.
- **Triggered:** Test #8 — explicit assertion `[[ "$output" != *"CTL-028"* ]]` under `--section structure`.

## Decisions

### 2026-05-17 — Section assignment: compliance, not structure
- **Chose:** Gate CTL-028 with `compliance || oe-daily`. Promote to compliance section.
- **Why:** (a) Pre-push audit already includes compliance — minimal change to scope. (b) Compliance is semantically correct: CTL-028 checks state-machine compliance (started-work in completed/ violates the lifecycle), not directory structure (which is about file layout). (c) Avoids expanding the structure section which is intentionally fast.
- **Rejected:** Adding CTL-028 to structure section — would force COMPLETED_SCAN to populate even when only structure was requested (e.g. fast cron 30m run), unnecessary work for the common case. Also semantically off (CTL-028 isn't a structure check).
- **Rejected:** Adding a new "drift" section — yet-another-section grows the section taxonomy with one check. Not worth the overhead vs. reusing compliance.

### 2026-05-17 — Physical relocation of CTL-028 block (not just gate-widening)
- **Chose:** Move the CTL-028 block out of the oe-daily `if` block (lines 2024-2402) into its own conditional gated on `compliance || oe-daily`.
- **Why:** The original location was nested inside `if should_run_section "oe-daily"` — wrapping with an inner `compliance || oe-daily` gate would have been dead code (the outer gate only opens when oe-daily is requested). Physical relocation outside the oe-daily block is the only way to make `--section compliance` fire CTL-028.
- **Rejected:** Duplicating the check in compliance section — adds maintenance burden; the underlying check is the same.

## Recommendation

**Recommendation:** GO

**Rationale:**

CTL-028 status-drift class shipped on 2026-05-15 (T-1846 git mv → completed/ without state-machine transition) was caught by the daily 07:00 cron audit on 2026-05-16 but only spotted manually 2026-05-17. The detection window for this drift class was up to 24h post-ship. With CTL-028 now gated by compliance, the pre-push audit catches the same class at commit-push time — before propagation.

The change is structurally minimal (~30-line audit.sh diff, 1 trigger expansion, 1 block relocation) and the regression suite confirms both code paths (compliance, oe-daily) still surface drift via the audit.sh integration path. The negative test (structure-only does NOT fire CTL-028) pins gate granularity so future widening is detected.

No new audit warnings/failures introduced on the live tree (verified: `bin/fw audit --section structure,compliance,quality,discovery` runs clean).

**Evidence:**

- audit.sh:466 — COMPLETED_SCAN trigger expanded to include `compliance`
- audit.sh:2333-2362 — CTL-028 block relocated, gated by `compliance || oe-daily`
- tests/unit/audit_ctl028_completed_status_consistency.bats — 4 new T-1882 tests appended (8 total, all PASS)
- Live verify: `bin/fw audit --section compliance | grep CTL-028` → PASS line emitted
- Live verify: `bin/fw audit --section oe-daily | grep CTL-028` → PASS line emitted (no regression)
- Live verify: `bin/fw audit --section structure,compliance,quality,discovery | grep CTL-028` → PASS line emitted
- Related: T-1687 commit 78d00388 (T-1846 status-drift remediation that surfaced this prevention gap)
- L-390 (the underlying learning: git mv bypasses state machine)

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-17T18:25:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1882-promote-ctl-028-status-drift-check-to-co.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-cfd841f1
- **Timestamp:** 2026-06-02T15:00:15Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-17T18:33:03Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
