# verification-port

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/verification-port.sh`

## What It Does

lib/verification-port.sh — hard-coded Watchtower port detection (T-2732)
Single definition of the predicate. Sourced by:
- agents/task-create/update-task.sh  (the P-011 close gate)
- tests/unit/verification_port_hardcode.bats
It lives here rather than inline in the gate because the regression suite has
to run the REAL predicate over the real corpus. A test that re-types the
producer's expression into a local helper can only ever check the sites its
author already knew about (L-533, from the T-2729/T-2730/T-2731 escape family).
Usage: source "$FRAMEWORK_ROOT/lib/verification-port.sh"
find_port_literals "$text"   # prints offending lines, one per line

---
*Auto-generated from Component Fabric. Card: `lib-verification-port.yaml`*
*Last verified: 2026-08-02*
