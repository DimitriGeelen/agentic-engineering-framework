# t3837_doctor_errexit_captures

> T-3837: bin/fw runs under `set -euo pipefail` (line 12). In that mode

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3837_doctor_errexit_captures.bats`

## What It Does

T-3837: bin/fw runs under `set -euo pipefail` (line 12). In that mode
x=$(cmd); rc=$?
never reaches `rc=$?` when cmd fails — the failed assignment IS the errexit,
and `fw doctor` dies mid-check with no summary. Four doctor checks were written
that way (BVP scorability, DM rail, consult inbox, sidecar watcher), each of
them designed to branch on a non-zero rc, plus a bare TermLink topic-list
capture that died whenever the local hub was down. Reported by a peer project
after upgrading to v1.8.0. Fix shape: `x=$(cmd) && rc=0 || rc=$?`.
Test 1 is behavioural: a termlink whose every subcommand fails (hub down) must
not stop doctor before its summary. Test 2 is the static guard for the class.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3837_doctor_errexit_captures.yaml`*
*Last verified: 2026-10-04*
