# t4499_sidecar_body_data

> T-4499: the Human-AC tick guard (check-human-ac-tick, Bash leg) refused `fw sidecar send ...

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4499_sidecar_body_data.bats`

## What It Does

T-4499: the Human-AC tick guard (check-human-ac-tick, Bash leg) refused
`fw sidecar send ... --body '<text>'` because the message quoted an example git
command with a variable --output option (`git log --output="$F"`) next to a .tasks
path. lib/shell_write_scan.py turned the backticks inside the single-quoted body
into command breaks (_tokens) and read the backtick body as a substitution
(_substitutions), so `git log --output=$F` became a git command with an unresolved
--output target in a command that names a guarded path.
Fix: _blank_data_args blanks a SINGLE-quoted --body value of `fw sidecar send`
before scanning. Double-quoted bodies stay scanned (bash runs $(..)/`..` there).
Both directions go through the real hook under CLAUDECODE=1.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4499_sidecar_body_data.yaml`*
*Last verified: 2026-10-20*
