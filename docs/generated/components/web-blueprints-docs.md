# docs

> Watchtower docs blueprint: file viewer for docs/reports/ and docs/articles/ — renders markdown with syntax highlighting.

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/docs.py`

## What It Does

T-1764: _VIEWABLE_DIRS and the .md-only restriction were the cause of
linker/route drift. Replaced by `is_viewable_path` (web/shared.py) which
both the linker and this route consult. Kept here as a deprecated alias
for any out-of-tree imports — but contains the FULL list now, not the old
4-prefix subset.

## Dependencies (4)

| Target | Relationship |
|--------|-------------|
| `web/shared.py` | imports |
| `web/shared.py` | calls |
| `web/templates/docs_index.html` | renders |
| `web/templates/docs_detail.html` | renders |

## Used By (5)

| Component | Relationship |
|-----------|-------------|
| `web/blueprints/__init__.py` | called_by |
| `web/blueprints/__init__.py` | registered_by |
| `tests/playwright/test_docs_detail.py` | called_by |
| `web/shared.py` | called_by |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-docs.yaml`*
*Last verified: 2026-03-09*
