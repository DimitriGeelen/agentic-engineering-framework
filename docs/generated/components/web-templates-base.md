# base

> Template: {{ page_title | default("Watchtower") }} — Agentic Engineering Framework

**Type:** template | **Subsystem:** watchtower | **Location:** `web/templates/base.html`

## What It Does

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [_pins](/docs/generated/web-templates-_pins) | includes | TODO: describe what this component does |

## Used By (10)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [_wrapper](/docs/generated/web-templates-_wrapper) | extended_by | Base layout wrapper: nav, header, footer, htmx/CSS includes |
| [config](/docs/generated/web-templates-config) | used-by | Watchtower /config page — show all FW_* settings with current values and sources |
| [config](/docs/generated/web-templates-config) | rendered_by | Watchtower /config page — show all FW_* settings with current values and sources |
| [reviewer_audit](/docs/generated/web-templates-reviewer_audit) | extended_by | TODO: describe what this component does |
| [reviewer_overrides](/docs/generated/web-templates-reviewer_overrides) | extended_by | TODO: describe what this component does |
| [escalation_drift](/docs/generated/web-templates-escalation_drift) | extended_by | TODO: describe what this component does |
| [arc_detail](/docs/generated/web-templates-arc_detail) | extended_by | Renders /arcs/<id> detail page — arc metadata, completion stats with G-062 audit-detective threshold call-out (matches T-1656), constituent task table with status badges, section Arc Completion Discipline three-question check inline (in-progress only), fw arc close CLI snippet. |
| [arcs_index](/docs/generated/web-templates-arcs_index) | extended_by | Renders /arcs index — list of every arc with focus dot indicator, status badge (in-progress/closed), constituent count, anchor task link, link to arc detail. |
| [orchestrator](/docs/generated/web-templates-orchestrator) | extended_by | TODO: describe what this component does |
| [bvp](/docs/generated/web-templates-bvp) | extended_by | TODO: describe what this component does |

## Related

### Tasks
- T-854: Pass project name to Watchtower templates — resolve from project root, display in header
- T-855: Sync vendored .agentic-framework/ with T-849 through T-854 fixes

---
*Auto-generated from Component Fabric. Card: `web-templates-base.yaml`*
*Last verified: 2026-02-20*
