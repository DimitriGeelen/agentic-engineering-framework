"""T-4088: fw issues close — internal issues only, one comment, idempotent. Stubbed gh, no network."""
import json
import os
import stat
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
ISSUES_PY = ROOT / "lib" / "issues.py"

GH_STUB = r'''#!/usr/bin/env python3
import json, os, sys
d = os.environ["STUB_DIR"]
args = sys.argv[1:]
open(os.path.join(d, "calls.log"), "a").write(json.dumps(args) + "\n")
def rd(n, default=""):
    p = os.path.join(d, n)
    return open(p).read() if os.path.exists(p) else default
if args[:2] == ["issue", "view"]:
    if "state,author" in args:
        sys.stdout.write(rd("state.json", '{"state":"OPEN","author":{"login":"o"}}'))
    else:
        sys.stdout.write(rd("view.json", '{"author":{"login":"o"},"comments":[]}'))
    sys.exit(0)
if args[:2] == ["issue", "comment"]:
    open(os.path.join(d, "body.txt"), "w").write(sys.stdin.read())
    print("https://github.com/o/r/issues/%s#issuecomment-1" % args[2]); sys.exit(0)
if args[:2] == ["issue", "close"]:
    if os.path.exists(os.path.join(d, "fail_close")):
        sys.stderr.write("nope"); sys.exit(1)
    sys.exit(0)
sys.exit(9)
'''

FOOTER = ("*These status updates are automated, but Dimitri personally looks at every issue "
          "and decides what happens to it. Replies on this issue are read.*")


@pytest.fixture
def env(tmp_path):
    stub = tmp_path / "stub"
    stub.mkdir()
    bindir = tmp_path / "bin"
    bindir.mkdir()
    gh = bindir / "gh"
    gh.write_text(GH_STUB)
    gh.chmod(gh.stat().st_mode | stat.S_IEXEC)
    ledger = tmp_path / "issues"
    e = dict(os.environ, PATH=f"{bindir}:{os.environ['PATH']}", STUB_DIR=str(stub),
             FW_ISSUES_DIR=str(ledger), FW_ISSUES_REPO="o/r", FW_ISSUES_GIT_REMOTE="github")
    e.pop("CLAUDECODE", None)
    return e, stub, ledger


def run(env_, *args, cwd=None):
    return subprocess.run([sys.executable, str(ISSUES_PY), *args], env=env_, cwd=cwd,
                          capture_output=True, text=True)


def calls(stub):
    p = stub / "calls.log"
    return [json.loads(x) for x in p.read_text().splitlines()] if p.exists() else []


def rows(ledger):
    p = ledger / "intake.jsonl"
    return [json.loads(x) for x in p.read_text().splitlines()] if p.exists() else []


def _git(cwd, *a):
    subprocess.run(["git", *a], cwd=cwd, check=True, capture_output=True,
                   env=dict(os.environ, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@t",
                            GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@t"))


@pytest.fixture
def repo(tmp_path):
    bare = tmp_path / "mirror.git"
    work = tmp_path / "work"
    work.mkdir()
    subprocess.run(["git", "init", "-q", "--bare", str(bare)], check=True)
    _git(work, "init", "-q", "-b", "bleeding-edge")
    _git(work, "remote", "add", "github", str(bare))
    (work / "a").write_text("1")
    _git(work, "add", "a")
    _git(work, "commit", "-qm", "one")
    _git(work, "push", "-q", "github", "bleeding-edge")
    on = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=work, text=True).strip()
    (work / "a").write_text("2")
    _git(work, "commit", "-qam", "two")
    local = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=work, text=True).strip()
    return work, on, local


def test_fixed_comment_footer_ledger_and_close(env, repo):
    e, stub, ledger = env
    work, on, _ = repo
    r = run(e, "close", "8", "--as", "fixed", "--task", "T-518", "--commit", on, cwd=work)
    assert r.returncode == 0, r.stderr
    body = (stub / "body.txt").read_text()
    assert body.startswith("<!-- aef-intake:stage=closed-fixed -->")
    assert f"Fixed under **T-518** in commit {on}" in body and body.rstrip().endswith(FOOTER)
    row = rows(ledger)[0]
    assert row["issue"] == 8 and row["stage"] == "closed-fixed" and row["commit"] == on
    assert row["comment"].startswith("https://")
    assert ["issue", "close", "8", "--repo", "o/r", "--reason", "completed"] in calls(stub)


def test_external_issue_is_never_touched(env, repo):
    e, stub, ledger = env
    work, on, _ = repo
    (stub / "state.json").write_text('{"state":"OPEN","author":{"login":"stranger"}}')
    r = run(e, "close", "90", "--as", "fixed", "--task", "T-1", "--commit", on, cwd=work)
    assert r.returncode != 0 and "not an internal issue" in r.stderr
    assert not (stub / "body.txt").exists() and rows(ledger) == []
    assert not [c for c in calls(stub) if c[:2] in (["issue", "comment"], ["issue", "close"])]


def test_already_closed_is_skipped(env, repo):
    e, stub, ledger = env
    work, on, _ = repo
    (stub / "state.json").write_text('{"state":"CLOSED","author":{"login":"o"}}')
    r = run(e, "close", "8", "--as", "fixed", "--task", "T-518", "--commit", on, cwd=work)
    assert r.returncode == 0 and "skipped" in r.stdout
    assert not (stub / "body.txt").exists() and rows(ledger) == []


def test_fixed_commit_must_be_on_mirror(env, repo):
    e, stub, ledger = env
    work, _, local = repo
    r = run(e, "close", "8", "--as", "fixed", "--task", "T-518", "--commit", local, cwd=work)
    assert r.returncode != 0 and "not on github/bleeding-edge" in r.stderr
    assert not (stub / "body.txt").exists() and rows(ledger) == []


def test_rerun_after_failed_close_does_not_comment_twice(env, repo):
    e, stub, ledger = env
    work, on, _ = repo
    (stub / "fail_close").write_text("")
    r = run(e, "close", "8", "--as", "fixed", "--task", "T-518", "--commit", on, cwd=work)
    assert r.returncode == 3 and "closing failed" in r.stderr
    assert len(rows(ledger)) == 1
    (stub / "fail_close").unlink()
    r = run(e, "close", "8", "--as", "fixed", "--task", "T-518", "--commit", on, cwd=work)
    assert r.returncode == 0, r.stderr
    assert len(rows(ledger)) == 1
    assert len([c for c in calls(stub) if c[:2] == ["issue", "comment"]]) == 1
    assert len([c for c in calls(stub) if c[:2] == ["issue", "close"]]) == 2


def test_duplicate_links_original_and_closes_not_planned(env):
    e, stub, ledger = env
    r = run(e, "close", "72", "--as", "duplicate", "--of", "70")
    assert r.returncode == 0, r.stderr
    assert "Duplicate of #70." in (stub / "body.txt").read_text()
    assert rows(ledger)[0]["stage"] == "closed-duplicate" and rows(ledger)[0]["of"] == 70
    assert ["issue", "close", "72", "--repo", "o/r", "--reason", "not planned"] in calls(stub)


def test_readback_marker_prevents_second_comment(env, repo):
    e, stub, ledger = env
    work, on, _ = repo
    (stub / "view.json").write_text(json.dumps({"author": {"login": "o"}, "comments": [
        {"author": {"login": "someone"}, "body": "<!-- aef-intake:stage=closed-fixed -->"}]}))
    r = run(e, "close", "8", "--as", "fixed", "--task", "T-518", "--commit", on, cwd=work)
    assert r.returncode == 0 and "already carries" in r.stdout
    assert not (stub / "body.txt").exists()


def test_dry_run_posts_and_closes_nothing(env, repo):
    e, stub, ledger = env
    work, on, _ = repo
    r = run(e, "close", "8", "--as", "fixed", "--task", "T-518", "--commit", on, "--dry-run", cwd=work)
    assert r.returncode == 0 and "Fixed under" in r.stdout
    assert rows(ledger) == []
    assert not [c for c in calls(stub) if c[:2] in (["issue", "comment"], ["issue", "close"])]


def test_bad_arguments_rejected(env):
    e, stub, ledger = env
    assert run(e, "close", "8", "--as", "fixed", "--task", "T-1").returncode != 0
    assert run(e, "close", "8", "--as", "duplicate").returncode != 0
    assert run(e, "close", "8", "--as", "fixed", "--task", "x; rm", "--commit", "abcdef1").returncode != 0
    assert calls(stub) == []
