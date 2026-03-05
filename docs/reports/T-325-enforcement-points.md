# Research: Enforcement Mechanisms for Actionable Human ACs

This document maps existing framework enforcement points and identifies where human AC actionability enforcement could be extended.

## 1. Task Templates (`.tasks/templates/`)

### Current State
- **default.md**: Includes `### Agent` and `### Human` AC sections (lines 26-33)
  - Agent ACs: agent-verifiable (code, tests, commands) — P-010 gates on these
  - Human ACs: human-verifiable (UI/UX, subjective) — not blocking, comments say "Remove this section if all criteria are agent-verifiable"
  - **No guidance on AC actionability or quality**
  - **No template examples** showing what makes an AC actionable vs. vague
- **inception.md**: Exists but has different AC structure for explorations

### Enforcement Gap
- Templates accept boilerplate like "- [ ]" with no validation
- No check for: "Is this AC specific, observable, measurable?"
- No guidance on human AC format (who decides what's done?)
- No requirement that human ACs reference task outputs (code files, UI pages, logs)

---

## 2. AC Gate (P-010) in `update-task.sh` (lines 211-310)

### Current State (update-task.sh)
- **What it checks:**
  - If `### Agent` header exists: gates only on Agent ACs (line 223-229)
  - If no `### Agent` header: gates on all ACs (backward compatible, line 240-247)
  - Rejects skeleton placeholders: `[First criterion]`, `[Criterion N]` (lines 266-293)
  - Counts checked vs unchecked boxes (line 226-227)
  
- **What it reports for human ACs:**
  - Informational only (lines 299-308)
  - "Human: X/Y checked (not blocking)" — no enforcement
  - Task enters partial-complete if agent ACs pass but human ACs remain unchecked (line 304)

- **What it DOES NOT check:**
  - Whether human ACs are actionable/specific
  - Whether human AC text has [TODO], vague wording, or placeholder language
  - Whether human ACs reference outputs (which file, which URL, what behavior)
  - Whether human AC completion instructions are clear
  - Whether human ACs are observable (e.g., "looks good" vs "button appears in top-right corner")

### Enforcement Opportunity (AC Quality)
- P-010 could reject human ACs with quality issues before work-completed, same as it rejects skeleton placeholders
- Examples of what to detect:
  - Placeholder text: "[criterion]", "TODO", "needs approval", "TBD"
  - Vague language: "looks good", "feels right", "is clean", "seems appropriate"
  - No observable acceptance: "is correct" (correct compared to what?)
  - Missing reference to output: "UI works" (which UI? where is it running?)
  - Orphaned ACs: "tests pass" (whose tests? where are they?)

---

## 3. Task Creation (`create-task.sh`, lines 166-209)

### Current State
- Selects template (default.md or inception.md) based on workflow_type
- Replaces placeholders: task ID, name, description, owner, etc.
- **Does NOT validate AC structure at creation time**
- **Interactive mode allows custom description, but no AC validation**

### Enforcement Gap
- No guidance when creating task about what makes a human AC actionable
- No template validation: "Is this AC specific enough to verify?"
- When a task is created as `owner: human` from the start, no warning that human ACs must be filled in
- No check: "If human ACs exist, are they written as observable conditions?"

### Enforcement Opportunity (AC Quality at Creation)
- When `--start` flag is used (starts work immediately): validate that AC section is not still placeholder text
- Warning: "You have Human ACs — they must be specific and observable. Examples: [list good patterns]"
- For inception tasks: template could prompt for assumption/validation criteria before task is started

---

## 4. Handover Generation (`handover.sh`, lines 213-445)

### Current State
- **Episodic completeness check** (lines 213-269): warns if recently completed tasks missing episodic summaries
- **D2 discovery check** (lines 1770-1824 in audit.sh): flags tasks with `owner: human` + `status: work-completed` waiting >24h
  - Detects aging in the queue but NOT quality of the human ACs
  - No check: "Can the human actually verify this AC without more information?"

- **Handover template** (lines 334-371): generates "Work in Progress" section with task status, horizon, last action, next step, blockers
  - **Each task has "Last action", "Next step", "Blockers", "Insight" [TODO] placeholders**
  - **No "Human AC status" field** showing which human ACs are pending and who needs to verify them

### Enforcement Gap
- Handover does NOT surface pending human ACs as separate action items
- No field for: "Human verification pending: [AC text] — waiting for [owner name]"
- No action brief: "Click here to verify this AC" or "Run this command and report result"
- Handover quality check (D8) looks for [TODO] in overall document but NOT specifically for human AC gaps

### Enforcement Opportunity (Actionability Brief)
- Add section to handover: **"Pending Human Verification"**
  - List all tasks with `owner: human` + `status: work-completed`
  - For each human AC: display the AC text + instructions for how to verify it
  - Example format:
    ```
    - **T-303**: Create fw preflight command
      - Human AC: Output is clear and actionable for someone who has never seen the framework
      - How to verify: Run `fw preflight --check-only` and read the output. Is it understandable?
      - Blockers: None
    ```

---

## 5. Audit System (`audit.sh`, discovery and OE sections)

### Current State (Discovery Checks)

**D1 (Episodic Quality Decay)** — lines 1751-1786
- Flags episodic files with [TODO] placeholders
- Not about human ACs

**D2 (Human Review Queue Aging)** — lines 1788-1824
- **Only checks age, not actionability**
- Finds tasks: `owner: human` + `status: work-completed` in active/
- Flags if age > 24h (info), >48h (warn), >72h (fail)
- **Missing:** Whether human ACs in those tasks are actually actionable/clear

**D10 (Decision-Without-Dialogue)** — lines 1901-1950 in audit.sh
- Flags inception/specification tasks completed with `owner: human` + unchecked human ACs
- **Detects the problem but does not check AC quality**
- Missing: Whether those human ACs have clarity issues that would prevent verification

### Current OE Checks (Operational Excellence)

**CTL-025** — lines 5090-5120 in audit.sh
- Validates: Tasks with `### Agent` header have checked agent ACs before completion
- Validates: Tasks in partial-complete state have `owner: human`
- **Does NOT validate:** Human AC quality/actionability

### Enforcement Opportunity (AC Quality Discovery)

**New check: D11 (Human AC Actionability Decay)**
- Scan all tasks with `owner: human` + unchecked human ACs
- For each, check: does the AC text contain
  - Vague words: "looks", "feels", "is clean", "seems", "appropriate", "correct" (without reference)
  - Missing observable condition: "code works" (works how? pass which test?)
  - Missing reference to output: "output is clear" (which output file/URL?)
  - Placeholder text: "[TODO]", "TBD", "[something]"
- Report: "X human ACs lack observable acceptance conditions"
- Suggestion: "For each human AC, include: (1) what to check, (2) where to find it, (3) what passes/fails"

**New OE check: CTL-027 (Human AC Clarity)**
- When task enters partial-complete: validate that human ACs meet minimum quality
- Reject with clear feedback: "Human AC '[text]' is too vague. Make it observable: [example]"

---

## 6. CLAUDE.md Rules (Instruction Precedence)

### Current State (T-193: Agent/Human AC Split)
- Lines 614-620 define the rule:
  - Agent ACs: gate criteria (P-010 enforces)
  - Human ACs: not blocking but must be checked before finalization
  - Partial-complete: agent done, human ACs pending
  - Only human can check human ACs

- Lines 622-629 (Verification Before Completion):
  - Step 2: "Check every ### Agent acceptance criterion checkbox (or all ACs if no split headers)"
  - Does NOT mention: checking human AC quality/actionability

- **No guidance on what makes a human AC actionable**

### Enforcement Opportunity (Guidance + Rules)

Add to CLAUDE.md after T-193 section:

**"Human AC Quality Rules (T-XXX)**
- Every human AC must include: (1) what to verify, (2) where to find it, (3) what passes
- Forbidden in human ACs: vague adjectives ("looks good", "is clean"), orphaned actions ("tests pass" without test reference), placeholder text
- Handover must surface pending human ACs as actionable items with clear next steps
- Audit will flag human ACs that lack observable acceptance conditions

---

## Summary: Enforcement Points Map

| Component | Where Checked | Current | Gap | Enforcement Opportunity |
|-----------|---------------|---------|-----|------------------------|
| **1. Templates** | `.tasks/templates/default.md` | Includes human AC section | No AC quality guidance | Add examples of actionable vs vague ACs |
| **2. Task Creation** | `create-task.sh` | Loads template | No validation | Warn if AC section is still placeholder; validate structure |
| **3. AC Gate (P-010)** | `update-task.sh` lines 211-310 | Counts checked boxes; rejects skeleton placeholders | Does not check human AC text quality | Reject vague/incomplete human ACs before partial-complete |
| **4. Handover** | `handover.sh` lines 333-372 | Lists active tasks + TODOs | Does not surface human AC action items | Add "Pending Human Verification" section with clear instructions |
| **5. Audit (Discovery)** | `audit.sh` D2/D10 checks | Flags age + unchecked ACs | Does not check clarity/actionability | New D11 check: flag vague/incomplete human ACs |
| **6. Audit (OE)** | `audit.sh` CTL-025 | Validates split AC structure | Does not validate quality | New CTL-027: reject unclear human ACs at partial-complete |
| **7. Rules (CLAUDE.md)** | T-193 section | Documents split semantics | No guidance on AC quality | Add human AC quality rules + examples |

---

## Phased Implementation Path

**Phase 1 (Template + Detection)**
- Update `default.md` template: add examples of actionable vs vague human ACs (comments)
- Add D11 discovery check to `audit.sh`: flag vague/incomplete human ACs
- Add guidance to CLAUDE.md T-193 section

**Phase 2 (Enforcement)**
- Extend P-010 gate in `update-task.sh`: reject tasks with low-quality human ACs before partial-complete
- Add CTL-027 OE check: validate human AC clarity at task creation or status change

**Phase 3 (Actionability Workflow)**
- Extend handover: add "Pending Human Verification" action brief
- Add `fw task human-ac` command: shows pending human ACs with verification instructions
- Add `fw audit --focus human-ac`: quick report on actionability gaps

---

## Evidence: Current Partial-Complete Workflow (T-303 Example)

**File:** `.tasks/active/T-303-create-fw-preflight-command-and-integrat.md`
- Status: `work-completed`
- Owner: `human` (partial-complete)
- Agent ACs: all checked (7/7)
- **Human AC: `[ ] Output is clear and actionable for someone who has never seen the framework`**
  - **Problem:** "Clear" and "actionable" are vague. How does human verify this?
  - **Missing:** Who tests it? On what output? What counts as passing?
  - **Needed:** "Run `fw preflight --check-only` and show output to someone unfamiliar with framework. Ask: Can you understand what each line means without documentation?"

**What P-010 enforced:** Agent ACs are checked.
**What was NOT enforced:** Human AC is specific enough for human to actually verify independently.

