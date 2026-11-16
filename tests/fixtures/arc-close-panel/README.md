# arc-close-panel fixture (T-5168)

A minimal project for the arc close-recommendation panel tests
(`tests/playwright/test_arc_close_recommendation_panel.py`, two tests in
`tests/playwright/test_arc_review_route.py`).

`tests/playwright/arc_fixture.py` copies it into a temporary directory as
`.context/arcs/` and `.tasks/{active,completed}/` and serves that copy from a
second Watchtower on its own port. Nothing here is read by the framework itself:
the files live outside `.context/` and `.tasks/` on purpose.

| File | State it gives the tests |
|---|---|
| `arcs/fixture-close-panel.yaml` | in-progress arc with an anchor task and a close-out task |
| `tasks/completed/T-900001-*.md` | anchor inception, recommendation GO (must NOT be shown as the close verdict, T-4320) |
| `tasks/active/T-900002-*.md` | close-out task, recommendation CLOSE with rationale and evidence |
