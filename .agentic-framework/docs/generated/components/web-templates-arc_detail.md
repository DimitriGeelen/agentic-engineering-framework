# arc_detail

> Renders /arcs/<id> detail page — arc metadata, completion stats with G-062 audit-detective threshold call-out (matches T-1656), constituent task table with status badges, section Arc Completion Discipline three-question check inline (in-progress only), fw arc close CLI snippet.

**Type:** template | **Subsystem:** watchtower | **Location:** `web/templates/arc_detail.html`

**Tags:** `arcs`, `watchtower`, `t-1662`

## What It Does

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [base](/docs/generated/web-templates-base) | extends | Template: {{ page_title \| default("Watchtower") }} — Agentic Engineering Framework |

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [arcs](/docs/generated/web-blueprints-arcs) | rendered_by | Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs. |

---
*Auto-generated from Component Fabric. Card: `web-templates-arc_detail.yaml`*
*Last verified: 2026-05-01*
