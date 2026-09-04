# metrics_history

> TODO: describe what this component does

**Type:** script | **Subsystem:** watchtower | **Location:** `web/metrics_history.py`

## What It Does

T-1235: Cache parsed metrics history (19K lines, called 3x per /discoveries)

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [shared](/docs/generated/web-shared) | uses | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [discoveries](/docs/generated/web-blueprints-discoveries) | called_by | Flask blueprint serving /discoveries route. Displays audit discovery findings with WARN/FAIL status from cron and manual audits. |

---
*Auto-generated from Component Fabric. Card: `web-metrics_history.yaml`*
*Last verified: 2026-09-03*
