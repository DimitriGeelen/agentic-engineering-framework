"""T-4883 — inbox's exception/sentinel classes survive importlib.reload(inbox).

Four test files reload lib.sidecar.inbox. Before this, a reload bound new
Unreadable/ReadFailed classes while aliases taken at import (alerts.Unreadable)
kept the old ones, so `pytest.raises(alerts.Unreadable)` missed what
strict_reader raised — the suite's verdict depended on file order.
"""

import importlib
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from lib.sidecar import alerts, inbox  # noqa: E402


def test_classes_keep_identity_across_reload():
    before = (inbox.Unreadable, inbox.ReadFailed)
    importlib.reload(inbox)
    assert (inbox.Unreadable, inbox.ReadFailed) == before
    assert alerts.Unreadable is inbox.Unreadable


def test_strict_reader_raise_is_caught_by_the_alias_after_reload(monkeypatch):
    importlib.reload(inbox)
    monkeypatch.setattr(inbox, "_binary", lambda: "/bin/termlink-fake")
    monkeypatch.setattr(inbox, "default_reader",
                        lambda *a, **k: inbox.ReadFailed("connection refused"))
    try:
        alerts.strict_reader("inbox:x", 0)
    except alerts.Unreadable as e:
        assert "connection refused" in str(e)
    else:
        raise AssertionError("strict_reader did not raise")
