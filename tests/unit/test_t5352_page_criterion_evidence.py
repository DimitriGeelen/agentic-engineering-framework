"""T-5352: a criterion that names a page but is not render-class (T-5350: a designer re-pin names
/designer, changes no web/ file, so it is `unclassified`) got an "Image evidence" brief that
promised screenshots and listed none: `_gather_evidence` asked only `render`. One predicate,
`judge_cli.needs_screenshots`, now decides for the capture, the brief and the run's pages.

Hermetic: the capturer and the visual gatherer are fakes; no browser, no server, no git."""
from __future__ import annotations

import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE.parent.parent))

from lib import review_seat_evidence  # noqa: E402
from lib.reviewer import judge_cli  # noqa: E402

VISUAL = {"widths": [1024], "problems": [],
          "shots": [{"state": "designer", "width": 1024,
                     "path": ".context/visual/T-9/designer@1024.png", "sha256": "ab" * 32}]}


def _crit(body: str, *, render=False, cls="unclassified") -> dict:
    page = render or judge_cli.names_page(body)
    return {"index": 1, "ac_index": 1, "text": body, "body": body, "class": cls,
            "render": render, "page": page, "image": page or judge_cli.names_image(body)}


def _setup(tmp_path, monkeypatch):
    (tmp_path / ".context/working").mkdir(parents=True)
    (tmp_path / ".context/working/watchtower.url").write_text("http://127.0.0.1:3000\n")
    monkeypatch.setattr(judge_cli, "_changed_web_files", lambda *a, **k: [])
    monkeypatch.setattr(judge_cli, "_gather_visual", lambda *a, **k: dict(VISUAL))
    monkeypatch.setattr(judge_cli, "_bare_get_refusals", lambda *a, **k: {})


def _capture(calls):
    def capture(url, pages, out):
        calls.append(list(pages))
        out.mkdir(parents=True, exist_ok=True)
        shots = []
        for i, pg in enumerate(pages):
            f = out / judge_cli._shot_name(i, pg)
            f.write_bytes(f"png {pg}".encode())
            shots.append(f)
        return shots, ""
    return capture


def _never(url, pages, out):
    raise AssertionError("no capture may run for a criterion that needs no screenshots")


def test_unclassified_page_criterion_gets_pages_and_visual(tmp_path, monkeypatch):
    _setup(tmp_path, monkeypatch)
    c = _crit("The designer loads at `/designer` and `/designer/app`.")
    assert c["class"] == "unclassified" and not c["render"] and judge_cli.needs_screenshots(c)
    calls: list = []
    ev = judge_cli._gather_evidence(tmp_path, "T-9", {"text": ""}, [c], _capture(calls),
                                    dry_run=False)
    assert ev["needed"] is True
    assert ev["pages"] == ["/designer", "/designer/app"] and calls == [["/designer", "/designer/app"]]
    assert [x["ok"] for x in ev["captures"]] == [True, True] and not ev["partial"] and not ev["error"]
    assert ev["visual"]["shots"][0]["path"] == ".context/visual/T-9/designer@1024.png"
    # the dry run plans the same pages and visual evidence without capturing
    dry = judge_cli._gather_evidence(tmp_path, "T-9", {"text": ""}, [c], _never, dry_run=True)
    assert dry["needed"] and dry["pages"] == ev["pages"] and dry["visual"] == ev["visual"]


def test_render_criterion_unchanged(tmp_path, monkeypatch):
    _setup(tmp_path, monkeypatch)
    c = _crit("The page renders at `/config`.", render=True, cls="render-surface")
    assert judge_cli.needs_screenshots(c) and judge_cli.is_image_evidence(c)
    calls: list = []
    ev = judge_cli._gather_evidence(tmp_path, "T-9", {"text": ""}, [c], _capture(calls),
                                    dry_run=False)
    assert ev["needed"] and ev["pages"] == ["/config"] and calls == [["/config"]]
    assert ev["shots"] and ev["visual"] == VISUAL
    brief = judge_cli._build_brief("T-9", [c], evidence=ev)
    assert "## Image evidence" in brief and "## Rendered pages" in brief


def test_no_page_no_image_gets_no_image_section(tmp_path, monkeypatch):
    _setup(tmp_path, monkeypatch)
    c = _crit("The changelog entry says the option was removed.")
    assert not judge_cli.needs_screenshots(c) and not judge_cli.is_image_evidence(c)
    ev = judge_cli._gather_evidence(tmp_path, "T-9", {"text": ""}, [c], _never, dry_run=False)
    assert ev["needed"] is False and ev["pages"] == [] and "visual" not in ev
    brief = judge_cli._build_brief("T-9", [c], evidence=ev)
    assert "## Image evidence" not in brief and "## Rendered pages" not in brief


def test_image_file_only_criterion_is_image_evidence_without_capture(tmp_path, monkeypatch):
    # T-5209's case stays as it was: an image file named, no page, so nothing to capture.
    _setup(tmp_path, monkeypatch)
    c = _crit("The attached diagram.png shows three stages.")
    assert judge_cli.is_image_evidence(c) and not judge_cli.needs_screenshots(c)
    ev = judge_cli._gather_evidence(tmp_path, "T-9", {"text": ""}, [c], _never, dry_run=False)
    assert ev["needed"] is False


def test_page_criterion_brief_cites_screenshots_for_the_seat_export(tmp_path, monkeypatch):
    _setup(tmp_path, monkeypatch)
    c = _crit("Open http://127.0.0.1:3000/designer and check the canvas loads.")
    calls: list = []
    ev = judge_cli._gather_evidence(tmp_path, "T-9", {"text": ""}, [c], _capture(calls),
                                    dry_run=False)
    brief = judge_cli._build_brief("T-9", [c], evidence=ev)
    assert "## Image evidence" in brief and "## Rendered pages" in brief
    assert "SCREENSHOT CAPTURE FAILED" not in brief
    cited = review_seat_evidence.cited(brief)
    assert ev["shots"] and set(ev["shots"]) <= set(cited)
    assert ".context/visual/T-9/designer@1024.png" in cited
