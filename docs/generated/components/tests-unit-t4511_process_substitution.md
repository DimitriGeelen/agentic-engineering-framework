# t4511_process_substitution

> T-4511 (SECURITY, G-121): process substitution runs a command whatever the outer verb is, and the read-only allowlist judged only the outer verb: `cat <(touch x)`, `grep x <(touch x)` and `diff <(touch a) <(touch b)` read as SAFE (the…

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4511_process_substitution.bats`

## What It Does

T-4511 (SECURITY, G-121): process substitution runs a command whatever the outer
verb is, and the read-only allowlist judged only the outer verb: `cat <(touch x)`,
`grep x <(touch x)` and `diff <(touch a) <(touch b)` read as SAFE (the redirect scan
only sees `>`). Reported by ring20-dashboard (msg af2bbc85).
Fix: is_bash_safe_command refuses `<(` / `>(` anywhere on the line
(_fw_has_process_subst), skipping only an escaped character and, on a line with no
double quote, single-quoted text. Classification only: nothing here is executed.
`! cmd` at statement position is INERT in bats (L-628), so NOT-SAFE assertions use
`if cmd; then false; fi`.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4511_process_substitution.yaml`*
*Last verified: 2026-10-20*
