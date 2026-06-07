# app

> Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port

**Type:** entrypoint | **Subsystem:** watchtower | **Location:** `web/app.py`

**Tags:** `flask`, `web-ui`, `entrypoint`

## What It Does

Application factory

### Framework Reference

When building a web application:
1. **Check port availability** before starting (`ss -tlnp | grep :PORT`)
2. **Start the app** and report the URL to the user
3. **Report access options** — localhost, LAN IP (for other devices), internet (if applicable)
4. Never leave a built web app unstarted without informing the user

## Dependencies (30)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
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
| [search_utils](/docs/generated/web-search_utils) | calls | Watchtower search utilities: full-text search across tasks, learnings, decisions for the search page. |
| [__init__](/docs/generated/web-blueprints-__init__) | calls | Flask blueprint:   Init |
| [embeddings](/docs/generated/web-embeddings) | calls | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |
| [arcs](/docs/generated/web-blueprints-arcs) | calls | Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs. |
| [arcs](/docs/generated/web-blueprints-arcs) | registers | Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs. |

## Used By (38)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [badge](/docs/generated/web-templates-_partials-badge) | used-by | htmx partial: status badge component — renders colored badge for task status (captured, started-work, etc.). |
| [test_costs](/docs/generated/web-test_costs) | called_by | 24 pytest tests for costs blueprint — _fmt_tokens, _parse_session, _load_all_sessions, route (T-810) |
| [badge](/docs/generated/web-templates-_partials-badge) | used-by_by | htmx partial: status badge component — renders colored badge for task status (captured, started-work, etc.). |
| [test_reviewer_audit_blueprint](/docs/generated/tests-unit-test_reviewer_audit_blueprint) | called_by | TODO: describe what this component does |
| [test_inception_decide_hardening](/docs/generated/tests-web-test_inception_decide_hardening) | called_by | TODO: describe what this component does |
| [test_file_route_extensions](/docs/generated/tests-unit-test_file_route_extensions) | called_by | TODO: describe what this component does |
| [test_review_paused_resolve](/docs/generated/tests-unit-test_review_paused_resolve) | called_by | TODO: describe what this component does |
| [test_arc_membership_web_surfaces](/docs/generated/tests-unit-test_arc_membership_web_surfaces) | called_by | TODO: describe what this component does |
| [test_render_surface_gate](/docs/generated/tests-unit-test_render_surface_gate) | tests_by | TODO: describe what this component does |
| [ux-review](/docs/generated/agents-ux-review-ux-review) | called_by | TODO: describe what this component does |
| [review_link_validator](/docs/generated/lib-review_link_validator) | called_by | TODO: describe what this component does |
| [test_approvals_content_tokens](/docs/generated/tests-unit-test_approvals_content_tokens) | called_by | TODO: describe what this component does |
| [test_approvals_style_tokens](/docs/generated/tests-unit-test_approvals_style_tokens) | called_by | TODO: describe what this component does |
| [test_arcs_pages_tokens](/docs/generated/tests-unit-test_arcs_pages_tokens) | called_by | TODO: describe what this component does |
| [test_breadcrumb](/docs/generated/tests-unit-test_breadcrumb) | called_by | TODO: describe what this component does |
| [test_bulk_actions](/docs/generated/tests-unit-test_bulk_actions) | called_by | TODO: describe what this component does |
| [test_cockpit_activity](/docs/generated/tests-unit-test_cockpit_activity) | called_by | TODO: describe what this component does |
| [test_cockpit_density_spacing](/docs/generated/tests-unit-test_cockpit_density_spacing) | called_by | TODO: describe what this component does |
| [test_cockpit_inline_tokens](/docs/generated/tests-unit-test_cockpit_inline_tokens) | called_by | TODO: describe what this component does |
| [test_cockpit_knowledge_counts](/docs/generated/tests-unit-test_cockpit_knowledge_counts) | called_by | TODO: describe what this component does |
| [test_cockpit_status_pills](/docs/generated/tests-unit-test_cockpit_status_pills) | called_by | TODO: describe what this component does |
| [test_cockpit_traceability](/docs/generated/tests-unit-test_cockpit_traceability) | called_by | TODO: describe what this component does |
| [test_command_palette](/docs/generated/tests-unit-test_command_palette) | called_by | TODO: describe what this component does |
| [test_fabric_coupling_token](/docs/generated/tests-unit-test_fabric_coupling_token) | called_by | TODO: describe what this component does |
| [test_filter_chips](/docs/generated/tests-unit-test_filter_chips) | called_by | TODO: describe what this component does |
| [test_kanban_drag](/docs/generated/tests-unit-test_kanban_drag) | called_by | TODO: describe what this component does |
| [test_nav_layout_polish](/docs/generated/tests-unit-test_nav_layout_polish) | called_by | TODO: describe what this component does |
| [test_nav_layouts](/docs/generated/tests-unit-test_nav_layouts) | called_by | TODO: describe what this component does |
| [test_nav_subsections](/docs/generated/tests-unit-test_nav_subsections) | called_by | TODO: describe what this component does |
| [test_pins](/docs/generated/tests-unit-test_pins) | called_by | TODO: describe what this component does |
| [test_settings_nav_link](/docs/generated/tests-unit-test_settings_nav_link) | called_by | TODO: describe what this component does |
| [test_shortcuts_overlay](/docs/generated/tests-unit-test_shortcuts_overlay) | called_by | TODO: describe what this component does |
| [test_task_panel](/docs/generated/tests-unit-test_task_panel) | called_by | TODO: describe what this component does |
| [test_task_panel_edit](/docs/generated/tests-unit-test_task_panel_edit) | called_by | TODO: describe what this component does |
| [test_theme_toggle_contrast](/docs/generated/tests-unit-test_theme_toggle_contrast) | called_by | TODO: describe what this component does |

## Related

### Tasks
- T-865: Fix Fabric Explorer naming — use project_name in title
- T-881: Upgrade consumer projects with T-879 xargs fix and T-880 init improvements
- T-964: Watchtower single terminal — xterm.js + Flask-SocketIO PTY bridge (T-962 Phase 1)
- T-965: Multi-session terminal tabs + session management (T-962 Phase 2)
- T-966: TermLink session observation in Watchtower terminal (T-962 Phase 3)

---
*Auto-generated from Component Fabric. Card: `web-app.yaml`*
*Last verified: 2026-02-20*
