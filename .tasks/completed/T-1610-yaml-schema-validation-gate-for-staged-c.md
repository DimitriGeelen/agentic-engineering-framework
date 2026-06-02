---
id: T-1610
name: "YAML schema-validation gate for staged .context/project/*.yaml — prevent silent corruption"
description: >
  YAML schema-validation gate for staged .context/project/*.yaml — prevent silent corruption

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-30T06:56:00Z
last_update: 2026-04-30T07:24:58Z
date_finished: 2026-04-30T07:24:58Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-1610: YAML schema-validation gate for staged .context/project/*.yaml — prevent silent corruption

## Problem Statement

If a writer (consumer-local or future framework agent) emits malformed YAML into `.context/project/*.yaml`, the corruption survives all framework gates: bad write succeeds; pre-commit doesn't `yaml.safe_load`; pre-push audit's D7 emits a finding but doesn't block; push lands; downstream consumers fail at load time. Origin: T-1599 pickup from 003-NTB-ATC-Plugin reported `concerns.yaml` corruption; investigation found no framework analog *yet* but the bug class generalizes. T-403 covers detection at *read* time (Watchtower error banner); this task is prevention at *write/push* time.

## Assumptions

1. `yaml.safe_load` on staged `.context/project/*.yaml` files in pre-push catches the T-1599 corruption shape.
2. Cost is <300ms total (largest tracked file: metrics-history.yaml ~450K ~150ms).
3. Audit D7 is diagnostic, not a hard push-blocking gate — complementary, not duplicate.
4. `--no-verify` bypass is acceptable (already Tier 0 protected).

See `docs/reports/T-1610-yaml-validation-gate.md` for full spike results.

## Exploration Plan

3 spikes, each <15min — all run as part of this inception:

- **Spike 1:** Confirm `yaml.safe_load` raises on T-1599-shape corruption.
- **Spike 2:** Time `yaml.safe_load` on real framework project YAMLs.
- **Spike 3:** Read audit D7 implementation to verify complementarity.

All three spike results documented in the research artifact.

## Technical Constraints

- pre-push hook runs `python3` (already a dependency for audit + agents).
- macOS bash 3.2 compat (T-518) — gate logic must avoid `declare -A` etc.
- Hook bytes are duplicated across consumers via `fw upgrade`; change must be backward-compatible (older consumers without the gate continue to work, just without the new check).

## Scope Fence

**IN scope:**
- Pre-push hook block for `.context/project/*.yaml` (concerns, decisions, learnings, patterns, practices, metrics-history).
- Bats test in `tests/governance/test_git_hooks.bats` covering the corruption catch.

**OUT of scope (deferred):**
- `.tasks/*.md` frontmatter validation (different parse path).
- `.fabric/components/*.yaml` validation (high fan-out, deserves separate sizing).
- Typed-schema validation beyond well-formedness (substantial design — separate inception).

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

**GO if:**
- `yaml.safe_load` catches the T-1599 corruption shape (verified — Spike 1)
- Cost <500ms on real-world project YAMLs (verified — Spike 2: ~270ms ceiling)
- Complementary to existing audit D7, not duplicate (verified — Spike 3)
- Fix is scoped to a single hook block + single bats test (verified)

**NO-GO if:**
- The check produces false positives on legitimate multi-document YAMLs (NOT TRIGGERED — scope limited to single-mapping project files)
- Cost exceeds 500ms (NOT TRIGGERED — measured at ~270ms worst-case)
- Schema language ambiguity emerges (NOT TRIGGERED — well-formedness only)

## Recommendation

- **Recommendation:** GO
- **Rationale:** Bounded scope (single pre-push hook block + bats test in tests/governance/), measured cost (~270ms worst-case), complementary to T-403 (read-time) and audit D7 (diagnostic). Catches the T-1599 corruption class at the right layer (block-at-push, before cross-consumer fan-out). Reversibility trivial (revert hook block). Sized at ~30min build.
- **Evidence:**
  - Research artifact: `docs/reports/T-1610-yaml-validation-gate.md` (Spikes 1/2/3 + decision artifact)
  - T-1599 closure commit `570b74301` explicitly recommended this prevention
  - Existing pre-push hook pattern at `agents/git/lib/hooks.sh:361-461` (VERSION + lightweight-tag + audit) — new gate is structurally identical, one more `if … exit 1` block

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

<!-- REQUIRED before fw inception decide. Write your recommendation here (T-974).
     Watchtower reads this section — if it's empty, the human sees nothing.
     Format:
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence from exploration)
     **Evidence:**
     - Finding 1
     - Finding 2
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

**Decision**: GO

**Rationale**: - Recommendation: GO
- Rationale: Bounded scope (single pre-push hook block + bats test in tests/governance/), measured cost (~270ms worst-case), complementary to T-403 (read-time) and audit D7 (diagnostic). Catches the T-1599 corruption class at the right layer (block-at-push, before cross-consumer fan-out). Reversibility trivial (revert hook block). Sized at ~30min build.
- Evidence:
  - Research artifact: `docs/reports/T-1610-yaml-validation-gate.md` (Spikes 1/2/3 + decision artifact)
  - T-1599 closure commit `570b74301` explicitly recommended this prevention
  - Existing pre-push hook pattern at `agents/git/lib/hooks.sh:361-461` (VERSION + lightweight-tag + audit) — new gate is structurally identical, one more `if … exit 1` block

**Date**: 2026-04-30T07:24:58Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-30T07:24:58Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** - Recommendation: GO
- Rationale: Bounded scope (single pre-push hook block + bats test in tests/governance/), measured cost (~270ms worst-case), complementary to T-403 (read-time) and audit D7 (diagnostic). Catches the T-1599 corruption class at the right layer (block-at-push, before cross-consumer fan-out). Reversibility trivial (revert hook block). Sized at ~30min build.
- Evidence:
  - Research artifact: `docs/reports/T-1610-yaml-validation-gate.md` (Spikes 1/2/3 + decision artifact)
  - T-1599 closure commit `570b74301` explicitly recommended this prevention
  - Existing pre-push hook pattern at `agents/git/lib/hooks.sh:361-461` (VERSION + lightweight-tag + audit) — new gate is structurally identical, one more `if … exit 1` block

## Reviewer Verdict (v1.5)

- **Scan ID:** R-05011986
- **Timestamp:** 2026-06-02T14:58:38Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-30T07:24:58Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
