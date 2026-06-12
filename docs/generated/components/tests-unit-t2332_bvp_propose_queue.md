# t2332_bvp_propose_queue

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t2332_bvp_propose_queue.bats`

## What It Does

T-2332 (T-2330 S2): Flask helpers + template render for the driver
propose-queue. Endpoints that shell out to `bin/fw` (propose / approve)
are integration-tested via live curl against the running Watchtower in
the live smoke section at the bottom of S2 — see task closure notes.
This bats covers pure Python paths that can be exercised in isolation:
_load_proposals state-machine, _append_proposal_state_change, the
template render (GET /bvp via Flask test client with PROJECT_ROOT
pointing at framework root so bin/fw resolves correctly).

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2332_bvp_propose_queue.yaml`*
*Last verified: 2026-06-11*
