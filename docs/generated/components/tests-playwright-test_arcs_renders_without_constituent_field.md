# test_arcs_renders_without_constituent_field

> Playwright DOM-content assertion (per T-1575/T-971) pinning the
/arcs/<slug> render contract for arcs that omit the legacy
`constituent_tasks:` frontmatter field. Fixture writes a synthetic arc
YAML to .context/arcs/, yields, removes on teardown — Watchtower
reads filesystem live, no restart needed.

Two tests:
- test_arcs_detail_renders_without_constituent_tasks: synthetic
  field-less arc → 200 + no "Traceback" + no "Internal Server Error"
  + arc name renders.
- test_legacy_arc_with_constituent_tasks_still_renders: regression
  guard pinning legacy /arcs/arc-grooming still renders.

Re-classifies T-1851's first Human [REVIEW] AC to Agent. The
deprecation-banner reading-quality AC remains Human [REVIEW] —
doc tone is genuinely subjective.


**Type:** script | **Subsystem:** testing | **Location:** `tests/playwright/test_arcs_renders_without_constituent_field.py`

**Tags:** `test`, `playwright`, `dom-content`, `arc`, `render-surface`, `fixture`, `T-1851`, `T-1575`, `T-971`

## What It Does

NOTE: deliberately no `constituent_tasks:` field — that's the contract.

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [arcs](/docs/generated/web-blueprints-arcs) | renders | Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs. |
| [conftest](/docs/generated/tests-playwright-conftest) | calls | Playwright test fixtures for Watchtower (T-969) |
| [arcs](/docs/generated/web-blueprints-arcs) | calls | Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs. |

---
*Auto-generated from Component Fabric. Card: `tests-playwright-test_arcs_renders_without_constituent_field.yaml`*
*Last verified: 2026-05-17*
