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

**Date:** 2026-02-19

### Coverage Summary

| Metric | Value |
|--------|-------|
| Total risks | 37 |
| Risks with CTL-XXX controls | 21 (56%) |
| Risks without formal controls | 16 (44%) |
| Of unmitigated: closed (ad-hoc fix) | 12 |
| Of unmitigated: open (no control) | 4 |

**Gap: 44% of risks have no formal control in the register.** Many are "closed" via ad-hoc fixes (learnings, one-time patches) that aren't tracked as controls. This is a structural finding — the framework has more mitigations than the control register captures, but those mitigations aren't observable, testable, or auditable.

### Assessment by Risk (score >= 8 or status != closed)

Rating: **S** = sufficient, **P** = partial, **I** = insufficient, **N** = no control

| Risk | Score | Controls | Rating | Rationale |
|------|-------|----------|--------|-----------|
| R-002 (human ACs falsified) | 16 HIGH | CTL-012 (blocking) | **P** | Gate checks checkbox state, not WHO checked it. Agent can check its own behavioral ACs. T-193 (tagging) not yet built. |
| R-010 (research lost) | 16 HIGH | CTL-014, CTL-021, CTL-022, CTL-023 (all warn) | **P** | 4 controls but zero blocking. Agent can ignore all 4. Experiment running — too early to assess effectiveness. |
| R-011 (sub-agent explosion) | 12 HIGH | CTL-021, CTL-023 (warn) | **I** | Controls target research persistence, not sub-agent output size. fw bus (designed for this) never adopted. No size gating. |
| R-033 (human tasks auto-completed) | 12 HIGH | none | **N** | No control exists. The T-194 "human-dialogue-mandatory" decision is a one-time statement, not a reusable control. |
| R-004 (context destroyed) | 10 HIGH | CTL-008 (blocking), CTL-010 (warn) | **S** | Budget gate + auto-handover + auto-restart provide defense-in-depth. Residual: unfilled handover TODOs. |
| R-005 (monitoring fails silently) | 10 HIGH | CTL-001, CTL-008 (blocking), CTL-010 (warn) | **S** | Multiple fixes (cache removal, synthetic filtering, 2MB tail). Tested. Conservative thresholds compensate for lag. |
| R-023 (hook config fails) | 10 HIGH | none | **N** | No validation tool. Correct format documented in MEMORY.md but a typo in settings.json silently disables ALL hooks. |
| R-018 (YAML silently lost) | 9 MED | CTL-013 (blocking) | **P** | Verification gate catches bad YAML only if task has verification commands that parse it. No general schema validation. |
| R-024 (UI drops data) | 9 MED | none | **N** | Same root cause as R-018. No parsing error surfaced to user. |
| R-036 (multi-agent untested) | 9 MED | none | **N** | Watching — no mitigation until first multi-agent task. Acceptable for now. |
| R-032 (inception gate conflict) | 8 MED | none | **N** | --no-verify is the workaround. Logged but not controlled. Needs configurable threshold. |
| R-003 (no inception) | 9 MED | CTL-001, CTL-009 (blocking), CTL-014 (warn) | **S** | Structural gate after 2 commits + task-first gate. Agent can build once without gate, but risk is small. |
| R-001 (governance override) | 8 MED | CTL-001 (blocking) | **S** | PreToolUse hook is structural. Precedence rules in CLAUDE.md. New plugins still a residual. |

### Design Adequacy Summary

| Rating | Count | Risks |
|--------|-------|-------|
| **S** (sufficient) | 4 | R-004, R-005, R-003, R-001 |
| **P** (partial) | 3 | R-002, R-010, R-018 |
| **I** (insufficient) | 1 | R-011 |
| **N** (no control) | 5 | R-033, R-023, R-024, R-036, R-032 |

### Key Findings

**Finding 1: High-risk items have the weakest controls.**
The two highest-scoring open risks (R-002 at 16, R-010 at 16) have only partial controls. R-033 (score 12) has NO control at all. This is inverted — control investment should correlate with risk score.

**Finding 2: Warn-only controls cluster on the highest risks.**
R-010 has 4 controls — more than any other risk — but all 4 are non-blocking. The defense-in-depth is breadth without depth. A single structural gate would be more effective than 4 warnings.

**Finding 3: 5 risks have no formal control.**
R-033 (human sovereignty), R-023 (hook config), R-024 (UI parse errors), R-036 (multi-agent), R-032 (inception gate conflict). These are known gaps but uncontrolled.

**Finding 4: Ad-hoc mitigations aren't observable.**
12 "closed" risks have mitigations (learnings, patches) but these aren't in controls.yaml. They can't be OE-tested. If the patch regresses, nothing detects it.

### Recommendations for Phase 3

1. **R-033**: Design a structural control — `owner: human` + `workflow_type: spec|inception` → require human interaction before status change
2. **R-023**: Build a hook config validator — `fw doctor` should parse `.claude/settings.json` and verify hook structure
3. **R-010**: Consider promoting one of the 4 warn-only controls to blocking (e.g., CTL-022 could block instead of warn)
4. **R-011**: Revive fw bus or build alternative size gating for sub-agent output
5. **Ad-hoc mitigations**: Decide whether to formalize the 12 closed-but-uncontrolled risks into controls, or accept them as "fixed" with residual risk

## Phase 3: OE Test Design

**Date:** 2026-02-19
**Question per control:** "What observable effect proves this control is working in practice?"

### OE Test Register

Each test classified as:
- **A** = automatable (cron/script)
- **S** = session-log analysis (needs transcript)
- **M** = manual review (human required)

#### Layer 1: PreToolUse Hooks

| CTL | Control | OE Test | How | Type | Freq |
|-----|---------|---------|-----|------|------|
| CTL-001 | Task-First Gate | Focus file exists when Write/Edit succeed | Check: recent commits touch source files → focus.yaml had value at that time | A | 30min |
| CTL-002 | Tier 0 Guard | Hook script exists + settings.json matcher correct | `test -x agents/context/check-tier0.sh && grep -q 'check-tier0' .claude/settings.json` | A | daily |
| CTL-003 | Budget Gate | `.budget-status` file < 5min old during active session | `find .context/working/.budget-status -mmin -5` (only meaningful during session) | A | 30min |

#### Layer 2: PostToolUse Hooks

| CTL | Control | OE Test | How | Type | Freq |
|-----|---------|---------|-----|------|------|
| CTL-004 | Context Checkpoint | Tool counter resets on commit | `.tool-counter` = 0 after most recent commit (post-commit hook resets it) | A | 30min |
| CTL-005 | Error Watchdog | Hook script exists + settings.json matcher correct | `test -x agents/context/error-watchdog.sh && grep -q 'error-watchdog' .claude/settings.json` | A | daily |

#### Layer 3: SessionStart Hooks

| CTL | Control | OE Test | How | Type | Freq |
|-----|---------|---------|-----|------|------|
| CTL-006 | Pre-Compact Handover | Handover exists within 5min of each compaction | Check `.compact-log` timestamps vs handover timestamps — each compaction should have a handover | A | daily |
| CTL-007 | Post-Compact Resume | Settings.json contains resume hook config | `grep -q 'post-compact-resume' .claude/settings.json` | A | daily |

#### Layer 4: Git Hooks

| CTL | Control | OE Test | How | Type | Freq |
|-----|---------|---------|-----|------|------|
| CTL-008 | Task Reference Gate | All recent commits have T-XXX prefix | `git log --oneline -20` → count without T-XXX → ratio | A | hourly |
| CTL-009 | Inception Commit Gate | Active inception tasks with >2 commits have decision OR bypass logged | Cross-check inception tasks vs commit count vs decision file | A | daily |
| CTL-010 | Bypass Detector | All --no-verify commits appear in bypass-log.yaml | Compare `git log --oneline` (missing T-XXX) vs bypass-log entries | A | daily |
| CTL-011 | Audit Push Gate | Hook file exists + is executable | `test -x .git/hooks/pre-push` | A | daily |
| CTL-022 | Research Warning (C-002) | Inception commits without docs/reports/ logged to warning file | Check `.inception-research-warnings` has entries when expected | A | 30min |

#### Layer 5: Script Gates

| CTL | Control | OE Test | How | Type | Freq |
|-----|---------|---------|-----|------|------|
| CTL-012 | AC Gate (P-010) | No completed task has unchecked ACs | Scan `.tasks/completed/` for `- [ ]` in AC section | A | daily |
| CTL-013 | Verification Gate (P-011) | Completed tasks with `## Verification` have all commands passing | Re-run verification commands for recently completed tasks | A | daily |

#### Layer 6: Behavioral Rules

| CTL | Control | OE Test | How | Type | Freq |
|-----|---------|---------|-----|------|------|
| CTL-014 | Inception Discipline | Active inception tasks have docs/reports/T-XXX-*.md | `test -f docs/reports/T-XXX-*` for each active inception | A | 30min |
| CTL-015 | Pre-Completion Check | N/A — subsumed by CTL-013 OE test | (if verification gate passes, pre-completion check is moot) | — | — |
| CTL-016 | Hypothesis Debugging | Error patterns resolved with mitigation recorded | Check healing patterns for recent resolutions | S | weekly |
| CTL-017 | Commit Cadence | Commits happen at least every 20 tool calls | Compare `.tool-counter` max between commits (from git log timestamps) | S | session |
| CTL-021 | Live Document Rule (C-001) | Same as CTL-014 | Research artifact exists + linked in task Updates | A | 30min |

#### Cross-cutting / Infrastructure

| CTL | Control | OE Test | How | Type | Freq |
|-----|---------|---------|-----|------|------|
| CTL-018 | Token Budget Monitor | Budget status file exists, valid JSON, level field present | `python3 -c "import json; d=json.load(open('.context/working/.budget-status')); assert 'level' in d"` | A | 30min |
| CTL-019 | Auto-Restart | claude-fw wrapper exists + is executable | `test -x bin/claude-fw` | A | daily |
| CTL-020 | Continuous Audit | Cron audit files produced within last hour | `find .context/audits/cron -name '*.yaml' -mmin -60` (during active cron) | A | hourly |
| CTL-023 | Checkpoint Prompt (C-003) | Checkpoint log shows research prompts fired | Check `.inception-checkpoint-log` for recent entries | A | 30min |

### OE Test Classification Summary

| Type | Count | Controls |
|------|-------|----------|
| **A** (automatable) | 20 | CTL-001 through CTL-014, CTL-018-023 |
| **S** (session-log) | 2 | CTL-016, CTL-017 |
| **M** (manual) | 0 | — |
| **Skipped** | 1 | CTL-015 (subsumed by CTL-013) |

**20 of 23 controls can be OE-tested automatically.** This exceeds the go/no-go criterion (>= 8 of 11 → now 20 of 23).

### Proposed Cron Redesign

Current cron runs **audit sections** (structure, compliance, quality, etc.). The redesign runs **OE tests grouped by frequency**:

```
# === OE Tests (T-194 Phase 3 redesign) ===

# Every 30 min: fast checks (file existence, freshness, research artifacts)
*/30 * * * *  fw audit --section oe-fast --cron
# Tests: CTL-001, CTL-003, CTL-004, CTL-014/021, CTL-018, CTL-022, CTL-023

# Hourly: git-based checks (traceability, audit output freshness)
0 * * * *     fw audit --section oe-hourly --cron
# Tests: CTL-008, CTL-020

# Daily: deep checks (hook installation, bypass reconciliation, AC gate, verification re-run)
0 8 * * *     fw audit --section oe-daily --cron
# Tests: CTL-002, CTL-005, CTL-006, CTL-007, CTL-009, CTL-010, CTL-011, CTL-012, CTL-013, CTL-019

# Weekly: behavioral/session analysis
0 9 * * 1     fw audit --section oe-weekly --cron
# Tests: CTL-016 (healing patterns)

# Keep existing structural audits for compliance
*/30 * * * *  fw audit --section structure,compliance,quality --cron
0 * * * *     fw audit --section traceability,episodic --cron
0 */6 * * *   fw audit --section observations,gaps --cron
0 8 * * *     fw audit --section full --cron

# Retention
0 9 * * *     find .context/audits/cron -name '*.yaml' -mtime +7 -delete
```

### Key Design Decisions

**D-Phase3-001: OE tests are outcome-based, not simulation-based.**
We test "did the control produce its expected effect?" (outcome) rather than "can we trigger the control?" (simulation). Outcome tests are cheaper, run without a session, and detect both control failures AND bypass.

**D-Phase3-002: Session-log tests (CTL-016, CTL-017) run within sessions, not cron.**
These require transcript analysis. They belong in checkpoint.sh (PostToolUse), not cron. Cron can't read active sessions.

**D-Phase3-003: Structural audit sections preserved alongside OE tests.**
The current structure/compliance/quality checks are still valuable — they catch different things than OE tests. OE tests verify controls work; structural audits verify the project is well-formed. Both needed.

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
