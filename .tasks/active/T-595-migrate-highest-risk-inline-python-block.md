---
id: T-595
name: "Migrate highest-risk inline Python blocks to fw-util calls"
description: >
  Migrate the 32 inline python3 -c blocks identified as breaking-on-quotes (T-586 Phase 1, docs/reports/T-586-q4-shell-escaping.md) to use fw-util subcommands. Priority order: 1) check-tier0.sh:176-184 (audit log writer, COMMAND injection), 2) create-task.sh:161-199 (multiple interpolated vars), 3) validate-init.sh:155,198,204 (open path pattern), 4) all 22 open(path) patterns. Each migration: replace python3 -c with node fw-util call, verify same behavior, run existing tests. Depends on T-593 (fw-util). Design source: docs/reports/T-586-q4-shell-escaping.md remediation priority.

status: captured
workflow_type: build
owner: agent
horizon: next
tags: [security, typescript, T-586]
components: []
related_tasks: [T-586, T-593, T-592]
created: 2026-03-23T23:00:57Z
last_update: 2026-03-23T23:00:57Z
date_finished: null
---

# T-595: Migrate highest-risk inline Python blocks to fw-util calls

## Context

The 32 highest-risk inline Python blocks break on input containing quotes. This task replaces them with fw-util calls, eliminating the shell escaping vulnerability.

Priority list from: `docs/reports/T-586-q4-shell-escaping.md` (Recommended Remediation Priority)
Design pattern from: `docs/reports/T-586-migration-path.md` (section 5: fw-util pattern)

Depends on: T-593 (fw-util must be built first)

## Acceptance Criteria

### Agent
- [ ] `check-tier0.sh:176-184` — audit log writer no longer interpolates `$COMMAND` into Python. Uses fw-util or stdin.
- [ ] `create-task.sh:161-199` — all `$TAGS_YAML`, `$RELATED_YAML`, `$FILEPATH` passed via args/stdin, not interpolation
- [ ] `validate-init.sh:155,198,204` — `open('$full_path')` replaced with fw-util yaml-get / json-get
- [ ] All 22 `open('$path')` patterns across framework replaced with fw-util calls
- [ ] No remaining `python3 -c "...$VAR..."` patterns in the 32 identified files (grep verification)
- [ ] All existing bats tests still pass after migration
- [ ] `fw doctor` passes
- [ ] `fw audit` passes (no regression)
- [ ] Each migrated invocation handles file-not-found gracefully (same error behavior as before)
- [ ] Input containing single quotes, double quotes, backticks, and `'''` processes correctly

## Verification

# No unsafe patterns remain in the 4 priority files
! grep -n 'python3 -c.*\$COMMAND' agents/context/check-tier0.sh
! grep -n 'python3 -c.*\$TAGS_YAML' agents/task-create/create-task.sh
! grep -n "open('\$full_path')" lib/validate-init.sh
# Existing tests pass
fw doctor
# Framework still initializes correctly
bash lib/validate-init.sh --check 2>/dev/null || true

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

### 2026-03-23T23:00:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-595-migrate-highest-risk-inline-python-block.md
- **Context:** Initial task creation
