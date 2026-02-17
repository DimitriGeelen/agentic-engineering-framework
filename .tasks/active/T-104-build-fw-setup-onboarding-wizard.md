---
id: T-104
name: Build fw setup onboarding wizard
description: >
  Build a 6-step guided onboarding wizard (fw setup) that wraps fw init with a breadcrumb flow. Design from code-architect agent investigation: Step 1: Project Identity (name, description, owner) -> writes .framework.yaml metadata + CLAUDE.md Project Overview. Step 2: Provider Selection (claude/cursor/generic) -> generates provider config, hooks. Step 3: Tech Stack and Conventions (languages, test framework, code style) -> appends to CLAUDE.md + .framework.yaml. Step 4: Enforcement Level (strict/standard/advisory) -> configures hooks, git hooks. Step 5: First Task (optional) -> creates task + sets focus + context init. Step 6: Verification -> runs fw doctor + prints cheat sheet + creates initial handover. IMPLEMENTATION: Create lib/setup.sh with do_setup() and per-step functions. Add setup route to bin/fw. Each step checks sentinel (idempotent). Non-interactive mode (detect TTY) applies defaults for agent invocation. Partial completion is safe — each step writes to disk before proceeding. fw init remains as fast non-interactive path; fw setup wraps it. ACCEPTANCE: fw setup /tmp/test runs interactive 6-step flow. Re-running skips completed steps. fw doctor passes after setup completes. DEPENDS ON: T-102 (needs comprehensive CLAUDE.md template) + T-103 (needs hardened init). Files: create lib/setup.sh (~350 lines), modify bin/fw (add routing).
status: work-completed
workflow_type: build
owner: agent
tags: [fw-setup, wizard, onboarding, external-project]
related_tasks: []
created: 2026-02-17T08:53:56Z
last_update: 2026-02-17T08:53:56Z
date_finished: null
---

# T-104: Build fw setup onboarding wizard

## Context

Designed by code-architect agent during session S-2026-0217-0920. The user specifically requested a "breadcrumb system or flow system — clear steps that we go through page by page for inception." The architect produced a full 6-step design with integration points.

## Dependencies

- **Blocks:** T-107 (pronunciation app init uses this wizard)
- **Blocked by:** T-102 (CLAUDE.md template), T-103 (hardened init)

## Implementation Guide

### Architecture Decision

`fw setup` wraps `fw init`. `fw init` stays as the fast non-interactive path. `fw setup` calls `fw init` internally, then layers guided questions.

### Step Details

**Step 1/6: Project Identity**
- Inputs: project name (default: basename), one-line description, primary owner
- Outputs: `.framework.yaml` updated with project_name, description, owner
- Sentinel: `.framework.yaml` has `project_name` key

**Step 2/6: Provider Selection**
- Inputs: claude/cursor/generic
- Actions: calls `fw init` internally with `--provider`, generates hooks
- Sentinel: CLAUDE.md exists with non-placeholder Project Overview

**Step 3/6: Tech Stack and Conventions**
- Inputs: primary language(s), test framework, code style rules
- Outputs: `## Tech Stack` section appended to CLAUDE.md, `tech_stack:` in .framework.yaml
- Sentinel: `.framework.yaml` has `tech_stack` key

**Step 4/6: Enforcement Level**
- Inputs: strict (Tier 0+1), standard (Tier 1 only), advisory (no blocking)
- Outputs: `.framework.yaml` gets `enforcement_level`, git hooks installed if elected
- Sentinel: `.framework.yaml` has `enforcement_level` key

**Step 5/6: First Task (optional)**
- Inputs: task name (can skip), task type
- Actions: `fw task create` + `fw context init` + `fw context focus`
- Sentinel: `.context/working/session.yaml` exists

**Step 6/6: Verification**
- No inputs. Runs `fw doctor`. Prints cheat sheet. Creates initial handover.
- Sentinel: always runs (idempotent)

### Non-Interactive Mode

Detect TTY: `[ -t 0 ]`. If non-interactive, apply defaults:
- Project name: basename of directory
- Provider: claude
- Tech stack: (empty — skip)
- Enforcement: standard
- First task: skip
- Verification: always run

### Files to Create/Modify

- **CREATE:** `lib/setup.sh` (~350 lines) — do_setup() + 6 step functions
- **MODIFY:** `bin/fw` — add `setup)` case to routing (1 line + source)
- **MODIFY:** `lib/init.sh` — accept `--from-wizard` flag for extra .framework.yaml fields

### Acceptance Criteria

- [x] `fw setup /tmp/test` runs interactive 6-step flow with breadcrumb headers
- [x] Each step shows "Step N of 6: Title"
- [x] Re-running on same directory skips completed steps (sentinel checks)
- [x] `fw setup /tmp/test` in non-interactive mode applies defaults silently
- [x] `fw doctor` passes after setup completes
- [x] `.framework.yaml` contains all metadata fields after setup

## Updates

### 2026-02-17T09:22:00Z — work-completed [claude-code]
- **Action:** Created lib/setup.sh (~300 lines) with 6-step wizard. Added `setup)` route to bin/fw and help text. Each step has sentinel check for idempotency, non-interactive mode auto-detected via TTY.
- **Output:** Tested: `fw setup /tmp/test-setup --non-interactive` runs all 6 steps, generates comprehensive CLAUDE.md, installs hooks, passes fw doctor. Re-run skips all completed steps (DONE markers).
- **Context:** Steps: Identity → Provider → Tech Stack → Enforcement → First Task → Verification. Wraps fw init internally for scaffolding.

### 2026-02-17T08:53:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-104-build-fw-setup-onboarding-wizard.md
- **Context:** Initial task creation
