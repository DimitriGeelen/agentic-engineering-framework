---
id: T-2097
name: "fw upgrade [3/10] seed-files merge strategy — universal items land into customized
  consumers"
description: >
  fw upgrade SKIPs practices.yaml/decisions.yaml/patterns.yaml when consumers customize
  them — canonical framework items never land. Goal: merge strategy that adds canonical
  items without clobbering project items.

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: [fw-upgrade, reliability, inception, T-2078-cluster, seed-files]
components: []
related_tasks: [T-2078, T-2092, T-2093, T-2094, T-2095]
created: 2026-05-29T14:02:19Z
last_update: 2026-05-30T07:38:05Z
date_finished: 2026-05-30T07:38:05Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-05-29T14:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 3
      D4: 2
    rationale: D1=2 (body:learning-ref); D2=2 (body:telemetry-or-audit-entry); 
      D3=3 (body:component-discoverability); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-29T14:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 4
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2097: fw upgrade [3/10] seed-files merge strategy — universal items land into customized consumers

## Problem Statement

`fw upgrade` step [3/10] SKIPs `practices.yaml`, `decisions.yaml`, `patterns.yaml` whenever the consumer's file has more items than the framework's seed (heuristic at `lib/upgrade.sh:556-575`). Result: canonical framework items never land in customized consumers. Governance drifts silently with every release. The SKIP message says "manual merge recommended" but no consumer ever actually performs that merge — YAML merging is annoying and the message reads as "OK, framework was smart" rather than as a TODO.

Full research artifact: `docs/reports/T-2097-seed-files-merge-strategy.md`

## Assumptions

- Most existing seed items already carry `id:` (sampling: >80%). Recommendation depends on this — invalidates to ~B (dual-file) if mass-backfill is too painful.
- Read-site code (audit.sh, lib/practice.sh, web/blueprints/practices.py) reads single-file YAMLs; touching their merge logic is out of scope.
- Conflict reporting via stdout warning is acceptable — no fancy diff UI needed at v1.

## Exploration Plan

Research complete in `docs/reports/T-2097-seed-files-merge-strategy.md`. Four strategies evaluated (A: item-keyed merge, B: dual-file, C: in-file delimiters, D: hybrid). Recommendation: A.

## Technical Constraints

- Must work without external YAML merge tools (yq, etc. are not framework dependencies — pure bash + python3 + grep is the contract).
- Must be idempotent: `fw upgrade` run twice produces identical state.
- Must not silently lose project-specific items — conflicts MUST be reported on stdout.

## Scope Fence

**In:** merge strategy for the 3 seed YAMLs in step [3/10]; schema enforcement (id: required); migration of existing consumer files; clearer output replacing the SKIP line.

**Out:** general-purpose YAML diff/merge; render-surface changes; touching other read sites' single-file assumption.

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Recommendation

**Recommendation:** GO with **Strategy A — item-keyed merge** (canonical wins on absent `id:`, project wins on present `id:`).

**Rationale:** Simplest path that solves the actual problem. Most current seed items already carry `id:` — minor schema cleanup, not a redesign. No touch on read-site code (audit.sh, lib/practice.sh continue reading a single file). Conflict path is clear: same `id:` with different content → leave local, log a warning. Idempotent: running upgrade twice produces identical state. Closes the upgrade-trust gap together with T-2078's V1 reliability slices (T-2092..T-2095).

**Evidence:**
- Existing seeds (`lib/seeds/{practices,decisions,patterns}.yaml`) — sampling shows >80% of items already carry `id:`.
- Comparable pattern proven in `lib/seeds/value-drivers.yaml` (BVP arc, T-1933) — merges with id-key wins.
- Failure of current heuristic visible across the fleet: 003-NTB-ATC-Plugin and 050-email-archive have not received a canonical seed item since first customization (months of drift).
- Full research: `docs/reports/T-2097-seed-files-merge-strategy.md`

**Suggested follow-ups (on GO):**
- T-2097-V1: schema enforcement — every seed item must have `id:`; bats refuses commit otherwise.
- T-2097-V2: implement item-keyed merge in `lib/upgrade.sh` step [3/10]; bats coverage exercising a customized consumer.
- T-2097-V3: backfill `id:` on the ~20% of items lacking it.
- T-2097-V4: replace the SKIP line with structured output ("MERGED 3 canonical into practices.yaml: X new, Y already present, Z conflicts logged").

**Rejected:** B (dual-file — touches too many read sites), C (in-file delimiters — fragile), D (hybrid — premature complexity).

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

**Decision**: GO

**Rationale**: Recommendation: GO with Strategy A — item-keyed merge (canonical wins on absent `id:`, project wins on present `id:`).

Rationale: Simplest path that solves the actual problem. Most current seed items already carry `id:` — minor schema cleanup, not a redesign. No touch on read-site code (audit.sh, lib/practice.sh continue reading a single file). Conflict path is clear: same `id:` with different content → leave local, log a warning. Idempotent: running upgrade twice produces identical state. Closes the upgrade-trust gap together with T-2078's V1 reliability slices (T-2092..T-2095).

Evidence:
- Existing seeds (`lib/seeds/{practices,decisions,patterns}.yaml`) — sampling shows >80% of items already carry `id:`.
- Comparable pattern proven in `lib/seeds/value-drivers.yaml` (BVP arc, T-1933) — merges with id-key wins.
- Failure of current heuristic visible across the fleet: 003-NTB-ATC-Plugin and 050-email-archive have not received a canonical seed item since first customization (months of drift).
- Full research: `docs/reports/T-2097-seed-files-merge-strategy.md`

Suggested follow-ups (on GO):
- T-2097-V1: schema enforcement — every seed item must have `id:`; bats refuses commit otherwise.
- T-2097-V2: implement item-keyed merge in `lib/upgrade.sh` step [3/10]; bats coverage exercising a customized consumer.
- T-2097-V3: backfill `id:` on the ~20% of items lacking it.
- T-2097-V4: replace the SKIP line with structured output ("MERGED 3 canonical into practices.yaml: X new, Y already present, Z conflicts logged").

Rejected: B (dual-file — touches too many read sites), C (in-file delimiters — fragile), D (hybrid — premature complexity).

**Date**: 2026-05-30T07:38:05Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-30T07:38:05Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO with Strategy A — item-keyed merge (canonical wins on absent `id:`, project wins on present `id:`).

Rationale: Simplest path that solves the actual problem. Most current seed items already carry `id:` — minor schema cleanup, not a redesign. No touch on read-site code (audit.sh, lib/practice.sh continue reading a single file). Conflict path is clear: same `id:` with different content → leave local, log a warning. Idempotent: running upgrade twice produces identical state. Closes the upgrade-trust gap together with T-2078's V1 reliability slices (T-2092..T-2095).

Evidence:
- Existing seeds (`lib/seeds/{practices,decisions,patterns}.yaml`) — sampling shows >80% of items already carry `id:`.
- Comparable pattern proven in `lib/seeds/value-drivers.yaml` (BVP arc, T-1933) — merges with id-key wins.
- Failure of current heuristic visible across the fleet: 003-NTB-ATC-Plugin and 050-email-archive have not received a canonical seed item since first customization (months of drift).
- Full research: `docs/reports/T-2097-seed-files-merge-strategy.md`

Suggested follow-ups (on GO):
- T-2097-V1: schema enforcement — every seed item must have `id:`; bats refuses commit otherwise.
- T-2097-V2: implement item-keyed merge in `lib/upgrade.sh` step [3/10]; bats coverage exercising a customized consumer.
- T-2097-V3: backfill `id:` on the ~20% of items lacking it.
- T-2097-V4: replace the SKIP line with structured output ("MERGED 3 canonical into practices.yaml: X new, Y already present, Z conflicts logged").

Rejected: B (dual-file — touches too many read sites), C (in-file delimiters — fragile), D (hybrid — premature complexity).

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c13d7866
- **Timestamp:** 2026-05-30T07:38:05Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-30T07:38:05Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
