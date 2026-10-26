# aef-start

> aef-start.sh — the P-01 one-click launcher (T-3659), reference copy (T-4721).

**Type:** script | **Subsystem:** unknown | **Location:** `install/launcher/aef-start.sh`

## What It Does

aef-start.sh — the P-01 one-click launcher (T-3659), reference copy (T-4721).
What the desktop icon runs: cd into the project, start Watchtower detached and
open it, run Claude Code under claude-fw, then leave the user in a project shell.
aef-start.sh [--new] [PROJECT_DIR]
Default: CONTINUE the project's last conversation (`claude-fw -c`). After a
restart the icon must take the operator back into the running work (055,
'greenfield', 2026-10-23); `--new` opens a fresh conversation instead.
How the fallback behaves (and why it is not `claude-fw -c || claude-fw`):
- claude-fw resolves -c to this project's interactive conversation, and with
none it already starts fresh (T-4497), so -c needs no fallback there.

---
*Auto-generated from Component Fabric. Card: `install-launcher-aef-start.yaml`*
*Last verified: 2026-10-25*
