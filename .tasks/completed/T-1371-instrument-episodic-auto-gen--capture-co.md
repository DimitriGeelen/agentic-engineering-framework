---
id: T-1371
name: "Instrument episodic auto-gen — capture context.sh stdout/stderr/exit to log file (G-054 mitigation)"
description: >
  Instrument episodic auto-gen — capture context.sh stdout/stderr/exit to log file (G-054 mitigation)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-20T22:56:24Z
last_update: 2026-04-20T22:58:25Z
date_finished: 2026-04-20T22:58:25Z
---

# T-1371: Instrument episodic auto-gen — capture context.sh stdout/stderr/exit to log file (G-054 mitigation)

## Context

G-054 (episodic auto-gen silent failure) now has 5 datapoints across 2 sessions — manual `generate-episodic` succeeds in the same session where auto-gen fails, so the failure is environmental to update-task.sh's invocation context. Previous iterations only logged a WARN when the output file was missing. That was too late — the actual stdout/stderr/exit code from context.sh was gone. This task adds always-on instrumentation so the next auto-gen invocation leaves a forensic log at `.context/working/.last-episodic-gen.log`.

## Acceptance Criteria

### Agent
- [x] Episodic auto-gen block in update-task.sh writes a log file every invocation (not only on failure)
- [x] Log captures: timestamp, task_id, FRAMEWORK_ROOT, PROJECT_ROOT, CONTEXT_DIR, cwd, context.sh stdout/stderr, exit code
- [x] WARN message on missing-episodic points to the log file path
- [x] `bash -n agents/task-create/update-task.sh` passes
- [x] Vendored .agentic-framework/agents/task-create/update-task.sh synced

## Verification

bash -n agents/task-create/update-task.sh
grep -q "last-episodic-gen.log" agents/task-create/update-task.sh
grep -q "EPISODIC_EXIT" agents/task-create/update-task.sh

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

### 2026-04-20T22:56:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1371-instrument-episodic-auto-gen--capture-co.md
- **Context:** Initial task creation

### 2026-04-20T22:58:25Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1e47b089
- **Timestamp:** 2026-06-02T14:57:01Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#5 (Agent)** — Vendored .agentic-framework/agents/task-create/update-task.sh synced
  - **AC-verify-mismatch** (narrow, heuristic) — `path=agentic-framework/agents/task-create/update-task.sh in: Vendored .agentic-framework/agents/task-create/update-task.sh synced`
