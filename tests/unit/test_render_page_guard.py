"""T-1899: render_page() runtime guard refuses templates that extend base.html.

The fragment convention is documented in render_page's docstring; this test
pins it as runtime behaviour. Origin: T-1898 — three templates violated the
convention silently, producing double-render on /arcs/arc-005 until a user
noticed. The guard fires `RuntimeError` the next time the violating page
loads in dev, with an actionable message naming the template, the convention,
and where to look.
"""

import os
from pathlib import Path

import pytest
from flask import Flask
from jinja2 import DictLoader

_REPO = Path(__file__).resolve().parents[2]
os.environ.setdefault("PROJECT_ROOT", str(_REPO))

from web import shared as _shared  # noqa: E402

_shared.PROJECT_ROOT = _REPO

from web.shared import render_page  # noqa: E402


@pytest.fixture(autouse=True)
def _pin_project_root():
    """T-1995: re-pin web.shared.PROJECT_ROOT per test (same fix as
    test_render_artefact_paths). Reload-based tests elsewhere leave the module
    global pointing at a deleted tmp dir; the import-time pin on line 23 runs
    once at collection and cannot recover. Restores the prior value on teardown.
    """
    saved = _shared.PROJECT_ROOT
    _shared.PROJECT_ROOT = _REPO
    yield
    _shared.PROJECT_ROOT = saved


def _app_with_templates(templates: dict) -> Flask:
    """Build a minimal Flask app whose jinja loader serves the given dict.

    `_wrapper.html` is always provided so the non-violating path can complete
    its render. Other framework globals (csrf_token, fw_version, etc.) used
    by base.html are stubbed to keep this an isolated unit test.
    """
    app = Flask(__name__)
    base_templates = {
        "_wrapper.html": "{% include _content_template %}",
        # Stub base.html so a violating template that resolves through the
        # double-extends chain wouldn't actually crash on missing macros —
        # we want the guard to fire, not unrelated Jinja errors.
        "base.html": "<html><nav>chrome</nav>{% block content %}{% endblock %}</html>",
    }
    base_templates.update(templates)
    app.jinja_env.loader = DictLoader(base_templates)
    # Stubs for globals base.html / _wrapper.html may reference indirectly.
    app.jinja_env.globals.setdefault("csrf_token", lambda: "stub")
    app.jinja_env.globals.setdefault("fw_version", "test")
    app.jinja_env.globals.setdefault("project_name", "test")
    return app


def test_guard_raises_on_extends_base_html():
    """Template that begins with `{% extends "base.html" %}` is refused."""
    app = _app_with_templates({
        "bad_page.html": '{% extends "base.html" %}\n{% block content %}<p>x</p>{% endblock %}',
    })
    with app.test_request_context("/"):
        with pytest.raises(RuntimeError, match=r"extends.*base\.html"):
            render_page("bad_page.html")


def test_guard_message_names_the_template():
    """Error message includes the template name so the dev knows where to fix."""
    app = _app_with_templates({
        "named_bad.html": '{% extends "base.html" %}\n{% block content %}{% endblock %}',
    })
    with app.test_request_context("/"):
        try:
            render_page("named_bad.html")
        except RuntimeError as exc:
            assert "named_bad.html" in str(exc)
            assert "fragment" in str(exc).lower()
            return
    pytest.fail("guard did not raise")


def test_guard_accepts_fragment_template():
    """Template that starts as a fragment renders normally."""
    app = _app_with_templates({
        "good_page.html": "<article>fragment body</article>",
    })
    with app.test_request_context("/"):
        out = render_page("good_page.html")
        # No RuntimeError fired; content rendered through the wrapper.
        assert "fragment body" in out


def test_guard_skips_jinja_comments_before_extends():
    """A Jinja comment block before extends still triggers — extends is still first substantive line."""
    app = _app_with_templates({
        "comment_then_bad.html": "{# preamble #}\n{% extends \"base.html\" %}\n{% block content %}{% endblock %}",
    })
    with app.test_request_context("/"):
        with pytest.raises(RuntimeError, match=r"extends.*base\.html"):
            render_page("comment_then_bad.html")


def test_guard_silent_on_template_with_leading_html_content():
    """Template that starts with HTML (no extends at all) is a valid fragment."""
    app = _app_with_templates({
        "html_first.html": "<div><h1>title</h1></div>",
    })
    with app.test_request_context("/"):
        out = render_page("html_first.html")
        assert "title" in out


def test_guard_skipped_on_htmx_request():
    """HX-Request bypasses render_page wrapping → no guard check fires.

    The htmx path returns the bare fragment, so even a violating template
    cannot cause double-render via this code path. We don't want the guard
    to break legitimate htmx swaps.
    """
    app = _app_with_templates({
        "would_be_bad.html": '{% extends "base.html" %}\n{% block content %}<p>x</p>{% endblock %}',
    })
    with app.test_request_context("/", headers={"HX-Request": "true"}):
        out = render_page("would_be_bad.html")
        # HX path renders the template through render_template directly; with
        # our DictLoader's stub base.html that emits one nav. The point is:
        # the guard did NOT raise.
        assert "chrome" in out or "x" in out
