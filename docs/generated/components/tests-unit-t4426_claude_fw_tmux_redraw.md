# t4426_claude_fw_tmux_redraw

> T-4426 (ring20-dashboard proposal): after a mouse-wheel scroll into tmux copy mode, on attach and on resize, Claude Code's screen stays cluttered until Ctrl+L.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4426_claude_fw_tmux_redraw.bats`

## What It Does

T-4426 (ring20-dashboard proposal): after a mouse-wheel scroll into tmux copy mode, on attach
and on resize, Claude Code's screen stays cluttered until Ctrl+L. claude-fw's tmux chain now
sets three hooks that send C-l to the wrapped session's pane. They are scoped to that session
(or its window), never -g: the fw-agents server also carries dispatch workers.
The static leg runs the real claude-fw with a fake tmux that records its argv. The live leg
takes the set-hook groups from that recorded argv and replays them on a throwaway tmux server
with a unique -L name, so it exercises the hook strings claude-fw emits, not a copy of them.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4426_claude_fw_tmux_redraw.yaml`*
*Last verified: 2026-10-19*
