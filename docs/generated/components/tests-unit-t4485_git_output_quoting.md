# t4485_git_output_quoting

> T-4485 (SECURITY): T-4367's git --output check matched RAW words, so every shell spelling that produces the word `--output=FILE` only after bash has processed it — quotes, a backslash, a variable, a parameter default, a loop variable —…

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4485_git_output_quoting.bats`

## What It Does

T-4485 (SECURITY): T-4367's git --output check matched RAW words, so every shell
spelling that produces the word `--output=FILE` only after bash has processed it —
quotes, a backslash, a variable, a parameter default, a loop variable — read as SAFE
while git wrote FILE. Reported by ring20-dashboard (msg 9fc80de4, probe
tmp/t4367_probe.sh) on v1.8.13.
Fix: the diff-family verbs are judged on the words bash will hand git
(lib/shell_write_scan.py git_output_risk: dequoted, brace-expanded), and any
expansion bash performs before git sees the word ($, a backtick, an unquoted glob)
fails closed. The write scanner reads the same shapes as an unresolved target.
`! cmd` at statement position is INERT in bats (L-628), so NOT-SAFE assertions use

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4485_git_output_quoting.yaml`*
*Last verified: 2026-10-20*
