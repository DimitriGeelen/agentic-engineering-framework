# docs

> Watchtower docs blueprint: file viewer for docs/reports/ and docs/articles/ — renders markdown with syntax highlighting.

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/docs.py`

## What It Does

Safe directories for file viewer (relative to PROJECT_ROOT)

## Dependencies (4)

| Target | Relationship |
|--------|-------------|
| `web/shared.py` | imports |
| `web/shared.py` | calls |
| `web/templates/docs_index.html` | renders |
| `web/templates/docs_detail.html` | renders |

## Used By (2)

| Component | Relationship |
|-----------|-------------|
| `web/blueprints/__init__.py` | called_by |
| `web/blueprints/__init__.py` | registered_by |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-docs.yaml`*
*Last verified: 2026-03-09*
