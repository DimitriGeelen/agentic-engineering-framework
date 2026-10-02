"""T-3725: the sidecar receiver's token must never be committable.

write_token() writes .context/sidecar/.gitignore beside the token, so any
project that runs a receiver (vendored consumers included) ignores it.
"""
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "lib"))

from sidecar import lifecycle  # noqa: E402


def _git(cwd, *args):
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True)


def test_write_token_makes_token_git_ignored(tmp_path, monkeypatch):
    proj = tmp_path / "proj"
    sidecar = proj / ".context" / "sidecar"
    sidecar.mkdir(parents=True)
    _git(proj, "init", "-q")
    monkeypatch.setattr(lifecycle, "token_path", lambda: sidecar / "receiver.token")

    lifecycle.write_token()

    gi = (sidecar / ".gitignore").read_text()
    for entry in ("receiver.token", "receiver.token.tmp", "ready-for-input.yaml", "receiver/"):
        assert entry in gi.splitlines()
    r = _git(proj, "check-ignore", "-q", ".context/sidecar/receiver.token")
    assert r.returncode == 0, "receiver.token is not ignored by git"
    (sidecar / "ready-for-input.yaml").write_text("{}")
    assert _git(proj, "check-ignore", "-q", ".context/sidecar/ready-for-input.yaml").returncode == 0


def test_existing_gitignore_is_appended_not_replaced(tmp_path, monkeypatch):
    sidecar = tmp_path / ".context" / "sidecar"
    sidecar.mkdir(parents=True)
    (sidecar / ".gitignore").write_text("keep-me\nreceiver.token\n")
    monkeypatch.setattr(lifecycle, "token_path", lambda: sidecar / "receiver.token")

    lifecycle.write_token()
    lifecycle.write_token()  # idempotent

    lines = (sidecar / ".gitignore").read_text().splitlines()
    assert "keep-me" in lines
    assert lines.count("receiver.token") == 1
    assert lines.count("ready-for-input.yaml") == 1
