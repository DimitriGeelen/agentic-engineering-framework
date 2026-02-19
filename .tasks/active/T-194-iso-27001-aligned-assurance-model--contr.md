---
id: T-194
name: "ISO 27001-aligned assurance model — control register, OE testing, risk-driven cron redesign"
description: >
  Deep inception (3-5 sessions): Formalize AEF's enforcement mechanisms using ISO 27001's
  four-level assurance model (Risk → Control Design → Operational Effectiveness → Audit).
  The framework has ~11 controls built organically but no control register, no formal risk
  linkage, no OE testing, and a cron audit system that reruns structural checks instead of
  verifying controls work. This inception explores whether ISO 27001 structure fits AEF,
  designs the control register, and redesigns cron jobs as proper OE testing.
  Origin: T-151 review revealed specification completed without human dialogue, and the
  cron system built from it (T-184) doesn't match the original antifragility intent.

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: [iso27001, assurance, controls, antifragility, cron]
related_tasks: [T-151, T-184]
created: 2026-02-19T15:50:03Z
last_update: 2026-02-19T16:00:29Z
date_finished: null
---

# T-194: ISO 27001-aligned assurance model — control register, OE testing, risk-driven cron redesign

## Problem Statement

AEF has ~11 enforcement mechanisms (hooks, gates, rules) built organically in response to problems encountered during development. These work — but they suffer from three gaps:

1. **No control register.** Controls exist as scattered scripts and CLAUDE.md rules. No single document maps: what risk does this control address? What is its expected behavior? How do we know it's working?

2. **No operational effectiveness testing.** When hooks silently fail (observed: hooks snapshot at session start, flat format silently fails, `((x++))` breaks `set -e`), nothing detects the failure until consequences surface. The cron audit system (T-184) was meant to fill this gap but instead just reruns structural checks.

3. **No risk-driven design.** Controls were added reactively ("T-057 showed agents check behavior ACs without testing → add T-193"). The risk-to-control linkage is implicit in task history but not formalized. New controls aren't assessed for design adequacy.

**For whom:** Framework maintainers (human + agent) who need confidence that governance is actually working.

**Why now:** At 11 controls, 190+ tasks, and 540+ commits, the framework is mature enough that control failures have real consequences. T-151's own journey (specification completed by agent in 2 minutes without human review) demonstrates the gap.

## ISO 27001 Four-Level Model (Reference)

| Level | ISO 27001 Definition | AEF Equivalent | Current Status |
|-------|---------------------|---------------|----------------|
| **1. Risk** | Risk assessment (likelihood × impact), risk register, treatment options | `gaps.yaml` (partial) | Informal — gaps capture spec-reality gaps, not structured risks |
| **2. Control Design** | Controls selected to mitigate risks, design adequacy assessed | Hooks, gates, CLAUDE.md rules | Exists but undocumented as controls — no register, no risk linkage |
| **3. Operational Effectiveness** | Controls working in practice, consistently, over time — tested via evidence | Cron audits (supposed to be) | Weak — reruns structural checks, not control-specific OE tests |
| **4. Audit** | Independent verification of all three levels above | `fw audit` | Mixed — combines structural + some OE, no clear separation |

## Current Control Inventory (from our review)

| Control | Type | Risk it mitigates | Design doc | OE test |
|---------|------|-------------------|-----------|---------|
| `check-active-task.sh` | PreToolUse hook | Work without task governance | CLAUDE.md | Indirect (compliance cron) |
| `check-tier0.sh` | PreToolUse hook | Destructive actions without approval | CLAUDE.md | **None** |
| `budget-gate.sh` | PreToolUse hook | Context exhaustion, lost work | CLAUDE.md | **None** |
| `checkpoint.sh` | PostToolUse hook | Missed auto-handover at critical | CLAUDE.md | **None** |
| `error-watchdog.sh` | PostToolUse hook | Silent errors | CLAUDE.md | **None** |
| `commit-msg` hook | Git hook | Commits without task refs | CLAUDE.md | Indirect (traceability cron) |
| `post-commit` hook | Git hook | Unlogged bypasses | CLAUDE.md | **None** |
| P-010 AC gate | Script gate | Incomplete work marked done | CLAUDE.md | **None** |
| P-011 Verification gate | Script gate | Unverified work marked done | CLAUDE.md | **None** |
| Inception gate | Git hook | Building before GO decision | CLAUDE.md | **None** |
| CLAUDE.md behavioral rules | Instruction | Agent overreach, skipped process | Self-referential | **None** |

**Result: 11 controls, 2 with indirect OE testing, 9 with none.**

## Assumptions

- A-017: ISO 27001's four-level model (Risk → Control → OE → Audit) maps meaningfully to a software governance framework, not just information security
- A-018: Formalizing controls into a register improves maintainability without creating overhead that outweighs the benefit
- A-019: OE tests can be automated as cron jobs for most controls (observable effects exist)
- A-020: The current cron infrastructure (T-184) can be repurposed rather than replaced
- A-021: A risk register adds value at AEF's current scale (~11 controls, ~15 agents, ~50 scripts)

## Exploration Plan

### Phase 1: Risk Landscape (Session 1 — with human)
- **1a.** Identify and categorize risks that AEF's controls address. Map from observed incidents (task history, gaps.yaml, episodic memory) to risk categories.
- **1b.** Assess whether `gaps.yaml` can serve as the risk register or needs a separate structure.
- **1c.** Human dialogue: validate risk categories, prioritize, decide on risk register format.

### Phase 2: Control Register Design (Session 2 — with human)
- **2a.** Design the control register schema: what fields per control? (ID, risk, type, implementation, expected behavior, OE test, frequency, owner)
- **2b.** Populate the register for all 11 current controls.
- **2c.** Assess design adequacy for each control: "If this control works as intended, does it sufficiently mitigate the risk?"
- **2d.** Human dialogue: review register, validate design adequacy assessments.

### Phase 3: OE Test Design (Session 3 — with human)
- **3a.** For each control, design an OE test: what observable effect proves it's working? What evidence to collect?
- **3b.** Classify OE tests: which can be automated (cron), which need manual review, which need session log analysis.
- **3c.** Design the cron schedule around OE tests (not structural checks).
- **3d.** Human dialogue: review OE tests, validate frequencies, discuss alerting model.

### Phase 4: Discovery Layer Design (Session 4 — with human)
- **4a.** Design the "layer 3" discovery jobs: pattern detection, omission finding, insight generation.
- **4b.** Define what "actionable findings" means: how should discoveries surface to the human?
- **4c.** Human dialogue: prioritize discovery capabilities, review the full model.

### Phase 5: Decision (Session 5 — with human)
- **5a.** Synthesize into architecture proposal.
- **5b.** Map build tasks.
- **5c.** Go/No-Go with full evidence.

## Technical Constraints

- File-based (D4 Portability) — no databases, no external services
- Must work when no Claude session is active (cron runs independently)
- Control register must be machine-readable (YAML) for automated OE testing
- Must not significantly increase agent context consumption at session start
- Backward compatible with existing cron infrastructure (T-184)

## Scope Fence

**IN scope:**
- Risk register design (or extending gaps.yaml)
- Control register with risk linkage and OE test specifications
- OE test design for all current controls
- Cron schedule redesign around OE testing
- Discovery/insight job design (layer 3)
- Alerting model (how findings surface)

**OUT of scope:**
- Implementing the full system (build tasks come after GO)
- Formal ISO 27001 certification (we're borrowing the model, not certifying)
- External audit process (no third-party auditors)
- Controls for projects OTHER than AEF (universal design is future work)

## Acceptance Criteria

- [ ] Risk landscape mapped from observed incidents to risk categories
- [ ] Control register designed and populated for all current controls
- [ ] Design adequacy assessed for each control
- [ ] OE test designed for each control with observable effects defined
- [ ] Cron schedule redesigned around OE testing
- [ ] Discovery layer capabilities defined
- [ ] All research persisted in docs/reports/T-194-*
- [ ] Go/No-Go decision made with full rationale

## Go/No-Go Criteria

**GO if:**
- ISO 27001 model maps cleanly to AEF without forcing unnatural abstractions
- Control register is low-overhead (maintains itself via existing automation)
- OE tests can be automated for >= 8 of 11 controls
- The redesigned cron system provides materially better assurance than the current one

**NO-GO if:**
- The formalization overhead exceeds the assurance value at AEF's current scale
- OE tests require infrastructure beyond cron + bash + existing tooling
- Risk register duplicates gaps.yaml without adding new insight
- The model is too rigid for a governance framework that evolves weekly

## Verification

# Research artifacts exist
test -f docs/reports/T-194-risk-landscape.md
test -f docs/reports/T-194-control-register.md

## Decisions

### 2026-02-19 — Inception scope
- **Chose:** Full ISO 27001 four-level model adaptation (not just "fix the cron jobs")
- **Why:** T-151 review revealed the cron system was solving the wrong problem. The real gap is assurance structure: risk → control → OE → audit. Fixing just cron without this foundation would produce another ad-hoc solution.
- **Rejected:** (a) Just redesign cron frequencies — treats symptoms. (b) Only add OE tests to existing cron — misses risk linkage and discovery layer.

### 2026-02-19 — Human dialogue mandatory
- **Chose:** Every phase requires human dialogue before completion
- **Why:** T-151 was completed by agent in 2 minutes without human consultation on a human-owned specification task. This inception explicitly prevents that pattern.
- **Rejected:** Agent-driven research with human review at end — failed in T-151.

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

### 2026-02-19T15:50:03Z — task-created [inception-start]
- **Action:** Created inception from T-151/T-184 review
- **Context:** Reviewing T-151 revealed agent completed specification without human dialogue. Cron system (T-184) reruns structural checks instead of OE testing. ISO 27001 model proposed during review dialogue.

### 2026-02-19 — Phase 0: Genesis discussion (thinking trail)
- **Artifact:** `docs/reports/T-194-assurance-genesis-discussion.md`
- **Content:** T-151 timeline analysis, three-layer model evolution, ISO 27001 mapping, control inventory (11 controls, 9 without OE), OE test examples, discovery capability gap analysis, 5 open questions for Phase 1
- **Key insight:** Layer 2 (cron audits) is NOT redundant — it's defense-in-depth for when hooks silently fail (observed multiple times in AEF history)

### 2026-02-19 — Phase 0b: Research persistence failure analysis
- **Artifact:** `docs/reports/T-194-research-persistence-failure-analysis.md`
- **Trigger:** T-194 genesis discussion almost lost — human caught it
- **Finding:** 7 controls exist for research persistence. ALL failed: post-hoc (check at completion), advisory (agent must remember), scope-limited (sub-agents only, not main-thread), or unused (fw bus — dead code). Zero structural enforcement for main-thread conversation capture.
- **Key insight:** Control Design ≠ Operational Effectiveness. Controls designed for sub-agent outputs, but real risk is main-thread conversation research loss.
- **Candidates:** 6 remediation options (A-F) identified. T-191 provides positive evidence for Option D (live document pattern). Human decision: document, plan, experiment, validate.

### 2026-02-19 — Phase 0c: Experiment specification
- **Artifact:** `docs/reports/T-194-research-persistence-experiment-spec.md`
- **Design:** Three controls (C-001 live document, C-002 commit gate, C-003 checkpoint prompt) each with ISO 27001 four-layer design: Risk → Control → OE Test → Audit. All defined before building.
- **Experiment:** T-194 itself as test subject across Phases 1-3 (3-5 sessions). Measuring capture completeness, control effectiveness, false positive rate, friction, OE test reliability.
- **Build order:** C-001 (CLAUDE.md rule, immediate) → C-002 (commit-msg hook, ~15 lines) → C-003 (checkpoint hook, ~30 lines) → OE tests (~50 lines) → cron integration.
- **Human decision:** Write it up, then build and experiment on T-194.
