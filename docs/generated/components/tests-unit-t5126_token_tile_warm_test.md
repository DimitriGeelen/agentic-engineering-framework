# t5126_token_tile_warm_test

> T-5126 (1409 msg c905c099): `/` never waits for a cold parse of every session transcript. The first call starts the parse in the background and returns None (the cockpit template omits the tile); once the parse is done, the tile is back.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t5126_token_tile_warm_test.py`

## What It Does

---
*Auto-generated from Component Fabric. Card: `tests-unit-t5126_token_tile_warm_test.yaml`*
*Last verified: 2026-11-14*
