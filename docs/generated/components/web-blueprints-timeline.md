# timeline

> Blueprint 'timeline' — routes: /timeline

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/timeline.py`

## What It Does

Next item in list is the predecessor (older session)

## Dependencies (2)

| Target | Relationship |
|--------|-------------|
| `web/shared.py` | calls |
| `web/templates/timeline.html` | renders |

## Used By (5)

| Component | Relationship |
|-----------|-------------|
| `web/app.py` | called_by |
| `web/app.py` | registered_by |
| `web/blueprints/__init__.py` | called_by |
| `web/blueprints/__init__.py` | registered_by |

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
