"""T-4059 — concurrent deliveries of one client_msg_id must not race the tmp file.

Before the fix, store_message wrote every delivery through the same tmp path
(<id>.json.tmp). Two concurrent writers shared it: the first os.replace moved
the file, the second found no file and the receiver answered HTTP 400 although
the message was stored.
"""

from __future__ import annotations

import sys
import threading
from pathlib import Path
from unittest import mock

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT))

from lib.sidecar import receiver  # noqa: E402


@pytest.fixture
def root(tmp_path):
    project = tmp_path / "project"
    (project / ".context" / "sidecar").mkdir(parents=True)
    with mock.patch.object(receiver, "_root", return_value=project):
        yield project


def _envelope(body="hello"):
    return {"from": "agent-a", "to": "agent-b", "conversation_id": "conv-1",
            "client_msg_id": "race-001", "body": body}


def _race(n, fn):
    """Run fn n times from n threads released by one barrier."""
    barrier = threading.Barrier(n)
    results = [None] * n

    def run(i):
        barrier.wait()
        try:
            results[i] = fn()
        except Exception as e:  # surface, do not swallow
            results[i] = ("EXC", repr(e))

    threads = [threading.Thread(target=run, args=(i,)) for i in range(n)]
    for t in threads:
        t.start()
    for t in threads:
        t.join(timeout=30)
    return results


@pytest.mark.usefixtures("root")
def test_concurrent_identical_deliveries_all_succeed():
    results = _race(16, lambda: receiver.store_message("race-001", _envelope()))

    assert all(r == (True, "") for r in results), results
    msgs = receiver._messages_dir()
    assert sorted(p.name for p in msgs.glob("*.json")) == ["race-001.json"]
    assert sorted(p.name for p in msgs.glob("*.ready")) == ["race-001.ready"]
    assert list(msgs.glob("*.tmp")) == [], "a temp file was left behind"


@pytest.mark.usefixtures("root")
def test_concurrent_identical_deliveries_repeated():
    # Many small rounds with fresh ids: the interleaving is timing-dependent,
    # so repetition is what makes the pre-fix failure show up reliably.
    failures = []
    for i in range(40):
        mid = f"race-{i:03d}"
        env = dict(_envelope(), client_msg_id=mid)
        results = _race(8, lambda: receiver.store_message(mid, env))
        failures += [r for r in results if r != (True, "")]
    assert failures == []
    assert list(receiver._messages_dir().glob("*.tmp")) == []


@pytest.mark.usefixtures("root")
def test_different_content_reusing_id_still_conflicts():
    assert receiver.store_message("race-001", _envelope("first")) == (True, "")
    ok, err = receiver.store_message("race-001", _envelope("second"))
    assert ok is False
    assert err.startswith("conflict:")


@pytest.mark.usefixtures("root")
def test_concurrent_different_content_one_wins_others_conflict():
    # Racing writers with different bodies: exactly one may be stored; every
    # other must be refused as a conflict, never answered as success for a
    # message that is not the stored one.
    results = _race(8, lambda: receiver.store_message(
        "race-001", _envelope(f"body-{threading.get_ident()}")))
    successes = [r for r in results if r == (True, "")]
    conflicts = [r for r in results if r[0] is False and r[1].startswith("conflict:")]
    assert len(successes) == 1, results
    assert len(conflicts) == 7, results
    assert list(receiver._messages_dir().glob("*.tmp")) == []
