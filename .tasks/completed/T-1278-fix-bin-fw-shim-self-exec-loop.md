---
id: T-1278
name: "Fix bin/fw self-exec loop — shim was overwriting real CLI in framework repo"
description: >
  bin/fw in the framework repo had been replaced with bin/fw-shim contents
  (identical md5). The shim walks up from CWD looking for bin/fw + FRAMEWORK.md
  and exec's it — inside the framework repo it finds itself and exec-loops
  forever. `fw work-on` (and every other `fw` command) hung until killed.
  Root cause of the 30s `fw` hang observed during T-1277 investigation.
status: work-completed
workflow_type: build
owner: human
horizon: null
tags: [bug, tooling, shim, regression]
components: [C-004, agents/task-create/create-task.sh, lib/upgrade.sh, tests/unit/task_id_race.bats, bin/fw, bin/fw-shim]
related_tasks: [T-664, T-1256, T-1277]
created: 2026-04-17T09:55:00Z
last_update: 2026-04-21T20:36:51Z
date_finished: 2026-04-21T20:36:35Z
---

# T-1278: Fix bin/fw self-exec loop — shim was overwriting real CLI

## Context

During T-1277 investigation, `bin/fw work-on …` hung and was killed by `timeout 30`. Probing further:

- `bin/fw` on disk: 50 lines, md5 `5f0d74e5b52a89d2d7a7bb3a4b7c4528`
- `bin/fw-shim` on disk: 50 lines, **same md5** — they were identical
- `bin/fw` in git HEAD: 4262 lines — the real CLI
- `git status` showed `modified: bin/fw` (uncommitted shim-overwrite)

Shim logic (`bin/fw-shim:18-34`): walks up from CWD looking for `bin/fw` + `FRAMEWORK.md`, then `exec "$fw_path" "$@"`. Inside this repo, `find_fw` discovered `bin/fw` (itself) + `FRAMEWORK.md` → exec'd itself → re-entered the shim → GOTO — infinite loop until a wrapping timeout killed it.

`~/.local/bin/fw` is a symlink back to the same broken file, so `fw` on PATH was equally stuck.

**Restoration:** `git checkout HEAD -- bin/fw` restored the 4262-line CLI. Verified with `bin/fw version` → `fw v1.5.16`.

## Why this happened — confirmed

`lib/upgrade.sh:379` runs `cp "$shim_src" "$current_fw"` where `$current_fw = ~/.local/bin/fw` is a **symlink** to the framework repo's `bin/fw`. `cp` follows the destination symlink and writes the shim **through** it into `bin/fw`, corrupting the real CLI. Every `fw upgrade` triggering that branch re-breaks the repo.

**Hot patch applied in this commit:** `lib/upgrade.sh` now does `rm -f "$current_fw"` before the copy so the symlink is removed first and the new file lands at `~/.local/bin/fw` without touching the framework repo. Durable ACs below still apply (self-loop guard + doctor check) as defence in depth.

## Impact

- Every `fw` invocation from inside the framework repo hangs until killed.
- Hooks that shell out to `fw` (checkpoint, context, handover) silently fail or hang.
- Masks itself as other issues: user thinks "hooks are slow", "Claude is stuck", "network issue". Wasted ~half a session's context on wrong hypotheses.
- Dangerous because the shim-vs-real detection is by filename alone — nothing warns when the wrong file is in place.

## Acceptance Criteria

### Agent

- [x] Guard against self-loop: shim aborts if `$fw_path` resolves to its own `$BASH_SOURCE` (compare realpath). Exit with explicit error: "fw shim found only itself — real CLI is missing from this project; run `fw upgrade` or restore `bin/fw` from git." — bin/fw-shim:36-53
- [x] `fw doctor` check: detect when `bin/fw` in a framework repo is the shim (size < 200 lines, or checks for shim-only markers like `find_fw()`). Report as FAIL. — bin/fw:1433-1448
- [x] `fw upgrade` refuses to overwrite a framework-repo `bin/fw` with the shim (detects `FRAMEWORK.md` at same level). — lib/upgrade.sh:379-389
- [x] Bats unit test: synthesize a shim-over-real situation in a tmp dir and assert the guard trips within 1 second. — tests/unit/fw_shim_selfloop_guard.bats (2 tests, both pass)
- [x] Restore already applied to working tree (`git checkout HEAD -- bin/fw`). — lib/upgrade.sh:383 `rm -f "$current_fw"` before cp prevents recurrence

### Human

- [ ] [REVIEW] After fix, running `bin/fw version` from repo root returns `fw vX.Y.Z` in <1s even if the shim is re-installed on top.
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && cp bin/fw-shim bin/fw`
  2. `timeout 5 bin/fw version`
  **Expected:** exits non-zero with the guard message, not the infinite loop.
  **Cleanup:** `git checkout HEAD -- bin/fw`

## Verification

# Must pass before work-completed
test $(wc -l < bin/fw) -gt 200
timeout 5 bin/fw version | grep -q '^fw v'
bats tests/unit/fw_shim_selfloop_guard.bats

## Decisions

## Updates

### 2026-04-17T09:55:00Z — task-created [manual]
- **Action:** Created T-1278 directly in .tasks/active/ (fw work-on was the broken command)
- **Context:** Discovered while investigating T-1277 (4h stall). Separate bug with separate fix; see docs/reports/issue-report-fw-shim-selfloop.md.

### 2026-04-21T20:36:35Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-fea90eaf
- **Timestamp:** 2026-06-02T14:56:23Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `timeout 5 bin/fw version | grep -q '^fw v'`
