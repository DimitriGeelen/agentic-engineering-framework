"""T-3863 — a consumer that gitignores .context/ must still be able to commit, see and discard
its reviewer verdict rows.

050-email-archive (bug 944e3f91, 1.7.754): `.gitignore` had `/.context/*`, the worker's verdict
commit failed, the judge printed only "unknown — never committed", and from then on the
verdict-ledger audit FAILed every pre-push on the uncommitted row with no agent exit: removing the
row is a "deleted verdict" (recorded.jsonl still names it), and an uncommitted row cannot be
acknowledged. Only a human hand-editing two files unblocked them.
"""
import json
import subprocess
import sys
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_HERE))

from lib import verdict_ledger as vl  # noqa: E402


def _git(root, *a):
    return subprocess.run(["git", *a], cwd=root, capture_output=True, text=True, check=True).stdout


def _repo(tmp_path, ignore):
    root = tmp_path / "proj"
    root.mkdir()
    _git(root, "init", "-q")
    _git(root, "config", "user.email", "t@t")
    _git(root, "config", "user.name", "t")
    (root / ".gitignore").write_text(ignore)
    _git(root, "add", ".gitignore")
    _git(root, "commit", "-qm", "init")
    return root


def _pending(root, rid="V-1", task="T-1"):
    (root / vl.VERDICTS).parent.mkdir(parents=True, exist_ok=True)
    with open(root / vl.VERDICTS, "a") as f:
        f.write(json.dumps({"id": rid, "task": task, "ac": 1, "dispatch_id": "d-1"}) + "\n")
    with open(root / vl.RECORDED, "a") as f:
        f.write(json.dumps({"verdict_id": rid, "task": task, "ac": 1}) + "\n")


@pytest.mark.parametrize("ignore", ["/.context/*\n", ".context/\n", ".context\n"])
def test_ledger_commits_when_context_is_gitignored(tmp_path, ignore):
    root = _repo(tmp_path, ignore)
    _pending(root)
    sha, err = vl._commit_rows(root, vl._ledger_paths(root, []), "w", "T-1: reviewer verdict")
    assert err == "" and sha
    files = set(_git(root, "show", "--name-only", "--format=", "HEAD").split())
    assert str(vl.VERDICTS) in files and str(vl.RECORDED) in files


def test_a_failed_commit_is_journalled_and_named_in_the_uncommitted_fault(tmp_path, monkeypatch):
    root = _repo(tmp_path, "")
    _pending(root)
    # A pre-commit hook that refuses stands in for any git failure the worker cannot see past.
    hook = root / ".git" / "hooks" / "pre-commit"
    hook.write_text("#!/bin/sh\necho 'refused by test hook' >&2\nexit 1\n")
    hook.chmod(0o755)
    sha, err = vl._commit_rows(root, vl._ledger_paths(root, []), "w", "T-1: reviewer verdict",
                               ids=["V-1"], task="T-1", dispatch_id="d-1")
    assert sha == "" and "refused by test hook" in err
    rows = vl._read(vl.COMMIT_ERRORS, root)
    assert rows and rows[-1]["verdict_ids"] == ["V-1"] and "refused by test hook" in rows[-1]["error"]
    assert "refused by test hook" in vl.commit_error_for(root, "V-1")
    assert vl.commit_error_for(root, "V-other") == ""
    why = vl._uncommitted_why(root, {"id": "V-1"})
    assert "never committed" in why and "refused by test hook" in why and "verdict discard V-1" in why


def test_discard_removes_only_an_uncommitted_row_and_clears_the_audit_fail(tmp_path, monkeypatch):
    root = _repo(tmp_path, "")
    monkeypatch.delenv("CLAUDECODE", raising=False)
    _pending(root, "V-1")
    _git(root, "add", "-f", str(vl.VERDICTS), str(vl.RECORDED))
    _git(root, "commit", "-qm", "T-1: committed row")
    _pending(root, "V-2")
    code, lines = vl.audit(root)
    assert any("V-2" in ln and ln.startswith("FAIL") for ln in lines)
    with pytest.raises(vl.VerdictRefused, match="committed"):
        vl.discard("V-1", reason="x", root=root)
    with pytest.raises(vl.VerdictRefused, match="--reason"):
        vl.discard("V-2", reason=" ", root=root)
    out = vl.discard("V-2", reason="worker commit failed: .context ignored", root=root)
    assert out["discarded"] == "V-2"
    led = vl.load_ledger(root)
    assert not led.faults and not led.missing and not led.pending
    assert [r["id"] for r, _ in led.entries()] == ["V-1"]
    log = vl._read(vl.DISCARDED, root)
    assert log[-1]["row"]["id"] == "V-2" and log[-1]["reason"].startswith("worker commit failed")
    code, lines = vl.audit(root)
    assert not any("V-2" in ln and ln.startswith("FAIL") for ln in lines)


def test_discard_is_refused_to_an_agent_without_i_am_human(tmp_path, monkeypatch):
    root = _repo(tmp_path, "")
    _pending(root, "V-2")
    monkeypatch.setenv("CLAUDECODE", "1")
    with pytest.raises(vl.VerdictRefused, match="--i-am-human"):
        vl.discard("V-2", reason="x", root=root)
    assert vl.discard("V-2", reason="x", root=root, i_am_human=True)["discarded"] == "V-2"
