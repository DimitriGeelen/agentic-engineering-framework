"""T-4951: with no policy/value-drivers.yaml, bvp.load_policy() calls sys.exit(2). A SystemExit
escaped /approvals' `except Exception` degrade-to-ratio path and aborted the Arc Closure build.
corpus_medians now raises an ordinary error the caller already handles."""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "lib"))

import arc_close_readiness as acr  # noqa: E402


def test_missing_policy_raises_an_ordinary_error_not_systemexit(tmp_path, monkeypatch):
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    (tmp_path / ".tasks" / "active").mkdir(parents=True)

    class FakeBvp:
        @staticmethod
        def load_policy():
            print("ERROR: policy file not found", file=sys.stderr)
            sys.exit(2)

    monkeypatch.setattr(acr.bvp_py, "load", lambda *a, **k: FakeBvp)
    with pytest.raises(RuntimeError, match="BVP policy unavailable") as ei:
        acr.corpus_medians(tmp_path, open_fms=[])
    assert isinstance(ei.value.__cause__, SystemExit)


def test_an_exception_handler_catches_it(tmp_path, monkeypatch):
    # The /approvals caller's shape: `except Exception: return None` must now see it.
    class FakeBvp:
        @staticmethod
        def load_policy():
            sys.exit(2)

    monkeypatch.setattr(acr.bvp_py, "load", lambda *a, **k: FakeBvp)
    try:
        acr.corpus_medians(tmp_path, open_fms=[])
        reached = "no error"
    except Exception:
        reached = "caught"
    assert reached == "caught"
