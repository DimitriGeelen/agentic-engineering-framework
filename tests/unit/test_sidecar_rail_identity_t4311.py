"""T-4311: every termlink call lib/sidecar makes signs with RAIL_IDENTITY_FILE when configured.

Origin: 832 T-1151 consult — lib/rail-identity.sh resolved RAIL_IDENTITY_FILE but only
`fw rail post` applied it, so sidecar mail was signed with the host-shared key unless
TERMLINK_IDENTITY_FILE happened to be exported. A fake `termlink` on PATH records the env
it is called with; nothing reaches a real hub.
"""
import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from lib.sidecar import dm, identity, inbox  # noqa: E402

HOST_FP = "hostfp"
OWN_FP = "ownfp"
SCRUB = (*identity.IDENTITY_ENV, identity.APPLIED_MARKER, "FW_SIDECAR_IDENTITY_FP",
         "FW_SIDECAR_RAIL_IDENTITY", "FW_RAIL_IDENTITY_FILE", "FW_SIDECAR_HOST_DM_TRANSITION")

FAKE_TERMLINK = r"""#!/usr/bin/env python3
import json, os, sys
with open(os.environ["FAKE_TL_LOG"], "a") as f:
    f.write(json.dumps({"argv": sys.argv[1:],
                        "TERMLINK_IDENTITY_FILE": os.environ.get("TERMLINK_IDENTITY_FILE", "")}) + "\n")
a = sys.argv[1:]
if a[:1] == ["whoami"]:
    fp = "ownfp" if os.environ.get("TERMLINK_IDENTITY_FILE") else "hostfp"
    print(json.dumps({"session": {"identity_fingerprint": fp}}))
elif a[:2] == ["channel", "list"]:
    print(os.environ.get("FAKE_TL_TOPICS", '{"topics": []}'))
elif a[:2] == ["channel", "subscribe"]:
    cur = int(a[a.index("--cursor") + 1])
    for o in range(cur, 5):
        print(json.dumps({"offset": o, "msg_type": "post", "sender_id": "peer", "payload": "hi"}))
else:
    print("{}")
"""


@pytest.fixture
def project(tmp_path, monkeypatch):
    """A project dir, a fake termlink first on PATH, and no inherited identity env."""
    bindir = tmp_path / "bin"
    bindir.mkdir()
    tl = bindir / "termlink"
    tl.write_text(FAKE_TERMLINK)
    tl.chmod(0o755)
    log = tmp_path / "termlink-calls.jsonl"
    monkeypatch.setenv("PATH", f"{bindir}{os.pathsep}{os.environ['PATH']}")
    monkeypatch.setenv("FAKE_TL_LOG", str(log))
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    for k in SCRUB:
        monkeypatch.delenv(k, raising=False)
    monkeypatch.setattr(inbox.outbox, "_root", lambda: tmp_path)
    tmp_path.joinpath(".context").mkdir()
    yield tmp_path
    for k in SCRUB:   # identity.apply() writes os.environ directly
        os.environ.pop(k, None)


def _configure(root: Path, switch: str | None = "1"):
    lines = ["RAIL_IDENTITY_FILE: .context/rail-identity.key"]
    if switch is not None:
        lines.append(f"SIDECAR_RAIL_IDENTITY: {switch}")
    (root / ".framework.yaml").write_text("\n".join(lines) + "\n")
    return str(root / ".context" / "rail-identity.key")


def _calls(root: Path) -> list[dict]:
    log = root / "termlink-calls.jsonl"
    return [json.loads(x) for x in log.read_text().splitlines()] if log.exists() else []


# ── termlink_env: the one place the identity is decided ─────────────────────

def test_off_by_default_even_with_rail_identity_configured(project):
    _configure(project, switch=None)
    assert "TERMLINK_IDENTITY_FILE" not in identity.termlink_env({"PROJECT_ROOT": str(project)})


def test_switch_on_selects_configured_file_relative_to_project(project):
    key = _configure(project)
    env = identity.termlink_env({"PROJECT_ROOT": str(project)})
    assert env["TERMLINK_IDENTITY_FILE"] == key
    assert env[identity.APPLIED_MARKER] == key


def test_env_tier_wins_over_framework_yaml(project):
    _configure(project)
    env = identity.termlink_env({"FW_RAIL_IDENTITY_FILE": "/abs/other.key"})
    assert env["TERMLINK_IDENTITY_FILE"] == "/abs/other.key"


@pytest.mark.parametrize("var", identity.IDENTITY_ENV)
def test_already_set_selector_keeps_precedence(project, var):
    _configure(project)
    env = identity.termlink_env({var: "chosen"})
    assert env.get("TERMLINK_IDENTITY_FILE", "") == ("chosen" if var == "TERMLINK_IDENTITY_FILE" else "")
    assert identity.APPLIED_MARKER not in env


def test_no_rail_identity_configured_changes_nothing(project):
    (project / ".framework.yaml").write_text("SIDECAR_RAIL_IDENTITY: 1\n")
    assert identity.termlink_env({}) == {}


# ── end to end: a real sidecar process, a recording termlink ────────────────

def _run_cli(root, *args):
    return subprocess.run([sys.executable, str(ROOT / "lib" / "sidecar_cli.py"), *args],
                          cwd=str(root), env=dict(os.environ), capture_output=True,
                          text=True, timeout=120)


def test_sidecar_cli_termlink_calls_sign_with_project_key(project):
    key = _configure(project)
    _run_cli(project, "inbox", "--peek")
    calls = _calls(project)
    assert calls, "the sidecar made no termlink call — the test proves nothing"
    assert {c["TERMLINK_IDENTITY_FILE"] for c in calls} == {key}


def test_sidecar_cli_unchanged_when_switch_off(project):
    _configure(project, switch=None)
    _run_cli(project, "inbox", "--peek")
    calls = _calls(project)
    assert calls
    assert {c["TERMLINK_IDENTITY_FILE"] for c in calls} == {""}


def test_exported_identity_keeps_precedence_end_to_end(project, monkeypatch):
    _configure(project)
    monkeypatch.setenv("TERMLINK_IDENTITY_FILE", "/operator/chosen.key")
    _run_cli(project, "inbox", "--peek")
    assert {c["TERMLINK_IDENTITY_FILE"] for c in _calls(project)} == {"/operator/chosen.key"}


@pytest.mark.parametrize("module,argv", [
    ("lib.sidecar.watcher", ["usage"]),        # usage exit, after apply()
    ("lib.sidecar.hooks", ["usage"]),          # unknown hook, after apply()
    ("lib.sidecar.http_server", []),           # argparse exit, after apply()
    ("lib.sidecar_cli", ["--help"]),
])
def test_every_entry_point_installs_the_identity(project, module, argv):
    key = _configure(project)
    code = (f"import os, sys; sys.path.insert(0, {str(ROOT)!r}); import {module} as m\n"
            f"try:\n    m.main({argv!r})\nexcept SystemExit:\n    pass\n"
            "print('IDENT=' + os.environ.get('TERMLINK_IDENTITY_FILE', ''))")
    out = subprocess.run([sys.executable, "-c", code], cwd=str(project), env=dict(os.environ),
                         stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=60)
    assert f"IDENT={key}" in out.stdout, out.stdout + out.stderr


def test_inject_main_installs_the_identity():
    src = (ROOT / "lib" / "sidecar" / "inject.py").read_text()
    main_block = src[src.index('if __name__ == "__main__":'):]
    assert "identity.apply()" in main_block


# ── DM transition: the host-key rails are not lost ─────────────────────────

HOST_RAIL = {"name": f"dm:peer:{HOST_FP}", "count": 5, "latest_offset": 4}
OWN_RAIL = {"name": f"dm:peer:{OWN_FP}", "count": 5, "latest_offset": 4}
OTHER_RAIL = {"name": "dm:peer:someoneelse", "count": 5, "latest_offset": 4}
LISTER = lambda: [HOST_RAIL, OWN_RAIL, OTHER_RAIL]  # noqa: E731


def test_switch_keeps_old_host_rails_and_their_cursors(project):
    _configure(project)
    assert identity.apply() is not None
    assert dm.legacy_host_fingerprint() == HOST_FP
    names = {t["name"] for t in dm.rails_for_key(lister=LISTER)}
    assert names == {HOST_RAIL["name"], OWN_RAIL["name"]}

    state = inbox.load_state()
    state["topics"][HOST_RAIL["name"]] = {"cursor": 3}   # read before the switch
    inbox.save_state(state)
    got = dm.pending(lister=LISTER, advance=True)
    by_topic = {}
    for p in got:
        by_topic.setdefault(p["topic"], []).append(p["offset"])
    assert by_topic[HOST_RAIL["name"]] == [3, 4]          # resumes where it was
    assert by_topic[OWN_RAIL["name"]] == [0, 1, 2, 3, 4]  # new rail, fresh cursor
    topics = inbox.load_state()["topics"]
    assert topics[HOST_RAIL["name"]]["cursor"] == 5
    assert topics[OWN_RAIL["name"]]["cursor"] == 5


def test_transition_off_drops_host_rails(project, monkeypatch):
    _configure(project)
    identity.apply()
    monkeypatch.setenv("FW_SIDECAR_HOST_DM_TRANSITION", "0")
    assert dm.legacy_host_fingerprint() is None
    assert {t["name"] for t in dm.rails_for_key(lister=LISTER)} == {OWN_RAIL["name"]}


def test_operator_exported_identity_is_not_a_transition(project, monkeypatch):
    monkeypatch.setenv("TERMLINK_IDENTITY_FILE", "/operator/chosen.key")
    assert dm.legacy_host_fingerprint() is None
    assert {t["name"] for t in dm.rails_for_key(lister=LISTER)} == {OWN_RAIL["name"]}


def test_switch_off_rails_unchanged(project):
    _configure(project, switch=None)
    assert identity.apply() is None
    assert {t["name"] for t in dm.rails_for_key(lister=LISTER)} == {HOST_RAIL["name"]}
