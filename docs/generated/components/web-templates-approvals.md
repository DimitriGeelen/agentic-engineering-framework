# approvals

> Full page template: approvals queue — wrapper around _approvals_content partial with nav, filters, bulk actions.

**Type:** template | **Subsystem:** watchtower | **Location:** `web/templates/approvals.html`

## What It Does

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `web/templates/_approvals_content.html` | includes |

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `web/blueprints/approvals.py` | rendered_by |

## Related

### Tasks
- T-641: Tier 0 rejection feedback — write rejection reason to resolved YAML, agent reads on retry
- T-643: Htmx-ify GO decision form — inline response on /approvals page
- T-668: Add /review/T-XXX mobile link to approvals page Human AC cards
- T-669: Approvals page auto-refresh — htmx polling for live Tier 0 and Human AC updates

---
*Auto-generated from Component Fabric. Card: `web-templates-approvals.yaml`*
*Last verified: 2026-03-27*
