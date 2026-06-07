# __init__

> Flask blueprint:   Init  

**Type:** route | **Subsystem:** watchtower | **Location:** `web/blueprints/__init__.py`

## What It Does

Flask blueprints for the Agentic Engineering Framework web UI
Centralizes blueprint registration (T-431/A2).
Adding a new blueprint: import it here and append to _BLUEPRINTS.

## Dependencies (66)

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
| [prompts](/docs/generated/web-blueprints-prompts) | calls | TODO: describe what this component does |
| [prompts](/docs/generated/web-blueprints-prompts) | registers | TODO: describe what this component does |
| [pending](/docs/generated/web-blueprints-pending) | calls | TODO: describe what this component does |
| [pending](/docs/generated/web-blueprints-pending) | registers | TODO: describe what this component does |
| [fleet](/docs/generated/web-blueprints-fleet) | calls | TODO: describe what this component does |
| [fleet](/docs/generated/web-blueprints-fleet) | registers | TODO: describe what this component does |
| [reviewer](/docs/generated/web-blueprints-reviewer) | calls | TODO: describe what this component does |
| [reviewer](/docs/generated/web-blueprints-reviewer) | registers | TODO: describe what this component does |
| [escalation](/docs/generated/web-blueprints-escalation) | calls | TODO: describe what this component does |
| [escalation](/docs/generated/web-blueprints-escalation) | registers | TODO: describe what this component does |
| [hooks](/docs/generated/web-blueprints-hooks) | calls | TODO: describe what this component does |
| [orchestrator](/docs/generated/web-blueprints-orchestrator) | calls | TODO: describe what this component does |
| [arcs](/docs/generated/web-blueprints-arcs) | calls | Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs. |
| [hooks](/docs/generated/web-blueprints-hooks) | registers | TODO: describe what this component does |
| [orchestrator](/docs/generated/web-blueprints-orchestrator) | registers | TODO: describe what this component does |
| [arcs](/docs/generated/web-blueprints-arcs) | registers | Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs. |
| [bvp](/docs/generated/web-blueprints-bvp) | calls | TODO: describe what this component does |
| [bvp](/docs/generated/web-blueprints-bvp) | registers | TODO: describe what this component does |

## Used By (12)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [app](/docs/generated/web-app) | imported_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port — _Python package init; implicitly loaded when app.py imports from web.blueprints.*_ |
| [app](/docs/generated/web-app) | called_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [test_bvp_blueprint_cost](/docs/generated/tests-unit-test_bvp_blueprint_cost) | called_by | TODO: describe what this component does |
| [test_bvp_scatter_arc_mode](/docs/generated/tests-unit-test_bvp_scatter_arc_mode) | called_by | TODO: describe what this component does |
| [test_arc_display_helper](/docs/generated/tests-unit-test_arc_display_helper) | called_by | TODO: describe what this component does |
| [test_appearance_validation](/docs/generated/tests-unit-test_appearance_validation) | called_by | TODO: describe what this component does |
| [test_cockpit_activity](/docs/generated/tests-unit-test_cockpit_activity) | called_by | TODO: describe what this component does |
| [test_cockpit_knowledge_counts](/docs/generated/tests-unit-test_cockpit_knowledge_counts) | called_by | TODO: describe what this component does |
| [test_cockpit_traceability](/docs/generated/tests-unit-test_cockpit_traceability) | called_by | TODO: describe what this component does |
| [test_nav_layout_polish](/docs/generated/tests-unit-test_nav_layout_polish) | called_by | TODO: describe what this component does |
| [test_nav_layouts](/docs/generated/tests-unit-test_nav_layouts) | called_by | TODO: describe what this component does |
| [test_pins](/docs/generated/tests-unit-test_pins) | called_by | TODO: describe what this component does |

## Related

### Tasks
- T-819: Build lib/config.sh — 3-tier config resolution for framework settings
- T-881: Upgrade consumer projects with T-879 xargs fix and T-880 init improvements
- T-964: Watchtower single terminal — xterm.js + Flask-SocketIO PTY bridge (T-962 Phase 1)
- T-983: Watchtower sessions page — list active terminal sessions with status and controls

---
*Auto-generated from Component Fabric. Card: `web-blueprints-__init__.yaml`*
*Last verified: 2026-03-01*
