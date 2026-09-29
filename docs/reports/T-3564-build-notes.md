# T-3564 build notes

Files changed: `web/blueprints/arcs.py` (helpers `_arc_story`, `_task_overview`, `_arc_sections`, `_source_ref`; one ordered `sections` list feeds both the quick-link bar and the section wrappers), `web/templates/arc_detail.html` (quick-link bar under the title; Purpose; Task overview with status counts, the old stats strip, and open-task list; story sections; existing sections wrapped with anchors), `tests/web/test_t3564_arc_page_layout.py` (2 tests).

Order: title → quick links → Purpose → Task overview → success criteria / context / decisions / open questions / non-goals / history / evidence → BVP → reports → constituent table → completion check or arc closed. Story sections and Purpose are omitted entirely when the fields are absent.

Tests: new file 2 passed. Existing arc tests (test_arcs_routes, test_arc_display_helper, test_arcs_membership_cached, test_approvals_blocked_arcs) pass. `tests/unit/test_arcs_pages_tokens.py::test_only_neutral_fallback_hexes_remain` fails on `#2a7`/`#c33` in arc_detail.html; those are T-3429 reviewer badges, and it fails identically with my changes stashed (pre-existing, not touched).

Done: watchtower restart + `current` (ok), `vendor self` + `--check` (clean). Not done: the independent render review AC (left to the parent) and any browser/screenshot check; the page is ~55s/request under the test client so I did not run playwright arc tests.
