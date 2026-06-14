# T-2389 — arc-012 continuous-mode live-fire via TermLink: evidence + finding

**Date:** 2026-06-14
**Arc:** arc-012 (`continuous-run`), anchor T-2158
**Driver:** TermLink-orchestrated, per operator instruction "drive the live-fire via TermLink"
**Result:** **NO-GO for closure via this run.** The loop did **not** fire end-to-end.
The live-fire surfaced a real integration gap (below) that the four per-link
unit/integration tests cannot see because they stub the transcript and run `fw`
from the correct cwd.

---

## What was set up (all verified)

| Step | Evidence |
|------|----------|
| Isolated worktree off master | `.claude/worktrees/arc012-livefire-demo`, own git-toplevel → isolated `.restart-requested` (avoids OBS-075 collision with the 2 live `claude-fw` wrappers on the master checkout, PIDs 1752988/1753004) |
| `startup` matcher present (T-2376) | worktree `.claude/settings.json` SessionStart = `['compact','resume','startup']` |
| T-2377 gauge fix present | `transcript_path` referenced in worktree `agents/context/checkpoint.sh` |
| T-2373 terminator present | `restart_sentinel` in worktree `bin/claude-fw` |
| continuous-mode seeded | `enabled: true, max_iterations: 3, tier_ceiling: 1, current_iteration: 0` |
| directive seeded | `.next-directive.yaml` (append-to-log per cycle) |

## Driving the session (TermLink → tmux backend)

A real interactive `claude-fw → claude` (Claude Code **v2.1.177**, Opus 4.8) was
spawned in a tmux-backed TermLink session (`arc012-livefire`) with
`FW_CONTEXT_WINDOW=20000`, and driven via `tmux send-keys`. Three first-run gates
had to be cleared before a classic session ran — none of which the runbook
anticipates:

1. **Trust dialog** — the new worktree path was absent from `~/.claude.json`;
   a bare background PTY exited on the prompt. Fixed by pre-seeding
   `hasTrustDialogAccepted` for the worktree.
2. **FleetView launcher** — `command claude` with no args opens the multi-agent
   FleetView ("describe a task for a new session"), where a typed prompt becomes a
   *separate* child task whose context does not climb the parent transcript the
   gauge reads. Bypassed by passing a **positional prompt** (`claude "<prompt>"`),
   which starts a classic single session.
3. **MCP approval** — "5 new MCP servers found in this project" blocked startup;
   config-level `disabledMcpjsonServers` did not suppress the discovery dialog, so
   it was dismissed with `Esc` (reject all). The loop needs no MCP.

The classic session then ran a real burn (read CLAUDE.md, FRAMEWORK.md, the
runbook, and four loop scripts in full; printed `DONE-BURN`), climbing to
**~179000 real context tokens** — far past the 19000-token framework critical.

## The finding (root cause)

Despite ~179K real tokens, **no `.budget-status`, no `.tool-counter`, and no
`.restart-requested` were ever written** in the worktree, and `current_iteration`
stayed `0`. Two facts pin the cause:

1. **The budget gauge's primary trigger only matches `Write|Edit|Bash`.** The
   PreToolUse `budget-gate` matcher is `Write|Edit|Bash` (not `Read`). A
   Read-only burn never invokes it. (Driving correction, not a loop bug.)
2. **When the session finally issued a Bash call, the hook chain fired but fw
   resolved `PROJECT_ROOT` to `/root`, not the worktree.** The `check-project-boundary`
   hook (T-559) blocked the Bash with the literal banner **"Project root: /root"**.
   Because every fw-backed hook in that chain (including `budget-gate` and the
   PostToolUse `checkpoint`) resolves the same wrong root, the gauge reads/writes
   the wrong location → critical is never detected → `checkpoint.sh` never reaches
   its auto-handover block → `.restart-requested` is never written → the loop
   never arms.

```
══════════════════════════════════════════════════════════
  PROJECT BOUNDARY BLOCK — Command Targets Another Project
  ...
  Project root: /root
  Policy: T-559 (Project Boundary Enforcement)
══════════════════════════════════════════════════════════
```

This is the **same class as T-2377** (the gauge reading the wrong directory), but
manifesting through the *hook execution cwd / `CLAUDE_PROJECT_DIR`* rather than the
transcript path. The session's hooks resolve to `/root` — most likely because the
tmux-`bash -lc 'cd … && exec claude-fw'` launch path did not propagate
`CLAUDE_PROJECT_DIR` (or Claude Code 2.1.177 runs hooks from `$HOME`), so fw fell
back to the home directory.

## Why the per-link tests didn't catch it

`tests/integration/{budget_gauge_stdin_transcript,continuous_loop_critical_signal,
claude_fw_restart_terminator,continuous_loop_auto_restart_advance}.bats` each stub
the transcript and invoke the scripts with a controlled `PROJECT_ROOT`/cwd. None
exercises a **real Claude Code session whose hooks resolve their own project
root**. The integration gap lives precisely at that join.

## Recommendation

- **Loop status:** all four links are individually coded + tested, but the
  end-to-end headline mechanic is **NOT demonstrated** — arc-012 must not be
  closed on "substrate is in place" (that phrasing is the §ACD violation the
  arc-close gate guards against).
- **Two follow-ups (one bug = one task):**
  1. **Hook project-root resolution** — fw resolves `PROJECT_ROOT` to `/root`
     when a Claude Code 2.1.177 session's hooks run without a propagated
     `CLAUDE_PROJECT_DIR`. Confirm whether this also affects normal sessions on
     the main checkout (the memory note that the gauge was "live-proven" on master
     suggests it may be specific to the tmux-spawn launch path — needs a
     controlled check). If general, it is a higher-priority gauge-blinding bug
     than T-2377.
  2. **Runbook hardening** — the canonical live-fire must document the three
     2.1.177 first-run gates (trust / FleetView / MCP) and require launching with a
     positional prompt; and the runbook's "interactive terminal" path is the
     reliable one because the operator's own terminal session propagates
     `CLAUDE_PROJECT_DIR` correctly.
- **For the demo the operator wants:** the most reliable path remains the
  **canonical interactive run on the main checkout** (operator launches
  `claude-fw` in a real terminal, where hooks resolve correctly — proven by the
  main repo's live `.budget-status` and by this driving session's own working
  gauge). TermLink driving is viable for spawning/observing but, in 2.1.177,
  introduces the `/root` hook-resolution artifact above.
