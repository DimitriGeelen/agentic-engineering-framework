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

- [ ] [REVIEW] Fix remaining GitHub Actions release build errors
  **Status:** CI passes (cargo check), Release fails (cargo build --release)
  **Steps:**
  1. Run `gh auth login` to re-authenticate gh CLI
  2. Check latest build logs: https://github.com/DimitriGeelen/termlink/actions
  3. The following fixes were already applied:
     - Restored edition 2024 (needed for let-chains)
     - thiserror 2 → 1
     - rand 0.9 → 0.8
     - rand::thread_rng().gen() → rand::thread_rng().r#gen() (gen reserved in 2024)
     - Added cmake/clang to CI
     - Fixed rustls 0.23 root_hint_subjects return type
  4. Debug why `cargo build --release` fails when `cargo check` passes
     - Likely aws-lc-rs cross-compilation issue on macOS
     - Try adding CC/CXX env vars or using ring backend
  5. Push fix and delete/recreate v0.1.0 tag: `git tag -d v0.1.0 && git push github :refs/tags/v0.1.0 && git tag v0.1.0 && git push github v0.1.0`
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
  - Downgraded thiserror from 2.x to 1.x (MSRV compatibility)
  - Downgraded rand from 0.9 to 0.8 (API stability)
  - Fixed rand API calls: rand::rng().random() → rand::thread_rng().gen()
  - Rewrote if-let-chain for broader Rust version compatibility
  - Pushed all fixes to both OneDev and GitHub remotes
  - Created and pushed v0.1.0 tag (triggers builds)
  - Prepared homebrew tap at /tmp/homebrew-termlink/ (Formula/termlink.rb)
- **Blocked:**
  - `gh auth` token expired - cannot create homebrew-termlink repo via API
  - GitHub Actions builds still failing - need to check logs with authenticated access
- **Commits pushed:**
  - Add GitHub Actions release workflow for macOS and Linux builds
  - Fix: Use dtolnay/rust-toolchain instead of rust-action
  - Fix: Use Rust 2021 edition for stable toolchain compatibility
  - Fix: Downgrade thiserror to 1.x and rand to 0.8 for stable Rust compatibility
  - Fix: Update rand API calls for 0.8 compatibility (rng -> thread_rng, random -> gen)
  - Fix: Rewrite if-let-chain for broader Rust version compatibility

### 2026-03-21T22:50:00Z — continued work [agent]
- **Action:** Additional fixes pushed in session S-2026-0321-2218
- **Done:**
  - Restored edition = "2024" (required for let-chains used throughout codebase)
  - Fixed reserved keyword: rand::thread_rng().gen() → rand::thread_rng().r#gen() (gen reserved in Rust 2024)
  - Fixed root_hint_subjects return type for rustls 0.23 (Option<&[DistinguishedName]>)
  - Added cmake and clang to CI workflow (required for aws-lc-rs backend)
  - CI workflow (`cargo check`) now passes
- **Still failing:**
  - Release workflow (`cargo build --release`) still failing on both macOS and Linux
  - The stable Rust toolchain DOES support edition 2024 (CI passes)
  - Likely a cross-compilation or aws-lc-rs build issue on macOS
- **Commits pushed:**
  - Fix: Use ring crypto backend for cross-platform builds (reverted)
  - Fix: Add pem feature to rcgen for PEM output support
  - CI: Add check/test workflow for better error visibility
  - Fix: Update TLS config for rustls 0.23 with ring crypto provider (reverted)
  - Fix: Use default rustls features with aws-lc-rs backend
  - CI: Install cmake and clang dependencies
  - Fix: Restore Rust 2024 edition and fix reserved keyword
  - T-530: Use stable toolchain for release builds (matches CI)
- **TermLink repo location:** /tmp/termlink-work
- **Homebrew tap prep:** /tmp/homebrew-termlink/
- **Remotes configured:**
  - origin: OneDev (onedev.docker.ring20.geelenandcompany.com)
  - github: git@github.com:DimitriGeelen/termlink.git
