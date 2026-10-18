"""T-4108: fw issues security regressions (ring20-dashboard review of ed683536a)."""
import importlib.util
import json
import os
import stat
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
ISSUES_PY = ROOT / "lib" / "issues.py"
sys.path.insert(0, str(ROOT / "lib"))
import issues  # noqa: E402

# Operator terminal stand-in: only the ancestry probe is neutralised, in-process.
OPERATOR = ("import sys; sys.path.insert(0, %r); import issues; issues._agent_ancestry = lambda: False; "
            "sys.exit(issues.main(sys.argv[1:]))" % str(ROOT / "lib"))

GH_STUB = r'''#!/usr/bin/env python3
import json, os, sys
d = os.environ["STUB_DIR"]
args = sys.argv[1:]
open(os.path.join(d, "calls.log"), "a").write(json.dumps(args) + "\n")
def rd(n, default=""):
    p = os.path.join(d, n)
    return open(p).read() if os.path.exists(p) else default
if args[:2] == ["api", "user"]:
    sys.stdout.write(rd("login.txt", "maint") + "\n"); sys.exit(0)
if args[:2] == ["issue", "view"]:
    sys.stdout.write(rd("view.json", '{"author":{"login":"reporter"},"comments":[]}')); sys.exit(0)
if args[:2] == ["label", "list"]:
    sys.stdout.write("[]"); sys.exit(0)
if args[:2] == ["label", "create"]:
    sys.exit(0)
if args[:2] == ["issue", "comment"]:
    open(os.path.join(d, "body.txt"), "w").write(sys.stdin.read())
    print("https://github.com/o/r/issues/%s#issuecomment-1" % args[2]); sys.exit(0)
if args[:2] == ["issue", "edit"]:
    sys.exit(0)
sys.exit(9)
'''


@pytest.fixture
def env(tmp_path):
    stub = tmp_path / "stub"
    stub.mkdir()
    bindir = tmp_path / "bin"
    bindir.mkdir()
    gh = bindir / "gh"
    gh.write_text(GH_STUB)
    gh.chmod(gh.stat().st_mode | stat.S_IEXEC)
    e = dict(os.environ, PATH=f"{bindir}:{os.environ['PATH']}", STUB_DIR=str(stub),
             FW_ISSUES_DIR=str(tmp_path / "issues"), FW_ISSUES_REPO="o/r",
             FW_ISSUES_DECISIONS_STANDING_PERMISSION="0")
    for k in ("CLAUDECODE", "AI_AGENT", "CLAUDE_CODE_ENTRYPOINT"):
        e.pop(k, None)
    return e, stub, tmp_path / "issues"


def op(e, *args):
    return subprocess.run([sys.executable, "-c", OPERATOR, *args], env=e, capture_output=True, text=True)


def raw(e, *args):
    """No ancestry neutralised: the real probe runs."""
    return subprocess.run([sys.executable, str(ISSUES_PY), *args], env=e, capture_output=True, text=True)


APPROVE = ("approve", "AP-1", "--issue", "86", "--stage", "accepted")


def test_agent_env_with_i_am_human_is_refused(env):
    e, _, ledger = env
    for extra in ({"CLAUDECODE": "1"}, {"AI_AGENT": "claude"}, {"CLAUDE_CODE_ENTRYPOINT": "cli"}):
        r = op(dict(e, **extra), *APPROVE, "--i-am-human")
        assert r.returncode != 0 and "operator action" in r.stderr, extra
    assert not (ledger / "approvals.jsonl").exists()


def test_env_unset_does_not_escape_when_a_claude_ancestor_exists(monkeypatch):
    monkeypatch.delenv("CLAUDECODE", raising=False)
    monkeypatch.delenv("AI_AGENT", raising=False)
    monkeypatch.delenv("CLAUDE_CODE_ENTRYPOINT", raising=False)
    monkeypatch.setattr(issues, "_agent_ancestry", lambda: True)
    assert issues._is_agent() is True
    monkeypatch.setattr(issues, "_agent_ancestry", lambda: False)
    assert issues._is_agent() is False


def test_ancestry_probe_sees_a_claude_named_ancestor(tmp_path):
    fake = tmp_path / "claude"
    fake.write_text("#!/bin/sh\nexec \"$@\"\n")
    fake.chmod(0o755)
    code = ("import sys; sys.path.insert(0, %r); import issues; print(issues._agent_ancestry())"
            % str(ROOT / "lib"))
    e = {k: v for k, v in os.environ.items() if k not in ("CLAUDECODE", "AI_AGENT", "CLAUDE_CODE_ENTRYPOINT")}
    r = subprocess.run([str(fake), sys.executable, "-c", code], env=e, capture_output=True, text=True)
    assert r.stdout.strip() == "True", r.stderr


def test_human_override_rows_are_not_accepted(env, monkeypatch):
    e, _, ledger = env
    ledger.mkdir()
    (ledger / "approvals.jsonl").write_text(
        json.dumps({"ref": "AP-1", "issue": 86, "stage": "accepted", "by": "human-override"}) + "\n")
    monkeypatch.setenv("FW_ISSUES_DIR", str(ledger))
    assert issues._approval_ok("AP-1", 86, "accepted") is False
    (ledger / "approvals.jsonl").write_text(
        json.dumps({"ref": "AP-1", "issue": 86, "stage": "accepted", "by": "human"}) + "\n")
    assert issues._approval_ok("AP-1", 86, "accepted") is True


def test_operator_path_records_an_accepted_approval(env):
    e, _, ledger = env
    assert op(e, *APPROVE).returncode == 0
    rows = [json.loads(x) for x in (ledger / "approvals.jsonl").read_text().splitlines()]
    assert rows[0]["by"] == "human"
    agent = dict(e, CLAUDECODE="1")
    r = op(agent, "comment", "86", "--stage", "accepted", "--task", "T-1", "--approved-by-operator", "AP-1")
    assert r.returncode == 0, r.stderr


def test_third_party_marker_does_not_suppress_the_stage(env):
    e, stub, ledger = env
    marker = "<!-- aef-intake:stage=in-progress -->"
    (stub / "view.json").write_text(json.dumps({"author": {"login": "reporter"}, "comments": [
        {"author": {"login": "mallory"}, "body": marker}]}))
    r = op(e, "comment", "86", "--stage", "in-progress", "--task", "T-1")
    assert r.returncode == 0 and "already marked" not in r.stdout, r.stderr
    assert (stub / "body.txt").exists()


def test_maintainer_marker_still_suppresses(env):
    e, stub, ledger = env
    marker = "<!-- aef-intake:stage=in-progress -->"
    (stub / "view.json").write_text(json.dumps({"author": {"login": "reporter"}, "comments": [
        {"author": {"login": "maint"}, "body": marker}]}))
    r = op(e, "comment", "87", "--stage", "in-progress", "--task", "T-1")
    assert r.returncode == 0 and "already marked" in r.stdout
    assert not (stub / "body.txt").exists()
