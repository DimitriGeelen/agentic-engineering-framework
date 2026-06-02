---
id: T-1481
name: "T-1481: fw upgrade --dedupe-user-hooks opt-in flag — backs up + removes framework hooks from ~/.claude/settings.json that duplicate project-level"
description: >
  T-1481: fw upgrade --dedupe-user-hooks opt-in flag — backs up + removes framework hooks from ~/.claude/settings.json that duplicate project-level

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-25T21:46:53Z
last_update: 2026-04-25T21:49:42Z
date_finished: 2026-04-25T21:49:42Z
---

# T-1481: T-1481: fw upgrade --dedupe-user-hooks opt-in flag — backs up + removes framework hooks from ~/.claude/settings.json that duplicate project-level

## Context

T-1479 + T-1480 surface the duplicate-hook overlap; users still have to hand-edit `~/.claude/settings.json` to fix it. Add an opt-in `--dedupe-user-hooks` flag to `fw upgrade` that:
1. Reads `$HOME/.claude/settings.json`
2. Identifies framework hooks (commands containing `fw hook` or `.agentic-framework`) that duplicate project-level
3. Backs up to `$HOME/.claude/settings.json.bak-<timestamp>`
4. Removes the duplicates (preserving non-framework user-level hooks)
5. Reports what was removed

Opt-in only — never auto-runs. Honors `--dry-run` (show what would be removed). Empty hook arrays are pruned to keep the file clean.

## Acceptance Criteria

### Agent
- [x] `fw upgrade --dedupe-user-hooks` removes framework hooks from `~/.claude/settings.json` that duplicate project-level
- [x] Backup created at `~/.claude/settings.json.bak-<epoch>` before modification
- [x] Non-framework hooks in user-level are preserved (untouched)
- [x] `--dedupe-user-hooks --dry-run` shows what would be removed without modifying
- [x] When no overlap, no backup is created and a "no duplicates" message is printed
- [x] When `~/.claude/settings.json` doesn't exist, the flag exits cleanly (gated by `if [ -f $user_settings ]` block)
- [x] `--help` mentions the flag (verified — bin/fw upgrade --help shows it)
- [x] `bash -n lib/upgrade.sh` passes
- [x] bats test `tests/unit/upgrade_dedupe_user_hooks.bats` passes (10/10)

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

grep -q "dedupe-user-hooks" lib/upgrade.sh
grep -q "dedupe-user-hooks" lib/upgrade.sh && grep -q "dedupe_user_hooks" lib/upgrade.sh
bash -n lib/upgrade.sh
cd /opt/999-Agentic-Engineering-Framework && bats tests/unit/upgrade_dedupe_user_hooks.bats

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

### 2026-04-25T21:46:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1481-t-1481-fw-upgrade---dedupe-user-hooks-op.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-269bfa84
- **Timestamp:** 2026-06-02T14:57:46Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Per-AC findings:**

- **AC#1 (Agent)** — `fw upgrade --dedupe-user-hooks` removes framework hooks from `~/.claude/settings.json` that duplicate project-level
  - **AC-verify-mismatch** (narrow, heuristic) — `path=claude/settings.json in: `fw upgrade --dedupe-user-hooks` removes framework hooks from `~/.claude/settings.json` that duplicate project-level`
- **AC#2 (Agent)** — Backup created at `~/.claude/settings.json.bak-<epoch>` before modification
  - **AC-verify-mismatch** (narrow, heuristic) — `path=claude/settings.json in: Backup created at `~/.claude/settings.json.bak-<epoch>` before modification`
- **AC#6 (Agent)** — When `~/.claude/settings.json` doesn't exist, the flag exits cleanly (gated by `if [ -f $user_settings ]` block)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=claude/settings.json in: When `~/.claude/settings.json` doesn't exist, the flag exits cleanly (gated by `if [ -f $user_settings ]` block)`
### 2026-04-25T21:49:42Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
