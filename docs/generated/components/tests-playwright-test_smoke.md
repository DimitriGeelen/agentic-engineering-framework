# test_smoke

> Playwright smoke tests — all major routes render (T-969)

**Type:** script | **Subsystem:** testing | **Location:** `tests/playwright/test_smoke.py`

## What It Does

Populated from conftest.py base_url fixture

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [target](/docs/generated/tests-playwright-target) | uses | The one place the Playwright suite decides what it is talking to (T-2784). |
| [smoke_test](/docs/generated/web-smoke_test) | calls | Watchtower smoke test — runtime route discovery + content validation. |

## Related

### Tasks
- T-969: Playwright test infrastructure — tests/playwright/ + fw test playwright + conftest.py (T-968 Phase 1)

---
*Auto-generated from Component Fabric. Card: `tests-playwright-test_smoke.yaml`*
*Last verified: 2026-04-06*
