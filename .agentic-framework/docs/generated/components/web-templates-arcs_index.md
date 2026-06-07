# arcs_index

> Renders /arcs index — list of every arc with focus dot indicator, status badge (in-progress/closed), constituent count, anchor task link, link to arc detail.

**Type:** template | **Subsystem:** watchtower | **Location:** `web/templates/arcs_index.html`

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
*Auto-generated from Component Fabric. Card: `web-templates-arcs_index.yaml`*
*Last verified: 2026-05-01*
