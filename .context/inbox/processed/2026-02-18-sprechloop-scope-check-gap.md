# Framework Feedback: check-active-task Hook Lacks Scope Validation (G-004)

**Source:** sprechloop project (001-sprechloop), discovered 2026-02-18
**Priority:** High
**Filed by:** human + agent during T-027 review

---

## Problem

`check-active-task.sh` only checks **existence** of a focused task, not **relevance**.
When task T-027 (mic selector) was active, the agent made an unrelated change (AGC
toggle) and the hook passed because "a task exists." The agent even suggested "no
task needed" — violating the core principle — and the hook couldn't catch it.

## Impact

- Untracked work generates no episodic memory → knowledge leak
- Changes get buried in wrong task's commit history → hard to find later
- The "Nothing gets done without a task" principle has a structural loophole

## Root Cause

The hook is binary: active task exists → allow. It has no concept of whether the
edit relates to the task's scope (acceptance criteria, files changed, description).

## Suggested Fixes

**Level 1 — Agent discipline (immediate, done):**
Learning L-016 recorded: agent must NEVER suggest skipping tasks.

**Level 2 — Audit check (low effort):**
Post-completion audit: compare committed files against task's ## Verification and
## Acceptance Criteria. Flag commits that touch unrelated files.

**Level 3 — Commit-msg hook enhancement (medium effort):**
At commit time, check if committed files were touched by the focused task's previous
commits. Warn if new files appear that weren't part of the task before.

**Level 4 — Scope-aware PreToolUse (high effort):**
Hook reads the focused task's AC and description, compares against the file being
edited. Would need an LLM call (expensive) or a simpler heuristic (file list match).

## Recommendation

Level 1 is done. Level 2 is practical and catches this retroactively. Level 3
catches it at commit time. Level 4 is aspirational.
