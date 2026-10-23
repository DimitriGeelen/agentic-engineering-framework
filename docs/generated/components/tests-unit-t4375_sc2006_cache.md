# t4375_sc2006_cache

> T-4375: the structure-section audit (the pre-push gate) spent ~280 s of its ~510 s in check_invariant_suite (`bats tests/lint/`), and ~250 s of that in two lint legs that ran real ShellCheck over the whole repo…

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4375_sc2006_cache.bats`

## What It Does

T-4375: the structure-section audit (the pre-push gate) spent ~280 s of its
~510 s in check_invariant_suite (`bats tests/lint/`), and ~250 s of that in two
lint legs that ran real ShellCheck over the whole repo:
- no-backticks-in-quoted-strings.bats, SC2006 over every bash source (~69 s),
now through tools/shellcheck-sc2006-cached.py, keyed on (version, path, bytes);
- bats-silent-skip.bats "fw test lint actually reports a silent-skip section"
(~180 s), which asserts wiring and now stubs shellcheck.
These tests pin the cache's contract: same findings, no rerun on a hit, a rerun
on any change, and nothing remembered from a shellcheck run that failed.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4375_sc2006_cache.yaml`*
*Last verified: 2026-10-19*
