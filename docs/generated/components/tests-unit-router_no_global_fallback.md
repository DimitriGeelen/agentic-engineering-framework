# router_no_global_fallback

> Pins bin/fw-router's three post-T-2854 properties together (a fix that regressed any one would still pass a narrower test): refuses with no project found and no global consulted, still routes a vendored consumer project correctly, and still finds the project root walking up from a nested subdirectory. Also covers a residue global on the host not being routed to, and the framework repo itself still routing to its own bin/fw.


**Type:** script | **Subsystem:** framework-core | **Location:** `tests/unit/router_no_global_fallback.bats`

**Tags:** `router`, `D-377`, `T-2854`

## What It Does

T-2854 (D-377) — bin/fw-router carries NO global-install fallback.
Before this task, a pre-T-2800 residue global (~/.agentic-framework or, on
this host, a stray /.agentic-framework) stayed alive AND authoritative: the
router's own refusal message already asserted "there is no global install to
fall back on by design", and it was only ever printed when no global
happened to exist. Where one did, code twenty lines above ran it — the
contradiction that surfaced as T-2853 (fw update misrouting).
This file pins the three properties the AC calls out by name so a future
reintroduction of a global fallback fails a test with this task's number in
it, not silently:

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw-router](/docs/generated/bin-fw-router) | calls | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tests-unit-router_no_global_fallback.yaml`*
*Last verified: 2026-08-07*
