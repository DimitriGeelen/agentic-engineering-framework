# test_scan

> Test suite for the Watchtower scan engine (scanner/rules/prioritizer/feedback), colocated in web/watchtower/

**Type:** script | **Subsystem:** tests | **Location:** `web/watchtower/test_scan.py`

## What It Does

web/watchtower/test_scan.py

## Dependencies (8)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [scanner](/docs/generated/web-watchtower-scanner) | calls | Watchtower scan engine — reads project state (AUTHORITY tier) and writes structured YAML scan output |
| [rules](/docs/generated/web-watchtower-rules) | calls | Watchtower detection rules — challenge, opportunity and strength rule functions over scanner inputs |
| [prioritizer](/docs/generated/web-watchtower-prioritizer) | calls | Work-queue prioritization for the Watchtower scan engine — orders active tasks by issues > stale > active > captured |
| [feedback](/docs/generated/web-watchtower-feedback) | calls | Feedback and antifragility metrics computation for the Watchtower scan engine |
| [scanner](/docs/generated/web-watchtower-scanner) | uses | Watchtower scan engine — reads project state (AUTHORITY tier) and writes structured YAML scan output |
| [rules](/docs/generated/web-watchtower-rules) | uses | Watchtower detection rules — challenge, opportunity and strength rule functions over scanner inputs |
| [prioritizer](/docs/generated/web-watchtower-prioritizer) | uses | Work-queue prioritization for the Watchtower scan engine — orders active tasks by issues > stale > active > captured |
| [feedback](/docs/generated/web-watchtower-feedback) | uses | Feedback and antifragility metrics computation for the Watchtower scan engine |

---
*Auto-generated from Component Fabric. Card: `web-watchtower-test_scan.yaml`*
*Last verified: 2026-09-08*
