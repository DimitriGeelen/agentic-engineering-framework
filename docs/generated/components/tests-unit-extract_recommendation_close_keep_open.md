# extract_recommendation_close_keep_open

> T-1960: extend extract_recommendation parser to accept CLOSE / KEEP-OPEN verdicts (in addition to GO / NO-GO / DEFER). Pinned so the arc-close recommendation surface doesn't silently fall back to verdict='?'.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/extract_recommendation_close_keep_open.bats`

## What It Does

T-1960: extend extract_recommendation parser to accept CLOSE / KEEP-OPEN
verdicts (in addition to GO / NO-GO / DEFER). Pinned so the arc-close
recommendation surface doesn't silently fall back to verdict='?'.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | tests | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |

---
*Auto-generated from Component Fabric. Card: `tests-unit-extract_recommendation_close_keep_open.yaml`*
*Last verified: 2026-07-22*
