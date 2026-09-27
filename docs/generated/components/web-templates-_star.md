# _star

> Pin/unpin toggle for the current page (T-2010, arc-007 S2c). Rendered in the breadcrumb bar (_breadcrumb.html) only when the page is a pinnable nav destination (wt_pinnable set; None on home/detail/off-nav pages → no toggle).

**Type:** fragment | **Subsystem:** watchtower | **Location:** `web/templates/_star.html`

## What It Does

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [_breadcrumb](/docs/generated/web-templates-_breadcrumb) | included_by | Breadcrumb trail (T-2009, arc-007 S2b). Rendered inside #content (full loads via _wrapper.html, htmx loads via render_page prepend) so it stays fresh on every navigation. |

---
*Auto-generated from Component Fabric. Card: `web-templates-_star.yaml`*
*Last verified: 2026-05-23*
