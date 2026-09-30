"""T-3591: /tasks/<id> must not offer "Complete Task" while a Human criterion is unticked.

Live, /tasks/T-2200 and /tasks/T-2202 showed the button: each has an unticked [REVIEW]
Human criterion under an intervening `## Status: COMPLETED ...` heading, which
`_parse_acceptance_criteria` never reaches, so "all checked" was true. Same root cause
as T-3590 on another surface.

Fixtures only: PROJECT_ROOT is pointed at a tmp dir holding fixture task files. Nothing
is posted, so no task is completed.
"""

import sys

import pytest

sys.path.insert(0, ".")

from tests.web.test_t3590_batch_ready_predicate import READY, T2200_SHAPE  # noqa: E402

BUTTON = 'hx-post="/api/task/{tid}/complete"'


def _task_file(tid, status, body):
    return f"---\nid: {tid}\nname: fixture\nstatus: {status}\nworkflow_type: build\nowner: agent\n---\n\n{body}"


@pytest.fixture()
def client(tmp_path, monkeypatch):
    import web.blueprints.tasks as tb
    from web.app import app

    active = tmp_path / ".tasks" / "active"
    active.mkdir(parents=True)
    (tmp_path / ".tasks" / "completed").mkdir()
    (active / "T-9001-t2200-shape.md").write_text(_task_file("T-9001", "started-work", T2200_SHAPE))
    (active / "T-9002-ready.md").write_text(_task_file("T-9002", "started-work", READY))
    monkeypatch.setattr(tb, "PROJECT_ROOT", tmp_path)

    app.config["TESTING"] = True
    return app.test_client()


def _page(client, tid):
    resp = client.get(f"/tasks/{tid}")
    assert resp.status_code == 200
    return resp.get_data(as_text=True)


def test_t2200_shape_shows_no_complete_button(client):
    assert BUTTON.format(tid="T-9001") not in _page(client, "T-9001")


def test_all_ticked_control_shows_complete_button(client):
    assert BUTTON.format(tid="T-9002") in _page(client, "T-9002")


def test_display_parser_alone_would_have_offered_it():
    """Pins the root cause: the display parser sees only ticked criteria on this shape."""
    from web.blueprints.tasks import _parse_acceptance_criteria

    items = _parse_acceptance_criteria(T2200_SHAPE)
    assert items and all(ac["checked"] for ac in items)


def test_route_does_not_decide_with_display_parser_alone():
    import inspect

    import web.blueprints.tasks as tb

    src = inspect.getsource(tb.task_detail)
    assert "count_human_acs(task_content)" in src
