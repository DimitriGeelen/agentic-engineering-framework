"""T-4455: `fw reviewer judge` derives the pages to screenshot from a render criterion's text.

Before the fix only a backticked bare path (`/review`) counted, so a criterion naming
`/search?q=release decision` (T-4350) or http://<host>:3000/cron (T-4432) yielded no page and
every seat ended 'no page derived'. A full URL counts only when its origin is this project's
Watchtower; a foreign origin is never captured.
"""
from __future__ import annotations

import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE.parent.parent))

from lib.reviewer import judge_cli  # noqa: E402


def _root(tmp_path: Path, url: str = "http://192.168.10.107:3000") -> Path:
    (tmp_path / ".context/working").mkdir(parents=True)
    (tmp_path / ".context/working/watchtower.url").write_text(url + "\n")
    return tmp_path


def _pages(root: Path, body: str) -> list[str]:
    return judge_cli._pages_for(root, "T-9999", "", [{"body": body}])


def test_backticked_bare_path_unchanged(tmp_path):
    assert _pages(_root(tmp_path), "renders at `/review` cleanly") == ["/review"]


def test_backticked_path_with_query_keeps_query_and_encodes_space(tmp_path):
    body = "append `/search?q=release decision` to the base URL"
    assert _pages(_root(tmp_path), body) == ["/search?q=release%20decision"]


def test_bare_full_url_on_own_watchtower(tmp_path):
    body = "1. Open http://192.168.10.107:3000/cron\n2. Click pause."
    assert _pages(_root(tmp_path), body) == ["/cron"]


def test_backticked_full_url_on_own_watchtower_keeps_query(tmp_path):
    body = "Open `http://192.168.10.107:3000/search?q=a b` and look"
    assert _pages(_root(tmp_path), body) == ["/search?q=a%20b"]


def test_placeholder_and_localhost_on_own_port(tmp_path):
    root = _root(tmp_path)
    assert _pages(root, "Open http://<watchtower>:3000/cron.") == ["/cron"]
    assert _pages(root, "Open http://localhost:3000/tasks/T-1") == ["/tasks/T-1"]


def test_foreign_origin_never_captured(tmp_path):
    root = _root(tmp_path)
    body = ("Open https://example.com/dashboard and `https://evil.example/x?y=1` and "
            "http://192.168.10.107:3001/cron and http://localhost:3001/other")
    assert _pages(root, body) == []


def test_no_watchtower_url_uses_configured_port_for_local_hosts(tmp_path, monkeypatch):
    monkeypatch.delenv("FW_PORT", raising=False)
    assert _pages(tmp_path, "Open http://localhost:3000/cron") == ["/cron"]
    assert _pages(tmp_path, "Open http://10.0.0.5:3000/cron") == []
