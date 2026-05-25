# arc

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/arc.sh`

## What It Does

lib/arc.sh — Arc system (T-1653 Phase 1 / T-1661 / T-1848)
Arcs are first-class workspaces grouping tasks by theme. Two identities:
• slug  — human-readable filename stem (e.g., `orchestrator-rethink`).
Used in URLs, tags (arc:<slug>), and discussion. Stable but
not immutable — a slug may be renamed (rare; never auto).
• arc-NNN — immutable sequential numeric ID (e.g., `arc-001`) written
into the YAML's `id:` field at creation time. Never renumbered,
never reused, never deleted (status flips, file stays).
D-Immutability axiom (T-1846 inception §11.3, captured here so future
changes find it):

### Framework Reference

Enforced structurally. `fw arc create` requires `--headline-mechanic "<who> <does what> <observes what user-visible result>"` and rejects substrate-only phrasing. `fw arc close` requires `--demo <path|url|none>` — a wire-level artefact (meta.json, stream-json, screencast, live URL) traceable to the arc, or `none` with a `--justification` logged to `.context/audits/arc-bypass.jsonl`. The gates fire before any closure narrative; substrate-vs-deliverable conflation cannot bypass them.

*(truncated — see CLAUDE.md for full section)*

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [update-task](/docs/generated/agents-task-create-update-task) | calls | Task Update Agent - Status transitions with auto-triggers |

## Used By (21)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_arc_system](/docs/generated/tests-unit-test_arc_system) | called_by | Unit tests for fw arc CLI (T-1661 Phase 1 MVP) — pins create/focus/list/show/tag/close/migrate verbs, anchor handling, and handover injection of ## Current Arc section. |
| [arc_abandon](/docs/generated/tests-unit-arc_abandon) | called_by | TODO: describe what this component does |
| [arc_abandon](/docs/generated/tests-unit-arc_abandon) | tests_by | TODO: describe what this component does |
| [arc_create_no_constituent_tasks](/docs/generated/tests-unit-arc_create_no_constituent_tasks) | called_by | TODO: describe what this component does |
| [arc_create_no_constituent_tasks](/docs/generated/tests-unit-arc_create_no_constituent_tasks) | tests_by | TODO: describe what this component does |
| [arc_dual_identity_verbs](/docs/generated/tests-unit-arc_dual_identity_verbs) | called_by | TODO: describe what this component does |
| [arc_dual_identity_verbs](/docs/generated/tests-unit-arc_dual_identity_verbs) | tests_by | TODO: describe what this component does |
| [arc_lifecycle_state_machine](/docs/generated/tests-unit-arc_lifecycle_state_machine) | called_by | TODO: describe what this component does |
| [arc_lifecycle_state_machine](/docs/generated/tests-unit-arc_lifecycle_state_machine) | tests_by | TODO: describe what this component does |
| [arc_membership_union](/docs/generated/tests-unit-arc_membership_union) | tests_by | TODO: describe what this component does |
| [arc_next_numeric_id_octal](/docs/generated/tests-unit-arc_next_numeric_id_octal) | tests_by | TODO: describe what this component does |
| [audit_ctl_arc_tag_only_pattern](/docs/generated/tests-unit-audit_ctl_arc_tag_only_pattern) | called_by | TODO: describe what this component does |
| [audit_ctl_arc_tag_only_pattern](/docs/generated/tests-unit-audit_ctl_arc_tag_only_pattern) | tests_by | TODO: describe what this component does |
| [test_arc_membership_web_surfaces](/docs/generated/tests-unit-test_arc_membership_web_surfaces) | called_by | TODO: describe what this component does |
| [arcs](/docs/generated/web-blueprints-arcs) | called_by | Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs. |
| [arc_remove_driver_verb](/docs/generated/tests-unit-arc_remove_driver_verb) | called_by | TODO: describe what this component does |
| [arc_remove_driver_verb](/docs/generated/tests-unit-arc_remove_driver_verb) | tests_by | TODO: describe what this component does |
| [arc_review_verb](/docs/generated/tests-unit-arc_review_verb) | called_by | TODO: describe what this component does |
| [arc_review_verb](/docs/generated/tests-unit-arc_review_verb) | tests_by | TODO: describe what this component does |
| [arc_set_scoped_weight](/docs/generated/tests-unit-arc_set_scoped_weight) | called_by | TODO: describe what this component does |
| [arc_set_scoped_weight](/docs/generated/tests-unit-arc_set_scoped_weight) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-arc.yaml`*
*Last verified: 2026-05-01*
