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

## Dependencies (38)

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
| [shared](/docs/generated/web-shared) | uses | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [search_utils](/docs/generated/web-search_utils) | uses | Watchtower search utilities: full-text search across tasks, learnings, decisions for the search page. |
| [arcs](/docs/generated/web-blueprints-arcs) | uses | Watchtower /arcs (index) + /arcs/<id> (detail) blueprint — generic operator-facing arc surface. Reads .context/arcs/*.yaml registry + .context/working/arc-focus.yaml. Detail page shows constituent task table + section Arc Completion Discipline three-question check + fw arc close snippet for in-progress arcs. |
| [__init__](/docs/generated/web-blueprints-__init__) | uses | Flask blueprint:   Init |
| [embeddings](/docs/generated/web-embeddings) | uses | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |
| [config](/docs/generated/web-config) | calls | Environment-based configuration for Watchtower. |
| [test_app](/docs/generated/web-test_app) | calls | Test suite for the Watchtower web UI. |
| [config](/docs/generated/web-config) | uses | Environment-based configuration for Watchtower. |

## Used By (103)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [badge](/docs/generated/web-templates-_partials-badge) | used-by | htmx partial: status badge component — renders colored badge for task status (captured, started-work, etc.). |
| [test_costs](/docs/generated/web-test_costs) | called_by | 24 pytest tests for costs blueprint — _fmt_tokens, _parse_session, _load_all_sessions, route (T-810) |
| [badge](/docs/generated/web-templates-_partials-badge) | used-by_by | htmx partial: status badge component — renders colored badge for task status (captured, started-work, etc.). |
| [test_reviewer_audit_blueprint](/docs/generated/tests-unit-test_reviewer_audit_blueprint) | called_by | Unit tests for /reviewer/audit Watchtower route (T-1486). |
| [test_inception_decide_hardening](/docs/generated/tests-web-test_inception_decide_hardening) | called_by | T-1470: Watchtower /inception/decide hardens against side-effect failure. |
| [test_file_route_extensions](/docs/generated/tests-unit-test_file_route_extensions) | called_by | T-1764: Regression tests for the /file/<path> route. |
| [test_review_paused_resolve](/docs/generated/tests-unit-test_review_paused_resolve) | called_by | Tests for /review/T-XXX paused-dispatch panel + resolve endpoint. |
| [test_arc_membership_web_surfaces](/docs/generated/tests-unit-test_arc_membership_web_surfaces) | called_by | T-1879 (T-NEW-14): silent-corpus #2 sweep — web surfaces must read both `arc_id:` frontmatter (T-1849 canonical, T-1850 migrated) AND legacy `arc:<slug>` tag. |
| [test_render_surface_gate](/docs/generated/tests-unit-test_render_surface_gate) | tests_by | T-1766 — render-surface Human-AC gate (P-013). |
| [ux-review](/docs/generated/agents-ux-review-ux-review) | called_by | UX-review capture engine (T-2002): drives Watchtower render surfaces in a headless browser across every appearance preset and produces visual review artifacts for human review. |
| [review_link_validator](/docs/generated/lib-review_link_validator) | called_by | Validate Watchtower review/inception handoff links at the moment of handoff. |
| [test_approvals_content_tokens](/docs/generated/tests-unit-test_approvals_content_tokens) | called_by | T-2026 (arc-007 S3c2): _approvals_content.html inline styles use semantic tokens. |
| [test_approvals_style_tokens](/docs/generated/tests-unit-test_approvals_style_tokens) | called_by | T-2025 (arc-007 S3c): approvals.html <style> block uses per-palette semantic tokens. |
| [test_arcs_pages_tokens](/docs/generated/tests-unit-test_arcs_pages_tokens) | called_by | T-2027 (arc-007 S5a): Arcs section templates use semantic --wt-* tokens. |
| [test_breadcrumb](/docs/generated/tests-unit-test_breadcrumb) | called_by | T-2009 (arc-007 S2b): path-derived breadcrumb guard. |
| [test_bulk_actions](/docs/generated/tests-unit-test_bulk_actions) | called_by | T-2018 (arc-007 S4e/S6c): bulk multi-select + floating action bar. |
| [test_cockpit_activity](/docs/generated/tests-unit-test_cockpit_activity) | called_by | T-2020 (arc-007 S6d): cockpit live activity feed — recent commits via htmx poll. |
| [test_cockpit_density_spacing](/docs/generated/tests-unit-test_cockpit_density_spacing) | called_by | T-2029: cockpit spacing scales with the density axis; exclusions are honoured. |
| [test_cockpit_inline_tokens](/docs/generated/tests-unit-test_cockpit_inline_tokens) | called_by | T-2024 (arc-007 S3a2): cockpit inline-style hexes use per-palette semantic tokens. |
| [test_cockpit_knowledge_counts](/docs/generated/tests-unit-test_cockpit_knowledge_counts) | called_by | T-2022: Cockpit System Health Knowledge counts come from live helpers, not a missing scan key. |
| [test_cockpit_status_pills](/docs/generated/tests-unit-test_cockpit_status_pills) | called_by | T-2023 (arc-007 S3a): cockpit status colours use per-palette semantic tokens. |
| [test_cockpit_traceability](/docs/generated/tests-unit-test_cockpit_traceability) | called_by | T-2021: Cockpit System Health renders traceability as a percentage, not a raw dict. |
| [test_command_palette](/docs/generated/tests-unit-test_command_palette) | called_by | T-2012 (arc-007 S6a): command-palette jump-list contract (server side). |
| [test_fabric_coupling_token](/docs/generated/tests-unit-test_fabric_coupling_token) | called_by | T-2028 (arc-007 S5b): fabric coupling-note uses --wt-danger; categorical map stays fixed. |
| [test_filter_chips](/docs/generated/tests-unit-test_filter_chips) | called_by | T-2016 (arc-007 S4c): active-filter chips on the tasks board. |
| [test_kanban_drag](/docs/generated/tests-unit-test_kanban_drag) | called_by | T-2019 (arc-007 S4d): drag-to-reorder kanban — cross-column status change. |
| [test_nav_layout_polish](/docs/generated/tests-unit-test_nav_layout_polish) | called_by | T-2033: arc-007 nav-layout polish — static guards for the sidebar/rail fixes. |
| [test_nav_layouts](/docs/generated/tests-unit-test_nav_layouts) | called_by | T-2011 (arc-007 S2d): nav-layout axis contract. |
| [test_nav_subsections](/docs/generated/tests-unit-test_nav_subsections) | called_by | T-2008 (arc-007 S2a): nav IA regroup + Govern sub-grouping guard. |
| [test_pins](/docs/generated/tests-unit-test_pins) | called_by | T-2010 (arc-007 S2c): pinned-pages model contract. |
| [test_settings_nav_link](/docs/generated/tests-unit-test_settings_nav_link) | called_by | T-2032: the top-bar action cluster has a gear link to the settings/appearance page. |
| [test_shortcuts_overlay](/docs/generated/tests-unit-test_shortcuts_overlay) | called_by | T-2013 (arc-007 S6b): keyboard-shortcuts overlay — server-side presence. |
| [test_task_panel](/docs/generated/tests-unit-test_task_panel) | called_by | T-2015 (arc-007 S4a): slide-in dockable task side-panel — server-side guarantees. |
| [test_task_panel_edit](/docs/generated/tests-unit-test_task_panel_edit) | called_by | T-2017 (arc-007 S4b): inline-edit task meta cells in the side panel. |
| [test_theme_toggle_contrast](/docs/generated/tests-unit-test_theme_toggle_contrast) | called_by | T-2031: the dark-mode toggle uses --wt-text (palette text token), not --pico-color. |
| [test_designer_api_uuid_identity](/docs/generated/tests-web-test_designer_api_uuid_identity) | called_by | T-2573 (T-2571 S1): immutable workflow uuid in the designer store. |
| [test_designer_registry_claim](/docs/generated/tests-web-test_designer_registry_claim) | called_by | T-2575 (T-2571 S6): claim — bind a ghost uuid to a live project. |
| [test_designer_registry_ghosts](/docs/generated/tests-web-test_designer_registry_ghosts) | called_by | T-2574 (T-2571 S2): pending-ref registry — ghost capture at save. |
| [test_designer_landing](/docs/generated/tests-web-test_designer_landing) | called_by | T-2589: /designer corpus landing page — server truth first, editor at /designer/app. |
| [test_api_overlay](/docs/generated/tests-web-test_api_overlay) | called_by | T-2629: /api/overlay endpoint contract — status codes + payload shape. |
| [test_api_version_latest](/docs/generated/tests-web-test_api_version_latest) | called_by | T-2624: /api/version bare-id resolution — `?id=` alone serves the latest version. |
| [test_designer_overlay](/docs/generated/tests-web-test_designer_overlay) | called_by | T-2630: /designer/overlay wrapper page + landing overlay-link contract. |
| [ux-review](/docs/generated/agents-ux-review-ux-review) | uses_by | UX-review capture engine (T-2002): drives Watchtower render surfaces in a headless browser across every appearance preset and produces visual review artifacts for human review. |
| [test_approvals_content_tokens](/docs/generated/tests-unit-test_approvals_content_tokens) | uses_by | T-2026 (arc-007 S3c2): _approvals_content.html inline styles use semantic tokens. |
| [test_approvals_style_tokens](/docs/generated/tests-unit-test_approvals_style_tokens) | uses_by | T-2025 (arc-007 S3c): approvals.html <style> block uses per-palette semantic tokens. |
| [test_arc_membership_web_surfaces](/docs/generated/tests-unit-test_arc_membership_web_surfaces) | uses_by | T-1879 (T-NEW-14): silent-corpus #2 sweep — web surfaces must read both `arc_id:` frontmatter (T-1849 canonical, T-1850 migrated) AND legacy `arc:<slug>` tag. |
| [test_arcs_pages_tokens](/docs/generated/tests-unit-test_arcs_pages_tokens) | uses_by | T-2027 (arc-007 S5a): Arcs section templates use semantic --wt-* tokens. |
| [test_arcs_routes](/docs/generated/tests-unit-test_arcs_routes) | uses_by | Unit tests for /arcs and /arcs/<id> routes (T-1662) — Flask test_client pins index empty/populated, detail in-progress with three-question check, detail closed without check, 404 for unregistered, missing-task graceful render. |
| [test_breadcrumb](/docs/generated/tests-unit-test_breadcrumb) | uses_by | T-2009 (arc-007 S2b): path-derived breadcrumb guard. |
| [test_bulk_actions](/docs/generated/tests-unit-test_bulk_actions) | uses_by | T-2018 (arc-007 S4e/S6c): bulk multi-select + floating action bar. |
| [test_cockpit_activity](/docs/generated/tests-unit-test_cockpit_activity) | uses_by | T-2020 (arc-007 S6d): cockpit live activity feed — recent commits via htmx poll. |
| [test_cockpit_density_spacing](/docs/generated/tests-unit-test_cockpit_density_spacing) | uses_by | T-2029: cockpit spacing scales with the density axis; exclusions are honoured. |
| [test_cockpit_inline_tokens](/docs/generated/tests-unit-test_cockpit_inline_tokens) | uses_by | T-2024 (arc-007 S3a2): cockpit inline-style hexes use per-palette semantic tokens. |
| [test_cockpit_knowledge_counts](/docs/generated/tests-unit-test_cockpit_knowledge_counts) | uses_by | T-2022: Cockpit System Health Knowledge counts come from live helpers, not a missing scan key. |
| [test_cockpit_status_pills](/docs/generated/tests-unit-test_cockpit_status_pills) | uses_by | T-2023 (arc-007 S3a): cockpit status colours use per-palette semantic tokens. |
| [test_cockpit_traceability](/docs/generated/tests-unit-test_cockpit_traceability) | uses_by | T-2021: Cockpit System Health renders traceability as a percentage, not a raw dict. |
| [test_command_palette](/docs/generated/tests-unit-test_command_palette) | uses_by | T-2012 (arc-007 S6a): command-palette jump-list contract (server side). |
| [test_fabric_coupling_token](/docs/generated/tests-unit-test_fabric_coupling_token) | uses_by | T-2028 (arc-007 S5b): fabric coupling-note uses --wt-danger; categorical map stays fixed. |
| [test_file_route_extensions](/docs/generated/tests-unit-test_file_route_extensions) | uses_by | T-1764: Regression tests for the /file/<path> route. |
| [test_filter_chips](/docs/generated/tests-unit-test_filter_chips) | uses_by | T-2016 (arc-007 S4c): active-filter chips on the tasks board. |
| [test_kanban_drag](/docs/generated/tests-unit-test_kanban_drag) | uses_by | T-2019 (arc-007 S4d): drag-to-reorder kanban — cross-column status change. |
| [test_nav_layout_polish](/docs/generated/tests-unit-test_nav_layout_polish) | uses_by | T-2033: arc-007 nav-layout polish — static guards for the sidebar/rail fixes. |
| [test_nav_layouts](/docs/generated/tests-unit-test_nav_layouts) | uses_by | T-2011 (arc-007 S2d): nav-layout axis contract. |
| [test_nav_subsections](/docs/generated/tests-unit-test_nav_subsections) | uses_by | T-2008 (arc-007 S2a): nav IA regroup + Govern sub-grouping guard. |
| [test_orchestrator_parallel_view](/docs/generated/tests-unit-test_orchestrator_parallel_view) | uses_by | T-2342 (arc-011 M1 §5) — /orchestrator/parallel view. |
| [test_orchestrator_workflow_coverage](/docs/generated/tests-unit-test_orchestrator_workflow_coverage) | uses_by | T-1799: /orchestrator surfaces Workflow coverage panel. |
| [test_pins](/docs/generated/tests-unit-test_pins) | uses_by | T-2010 (arc-007 S2c): pinned-pages model contract. |
| [test_review_paused_resolve](/docs/generated/tests-unit-test_review_paused_resolve) | uses_by | Tests for /review/T-XXX paused-dispatch panel + resolve endpoint. |
| [test_reviewer_audit_blueprint](/docs/generated/tests-unit-test_reviewer_audit_blueprint) | uses_by | Unit tests for /reviewer/audit Watchtower route (T-1486). |
| [test_session_cookie_port](/docs/generated/tests-unit-test_session_cookie_port) | called_by | T-3065: the session cookie is named for the port actually being served. |
| [test_settings_nav_link](/docs/generated/tests-unit-test_settings_nav_link) | uses_by | T-2032: the top-bar action cluster has a gear link to the settings/appearance page. |
| [test_shortcuts_overlay](/docs/generated/tests-unit-test_shortcuts_overlay) | uses_by | T-2013 (arc-007 S6b): keyboard-shortcuts overlay — server-side presence. |
| [test_t3068_unknown_cost](/docs/generated/tests-unit-test_t3068_unknown_cost) | called_by | T-3068: unmeasured blast radius must not price as cheapest. |
| [test_task_panel](/docs/generated/tests-unit-test_task_panel) | uses_by | T-2015 (arc-007 S4a): slide-in dockable task side-panel — server-side guarantees. |
| [test_task_panel_edit](/docs/generated/tests-unit-test_task_panel_edit) | uses_by | T-2017 (arc-007 S4b): inline-edit task meta cells in the side panel. |
| [test_theme_toggle_contrast](/docs/generated/tests-unit-test_theme_toggle_contrast) | uses_by | T-2031: the dark-mode toggle uses --wt-text (palette text token), not --pico-color. |
| [test_api_overlay](/docs/generated/tests-web-test_api_overlay) | uses_by | T-2629: /api/overlay endpoint contract — status codes + payload shape. |
| [test_api_version_latest](/docs/generated/tests-web-test_api_version_latest) | uses_by | T-2624: /api/version bare-id resolution — `?id=` alone serves the latest version. |
| [test_approvals_blocked_arcs](/docs/generated/tests-web-test_approvals_blocked_arcs) | called_by | T-2986: an arc that meets the closure threshold but is not reviewable says so. |
| [test_approvals_blocked_arcs](/docs/generated/tests-web-test_approvals_blocked_arcs) | uses_by | T-2986: an arc that meets the closure threshold but is not reviewable says so. |
| [test_approvals_origin](/docs/generated/tests-web-test_approvals_origin) | called_by | T-3078: /approvals must not assert an agent asked when none did. |
| [test_approvals_origin](/docs/generated/tests-web-test_approvals_origin) | uses_by | T-3078: /approvals must not assert an agent asked when none did. |
| [test_designer_api_uuid_identity](/docs/generated/tests-web-test_designer_api_uuid_identity) | uses_by | T-2573 (T-2571 S1): immutable workflow uuid in the designer store. |
| [test_designer_landing](/docs/generated/tests-web-test_designer_landing) | uses_by | T-2589: /designer corpus landing page — server truth first, editor at /designer/app. |
| [test_designer_overlay](/docs/generated/tests-web-test_designer_overlay) | uses_by | T-2630: /designer/overlay wrapper page + landing overlay-link contract. |
| [test_designer_registry_claim](/docs/generated/tests-web-test_designer_registry_claim) | uses_by | T-2575 (T-2571 S6): claim — bind a ghost uuid to a live project. |
| [test_designer_registry_ghosts](/docs/generated/tests-web-test_designer_registry_ghosts) | uses_by | T-2574 (T-2571 S2): pending-ref registry — ghost capture at save. |
| [test_inception_decide_hardening](/docs/generated/tests-web-test_inception_decide_hardening) | uses_by | T-1470: Watchtower /inception/decide hardens against side-effect failure. |
| [test_onboarding_maps_reachable](/docs/generated/tests-web-test_onboarding_maps_reachable) | called_by | T-2981: the onboarding maps stay reachable from the UI the seeds send operators to. |
| [test_onboarding_maps_reachable](/docs/generated/tests-web-test_onboarding_maps_reachable) | uses_by | T-2981: the onboarding maps stay reachable from the UI the seeds send operators to. |
| [test_costs](/docs/generated/web-test_costs) | uses_by | 24 pytest tests for costs blueprint — _fmt_tokens, _parse_session, _load_all_sessions, route (T-810) |
| [test_inception_close_card](/docs/generated/tests-unit-test_inception_close_card) | called_by | T-3180: a decided inception must have a way to close it. |
| [test_inception_close_card](/docs/generated/tests-unit-test_inception_close_card) | uses_by | T-3180: a decided inception must have a way to close it. |
| [approvals](/docs/generated/web-blueprints-approvals) | called_by | Watchtower approvals blueprint: human review queue — lists tasks with unchecked Human ACs, supports checkbox toggling. |
| [smoke_test](/docs/generated/web-smoke_test) | called_by | Watchtower smoke test — runtime route discovery + content validation. |
| [smoke_test](/docs/generated/web-smoke_test) | uses_by | Watchtower smoke test — runtime route discovery + content validation. |
| [test_app](/docs/generated/web-test_app) | called_by | Test suite for the Watchtower web UI. |
| [test_app](/docs/generated/web-test_app) | uses_by | Test suite for the Watchtower web UI. |
| [wsgi](/docs/generated/web-wsgi) | called_by | WSGI entry point for Watchtower. |
| [wsgi](/docs/generated/web-wsgi) | uses_by | WSGI entry point for Watchtower. |

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
