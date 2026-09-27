# shared

> Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering)

**Type:** library | **Subsystem:** watchtower | **Location:** `web/shared.py`

**Tags:** `flask`, `web-ui`, `shared`, `navigation`

## What It Does

Path resolution

## Dependencies (13)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [docs](/docs/generated/web-blueprints-docs) | calls | Watchtower docs blueprint: file viewer for docs/reports/ and docs/articles/ — renders markdown with syntax highlighting. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [settings](/docs/generated/web-blueprints-settings) | calls | Watchtower settings blueprint: framework configuration display — shows hooks, cron config, notification state. |
| [settings](/docs/generated/web-blueprints-settings) | registers | Watchtower settings blueprint: framework configuration display — shows hooks, cron config, notification state. |
| [recommendation_claims](/docs/generated/lib-reviewer-recommendation_claims) | calls | T-100187: Recommendation-claims validator (T-100186 GO slice A). |
| [bvp](/docs/generated/web-blueprints-bvp) | calls | BVP scatter blueprint — T-1928 (arc-006, value-prioritisation, T-NEW-12a). |
| [approvals](/docs/generated/web-blueprints-approvals) | calls | Watchtower approvals blueprint: human review queue — lists tasks with unchecked Human ACs, supports checkbox toggling. |
| [timeline](/docs/generated/web-blueprints-timeline) | calls | Blueprint 'timeline' — routes: /timeline |
| [search_utils](/docs/generated/web-search_utils) | calls | Watchtower search utilities: full-text search across tasks, learnings, decisions for the search page. |
| [cockpit](/docs/generated/web-blueprints-cockpit) | calls | Flask blueprint: Cockpit |
| [static_scan](/docs/generated/lib-reviewer-static_scan) | calls | Static-scan reviewer (T-1443 v1.0 → v1.5). |
| [settings](/docs/generated/web-blueprints-settings) | uses | Watchtower settings blueprint: framework configuration display — shows hooks, cron config, notification state. |
| [inception-readiness](/docs/generated/lib-inception-readiness) | calls | lib/inception-readiness.sh — SHARED decision-readiness predicates for inception tasks. |

## Used By (138)

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
| [prompts](/docs/generated/web-blueprints-prompts) | called_by | Prompts blueprint — reusable agent-prompt register UI (T-1283 B3). |
| [pending](/docs/generated/web-blueprints-pending) | called_by | Pending-updates registry blueprint — Watchtower UI for T-1268 B3. |
| [fleet](/docs/generated/web-blueprints-fleet) | called_by | Fleet blueprint — operational dashboard for termlink fleet health (T-1103, T-1107). |
| [reviewer](/docs/generated/web-blueprints-reviewer) | called_by | Reviewer blueprint — machine-reviewer system state (T-1443 v1.5a). |
| [escalation](/docs/generated/web-blueprints-escalation) | called_by | Escalation drift blueprint — G-019 Layer C surface (T-1595). |
| [test_project_root_discovery](/docs/generated/tests-unit-test_project_root_discovery) | called_by | T-1747 / G-069 — Regression tests for web.shared._discover_project_root. |
| [arcs](/docs/generated/web-blueprints-arcs) | called_by | Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs. |
| [hooks](/docs/generated/web-blueprints-hooks) | called_by | T-1632 (B-3c of T-1626) — Watchtower /hooks page. |
| [orchestrator](/docs/generated/web-blueprints-orchestrator) | called_by | T-1647 (W10 #2 of T-1641 Arc C) — Watchtower /orchestrator page. |
| [test_file_route_extensions](/docs/generated/tests-unit-test_file_route_extensions) | called_by | T-1764: Regression tests for the /file/<path> route. |
| [episodic_yaml_decision_escape](/docs/generated/tests-unit-episodic_yaml_decision_escape) | tests_by | T-1871 — episodic generator must emit valid YAML when ## Decisions content contains YAML-double-quote-hostile characters (backticks, backslashes, embedded quotes, escape sequences). |
| [test_render_surface_gate](/docs/generated/tests-unit-test_render_surface_gate) | tests_by | T-1766 — render-surface Human-AC gate (P-013). |
| [check_render_surface_human_ac_sigpipe](/docs/generated/tests-unit-check_render_surface_human_ac_sigpipe) | tests_by | T-1900: render-surface gate error path used to die with SIGPIPE (exit 141) under set -eo pipefail when `render_surface_files_in \| head -N` produced more lines than head consumed. |
| [test_render_page_guard](/docs/generated/tests-unit-test_render_page_guard) | called_by | T-1899: render_page() runtime guard refuses templates that extend base.html. |
| [bvp](/docs/generated/web-blueprints-bvp) | called_by | BVP scatter blueprint — T-1928 (arc-006, value-prioritisation, T-NEW-12a). |
| [test_breadcrumb](/docs/generated/tests-unit-test_breadcrumb) | called_by | T-2009 (arc-007 S2b): path-derived breadcrumb guard. |
| [test_nav_subsections](/docs/generated/tests-unit-test_nav_subsections) | called_by | T-2008 (arc-007 S2a): nav IA regroup + Govern sub-grouping guard. |
| [test_orchestrator_workflow_coverage](/docs/generated/tests-unit-test_orchestrator_workflow_coverage) | called_by | T-1799: /orchestrator surfaces Workflow coverage panel. |
| [test_command_palette](/docs/generated/tests-unit-test_command_palette) | called_by | T-2012 (arc-007 S6a): command-palette jump-list contract (server side). |
| [designer](/docs/generated/web-blueprints-designer) | called_by | Designer blueprint — serves the pinned Workflow Designer build (T-2521). |
| [designer_api](/docs/generated/web-blueprints-designer_api) | called_by | Designer gallery-server API (T-2529) — the ``/api/*`` endpoints that 832's shipped 0.2.0 Workflow Designer client already calls. |
| [extract_recommendation_close_keep_open](/docs/generated/tests-unit-extract_recommendation_close_keep_open) | tests_by | T-1960: extend extract_recommendation parser to accept CLOSE / KEEP-OPEN verdicts (in addition to GO / NO-GO / DEFER). Pinned so the arc-close recommendation surface doesn't silently fall back to verdict='?'. |
| [learnings-route](/docs/generated/learnings-route) | uses_by | Serve the /learnings page showing all project learnings, patterns, and practices. |
| [test_arc_membership_web_surfaces](/docs/generated/tests-unit-test_arc_membership_web_surfaces) | uses_by | T-1879 (T-NEW-14): silent-corpus #2 sweep — web surfaces must read both `arc_id:` frontmatter (T-1849 canonical, T-1850 migrated) AND legacy `arc:<slug>` tag. |
| [test_arcs_membership_cached](/docs/generated/tests-unit-test_arcs_membership_cached) | called_by | T-2774: /arcs constituent resolution must not re-scan the corpus per arc. |
| [test_arcs_routes](/docs/generated/tests-unit-test_arcs_routes) | uses_by | Unit tests for /arcs and /arcs/<id> routes (T-1662) — Flask test_client pins index empty/populated, detail in-progress with three-question check, detail closed without check, 404 for unregistered, missing-task graceful render. |
| [test_breadcrumb](/docs/generated/tests-unit-test_breadcrumb) | uses_by | T-2009 (arc-007 S2b): path-derived breadcrumb guard. |
| [test_file_route_extensions](/docs/generated/tests-unit-test_file_route_extensions) | uses_by | T-1764: Regression tests for the /file/<path> route. |
| [test_frontmatter_loader_equivalence](/docs/generated/tests-unit-test_frontmatter_loader_equivalence) | called_by | T-2774: the fast YAML loader must parse identically to the pure-Python one. |
| [test_frontmatter_loader_equivalence](/docs/generated/tests-unit-test_frontmatter_loader_equivalence) | uses_by | T-2774: the fast YAML loader must parse identically to the pure-Python one. |
| [test_inception_commit_rename_paths](/docs/generated/tests-unit-test_inception_commit_rename_paths) | uses_by | T-2864 — the Watchtower decision commit must stage BOTH sides of a rename. |
| [test_nav_subsections](/docs/generated/tests-unit-test_nav_subsections) | uses_by | T-2008 (arc-007 S2a): nav IA regroup + Govern sub-grouping guard. |
| [test_orchestrator_parallel_view](/docs/generated/tests-unit-test_orchestrator_parallel_view) | uses_by | T-2342 (arc-011 M1 §5) — /orchestrator/parallel view. |
| [test_orchestrator_workflow_coverage](/docs/generated/tests-unit-test_orchestrator_workflow_coverage) | uses_by | T-1799: /orchestrator surfaces Workflow coverage panel. |
| [test_project_root_discovery](/docs/generated/tests-unit-test_project_root_discovery) | uses_by | T-1747 / G-069 — Regression tests for web.shared._discover_project_root. |
| [test_render_page_guard](/docs/generated/tests-unit-test_render_page_guard) | uses_by | T-1899: render_page() runtime guard refuses templates that extend base.html. |
| [test_reviewer_audit_blueprint](/docs/generated/tests-unit-test_reviewer_audit_blueprint) | uses_by | Unit tests for /reviewer/audit Watchtower route (T-1486). |
| [test_inception_decide_hardening](/docs/generated/tests-web-test_inception_decide_hardening) | uses_by | T-1470: Watchtower /inception/decide hardens against side-effect failure. |
| [app](/docs/generated/web-app) | uses_by | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [api](/docs/generated/web-blueprints-api) | uses_by | Watchtower API blueprint: JSON endpoints for AJAX/htmx — task data, metrics, approval actions. |
| [approvals](/docs/generated/web-blueprints-approvals) | uses_by | Watchtower approvals blueprint: human review queue — lists tasks with unchecked Human ACs, supports checkbox toggling. |
| [arcs](/docs/generated/web-blueprints-arcs) | uses_by | Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs. |
| [bvp](/docs/generated/web-blueprints-bvp) | uses_by | BVP scatter blueprint — T-1928 (arc-006, value-prioritisation, T-NEW-12a). |
| [cockpit](/docs/generated/web-blueprints-cockpit) | uses_by | Flask blueprint: Cockpit |
| [config](/docs/generated/web-blueprints-config) | uses_by | Flask blueprint that renders the configuration settings page showing all framework settings with current values and resolution sources |
| [core](/docs/generated/web-blueprints-core) | uses_by | Flask blueprint: Core |
| [costs](/docs/generated/web-blueprints-costs) | uses_by | Watchtower /costs page — token usage dashboard with session table and project summary (T-802) |
| [cron](/docs/generated/web-blueprints-cron) | uses_by | Watchtower cron blueprint: cron job status display — shows registered jobs, schedule, last run, active/paused state. |
| [designer](/docs/generated/web-blueprints-designer) | uses_by | Designer blueprint — serves the pinned Workflow Designer build (T-2521). |
| [designer_api](/docs/generated/web-blueprints-designer_api) | uses_by | Designer gallery-server API (T-2529) — the ``/api/*`` endpoints that 832's shipped 0.2.0 Workflow Designer client already calls. |
| [discoveries](/docs/generated/web-blueprints-discoveries) | uses_by | Flask blueprint serving /discoveries route. Displays audit discovery findings with WARN/FAIL status from cron and manual audits. |
| [discovery_blueprint](/docs/generated/web-blueprints-discovery) | uses_by | Watchtower discovery page — decisions, learnings, gaps, search, graduation |
| [docs](/docs/generated/web-blueprints-docs) | uses_by | Watchtower docs blueprint: file viewer for docs/reports/ and docs/articles/ — renders markdown with syntax highlighting. |
| [embeddings](/docs/generated/web-blueprints-embeddings) | called_by | Embeddings blueprint — the recall substrate's own instrument panel (T-1719 A4). |
| [embeddings](/docs/generated/web-blueprints-embeddings) | uses_by | Embeddings blueprint — the recall substrate's own instrument panel (T-1719 A4). |
| [enforcement](/docs/generated/web-blueprints-enforcement) | uses_by | Flask blueprint: Enforcement |
| [escalation](/docs/generated/web-blueprints-escalation) | uses_by | Escalation drift blueprint — G-019 Layer C surface (T-1595). |
| [fabric](/docs/generated/web-blueprints-fabric) | uses_by | Flask blueprint: Fabric |
| [fleet](/docs/generated/web-blueprints-fleet) | uses_by | Fleet blueprint — operational dashboard for termlink fleet health (T-1103, T-1107). |
| [hooks](/docs/generated/web-blueprints-hooks) | uses_by | T-1632 (B-3c of T-1626) — Watchtower /hooks page. |
| [inception](/docs/generated/web-blueprints-inception) | uses_by | Blueprint 'inception' — routes: /inception |
| [metrics](/docs/generated/web-blueprints-metrics) | uses_by | Flask blueprint: Metrics |
| [orchestrator](/docs/generated/web-blueprints-orchestrator) | uses_by | T-1647 (W10 #2 of T-1641 Arc C) — Watchtower /orchestrator page. |
| [pending](/docs/generated/web-blueprints-pending) | uses_by | Pending-updates registry blueprint — Watchtower UI for T-1268 B3. |
| [prompts](/docs/generated/web-blueprints-prompts) | uses_by | Prompts blueprint — reusable agent-prompt register UI (T-1283 B3). |
| [quality](/docs/generated/web-blueprints-quality) | uses_by | Flask blueprint: Quality |
| [review](/docs/generated/web-blueprints-review) | uses_by | Watchtower review blueprint: task review page — shows ACs, research artifacts, recommendation, approval actions. |
| [reviewer](/docs/generated/web-blueprints-reviewer) | uses_by | Reviewer blueprint — machine-reviewer system state (T-1443 v1.5a). |
| [risks](/docs/generated/web-blueprints-risks) | uses_by | Flask blueprint 'risks' serving routes: /risks |
| [session](/docs/generated/web-blueprints-session) | uses_by | Flask blueprint: Session |
| [sessions](/docs/generated/web-blueprints-sessions) | uses_by | Flask blueprint that renders the terminal session management page listing active and historical sessions |
| [settings](/docs/generated/web-blueprints-settings) | uses_by | Watchtower settings blueprint: framework configuration display — shows hooks, cron config, notification state. |
| [tasks](/docs/generated/web-blueprints-tasks) | uses_by | Flask blueprint: Tasks |
| [terminal](/docs/generated/web-blueprints-terminal) | uses_by | Flask blueprint providing the interactive web terminal API with session creation, I/O, resize, and profile-based configuration |
| [timeline](/docs/generated/web-blueprints-timeline) | uses_by | Blueprint 'timeline' — routes: /timeline |
| [context_loader](/docs/generated/web-context_loader) | uses_by | Centralized YAML loading for context project files (learnings, patterns, decisions, practices, concerns, directives). Replaces duplicated try/except blocks across blueprints. Uses shared.load_yaml() for error collection. |
| [embeddings](/docs/generated/web-embeddings) | uses_by | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |
| [search](/docs/generated/web-search) | uses_by | Tantivy BM25 full-text search engine — indexes all YAML/Markdown files, provides ranked search with snippets |
| [search_utils](/docs/generated/web-search_utils) | uses_by | Watchtower search utilities: full-text search across tasks, learnings, decisions for the search page. |
| [subprocess_utils](/docs/generated/web-subprocess_utils) | uses_by | Consistent subprocess execution for git and fw commands. Provides run_git_command() and run_fw_command() with standardized timeouts, encoding, and error handling. |
| [enrich](/docs/generated/agents-fabric-lib-enrich) | called_by | Fabric enrichment engine — auto-detect dependency edges from source analysis. |
| [ask](/docs/generated/web-ask) | called_by | LLM-assisted Q&A for Watchtower search. |
| [ask](/docs/generated/web-ask) | uses_by | LLM-assisted Q&A for Watchtower search. |
| [metrics_history](/docs/generated/web-metrics_history) | called_by | Metrics history — read and query time-series audit data. |
| [metrics_history](/docs/generated/web-metrics_history) | uses_by | Metrics history — read and query time-series audit data. |
| [qa_feedback](/docs/generated/web-qa_feedback) | called_by | Q&A feedback storage — SQLite-backed thumbs up/down tracking (T-267). |
| [qa_feedback](/docs/generated/web-qa_feedback) | uses_by | Q&A feedback storage — SQLite-backed thumbs up/down tracking (T-267). |
| [secrets_store](/docs/generated/web-secrets_store) | called_by | Encrypted API key storage for Watchtower. |
| [secrets_store](/docs/generated/web-secrets_store) | uses_by | Encrypted API key storage for Watchtower. |
| [test_app](/docs/generated/web-test_app) | called_by | Test suite for the Watchtower web UI. |
| [test_app](/docs/generated/web-test_app) | uses_by | Test suite for the Watchtower web UI. |
| [test_ac_field_render_safety](/docs/generated/tests-unit-test_ac_field_render_safety) | called_by | T-3369: AC field rendering — escaped input, un-escaped output. |
| [manager](/docs/generated/web-llm-manager) | called_by | LLM provider manager — registration, active-provider selection, hot-switching and failover between Ollama and OpenRouter (T-377) |
| [manager](/docs/generated/web-llm-manager) | uses_by | LLM provider manager — registration, active-provider selection, hot-switching and failover between Ollama and OpenRouter (T-377) |
| [scanner](/docs/generated/web-watchtower-scanner) | called_by | Watchtower scan engine — reads project state (AUTHORITY tier) and writes structured YAML scan output |
| [scanner](/docs/generated/web-watchtower-scanner) | uses_by | Watchtower scan engine — reads project state (AUTHORITY tier) and writes structured YAML scan output |

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
