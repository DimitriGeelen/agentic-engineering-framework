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

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | imports | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [docs_index](/docs/generated/web-templates-docs_index) | renders | Full page template: document index — lists docs/reports/ and docs/articles/ files with last-modified dates. |
| [docs_detail](/docs/generated/web-templates-docs_detail) | renders | Full page template: document detail — renders markdown file content with breadcrumbs and navigation. |

## Used By (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [__init__](/docs/generated/web-blueprints-__init__) | called_by | Flask blueprint:   Init |
| [__init__](/docs/generated/web-blueprints-__init__) | registered_by | Flask blueprint:   Init |
| [test_docs_detail](/docs/generated/tests-playwright-test_docs_detail) | called_by | Playwright tests for /docs/generated/<card_name> detail page (T-1026). |
| [shared](/docs/generated/web-shared) | called_by | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |

---
*Auto-generated from Component Fabric. Card: `web-blueprints-docs.yaml`*
*Last verified: 2026-03-09*
