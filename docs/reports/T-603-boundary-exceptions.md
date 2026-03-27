# T-603: Project Boundary Exceptions — /etc/cron.d and Other Legitimate Outside-PROJECT_ROOT Writes

## Problem Statement

Framework enforces project isolation: agents stay within PROJECT_ROOT. The boundary gate (T-559) blocks writes outside this boundary. However, `/etc/cron.d/` writes are a legitimate exception — cron jobs MUST live outside PROJECT_ROOT.

## Key Findings

### Outside-Boundary Write Inventory
- `/etc/cron.d/` — cron job definitions (required for audit scheduling)
- `/tmp/` — transient agent files (framework already handles this)
- No other legitimate outside-boundary writes identified

### Options Evaluated
1. **Whitelist in boundary gate** — ad-hoc carve-outs, brittle
2. **Escape hatch flag** — weakens general boundary, exploitable
3. **Symlink architecture (Option E)** — cron defs inside project, symlink from `/etc/cron.d/`. Works but requires root-owned targets, not portable to macOS launchd
4. **Copy-on-change with drift detection (Option F)** — cron defs as git-tracked project artifacts in `PROJECT_ROOT/.context/cron/`, copied to `/etc/cron.d/` with graceful sudo degradation and audit drift detection

### Decision: GO with Option F

**Why:** Eliminates ongoing boundary violations. Cron definitions become normal project files (git-tracked, auditable). Copy step uses sudo when available, degrades gracefully with clear instructions when not. Works cross-platform (cron.d, launchd, systemd timers). Related: T-604 (build task for copy-on-change implementation).

## Dialogue Log

- Human proposed Option E (symlinks) and Option F (copy-on-change)
- Agent validated cron symlink constraints and portability trade-offs
- Decision: Option F wins on portability and graceful degradation
