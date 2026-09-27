# scanner

> Watchtower scan engine — reads project state (AUTHORITY tier) and writes structured YAML scan output

**Type:** script | **Subsystem:** watchtower | **Location:** `web/watchtower/scanner.py`

## What It Does

web/watchtower/scanner.py

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [shared](/docs/generated/web-shared) | uses | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_scan](/docs/generated/web-watchtower-test_scan) | called_by | Test suite for the Watchtower scan engine (scanner/rules/prioritizer/feedback), colocated in web/watchtower/ |
| [test_scan](/docs/generated/web-watchtower-test_scan) | uses_by | Test suite for the Watchtower scan engine (scanner/rules/prioritizer/feedback), colocated in web/watchtower/ |

---
*Auto-generated from Component Fabric. Card: `web-watchtower-scanner.yaml`*
*Last verified: 2026-09-08*
