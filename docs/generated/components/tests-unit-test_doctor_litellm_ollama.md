# test_doctor_litellm_ollama

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_doctor_litellm_ollama.bats`

## What It Does

T-1700 — fw doctor: litellm-proxy + ollama reachability checks.
Pins the skip-if-no-consumer pattern (mirror of T-1694 pi check):
1. The check ONLY fires when a workflow file declares the marker.
2. When a workflow declares ANTHROPIC_BASE_URL: http://localhost:4000,
doctor probes :4000/health.
3. When a workflow declares worker_kind: ollama-loop, doctor probes
192.168.10.107:11434/api/tags.
4. Both checks are host-scope (use _doctor_warn_host on failure).

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `bin/fw` | tests |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_doctor_litellm_ollama.yaml`*
*Last verified: 2026-05-04*
