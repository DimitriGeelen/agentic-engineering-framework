"""T-3564: arc detail page order — quick links, Purpose, Task overview, story, BVP.

Runs against the real arc store (continuous-run has the T-3563 story fields) and,
for the no-story case, a temp arc registered by monkeypatching `_read_arc`.
"""

import re
import sys

import pytest

sys.path.insert(0, ".")


@pytest.fixture()
def client():
    from web.app import app

    app.config["TESTING"] = True
    return app.test_client()


def _ids(html):
    return set(re.findall(r'<section[^>]*\sid="([^"]+)"', html))


def _links(html):
    nav = re.search(r'<nav class="arc-quicklinks".*?</nav>', html, re.S)
    assert nav, "quick-link bar missing"
    return nav.group(0), re.findall(r'href="#([^"]+)"', nav.group(0))


def test_story_arc_layout(client):
    html = client.get("/arcs/continuous-run").get_data(as_text=True)
    nav, targets = _links(html)
    assert targets
    all_ids = set(re.findall(r'\sid="([^"]+)"', html))
    for t in targets:
        assert t in all_ids, f"dead quick link #{t}"
    # every rendered section is linked
    for sid in _ids(html):
        assert sid in targets, f"section #{sid} has no quick link"
    # quick links are the first element under the title
    assert html.index('class="arc-quicklinks"') < html.index('id="purpose"')
    assert "hx-" not in nav
    for sid in ("purpose", "task-overview", "success-criteria", "decisions",
                "open-questions", "non-goals", "history", "evidence"):
        assert sid in targets
    # order
    assert html.index('id="purpose"') < html.index('id="task-overview"')
    assert html.index('id="task-overview"') < html.index('id="bvp-signals"')
    assert html.index('id="task-overview"') < html.index('id="constituent-tasks"')
    assert "done" in html[html.index('id="task-overview"'):html.index('id="success-criteria"')]


def test_arc_without_story_fields(client, monkeypatch):
    from web.blueprints import arcs

    real = arcs._read_arc("continuous-run")
    bare = {k: v for k, v in real.items()
            if k not in ("purpose", "objective", "success_criteria", "context", "decisions",
                         "open_questions", "non_goals", "history", "evidence", "story_review")}
    monkeypatch.setattr(arcs, "_read_arc", lambda _id: dict(bare))
    html = client.get("/arcs/continuous-run").get_data(as_text=True)
    _, targets = _links(html)
    assert "purpose" not in targets and 'id="purpose"' not in html
    for sid in ("success-criteria", "context", "decisions", "open-questions",
                "non-goals", "history", "evidence"):
        assert sid not in targets
        assert f'id="{sid}"' not in html
    assert "task-overview" in targets
    all_ids = set(re.findall(r'\sid="([^"]+)"', html))
    for t in targets:
        assert t in all_ids
    for sid in _ids(html):
        assert sid in targets
