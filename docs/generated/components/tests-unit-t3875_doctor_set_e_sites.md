# t3875_doctor_set_e_sites

> T-3875: two `set -euo pipefail` abort sites in do_doctor that T-3837 missed (reported by ring20-dashboard, 2026-10-05).

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3875_doctor_set_e_sites.bats`

## What It Does

T-3875: two `set -euo pipefail` abort sites in do_doctor that T-3837 missed
(reported by ring20-dashboard, 2026-10-05). The constructs are extracted from
bin/fw itself and run under the shell options doctor runs with, so the test
follows the real code rather than a copy of it.
(a) _at_out=$(python3 lib/audit_timing.py …) — a non-zero exit ended doctor
(b) slowest-phases `sort | head -3 | while` — head closed the pipe early,
sort took SIGPIPE (141) and pipefail+errexit ended doctor pre-summary.
(b) is a race in the field (it needs sort to still be writing when head
quits); a 30000-line phase log makes it deterministic.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3875_doctor_set_e_sites.yaml`*
*Last verified: 2026-10-05*
