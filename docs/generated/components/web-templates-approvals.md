# approvals

> Full page template: approvals queue — wrapper around _approvals_content partial with nav, filters, bulk actions.

**Type:** template | **Subsystem:** watchtower | **Location:** `web/templates/approvals.html`

## What It Does

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [_approvals_content](/docs/generated/web-templates-_approvals_content) | includes | htmx partial: approvals content fragment — task list with AC checkboxes, loaded by htmx swap into approvals page. |

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [approvals](/docs/generated/web-blueprints-approvals) | rendered_by | Watchtower approvals blueprint: human review queue — lists tasks with unchecked Human ACs, supports checkbox toggling. |

---
*Auto-generated from Component Fabric. Card: `web-templates-approvals.yaml`*
*Last verified: 2026-03-27*
