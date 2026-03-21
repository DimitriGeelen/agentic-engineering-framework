---
id: T-516
name: "Create TermLink Homebrew tap with GitHub Actions builds"
description: >
  Create TermLink Homebrew tap with GitHub Actions builds

status: started-work
workflow_type: build
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-21T16:02:14Z
last_update: 2026-03-21T16:03:53Z
date_finished:
---

# T-516: Create TermLink Homebrew tap with GitHub Actions builds

## Context

Setting up TermLink distribution via Homebrew with GitHub Actions automated builds.

## Acceptance Criteria

### Agent
- [x] GitHub Actions workflow created for macOS builds (aarch64 + x86_64)
- [x] Homebrew formula template created
- [x] Documentation updated with brew install instructions
- [x] All YAML files valid syntax

### Human
- [x] [RUBBER-STAMP] Push GitHub Actions workflow to termlink repo
  **Status:** DONE - Workflow pushed to `.github/workflows/release.yml` on GitHub
  **Note:** Build is failing due to dependency issues (rand 0.9, thiserror 2.x require recent Rust)

- [ ] [REVIEW] Fix GitHub Actions build errors
  **Steps:**
  1. Run `gh auth login` to re-authenticate gh CLI
  2. Check build logs: https://github.com/DimitriGeelen/termlink/actions
  3. Fix Cargo.toml dependencies (downgrade rand to 0.8, thiserror to 1.x if needed)
  4. Push fix and create new tag
  **Expected:** Green builds for all 3 platforms

- [ ] [RUBBER-STAMP] Create Homebrew tap repo and publish formula
  **Steps:**
  1. Run `gh auth login` first
  2. `gh repo create homebrew-termlink --public`
  3. Local tap repo prepared at `/tmp/homebrew-termlink/`
  4. Push Formula/termlink.rb after builds succeed
  5. Update SHA256 hashes from release checksums.txt
  **Expected:** `brew install DimitriGeelen/termlink/termlink` works on macOS
  **If not:** Check formula syntax with `brew audit --strict termlink`

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     Examples:
       python3 -c "import yaml; yaml.safe_load(open('path/to/file.yaml'))"
       curl -sf http://localhost:3000/page
       grep -q "expected_string" output_file.txt
-->

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

### 2026-03-21T16:02:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /home/dimitri-mint-dev/.agentic-framework/.tasks/active/T-516-create-termlink-homebrew-tap-with-github.md
- **Context:** Initial task creation

### 2026-03-21T16:03:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-03-21T16:09:30Z — resumed [agent]
- **Action:** Task reopened to complete Human ACs with full authorization
- **Done:**
  - Cloned termlink repo to /tmp/termlink-work
  - Added GitHub Actions workflow (.github/workflows/release.yml)
  - Fixed rust-toolchain action name (was rust-action, now rust-toolchain)
  - Changed Rust edition from 2024 to 2021 for stable compatibility
  - Pushed to both OneDev and GitHub remotes
  - Created and pushed v0.1.0 tag (triggers builds)
  - Prepared homebrew tap at /tmp/homebrew-termlink/ (Formula/termlink.rb)
- **Blocked:**
  - `gh auth` token expired - cannot create homebrew-termlink repo via API
  - GitHub Actions builds failing - needs dependency version fixes
