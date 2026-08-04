# test_all_routes_size

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/playwright/test_all_routes_size.py`

## What It Does

2 MB. Chosen against measurement, not taste: after T-2775 the worst /timeline page is
513,706 bytes and the heaviest ordinary route is a few hundred KB, so 2 MB leaves ~4x
headroom for honest growth while catching anything in the runaway class (the pre-fix page
was 34x this). A cap that only just fits today's corpus would fail on corpus growth and
teach everyone to raise it, which is how a guard stops meaning anything.

---
*Auto-generated from Component Fabric. Card: `tests-playwright-test_all_routes_size.yaml`*
*Last verified: 2026-08-03*
