"""T-4494: a sidecar process (re)started with a clean env signs with the project key.

Origin: 832 msg dbd05180 on v1.8.14-be.3. `fw upgrade` stopped their receiver and
it came back at 15:25:11Z with parent pid 1 and a clean env. TERMLINK_IDENTITY_FILE
was unset, so mail went out on the shared host key again (their T-1204 after
v1.8.12, same class). claude-fw exports the key when the file exists (T-4454), but
the python restart paths (cron `ensure --all`, the supervisor, the receiver's own
entry) selected it only with SIDECAR_RAIL_IDENTITY=1, which is off by default.

Each restart here runs under `env -i` with nothing but PATH and PROJECT_ROOT, the
way cron and a parent-pid-1 respawn see the world. A fake `termlink` records the
env it is called with; nothing reaches a real hub.
"""
import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from lib.sidecar import identity  # noqa: E402

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
    print('{"topics": []}')
else:
    print("{}")
"""

# What a restarted process sees at entry: http_server.py / watcher.py / sidecar_cli.py
# call identity.apply() first, then spawn their children with respawn_env().
ENTRY = r"""
import json, os, sys
sys.path.insert(0, sys.argv[1])
from lib.sidecar import identity
identity.apply()
child = identity.respawn_env(root=os.environ["PROJECT_ROOT"])
print(json.dumps({"self": os.environ.get("TERMLINK_IDENTITY_FILE", ""),
                  "child": child.get("TERMLINK_IDENTITY_FILE", ""),
                  "marker": os.environ.get(identity.APPLIED_MARKER, "")}))
"""


@pytest.fixture
def project(tmp_path):
    (tmp_path / ".context").mkdir()
    (tmp_path / ".framework.yaml").write_text("RAIL_IDENTITY_FILE: .context/rail-identity.key\n")
    bindir = tmp_path / "bin"
    bindir.mkdir()
    tl = bindir / "termlink"
    tl.write_text(FAKE_TERMLINK)
    tl.chmod(0o755)
    return tmp_path


def _clean_env(root: Path, **extra) -> dict:
    """env -i: PATH and PROJECT_ROOT only, no inherited identity or session env."""
    env = {"PATH": f"{root / 'bin'}{os.pathsep}/usr/local/bin:/usr/bin:/bin",
           "PROJECT_ROOT": str(root), "FAKE_TL_LOG": str(root / "tl.jsonl")}
    env.update(extra)
    return env


def _entry(root: Path, **extra) -> dict:
    out = subprocess.run(["env", "-i", *(f"{k}={v}" for k, v in _clean_env(root, **extra).items()),
                          sys.executable, "-c", ENTRY, str(ROOT)],
                         cwd=str(root), capture_output=True, text=True, timeout=60)
    assert out.returncode == 0, out.stderr
    return json.loads(out.stdout.strip().splitlines()[-1])


def _key(root: Path, create: bool) -> Path:
    key = root / ".context" / "rail-identity.key"
    if create:
        key.write_text("secret")
        key.chmod(0o600)
    return key


def test_clean_env_restart_signs_with_existing_project_key(project):
    key = _key(project, create=True)
    got = _entry(project)
    assert got["self"] == str(key)
    assert got["child"] == str(key), "the respawned child (receiver/watcher) lost the key"
    assert got["marker"] == "", "an existing configured key is not a host->project transition"


def test_clean_env_restart_never_selects_a_missing_key(project):
    key = _key(project, create=False)
    got = _entry(project)
    assert got == {"self": "", "child": "", "marker": ""}
    assert not key.exists(), "a restart must not mint a keypair"


def test_switch_on_still_selects_a_missing_key_with_marker(project):
    # T-4311 behaviour is unchanged: with the switch on the key is created on first use.
    key = _key(project, create=False)
    got = _entry(project, FW_SIDECAR_RAIL_IDENTITY="1")
    assert got["self"] == got["child"] == got["marker"] == str(key)


def test_switch_default_stays_off():
    assert identity.enabled({}) is False


def test_clean_env_cli_restart_termlink_calls_carry_the_key(project):
    """End to end: a real sidecar_cli process under env -i, as cron runs it."""
    key = _key(project, create=True)
    subprocess.run(["env", "-i", *(f"{k}={v}" for k, v in _clean_env(project).items()),
                    sys.executable, str(ROOT / "lib" / "sidecar_cli.py"), "inbox", "--peek"],
                   cwd=str(project), capture_output=True, text=True, timeout=120)
    log = project / "tl.jsonl"
    calls = [json.loads(x) for x in log.read_text().splitlines()] if log.exists() else []
    assert calls, "the sidecar made no termlink call, so the test proves nothing"
    assert {c["TERMLINK_IDENTITY_FILE"] for c in calls} == {str(key)}


def test_ensure_all_child_does_not_inherit_another_projects_key(project):
    """`ensure --all` (respawn_env signing=False) starts children in OTHER projects. The
    caller's selectors must not reach them: by precedence they would beat the
    child's own RAIL_IDENTITY_FILE."""
    base = {"PATH": "/usr/bin", "TERMLINK_IDENTITY_FILE": "/projA/rail-identity.key",
            "TERMLINK_AGENT_ID": "a", "TERMLINK_IDENTITY_DIR": "/d",
            identity.APPLIED_MARKER: "/projA/rail-identity.key"}
    env = identity.respawn_env(base=base, root=str(project), signing=False)
    for k in (*identity.IDENTITY_ENV, identity.APPLIED_MARKER):
        assert k not in env, k
    assert env["PROJECT_ROOT"] == str(project)


def test_own_project_respawn_keeps_an_operator_chosen_key(project):
    """Precedence for the project's own respawn is unchanged (T-4311)."""
    _key(project, create=True)
    env = identity.respawn_env(base={"TERMLINK_IDENTITY_FILE": "/operator/chosen.key",
                                     "PROJECT_ROOT": str(project)}, root=str(project))
    assert env["TERMLINK_IDENTITY_FILE"] == "/operator/chosen.key"
