# __init__

> Flask blueprint:   Init  

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/__init__.py`

## What It Does

Flask blueprints for the Agentic Engineering Framework web UI
Centralizes blueprint registration (T-431/A2).
Adding a new blueprint: import it here and append to _BLUEPRINTS.

## Dependencies (107)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [core](/docs/generated/web-blueprints-core) | calls | Flask blueprint: Core |
| [tasks](/docs/generated/web-blueprints-tasks) | calls | Flask blueprint: Tasks |
| [timeline](/docs/generated/web-blueprints-timeline) | calls | Blueprint 'timeline' — routes: /timeline |
| [learnings-route](/docs/generated/learnings-route) | calls | Serve the /learnings page showing all project learnings, patterns, and practices. |
| [quality](/docs/generated/web-blueprints-quality) | calls | Flask blueprint: Quality |
| [session](/docs/generated/web-blueprints-session) | calls | Flask blueprint: Session |
| [metrics](/docs/generated/web-blueprints-metrics) | calls | Flask blueprint: Metrics |
| [cockpit](/docs/generated/web-blueprints-cockpit) | calls | Flask blueprint: Cockpit |
| [inception](/docs/generated/web-blueprints-inception) | calls | Blueprint 'inception' — routes: /inception |
| [enforcement](/docs/generated/web-blueprints-enforcement) | calls | Flask blueprint: Enforcement |
| [risks](/docs/generated/web-blueprints-risks) | calls | Flask blueprint 'risks' serving routes: /risks |
| [fabric](/docs/generated/web-blueprints-fabric) | calls | Flask blueprint: Fabric |
| [discoveries](/docs/generated/web-blueprints-discoveries) | calls | Flask blueprint serving /discoveries route. Displays audit discovery findings with WARN/FAIL status from cron and manual audits. |
| [docs](/docs/generated/web-blueprints-docs) | calls | Watchtower docs blueprint: file viewer for docs/reports/ and docs/articles/ — renders markdown with syntax highlighting. |
| [settings](/docs/generated/web-blueprints-settings) | calls | Watchtower settings blueprint: framework configuration display — shows hooks, cron config, notification state. |
| [cron](/docs/generated/web-blueprints-cron) | calls | Watchtower cron blueprint: cron job status display — shows registered jobs, schedule, last run, active/paused state. |
| [api](/docs/generated/web-blueprints-api) | calls | Watchtower API blueprint: JSON endpoints for AJAX/htmx — task data, metrics, approval actions. |
| [approvals](/docs/generated/web-blueprints-approvals) | calls | Watchtower approvals blueprint: human review queue — lists tasks with unchecked Human ACs, supports checkbox toggling. |
| [review](/docs/generated/web-blueprints-review) | calls | Watchtower review blueprint: task review page — shows ACs, research artifacts, recommendation, approval actions. |
| [core](/docs/generated/web-blueprints-core) | registers | Flask blueprint: Core |
| [tasks](/docs/generated/web-blueprints-tasks) | registers | Flask blueprint: Tasks |
| [timeline](/docs/generated/web-blueprints-timeline) | registers | Blueprint 'timeline' — routes: /timeline |
| [learnings-route](/docs/generated/learnings-route) | registers | Serve the /learnings page showing all project learnings, patterns, and practices. |
| [quality](/docs/generated/web-blueprints-quality) | registers | Flask blueprint: Quality |
| [session](/docs/generated/web-blueprints-session) | registers | Flask blueprint: Session |
| [metrics](/docs/generated/web-blueprints-metrics) | registers | Flask blueprint: Metrics |
| [cockpit](/docs/generated/web-blueprints-cockpit) | registers | Flask blueprint: Cockpit |
| [inception](/docs/generated/web-blueprints-inception) | registers | Blueprint 'inception' — routes: /inception |
| [enforcement](/docs/generated/web-blueprints-enforcement) | registers | Flask blueprint: Enforcement |
| [risks](/docs/generated/web-blueprints-risks) | registers | Flask blueprint 'risks' serving routes: /risks |
| [fabric](/docs/generated/web-blueprints-fabric) | registers | Flask blueprint: Fabric |
| [discoveries](/docs/generated/web-blueprints-discoveries) | registers | Flask blueprint serving /discoveries route. Displays audit discovery findings with WARN/FAIL status from cron and manual audits. |
| [docs](/docs/generated/web-blueprints-docs) | registers | Watchtower docs blueprint: file viewer for docs/reports/ and docs/articles/ — renders markdown with syntax highlighting. |
| [settings](/docs/generated/web-blueprints-settings) | registers | Watchtower settings blueprint: framework configuration display — shows hooks, cron config, notification state. |
| [cron](/docs/generated/web-blueprints-cron) | registers | Watchtower cron blueprint: cron job status display — shows registered jobs, schedule, last run, active/paused state. |
| [api](/docs/generated/web-blueprints-api) | registers | Watchtower API blueprint: JSON endpoints for AJAX/htmx — task data, metrics, approval actions. |
| [approvals](/docs/generated/web-blueprints-approvals) | registers | Watchtower approvals blueprint: human review queue — lists tasks with unchecked Human ACs, supports checkbox toggling. |
| [review](/docs/generated/web-blueprints-review) | registers | Watchtower review blueprint: task review page — shows ACs, research artifacts, recommendation, approval actions. |
| [discovery_blueprint](/docs/generated/web-blueprints-discovery) | calls | Watchtower discovery page — decisions, learnings, gaps, search, graduation |
| [costs](/docs/generated/web-blueprints-costs) | calls | Watchtower /costs page — token usage dashboard with session table and project summary (T-802) |
| [config](/docs/generated/web-blueprints-config) | calls | Flask blueprint that renders the configuration settings page showing all framework settings with current values and resolution sources |
| [terminal](/docs/generated/web-blueprints-terminal) | calls | Flask blueprint providing the interactive web terminal API with session creation, I/O, resize, and profile-based configuration |
| [sessions](/docs/generated/web-blueprints-sessions) | calls | Flask blueprint that renders the terminal session management page listing active and historical sessions |
| [discovery_blueprint](/docs/generated/web-blueprints-discovery) | registers | Watchtower discovery page — decisions, learnings, gaps, search, graduation |
| [costs](/docs/generated/web-blueprints-costs) | registers | Watchtower /costs page — token usage dashboard with session table and project summary (T-802) |
| [config](/docs/generated/web-blueprints-config) | registers | Flask blueprint that renders the configuration settings page showing all framework settings with current values and resolution sources |
| [terminal](/docs/generated/web-blueprints-terminal) | registers | Flask blueprint providing the interactive web terminal API with session creation, I/O, resize, and profile-based configuration |
| [sessions](/docs/generated/web-blueprints-sessions) | registers | Flask blueprint that renders the terminal session management page listing active and historical sessions |
| [prompts](/docs/generated/web-blueprints-prompts) | calls | Prompts blueprint — reusable agent-prompt register UI (T-1283 B3). |
| [prompts](/docs/generated/web-blueprints-prompts) | registers | Prompts blueprint — reusable agent-prompt register UI (T-1283 B3). |
| [pending](/docs/generated/web-blueprints-pending) | calls | Pending-updates registry blueprint — Watchtower UI for T-1268 B3. |
| [pending](/docs/generated/web-blueprints-pending) | registers | Pending-updates registry blueprint — Watchtower UI for T-1268 B3. |
| [fleet](/docs/generated/web-blueprints-fleet) | calls | Fleet blueprint — operational dashboard for termlink fleet health (T-1103, T-1107). |
| [fleet](/docs/generated/web-blueprints-fleet) | registers | Fleet blueprint — operational dashboard for termlink fleet health (T-1103, T-1107). |
| [reviewer](/docs/generated/web-blueprints-reviewer) | calls | Reviewer blueprint — machine-reviewer system state (T-1443 v1.5a). |
| [reviewer](/docs/generated/web-blueprints-reviewer) | registers | Reviewer blueprint — machine-reviewer system state (T-1443 v1.5a). |
| [escalation](/docs/generated/web-blueprints-escalation) | calls | Escalation drift blueprint — G-019 Layer C surface (T-1595). |
| [escalation](/docs/generated/web-blueprints-escalation) | registers | Escalation drift blueprint — G-019 Layer C surface (T-1595). |
| [hooks](/docs/generated/web-blueprints-hooks) | calls | T-1632 (B-3c of T-1626) — Watchtower /hooks page. |
| [orchestrator](/docs/generated/web-blueprints-orchestrator) | calls | T-1647 (W10 #2 of T-1641 Arc C) — Watchtower /orchestrator page. |
| [arcs](/docs/generated/web-blueprints-arcs) | calls | Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs. |
| [hooks](/docs/generated/web-blueprints-hooks) | registers | T-1632 (B-3c of T-1626) — Watchtower /hooks page. |
| [orchestrator](/docs/generated/web-blueprints-orchestrator) | registers | T-1647 (W10 #2 of T-1641 Arc C) — Watchtower /orchestrator page. |
| [arcs](/docs/generated/web-blueprints-arcs) | registers | Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs. |
| [bvp](/docs/generated/web-blueprints-bvp) | calls | BVP scatter blueprint — T-1928 (arc-006, value-prioritisation, T-NEW-12a). |
| [bvp](/docs/generated/web-blueprints-bvp) | registers | BVP scatter blueprint — T-1928 (arc-006, value-prioritisation, T-NEW-12a). |
| [designer](/docs/generated/web-blueprints-designer) | calls | Designer blueprint — serves the pinned Workflow Designer build (T-2521). |
| [designer_api](/docs/generated/web-blueprints-designer_api) | calls | Designer gallery-server API (T-2529) — the ``/api/*`` endpoints that 832's shipped 0.2.0 Workflow Designer client already calls. |
| [designer](/docs/generated/web-blueprints-designer) | registers | Designer blueprint — serves the pinned Workflow Designer build (T-2521). |
| [designer_api](/docs/generated/web-blueprints-designer_api) | registers | Designer gallery-server API (T-2529) — the ``/api/*`` endpoints that 832's shipped 0.2.0 Workflow Designer client already calls. |
| [embeddings](/docs/generated/web-blueprints-embeddings) | calls | Embeddings blueprint — the recall substrate's own instrument panel (T-1719 A4). |
| [embeddings](/docs/generated/web-blueprints-embeddings) | registers | Embeddings blueprint — the recall substrate's own instrument panel (T-1719 A4). |
| [core](/docs/generated/web-blueprints-core) | uses | Flask blueprint: Core |
| [tasks](/docs/generated/web-blueprints-tasks) | uses | Flask blueprint: Tasks |
| [timeline](/docs/generated/web-blueprints-timeline) | uses | Blueprint 'timeline' — routes: /timeline |
| [discovery_blueprint](/docs/generated/web-blueprints-discovery) | uses | Watchtower discovery page — decisions, learnings, gaps, search, graduation |
| [quality](/docs/generated/web-blueprints-quality) | uses | Flask blueprint: Quality |
| [session](/docs/generated/web-blueprints-session) | uses | Flask blueprint: Session |
| [metrics](/docs/generated/web-blueprints-metrics) | uses | Flask blueprint: Metrics |
| [cockpit](/docs/generated/web-blueprints-cockpit) | uses | Flask blueprint: Cockpit |
| [inception](/docs/generated/web-blueprints-inception) | uses | Blueprint 'inception' — routes: /inception |
| [enforcement](/docs/generated/web-blueprints-enforcement) | uses | Flask blueprint: Enforcement |
| [risks](/docs/generated/web-blueprints-risks) | uses | Flask blueprint 'risks' serving routes: /risks |
| [fabric](/docs/generated/web-blueprints-fabric) | uses | Flask blueprint: Fabric |
| [discoveries](/docs/generated/web-blueprints-discoveries) | uses | Flask blueprint serving /discoveries route. Displays audit discovery findings with WARN/FAIL status from cron and manual audits. |
| [docs](/docs/generated/web-blueprints-docs) | uses | Watchtower docs blueprint: file viewer for docs/reports/ and docs/articles/ — renders markdown with syntax highlighting. |
| [settings](/docs/generated/web-blueprints-settings) | uses | Watchtower settings blueprint: framework configuration display — shows hooks, cron config, notification state. |
| [cron](/docs/generated/web-blueprints-cron) | uses | Watchtower cron blueprint: cron job status display — shows registered jobs, schedule, last run, active/paused state. |
| [api](/docs/generated/web-blueprints-api) | uses | Watchtower API blueprint: JSON endpoints for AJAX/htmx — task data, metrics, approval actions. |
| [approvals](/docs/generated/web-blueprints-approvals) | uses | Watchtower approvals blueprint: human review queue — lists tasks with unchecked Human ACs, supports checkbox toggling. |
| [review](/docs/generated/web-blueprints-review) | uses | Watchtower review blueprint: task review page — shows ACs, research artifacts, recommendation, approval actions. |
| [costs](/docs/generated/web-blueprints-costs) | uses | Watchtower /costs page — token usage dashboard with session table and project summary (T-802) |
| [config](/docs/generated/web-blueprints-config) | uses | Flask blueprint that renders the configuration settings page showing all framework settings with current values and resolution sources |
| [terminal](/docs/generated/web-blueprints-terminal) | uses | Flask blueprint providing the interactive web terminal API with session creation, I/O, resize, and profile-based configuration |
| [sessions](/docs/generated/web-blueprints-sessions) | uses | Flask blueprint that renders the terminal session management page listing active and historical sessions |
| [prompts](/docs/generated/web-blueprints-prompts) | uses | Prompts blueprint — reusable agent-prompt register UI (T-1283 B3). |
| [pending](/docs/generated/web-blueprints-pending) | uses | Pending-updates registry blueprint — Watchtower UI for T-1268 B3. |
| [fleet](/docs/generated/web-blueprints-fleet) | uses | Fleet blueprint — operational dashboard for termlink fleet health (T-1103, T-1107). |
| [reviewer](/docs/generated/web-blueprints-reviewer) | uses | Reviewer blueprint — machine-reviewer system state (T-1443 v1.5a). |
| [escalation](/docs/generated/web-blueprints-escalation) | uses | Escalation drift blueprint — G-019 Layer C surface (T-1595). |
| [hooks](/docs/generated/web-blueprints-hooks) | uses | T-1632 (B-3c of T-1626) — Watchtower /hooks page. |
| [orchestrator](/docs/generated/web-blueprints-orchestrator) | uses | T-1647 (W10 #2 of T-1641 Arc C) — Watchtower /orchestrator page. |
| [arcs](/docs/generated/web-blueprints-arcs) | uses | Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs. |
| [bvp](/docs/generated/web-blueprints-bvp) | uses | BVP scatter blueprint — T-1928 (arc-006, value-prioritisation, T-NEW-12a). |
| [designer](/docs/generated/web-blueprints-designer) | uses | Designer blueprint — serves the pinned Workflow Designer build (T-2521). |
| [designer_api](/docs/generated/web-blueprints-designer_api) | uses | Designer gallery-server API (T-2529) — the ``/api/*`` endpoints that 832's shipped 0.2.0 Workflow Designer client already calls. |
| [embeddings](/docs/generated/web-blueprints-embeddings) | uses | Embeddings blueprint — the recall substrate's own instrument panel (T-1719 A4). |

## Used By (25)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [app](/docs/generated/web-app) | imported_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port — _Python package init; implicitly loaded when app.py imports from web.blueprints.*_ |
| [app](/docs/generated/web-app) | called_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [test_bvp_blueprint_cost](/docs/generated/tests-unit-test_bvp_blueprint_cost) | called_by | T-1934: pin the `_compute_cost(default_when_absent=...)` contract. |
| [test_bvp_scatter_arc_mode](/docs/generated/tests-unit-test_bvp_scatter_arc_mode) | called_by | T-1941: pin `bvp_mode` field in /bvp scatter arc payload. |
| [test_arc_display_helper](/docs/generated/tests-unit-test_arc_display_helper) | called_by | T-1969: pin the arc_display(arc_id_or_slug) helper. |
| [test_appearance_validation](/docs/generated/tests-unit-test_appearance_validation) | called_by | T-1988 (arc-007 S1): pin the appearance security contract. |
| [test_cockpit_activity](/docs/generated/tests-unit-test_cockpit_activity) | called_by | T-2020 (arc-007 S6d): cockpit live activity feed — recent commits via htmx poll. |
| [test_cockpit_knowledge_counts](/docs/generated/tests-unit-test_cockpit_knowledge_counts) | called_by | T-2022: Cockpit System Health Knowledge counts come from live helpers, not a missing scan key. |
| [test_cockpit_traceability](/docs/generated/tests-unit-test_cockpit_traceability) | called_by | T-2021: Cockpit System Health renders traceability as a percentage, not a raw dict. |
| [test_nav_layout_polish](/docs/generated/tests-unit-test_nav_layout_polish) | called_by | T-2033: arc-007 nav-layout polish — static guards for the sidebar/rail fixes. |
| [test_nav_layouts](/docs/generated/tests-unit-test_nav_layouts) | called_by | T-2011 (arc-007 S2d): nav-layout axis contract. |
| [test_pins](/docs/generated/tests-unit-test_pins) | called_by | T-2010 (arc-007 S2c): pinned-pages model contract. |
| [test_appearance_validation](/docs/generated/tests-unit-test_appearance_validation) | uses_by | T-1988 (arc-007 S1): pin the appearance security contract. |
| [test_arc_display_helper](/docs/generated/tests-unit-test_arc_display_helper) | uses_by | T-1969: pin the arc_display(arc_id_or_slug) helper. |
| [test_arcs_membership_cached](/docs/generated/tests-unit-test_arcs_membership_cached) | called_by | T-2774: /arcs constituent resolution must not re-scan the corpus per arc. |
| [test_arcs_membership_cached](/docs/generated/tests-unit-test_arcs_membership_cached) | uses_by | T-2774: /arcs constituent resolution must not re-scan the corpus per arc. |
| [test_bvp_blueprint_cost](/docs/generated/tests-unit-test_bvp_blueprint_cost) | uses_by | T-1934: pin the `_compute_cost(default_when_absent=...)` contract. |
| [test_bvp_scatter_arc_mode](/docs/generated/tests-unit-test_bvp_scatter_arc_mode) | uses_by | T-1941: pin `bvp_mode` field in /bvp scatter arc payload. |
| [test_cockpit_activity](/docs/generated/tests-unit-test_cockpit_activity) | uses_by | T-2020 (arc-007 S6d): cockpit live activity feed — recent commits via htmx poll. |
| [test_cockpit_knowledge_counts](/docs/generated/tests-unit-test_cockpit_knowledge_counts) | uses_by | T-2022: Cockpit System Health Knowledge counts come from live helpers, not a missing scan key. |
| [test_cockpit_traceability](/docs/generated/tests-unit-test_cockpit_traceability) | uses_by | T-2021: Cockpit System Health renders traceability as a percentage, not a raw dict. |
| [test_nav_layout_polish](/docs/generated/tests-unit-test_nav_layout_polish) | uses_by | T-2033: arc-007 nav-layout polish — static guards for the sidebar/rail fixes. |
| [test_nav_layouts](/docs/generated/tests-unit-test_nav_layouts) | uses_by | T-2011 (arc-007 S2d): nav-layout axis contract. |
| [test_pins](/docs/generated/tests-unit-test_pins) | uses_by | T-2010 (arc-007 S2c): pinned-pages model contract. |
| [app](/docs/generated/web-app) | uses_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |

## Related

### Tasks
- T-819: Build lib/config.sh — 3-tier config resolution for framework settings
- T-881: Upgrade consumer projects with T-879 xargs fix and T-880 init improvements
- T-964: Watchtower single terminal — xterm.js + Flask-SocketIO PTY bridge (T-962 Phase 1)
- T-983: Watchtower sessions page — list active terminal sessions with status and controls

---
*Auto-generated from Component Fabric. Card: `web-blueprints-__init__.yaml`*
*Last verified: 2026-03-01*
