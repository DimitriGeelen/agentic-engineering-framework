# T-502: TermLink Integration Inception — Research Artifact

## Source

Pickup message from TermLink repo session (T-148 on OneDev).
Spec: `docs/specs/T-148-termlink-framework-integration.md` (in TermLink repo).
Repo: `https://onedev.docker.ring20.geelenandcompany.com/termlink`

## What is TermLink?

TermLink is a cross-terminal session communication system built in-house (Rust, 4 crates,
264 passing tests). It provides 26 CLI commands with `--json` output and semantic exit codes.

Key capabilities:
- **Session management** — register, list, discover, status
- **Command execution** — `interact` (wait for result) and `pty inject` (fire-and-forget)
- **Event system** — emit/wait/poll/broadcast between sessions
- **Terminal output** — read/stream with ANSI stripping
- **TCP hub** — cross-machine session routing with heartbeat and hybrid discovery

Installed via: `cargo install --path crates/termlink-cli`

## Proposed Integration (from pickup message)

The spec proposes 5 phases. Phase 0 (foundation) would add:
1. `fw doctor` check — WARN if TermLink not installed (optional tool)
2. `agents/termlink/AGENT.md` — when/how to use TermLink
3. `agents/termlink/termlink.sh` — thin wrapper with 8 subcommands (check, spawn, exec, status, cleanup, dispatch, wait, result)
4. `fw termlink` route in `bin/fw`
5. CLAUDE.md section — primitives, budget rule, cleanup rule

The wrapper is intentionally thin — delegates all real work to the `termlink` binary.
Framework adds: task-tagging, budget checks, cleanup tracking.

## Key Technical Details

### Reference Implementation: tl-dispatch.sh
A battle-tested dispatch script (T-143, 3 parallel workers) exists in the TermLink repo at
`scripts/tl-dispatch.sh`. The wrapper should adapt this, not rewrite it.

### 3-Phase Terminal Cleanup (T-074 lesson)
Never close Terminal.app windows directly. Must:
1. Kill child processes via TTY (spare login/shell)
2. `do script "exit"` for graceful shell exit
3. Close by tracked window ID as fallback

### Platform Considerations
- macOS: Terminal.app via osascript (spawn + window ID tracking)
- Linux: gnome-terminal / x-terminal-emulator / xterm fallback
- TermLink binary is cross-platform (Rust), but terminal spawning is OS-specific

### TermLink Not Installed on Framework Server
This machine (Linux server) does not have TermLink installed. The framework server runs
headless — no terminal emulator for spawn/dispatch. These features are primarily macOS
development workstation features.

The `fw doctor` check and `fw termlink check` will show WARN. The agent wrapper will
fail gracefully with install instructions.

## Questions to Resolve

1. **Is TermLink on this machine?** No. Should it be installed? The framework server is
   headless Linux — spawn/dispatch won't work without a terminal emulator. But `interact`,
   `event`, and `hub` commands work over Unix sockets regardless.

2. **Phase 0 scope right?** The spec is detailed and tested. The 8 subcommands, 3-phase
   cleanup, and fire-and-forget dispatch are well-proven patterns from the TermLink repo.

3. **What can we validate here?** Without TermLink installed, we can validate the wrapper
   structure, doctor check, and CLAUDE.md integration. Full dispatch testing needs the
   macOS workstation.

4. **Decomposition:** Phase 0 is one coherent build task (5 deliverables, all small).
   Phases 1-4 are separate future tasks, each depending on Phase 0.

## Dialogue Log

### Human instruction
"Build Phase 0 based on the spec below."

### Agent initial response
Jumped straight to build (T-502 as build task). Violated G-020 — pickup messages are
proposals, not build instructions. Human corrected: "are we using framework governance????!!!!"

### Course correction
Reverted premature build commit (`1917001`). Created proper inception task. Now doing
exploration/assessment before any code.

## Go/No-Go Assessment

**GO indicators:**
- TermLink is our own project (full control, known quality)
- Spec is detailed with tested reference implementation
- Phase 0 is small (5 deliverables, all framework-side, no TermLink changes needed)
- Optional integration — doctor WARN not FAIL, graceful degradation
- Clear phase boundaries (0-4), Phase 0 has no dependencies

**Concerns:**
- TermLink not installed on this machine — can't fully test
- Terminal spawning is macOS-specific (osascript) — Linux path is untested
- The pickup message was very detailed — which historically correlates with skipping governance (G-020)

**Recommendation:** GO for Phase 0, with build task(s) to follow.
