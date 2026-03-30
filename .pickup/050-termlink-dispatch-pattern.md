# Document TermLink Agent Dispatch Pattern

**Source:** 050-email-archive, T-400 | **Priority:** P2 | **Date:** 2026-03-30

## Learning
termlink_spawn command array doesn't support cwd. Correct pattern for worktree dispatch:
1. `termlink_spawn` with `command: ["bash"]`
2. `termlink_interact` with `cd /worktree && claude -p "prompt"`

## Also Discovered
- Spawned sessions with tags sometimes fail to register (timeout)
- Sessions that timeout on registration become unreachable by name
- Need to verify session exists via `termlink_list_sessions` before interacting

## Additional: Worktree Merge Protocol Needed

After parallel dispatch, 10 branches exist in worktrees. No automated merge-back pattern exists. Need:
1. `fw termlink merge` — merge all worktree branches sequentially with conflict detection
2. Timeout calibration guidance — heavy tasks (>1000 LOC files) need 600s+, light tasks 120s
3. False-timeout detection — check worktree for commits even when exec reports timeout
