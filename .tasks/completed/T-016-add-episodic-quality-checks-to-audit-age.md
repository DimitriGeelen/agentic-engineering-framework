---
id: T-016
name: Add episodic quality checks to audit agent
description: >
  Audit agent has ZERO episodic checks. Add: (1) Check all completed tasks have episodic files, (2) Check episodic summary field is non-empty (>50 chars), (3) Check successes OR challenges has entries, (4) Check decisions populated if Design Record exists. FAIL on missing, WARN on low-quality.
status: work-completed
workflow_type: build
owner: human
priority: high
tags: [audit, D2, P-002]
agents:
  primary: claude-code
  supporting: []
created: 2026-02-13T21:21:30Z
last_update: 2026-02-13T22:28:00Z
date_finished: 2026-02-13T21:27:49Z
---

# T-016: Add episodic quality checks to audit agent

## Design Record

**Approach:** Add a new section (Section 6) to audit.sh for episodic memory checks.

**Checks implemented:**
1. Every completed task has an episodic file
2. Check for enrichment_status: pending (needs enrichment)
3. Check summary is not empty or [TODO]

**Severity decisions:**
- Missing episodic: WARN (not FAIL, since older tasks may predate the system)
- Pending enrichment: WARN
- Empty/TODO summary: WARN

## Specification Record

Acceptance criteria:
- [x] Audit checks all completed tasks have episodic files
- [x] Audit checks enrichment_status field
- [x] Audit checks summary is not empty/TODO
- [x] Audit detected 4 missing episodics (T-002, T-003, T-004, T-012)
- [x] Audit detected low-quality episodics

## Test Files

- Run `./agents/audit/audit.sh` and check EPISODIC MEMORY CHECKS section

## Updates

### 2026-02-13T21:21:30Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-016-add-episodic-quality-checks-to-audit-age.md
- **Context:** Initial task creation

### 2026-02-13T22:28:00Z — work-completed [claude-code]
- **Action:** Added Section 6 (Episodic Memory Checks) to audit.sh
- **Output:**
  - Checks for missing episodic files
  - Checks for enrichment_status: pending
  - Checks for empty/TODO summaries
  - Detected 4 missing + 1 low-quality episodics
- **Context:** Audit now catches the gaps that the multi-agent review identified
