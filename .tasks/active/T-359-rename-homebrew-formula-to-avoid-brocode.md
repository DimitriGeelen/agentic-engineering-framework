---
id: T-359
name: "Rename Homebrew formula to avoid brocode/fw collision"
description: >
  Our Homebrew formula 'fw' collides with brocode/fw (Workspace productivity booster) in Homebrew core. When users run 'brew install fw' without qualifying the tap, they get the wrong package. Rename formula to 'agentic-fw' or similar unique name. Update: tap formula filename, install instructions in README, any docs referencing 'brew install fw'. Consider adding a migration note for existing users.

status: started-work
workflow_type: build
owner: human
horizon: next
tags: [homebrew, distribution]
components: []
related_tasks: []
created: 2026-03-08T19:14:22Z
last_update: 2026-03-08T19:42:05Z
date_finished: null
---

# T-359: Rename Homebrew formula to avoid brocode/fw collision

## Context

Homebrew core has a `fw` formula (brocode/fw — "Workspace productivity booster"). Users running `brew install fw` without tap qualification get the wrong package. Rename our formula to `agentic-fw`.

## Acceptance Criteria

### Agent
- [x] Tap repo has `Formula/agentic-fw.rb` with class `AgenticFw`
- [x] Old `Formula/fw.rb` deleted from tap repo
- [x] Tap README updated with `brew install agentic-fw` instructions
- [x] Migration note added to formula caveats
- [x] Main README updated: `brew install DimitriGeelen/agentic-fw/agentic-fw`
- [x] Launch article and Reddit post updated with new formula name

### Human
- [ ] [RUBBER-STAMP] Verify install works with new formula name on macOS
  **Steps:**
  1. `brew uninstall agentic-fw 2>/dev/null; brew uninstall fw 2>/dev/null`
  2. `brew untap DimitriGeelen/agentic-fw 2>/dev/null`
  3. `brew install DimitriGeelen/agentic-fw/agentic-fw`
  4. `fw version`
  **Expected:** Shows `fw v1.2.5` and framework path under `/usr/local/opt/agentic-fw/libexec`
  **If not:** Check `brew info agentic-fw` for errors

## Verification

# README references new formula name
grep -q 'agentic-fw/agentic-fw' README.md
# No remaining old-style install references in user-facing docs
! grep -q 'agentic-fw/fw' README.md

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

### 2026-03-08T19:14:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-359-rename-homebrew-formula-to-avoid-brocode.md
- **Context:** Initial task creation

### 2026-03-08T19:42:05Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
