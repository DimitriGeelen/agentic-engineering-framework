# t2452_doctor_quick

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t2452_doctor_quick.bats`

## What It Does

T-2452 / F6 (T-2441 dogfood) — `fw doctor --quick` project-only fast mode.
`fw doctor` runs the full host+project+network check set every invocation
(~150s — measured live during T-2452). The onboarding fix-and-rerun loop
compounds it (3 calls timed out a 120s budget). `--quick` skips the slow
host/network probes (mirror divergence ls-remote, litellm/ollama/watchtower
curls) for a project-only scan. Live A/B during T-2452: quick=44s vs full=150s
(3.4×), full mode unchanged (zero SKIP-leak).
Most pins are source-level (cheap, deterministic) per the F7/T-2451 lesson:
`fw doctor` is slow and network-coupled, so running it in unit tests is an
anti-pattern. One behavioural pin exercises `--quick` (the fast path).

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2452_doctor_quick.yaml`*
*Last verified: 2026-06-21*
