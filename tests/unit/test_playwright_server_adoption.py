"""Adoption decision for the shared Playwright test server (T-2782).

`tests/playwright/conftest.py` does not start a server if one is already listening on
`FW_TEST_PORT` — it adopts it. Before T-2782 that adoption had no decision in it: anything
answering `/health` was taken, forever, unmanaged. Two things went wrong through that door:

  * **Staleness** — an adopted server is never torn down, so it accumulates across sessions.
    T-2777 measured one at 656MB RSS / 66min CPU returning 13-16s on routes a fresh instance
    served in under 3s, and that was first diagnosed as host contention rather than as the
    fixture degrading the very timings the suite exists to guard.
  * **Identity** — `/health` answers "something is listening", not "the right thing is". Every
    consumer project runs the same Flask app, so another project's Watchtower answers every
    route and passes every assertion, about the wrong corpus. That is the exact false-green
    CLAUDE.md §Watchtower Port documents (371 verification lines against `:3000`).

These tests exist to fail if either check is taken back out — a guard that has never been red
proves only that it is implemented (L-530).
"""
import datetime
import importlib.util
import os

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OURS = ROOT


def _load_conftest():
    path = os.path.join(ROOT, "tests", "playwright", "conftest.py")
    spec = importlib.util.spec_from_file_location("pw_conftest_t2782", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


cf = _load_conftest()

NOW = datetime.datetime(2026, 8, 4, 12, 0, 0, tzinfo=datetime.timezone.utc)


def _ident(root=OURS, age_s=60, service="watchtower", pid=12345, started=True):
    d = {"service": service, "project_root": root, "pid": pid}
    if started:
        d["started_at"] = (NOW - datetime.timedelta(seconds=age_s)).isoformat()
    return d


# --- the three paths that must stay distinguishable ---------------------------------


def test_nothing_listening_starts_our_own():
    action, _ = cf._adoption_decision(None, OURS, now=NOW)
    assert action == "start"


def test_occupied_but_silent_port_is_rejected_not_started():
    """A non-Watchtower listener answers the socket but not /api/_identity. Treating
    that as 'nothing there' sends the fixture down the start path, where it fails on
    bind with 'Watchtower failed to start' — an error about the wrong thing, which is
    how a five-second diagnosis becomes a long one."""
    action, reason = cf._adoption_decision(None, OURS, now=NOW, port_occupied=True)
    assert action == "reject", f"occupied-but-silent port was {action!r}"
    assert "/api/_identity" in reason


def test_our_young_server_is_adopted():
    action, reason = cf._adoption_decision(_ident(age_s=300), OURS, max_age_s=3600, now=NOW)
    assert action == "adopt", reason


def test_our_stale_server_is_recycled_not_adopted():
    """The T-2777 case: same project, but up long enough to have degraded."""
    action, reason = cf._adoption_decision(
        _ident(age_s=20 * 3600), OURS, max_age_s=3600, now=NOW
    )
    assert action == "recycle", (
        f"a 20h-old server was {action!r}. Adopting it is how a 5x-slower reading gets "
        "attributed to host contention instead of to the fixture (T-2777)."
    )


def test_foreign_project_is_rejected_not_adopted():
    """The dangerous one: it answers everything, so adopting it produces confident
    numbers about a corpus nobody is changing."""
    action, reason = cf._adoption_decision(
        _ident(root="/opt/003-Some-Other-Project"), OURS, now=NOW
    )
    assert action == "reject", (
        f"a server for a DIFFERENT project was {action!r}. It runs the same Flask app, so "
        "every route answers and every assertion passes — against the wrong corpus "
        "(CLAUDE.md §Watchtower Port)."
    )
    assert "/opt/003-Some-Other-Project" in reason and OURS in reason, (
        "the rejection must name both roots — otherwise the operator is told 'wrong "
        "project' with no way to see which one is listening"
    )


def test_non_watchtower_listener_is_rejected():
    action, _ = cf._adoption_decision(_ident(service="some-other-app"), OURS, now=NOW)
    assert action == "reject"


def test_server_that_will_not_say_its_age_is_rejected():
    """Unbounded staleness is the defect; a server that hides its age is unbounded."""
    action, _ = cf._adoption_decision(_ident(started=False), OURS, now=NOW)
    assert action == "reject"


def test_symlinked_root_still_counts_as_ours():
    """realpath both sides: /opt/x and a symlink to it are the same project, and a
    fixture that rejects on that is one people route around."""
    action, _ = cf._adoption_decision(_ident(root=OURS + "/."), OURS, now=NOW)
    assert action == "adopt"


# --- age parsing --------------------------------------------------------------------


@pytest.mark.parametrize("started_at,expected", [
    ("2026-08-04T11:00:00+00:00", 3600),
    ("2026-08-04T11:00:00", 3600),  # naive — assumed UTC, not crashed on
])
def test_age_parses_aware_and_naive(started_at, expected):
    assert cf._server_age_s({"started_at": started_at}, now=NOW) == expected


@pytest.mark.parametrize("bad", [{}, {"started_at": ""}, {"started_at": "not-a-date"}])
def test_age_is_none_when_unparseable(bad):
    assert cf._server_age_s(bad, now=NOW) is None


# --- the recycle safety rail --------------------------------------------------------


def test_recycle_refuses_to_kill_the_live_watchtower(monkeypatch):
    """Recycling a scratch server on 3099 is correct. Doing it to the operator's live
    session because FW_TEST_PORT was pointed at the real port is the accident CLAUDE.md
    §Watchtower Port exists to prevent, so it is refused rather than trusted to config.
    """
    monkeypatch.setattr(cf, "_live_watchtower_port", lambda _root: cf.TEST_PORT)
    killed = []
    monkeypatch.setattr(os, "kill", lambda pid, sig: killed.append((pid, sig)))

    with pytest.raises(RuntimeError, match="refusing to recycle"):
        cf._recycle(_ident(), ROOT)
    assert killed == [], "it sent a signal before refusing"


def test_recycle_refuses_when_no_pid_rather_than_guessing(monkeypatch):
    monkeypatch.setattr(cf, "_live_watchtower_port", lambda _root: 3001)
    ident = _ident(pid=None)
    with pytest.raises(RuntimeError, match="no pid"):
        cf._recycle(ident, ROOT)
