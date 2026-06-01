---
id: T-606
name: "Version bumping mechanism — structural enforcement for version tracking across framework and vendored projects"
description: >
  458 commits since v1.2.6 with no version bump. FW_VERSION in bin/fw is manual-only,
  VERSION file was stuck at 1.0.0 for 7 releases, audit checks zero version fields.
  Build: fw version bump/check/sync commands in lib/version.sh, audit Layer 5,
  pre-push staleness advisory. Pure bash, macOS-portable. Origin: T-606 TermLink investigation.

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-25T14:05:56Z
last_update: 2026-03-26T15:47:28Z
date_finished: 2026-03-25T14:21:39Z
---

# T-606: Version bumping mechanism — structural enforcement for version tracking across framework and vendored projects

## Context

458 commits since v1.2.6 (17 days). VERSION file was stuck at 1.0.0 for 7 releases undetected. No automation, no audit, no enforcement. Design: `/tmp/fw-agent-version-design.md`. Gaps audit: `/tmp/fw-agent-version-current-gaps.md`.

## Acceptance Criteria

### Agent
- [x] `lib/version.sh` created with `do_version_bump`, `do_version_check`, `do_version_sync`
- [x] `fw version bump patch` increments patch in bin/fw, VERSION, .agentic-framework/VERSION, .agentic-framework/bin/fw
- [x] `fw version bump minor` zeroes patch, increments minor
- [x] `fw version bump major` zeroes minor+patch, increments major
- [x] `fw version bump patch --tag` creates annotated git tag
- [x] `fw version bump --dry-run` shows changes without modifying files
- [x] `fw version check` reports sync status of all version sources + staleness
- [x] `fw version sync` updates all files to match FW_VERSION
- [x] `fw version bump` errors in consumer project (not framework repo)
- [x] Audit Layer 5 added: version consistency + staleness warning
- [x] Pre-push hook: staleness advisory when >50 commits since last tag
- [x] Uses `_sed_i` for macOS/Linux portability
- [x] Vendored copy synced to `.agentic-framework/lib/version.sh`

### Human
- [x] [RUBBER-STAMP] Run `fw version bump patch --dry-run` and verify output shows all files
  **Steps:**
  1. Run `fw version bump patch --dry-run`
  2. Verify it lists bin/fw, VERSION, .agentic-framework/VERSION, .agentic-framework/bin/fw
  **Expected:** Shows "Would bump 1.X.Y -> 1.X.Z" and lists all files
  **If not:** Report which files are missing from the dry-run output

## Verification

# lib/version.sh syntax check
bash -n lib/version.sh
# version subcommand routing works
test -f lib/version.sh && grep -q "do_version_check" lib/version.sh
# dry-run support present
grep -q "dry_run" lib/version.sh

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

### 2026-03-25T14:05:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-606-version-bumping-mechanism--structural-en.md
- **Context:** Initial task creation

### 2026-03-25T14:21:39Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
