---
id: T-516
name: "Create TermLink Homebrew tap with GitHub Actions builds"
description: >
  Create TermLink Homebrew tap with GitHub Actions builds

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-21T16:02:14Z
last_update: 2026-03-21T16:02:14Z
date_finished: null
---

# T-516: Create TermLink Homebrew tap with GitHub Actions builds

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] GitHub Actions workflow created for macOS builds (aarch64 + x86_64)
- [x] Homebrew formula template created
- [x] Documentation updated with brew install instructions
- [x] All YAML files valid syntax

### Human
- [ ] [RUBBER-STAMP] Push GitHub Actions workflow to termlink repo
  **Steps:**
  1. Copy `deploy/termlink/github-release.yml` to `termlink/.github/workflows/release.yml`
  2. Push to termlink repo and create a tag (e.g., v1.0.0)
  3. Verify GitHub Actions builds complete for both architectures
  **Expected:** Release artifacts include termlink-darwin-aarch64 and termlink-darwin-x86_64
  **If not:** Check GitHub Actions logs for build errors

- [ ] [RUBBER-STAMP] Create Homebrew tap repo and publish formula
  **Steps:**
  1. Create repo github.com/DimitriGeelen/homebrew-termlink
  2. Copy `deploy/termlink/termlink.rb` to the tap repo
  3. Update SHA256 hashes from GitHub release
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
