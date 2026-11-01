"""T-4960: the judge's full-page shot of /approvals (81,749 px) ran past Playwright's 30 s
screenshot timeout, so every render review of it was PARTIAL. Above MAX_FULL_PAGE_PX the
capturer keeps the viewport, records console/page errors per page, and the brief says both.

The notes legs run everywhere; the browser leg needs Playwright + Chromium and skips with the
reason named when either is missing."""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE.parent.parent))

from lib.reviewer import judge_cli  # noqa: E402

PAGES = ["/approvals", "/approvals/content"]
CRIT = [{"index": 1, "ac_index": 1, "body": "renders", "render": True}]


def _setup(tmp_path, monkeypatch):
    (tmp_path / ".context/working").mkdir(parents=True)
    (tmp_path / ".context/working/watchtower.url").write_text("http://127.0.0.1:3000\n")
    monkeypatch.setattr(judge_cli, "_pages_for", lambda *a, **k: list(PAGES))
    monkeypatch.setattr(judge_cli, "_gather_visual", lambda *a, **k: {})


def _capturer(notes):
    def capture(url, pages, out):
        out.mkdir(parents=True, exist_ok=True)
        shots = []
        for i, pg in enumerate(pages):
            f = out / judge_cli._shot_name(i, pg)
            f.write_bytes(f"png {pg}".encode())
            shots.append(f)
        if notes is not None:
            (out / judge_cli.CAPTURE_NOTES).write_text(json.dumps(notes))
        return shots, ""
    return capture


def test_tall_page_and_console_errors_reach_the_brief(tmp_path, monkeypatch):
    _setup(tmp_path, monkeypatch)
    notes = {"/approvals": {"height": 81749, "viewport_only": True, "console_errors": [],
                            "console_error_count": 0},
             "/approvals/content": {"height": 4000, "viewport_only": False,
                                    "console_errors": ["console: boom"], "console_error_count": 1},
             "/elsewhere": {"height": 1, "viewport_only": False}}
    ev = judge_cli._gather_evidence(tmp_path, "T-9", {"text": ""}, CRIT, _capturer(notes),
                                    dry_run=False)
    assert ev["partial"] == [] and set(ev["notes"]) == set(PAGES)      # unplanned page dropped
    brief = judge_cli._build_brief("T-9", CRIT, evidence=ev)
    assert "`/approvals` is 81,749 px tall" in brief and "top of the page only" in brief
    assert "`/approvals`: the browser reported no console or page errors." in brief
    assert "`/approvals/content`: the browser reported 1 console/page error(s):" in brief
    assert "  - console: boom" in brief
    assert "/approvals/content` is" not in brief                       # not tall, no tall line


def test_no_notes_renders_the_brief_as_before(tmp_path, monkeypatch):
    _setup(tmp_path, monkeypatch)
    ev = judge_cli._gather_evidence(tmp_path, "T-9", {"text": ""}, CRIT, _capturer(None),
                                    dry_run=False)
    assert ev["notes"] == {}
    assert "What the capturing browser recorded" not in judge_cli._build_brief("T-9", CRIT, evidence=ev)


def test_malformed_notes_are_ignored(tmp_path):
    f = tmp_path / "n.json"
    f.write_text("{not json")
    assert judge_cli._capture_notes(f, PAGES) == {}
    f.write_text(json.dumps(["x"]))
    assert judge_cli._capture_notes(f, PAGES) == {}


def _browser_unavailable_reason():
    try:
        from playwright.sync_api import sync_playwright
    except Exception as e:  # noqa: BLE001
        return f"playwright not importable ({e})"
    try:
        with sync_playwright() as pw:
            pw.chromium.launch().close()
    except Exception as e:  # noqa: BLE001
        return f"chromium cannot launch ({str(e).splitlines()[0][:120]})"
    return None


_REASON = _browser_unavailable_reason()


@pytest.mark.skipif(_REASON is not None, reason=f"browser capture not exercised: {_REASON}")
def test_real_capture_keeps_the_viewport_of_a_tall_page(tmp_path, monkeypatch):
    import http.server
    import threading
    site = tmp_path / "site"
    site.mkdir()
    (site / "tall.html").write_text(
        "<!doctype html><body style='margin:0'><div style='height:30000px'>x</div>"
        "<script>console.error('boom')</script></body>")
    (site / "short.html").write_text("<!doctype html><body><p>ok</p></body>")
    handler = lambda *a, **k: http.server.SimpleHTTPRequestHandler(*a, directory=str(site), **k)  # noqa: E731
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    try:
        out = tmp_path / "out"
        shots, err = judge_cli._capture_playwright(f"http://127.0.0.1:{srv.server_port}",
                                                   ["/tall.html", "/short.html"], out)
    finally:
        srv.shutdown()
    assert err == "" and len(shots) == 2
    png = shots[0].read_bytes()
    assert int.from_bytes(png[20:24], "big") == 900                    # viewport, not 30,000 px
    notes = json.loads((out / judge_cli.CAPTURE_NOTES).read_text())
    assert notes["/tall.html"]["viewport_only"] is True and notes["/tall.html"]["height"] >= 30000
    assert any("boom" in e for e in notes["/tall.html"]["console_errors"])
    assert notes["/short.html"] == {"height": notes["/short.html"]["height"], "viewport_only": False,
                                    "console_errors": [], "console_error_count": 0}
