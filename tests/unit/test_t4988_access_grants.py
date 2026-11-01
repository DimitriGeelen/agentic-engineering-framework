"""T-4988: lib/access_grants.py — validation, HEAD-only loading, audit trailer, doctor lines."""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "lib"))

import access_grants as ag  # noqa: E402

OK = {"grants": [{"path": "/srv/s/ro", "level": "read", "via": "/srv/s"}], "never_write": ["/srv/admin"]}


def _repo(tmp_path: Path, text: str | None, trailer: bool = True) -> Path:
    root = tmp_path / "proj"
    (root / "policy").mkdir(parents=True)
    subprocess.run(["git", "init", "-q", str(root)], check=True)
    (root / "README").write_text("x\n")
    if text is not None:
        (root / ag.GRANT_FILE).write_text(text)
    subprocess.run(["git", "-C", str(root), "add", "-A"], check=True)
    msg = ["-m", "grants"] + (["-m", ag.TRAILER] if trailer else [])
    subprocess.run(["git", "-C", str(root), "-c", "user.name=t", "-c", "user.email=t@t",
                    "commit", "-q", *msg], check=True)
    ag._PRESENT.clear()
    return root


def test_valid_file_validates():
    grants, never, errors = ag.validate(OK)
    assert errors == [] and grants[0]["level"] == "read" and never == ["/srv/admin"]


@pytest.mark.parametrize("bad, fragment", [
    ({"grants": [{"path": "rel/x", "level": "read", "via": "/srv"}]}, "path must be absolute"),
    ({"grants": [{"path": "/srv/../etc", "level": "read", "via": "/srv"}]}, "path must be absolute"),
    ({"grants": [{"path": "/", "level": "read", "via": "/"}]}, "path must be absolute"),
    ({"grants": [{"path": "/srv/x", "level": "write", "via": "/srv"}]}, "level must be one of"),
    ({"grants": [{"path": "/srv/x", "level": "read", "via": "/mnt"}]}, "is not under its via"),
    ({"grants": [{"path": "/srv/a", "level": "read", "via": "/srv"},
                 {"path": "/srv/a/b", "level": "create", "via": "/srv"}]}, "overlap"),
    ({"grants": [{"path": "/srv/admin/x", "level": "create", "via": "/srv"}],
      "never_write": ["/srv/admin"]}, "under never_write"),
    ({"never_write": "/srv/admin"}, "never_write must be a list"),
    ({"grants": [], "extra": 1}, "unknown key"),
])
def test_invalid_files_are_named(bad, fragment):
    _, _, errors = ag.validate(bad)
    assert any(fragment in e for e in errors), errors


def test_loaded_from_head_only(tmp_path):
    root = _repo(tmp_path, "grants:\n  - {path: /srv/s/ro, level: read, via: /srv/s}\n")
    (root / ag.GRANT_FILE).write_text("grants:\n  - {path: /srv/other, level: read, via: /srv/other}\n")
    assert ag.read_paths(str(root)) == ["/srv/s/ro"]


def test_invalid_committed_file_grants_nothing_but_keeps_never_write(tmp_path):
    root = _repo(tmp_path, "grants:\n  - {path: x, level: read, via: /srv}\nnever_write: [/srv/admin]\n")
    st = ag.load(str(root))
    assert st["grants"] == [] and st["errors"] and st["never_write"] == ["/srv/admin"]


def test_no_file_means_no_grants_and_no_guard(tmp_path):
    root = _repo(tmp_path, None)
    assert ag.load(str(root))["present"] is False
    assert not ag.is_grant_file_or_ancestor(str(root / "policy"), str(root))


def test_guard_covers_file_and_policy_dir_not_the_root(tmp_path):
    root = _repo(tmp_path, "grants: []\n")
    r = str(root)
    assert ag.is_grant_file_or_ancestor(f"{r}/policy/access-grants.yaml", r)
    assert ag.is_grant_file_or_ancestor(f"{r}/policy", r)
    assert not ag.is_grant_file_or_ancestor(r, r)
    assert not ag.is_grant_file_or_ancestor(f"{r}/policy/other.yaml", r)
    assert not ag.is_grant_file_or_ancestor("/srv/policy/access-grants.yaml", r)


def test_audit_names_a_commit_without_the_trailer(tmp_path):
    root = _repo(tmp_path, "grants: []\n", trailer=True)
    assert ag.audit(str(root)) == []
    (root / ag.GRANT_FILE).write_text("grants: []\nnever_write: [/srv/admin]\n")
    subprocess.run(["git", "-C", str(root), "-c", "user.name=t", "-c", "user.email=t@t",
                    "commit", "-qam", "agent edit"], check=True)
    lines = ag.audit(str(root))
    assert len(lines) == 1 and "agent edit" in lines[0] and ag.TRAILER in lines[0]


def test_doctor_warns_on_a_via_that_is_not_a_mount(tmp_path):
    root = _repo(tmp_path, "grants:\n  - {path: /srv/s/ro, level: read, via: /srv/s}\n")
    lines = ag.doctor(str(root))
    assert any(ln.startswith("WARN") and "not a mount point" in ln for ln in lines), lines
