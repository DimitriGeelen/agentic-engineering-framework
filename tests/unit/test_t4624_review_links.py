"""T-4624 (G-123): review-page links reach the operator as full clickable URLs.

The operator opened /review/T-4607 and Step 1 read
``$(cd /opt/999-Agentic-Engineering-Framework && bin/fw watchtower url)/designer``.
The render layer now resolves that shell form, and backticked Watchtower route
paths, to full own-origin anchors. The strings below are copied verbatim from
T-4607's Human criterion as it stood before 5e54fc4b1.
"""
from __future__ import annotations

import contextlib
import io

import pytest

with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
    from web.app import app

from web.blueprints.tasks import _parse_ac_body, _render_md_inline
from web.shared import (
    link_route_code_spans,
    render_markdown_safe,
    resolve_watchtower_refs,
)

BASE = "http://192.168.10.107:3000"

T4607_STEP1 = (
    "1. Open `$(cd /opt/999-Agentic-Engineering-Framework && bin/fw watchtower url)/designer` "
    "in a browser (hard-refresh)"
)
T4607_IF_NOT = (
    "**If not:** note which map shows the placeholder and run "
    "`curl -s -o /dev/null -w '%{http_code} %{content_type}\\n' "
    "\"$(bin/fw watchtower url)/api/thumb?id=<id>\"`"
)
T4607_AC_BODY = "\n".join([
    "  **Steps:**",
    "  " + T4607_STEP1,
    "  2. Click **Open project**",
    "  3. Look at the map cards (e.g. aef-task-lifecycle, aef-audit-cron)",
    "  **Expected:** each card shows a small diagram picture, not the grid ▦ placeholder",
    "  " + T4607_IF_NOT,
])


@pytest.fixture
def req():
    with app.test_request_context("/review/T-4607", base_url=BASE):
        yield


# --- shell form --------------------------------------------------------------

@pytest.mark.parametrize("src", [
    "$(cd /opt/999-Agentic-Engineering-Framework && bin/fw watchtower url)/designer",
    "$(bin/fw watchtower url)/designer",
    "$(fw watchtower url)/designer",
    "$(.agentic-framework/bin/fw watchtower url)/designer",
    "$( cd /x &&  bin/fw  watchtower  url )/designer",
])
def test_resolve_shell_form_every_spelling(src):
    assert resolve_watchtower_refs(src, BASE) == f"{BASE}/designer"


def test_resolve_leaves_fenced_code_alone():
    src = "```\ncurl \"$(bin/fw watchtower url)/x\"\n```\nOpen $(bin/fw watchtower url)/designer"
    out = resolve_watchtower_refs(src, BASE)
    assert "```\ncurl \"$(bin/fw watchtower url)/x\"\n```" in out
    assert out.endswith(f"Open {BASE}/designer")


def test_t4607_step1_renders_full_url_anchor(req):
    steps, _expected, if_not = _parse_ac_body(T4607_AC_BODY)
    assert f'<a href="{BASE}/designer"><code>{BASE}/designer</code></a>' in steps[0]
    assert "$(" not in steps[0]
    assert "watchtower url" not in steps[0]


def test_t4607_if_not_resolves_inside_command(req):
    _steps, _expected, if_not = _parse_ac_body(T4607_AC_BODY)
    assert f"{BASE}/api/thumb?id=" in if_not
    assert "watchtower url" not in if_not


def test_non_backticked_shell_form_becomes_anchor(req):
    html = _render_md_inline("Open $(bin/fw watchtower url)/designer now")
    assert f'href="{BASE}/designer"' in html


def test_recommendation_renderer_resolves_shell_form(req):
    html = render_markdown_safe("See `$(bin/fw watchtower url)/review/T-4607` for the card.")
    assert f'<a href="{BASE}/review/T-4607">' in html


# --- backticked route paths ----------------------------------------------------

@pytest.mark.parametrize("path", ["/designer", "/review/T-1", "/api/thumb?id=x", "/approvals"])
def test_backticked_route_becomes_full_url_anchor(req, path):
    html = _render_md_inline(f"Open `{path}` in a browser")
    url = BASE + path.replace("&", "&amp;")
    assert f'<a href="{url}"><code>{url}</code></a>' in html


@pytest.mark.parametrize("path", ["/opt/999-Agentic-Engineering-Framework", "/tmp/x.log", "/no-such-route-t4624"])
def test_backticked_non_route_stays_code(req, path):
    html = _render_md_inline(f"Look at `{path}`")
    assert f"<code>{path}</code>" in html
    assert "<a " not in html


def test_route_code_spans_need_app_context():
    # Outside an app context the route table is unknown: leave the HTML alone.
    html = "<code>/designer</code>"
    assert link_route_code_spans(html, BASE) == html


def test_external_base_url_comes_from_request(req):
    from web.shared import external_base_url
    assert external_base_url() == BASE


# --- validator allowlist (lib/review_link_validator.py) --------------------------

import importlib.util  # noqa: E402
import os  # noqa: E402

_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_spec = importlib.util.spec_from_file_location(
    "review_link_validator_t4624", os.path.join(_ROOT, "lib", "review_link_validator.py"))
V = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(V)


def _human(steps: str, rec: str = "") -> str:
    body = (
        "---\nid: T-9999\nworkflow_type: build\n---\n"
        "## Acceptance Criteria\n### Agent\n- [x] done\n### Human\n"
        "- [ ] [REVIEW] check it\n  **Steps:**\n" + steps + "\n"
        "  **Expected:** fine\n  **If not:** say so\n\n"
        "## Verification\ncurl -sf \"$(bin/fw watchtower url)/designer\" >/dev/null\n"
    )
    if rec:
        body += "\n## Recommendation\n" + rec + "\n"
    return body


def _blocks(body):
    return [m for lvl, m in V.detect_homework_patterns(body) if lvl == "block"]


@pytest.mark.parametrize("steps", [
    # the shell form — T-4607, verbatim
    "  " + T4607_STEP1,
    "  1. Open $(bin/fw watchtower url)/designer",
    "  1. Open `$(fw watchtower url)/review/T-1`",
    # T-2138's three phrasings
    "  1. Open these (URL from `bin/fw watchtower url`): http://x/",
    "  1. Open (base from `bin/fw watchtower url`)/foo",
    "  1. Open each (Watchtower URL from cli output) at http://x/",
    # other spellings of the same homework
    "  1. Run bin/fw watchtower url and append the path",
    # bare paths
    "     - `/designer`",
    "  1. Open `/designer` in a browser",
    "  1. Open /review/T-4607 and click Approve",
    "  1. Go to [the queue](/approvals)",
])
def test_every_spelling_blocks(steps):
    assert _blocks(_human(steps)), steps


def test_t4607_if_not_command_blocks():
    assert _blocks(_human("  1. Open http://192.168.10.107:3000/designer\n  " + T4607_IF_NOT))


def test_recommendation_is_in_scope():
    body = _human("  1. Open http://192.168.10.107:3000/designer",
                  rec="**Recommendation:** GO\n**Rationale:** see `/review/T-1`")
    assert any("/review/T-1" in m for m in _blocks(body))


@pytest.mark.parametrize("steps", [
    "  1. Open http://192.168.10.107:3000/designer in a browser",
    "  1. Open `http://192.168.10.107:3000/api/thumb?id=x`",
    "  1. Read `/opt/999-Agentic-Engineering-Framework/docs/reports/x.md` and `/tmp/out.log`",
    "  1. Read `docs/reports/T-1-x.md` and `.tasks/active/T-1-x.md`",
    "  1. Run `cd /opt/999-Agentic-Engineering-Framework && bin/fw doctor`",
    "  1. Example only:\n```\nOpen $(bin/fw watchtower url)/designer\n```",
])
def test_literal_urls_and_file_paths_pass(steps):
    assert _blocks(_human(steps)) == [], steps


def test_verification_section_is_out_of_scope():
    # _human() always puts $(bin/fw watchtower url) in ## Verification.
    assert _blocks(_human("  1. Open http://192.168.10.107:3000/designer")) == []


def test_template_comments_are_out_of_scope():
    steps = "<!-- example: Open `/designer` via $(bin/fw watchtower url)/x -->\n  1. Open http://h:3000/x"
    assert _blocks(_human(steps)) == []


def test_main_links_only_enforce_blocks_without_probe(tmp_path):
    f = tmp_path / "T-9999-x.md"
    f.write_text(_human("  " + T4607_STEP1))
    assert V.main([str(f), BASE, "--enforce", "--links-only"]) == 2
    f.write_text(_human("  1. Open http://192.168.10.107:3000/designer"))
    assert V.main([str(f), BASE, "--enforce", "--links-only"]) == 0
