# _breadcrumb

> Breadcrumb trail (T-2009, arc-007 S2b). Rendered inside #content (full loads via _wrapper.html, htmx loads via render_page prepend) so it stays fresh on every navigation.

**Type:** fragment | **Subsystem:** watchtower | **Location:** `web/templates/_breadcrumb.html`

## What It Does

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [_star](/docs/generated/web-templates-_star) | includes | Pin/unpin toggle for the current page (T-2010, arc-007 S2c). Rendered in the breadcrumb bar (_breadcrumb.html) only when the page is a pinnable nav destination (wt_pinnable set; None on home/detail/off-nav pages → no toggle). |

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [_wrapper](/docs/generated/web-templates-_wrapper) | included_by | Base layout wrapper: nav, header, footer, htmx/CSS includes |

---
*Auto-generated from Component Fabric. Card: `web-templates-_breadcrumb.yaml`*
*Last verified: 2026-05-23*
