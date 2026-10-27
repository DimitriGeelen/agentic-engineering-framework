# doctor-tmux

> lib/doctor-tmux.sh — T-4781

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/doctor-tmux.sh`

## What It Does

lib/doctor-tmux.sh — T-4781
`fw doctor` check: does one tmux server carry claude-fw sessions of more than one
project? Until T-4781 bin/claude-fw wrapped every project on one shared server
(`tmux -L fw-agents`), and a bare `tmux kill-server` from any project's pane killed
every project's agent on the host at once (dimitri-mint-dev T-188/T-190, 2026-10-26).
claude-fw now starts one server per project (`-L fw-agents-<16 hex>`); this check
reports any server that still mixes projects (the legacy one, while old sessions
live on it). WARN only, never blocks.
Read-only: it only runs `tmux -S <socket> list-sessions` on sockets named fw-agents*
in this user's tmux socket dir — never the default server, never a write.

---
*Auto-generated from Component Fabric. Card: `lib-doctor-tmux.yaml`*
*Last verified: 2026-10-26*
