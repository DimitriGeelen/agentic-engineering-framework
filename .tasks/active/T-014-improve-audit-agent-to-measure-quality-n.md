---
id: T-014
name: Improve audit agent to measure quality not just existence
description: >
  Critical review revealed audit agent violates P-001, P-004 (measures existence not quality), P-002 (reports but doesn't enforce), and doesn't check Tier 0 at all. Multiple gaming vectors exist. AGENT.md claims capabilities not implemented in audit.sh.
status: started-work
workflow_type: build
owner: human
priority: high
tags: [audit, P-001, P-002, P-004, D1, D2, enforcement]
agents:
  primary:
  supporting: [Plan]
created: 2026-02-13T18:58:38Z
last_update: 2026-02-13T19:03:02Z
date_finished: null
---

# T-014: Improve audit agent to measure quality not just existence

## Design Record

### Critical Review Findings (2026-02-13)

**Principle Violations Identified:**

| Finding | Severity | Violation |
|---------|----------|-----------|
| Measures existence, not quality | HIGH | P-001, P-004 |
| Reports but doesn't enforce | MEDIUM | P-002 |
| Tier 0 not checked at all | HIGH | 011-EnforcementConfig |
| Easy gaming vectors | HIGH | Framework spirit |
| No antifragile learning loop | MEDIUM-HIGH | D1 |
| Spec-implementation drift in AGENT.md | MEDIUM | D2 |

**Gaming Vectors Not Detected:**
1. Status gaming — Keep tasks "started-work" forever
2. Commit ref gaming — Put "T-001" in every commit regardless of actual task
3. Practice origin fabrication — Reference non-existent tasks
4. Template compliance without substance — Fill fields minimally, never update

**AGENT.md Claims Not Implemented:**
- D1-D4 directive compliance checking
- Tier 0 action detection
- Quality heuristics

### Design Decisions (TBD)

- Should audit be phased (quick/deep)?
- Should quality checks be WARN or FAIL?
- How to detect Tier 0 violations retrospectively?
- Should audit persist results for trend analysis?

## Specification Record

### Acceptance Criteria

**Phase 1: Quality Heuristics**
- [ ] Description field > 50 characters (WARN if shorter)
- [ ] Updates section has > 0 entries for started-work tasks
- [ ] Updates section has > 3 entries for tasks older than 7 days
- [ ] Task refs in commits resolve to actual task files
- [ ] Practice origins reference existing tasks

**Phase 2: Enforcement Integration**
- [ ] Option to run audit as pre-push hook
- [ ] Exit code 2 (FAIL) blocks operations when integrated
- [ ] Document audit integration points in AGENT.md

**Phase 3: Tier 0 Checking**
- [ ] Parse bypass-log.yaml for Tier 0 patterns
- [ ] Check git history for consequential action keywords
- [ ] Cross-reference with task authorization

**Phase 4: Antifragile Learning**
- [ ] Persist audit results to `.context/audits/YYYY-MM-DD.yaml`
- [ ] Detect repeated failures across runs
- [ ] Suggest practice candidates from patterns

**Phase 5: Spec-Implementation Alignment**
- [ ] AGENT.md accurately describes what audit.sh does
- [ ] Remove or implement all claimed capabilities

### Anti-Gaming Tests

Create test scenarios that SHOULD fail audit:
- Task with `description: TBD` passes quality check? → Should WARN
- Commit with `T-999` (non-existent task) passes traceability? → Should WARN
- Practice with `Origin: T-999` (non-existent) passes? → Should WARN
- Task in started-work for 30 days with 0 updates? → Should WARN

## Test Files

- `tests/audit/gaming-detection.sh` — Scenarios that should trigger warnings
- `tests/audit/quality-heuristics.sh` — Quality threshold tests
- `tests/audit/tier0-detection.sh` — Tier 0 violation detection

## Updates

### 2026-02-13T18:58:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-014-improve-audit-agent-to-measure-quality-n.md
- **Context:** Initial task creation

### 2026-02-13T19:00:00Z — critical-review-completed [Plan agent]
- **Action:** Spawned Plan agent to critically review audit against framework principles
- **Output:** 8 findings, 6 recommendations, severity ratings
- **Context:** User asked "critically review if our audit is adhering to the mindset of our framework"
- **Insight:** "Healthy dysfunction" — the framework can critique itself, proving its value
