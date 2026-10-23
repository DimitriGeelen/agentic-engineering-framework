# t4425_lint_sigpipe

> T-4425: `fw test lint` printed each failing file's findings with `echo "$_sc_output" | head -5 | sed ...` under `set -euo pipefail`.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4425_lint_sigpipe.bats`

## What It Does

T-4425: `fw test lint` printed each failing file's findings with
`echo "$_sc_output" | head -5 | sed ...` under `set -euo pipefail`. Once the
findings outgrew what head read, echo took SIGPIPE, the pipeline returned 141
and errexit killed fw before the Lint summary, the Silent-Skip lint and the
Test-Isolation lint ran. The sibling `echo | grep -q "error"` had the same
shape and could misclassify an error file as WARN.
A fake shellcheck on PATH emits 5000 lines (~190 KB, far over the 64 KB pipe
buffer) so the old pipe SIGPIPEs deterministically on the first file.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4425_lint_sigpipe.yaml`*
*Last verified: 2026-10-19*
