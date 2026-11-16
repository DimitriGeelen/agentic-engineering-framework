# test_arc_close_recommendation_panel

> T-1960: /arcs/<slug>/close — Agent Recommendation panel renders above form.

**Type:** script | **Subsystem:** tests-playwright | **Location:** `tests/playwright/test_arc_close_recommendation_panel.py`

## What It Does

T-5168: these tests run against the fixture project (tests/fixtures/arc-close-panel,
served by conftest's `arc_fixture_server`), not the live corpus. The panel needs an
open arc whose close-out or anchor task holds a CLOSE or KEEP-OPEN recommendation
(since T-4320 an anchor's GO / NO-GO / DEFER is not shown as one). The live corpus
often has no such arc, and the tests then skipped. `close_rec_arc` is that arc.

---
*Auto-generated from Component Fabric. Card: `tests-playwright-test_arc_close_recommendation_panel.yaml`*
*Last verified: 2026-05-21*
