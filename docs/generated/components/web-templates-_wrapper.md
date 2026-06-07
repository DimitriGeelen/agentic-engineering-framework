# _wrapper

> Base layout wrapper: nav, header, footer, htmx/CSS includes

**Type:** fragment | **Subsystem:** watchtower | **Location:** `web/templates/_wrapper.html`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [base](/docs/generated/web-templates-base) | extends | Template: {{ page_title \| default("Watchtower") }} — Agentic Engineering Framework |
| [_breadcrumb](/docs/generated/web-templates-_breadcrumb) | includes | TODO: describe what this component does |

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [docs_detail](/docs/generated/web-templates-docs_detail) | wrapped_by_by | Full page template: document detail — renders markdown file content with breadcrumbs and navigation. |
| [docs_index](/docs/generated/web-templates-docs_index) | wrapped_by_by | Full page template: document index — lists docs/reports/ and docs/articles/ files with last-modified dates. |
| [feedback_analytics](/docs/generated/web-templates-feedback_analytics) | wrapped_by_by | Jinja2 template for feedback analytics page. Displays handover quality feedback trends and session statistics. |
| [settings](/docs/generated/web-templates-settings) | wrapped_by_by | Full page template: settings — hook configuration, notification state, framework paths. |

---
*Auto-generated from Component Fabric. Card: `web-templates-_wrapper.yaml`*
*Last verified: 2026-02-20*
