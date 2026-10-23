# t2998_ctl008_merge_exempt

> T-2998 — CTL-008 must not count git-generated merge subjects as task-less.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t2998_ctl008_merge_exempt.bats`

## What It Does

T-2998 — CTL-008 must not count git-generated merge subjects as task-less.
The commit-msg hook admits any commit made with MERGE_HEAD set
(agents/git/lib/hooks.sh), so `git merge --no-ff <branch>` lands with git's
default subject `Merge branch '<branch>'`. CTL-008 counted that subject as a
traceability offender (consumer 001-CashWeb, G-008: 2/20 → 90%).
Both directions: a merge is exempt, and a real task-less commit still counts —
the negative control keeps a "fix" that disables the check from passing.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2998_ctl008_merge_exempt.yaml`*
*Last verified: 2026-10-20*
