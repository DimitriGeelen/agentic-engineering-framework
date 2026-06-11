---
id: T-1883
name: "Promote CTL-012 unchecked-AC check to compliance section (twin of CTL-028,
  closes detection-window for AC-drift class)"
description: >
  Promote CTL-012 unchecked-AC check to compliance section (twin of CTL-028, closes
  detection-window for AC-drift class)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [arc-grooming, audit, prevention, governance]
components: [C-004]
related_tasks: ["T-1882", "T-1846", "T-1687", "T-1870"]
arc_id: arc-grooming
created: 2026-05-17T19:03:53Z
last_update: '2026-06-11T22:24:02Z'
date_finished: 2026-05-17T19:09:57Z
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
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-1883: Promote CTL-012 unchecked-AC check to compliance section (twin of CTL-028, closes detection-window for AC-drift class)

## Context

CTL-012 is the AC-drift symmetric twin of CTL-028: when a completed task lives in
`.tasks/completed/` but has unchecked Agent ACs, P-010 was bypassed (typically by
`git mv` or `--skip-acceptance-criteria`). CTL-028 catches the metadata-side
desync (status != work-completed); CTL-012 catches the AC-side desync.

**Identical detection-window gap as CTL-028:** CTL-012 currently lives in
`oe-daily` section (07:00 cron). Pre-push audit runs
`--section structure,compliance,quality,discovery` — none trigger CTL-012.
Detection window for AC drift can be up to 24h post-ship. T-1882 closed this
window for CTL-028; this task closes it for CTL-012.

**Why CTL-012 belongs in compliance:** it shares the COMPLETED_SCAN dependency
with CTL-028 (already gated by `compliance || oe-daily` after T-1882 — line 466).
Adding CTL-012 to the same gate is near-zero marginal cost (the scan is already
running when compliance fires).

**Origin:** T-1882 sweep (option 2 in S-2026-0517) identified CTL-012 as the
strongest follow-on candidate: same detection class as CTL-028, same scan path,
same blast radius. The pattern is "L-390 detection-window meta-lesson applied
to the symmetric twin."

## Acceptance Criteria

### Agent
- [x] CTL-012 fires when audit runs with `--section compliance` (was: only fired with `--section oe-daily`)
- [x] CTL-012 still fires when audit runs with `--section oe-daily` (no regression)
- [x] `COMPLETED_SCAN` continues to populate when compliance section is requested (T-1882 wiring reused, no additional change needed)
- [x] New bats file `tests/unit/audit_ctl012_compliance_section.bats` — 5 cases (compliance, oe-daily, pre-push-profile, structure-only negative, clean PASS). All 5 PASS.
- [x] Pre-push audit profile (`--section structure,compliance,quality,discovery`) emits CTL-012 line
- [x] No new audit warnings/failures on the live tree — pre-existing CTL-012 WARNs surfaced on T-678 + T-436 (these were already firing daily; promotion just makes them visible at pre-push too)
- [x] CTL-012 does NOT fire from `--section structure` alone (negative test PASS — gate granularity, mirrors T-1882 test #8)

## Verification
cd /opt/999-Agentic-Engineering-Framework && bats tests/unit/audit_ctl012_compliance_section.bats
# Pipefail-safe per L-387 — capture-then-grep
cd /opt/999-Agentic-Engineering-Framework && out=$(bin/fw audit --section compliance 2>&1); echo "$out" | grep -q "CTL-012"
cd /opt/999-Agentic-Engineering-Framework && out=$(bin/fw audit --section oe-daily 2>&1); echo "$out" | grep -q "CTL-012"
cd /opt/999-Agentic-Engineering-Framework && out=$(bin/fw audit --section structure,compliance,quality,discovery 2>&1); echo "$out" | grep -q "CTL-012"

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

### 2026-05-17 — T-1882 wiring meant zero new dependency-init work
- **What changed:** Filed-task plan included AC #3 about `COMPLETED_SCAN` populating for compliance section. Reading audit.sh line 466 showed T-1882 had already expanded the trigger to include `compliance`. So no audit.sh init change was needed — just the CTL-012 block relocation.
- **Plan impact:** Code diff smaller than expected. Single change: relocate CTL-012 block out of oe-daily, gate with `compliance || oe-daily`.
- **Triggered:** ACs amended to reflect "reused T-1882 wiring" rather than "new wiring needed".

### 2026-05-17 — Pre-existing CTL-012 WARNs now visible at pre-push
- **What changed:** Promotion exposed 2 chronic CTL-012 WARNs (T-678, T-436) that were already firing daily but invisible at push-time. After this slice ships, every developer pre-push will see them until cleaned up.
- **Plan impact:** No regression — these WARNs already exist. But the noise floor for pre-push audit just rose by 2 lines until those tasks are remediated.
- **Triggered:** Pre-existing-task cleanup is OUT of scope for this slice. Consider filing a separate cleanup task if the WARN noise becomes a nuisance.

### 2026-05-17 — Separate test file (not append to CTL-028 file)
- **What changed:** Considered appending to `audit_ctl028_completed_status_consistency.bats` (which already has T-1882 cases). Decided to create `audit_ctl012_compliance_section.bats` — different check, different fixture (unchecked AC vs. status desync), should grow independently.
- **Plan impact:** New file (~120 lines). Pattern matches the T-1882 test naming convention (`audit_<checkid>_compliance_section.bats`).
- **Triggered:** Established a per-check convention if more promotion candidates follow (CTL-026, CTL-027).

## Decisions

### 2026-05-17 — Same gate as CTL-028 (`compliance || oe-daily`)
- **Chose:** Mirror T-1882's gate pattern exactly. CTL-012 lives in the same code region just below CTL-028.
- **Why:** Symmetry — both checks share scan path, both detect post-fact desync, both should fire at same cadences. Easier for future readers to reason about.
- **Rejected:** Promoting only to compliance (drop oe-daily). Would leave a gap if pre-push audit is bypassed via `--no-verify` (Tier-2); the daily cron remains as a backstop.

## Recommendation

**Recommendation:** GO

**Rationale:**

CTL-012 is the symmetric twin of CTL-028. Both detect the same drift class (completed/ tasks bypassed the state machine) on different dimensions (status field vs. AC checkboxes). T-1882 closed the pre-push detection-window gap for CTL-028; this slice closes the same gap for CTL-012. The L-390 meta-lesson ("detective checks in slow-cadence sections create proportional detection-window gaps") was the trigger and is now demonstrated twice — pattern strengthening.

Implementation reused T-1882's COMPLETED_SCAN wiring (no audit.sh init change), so the patch is purely the CTL-012 block relocation + gate widening. 5 regression tests pin the new behaviour including the negative gate-granularity test that mirrors T-1882's test #8.

Live tree clean: live audit emits 1 expected pass + 2 pre-existing WARNs (T-678, T-436 — chronic unchecked ACs on legacy completed tasks, unrelated to this slice). No new failure class introduced.

**Evidence:**

- agents/audit/audit.sh — CTL-012 block relocated (was inside oe-daily at line 2173, now sibling of CTL-028 after oe-daily close)
- Gated by `if should_run_section "compliance" || should_run_section "oe-daily"` — same gate as CTL-028
- tests/unit/audit_ctl012_compliance_section.bats — 5 cases, all PASS
- tests/unit/audit_ctl028_completed_status_consistency.bats — 8 cases (unchanged, all PASS — no CTL-028 regression)
- Live verify: `bin/fw audit --section compliance | grep CTL-012` → WARN T-678 + WARN T-436 + PASS line emitted
- Live verify: `bin/fw audit --section structure | grep CTL-012` → no output (gate granularity confirmed)
- Related learnings: L-390 (root pattern), T-1882 (twin slice, shipped this session)
- Sweep evidence: this slice closes the strongest remaining promotion candidate identified in T-1882's option-2 sweep. CTL-026 + CTL-027 remain as weaker follow-ons (different detection class).

## Decision

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

### 2026-05-17T19:03:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1883-promote-ctl-012-unchecked-ac-check-to-co.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b121f798
- **Timestamp:** 2026-06-02T15:00:15Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-17T19:09:57Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
