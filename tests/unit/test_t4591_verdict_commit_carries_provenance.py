"""T-4591 — a verdict commit must carry the provenance the row is verified against.

`_ledger_paths` staged VERDICTS/RECORDED/REFUSALS/APPLIED only. The dispatch registry, runs and
completions a row is checked against stayed uncommitted, so a `git stash` in the shared checkout
(2026-10-22, T-4578 worker) reset them to HEAD and 13 committed verdict rows stopped verifying
("dispatch ... is not in the review-dispatch registry"). A fresh clone had the same hole.
"""
import json
import subprocess
import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_HERE))

from lib import verdict_ledger as vl  # noqa: E402


def _git(root, *a):
    return subprocess.run(["git", *a], cwd=root, capture_output=True, text=True, check=True).stdout


def _repo(tmp_path):
    root = tmp_path / "proj"
    root.mkdir()
    _git(root, "init", "-q")
    _git(root, "config", "user.email", "t@t")
    _git(root, "config", "user.name", "t")
    (root / "README").write_text("x\n")
    _git(root, "add", "README")
    _git(root, "commit", "-qm", "init")
    return root


def _write(root, rel, rows):
    p = root / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text("".join(json.dumps(r) + "\n" for r in rows))


def test_provenance_files_are_staged_with_the_row(tmp_path):
    root = _repo(tmp_path)
    _write(root, vl.VERDICTS, [{"id": "V-1", "dispatch_id": "d-1"}])
    _write(root, vl.DISPATCHES, [{"dispatch_id": "d-1"}])
    _write(root, vl.RUNS, [{"kind": "run", "run_id": "r-1"}])
    _write(root, vl.COMPLETIONS, [{"dispatch_id": "d-1"}])
    paths = vl._ledger_paths(root, [])
    for rel in (vl.DISPATCHES, vl.RUNS, vl.COMPLETIONS):
        assert str(rel) in paths


def test_registry_row_survives_a_stash_after_the_verdict_commit(tmp_path):
    root = _repo(tmp_path)
    _write(root, vl.VERDICTS, [{"id": "V-1", "dispatch_id": "d-1"}])
    _write(root, vl.DISPATCHES, [{"dispatch_id": "d-1"}])
    sha, err = vl._commit_rows(root, vl._ledger_paths(root, []), "judge-x-worker",
                               "T-1: reviewer verdict")
    assert err == "" and sha
    files = set(_git(root, "show", "--name-only", "--format=", "HEAD").split())
    assert str(vl.DISPATCHES) in files
    # the 2026-10-22 trigger: another worker stashes the shared checkout
    (root / vl.DISPATCHES).write_text('{"dispatch_id": "d-1"}\n{"dispatch_id": "d-2"}\n')
    _git(root, "stash", "-q", "-u")
    assert any(r.get("dispatch_id") == "d-1" for r in vl._read(vl.DISPATCHES, root))


def test_control_absent_provenance_files_are_not_named(tmp_path):
    root = _repo(tmp_path)
    _write(root, vl.VERDICTS, [{"id": "V-1"}])
    assert vl._ledger_paths(root, []) == [str(vl.VERDICTS)]
