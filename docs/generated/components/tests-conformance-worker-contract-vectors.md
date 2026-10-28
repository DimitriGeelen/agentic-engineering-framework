# vectors

> Shared dispatched-worker contract: conformance vectors.

**Type:** config | **Subsystem:** tests | **Location:** `tests/conformance/worker-contract/vectors.yaml`

## What It Does

Shared dispatched-worker contract: conformance vectors.
Data only. One entry per conformance case of §9 of the shared worker contract
("Shared dispatched-worker contract — transition table and conformance spec",
DRAFT v0.3.4 pending adoption, contract_version wc/0.3). Every backend that claims conformance (hub,
local, any external backend per §6.6) runs these vectors through its own adapter.
Ownership and how to contribute: README.md beside this file.
Reading a vector
given   records and worker-dir evidence that exist before the first step. A
backend's adapter seeds them into its own store; symbols (n1, c1, E1)
are placeholders the adapter maps to real values.

---
*Auto-generated from Component Fabric. Card: `tests-conformance-worker-contract-vectors.yaml`*
*Last verified: 2026-10-21*
