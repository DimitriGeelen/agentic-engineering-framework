# t1719_ask_routing

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t1719_ask_routing.bats`

## What It Does

T-1719 A3 — `fw ask` routes through the Resolver, with a cloud fallback.
THE PROPERTY THAT MATTERS MOST HERE IS THE ONE THAT SAYS "NO".
The fallback trigger is connection-error-only. A model error, a mid-generation
timeout, or a malformed response all mean Ollama IS running and something else
is wrong — falling through to a paid cloud model on those would convert a
visible local fault into an invisible recurring bill, and nothing in the
system would ever surface it. `_is_connection_error` returning FALSE for a
model error is therefore load-bearing, and is tested in both directions.
The telemetry is deliberately best-effort: if the Resolver is missing or the
capture fails, ask still answers. So these tests assert that ask SURVIVES

---
*Auto-generated from Component Fabric. Card: `tests-unit-t1719_ask_routing.yaml`*
*Last verified: 2026-08-16*
