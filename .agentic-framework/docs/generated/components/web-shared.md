# shared

> Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering)

**Type:** library | **Subsystem:** watchtower | **Location:** `web/shared.py`

**Tags:** `flask`, `web-ui`, `shared`, `navigation`

## What It Does

Path resolution

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [docs](/docs/generated/web-blueprints-docs) | calls | Watchtower docs blueprint: file viewer for docs/reports/ and docs/articles/ — renders markdown with syntax highlighting. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [settings](/docs/generated/web-blueprints-settings) | calls | Watchtower settings blueprint: framework configuration display — shows hooks, cron config, notification state. |
| [settings](/docs/generated/web-blueprints-settings) | registers | Watchtower settings blueprint: framework configuration display — shows hooks, cron config, notification state. |

## Used By (60)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [learnings-route](/docs/generated/learnings-route) | called_by | Serve the /learnings page showing all project learnings, patterns, and practices. |
| [app](/docs/generated/web-app) | called_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [cockpit](/docs/generated/web-blueprints-cockpit) | called_by | Flask blueprint: Cockpit |
| [core](/docs/generated/web-blueprints-core) | called_by | Flask blueprint: Core |
| [enforcement](/docs/generated/web-blueprints-enforcement) | called_by | Flask blueprint: Enforcement |
| [fabric](/docs/generated/web-blueprints-fabric) | called_by | Flask blueprint: Fabric |
| [inception](/docs/generated/web-blueprints-inception) | called_by | Blueprint 'inception' — routes: /inception |
| [metrics](/docs/generated/web-blueprints-metrics) | called_by | Flask blueprint: Metrics |
| [quality](/docs/generated/web-blueprints-quality) | called_by | Flask blueprint: Quality |
| [risks](/docs/generated/web-blueprints-risks) | called_by | Flask blueprint 'risks' serving routes: /risks |
| [session](/docs/generated/web-blueprints-session) | called_by | Flask blueprint: Session |
| [tasks](/docs/generated/web-blueprints-tasks) | called_by | Flask blueprint: Tasks |
| [timeline](/docs/generated/web-blueprints-timeline) | called_by | Blueprint 'timeline' — routes: /timeline |
| [api](/docs/generated/web-blueprints-api) | imported_by | Watchtower API blueprint: JSON endpoints for AJAX/htmx — task data, metrics, approval actions. |
| [docs](/docs/generated/web-blueprints-docs) | imported_by | Watchtower docs blueprint: file viewer for docs/reports/ and docs/articles/ — renders markdown with syntax highlighting. |
| [settings](/docs/generated/web-blueprints-settings) | imported_by | Watchtower settings blueprint: framework configuration display — shows hooks, cron config, notification state. |
| [search_utils](/docs/generated/web-search_utils) | imported_by | Watchtower search utilities: full-text search across tasks, learnings, decisions for the search page. |
| [api](/docs/generated/web-blueprints-api) | called_by | Watchtower API blueprint: JSON endpoints for AJAX/htmx — task data, metrics, approval actions. |
| [approvals](/docs/generated/web-blueprints-approvals) | called_by | Watchtower approvals blueprint: human review queue — lists tasks with unchecked Human ACs, supports checkbox toggling. |
| [cron](/docs/generated/web-blueprints-cron) | called_by | Watchtower cron blueprint: cron job status display — shows registered jobs, schedule, last run, active/paused state. |
| [discoveries](/docs/generated/web-blueprints-discoveries) | called_by | Flask blueprint serving /discoveries route. Displays audit discovery findings with WARN/FAIL status from cron and manual audits. |
| [docs](/docs/generated/web-blueprints-docs) | called_by | Watchtower docs blueprint: file viewer for docs/reports/ and docs/articles/ — renders markdown with syntax highlighting. |
| [review](/docs/generated/web-blueprints-review) | called_by | Watchtower review blueprint: task review page — shows ACs, research artifacts, recommendation, approval actions. |
| [settings](/docs/generated/web-blueprints-settings) | called_by | Watchtower settings blueprint: framework configuration display — shows hooks, cron config, notification state. |
| [embeddings](/docs/generated/web-embeddings) | called_by | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |
| [search](/docs/generated/web-search) | called_by | Tantivy BM25 full-text search engine — indexes all YAML/Markdown files, provides ranked search with snippets |
| [search_utils](/docs/generated/web-search_utils) | called_by | Watchtower search utilities: full-text search across tasks, learnings, decisions for the search page. |
| [api](/docs/generated/web-blueprints-api) | imports_by | Watchtower API blueprint: JSON endpoints for AJAX/htmx — task data, metrics, approval actions. |
| [docs](/docs/generated/web-blueprints-docs) | imports_by | Watchtower docs blueprint: file viewer for docs/reports/ and docs/articles/ — renders markdown with syntax highlighting. |
| [settings](/docs/generated/web-blueprints-settings) | imports_by | Watchtower settings blueprint: framework configuration display — shows hooks, cron config, notification state. |
| [context_loader](/docs/generated/web-context_loader) | called_by | Centralized YAML loading for context project files (learnings, patterns, decisions, practices, concerns, directives). Replaces duplicated try/except blocks across blueprints. Uses shared.load_yaml() for error collection. |
| [search](/docs/generated/web-search) | imports_by | Tantivy BM25 full-text search engine — indexes all YAML/Markdown files, provides ranked search with snippets |
| [search_utils](/docs/generated/web-search_utils) | imports_by | Watchtower search utilities: full-text search across tasks, learnings, decisions for the search page. |
| [subprocess_utils](/docs/generated/web-subprocess_utils) | called_by | Consistent subprocess execution for git and fw commands. Provides run_git_command() and run_fw_command() with standardized timeouts, encoding, and error handling. |
| [costs](/docs/generated/web-blueprints-costs) | called-by | Watchtower /costs page — token usage dashboard with session table and project summary (T-802) |
| [config](/docs/generated/web-blueprints-config) | called-by | Flask blueprint that renders the configuration settings page showing all framework settings with current values and resolution sources |
| [discovery_blueprint](/docs/generated/web-blueprints-discovery) | called-by | Watchtower discovery page — decisions, learnings, gaps, search, graduation |
| [sessions](/docs/generated/web-blueprints-sessions) | called_by | Flask blueprint that renders the terminal session management page listing active and historical sessions |
| [terminal](/docs/generated/web-blueprints-terminal) | called_by | Flask blueprint providing the interactive web terminal API with session creation, I/O, resize, and profile-based configuration |
| [config](/docs/generated/web-blueprints-config) | called_by | Flask blueprint that renders the configuration settings page showing all framework settings with current values and resolution sources |
| [costs](/docs/generated/web-blueprints-costs) | called_by | Watchtower /costs page — token usage dashboard with session table and project summary (T-802) |
| [discovery_blueprint](/docs/generated/web-blueprints-discovery) | called_by | Watchtower discovery page — decisions, learnings, gaps, search, graduation |
| [prompts](/docs/generated/web-blueprints-prompts) | called_by | TODO: describe what this component does |
| [pending](/docs/generated/web-blueprints-pending) | called_by | TODO: describe what this component does |
| [fleet](/docs/generated/web-blueprints-fleet) | called_by | TODO: describe what this component does |
| [reviewer](/docs/generated/web-blueprints-reviewer) | called_by | TODO: describe what this component does |
| [escalation](/docs/generated/web-blueprints-escalation) | called_by | TODO: describe what this component does |
| [test_project_root_discovery](/docs/generated/tests-unit-test_project_root_discovery) | called_by | TODO: describe what this component does |
| [arcs](/docs/generated/web-blueprints-arcs) | called_by | Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs. |
| [hooks](/docs/generated/web-blueprints-hooks) | called_by | TODO: describe what this component does |
| [orchestrator](/docs/generated/web-blueprints-orchestrator) | called_by | TODO: describe what this component does |
| [test_file_route_extensions](/docs/generated/tests-unit-test_file_route_extensions) | called_by | TODO: describe what this component does |
| [episodic_yaml_decision_escape](/docs/generated/tests-unit-episodic_yaml_decision_escape) | tests_by | TODO: describe what this component does |
| [test_render_surface_gate](/docs/generated/tests-unit-test_render_surface_gate) | tests_by | TODO: describe what this component does |
| [check_render_surface_human_ac_sigpipe](/docs/generated/tests-unit-check_render_surface_human_ac_sigpipe) | tests_by | TODO: describe what this component does |
| [test_render_page_guard](/docs/generated/tests-unit-test_render_page_guard) | called_by | TODO: describe what this component does |
| [bvp](/docs/generated/web-blueprints-bvp) | called_by | TODO: describe what this component does |
| [test_breadcrumb](/docs/generated/tests-unit-test_breadcrumb) | called_by | TODO: describe what this component does |
| [test_nav_subsections](/docs/generated/tests-unit-test_nav_subsections) | called_by | TODO: describe what this component does |
| [test_orchestrator_workflow_coverage](/docs/generated/tests-unit-test_orchestrator_workflow_coverage) | called_by | TODO: describe what this component does |

## Related

### Tasks
- T-819: Build lib/config.sh — 3-tier config resolution for framework settings
- T-851: Linkable task references in handover session summary — clickable T-XXX links to Watchtower task pages
- T-855: Sync vendored .agentic-framework/ with T-849 through T-854 fixes
- T-964: Watchtower single terminal — xterm.js + Flask-SocketIO PTY bridge (T-962 Phase 1)
- T-984: Add Sessions link to Watchtower navigation

---
*Auto-generated from Component Fabric. Card: `web-shared.yaml`*
*Last verified: 2026-02-20*
