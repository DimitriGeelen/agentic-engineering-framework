# t4510_sed_exec

> T-4510 (SECURITY, G-121): the read-only allowlist admitted sed on the argument that its only write routes (-i, w FILE) are gated by the outer raw-text rules.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4510_sed_exec.bats`

## What It Does

T-4510 (SECURITY, G-121): the read-only allowlist admitted sed on the argument that
its only write routes (-i, w FILE) are gated by the outer raw-text rules. GNU sed
also RUNS commands: the `e` command (`e CMD`, `1e CMD`) and the `e` flag of `s`.
Reported by ring20-dashboard (msg af2bbc85).
Fix: agents/context/lib/safe-commands.sh _fw_sed_runs_command — options are a
whitelist (-f/--file hide the script; unknown or ambiguous long options fail
closed), and every script is judged by lib/shell_write_scan.py sed_script_risk, a
command-by-command sed parser in which regexes, replacements and `a` text are data.
Classification only: nothing here is executed.
`! cmd` at statement position is INERT in bats (L-628), so NOT-SAFE assertions use

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4510_sed_exec.yaml`*
*Last verified: 2026-10-20*
