"""T-4890 (0506, found in T-4884): with inject on but no sidecar prompt hook registered, the
receiver typed "[sidecar] N peer messages waiting … the prompt hook shows it above" into the
session every ~2 minutes, forever: nothing printed the mail, so no hand-over was recorded.
The injector now checks for the hook first and records why it did not type.
"""
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parents[1]))

from lib.sidecar import inject, receiver  # noqa: E402
from test_sidecar_receiver_t3693 import (  # noqa: E402,F401  (env is a fixture)
    FakeTermlink, _ready_session, _sess, _store, env)

HOOK = {"type": "command", "command": "${CLAUDE_PROJECT_DIR}/bin/fw hook sidecar-receiver-adapter"}


def _settings(root: Path, name: str, hooks: dict) -> None:
    d = root / ".claude"
    d.mkdir(exist_ok=True)
    (d / name).write_text(json.dumps({"hooks": hooks}))


def _go(env, monkeypatch, name="t4890"):
    root = env.project(name)
    env.use(root)
    _store("m1")
    _ready_session(monkeypatch, "sess-x", "tl-x")
    tl = FakeTermlink([_sess("tl-x", ["claude", inject.project_tag()])])
    return root, tl


def test_no_prompt_hook_types_nothing_and_says_why(env, monkeypatch):
    root, tl = _go(env, monkeypatch)
    _settings(root, "settings.json", {"Stop": [{"hooks": [HOOK]}]})   # hook on the wrong event
    rep = inject.deliver_pending("test", runner=tl)
    assert tl.injects == []
    assert rep["injected"] == [] and rep["reason"].startswith("no prompt hook")
    assert "fw upgrade" in rep["reason"]
    blocked = [e for e in receiver.read_events("m1") if e.get("event") == "INJECT_BLOCKED"]
    assert len(blocked) == 1 and blocked[0]["reason"].startswith("no prompt hook")
    assert "m1" in receiver.awaiting_handover()          # not lost: alerts still lists it
    inject.deliver_pending("test", runner=tl)             # once per message and reason
    assert len([e for e in receiver.read_events("m1") if e.get("event") == "INJECT_BLOCKED"]) == 1


def test_hook_in_settings_json_injects_as_before(env, monkeypatch):
    root, tl = _go(env, monkeypatch)
    _settings(root, "settings.json", {"UserPromptSubmit": [{"hooks": [HOOK]}]})
    rep = inject.deliver_pending("test", runner=tl)
    assert rep["injected"] == ["m1"] and len(tl.injects) == 1


def test_hook_in_settings_local_json_counts(env, monkeypatch):
    root, tl = _go(env, monkeypatch)
    _settings(root, "settings.json", {})
    _settings(root, "settings.local.json", {"UserPromptSubmit": [{"hooks": [HOOK]}]})
    assert inject.deliver_pending("test", runner=tl)["injected"] == ["m1"]


def test_unreadable_settings_count_as_no_hook(env, monkeypatch):
    root, tl = _go(env, monkeypatch)
    (root / ".claude").mkdir(exist_ok=True)
    (root / ".claude" / "settings.json").write_text("{ not json")
    rep = inject.deliver_pending("test", runner=tl)
    assert tl.injects == [] and rep["reason"].startswith("no prompt hook")


def test_project_without_claude_settings_is_not_judged(env, monkeypatch):
    root, tl = _go(env, monkeypatch)
    assert inject.prompt_hook_missing(root) is False
    assert inject.deliver_pending("test", runner=tl)["injected"] == ["m1"]
