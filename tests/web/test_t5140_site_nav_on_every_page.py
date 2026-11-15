"""T-5140: every page that extends base.html draws the full site nav on a full load.

/bvp, /reviewer/audit, /reviewer/overrides and /escalation-drift render base.html
templates through flask.render_template, not web.shared.render_page, and drew the
site-nav bar with none of its groups. Found while gathering T-5130's click-through
evidence: T-5130 made in-app navigation to /bvp a full load.
"""
import os
import re
from pathlib import Path

import pytest

os.environ.setdefault("PROJECT_ROOT", str(Path(__file__).resolve().parents[2]))

from web.app import app  # noqa: E402
from web.shared import NAV_GROUPS  # noqa: E402

GROUP_TITLES = [name for name, _ in NAV_GROUPS]


def _groups_in(html):
    return re.findall(r'<summary title="([^"]+)"', html)


@pytest.mark.parametrize("path", ["/bvp", "/reviewer/audit", "/reviewer/overrides",
                                  "/escalation-drift"])
def test_full_load_draws_every_nav_group(path):
    resp = app.test_client().get(path)
    assert resp.status_code == 200, (path, resp.status_code)
    shown = _groups_in(resp.get_data(as_text=True))
    assert shown == GROUP_TITLES, (path, shown)


def test_control_a_render_page_route_draws_them_too():
    html = app.test_client().get("/fabric").get_data(as_text=True)
    assert _groups_in(html) == GROUP_TITLES


def test_a_view_can_still_pass_its_own_nav():
    from flask import render_template_string
    with app.test_request_context("/"):
        out = render_template_string("{{ nav_groups|length }}", nav_groups=[("only", [])])
    assert out == "1"
