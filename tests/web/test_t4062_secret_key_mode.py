"""T-4062: _resolve_secret_key leaves the persisted key file owner-only (0600).

The key is written under tmp_path only — the live .context/working/.fw-secret-key
is never read or changed by these tests.
"""

import os
import stat
import subprocess
import shutil

import pytest

from web.app import _resolve_secret_key
from web.config import Config


@pytest.fixture(autouse=True)
def _no_env_key(monkeypatch):
    monkeypatch.setattr(Config, "SECRET_KEY", "")


def _key_file(root):
    d = root / ".context" / "working"
    d.mkdir(parents=True, exist_ok=True)
    return d / ".fw-secret-key"


def _mode(path):
    return stat.S_IMODE(os.stat(path).st_mode)


def test_generated_key_is_0600(tmp_path):
    key, source = _resolve_secret_key(tmp_path)
    kf = _key_file(tmp_path)
    assert source == "generated"
    assert _mode(kf) == 0o600
    assert kf.read_text() == key


def test_generated_key_is_never_group_or_world_readable(tmp_path, monkeypatch):
    # A permissive umask must not leave a window where the new file is readable.
    old = os.umask(0o000)
    try:
        _resolve_secret_key(tmp_path)
    finally:
        os.umask(old)
    assert _mode(_key_file(tmp_path)) == 0o600


def test_existing_0660_file_is_tightened_and_key_unchanged(tmp_path):
    kf = _key_file(tmp_path)
    kf.write_text("a" * 64)
    os.chmod(kf, 0o660)
    key, source = _resolve_secret_key(tmp_path)
    assert source == "file"
    assert key == "a" * 64
    assert _mode(kf) == 0o600
    assert kf.read_text() == "a" * 64


def test_existing_0644_file_is_tightened(tmp_path):
    kf = _key_file(tmp_path)
    kf.write_text("b" * 64)
    os.chmod(kf, 0o644)
    _resolve_secret_key(tmp_path)
    assert _mode(kf) == 0o600


@pytest.mark.skipif(shutil.which("setfacl") is None, reason="needs setfacl")
def test_existing_file_with_named_acl_grant_loses_it(tmp_path):
    kf = _key_file(tmp_path)
    kf.write_text("c" * 64)
    os.chmod(kf, 0o600)
    grant = subprocess.run(
        ["setfacl", "-m", "u:nobody:r", str(kf)], capture_output=True, check=False
    )
    if grant.returncode != 0:
        pytest.skip("filesystem does not support ACLs")
    _resolve_secret_key(tmp_path)
    listing = subprocess.run(
        ["getfacl", "-cp", str(kf)], capture_output=True, text=True, check=False
    ).stdout
    assert "nobody" not in listing
    assert _mode(kf) == 0o600
