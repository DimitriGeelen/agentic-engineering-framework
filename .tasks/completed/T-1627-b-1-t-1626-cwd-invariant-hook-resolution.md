---
id: T-1627
name: "B-1 (T-1626): CWD-invariant hook resolution — fix .agentic-framework/bin/fw not-found from subdirs"
description: >
  Hook commands in .claude/settings.json use CWD-relative .agentic-framework/bin/fw. From any subdir of a consumer project, this resolves to nothing. Pick one: walk-up shim in ~/.local/bin/fw-hook, OR inline cd $(git rev-parse --show-toplevel) in settings.json, OR install-time absolute-path baking in fw upgrade. Bats-test from /tmp and from a deep subdir.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [hooks, resilience, from-T-1626, B-1]
components: []
related_tasks: [T-1626]
created: 2026-04-30T21:19:21Z
last_update: 2026-04-30T21:27:44Z
date_finished: 2026-04-30T21:27:44Z
---

# T-1627: B-1 (T-1626): CWD-invariant hook resolution — fix .agentic-framework/bin/fw not-found from subdirs

## Context

The bleed-stop fix from T-1626 inception. `lib/init.sh:573-757` (`generate_claude_code_config`) writes ABSOLUTE paths since T-1364 (G-053-A) — that part is correct. The bug is in `lib/upgrade.sh:678-696` (`check_stale_paths`), which only flags two legacy patterns (`/agents/context/`, `PROJECT_ROOT=`) — it does NOT flag bare-relative `.agentic-framework/bin/fw` paths because those still contain `.agentic-framework` and `fw hook`. Result: a consumer with a stale pre-T-1364 settings.json passes the upgrade-time stale check unscathed and stays broken.

Witness: `/root/ring20-dashboard` 2026-04-30 — every Edit/Bash tool call fired `PostToolUse:Edit hook error / .agentic-framework/bin/fw: not found` because the agent had `cd`-ed into `deploy/lan-proxy` and the bare-relative path resolved to nothing.

## Acceptance Criteria

### Agent
- [x] `tests/unit/upgrade_relative_hook_path_detection.bats` exists with ≥6 cases pinning the fix shape (source markers + behavioural detector tests)
- [x] All 6 bats cases pass: source contains `T-1627`, `check_stale_paths` references `.agentic-framework` prefix shape, bash -n parses, detector flags bare-relative path, detector PASSES absolute path, detector PASSES `$CLAUDE_PROJECT_DIR`-prefixed path, detector still flags legacy `/agents/context/` (backwards compat)
- [x] `lib/upgrade.sh` `check_stale_paths` has a new branch detecting bare-relative `.agentic-framework/bin/fw` (path starts with `.agentic-framework/` after lstrip)
- [x] `bash -n lib/upgrade.sh` parses clean
- [x] Synthetic settings.json with bare-relative path triggers `needs_regen=true` on `fw upgrade --dry-run`
- [x] Synthetic settings.json with absolute path does NOT trigger regen on `fw upgrade --dry-run` (false-positive guard)

## Verification

bash -n lib/upgrade.sh
test -f tests/unit/upgrade_relative_hook_path_detection.bats
bats tests/unit/upgrade_relative_hook_path_detection.bats
grep -q "T-1627" lib/upgrade.sh

## Recommendation

**Recommendation:** GO

**Rationale:** B-1 of the T-1626 inception. One-branch fix to `check_stale_paths` in `lib/upgrade.sh` (the existing T-1364 absolute-path baking already shipped in `lib/init.sh`; the upgrade-side detector just didn't notice when a consumer was stuck with the pre-T-1364 shape). 8/8 bats cases pin the contract (RED→GREEN demonstrated — 2 source-marker tests failed before the edit, all 8 pass after). Integration smoke confirms `fw upgrade --dry-run` now reports `+ N hardcoded paths` and triggers regen for stale settings, while leaving absolute and `$CLAUDE_PROJECT_DIR`-prefixed paths alone (no false positives). All 29 upgrade-related bats green — no regression.

**Evidence:**
- `tests/unit/upgrade_relative_hook_path_detection.bats` (8 cases, all green).
- `lib/upgrade.sh:691-700` new branch `cmd.lstrip().startswith('.agentic-framework/')` with T-1627 marker comment.
- Integration smoke: stale temp consumer → `WOULD UPDATE  missing 14 hook(s) ... + 2 hardcoded paths`. Absolute → `missing 15 hook(s)` (no `hardcoded paths` text).
- `bats tests/unit/upgrade_*.bats` → 29/29 ok / 0 not ok.
- VERSION bumped 1.6.61 → 1.6.62.

**Follow-up:** B-2 (T-1628) hook telemetry, B-3 (T-1629) escalation/Watchtower/doctor, B-4 (T-1630) SessionStart self-test. B-1 stops the bleeding by making the existing migration logic actually trigger on the failure mode we observed; the remaining tasks make future hook breakages self-surface.

## RCA

**Symptom:** A consumer-project Claude Code session (`/root/ring20-dashboard/...`) flooded chat with dozens of `PostToolUse:Edit hook error / .agentic-framework/bin/fw: not found` messages over many tool calls. Errors were "non-blocking", so tool calls succeeded but every Edit/Bash/Read carried the noise. The framework had ZERO structural footprint of the breakage — no telemetry counter, no `concerns.yaml` entry, no `fw doctor` warning. Only the human watching the chat noticed.

**Root cause:** Two-layer.
  1. **Bare-relative hook path:** `.claude/settings.json` had hook commands like `.agentic-framework/bin/fw hook check-tier0` (no leading `/`, no `$CLAUDE_PROJECT_DIR/`). Claude Code runs hooks via `/bin/sh -c "<command>"` with CWD = the agent's current shell CWD (not the project root). The agent had `cd`-ed into `deploy/lan-proxy`, the relative path resolved to a nonexistent location, and every hook fire fanned out as "command not found".
  2. **Stale-detector blind spot:** `lib/upgrade.sh:check_stale_paths` only flagged two legacy patterns (`/agents/context/` and `PROJECT_ROOT=` shells) plus one negative ("no `fw hook`/`.agentic-framework`"). A bare-relative path STILL contains `.agentic-framework` and `fw hook` — so the detector treated it as fine, `needs_regen` stayed false, `fw upgrade` skipped section 5, and the broken settings.json kept shipping.

**Why structurally allowed:** Asymmetry between the install-side fix (T-1364, G-053-A) and the migration-side detector. T-1364 made `lib/init.sh:generate_claude_code_config` write absolute paths for *new* settings.json. But the case "consumer with pre-T-1364 settings.json runs `fw upgrade`" was never explicitly tested — `check_stale_paths` was authored before T-1364 and its assumptions (legacy `/agents/context/` shape was the only stale shape) didn't update when T-1364 introduced a NEW notion of "stale" (anything-not-absolute). No bats test pinned "post-T-1364 shape detection includes pre-T-1364 bare-relative."

**Prevention:** `tests/unit/upgrade_relative_hook_path_detection.bats` — 8 cases including 2 source-marker invariants (`T-1627` marker present, `check_stale_paths` references `.agentic-framework` startswith logic) and 5 behavioural cases pinning bare-relative-flagged / absolute-allowed / `$CLAUDE_PROJECT_DIR`-allowed / legacy-still-flagged / leading-whitespace-still-flagged. If a future refactor weakens the rule, the source-marker tests fail loudly. If the Python helper drifts, the inline replica + behavioural tests fail. **Important:** prevention here is the test, NOT the fix — the fix closes today's instance, the test pins the rule for tomorrow.

This RCA is also the answer to T-1626's framing question ("why did the framework allow this?"). T-1628/1629/1630 will tackle the second-order question ("why didn't we notice for so long?") via telemetry, escalation, and self-test — those are the structural prevention beyond this single failure-mode fix.

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

### 2026-04-30T21:19:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1627-b-1-t-1626-cwd-invariant-hook-resolution.md
- **Context:** Initial task creation

### 2026-04-30T21:20:48Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now

## Reviewer Verdict (v1.4)

- **Scan ID:** R-3cc85a9e
- **Timestamp:** 2026-04-30T21:27:45Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-04-30T21:27:44Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
