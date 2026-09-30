"""T-3590: the /approvals batch button must never offer, or close, a task that is not ready.

Live, the page offered "Complete 2 Ready Tasks" for T-2200 and T-2202: both started-work,
each with an unticked [REVIEW] Human criterion sitting under an intervening
`## Status: COMPLETED ...` heading. Admission counted that block (T-3139 scoping);
the ready test used `_parse_acceptance_criteria`, which stops at the `## ` heading, saw
zero Human criteria, and called "all ticked" vacuously true.

Fixtures only. No real task is read, written or completed: `_read_active_task`,
`get_all_task_metadata`, `_get_body_cached` and `subprocess.run` are all substituted.
"""

import subprocess
import sys

import pytest

sys.path.insert(0, ".")

from web.shared import count_human_acs, is_ready_for_batch_completion  # noqa: E402

# Shape of T-2200 / T-2202: Human block after an intervening `## ` heading, unticked.
T2200_SHAPE = """# T-9001: fixture

## Acceptance Criteria

### Agent
- [x] Worker dispatched

## Status: COMPLETED 2026-06-09

### Human
- [ ] [REVIEW] Operator confirms the consumer works
  **Steps:** 1. look
  **Expected:** fine
  **If not:** note it

## Verification
true
"""

# Genuinely ready control: every Human criterion ticked, including one past a `## ` heading.
READY = """# T-9002: fixture

## Acceptance Criteria

### Agent
- [x] Built

### Human
- [x] [REVIEW] Looks right

## Measured Behaviour

### Human
- [x] [RUBBER-STAMP] Second block, ticked
"""

NO_HUMAN = """# T-9003: fixture

## Acceptance Criteria

### Agent
- [x] Built

<!--
### Human
- [ ] [REVIEW] template stub inside a comment
-->
"""


def test_t2200_shape_is_not_ready_even_if_partial_complete():
    assert count_human_acs(T2200_SHAPE) == (1, 1)
    assert not is_ready_for_batch_completion("work-completed", T2200_SHAPE)
    assert not is_ready_for_batch_completion("started-work", T2200_SHAPE)


def test_the_old_parser_is_what_was_wrong():
    """Pins the root cause: the display parser sees no Human criteria on this shape."""
    from web.blueprints.tasks import _parse_acceptance_criteria

    human = [a for a in _parse_acceptance_criteria(T2200_SHAPE) if a["section"] == "human"]
    assert human == []  # vacuous "all checked" — must never feed a decision


def test_ready_control_is_ready():
    assert count_human_acs(READY) == (2, 0)
    assert is_ready_for_batch_completion("work-completed", READY)


def test_started_work_is_never_ready():
    """Batch runs with --skip-acceptance-criteria; unfinished work must not qualify."""
    assert not is_ready_for_batch_completion("started-work", READY)
    assert not is_ready_for_batch_completion("captured", READY)


def test_no_human_criterion_is_not_ready():
    assert count_human_acs(NO_HUMAN) == (0, 0)
    assert not is_ready_for_batch_completion("work-completed", NO_HUMAN)


def test_unchecked_count_agrees_with_admission_predicate():
    from web.shared import count_unchecked_human_acs

    for body in (T2200_SHAPE, READY, NO_HUMAN):
        assert count_human_acs(body)[1] == count_unchecked_human_acs(body)


def test_approvals_makes_no_decision_with_the_display_parser():
    """grep-level guard: the only use of _parse_acceptance_criteria on /approvals is
    the display list in _load_pending_human_acs."""
    src = open("web/blueprints/approvals.py").read()
    uses = [ln.strip() for ln in src.splitlines()
            if "_parse_acceptance_criteria(" in ln and not ln.strip().startswith("#")]
    assert uses == ["all_acs = _parse_acceptance_criteria(body)"]
    assert 'ac["checked"]' not in src


# ── fixture store for the route-level tests ──────────────────────────────────

FIXTURES = {
    "T-9001": ({"id": "T-9001", "name": "t2200 shape", "status": "work-completed"}, T2200_SHAPE),
    "T-9002": ({"id": "T-9002", "name": "ready", "status": "work-completed"}, READY),
    "T-9004": ({"id": "T-9004", "name": "ready but started", "status": "started-work"}, READY),
}


@pytest.fixture()
def fake_store(monkeypatch):
    import web.blueprints.approvals as ap

    meta = [dict(fm, _location="active", _path=f"/fixture/{tid}.md") for tid, (fm, _) in FIXTURES.items()]
    monkeypatch.setattr(ap, "get_all_task_metadata", lambda: meta)
    monkeypatch.setattr(ap, "_get_body_cached", lambda p: FIXTURES[p.rsplit("/", 1)[1][:-3]][1])
    monkeypatch.setattr(ap, "_read_active_task", lambda tid: FIXTURES.get(tid))

    calls = []
    real_run = subprocess.run

    def fake_run(argv, **kw):
        # Only `fw task update` is faked (and recorded); read-only helpers the page
        # render shells out to (git describe, …) run for real.
        if isinstance(argv, list) and str(argv[0]).endswith("/fw"):
            assert argv[1:3] == ["task", "update"]
            calls.append(argv[3])
            return subprocess.CompletedProcess(argv, 0, "", "")
        return real_run(argv, **kw)

    monkeypatch.setattr(subprocess, "run", fake_run)
    return calls


def test_loader_and_ready_count_offer_only_the_ready_task(fake_store):
    import web.blueprints.approvals as ap

    assert [t["task_id"] for t in ap._load_batch_ready_tasks()] == ["T-9002"]


@pytest.fixture()
def client():
    from web.app import app

    app.config["TESTING"] = True
    c = app.test_client()
    with c.session_transaction() as s:
        s["_csrf_token"] = "tok"
    return c


def _post(client, ids):
    from werkzeug.datastructures import MultiDict

    data = MultiDict([("_csrf_token", "tok")] + [("task_id", i) for i in ids])
    return client.post("/api/approvals/complete-batch", data=data).get_data(as_text=True)


def test_post_completes_only_posted_ready_ids_and_refuses_the_rest(fake_store, client):
    html = _post(client, ["T-9001", "T-9002", "T-9004", "T-0000", "bogus"])
    assert fake_store == ["T-9002"]
    assert "Completed 1 task(s): T-9002" in html
    for tid in ("T-9001", "T-9004", "T-0000", "bogus"):
        assert f"{tid}: refused" in html


def test_post_with_no_ids_completes_nothing(fake_store, client):
    html = _post(client, [])
    assert fake_store == []
    assert "Refused: no task ids posted" in html


def test_post_never_reaches_beyond_the_posted_list(fake_store, client):
    """T-9002 is ready, but it was not posted — it must not be touched."""
    _post(client, ["T-9001"])
    assert fake_store == []


def test_page_offers_only_the_ready_task_and_no_card_complete_for_t2200_shape(fake_store, client):
    """Rendered /approvals: the batch form posts exactly the ready id; the T-2200-shaped
    card (listed as pending) carries no Complete button and names its hidden criterion."""
    import re

    html = client.get("/approvals/content").get_data(as_text=True)
    form = re.search(r'<form hx-post="/api/approvals/complete-batch".*?</form>', html, re.S)
    assert form, "batch form missing although T-9002 is ready"
    assert re.findall(r'name="task_id" value="([^"]+)"', form.group(0)) == ["T-9002"]
    assert "Complete 1 Ready Task" in form.group(0)

    card = re.search(r'T-9001.*?(?=class="human-ac-group"|</body>|\Z)', html, re.S)
    assert card, "T-2200-shaped task is no longer listed as pending review"
    assert "/api/task/T-9001/complete" not in html
    assert "1 unticked Human criterion sit" in html
