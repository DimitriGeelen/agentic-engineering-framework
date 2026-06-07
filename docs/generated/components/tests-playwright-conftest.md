# conftest

> Playwright test fixtures for Watchtower (T-969)

**Type:** script | **Subsystem:** testing | **Location:** `tests/playwright/conftest.py`

## What It Does

Check if already running on test port

## Used By (43)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_accessibility](/docs/generated/tests-playwright-test_accessibility) | called_by | Playwright accessibility tests for Watchtower (T-1059) |
| [test_api_approvals](/docs/generated/tests-playwright-test_api_approvals) | called_by | Playwright tests for approvals API endpoints (T-1031). |
| [test_api_ask_stream](/docs/generated/tests-playwright-test_api_ask_stream) | called_by | Playwright tests for /ask/stream SSE endpoint (T-1041). |
| [test_api_config](/docs/generated/tests-playwright-test_api_config) | called_by | Playwright tests for /config page content (T-1035). |
| [test_api_context_capture](/docs/generated/tests-playwright-test_api_context_capture) | called_by | Playwright tests for context capture API endpoints (T-1030). |
| [test_api_cron_jobs](/docs/generated/tests-playwright-test_api_cron_jobs) | called_by | Playwright tests for cron job API endpoints (T-1033). |
| [test_api_fabric_source](/docs/generated/tests-playwright-test_api_fabric_source) | called_by | Playwright tests for fabric file APIs (T-1025). |
| [test_api_healing](/docs/generated/tests-playwright-test_api_healing) | called_by | Playwright tests for /api/healing/<task_id> endpoint (T-1026). |
| [test_api_health](/docs/generated/tests-playwright-test_api_health) | called_by | Playwright tests for health endpoints (T-1033). |
| [test_api_inception](/docs/generated/tests-playwright-test_api_inception) | called_by | Playwright tests for inception API endpoints (T-1031). |
| [test_api_index](/docs/generated/tests-playwright-test_api_index) | called_by | Playwright tests for /api/v1 index endpoint (T-1034). |
| [test_api_json_schema](/docs/generated/tests-playwright-test_api_json_schema) | called_by | Playwright JSON API schema validation tests (T-1055) |
| [test_api_quality](/docs/generated/tests-playwright-test_api_quality) | called_by | Playwright tests for quality API endpoints (T-1030). |
| [test_api_scan](/docs/generated/tests-playwright-test_api_scan) | called_by | Playwright tests for scan API endpoints (T-1029). |
| [test_api_scan_actions](/docs/generated/tests-playwright-test_api_scan_actions) | called_by | Playwright tests for scan action endpoints (T-1041). |
| [test_api_search](/docs/generated/tests-playwright-test_api_search) | called_by | Playwright tests for /api/v1/search endpoint (T-1034). |
| [test_api_session_init](/docs/generated/tests-playwright-test_api_session_init) | called_by | Playwright tests for session init API (T-1029). |
| [test_api_settings](/docs/generated/tests-playwright-test_api_settings) | called_by | Playwright tests for settings API endpoints (T-1035). |
| [test_api_task_complete](/docs/generated/tests-playwright-test_api_task_complete) | called_by | Playwright tests for task complete API (T-1037). |
| [test_api_task_happy](/docs/generated/tests-playwright-test_api_task_happy) | called_by | Playwright tests for task API happy paths (T-1039). |
| [test_api_task_inline](/docs/generated/tests-playwright-test_api_task_inline) | called_by | Playwright tests for task inline edit API endpoints (T-1029). |
| [test_api_task_mutations](/docs/generated/tests-playwright-test_api_task_mutations) | called_by | Playwright tests for POST task API error handling (T-1026). |
| [test_api_termlink](/docs/generated/tests-playwright-test_api_termlink) | called_by | Playwright tests for TermLink sessions API (T-1025). |
| [test_api_timeline_detail](/docs/generated/tests-playwright-test_api_timeline_detail) | called_by | Playwright tests for timeline task detail API (T-1025). |
| [test_ask](/docs/generated/tests-playwright-test_ask) | called_by | Playwright tests for /api/v1/ask endpoint (T-1025). |
| [test_assumptions](/docs/generated/tests-playwright-test_assumptions) | called_by | Playwright tests for Assumptions page (T-1020). |
| [test_cockpit](/docs/generated/tests-playwright-test_cockpit) | called_by | Playwright tests for Cockpit dashboard (T-1018). |
| [test_docs_count](/docs/generated/tests-playwright-test_docs_count) | called_by | Playwright tests for docs generated page coverage (T-1054) |
| [test_docs_detail](/docs/generated/tests-playwright-test_docs_detail) | called_by | Playwright tests for /docs/generated/<card_name> detail page (T-1026). |
| [test_fabric_detail](/docs/generated/tests-playwright-test_fabric_detail) | called_by | Playwright tests for fabric component detail page (T-1041). |
| [test_file_viewer](/docs/generated/tests-playwright-test_file_viewer) | called_by | Playwright tests for /file/<path> viewer endpoint (T-1025). |
| [test_inception_page](/docs/generated/tests-playwright-test_inception_page) | called_by | Playwright tests for Inception detail page (T-1019). |
| [test_nav_links](/docs/generated/tests-playwright-test_nav_links) | called_by | Playwright tests for navigation link validation (T-1057) |
| [test_project](/docs/generated/tests-playwright-test_project) | called_by | Playwright tests for Project Documentation page (T-1019). |
| [test_response_times](/docs/generated/tests-playwright-test_response_times) | called_by | Playwright response time regression tests (T-1051) |
| [test_review_acs](/docs/generated/tests-playwright-test_review_acs) | called_by | Playwright tests for /review/<task_id>/acs fragment endpoint (T-1026). |
| [test_review_page](/docs/generated/tests-playwright-test_review_page) | called_by | Playwright tests for Task Review page (T-1020). |
| [test_search_extended](/docs/generated/tests-playwright-test_search_extended) | called_by | Playwright tests for search sub-pages (T-1025). |
| [test_settings_models](/docs/generated/tests-playwright-test_settings_models) | called_by | Playwright tests for settings models endpoint (T-1025). |
| [test_task_detail](/docs/generated/tests-playwright-test_task_detail) | called_by | Playwright tests for task detail page (T-1019). |
| [test_task_detail_enhanced](/docs/generated/tests-playwright-test_task_detail_enhanced) | called_by | Playwright tests for enhanced task detail page (T-1056) |
| [test_arcs_renders_without_constituent_field](/docs/generated/tests-playwright-test_arcs_renders_without_constituent_field) | called_by | Playwright DOM-content assertion (per T-1575/T-971) pinning the /arcs/<slug> render contract for arcs that omit the legacy `constituent_tasks:` frontmatter field. Fixture writes a synthetic arc YAML to .context/arcs/, yields, removes on teardown — Watchtower reads filesystem live, no restart needed.  Two tests: - test_arcs_detail_renders_without_constituent_tasks: synthetic   field-less arc → 200 + no "Traceback" + no "Internal Server Error"   + arc name renders. - test_legacy_arc_with_constituent_tasks_still_renders: regression   guard pinning legacy /arcs/arc-grooming still renders.  Re-classifies T-1851's first Human [REVIEW] AC to Agent. The deprecation-banner reading-quality AC remains Human [REVIEW] — doc tone is genuinely subjective. |
| [test_landing_arc_cards](/docs/generated/tests-playwright-test_landing_arc_cards) | called_by | Playwright DOM-content assertion (per T-1575/T-971) pinning the landing-page arc-cards render contract and the /tasks?arc=<id> filter contract after the T-1850 arc_id migration. Two tests: - test_landing_arc_cards_show_nonzero_counts: every in-progress arc card   on / renders with a non-zero task count (arc-005 ≥14); no zero-count   cards (the migration-blindness regression signal). - test_tasks_filter_by_arc_returns_members: /tasks?arc=arc-grooming lists   ≥4 known arc-grooming task IDs.  Re-classifies T-1879's Human [REVIEW] AC to Agent. Origin: T-1879 migration-blindness #2 sweep — 5 sites read arc:<slug> tag only after the migration stripped them, surfacing zero arc memberships on the landing page. |

## Related

### Tasks
- T-969: Playwright test infrastructure — tests/playwright/ + fw test playwright + conftest.py (T-968 Phase 1)

---
*Auto-generated from Component Fabric. Card: `tests-playwright-conftest.yaml`*
*Last verified: 2026-04-06*
