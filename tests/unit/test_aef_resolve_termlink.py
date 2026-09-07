"""T-3338 (arc-020 S8): live termlink wiring for the endpoint-probe seam.

Covers `termlink_probe` — the probe that resolve() climbs the ladder with —
against a fake invoke (no live hub). The point under test is the D4-A
death-test contract: a hub that ANSWERS "not there" yields False, but an
unreachable hub / failed invoke RAISES ResolveIndeterminate. Conflating the
two is the bug this seam exists to prevent, so most tests assert the raise,
not the value.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from lib.aef_address import AEFAddress  # noqa: E402
from lib.aef_resolve import (  # noqa: E402
    ResolveError,
    ResolveIndeterminate,
    resolve,
    termlink_probe,
)


class FakeInvoke:
    """Records calls; returns a scripted result keyed by the (verb, sub)."""

    def __init__(self, script=None, *, raises=False):
        self.calls: list[list[str]] = []
        self.script = script or {}
        self.raises = raises

    def __call__(self, args, *, timeout=8.0):
        self.calls.append(list(args))
        if self.raises:
            raise RuntimeError("binary missing / invoke blew up")
        key = args[0] if args else ""
        if key == "hub" and len(args) > 1:
            key = f"hub {args[1]}"
        handler = self.script.get(key)
        if handler is None:
            return {"ok": False, "data": {}, "stdout": "", "stderr": "no script"}
        return handler(args)


def _ok(data):
    return lambda args: {"ok": True, "data": data, "stdout": "", "stderr": ""}


def _ret(payload):
    return lambda args: payload


# ── session rung (ping) ──────────────────────────────────────────────────


def test_session_alive_is_true():
    fake = FakeInvoke({"ping": _ok({"ok": True, "state": "ready"})})
    probe = termlink_probe(invoke=fake)
    assert probe(AEFAddress(host="h", hub="u", session="tl-live")) is True
    assert fake.calls[0][:2] == ["ping", "tl-live"]


def test_session_not_found_is_false_definitive():
    # hub ANSWERED ok:false with a not-found error -> definitive absence.
    fake = FakeInvoke(
        {"ping": _ret({"ok": False, "data": {"ok": False, "error": "Session not found: tl-x"},
                       "stdout": "", "stderr": ""})}
    )
    probe = termlink_probe(invoke=fake)
    assert probe(AEFAddress(host="h", session="tl-x")) is False


def test_session_no_hub_verdict_raises_indeterminate():
    # no structured verdict came back -> unreachable, NOT absent.
    fake = FakeInvoke({"ping": _ret({"ok": False, "data": {}, "stdout": "", "stderr": "connection refused"})})
    probe = termlink_probe(invoke=fake)
    with pytest.raises(ResolveIndeterminate):
        probe(AEFAddress(host="h", session="tl-x"))


def test_session_ok_false_other_error_raises_indeterminate():
    # ok:false but NOT a not-found (e.g. auth) -> unknowable, not a false-absence.
    fake = FakeInvoke({"ping": _ret({"ok": False, "data": {"ok": False, "error": "unauthorized"},
                                     "stdout": "", "stderr": ""})})
    probe = termlink_probe(invoke=fake)
    with pytest.raises(ResolveIndeterminate):
        probe(AEFAddress(host="h", session="tl-x"))


def test_invoke_blowup_raises_indeterminate():
    probe = termlink_probe(invoke=FakeInvoke(raises=True))
    with pytest.raises(ResolveIndeterminate):
        probe(AEFAddress(host="h", session="tl-x"))


# ── project rung (delegates to path_exists) ──────────────────────────────


def test_project_delegates_to_path_exists_true():
    seen = {}
    def pe(p):
        seen["p"] = p
        return True
    probe = termlink_probe(invoke=FakeInvoke(), path_exists=pe)
    assert probe(AEFAddress(host="h", hub="u", project="/opt/proj")) is True
    assert seen["p"] == "/opt/proj"


def test_project_delegates_to_path_exists_false():
    probe = termlink_probe(invoke=FakeInvoke(), path_exists=lambda p: False)
    assert probe(AEFAddress(host="h", project="/opt/gone")) is False


# ── hub rung ─────────────────────────────────────────────────────────────


def test_local_hub_running_is_true():
    fake = FakeInvoke({"hub status": _ok({"ok": True, "status": "running", "pid": 1})})
    probe = termlink_probe(invoke=fake)
    assert probe(AEFAddress(host=None, hub="u")) is True
    assert fake.calls[0][:2] == ["hub", "status"]


def test_local_hub_not_running_is_false_definitive():
    fake = FakeInvoke({"hub status": _ret({"ok": False, "data": {"ok": False, "status": "stopped"},
                                           "stdout": "", "stderr": ""})})
    probe = termlink_probe(invoke=fake)
    assert probe(AEFAddress(host="localhost", hub="u")) is False


def test_local_hub_no_verdict_raises_indeterminate():
    fake = FakeInvoke({"hub status": _ret({"ok": False, "data": None, "stdout": "", "stderr": "boom"})})
    probe = termlink_probe(invoke=fake)
    with pytest.raises(ResolveIndeterminate):
        probe(AEFAddress(hub="u"))


# ── remote host rung (hub probe) ─────────────────────────────────────────


def test_remote_host_handshake_ok_is_true():
    fake = FakeInvoke({"hub probe": _ok({"sha256": "abc"})})
    probe = termlink_probe(invoke=fake)
    assert probe(AEFAddress(host="other-box", hub="u")) is True
    assert fake.calls[0][:2] == ["hub", "probe"]


def test_remote_host_unreachable_raises_indeterminate():
    # a remote miss is UNKNOWABLE, never a definitive False (D4-A).
    fake = FakeInvoke({"hub probe": _ret({"ok": False, "data": {}, "stdout": "", "stderr": "no route to host"})})
    probe = termlink_probe(invoke=fake)
    with pytest.raises(ResolveIndeterminate):
        probe(AEFAddress(host="other-box"))


# ── malformed rungs raise (not silent False) ─────────────────────────────


def test_agent_without_session_raises_resolve_error():
    probe = termlink_probe(invoke=FakeInvoke())
    with pytest.raises(ResolveError):
        probe(AEFAddress(host="h", hub="u", agent="alpha"))


def test_empty_rung_raises_resolve_error():
    probe = termlink_probe(invoke=FakeInvoke())
    with pytest.raises(ResolveError):
        probe(AEFAddress())


# ── composition: usable directly as resolve()'s probe ────────────────────


def test_probe_drives_resolve_to_found():
    # session alive at the deepest rung -> resolve FOUND without climbing.
    fake = FakeInvoke({"ping": _ok({"ok": True, "state": "ready"})})
    probe = termlink_probe(invoke=fake)
    res = resolve(AEFAddress(host="h", hub="u", session="tl-live"), probe)
    assert res.outcome == "found"


def test_probe_indeterminate_propagates_to_resolve():
    # an unreachable session rung -> resolve INDETERMINATE, not NOT_FOUND.
    fake = FakeInvoke({"ping": _ret({"ok": False, "data": {}, "stdout": "", "stderr": "refused"})})
    probe = termlink_probe(invoke=fake)
    res = resolve(AEFAddress(host="h", hub="u", session="tl-x"), probe)
    assert res.outcome == "indeterminate"
