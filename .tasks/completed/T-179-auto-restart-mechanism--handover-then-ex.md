---
id: T-179
name: "Auto-restart mechanism — handover then exit then auto-resume"
description: >
  Investigate automatic session restart after handover so context recovery is seamless without human intervention. Approaches to explore: (1) Wrapper script around claude that monitors exit status file, (2) Shell trap that catches exit and runs claude --continue/--resume, (3) .context/working/.restart-requested flag set by budget gate before forcing exit, (4) fswatch/inotifywait monitoring the flag file, (5) Systemd user unit. Key questions: Can Claude Code exit cleanly from within a session? What does claude --continue vs --resume do? Can we pass initial commands (e.g., auto-run /resume)? What's the UX — does the user see a brief flash or seamless continuation? Relates to T-174 (Option B architecture), T-173 (budget gate handover fix), T-175 (stronger emergency handover).

status: work-completed
workflow_type: inception
owner: claude-code
horizon: next
tags: []
related_tasks: []
created: 2026-02-18T19:27:34Z
last_update: 2026-02-19T07:37:31Z
date_finished: 2026-02-19T07:37:31Z
---

# T-179: Auto-restart mechanism — handover then exit then auto-resume

## Problem Statement

With compaction disabled (T-174), sessions end when the budget gate forces handover at critical. The user must then manually run `claude -c` to start a new session. This breaks autonomous workflow. Can we make the transition seamless — handover completes, session ends, new session starts automatically with `fw resume`? Preliminary research in docs/reports/T-179-session-restart-mechanisms.md found: `claude -c` resumes most recent session, no native auto-restart exists, external tool `claude-auto-resume` exists on GitHub, flag-file approach (`.context/working/.session-ended` + wrapper script) is viable.

## Assumptions

1. `claude -c` reliably resumes the most recent session with full conversation history — **VALIDATED**: Yes, it loads the `.jsonl` transcript in full. Sessions stored in `~/.claude/projects/<encoded-path>/`.
2. `SessionEnd` hook fires on normal exit and can write signal files — **VALIDATED**: Hook exists with matchers: `clear`, `logout`, `prompt_input_exit`, `bypass_permissions_disabled`, `other`. Receives `session_id` and `transcript_path`.
3. `SessionStart` hook can fire on `claude -c` resume — **VALIDATED**: `SessionStart` event fires with matcher `resume` when using `-c` or `-r`. Currently only configured for `compact` matcher.
4. The budget gate can write a signal file at critical level — **VALIDATED**: Trivial addition before `exit 2` in the critical branch of `budget-gate.sh`.
5. Claude Code cannot exit itself programmatically from within a session — **VALIDATED**: No documented mechanism. `exit N` in Bash tool only exits the subprocess.

## Investigation Findings

### Approaches Evaluated

| Approach | Mechanism | Verdict |
|----------|-----------|---------|
| A. `claude-auto-resume` (terryso) | Stdout string parsing for rate-limit messages | **REJECT** — targets rate limits not context limits, brittle parsing, requires `--dangerously-skip-permissions` |
| B. `while true; do claude -c; done` | Unconditional restart loop | **REJECT** — no gating, restarts on intentional exit, hides session boundaries |
| C. Exit-code wrapper (panozzaj pattern) | Agent runs `exit 129`, wrapper catches code | **REJECT** — `exit N` in Bash tool doesn't exit Claude Code process, only the subprocess |
| D. Flag-file + wrapper function | Handover writes `.restart-requested`, wrapper checks on exit | **GO** — clean, opt-in, builds on existing hooks |
| E. `SessionEnd` hook + inotifywait | Hook writes signal, external watcher restarts | **REJECT** — unnecessary complexity vs. wrapper checking file after exit |
| F. `Stop` hook blocking | Prevent agent from stopping, force more turns | **REJECT** — fights the budget gate's purpose, doesn't solve context exhaustion |

### Recommended Architecture (Option D)

**Three components:**

1. **Signal file creation** (inside session, at critical budget):
   - `checkpoint.sh` auto-handover at critical already runs `handover.sh --commit`
   - After successful handover commit, write `.context/working/.restart-requested` with timestamp
   - Alternatively: explicit `fw session request-restart` command

2. **Wrapper function** (user's shell profile or `bin/claude-fw`):
   ```bash
   claude-fw() {
     while true; do
       command claude "$@"
       local signal="$(git rev-parse --show-toplevel 2>/dev/null)/.context/working/.restart-requested"
       if [ -f "$signal" ]; then
         local age=$(( $(date +%s) - $(stat -c %Y "$signal" 2>/dev/null || echo 0) ))
         if [ "$age" -lt 300 ]; then  # 5-minute TTL
           echo "Auto-restarting session (handover committed)..."
           rm -f "$signal"
           sleep 2
           set -- -c  # next iteration continues last session
         else
           echo "Stale restart signal (${age}s old), ignoring."
           rm -f "$signal"
           break
         fi
       else
         break
       fi
     done
   }
   ```

3. **SessionStart:resume hook** (context injection on `claude -c`):
   - Extend existing `post-compact-resume.sh` or add new hook with matcher `resume`
   - Inject handover context into the fresh session
   - Same mechanism as the existing `compact` hook

**Flow:**
```
Budget critical → checkpoint.sh auto-handover → .restart-requested written
  → Agent wraps up → User exits (or session ends naturally)
  → claude-fw wrapper detects signal → sleep 2 → claude -c
  → SessionStart:resume fires → Context injected → /resume auto-runs
```

### Edge Cases Addressed

- **Crash recovery**: `SessionEnd` hook doesn't fire on crash → signal file not written → wrapper doesn't restart → safe (human intervention needed for crashes)
- **Intentional exit**: User exits without triggering handover → no signal file → wrapper exits normally
- **Stale signal**: TTL of 5 minutes prevents accidental restart from old signals
- **Multiple restarts**: Each restart generates a new handover, which can write a new signal → chain continues until budget is healthy or user intervenes

## Technical Constraints

- `claude -c` loads full session transcript — 90%+ context sessions produce 3-5 MB files, 2-3 second load time
- Session-scoped permissions are NOT restored by `-c` (always-allow rules lost) — user must re-approve or use `--dangerously-skip-permissions`
- `SessionEnd` hook cannot distinguish "context limit" from "other" exit reasons — both map to `other` matcher
- No way for agent to force Claude Code process exit from within a session

## Scope Fence

**IN scope:**
- Signal file mechanism (`.restart-requested`)
- Wrapper script (`bin/claude-fw` or shell function)
- `SessionStart:resume` hook for context injection
- Integration with existing `checkpoint.sh` auto-handover

**OUT of scope:**
- Crash recovery (requires external process monitoring — systemd, supervisor)
- Rate-limit recovery (different problem, different timing — hours not seconds)
- Automatic permission restoration (Claude Code limitation)
- Headless/CI mode (different UX requirements)

## Acceptance Criteria

- [x] Problem statement validated
- [x] Assumptions tested
- [x] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- A clean, simple mechanism exists that doesn't require process monitoring daemons
- It builds on existing framework infrastructure (hooks, handover, budget gate)
- It's opt-in (user chooses to use wrapper, not forced)

**NO-GO if:**
- Requires `--dangerously-skip-permissions` or other unsafe flags
- Requires external dependencies (inotifywait, fswatch, systemd user units)
- Creates hidden session boundaries that the user can't observe

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

**Decision**: GO

**Rationale**: Flag-file + wrapper function approach is simple, opt-in, builds on existing hooks/handover infrastructure, requires no external dependencies or unsafe flags. Three components: signal file from checkpoint.sh, claude-fw wrapper, SessionStart:resume hook.

**Date**: 2026-02-19T07:37:31Z
## Decision

**Decision**: GO

**Rationale**: Flag-file + wrapper function approach is simple, opt-in, builds on existing hooks/handover infrastructure, requires no external dependencies or unsafe flags. Three components: signal file from checkpoint.sh, claude-fw wrapper, SessionStart:resume hook.

**Date**: 2026-02-19T07:37:31Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-02-19T07:31:15Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-19T07:37:31Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Flag-file + wrapper function approach is simple, opt-in, builds on existing hooks/handover infrastructure, requires no external dependencies or unsafe flags. Three components: signal file from checkpoint.sh, claude-fw wrapper, SessionStart:resume hook.

### 2026-02-19T07:37:31Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
