# t3257-livefire-driver

> T-3257 — live-fire: does the continuous-driver actually hand a turn to a REAL agent?

**Type:** script | **Subsystem:** framework-core | **Location:** `tools/t3257-livefire-driver.sh`

## What It Does

T-3257 — live-fire: does the continuous-driver actually hand a turn to a REAL agent?
WHAT THIS PROVES THAT NOTHING ELSE DOES.
tests/unit/t3275_delivery_confirmation.bats  — stubs the transport. Proves the
driver's VERDICT tracks delivery. Cannot prove delivery itself.
tools/t3250-transport-probe.sh               — real binaries, but probes the
WIRE directly. Never runs the driver.
This runs the actual `continuous-driver.sh` end to end — bounds -> target
resolution -> transport -> delivery confirmation -> ledger — against a real
`claude` TUI, and then asks the harder question the other two never ask:
did the agent PROCESS the turn, or did the text merely land in an input box?

---
*Auto-generated from Component Fabric. Card: `tools-t3257-livefire-driver.yaml`*
*Last verified: 2026-09-05*
