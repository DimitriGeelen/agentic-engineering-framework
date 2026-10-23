# t4512_option_check_dequote

> T-4512 (SECURITY, G-121): the read-only allowlist's option checks read raw or quote-stripped words, so `find . -'exec' touch {} \;` and `curl -'o' F URL` read as SAFE while find ran a command and curl wrote F.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4512_option_check_dequote.bats`

## What It Does

T-4512 (SECURITY, G-121): the read-only allowlist's option checks read raw or
quote-stripped words, so `find . -'exec' touch {} \;` and `curl -'o' F URL` read as
SAFE while find ran a command and curl wrote F. Reported by ring20-dashboard
(msg af2bbc85). Same class as T-4485 (git --output), which fixed git alone.
Fix: every option check reads the words the program gets, from one tokenizer
(agents/context/lib/safe-commands.sh _fw_option_words -> lib/shell_write_scan.py
option_words: dequoted, ANSI-C decoded, brace-expanded), and refuses what the text
cannot resolve. Classification only: no command line here is executed.
`! cmd` at statement position is INERT in bats (L-628), so NOT-SAFE assertions use
`if cmd; then false; fi`.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4512_option_check_dequote.yaml`*
*Last verified: 2026-10-20*
