# t4487_boundary_unresolved_git_output

> T-4487: scan_boundary (the project-boundary hook's write scanner) stayed CLEAN on a git diff-family --output target it cannot resolve from the text — `$o` set earlier in the same command, `${O:---output=/etc/x}`, `$(echo --output=/etc/x)`…

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4487_boundary_unresolved_git_output.bats`

## What It Does

T-4487: scan_boundary (the project-boundary hook's write scanner) stayed CLEAN on a
git diff-family --output target it cannot resolve from the text — `$o` set earlier in
the same command, `${O:---output=/etc/x}`, `$(echo --output=/etc/x)`, a loop
variable. _check_target only refused an unresolved target under `ctx.mentions`, which
boundary mode never sets, so `git diff $o` wrote /etc/x past the boundary.
Fix: boundary mode fails closed when such a word could begin with --output (its
literal prefix is a prefix of `--output`) AND the command names a path outside the
project. `git diff $BASE..HEAD` and friends that name no outside path stay clean
(corpus cost measured in the task: <=68 of 222,119 real agent commands).

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4487_boundary_unresolved_git_output.yaml`*
*Last verified: 2026-10-20*
