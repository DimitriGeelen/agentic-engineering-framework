"""T-4010 (dimitri-mint-dev G-010) — `fw reviewer judge` exited 0 when no seat could record.

In a consumer whose vendored framework is untracked, no worker kind is launchable, every
dispatch is refused at start, and the judge printed `unknown (no-ledger-row)` with exit 0 — a
finished-looking review that reviewed nothing. Now: exit 3 and name the cause.
"""
from __future__ import annotations

import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_HERE))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib.reviewer import judge_cli  # noqa: E402
import _review_runtime as rt  # noqa: E402
from t3580_judge_cli_test import NOCAP, TASTE, TID, _mk_task, _produce, repo  # noqa: E402,F401


def _silent(**_kw) -> str:
    """A dispatcher whose worker never records anything (as when start is refused)."""
    _silent.n += 1
    return f"judge-silent-{_silent.n:06d}"


_silent.n = 0


def test_no_ledger_row_from_any_seat_is_an_error(repo, monkeypatch):
    rt.unbound_spend(monkeypatch)
    _mk_task(repo, TASTE)
    _produce(repo)
    res = judge_cli.judge(TID, repo, dispatcher=_silent, capture=NOCAP,
                          worker_kinds={"claude"}, kind_vendors={"claude": "anthropic"})
    assert res["code"] == 3, res
    assert "no review seat recorded a verdict" in res["no_seat_recorded"]


def test_control_dry_run_is_not_an_error(repo, monkeypatch):
    rt.unbound_spend(monkeypatch)
    _mk_task(repo, TASTE)
    _produce(repo)
    res = judge_cli.judge(TID, repo, dry_run=True, capture=NOCAP,
                          worker_kinds={"claude"}, kind_vendors={"claude": "anthropic"})
    assert res["code"] == 0 and "no_seat_recorded" not in res
