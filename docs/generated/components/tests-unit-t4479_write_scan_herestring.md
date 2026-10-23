# t4479_write_scan_herestring

> T-4479 — termlink proposal 349 (their T-3178/T-3370), re-derived at HEAD.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4479_write_scan_herestring.bats`

## What It Does

T-4479 — termlink proposal 349 (their T-3178/T-3370), re-derived at HEAD.
1. SIGPIPE fail-open. check-active-task.sh runs with pipefail. The write
scan used `echo "$cmd" | grep -qE`: on a multi-line command larger than
the 64KB pipe buffer, grep -q matches line 1 and exits, echo takes
SIGPIPE, the pipeline returns 141, and the scan reported "no write".
Measured at HEAD: `rm x` + 5000 lines classified as a read 5/5. Fix:
herestrings. (The python -c check in is_bash_safe_command has the same
shape and was converted too, but is not tested here: the chain splitter
is quadratic, so a >64KB command does not reach it in useful time.)
2. `sed -n p notes-in-x.md` read as an in-place sed (`\bsed\b.*-i`). Fix:

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4479_write_scan_herestring.yaml`*
*Last verified: 2026-10-20*
