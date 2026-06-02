---
id: T-551
name: "Fabric register scan-then-confirm — preview before bulk registration, three-layer codification"
description: >
  fw fabric register on a directory should preview what will be registered (subsystem breakdown, file counts) before creating cards. Single file = no gate. Directory = always preview. --yes flag for automation. Also update onboarding T-003 template with scaled guidance and add CLAUDE.md governance rule. Origin: T-549 OpenClaw eval — agent registered 2734 cards blindly, required coaching + cleanup.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-23T16:05:30Z
last_update: 2026-03-24T21:38:30Z
date_finished: 2026-03-24T21:38:30Z
---

# T-551: Fabric register scan-then-confirm — preview before bulk registration, three-layer codification

## Context

`fw fabric register <dir>` blindly creates cards for all eligible files. On OpenClaw (2734 files), this caused context explosion. Add preview-then-confirm for directory registration.

## Acceptance Criteria

### Agent
- [x] Directory registration shows preview (file count, subsystem breakdown) before creating cards
- [x] Preview exits without creating cards unless `--yes` flag is passed
- [x] Single file registration is unchanged (no gate)
- [x] `--yes` flag bypasses preview confirmation

## Verification

grep -q "\-\-yes" agents/fabric/lib/register.sh
grep -q "preview\|Preview" agents/fabric/lib/register.sh

## Decisions

## Updates

### 2026-03-23T16:05:30Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-551-fabric-register-scan-then-confirm--previ.md
- **Context:** Initial task creation

### 2026-03-24T21:36:25Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-24T21:38:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-299e6855
- **Timestamp:** 2026-06-02T15:03:31Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
