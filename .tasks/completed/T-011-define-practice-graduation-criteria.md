---
id: T-011
name: Define practice graduation criteria
description: >
  When does a learning graduate from task update to practice to directive? Define criteria and process. Currently undefined in framework.
status: work-completed
workflow_type: specification
owner: human
priority: medium
tags: [meta, practices, governance]
agents:
  primary: claude-code
  supporting: []
created: 2026-02-13T18:19:25Z
last_update: 2026-02-13T22:00:00Z
date_finished: 2026-02-13T21:00:05Z
---

# T-011: Define practice graduation criteria

## Design Record

**Approach:** Define a knowledge pyramid with clear graduation criteria at each level.

The framework has four levels of operational knowledge:
1. **Task Update** — Single observation in one task
2. **Learning** — Recognized pattern worth remembering
3. **Practice** — Proven pattern with operational guidance
4. **Directive** — Constitutional principle

Each graduation requires **evidence** and **increased permanence**. Higher levels are harder to change.

## Specification Record

Acceptance criteria:
- [x] Define what each level represents
- [x] Define graduation criteria from each level to the next
- [x] Define retirement/demotion criteria
- [x] Document the process for graduation
- [x] Update 015-Practices.md with the criteria

---

## Knowledge Pyramid

```
                    ┌─────────────┐
                    │ DIRECTIVES  │  ← Constitutional (D1-D4)
                    │   (D-XXX)   │     Stable anchors
                    ├─────────────┤
                    │  PRACTICES  │  ← Operational (P-XXX)
                    │   (P-XXX)   │     Proven patterns
                    ├─────────────┤
                    │  LEARNINGS  │  ← Recognized (L-XXX)
                    │   (L-XXX)   │     Worth remembering
                    ├─────────────┤
                    │   UPDATES   │  ← Observed (in task)
                    │ (task logs) │     Single instance
                    └─────────────┘
```

---

## Level Definitions

### Task Update (Bottom)

**What it is:** A single observation logged in a task's Updates section.

**Characteristics:**
- Specific to one task
- May be wrong or context-dependent
- Low confidence, high specificity
- No ID, lives in task file

**Examples:**
- "API timeout after 30s" (specific failure)
- "Used sed instead of grep for multiline" (technique)
- "Had to check task status before updating" (gotcha)

---

### Learning (L-XXX)

**What it is:** A recognized pattern captured in `learnings.yaml`. Worth remembering but not yet operational guidance.

**Characteristics:**
- Generalizable beyond one task
- Includes application guidance
- Has ID (L-XXX) and references source
- Lives in `.context/project/learnings.yaml`

**Examples:**
- L-001: "Measure what exists, not what should exist"
- L-004: "Only update active tasks to avoid timestamp loops"

---

### Practice (P-XXX)

**What it is:** A proven pattern with full operational documentation. Tells you what to do and why.

**Characteristics:**
- Proven across multiple instances
- Has pattern, anti-pattern, and origin
- Derives from one or more directives
- Lives in `015-Practices.md`

**Examples:**
- P-002: "Structural Enforcement Over Agent Discipline"
- P-006: "Hybrid Agent Architecture"

---

### Directive (D1-D4)

**What it is:** A constitutional principle. Stable anchor that practices derive from.

**Characteristics:**
- Universal applicability
- Very hard to change
- All decisions trace to directives
- Lives in `005-DesignDirectives.md`

**Examples:**
- D1: Antifragility
- D2: Reliability

---

## Graduation Criteria

### Update → Learning

**When:** An observation proves generalizable.

| Criterion | Evidence Required |
|-----------|-------------------|
| Repeatability | Same pattern observed in 2+ tasks |
| Applicability | Clear guidance on when to apply |
| Non-obviousness | Not common knowledge |

**Process:**
1. Observe pattern in task Update
2. Notice same pattern in another task
3. Add to `learnings.yaml` with:
   - ID (L-XXX)
   - Learning statement
   - Source task(s)
   - Application guidance

**Demotion:** Learning can return to "just an update" if it proves wrong or context-specific.

---

### Learning → Practice

**When:** A learning is proven enough to guide behavior.

| Criterion | Evidence Required |
|-----------|-------------------|
| Validation | Applied successfully in 3+ contexts |
| Abstraction | Can be stated as "The practice is..." |
| Derivation | Traces to one or more directives |
| Teachability | Someone else could follow it |

**Process:**
1. Identify learning with 3+ successful applications
2. Abstract to pattern/anti-pattern format
3. Document in `015-Practices.md` with:
   - ID (P-XXX)
   - Directive derivation
   - The practice statement
   - The pattern (steps)
   - Why it matters
   - Anti-pattern
   - Origin

**Demotion:** Practice can be retired if it stops being useful or is replaced by better practice.

---

### Practice → Directive

**When:** A practice is so fundamental it becomes constitutional.

| Criterion | Evidence Required |
|-----------|-------------------|
| Universality | Applies to all framework work, not just some |
| Stability | Hasn't changed in 6+ months of use |
| Priority | Conflicts with other principles require its consideration |
| Consequence | Violating it causes significant harm |

**Process:**
1. Recognize practice has become foundational
2. Propose to human owner as potential directive
3. **Human decision required** — directives are constitutional
4. If approved, add to `005-DesignDirectives.md`
5. Original practice can remain as operational guidance

**Demotion:** Directives are intentionally hard to change. Require explicit human decision and documented rationale.

---

## Retirement Criteria

Knowledge can also demote or retire:

### Learning Retirement
- **Wrong:** The pattern was incorrect
- **Superseded:** Better learning replaced it
- **Obsolete:** Context changed, no longer applies

### Practice Retirement
- **Obsolete:** Technology/context changed
- **Superseded:** Better practice emerged
- **Overcomplicated:** Simpler approach works

### Directive Retirement
- **Fundamental reconception:** The framework's purpose changed
- **Evidence of harm:** The directive causes more problems than it solves
- **Human decision required**

---

## Summary Table

| From | To | Evidence Needed | Approver |
|------|-----|-----------------|----------|
| Update | Learning | 2+ tasks with same pattern | Agent |
| Learning | Practice | 3+ successful applications | Agent |
| Practice | Directive | Universal, stable, 6+ months | Human |

---

## Test Files

N/A - this is a specification task

## Updates

### 2026-02-13T18:19:25Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-011-define-practice-graduation-criteria.md
- **Context:** Initial task creation

### 2026-02-13T22:00:00Z — criteria-defined [claude-code]
- **Action:** Defined knowledge pyramid with graduation criteria for each level
- **Output:** 4-level hierarchy (Update → Learning → Practice → Directive) with clear criteria
- **Key insight:** Higher levels require more evidence and are harder to change
- **Decision:** Practice → Directive requires human approval (constitutional change)
- **Context:** This completes the framework's governance model
