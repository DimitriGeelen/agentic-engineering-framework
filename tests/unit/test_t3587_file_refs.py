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
    # round 2 (render review AMBER)
    "001-Vision.md",
    ".claude/settings.json",
    "lib/ts/tsconfig.json",
    "docs/reports/T-9003-twin.md",
    "docs/plans/T-9003-twin.md",
    ".agentic-framework/docs/T-9004-vendored-only.md",
    "docs/adr/0001-thing.md",
    "docs/runbooks/restart.md",
    "agents/context/checkpoint.sh",
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
    out = render_markdown_safe("see T-9003-twin.md")
    assert hrefs(out) == []
    assert 'class="file-ref-ambiguous"' in out
    assert "docs/plans/T-9003-twin.md" in out and "docs/reports/T-9003-twin.md" in out  # title


def test_generic_bare_name_with_several_matches_is_plain(proj):
    # control for the above: AGENT.md is generic, so it is not judged at all
    assert "file-ref" not in render_markdown_safe("see AGENT.md") and hrefs(
        render_markdown_safe("see AGENT.md")) == []


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


# ── round 2: render review AMBER (docs/reports/T-3587-render-review.md) ──────

# Item 1 — source-viewer palette follows the theme.

def test_file_view_palette_is_scoped_per_theme():
    from web.app import app
    body = app.test_client().get("/file/web/shared.py").get_data(as_text=True)
    light = 'html:not([data-theme="dark"]) .file-lines'
    dark = 'html[data-theme="dark"] .file-lines'
    assert f"{light} {{ background: #f8f8f8; }}" in body
    assert f"{dark} {{ background: #0d1117;" in body
    # the near-white dark-theme name colour exists only under the dark scope
    near_white = [l for l in body.splitlines() if "#E6EDF3" in l.upper() and ".file-lines" in l]
    assert near_white and all(l.startswith(dark) for l in near_white)
    # control: no unscoped rule that would restyle every <pre> on the page
    style = body[body.index("<style>"):body.index("</style>")]
    assert not re.search(r"^\s*pre\s*\{", style, re.M)
    assert "span.linenos" not in style


def test_file_view_light_theme_token_colours_are_dark_enough():
    from web.blueprints.docs import _source_theme_css
    light = 'html:not([data-theme="dark"]) .file-lines'
    for line in _source_theme_css().splitlines():
        m = re.match(re.escape(light) + r" \.\w+ \{ color: #([0-9A-Fa-f]{3,6})", line)
        if not m:
            continue
        h = m.group(1)
        h = "".join(c * 2 for c in h) if len(h) == 3 else h
        lum = sum(int(h[i:i + 2], 16) for i in (0, 2, 4)) / 3
        assert lum < 200, line  # nothing near-white on the #f8f8f8 background
    # control: the dark palette really is light-on-dark
    assert 'html[data-theme="dark"] .file-lines { color: #e6edf3; }' in _source_theme_css()


# Item 2 — refs to files that exist never look broken.

def test_numbered_root_doc_links(proj):
    assert hrefs(render_markdown_safe("see 001-Vision.md")) == ["/file/001-Vision.md"]
    assert is_viewable_path("001-Vision.md") and is_viewable_path("040-ValueDrivers.md")


def test_root_doc_rule_is_numbered_markdown_only(proj):
    # control: depth-0 viewability is the numbered-doc shape only (T-2281)
    assert not is_viewable_path("setup.py")
    assert not is_viewable_path("scratch.md")
    assert not is_viewable_path("001-x.py")
    assert not is_viewable_path(".001-x.md")


def test_live_root_docs_are_served():
    from web.app import app
    c = app.test_client()
    for name in ("001-Vision.md", "040-ValueDrivers.md"):
        if (REPO / name).is_file():
            assert c.get(f"/file/{name}").status_code == 200, name
            assert hrefs(render_markdown_safe(f"see {name}")) == [f"/file/{name}"]


def test_dotdir_file_that_exists_is_not_dead(proj):
    out = render_markdown_safe("hook is in .claude/settings.json:100")
    assert "file-ref-dead" not in out
    assert 'class="file-ref-unserved"' in out  # exists, honestly not served


def test_task_name_that_exists_only_outside_viewer_is_plain(proj):
    out = render_markdown_safe("see T-9004-vendored-only.md")
    assert "file-ref" not in out and hrefs(out) == []
    # control: a task-shaped name that exists nowhere is dead
    assert "file-ref-dead" in render_markdown_safe("see T-9005-nowhere.md")


def test_path_under_a_directory_the_project_lacks_is_plain(proj):
    assert "file-ref" not in render_markdown_safe("see src/main.py")
    # control: a missing file under a directory the project has is dead
    assert "file-ref-dead" in render_markdown_safe("see lib/omega.py")


# Item 3 — generic filenames in prose are left alone.

@pytest.mark.parametrize("name", ["Cargo.toml", "tsconfig.json", "settings.json",
                                  "snake_case_name.md", "pom.json"])
def test_generic_bare_names_are_neither_linked_nor_marked(proj, name):
    out = render_markdown_safe(f"If you edited {name}, rebuild.")
    assert hrefs(out) == [] and "file-ref" not in out, out


def test_generic_names_inside_html_comment_template_stay_plain(proj):
    out = render_markdown_safe("# *.go, Cargo.toml, tsconfig.json, or pom.xml")
    assert hrefs(out) == [] and "file-ref" not in out
    # control: a generic name WITH a directory is still resolved
    assert hrefs(render_markdown_safe("lib/ts/tsconfig.json")) == ["/file/lib/ts/tsconfig.json"]


def test_unique_report_basename_still_links(proj):
    # control: the project-specific shapes keep resolving
    assert hrefs(render_markdown_safe("T-9002-unique-report.md")) == [
        "/file/docs/reports/T-9002-unique-report.md"]


# Item 4 — a leading ./ is stripped.

def test_dot_slash_prefix_resolves(proj):
    out = render_markdown_safe("run ./agents/context/checkpoint.sh now")
    assert hrefs(out) == ["/file/agents/context/checkpoint.sh"]
    assert "file-ref" not in out
    # control: ./ of a missing file is still dead, not unserved
    assert "file-ref-dead" in render_markdown_safe("run ./agents/context/nope.sh")


# Item 5 — no marks inside code; live links there are fine.

def test_fenced_block_rendered_as_p_code_marks_nothing(proj):
    out = render_markdown_safe("```\nERROR lib/omega.py failed\nsee lib/alpha.py\n```")
    assert "file-ref" not in out
    assert "/file/lib/alpha.py" in hrefs(out)


def test_inline_code_log_marks_nothing(proj):
    out = render_markdown_safe("`grep: lib/omega.py: No such file or directory`")
    assert "file-ref" not in out


def test_code_span_that_is_the_ref_still_shows_dead(proj):
    # control: a backticked citation of a stale path is a claim, not a log
    assert "file-ref-dead" in render_markdown_safe("`lib/omega.py`")


# Item 6 — docs/adr/ and docs/runbooks/ are served.

def test_adr_and_runbooks_are_viewable(proj):
    out = render_markdown_safe("docs/adr/0001-thing.md docs/runbooks/restart.md")
    assert hrefs(out) == ["/file/docs/adr/0001-thing.md", "/file/docs/runbooks/restart.md"]
    # control: a sibling docs/ directory not on the list stays unserved
    assert not is_viewable_path("docs/secret/x.md")
