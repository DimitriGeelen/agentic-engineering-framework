# T-194: Control Register Design — Phase 2

**Date:** 2026-02-19
**Participants:** Human + Claude (dialogue)
**Phase:** 2 (Control Register Design)
**Prerequisite:** Phase 1 (risk landscape — 38 risks scored, three-register model)

## Summary

Designing the control register: schema, population, and design adequacy assessment for all controls.

## Updated Control Inventory

Phase 0 identified 11 controls. Full audit reveals **20 distinct controls** plus 3 experimental (T-194).

### By Type

| Type | Count | Examples |
|------|-------|---------|
| PreToolUse Hook | 3 | check-active-task, check-tier0, budget-gate |
| PostToolUse Hook | 2 | checkpoint, error-watchdog |
| SessionStart Hook | 2 | pre-compact, post-compact-resume |
| Git Hook | 3 | commit-msg (3 gates), post-commit, pre-push |
| Script Gate | 2 | P-010 AC gate, P-011 verification gate |
| Behavioral Rule | 4 | inception discipline, verification-before-completion, hypothesis debugging, commit cadence |
| Monitoring | 1 | token budget (dual-hook architecture) |
| Infrastructure | 1 | auto-restart (T-179) |
| Auditor | 1 | audit agent (continuous compliance) |
| Composite/Structural | 1 | task-first protocol (behavioral + hook) |
| **Total** | **20** | |
| Experimental (T-194) | 3 | C-001, C-002, C-003 |

### Full Control List

| ID | Name | Type | Implementation | Blocking? |
|----|------|------|---------------|-----------|
| CTL-001 | Task-First Gate | PreToolUse | check-active-task.sh | Yes (exit 2) |
| CTL-002 | Tier 0 Guard | PreToolUse | check-tier0.sh | Yes (exit 2) |
| CTL-003 | Budget Gate | PreToolUse | budget-gate.sh | Yes (exit 2 at 170K) |
| CTL-004 | Context Checkpoint | PostToolUse | checkpoint.sh | No (warns, auto-handover) |
| CTL-005 | Error Watchdog | PostToolUse | error-watchdog.sh | No (investigation prompt) |
| CTL-006 | Pre-Compact Handover | SessionStart | pre-compact.sh | No (creates handover) |
| CTL-007 | Post-Compact Resume | SessionStart | post-compact-resume.sh | No (injects context) |
| CTL-008 | Task Reference Gate | Git commit-msg | commit-msg hook (line ~21) | Yes (exit 1) |
| CTL-009 | Inception Commit Gate | Git commit-msg | commit-msg hook (line ~40) | Yes (exit 1 after 2 commits) |
| CTL-010 | Bypass Detector | Git post-commit | post-commit hook | No (warns) |
| CTL-011 | Audit Push Gate | Git pre-push | pre-push hook | Yes (exit 1 if audit fails) |
| CTL-012 | AC Completion Gate | Script gate | update-task.sh:163 | Yes (exit 1) |
| CTL-013 | Verification Gate | Script gate | update-task.sh:189 | Yes (exit 1) |
| CTL-014 | Inception Discipline | Behavioral | CLAUDE.md §Inception | No (rule set) |
| CTL-015 | Pre-Completion Check | Behavioral | CLAUDE.md §Verification | No (agent practice) |
| CTL-016 | Hypothesis Debugging | Behavioral | CLAUDE.md §Debugging | No (error protocol) |
| CTL-017 | Commit Cadence | Behavioral | CLAUDE.md §Budget | No (reminders) |
| CTL-018 | Token Budget Monitor | Monitoring | budget-gate + checkpoint | Yes (dual-hook) |
| CTL-019 | Auto-Restart | Infrastructure | checkpoint.sh + claude-fw | No (signal-based) |
| CTL-020 | Continuous Audit | Auditor | audit.sh (13 sections) | Yes (pre-push blocks) |

### Experimental Controls (T-194)

| ID | Name | Type | Implementation | Status |
|----|------|------|---------------|--------|
| C-001 | Live Document Rule | Behavioral | CLAUDE.md §Inception #6 | Active |
| C-002 | Research Artifact Warning | Git commit-msg | commit-msg hook (line ~78) | Active |
| C-003 | Checkpoint Research Prompt | PostToolUse | checkpoint.sh (spec only) | Partial |

## Phase 2a: Schema Design

### Agent Research (2 parallel investigations)

**Investigation 1 — ISO 27001 control register patterns:**
- Typical SoA (Statement of Applicability) has 13+ fields
- ISO 27001 clause 6.1.3(d) mandates only 3 things: controls selected, implementation status, justification for exclusions
- Lightweight startup variants strip to: ID, name, in-scope, implemented, owner, evidence link
- `failure_mode` is non-standard but recommended for antifragile systems — enables proactive learning surface
- Design adequacy is a cross-register assessment (risk + control + residual gap reasoning), not a property of the control itself — belongs in report, not per-control field

**Investigation 2 — AEF-specific schema considerations:**
- 20 controls × 15 fields = 300 data points (unsustainable for 1-2 person team)
- 20 controls × 8 fields = 160 data points (sustainable with occasional review)
- Breakeven at ~10 fields; above that, stale fields exceed lookup value
- Consistency with risks.yaml/issues.yaml: typed prefix IDs (CTL-XXX), header comment block, cross-register linking via ID lists, flat YAML (no nested objects), enumerated status values
- Normalization opportunity: risks.yaml `controls` field currently uses script names → should migrate to CTL-XXX IDs

### Human Course Correction

**Human directive:** "We are not doing an ISO 27001 project. I just used the example for inspiration. Let's keep it fit for use and check our Constitutional Directives."

This reframed the schema design from "ISO 27001 alignment" to "Constitutional Directive alignment":

| Directive | Schema implication |
|-----------|-------------------|
| D1 Antifragility | Capture `failure_mode` — how controls break is the learning surface |
| D2 Reliability | Controls must be observable and auditable — `blocking` + `status` fields |
| D3 Usability | Keep it lean — 8 fields max, no field that exists "just in case" |
| D4 Portability | Flat YAML, no tooling dependency, greppable by shell scripts |

### Agreed Schema (8 fields)

```yaml
# Control Register — Agentic Engineering Framework
# Schema: 8 fields, flat YAML, greppable
#
# id:           CTL-XXX (unique, sequential)
# name:         Short human name
# type:         pretooluse|posttooluse|git_hook|script_gate|behavioral|monitoring
# impl:         File path or CLAUDE.md §section
# blocking:     true = prevents action, false = warns/logs
# mitigates:    [R-XXX] references to risks.yaml
# status:       active|partial|planned|disabled
# failure_mode: How this control breaks (D1: antifragility)
```

### Fields Dropped (with rationale)

| Field | Why dropped |
|-------|-------------|
| `description` | `name` + `impl` file IS the description (D3: don't duplicate) |
| `owner` | Single team, always "framework" (D3: no value-less fields) |
| `oe_test` / `oe_frequency` / `oe_automated` | Belong in audit.sh sections, not the register (D3: separation of concerns) |
| `design_adequacy` | Assessment output, not control property — lives in this report |
| `origin` | Nice-to-have but low lookup value vs maintenance cost |
| `expected_behavior` | Redundant with `blocking` + reading the impl file |
| `last_reviewed` | Stale the moment you write it |

### Fields Kept That Are Non-Standard

| Field | Why kept |
|-------|---------|
| `failure_mode` | D1 (antifragility) demands knowing HOW things break, not just what they do. Enables root cause analysis and remediation when controls fail. |

## Phase 2b: Register Population

**File:** `.context/project/controls.yaml`
**Date:** 2026-02-19
**Controls populated:** 23 (CTL-001 through CTL-023)

### Population Summary

| Type | Count | Blocking | IDs |
|------|-------|----------|-----|
| PreToolUse | 3 | 3 | CTL-001, CTL-002, CTL-003 |
| PostToolUse | 3 | 0 | CTL-004, CTL-005, CTL-023 |
| SessionStart | 2 | 0 | CTL-006, CTL-007 |
| Git Hook | 4 | 2 | CTL-008, CTL-009, CTL-010, CTL-022 |
| Script Gate | 2 | 2 | CTL-012, CTL-013 |
| Behavioral | 5 | 0 | CTL-014, CTL-015, CTL-016, CTL-017, CTL-021 |
| Monitoring | 1 | 1 | CTL-018 |
| Infrastructure | 1 | 0 | CTL-019 |
| Auditor | 1 | 1 | CTL-020 |
| Git Hook (warn) | 1 | 0 | CTL-011 (blocks push, not commit) |
| **Total** | **23** | **9 blocking** | |

### Risk Coverage

Every risk in risks.yaml should be mitigated by at least one control. Coverage check deferred to Phase 2c (design adequacy assessment).

### Observations During Population

1. **Failure modes are revealing** — writing them exposed that many controls share a common failure mode: "agent can ignore non-blocking warning." This is a systemic weakness in the warn-only controls (12 of 23).
2. **Behavioral controls lack structural enforcement** — CTL-014 through CTL-017 and CTL-021 rely on agent compliance. Only CTL-009 (inception commit gate) provides structural backstop for CTL-014.
3. **--no-verify is a universal bypass** — 4 git hook controls (CTL-008, CTL-009, CTL-010, CTL-022) are all neutralized by a single flag. Compensating control: bypass-log.yaml audit trail (CTL-010 detects post-commit).
4. **Experimental controls (CTL-021-023)** — C-001/C-002/C-003 from the T-194 experiment. Promoted to CTL IDs since they are deployed and active.

## Phase 2c: Design Adequacy Assessment

Assessment lives here (not in controls.yaml) because it is cross-register reasoning:
"Given risk R-XXX, does control CTL-XXX sufficiently mitigate it?"

<!-- TODO: Assessment per control after population -->

## Dialogue Log

### 2026-02-19 — Schema design conversation

**Context:** Phase 2 start. Agent proposed 15-field schema based on ISO 27001 SoA patterns.

**Human questions posed (4):**
1. Schema scope — too heavy / too light?
2. Failure mode field — worth including?
3. Design adequacy field — what's the value?
4. ID scheme — preference?

**Human answers:**
1. "No idea, spawn agents to investigate/reflect"
2. "I would argue it makes sense as it helps us do root cause analysis and remediate, but open for debate"
3. "No idea what is the value of that, we should not make it too heavy"
4. "As long as it's uniquely identifiable and numbered and used consistently through the framework"

**Agent research dispatched:** 2 parallel agents (ISO 27001 patterns + AEF-specific reflection)

**Human course correction:** "We are not doing an ISO 27001 project. I just used the example for inspiration. Let's keep it fit for use and check our Constitutional Directives."

**Outcome:** Schema reduced from 15 → 8 fields, anchored on Constitutional Directives not ISO compliance. `failure_mode` kept (D1). `design_adequacy` dropped from schema (stays in report). CTL-XXX ID scheme adopted for consistency.

## Decisions

### D-Phase2-001 — Schema anchored on Constitutional Directives, not ISO 27001
- **Chose:** 8-field schema driven by D1-D4 directives
- **Why:** ISO 27001 was inspiration, not target. Schema must serve AEF's actual needs: antifragility (know how things break), reliability (observable/auditable), usability (lean), portability (flat YAML)
- **Rejected:** 15-field ISO-aligned schema (enterprise bloat for 1-2 person team)

### D-Phase2-002 — failure_mode field included (non-standard)
- **Chose:** Include `failure_mode` as 8th field
- **Why:** D1 Antifragility — controls that break silently are the #1 pattern in AEF history. Pre-documenting failure modes enables proactive root cause analysis. Human leaned yes.
- **Rejected:** Omit as non-standard — but the whole framework is non-standard; standards serve us, not the reverse

### D-Phase2-003 — Design adequacy in report, not schema
- **Chose:** Keep design adequacy assessment in docs/reports/T-194-control-register.md
- **Why:** It's cross-register reasoning (risk + control + residual gap), not a property of the control. Adding it to controls.yaml means 20 more data points that go stale when risks change. Human concern: "should not make it too heavy."
- **Rejected:** `adequacy: sufficient|partial|insufficient` per control — maintenance exceeds lookup value

### D-Phase2-004 — CTL-XXX ID scheme
- **Chose:** CTL-001 through CTL-020+ with sequential numbering
- **Why:** Consistent with R-XXX, I-XXX, G-XXX patterns. Uniquely identifiable. Enables cross-register linking.
- **Follow-up:** Normalize risks.yaml `controls` field from script names to CTL-XXX IDs once register populated
