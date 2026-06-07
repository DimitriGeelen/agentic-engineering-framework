# timeline

> Blueprint 'timeline' — routes: /timeline

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/timeline.py`

## What It Does

T-2106/T-2109: per-file frontmatter cache keyed on (path, mtime_ns).
The session cache (_session_cache, 30s TTL) flushes the entire list every TTL,
forcing a full re-walk of 1000+ handover files (parse_frontmatter @ ~4ms ea =
4-5s steady-state cost). This cache survives the TTL — unchanged files return
instantly from memory; only added/modified files pay parse cost.
T-2109: migrated from local stat+cache logic to shared.mtime_cached_get.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [timeline](/docs/generated/web-templates-timeline) | renders | Page template: Timeline |

## Used By (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [app](/docs/generated/web-app) | called_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [app](/docs/generated/web-app) | registered_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |
| [test_api_timeline_detail](/docs/generated/tests-playwright-test_api_timeline_detail) | called_by | Playwright tests for timeline task detail API (T-1025). |

## Related

### Tasks
- T-827: Timeline per-session token delta — show session-specific token and turn counts alongside cumulative
- T-829: Input/output token breakdown — enrich handover frontmatter and timeline display
- T-831: Session quality metrics — session-metrics.sh JSONL analyzer + handover integration
- T-852: Timeline per-session quality metrics display
- T-855: Sync vendored .agentic-framework/ with T-849 through T-854 fixes

---
*Auto-generated from Component Fabric. Card: `web-blueprints-timeline.yaml`*
*Last verified: 2026-02-20*
