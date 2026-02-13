---
id: T-009
name: Document falsifiability criteria
description: >
  Answer: What would prove this approach wrong? Define criteria that would indicate the framework is not working. Critical for D1 Antifragility - we need to know when to pivot.
status: work-completed
workflow_type: specification
owner: human
priority: medium
tags: [meta, D1, vision]
agents:
  primary: claude-code
  supporting: []
created: 2026-02-13T18:19:20Z
last_update: 2026-02-13T21:55:00Z
date_finished: null
---

# T-009: Document falsifiability criteria

## Design Record

**Approach:** Map each framework claim to observable failure indicators.

A claim is falsifiable when we can specify **what evidence would disprove it**. For each of the four directives and core mechanisms, we define:
1. What the framework claims
2. What would prove that claim false
3. How we would observe the failure

**Key insight:** Falsifiability criteria are about the framework itself, not about individual tasks. We're asking "when should we abandon this approach?" not "when did a task fail?"

## Specification Record

Acceptance criteria:
- [x] Define falsifiability criteria for each of the 4 directives
- [x] Define falsifiability criteria for core mechanisms (task system, context fabric, learning loop)
- [x] Each criterion has: claim, failure indicator, observable signal
- [x] Document the "pivot threshold" — when accumulated failures mean the approach is wrong

---

## Falsifiability Criteria

### D1: Antifragility — "System gets stronger under stress"

| Claim | Failure Indicator | Observable Signal |
|-------|-------------------|-------------------|
| Failures become learning events | Same failures repeat without captured patterns | Healing agent shows no patterns for recurring issues |
| Patterns improve recovery | Recovery time for similar failures doesn't decrease | Time-in-issues status stays constant or increases |
| Framework benefits from disorder | Novel failures break the framework instead of expanding it | Exception handling fails; manual intervention required |
| Error Escalation Ladder works | Failures stay at level A (don't repeat) forever | No learnings graduate to practices (B→C→D stagnates) |

**Falsified if:** After 50+ task completions, identical failures still occur without mitigation patterns, and healing agent suggestions are consistently unhelpful.

---

### D2: Reliability — "Predictable, observable, auditable execution"

| Claim | Failure Indicator | Observable Signal |
|-------|-------------------|-------------------|
| Every action is traceable | Actions happen without task references | Git traceability falls below 80% |
| No silent failures | Errors occur without being logged | Tasks move to completed without Updates entries |
| State is robust | Orphaned state, inconsistent data | Audit finds structural violations it can't explain |
| Execution is auditable | Can't reconstruct what happened | Updates section is empty or generic |

**Falsified if:** Audit consistently passes but real problems exist, OR git traceability drops below 70% despite enforcement hooks being installed.

---

### D3: Usability — "Joy to use, extend, debug"

| Claim | Failure Indicator | Observable Signal |
|-------|-------------------|-------------------|
| Framework is a joy to use | Developers bypass rather than comply | High bypass rate (>20% of commits) |
| Sensible defaults | Frequent override of defaults | Most tasks require extensive manual configuration |
| Errors are actionable | Developers can't recover from errors | Tasks stay in "issues" status for extended periods |
| Low friction adoption | Time to create task > time to do work | Developers skip task creation for "small" work |

**Falsified if:** Users consistently work around the framework (bypass hooks, skip handovers, don't create tasks) because the overhead isn't worth the benefit.

---

### D4: Portability — "No lock-in"

| Claim | Failure Indicator | Observable Signal |
|-------|-------------------|-------------------|
| LLM provider independence | Only works with Claude Code | Other agents (GPT-4, Gemini) can't follow CLAUDE.md |
| Environment agnosticism | Only works in one OS/shell | Scripts fail on macOS, Windows, or different shells |
| Protocol-based integration | Requires proprietary tools | No standard (MCP, LSP) interfaces exposed |
| Git provider independence | Tied to specific git host | Enforcement hooks assume GitHub/GitLab specifics |

**Falsified if:** Framework cannot function with any LLM provider other than Anthropic Claude, OR requires specific OS/toolchain not specified in prerequisites.

---

### Core Mechanism: Task System — "Nothing gets done without a task"

| Claim | Failure Indicator | Observable Signal |
|-------|-------------------|-------------------|
| Tasks trace to intent | Tasks exist but are meaningless | Description quality metric shows <50% good descriptions |
| Task lifecycle works | Tasks get stuck | >30% of tasks never reach completed |
| Acceptance criteria met | Tasks complete without meeting AC | AC completion rate <60% on completed tasks |

**Falsified if:** Tasks become compliance paperwork (exist but don't capture real intent), OR developers routinely do work without creating tasks.

---

### Core Mechanism: Context Fabric — "Context persists across sessions"

| Claim | Failure Indicator | Observable Signal |
|-------|-------------------|-------------------|
| Handovers prevent re-learning | New sessions repeat old learnings | Same questions asked across multiple handovers |
| Episodic memory is useful | Summaries aren't referenced | No searches against .context/episodic/ |
| Project memory accumulates | Patterns/learnings don't grow | Context Fabric metrics stay flat over time |

**Falsified if:** After 10+ handovers, the same context is re-discovered repeatedly, OR episodic summaries are never consulted.

---

### Core Mechanism: Learning Loop — "Learnings become practices"

| Claim | Failure Indicator | Observable Signal |
|-------|-------------------|-------------------|
| Learnings graduate to practices | L-XXX never becomes P-XXX | Learnings count grows but practices don't |
| Practices influence decisions | P-XXX not referenced in task decisions | Design Records don't cite practices |
| Practices graduate to directives | No practices ever modify directives | D1-D4 never evolve based on evidence |

**Falsified if:** After 20+ learnings captured, none have graduated to practices, and practices don't influence how work is done.

---

## Pivot Threshold

The framework approach should be **abandoned or fundamentally redesigned** when:

1. **3+ directives are falsified** — The core principles aren't being achieved
2. **2+ core mechanisms fail** — The implementation doesn't deliver the principles
3. **Usability is falsified AND one other** — Nobody wants to use it, making other goals irrelevant
4. **Cost exceeds benefit for 3 consecutive projects** — Even if metrics look good, if it slows people down

**What pivoting looks like:**
- If D1 fails: Add more rigorous failure capture, or accept the framework is documentation-only
- If D2 fails: Add stricter enforcement, or accept lighter-weight approach
- If D3 fails: Simplify radically, or target different users
- If D4 fails: Narrow scope to specific environments, or rebuild interfaces

---

## Test Files

N/A - this is a specification task

## Updates

### 2026-02-13T18:19:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-009-document-falsifiability-criteria.md
- **Context:** Initial task creation

### 2026-02-13T21:55:00Z — criteria-defined [claude-code]
- **Action:** Documented falsifiability criteria for all 4 directives and 3 core mechanisms
- **Output:** Detailed tables with claim/failure-indicator/observable-signal for each
- **Key insight:** Falsifiability is about the framework approach, not individual task failures
- **Pivot threshold:** Defined when to abandon the approach (3+ directives fail, 2+ mechanisms fail, usability fails)
- **Context:** This completes the specification. Framework now has clear failure conditions.
