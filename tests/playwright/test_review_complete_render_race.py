"""T-2081 / T-2082: /review/<id>/acs polling endpoint must not re-render the
Complete button for a task that has already been work-completed.

Origin: human reported the Complete button on /review/T-XXX briefly reappears
~1-2s after a successful click. RCA in
`docs/reports/T-2081-review-complete-button-render-race.md`:

1. `#ac-container` carries `hx-trigger="every 5s"` (web/templates/review.html:592).
2. The polling GET `/review/<id>/acs` re-renders `_review_acs.html` from disk.
3. T-1575 closed this race for INCEPTIONS via a `decision_recorded` guard, but
   the non-inception sibling case (Complete button on build tasks) was missed —
   L-441 class.
4. After Complete fires: POST swap clears the button → poll fires within 1-5s →
   fragment re-renders with `all_checked && total_count > 0 && workflow_type !=
   'inception'` → Complete button HTML returns → swap → user sees it "come back".

The fix (T-2082) adds a `task_completed` flag to `review_acs_fragment` and a
`{% elif task_completed %}` branch in `_review_acs.html`. This test asserts the
contract:

    GET /review/<id>/acs for a work-completed build task
        MUST NOT contain "Complete Task" button HTML
        MUST contain the "✓ Task completed" panel

Reproduction seed: T-2079 was completed earlier in the same session and is the
canonical fixture (work-completed build task with all Human ACs ticked). If the
fixture changes — e.g. T-2079 is purged — replace with any work-completed build
task by adjusting `COMPLETED_TASK_ID`.
"""

import re

# Pinned fixture: T-2079 (a work-completed build task that exposed the bug
# in the originating session). Replace if the fixture is purged.
COMPLETED_TASK_ID = "T-2079"


def test_polling_endpoint_no_complete_button_on_completed_task(page, base_url):
    """The exact T-2081 contract: GET /review/<id>/acs on a completed task
    must not re-render the Complete Task button."""
    resp = page.request.get(f"{base_url}/review/{COMPLETED_TASK_ID}/acs")
    assert resp.status == 200, f"polling endpoint returned {resp.status}"
    body = resp.text()
    assert "Complete Task" not in body, (
        f"/review/{COMPLETED_TASK_ID}/acs returned 'Complete Task' button text "
        f"on a work-completed task — the T-2081 render race has regressed. "
        f"See docs/reports/T-2081-review-complete-button-render-race.md."
    )
    # The form action itself must be absent (defence-in-depth — the button text
    # might be moved to a different element label in a future redesign).
    assert "/api/task/" not in body or "/complete" not in body.split("/api/task/")[1][:120], (
        f"/review/{COMPLETED_TASK_ID}/acs still wires the POST .../complete form "
        f"on a work-completed task."
    )


def test_polling_endpoint_renders_task_completed_marker(page, base_url):
    """Symmetric positive guard: the new `task_completed` branch must render the
    "✓ Task completed" panel so the human sees the completion state instead of
    an empty container."""
    resp = page.request.get(f"{base_url}/review/{COMPLETED_TASK_ID}/acs")
    assert resp.status == 200
    body = resp.text()
    # The panel id is stable contract (T-2082) — assert on id, not text rhythm.
    assert 'id="task-completed-marker"' in body, (
        f"/review/{COMPLETED_TASK_ID}/acs should render the task-completed-marker "
        f"panel from the T-2082 guard branch."
    )
    # And the user-visible label sits in the same fragment.
    assert "Task completed" in body
