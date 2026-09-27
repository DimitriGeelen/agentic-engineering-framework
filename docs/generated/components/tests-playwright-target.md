# target

> The one place the Playwright suite decides what it is talking to (T-2784).

**Type:** script | **Subsystem:** tests-playwright | **Location:** `tests/playwright/target.py`

## What It Does

## Used By (75)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [conftest](/docs/generated/tests-playwright-conftest) | uses_by | Playwright test fixtures for Watchtower (T-969) |
| [test_api_config](/docs/generated/tests-playwright-test_api_config) | uses_by | Playwright tests for /config page content (T-1035). |
| [test_api_cron_jobs](/docs/generated/tests-playwright-test_api_cron_jobs) | uses_by | Playwright tests for cron job API endpoints (T-1033). |
| [test_api_health](/docs/generated/tests-playwright-test_api_health) | uses_by | Playwright tests for health endpoints (T-1033). |
| [test_api_index](/docs/generated/tests-playwright-test_api_index) | uses_by | Playwright tests for /api/v1 index endpoint (T-1034). |
| [test_api_quality](/docs/generated/tests-playwright-test_api_quality) | uses_by | Playwright tests for quality API endpoints (T-1030). |
| [test_api_search](/docs/generated/tests-playwright-test_api_search) | uses_by | Playwright tests for /api/v1/search endpoint (T-1034). |
| [test_approvals](/docs/generated/tests-playwright-test_approvals) | uses_by | Playwright tests for Approvals page (T-981) |
| [test_approvals_content_tokens](/docs/generated/tests-playwright-test_approvals_content_tokens) | uses_by | Playwright guard for T-2026 (arc-007 S3c2) — approvals content inline styles re-theme. |
| [test_approvals_style_tokens](/docs/generated/tests-playwright-test_approvals_style_tokens) | uses_by | Playwright guard for T-2025 (arc-007 S3c) — approvals stylesheet re-themes per palette. |
| [test_arc_badge](/docs/generated/tests-playwright-test_arc_badge) | uses_by | Playwright tests for T-1909 arc-membership badge. |
| [test_arc_page_parity](/docs/generated/tests-playwright-test_arc_page_parity) | uses_by | Playwright tests for T-1910 — arc page parity (Slices 1+2+4 of T-1905). |
| [test_arcs_pages_tokens](/docs/generated/tests-playwright-test_arcs_pages_tokens) | uses_by | Playwright guard for T-2027 (arc-007 S5a) — Arcs badges re-theme per palette. |
| [test_ask](/docs/generated/tests-playwright-test_ask) | uses_by | Playwright tests for /api/v1/ask endpoint (T-1025). |
| [test_assumptions](/docs/generated/tests-playwright-test_assumptions) | uses_by | Playwright tests for Assumptions page (T-1020). |
| [test_badge_contrast](/docs/generated/tests-playwright-test_badge_contrast) | uses_by | T-1970: Pin badge contrast on /arcs surfaces against WCAG AA (4.5:1). |
| [test_breadcrumb](/docs/generated/tests-playwright-test_breadcrumb) | uses_by | Playwright guard for T-2009 (arc-007 S2b) — breadcrumb is htmx-fresh. |
| [test_bulk_actions](/docs/generated/tests-playwright-test_bulk_actions) | uses_by | Playwright guard for T-2018 (arc-007 S4e/S6c) — bulk multi-select, end-to-end. |
| [test_cockpit](/docs/generated/tests-playwright-test_cockpit) | uses_by | Playwright tests for Cockpit dashboard (T-1018). |
| [test_cockpit_activity](/docs/generated/tests-playwright-test_cockpit_activity) | uses_by | Playwright guard for T-2020 (arc-007 S6d) — cockpit live activity feed. |
| [test_cockpit_density_spacing](/docs/generated/tests-playwright-test_cockpit_density_spacing) | uses_by | Playwright guard for T-2029 — cockpit spacing responds to the density axis. |
| [test_cockpit_inline_tokens](/docs/generated/tests-playwright-test_cockpit_inline_tokens) | uses_by | Playwright guard for T-2024 (arc-007 S3a2) — cockpit inline-style colours re-theme. |
| [test_cockpit_knowledge_counts](/docs/generated/tests-playwright-test_cockpit_knowledge_counts) | uses_by | Playwright guard for T-2022 — cockpit System Health Knowledge counts. |
| [test_cockpit_status_pills](/docs/generated/tests-playwright-test_cockpit_status_pills) | uses_by | Playwright guard for T-2023 (arc-007 S3a) — cockpit status pills re-theme per palette. |
| [test_cockpit_traceability](/docs/generated/tests-playwright-test_cockpit_traceability) | uses_by | Playwright guard for T-2021 — cockpit System Health traceability render. |
| [test_command_palette](/docs/generated/tests-playwright-test_command_palette) | uses_by | Playwright guard for T-2012 (arc-007 S6a) — ⌘K command palette, end-to-end. |
| [test_config](/docs/generated/tests-playwright-test_config) | uses_by | Playwright tests for Config page (T-981) |
| [test_core](/docs/generated/tests-playwright-test_core) | uses_by | Playwright tests for Watchtower landing page (T-986) |
| [test_costs](/docs/generated/tests-playwright-test_costs) | uses_by | Playwright tests for Costs page (T-981) |
| [test_cron](/docs/generated/tests-playwright-test_cron) | uses_by | Playwright tests for Cron Registry page (T-986) |
| [test_directives](/docs/generated/tests-playwright-test_directives) | uses_by | Playwright tests for Constitutional Directives page (T-990) |
| [test_discoveries](/docs/generated/tests-playwright-test_discoveries) | uses_by | Playwright tests for Discoveries dashboard (T-987) |
| [test_discovery](/docs/generated/tests-playwright-test_discovery) | uses_by | Playwright tests for Discovery pages — learnings, decisions, gaps (T-986) |
| [test_docs](/docs/generated/tests-playwright-test_docs) | uses_by | Playwright tests for Generated Docs page (T-987) |
| [test_docs_detail](/docs/generated/tests-playwright-test_docs_detail) | uses_by | Playwright tests for /docs/generated/<card_name> detail page (T-1026). |
| [test_enforcement](/docs/generated/tests-playwright-test_enforcement) | uses_by | Playwright tests for Enforcement dashboard (T-986) |
| [test_fabric](/docs/generated/tests-playwright-test_fabric) | uses_by | Playwright tests for Fabric pages (T-970) |
| [test_fabric_coupling_token](/docs/generated/tests-playwright-test_fabric_coupling_token) | uses_by | Playwright guard for T-2028 (arc-007 S5b) — fabric coupling-note danger token re-themes. |
| [test_fabric_graph_cold_load](/docs/generated/tests-playwright-test_fabric_graph_cold_load) | uses_by | T-1770 — /fabric/graph cold-load regression test. |
| [test_file_viewer](/docs/generated/tests-playwright-test_file_viewer) | uses_by | Playwright tests for /file/<path> viewer endpoint (T-1025). |
| [test_filter_chips](/docs/generated/tests-playwright-test_filter_chips) | uses_by | Playwright guard for T-2016 (arc-007 S4c) — active-filter chips, end-to-end. |
| [test_graduation](/docs/generated/tests-playwright-test_graduation) | uses_by | Playwright tests for Graduation page (T-989) |
| [test_health](/docs/generated/tests-playwright-test_health) | uses_by | Playwright tests for /health endpoint (T-1008) |
| [test_inception](/docs/generated/tests-playwright-test_inception) | uses_by | Playwright tests for Inception pages (T-970) |
| [test_inception_page](/docs/generated/tests-playwright-test_inception_page) | uses_by | Playwright tests for Inception detail page (T-1019). |
| [test_interactions](/docs/generated/tests-playwright-test_interactions) | uses_by | Playwright interaction tests — dark mode, search, task filtering (T-1015) |
| [test_kanban_drag](/docs/generated/tests-playwright-test_kanban_drag) | uses_by | Playwright guard for T-2019 (arc-007 S4d) — drag-to-reorder kanban, end-to-end. |
| [test_metrics](/docs/generated/tests-playwright-test_metrics) | uses_by | Playwright tests for Metrics page (T-986) |
| [test_nav_layouts](/docs/generated/tests-playwright-test_nav_layouts) | uses_by | Playwright guard for T-2011 (arc-007 S2d) — nav layouts, end-to-end. |
| [test_nav_subsections](/docs/generated/tests-playwright-test_nav_subsections) | uses_by | Playwright guard for T-2008 (arc-007 S2a) — Govern dropdown is subsectioned. |
| [test_navigation](/docs/generated/tests-playwright-test_navigation) | uses_by | Playwright tests for Watchtower navigation (T-1003) |
| [test_patterns](/docs/generated/tests-playwright-test_patterns) | uses_by | Playwright tests for Patterns page (T-989) |
| [test_pins](/docs/generated/tests-playwright-test_pins) | uses_by | Playwright guard for T-2010 (arc-007 S2c) — pinned-pages model, end-to-end. |
| [test_project](/docs/generated/tests-playwright-test_project) | uses_by | Playwright tests for Project Documentation page (T-1019). |
| [test_quality](/docs/generated/tests-playwright-test_quality) | uses_by | Playwright tests for Quality Gate page (T-986) |
| [test_review](/docs/generated/tests-playwright-test_review) | uses_by | Playwright tests for Review page (T-970, T-982) |
| [test_review_acs](/docs/generated/tests-playwright-test_review_acs) | uses_by | Playwright tests for /review/<task_id>/acs fragment endpoint (T-1026). |
| [test_review_csrf](/docs/generated/tests-playwright-test_review_csrf) | uses_by | Playwright regression for /review/<task_id> CSRF wiring (T-1453). |
| [test_review_htmx_target_inheritance](/docs/generated/tests-playwright-test_review_htmx_target_inheritance) | uses_by | T-2135: regression net for the htmx-target-inheritance class. |
| [test_review_page](/docs/generated/tests-playwright-test_review_page) | uses_by | Playwright tests for Task Review page (T-1020). |
| [test_risks](/docs/generated/tests-playwright-test_risks) | uses_by | Playwright tests for Risk Register / Concerns page (T-986) |
| [test_search](/docs/generated/tests-playwright-test_search) | uses_by | Playwright tests for Search page (T-990) |
| [test_search_extended](/docs/generated/tests-playwright-test_search_extended) | uses_by | Playwright tests for search sub-pages (T-1025). |
| [test_sessions](/docs/generated/tests-playwright-test_sessions) | uses_by | Playwright tests for Sessions page (T-983) |
| [test_settings](/docs/generated/tests-playwright-test_settings) | uses_by | Playwright tests for Settings page (T-987) |
| [test_settings_nav_link](/docs/generated/tests-playwright-test_settings_nav_link) | uses_by | Playwright guard for T-2032 — the settings gear is visible and navigates to the page. |
| [test_shortcuts_overlay](/docs/generated/tests-playwright-test_shortcuts_overlay) | uses_by | Playwright guard for T-2013 (arc-007 S6b) — ? shortcuts overlay, end-to-end. |
| [test_smoke](/docs/generated/tests-playwright-test_smoke) | uses_by | Playwright smoke tests — all major routes render (T-969) |
| [test_task_detail](/docs/generated/tests-playwright-test_task_detail) | uses_by | Playwright tests for task detail page (T-1019). |
| [test_task_panel](/docs/generated/tests-playwright-test_task_panel) | uses_by | Playwright guard for T-2015 (arc-007 S4a) — slide-in dockable task panel, end-to-end. |
| [test_task_panel_edit](/docs/generated/tests-playwright-test_task_panel_edit) | uses_by | Playwright guard for T-2017 (arc-007 S4b) — inline-edit in the side panel, end-to-end. |
| [test_tasks](/docs/generated/tests-playwright-test_tasks) | uses_by | Playwright tests for Tasks pages (T-970) |
| [test_terminal](/docs/generated/tests-playwright-test_terminal) | uses_by | Playwright tests for Terminal page (T-970) |
| [test_theme_toggle_contrast](/docs/generated/tests-playwright-test_theme_toggle_contrast) | uses_by | Playwright regression guard for T-2031 — dark-mode toggle stays visible on light palettes. |
| [test_timeline](/docs/generated/tests-playwright-test_timeline) | uses_by | Playwright tests for Timeline page (T-981) |

---
*Auto-generated from Component Fabric. Card: `tests-playwright-target.yaml`*
*Last verified: 2026-08-04*
