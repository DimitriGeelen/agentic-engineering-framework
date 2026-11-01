"""T-4943: `fw reviewer judge` planned 8 required pages for T-4906 but screenshotted only the
first 6 (MAX_CAPTURE_PAGES); the other 2 were recorded as not captured and the ledger refused
every green, so no reviewer could ever close the criterion. Every required page is captured."""
from __future__ import annotations

import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE.parent.parent))

from lib.reviewer import judge_cli  # noqa: E402

PAGES = [f"/p{i}" for i in range(8)]


def test_every_required_page_is_captured(tmp_path, monkeypatch):
    (tmp_path / ".context/working").mkdir(parents=True)
    (tmp_path / ".context/working/watchtower.url").write_text("http://127.0.0.1:3000\n")
    monkeypatch.setattr(judge_cli, "_pages_for", lambda *a, **k: list(PAGES))
    monkeypatch.setattr(judge_cli, "_gather_visual", lambda *a, **k: {})
    asked = []

    def capture(url, pages, out):
        asked.extend(pages)
        out.mkdir(parents=True, exist_ok=True)
        shots = []
        for i, pg in enumerate(pages):
            f = out / judge_cli._shot_name(i, pg)
            f.write_bytes(f"png {pg}".encode())
            shots.append(f)
        return shots, ""

    ev = judge_cli._gather_evidence(tmp_path, "T-9", {"text": ""}, [{"render": True}],
                                    capture, dry_run=False)
    assert asked == PAGES
    assert [c["page"] for c in ev["captures"]] == PAGES
    assert all(c["ok"] and c["sha256"] for c in ev["captures"])
    assert not any("not captured" in c["error"] for c in ev["captures"])
    assert len(ev["shots"]) == 8


def test_a_page_the_capturer_missed_is_still_reported_not_ok(tmp_path, monkeypatch):
    # The strict rule is unchanged: a required page with no screenshot stays ok: False.
    (tmp_path / ".context/working").mkdir(parents=True)
    (tmp_path / ".context/working/watchtower.url").write_text("http://127.0.0.1:3000\n")
    monkeypatch.setattr(judge_cli, "_pages_for", lambda *a, **k: list(PAGES))
    monkeypatch.setattr(judge_cli, "_gather_visual", lambda *a, **k: {})

    def capture(url, pages, out):
        out.mkdir(parents=True, exist_ok=True)
        f = out / judge_cli._shot_name(0, pages[0])
        f.write_bytes(b"png")
        return [f], f"partial: {pages[7]}: timeout"

    ev = judge_cli._gather_evidence(tmp_path, "T-9", {"text": ""}, [{"render": True}],
                                    capture, dry_run=False)
    by_page = {c["page"]: c for c in ev["captures"]}
    assert by_page["/p0"]["ok"] is True
    assert by_page["/p7"]["ok"] is False and "timeout" in by_page["/p7"]["error"]
