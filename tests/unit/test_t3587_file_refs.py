"""T-3587: evidence references on review pages must be links, or visibly dead.

Every shape runs against a FIXTURE project in tmp_path (PROJECT_ROOT is
monkeypatched), never against the live corpus, so a report being added or
renamed cannot turn these red (T-3326).

Shapes: exact path, dead path, brace group (prefixed, bare, multi), bare
filename (unique / none / several), `path:NNN`, allowlist, underscore paths,
the /file line anchors, and every surface that renders Recommendation/Evidence.
Each positive has a negative control beside it.
"""
from __future__ import annotations

import http.server
import json
import os
import re
import subprocess
import threading
from pathlib import Path

import pytest

import web.shared as shared
from web.shared import VIEWABLE_DIR_PREFIXES, is_viewable_path, render_markdown_safe

REPO = Path(__file__).resolve().parents[2]

FIXTURE_FILES = [
    "docs/reports/T-9001-review-openai.md",
    "docs/reports/T-9001-review-zai.md",
    "docs/reports/T-9002-unique-report.md",
    "lib/task_pair_acd.sh",
    "lib/alpha.py",
    "web/alpha.py",
    "agents/one/AGENT.md",
    "agents/two/AGENT.md",
    "tests/unit/test_fixture_thing.py",
    ".agentic-framework/lib/vendored.sh",
    "README.md",
]


@pytest.fixture
def proj(tmp_path, monkeypatch):
    for rel in FIXTURE_FILES:
        p = tmp_path / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text("\n".join(f"line {i}" for i in range(1, 50)) + "\n")
    monkeypatch.setattr(shared, "PROJECT_ROOT", tmp_path)
    monkeypatch.setitem(shared._BASENAME_INDEX, "built", 0.0)
    monkeypatch.setitem(shared._BASENAME_INDEX, "index", {})
    yield tmp_path
    shared._BASENAME_INDEX["built"] = 0.0


def hrefs(html):
    return re.findall(r'href="(/file/[^"]*)"', html)


# ── exact paths and dead paths ────────────────────────────────────────────────

def test_existing_path_links(proj):
    assert hrefs(render_markdown_safe("see docs/reports/T-9002-unique-report.md")) == [
        "/file/docs/reports/T-9002-unique-report.md"]


def test_dead_path_is_marked_not_linked(proj):
    out = render_markdown_safe("see lib/does_not_exist.sh here")
    assert hrefs(out) == []
    assert 'class="file-ref-dead"' in out
    assert "lib/does_not_exist.sh" in out
    assert re.search(r'class="file-ref-dead" title="Not found:[^"]+"', out)


def test_live_and_dead_refs_render_differently(proj):
    live = render_markdown_safe("lib/alpha.py")
    dead = render_markdown_safe("lib/omega.py")
    assert "<a " in live and "file-ref-dead" not in live
    assert "<a " not in dead and "file-ref-dead" in dead


def test_unserved_path_is_marked(proj):
    out = render_markdown_safe(".agentic-framework/lib/vendored.sh")
    assert hrefs(out) == []
    assert 'class="file-ref-unserved"' in out


# ── brace groups ──────────────────────────────────────────────────────────────

def test_brace_group_links_each_member_and_stays_readable(proj):
    out = render_markdown_safe("Reviews: docs/reports/T-9001-review-{openai,zai}.md (RED)")
    assert hrefs(out) == ["/file/docs/reports/T-9001-review-openai.md",
                          "/file/docs/reports/T-9001-review-zai.md"]
    text = re.sub(r"<[^>]+>", "", out)
    assert "docs/reports/T-9001-review-{openai,zai}.md" in text


def test_brace_group_member_that_does_not_exist_is_marked(proj):
    out = render_markdown_safe("docs/reports/T-9001-review-{openai,gemini}.md")
    assert hrefs(out) == ["/file/docs/reports/T-9001-review-openai.md"]
    assert out.count("file-ref-dead") == 1


def test_bare_brace_group_resolves_by_basename(proj):
    out = render_markdown_safe("T-9001-review-{openai,zai}.md")
    assert hrefs(out) == ["/file/docs/reports/T-9001-review-openai.md",
                          "/file/docs/reports/T-9001-review-zai.md"]


def test_multi_group_expands_the_product(proj):
    out = render_markdown_safe("{lib,web}/alpha.py")
    assert hrefs(out) == ["/file/lib/alpha.py", "/file/web/alpha.py"]


# ── bare filenames ────────────────────────────────────────────────────────────

def test_bare_filename_with_one_match_links(proj):
    assert hrefs(render_markdown_safe("see T-9002-unique-report.md")) == [
        "/file/docs/reports/T-9002-unique-report.md"]


def test_bare_filename_with_no_match_is_marked_dead(proj):
    out = render_markdown_safe("see T-9999-nothing.md")
    assert hrefs(out) == [] and "file-ref-dead" in out


def test_bare_filename_with_several_matches_is_marked_ambiguous(proj):
    out = render_markdown_safe("see AGENT.md")
    assert hrefs(out) == []
    assert 'class="file-ref-ambiguous"' in out
    assert "agents/one/AGENT.md" in out and "agents/two/AGENT.md" in out  # in the title


def test_path_tail_is_not_mistaken_for_a_bare_name(proj):
    # control: `somewhere/T-9002-unique-report.md` must not link its tail
    out = render_markdown_safe("somewhere/T-9002-unique-report.md")
    assert hrefs(out) == []


def test_url_text_is_not_rewritten(proj):
    out = render_markdown_safe("https://example.com/docs/reports/T-9002-unique-report.md")
    assert hrefs(out) == []
    assert "file-ref-dead" not in out


def test_absent_extensionless_root_word_is_not_marked(proj):
    out = render_markdown_safe("CHANGELOG entries follow conventional commits")
    assert "file-ref" not in out


# ── line references ───────────────────────────────────────────────────────────

def test_path_colon_line_links_to_line_anchor(proj):
    out = render_markdown_safe("see lib/alpha.py:12 and lib/alpha.py:3-9")
    assert hrefs(out) == ["/file/lib/alpha.py#L12", "/file/lib/alpha.py#L3"]
    assert ">lib/alpha.py:12</a>" in out


def test_underscore_path_is_one_token_not_emphasis(proj):
    out = render_markdown_safe("see lib/task_pair_acd.sh and _real emphasis_")
    assert hrefs(out) == ["/file/lib/task_pair_acd.sh"]
    assert "<em>real emphasis</em>" in out  # control: emphasis still works


def test_backticked_path_links_inside_code(proj):
    out = render_markdown_safe("`lib/task_pair_acd.sh`")
    assert '<code><a href="/file/lib/task_pair_acd.sh">lib/task_pair_acd.sh</a></code>' in out


def test_code_block_marks_nothing_dead(proj):
    out = shared._auto_link_files("<pre><code>lib/alpha.py nothing_here.py</code></pre>")
    assert hrefs(out) == ["/file/lib/alpha.py"]
    assert "file-ref-dead" not in out


def test_no_rewrite_inside_tags_or_anchors(proj):
    for html in ['<a href="lib/alpha.py">x</a>', '<a href="/file/lib/alpha.py">lib/alpha.py</a>',
                 '<span title="lib/omega.py">x</span>']:
        assert shared._auto_link_files(html) == html


# ── allowlist: one list, the renderer never emits a link the route refuses ────

@pytest.mark.parametrize("prefix", ["tests/", "web/", "bin/", "policy/", "lib/", "agents/", "docs/reports/"])
def test_allowlist_covers_cited_directories(prefix):
    assert prefix in VIEWABLE_DIR_PREFIXES
    assert is_viewable_path(prefix + "x.py")


def test_route_and_renderer_share_the_one_allowlist():
    docs_src = (REPO / "web/blueprints/docs.py").read_text()
    assert "is_viewable_path(filepath)" in docs_src
    assert "VIEWABLE_DIR_PREFIXES = (" not in docs_src


def test_every_rendered_link_is_served():
    """Live-repo parity: render refs to real files; every emitted href is 200."""
    from web.app import app
    c = app.test_client()
    src = ("web/shared.py:600 tests/unit/test_t3587_file_refs.py bin/fw "
           "policy/review-backends.yaml agents/audit/audit.sh docs/reports/ lib/review.sh")
    out = render_markdown_safe(src)
    links = hrefs(out)
    assert len(links) >= 5
    for h in links:
        assert c.get(h.split("#")[0]).status_code == 200, h


# ── /file line anchors ────────────────────────────────────────────────────────

def test_file_view_has_line_anchors():
    from web.app import app
    body = app.test_client().get("/file/web/shared.py").get_data(as_text=True)
    n = len((REPO / "web/shared.py").read_text().split("\n"))
    assert 'id="L1"' in body and f'id="L{n - 1}"' in body
    assert body.count('class="line"') >= n - 1
    assert 'id="L-' not in body  # pygments' default id shape is rewritten


def test_file_view_anchor_for_bats_and_shell():
    from web.app import app
    body = app.test_client().get("/file/lib/review.sh").get_data(as_text=True)
    assert 'id="L10"' in body


# ── every Recommendation/Evidence surface goes through the shared linker ─────

SURFACES = ["review.py", "tasks.py", "arcs.py", "inception.py", "approvals.py", "core.py", "docs.py"]


def test_no_surface_renders_markdown_without_the_linker():
    for name in SURFACES:
        src = (REPO / "web/blueprints" / name).read_text()
        calls = len(re.findall(r"markdown2\.markdown\(", src))
        linked = len(re.findall(r"_auto_link_files\(|render_markdown_safe\(", src))
        assert calls == 0 or linked >= 1, f"{name}: markdown2 without the linker"


def test_recommendation_and_evidence_are_rendered_not_raw():
    """No template prints a Recommendation/Rationale/Evidence value as raw text.

    The one sanctioned raw use is a <textarea> pre-fill (`*_text`, `*_hint`):
    a form field must hold the source, not HTML.
    """
    expr = re.compile(r"\{\{([^}]*)\}\}")
    subject = re.compile(r"\b(rec_(rationale|evidence|other)\w*|t\.recommendation\w*|\w*evidence_html|\w*rationale_html)\b")
    offenders = []
    for p in (REPO / "web/templates").glob("*.html"):
        for line in p.read_text().splitlines():
            for e in expr.findall(line):
                m = subject.search(e)
                if not m:
                    continue
                name = m.group(1)
                if name.endswith(("_text", "_hint")) and "<textarea" in line:
                    continue
                if not name.endswith("_html"):
                    offenders.append(f"{p.name}: {e.strip()}")
    assert not offenders, offenders


def test_approvals_renders_recommendation_markdown():
    tpl = (REPO / "web/templates/_approvals_content.html").read_text()
    assert "t.recommendation_html | safe" in tpl
    assert "{{ t.recommendation }}" not in tpl
    assert '"recommendation_html": render_markdown_safe(' in (REPO / "web/blueprints/approvals.py").read_text()


def test_review_page_loads_the_marker_styles():
    assert "css/file-refs.css" in (REPO / "web/templates/review.html").read_text()
    assert "css/file-refs.css" in (REPO / "web/templates/base.html").read_text()
    css = (REPO / "web/static/css/file-refs.css").read_text()
    for cls in ("file-ref-dead", "file-ref-ambiguous", "file-ref-unserved"):
        assert "." + cls in css


# ── URLs printed outside Watchtower come from the triple file ────────────────

class _Identity(http.server.BaseHTTPRequestHandler):
    root = ""

    def do_GET(self):
        body = json.dumps({"service": "watchtower", "project_root": self.root}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):  # noqa: A002
        pass


def test_watchtower_url_follows_triple_file_on_non_default_port(tmp_path):
    """`_watchtower_url` (used by fw task review, review-batch, and via
    `fw watchtower url` by handover) returns the triple-file URL of a
    non-default port — nothing substitutes :3000."""
    root = tmp_path / "proj"
    (root / ".context/working").mkdir(parents=True)
    _Identity.root = str(root)
    srv = http.server.HTTPServer(("127.0.0.1", 0), _Identity)
    port = srv.server_address[1]
    assert port != 3000
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    try:
        w = root / ".context/working"
        (w / "watchtower.pid").write_text(str(os.getpid()))
        (w / "watchtower.port").write_text(str(port))
        (w / "watchtower.url").write_text(f"http://127.0.0.1:{port}")
        script = (f'export PROJECT_ROOT="{root}" FRAMEWORK_ROOT="{REPO}"; '
                  f'unset WATCHTOWER_URL; source "{REPO}/lib/config.sh" 2>/dev/null; '
                  f'_watchtower_our_root() {{ echo "{root}"; }}; '
                  f'source "{REPO}/lib/watchtower.sh"; '
                  f'_watchtower_our_root() {{ echo "{root}"; }}; _watchtower_url; '
                  f'fw_task_review_url T-9001; fw_task_review_url T-9002')
        (root / ".tasks/active").mkdir(parents=True)
        (root / ".tasks/active/T-9002-x.md").write_text("---\nworkflow_type: inception\n---\n")
        r = subprocess.run(["bash", "-c", script], capture_output=True, text=True, timeout=30)
        base = f"http://127.0.0.1:{port}"
        assert r.stdout.split() == [base, f"{base}/review/T-9001", f"{base}/inception/T-9002"], r.stderr
    finally:
        srv.shutdown()


def test_emitters_do_not_hard_code_a_host_or_port():
    for rel in ("agents/handover/handover.sh", "lib/reviewer/judge_cli.py", "lib/review.sh"):
        src = (REPO / rel).read_text()
        live = [l for l in src.splitlines()
                if re.search(r"https?://(localhost|127\.0\.0\.1|[\d.]+):\d+", l)
                and not l.lstrip().startswith("#")]
        assert not live, f"{rel}: {live}"
    assert "watchtower url" in (REPO / "agents/handover/handover.sh").read_text()
    assert "watchtower.url" in (REPO / "lib/reviewer/judge_cli.py").read_text()
