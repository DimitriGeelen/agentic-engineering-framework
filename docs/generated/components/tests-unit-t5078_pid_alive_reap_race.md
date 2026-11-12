# t5078_pid_alive_reap_race

> T-5078 — fw_pid_alive ran `kill -0` (true on a zombie) and then read the process state. When the parent reaped the zombie in between, the read came back empty, and empty is not "Z", so a process that no longer existed read as ALIVE.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t5078_pid_alive_reap_race.bats`

## What It Does

T-5078 — fw_pid_alive ran `kill -0` (true on a zombie) and then read the
process state. When the parent reaped the zombie in between, the read came
back empty, and empty is not "Z", so a process that no longer existed read as
ALIVE. `watchtower stop` then printed "Failed to stop" for a stop that worked.
The race is simulated: a pid that does not exist (so /proc/PID/stat is not
readable and the ps branch runs), a `kill` stub that answers "exists" once and
"gone" after that, and a `ps` stub that prints nothing — exactly the order of
events in the trace.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t5078_pid_alive_reap_race.yaml`*
*Last verified: 2026-11-11*
