"""T-4482: the sidecar resolves the TermLink runtime dir the way the hub does."""
import json
import subprocess
from types import SimpleNamespace

from lib.sidecar import inject, runtime_dir


def _runner(by_dir, calls):
    def run(argv, **kw):
        d = (kw.get("env") or {}).get(runtime_dir.ENV)
        calls.append(d)
        return SimpleNamespace(returncode=0, stderr="",
                               stdout=json.dumps({"sessions": by_dir.get(d, [])}))
    return run


def test_resolve_prefers_env_then_hub_dir_then_default(tmp_path, monkeypatch):
    hub = tmp_path / "hub"
    hub.mkdir()
    monkeypatch.setattr(runtime_dir, "HUB_DIR", str(hub))
    assert runtime_dir.resolve({"TERMLINK_RUNTIME_DIR": "/x"})[0] == "/x"
    assert runtime_dir.resolve({})[0] == str(hub)
    monkeypatch.setattr(runtime_dir, "HUB_DIR", str(tmp_path / "absent"))
    assert runtime_dir.resolve({})[0] is None


def test_apply_exports_hub_dir_into_environment(tmp_path, monkeypatch):
    hub = tmp_path / "hub"
    hub.mkdir()
    monkeypatch.setattr(runtime_dir, "HUB_DIR", str(hub))
    env = {}
    runtime_dir.apply(env)
    assert env[runtime_dir.ENV] == str(hub)


def test_discover_uses_hub_dir_when_env_unset(tmp_path, monkeypatch):
    hub = tmp_path / "hub"
    hub.mkdir()
    monkeypatch.setattr(runtime_dir, "HUB_DIR", str(hub))
    monkeypatch.delenv(runtime_dir.ENV, raising=False)
    calls = []
    got = inject._discover(_runner({str(hub): [{"id": "s1"}]}, calls))
    assert got == [{"id": "s1"}] and calls == [str(hub)]


def test_zero_sessions_warns_naming_other_dir(tmp_path, monkeypatch):
    hub, mine = tmp_path / "hub", tmp_path / "mine"
    hub.mkdir()
    mine.mkdir()
    monkeypatch.setattr(runtime_dir, "HUB_DIR", str(hub))
    monkeypatch.setenv(runtime_dir.ENV, str(mine))
    events = []
    monkeypatch.setattr(inject.receiver, "record_event",
                        lambda mid, ev, **kw: events.append((ev, kw)))
    got = inject._discover(_runner({str(hub): [{"id": "s1"}]}, []))
    assert got == []
    assert events and events[0][0] == "RUNTIME_DIR_MISMATCH"
    assert str(hub) in events[0][1]["warning"]
