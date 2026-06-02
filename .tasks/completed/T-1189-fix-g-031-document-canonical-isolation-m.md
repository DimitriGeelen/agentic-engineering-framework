---
id: T-1189
name: "Fix G-031: document canonical isolation model — vendored dir + shim patterns, doctor detection for legacy patterns"
description: >
  Fix G-031: document canonical isolation model — vendored dir + shim patterns, doctor detection for legacy patterns

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-12T21:46:16Z
last_update: 2026-04-12T21:48:34Z
date_finished: 2026-04-12T21:48:34Z
---

# T-1189: Fix G-031: document canonical isolation model — vendored dir + shim patterns, doctor detection for legacy patterns

## Context

G-031: Five isolation patterns coexist undocumented (T-1100 inception, GO). Fix: add fw doctor checks for legacy/problematic patterns + document the canonical model in FRAMEWORK.md. Inception: T-1100.

## Acceptance Criteria

### Agent
- [x] `fw doctor` warns on nested `.agentic-framework` inside vendored dir
- [x] `fw doctor` warns on oversized global install (>100MB at `~/.agentic-framework`)
- [x] FRAMEWORK.md documents canonical isolation model (vendored + shim)
- [x] G-031 marked resolved in concerns.yaml

## Verification

bash -c 'bin/fw doctor 2>&1 | grep -q "OK\|WARN\|checks passed"'
grep -q "Isolation Model" FRAMEWORK.md

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-04-12T21:46:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1189-fix-g-031-document-canonical-isolation-m.md
- **Context:** Initial task creation

### 2026-04-12T21:48:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1fbfa3be
- **Timestamp:** 2026-06-02T14:55:47Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `bash -c 'bin/fw doctor 2>&1 | grep -q "OK\|WARN\|checks passed"'`
