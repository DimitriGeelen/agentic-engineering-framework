"""T-5128: the approvals page's per-task display parse of the acceptance criteria is cached per
task file (mtime, the same key as its body cache), so a repeat request re-parses nothing that did
not change — and returns exactly what an uncached request returns."""
from __future__ import annotations

import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_HERE))

from web.app import app  # noqa: E402
from web.blueprints import approvals as ap  # noqa: E402
import web.blueprints.tasks as tasks_bp  # noqa: E402


def _cards():
    with app.test_request_context("/approvals"):
        return ap._load_pending_human_acs()


def test_a_warm_request_reparses_nothing_and_returns_the_same_cards(monkeypatch):
    ap._AC_DISPLAY_CACHE.clear()
    cold = _cards()
    calls = []
    real = tasks_bp._parse_acceptance_criteria

    def counting(body):
        calls.append(1)
        return real(body)

    monkeypatch.setattr(tasks_bp, "_parse_acceptance_criteria", counting)
    warm = _cards()
    assert calls == [], f"{len(calls)} criteria parse(s) on a warm request"
    assert warm == cold


def test_the_cache_is_keyed_per_file_like_the_body_cache():
    ap._AC_DISPLAY_CACHE.clear()
    _cards()
    if not ap._AC_DISPLAY_CACHE:
        return   # no task awaiting review on this checkout: nothing to cache
    for key in ap._AC_DISPLAY_CACHE:
        assert key in ap._BODY_CACHE   # parsed from the same cached body, same mtime key
