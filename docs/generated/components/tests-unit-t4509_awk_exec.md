# t4509_awk_exec

> T-4509 (SECURITY, G-121): the read-only allowlist admitted awk on the argument that its only write form needs a literal `>`. awk also RUNS commands: system("…"), "cmd" | getline, print | "cmd", gawk's |& coprocess.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4509_awk_exec.bats`

## What It Does

T-4509 (SECURITY, G-121): the read-only allowlist admitted awk on the argument that
its only write form needs a literal `>`. awk also RUNS commands: system("…"),
"cmd" | getline, print | "cmd", gawk's |& coprocess. Reported by ring20-dashboard
(msg af2bbc85).
Fix: agents/context/lib/safe-commands.sh _fw_awk_runs_command — options are a
whitelist (-f/-E/-i/-l load code, -d/-D/-o/-p write files), and the program text is
judged by lib/shell_write_scan.py awk_program_risk, which skips strings, regex
literals and comments. Classification only: nothing here is executed.
`! cmd` at statement position is INERT in bats (L-628), so NOT-SAFE assertions use
`if cmd; then false; fi`.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4509_awk_exec.yaml`*
*Last verified: 2026-10-20*
