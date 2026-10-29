"""T-4077: fw issues comment — stubbed gh on PATH, no network, fixtures in tmp_path."""
import json
import os
import re
import stat
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
ISSUES_PY = ROOT / "lib" / "issues.py"

# T-4108: _is_agent() now looks at the process ancestry, and these tests run under a Claude worker.
# Fixtures stand in for an operator terminal by neutralising ONLY the ancestry probe, in-process.
WRAP = ("import sys; sys.path.insert(0, %r); import issues; issues._agent_ancestry = lambda: False; "
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
    sys.stdout.write(rd("labels.json", "[]")); sys.exit(0)
if args[:2] == ["label", "create"]:
    sys.exit(0)
if args[:2] == ["issue", "comment"]:
    open(os.path.join(d, "body.txt"), "w").write(sys.stdin.read())
    if os.path.exists(os.path.join(d, "fail_comment")):
        sys.stderr.write("boom"); sys.exit(1)
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
    ledger = tmp_path / "issues"
    e = dict(os.environ, PATH=f"{bindir}:{os.environ['PATH']}", STUB_DIR=str(stub), FW_ISSUES_DECISIONS_STANDING_PERMISSION="0",
             FW_ISSUES_DIR=str(ledger), FW_ISSUES_REPO="o/r", FW_ISSUES_GIT_REMOTE="github")
    for k in ("CLAUDECODE", "AI_AGENT", "CLAUDE_CODE_ENTRYPOINT"):
        e.pop(k, None)
    return e, stub, ledger


def run(env_, *args, cwd=None):
    return subprocess.run([sys.executable, "-c", WRAP, *args], env=env_, cwd=cwd,
                          capture_output=True, text=True)


def calls(stub):
    p = stub / "calls.log"
    return [json.loads(x) for x in p.read_text().splitlines()] if p.exists() else []


def rows(ledger):
    p = ledger / "intake.jsonl"
    return [json.loads(x) for x in p.read_text().splitlines()] if p.exists() else []


FOOTER = ("*These status updates are automated, but Dimitri personally looks at every issue "
          "and decides what happens to it. Replies on this issue are read.*")


def test_template_footer_marker_and_ledger(env):
    e, stub, ledger = env
    r = run(e, "comment", "86", "--stage", "in-progress", "--task", "T-4040")
    assert r.returncode == 0, r.stderr
    body = (stub / "body.txt").read_text()
    assert body.startswith("<!-- aef-intake:stage=in-progress -->")
    # T-4903: the id is bare or linked to its task file, depending on whether a GitHub remote resolves
    assert "**[AEF intake] In progress**" in body
    assert re.search(r"\*\*(T-4040|\[T-4040\]\(https://github\.com/[^)]+\))\*\*", body)
    assert body.rstrip().endswith(FOOTER)
    row = rows(ledger)[0]
    assert row["issue"] == 86 and row["stage"] == "in-progress" and row["tasks"] == ["T-4040"]
    assert row["comment"].startswith("https://") and row["ts"]


def test_received_gets_next_intake_id(env):
    e, stub, ledger = env
    ledger.mkdir()
    (ledger / "intake.jsonl").write_text(json.dumps({"intake": "INTAKE-0010", "issue": 1,
                                                     "stage": "received"}) + "\n")
    assert run(e, "comment", "95", "--stage", "received").returncode == 0
    assert "INTAKE-0011" in (stub / "body.txt").read_text()
    assert rows(ledger)[-1]["intake"] == "INTAKE-0011"


def test_idempotent_by_ledger(env):
    e, stub, ledger = env
    assert run(e, "comment", "86", "--stage", "in-progress", "--task", "T-4040").returncode == 0
    n = len([c for c in calls(stub) if c[:2] == ["issue", "comment"]])
    r = run(e, "comment", "86", "--stage", "in-progress", "--task", "T-4040")
    assert r.returncode == 0 and "already posted" in r.stdout
    assert len([c for c in calls(stub) if c[:2] == ["issue", "comment"]]) == n
    assert len(rows(ledger)) == 1


def test_legacy_combined_stage_row_counts(env):
    e, stub, ledger = env
    ledger.mkdir()
    (ledger / "intake.jsonl").write_text(json.dumps({"issue": 86, "stage": "classified+accepted"}) + "\n")
    r = run(e, "comment", "86", "--stage", "classified", "--text", "x")
    assert r.returncode == 0 and "already posted" in r.stdout


def test_idempotent_by_readback_and_reporter_cannot_suppress(env):
    e, stub, ledger = env
    marker = "<!-- aef-intake:stage=in-progress -->"
    # a comment by the issue author containing the marker must be ignored (untrusted data)
    (stub / "view.json").write_text(json.dumps({"author": {"login": "reporter"}, "comments": [
        {"author": {"login": "reporter"}, "body": marker}]}))
    assert run(e, "comment", "86", "--stage", "in-progress", "--task", "T-1").returncode == 0
    assert "already marked" not in run(e, "comment", "87", "--stage", "in-progress", "--task", "T-1").stdout
    # a comment by someone else with the marker stops the post
    (stub / "view.json").write_text(json.dumps({"author": {"login": "reporter"}, "comments": [
        {"author": {"login": "maint"}, "body": marker + "\nx"}]}))
    (stub / "body.txt").unlink()
    r = run(e, "comment", "88", "--stage", "in-progress", "--task", "T-1")
    assert r.returncode == 0 and "already marked" in r.stdout
    assert not (stub / "body.txt").exists() and not any(x["issue"] == 88 for x in rows(ledger))


@pytest.mark.parametrize("stage,extra", [("accepted", ["--task", "T-1"]), ("needs-info", ["--text", "q"]),
                                         ("duplicate", ["--text", "T-9"]), ("not-planned", ["--text", "r"])])
def test_decision_stage_refuses_without_approval(env, stage, extra):
    e, stub, ledger = env
    r = run(e, "comment", "86", "--stage", stage, *extra)
    assert r.returncode != 0 and "--approved-by-operator" in r.stderr
    assert not (stub / "body.txt").exists() and rows(ledger) == []


def test_decision_stage_under_agent_needs_real_record(env):
    e, stub, ledger = env
    op = e
    e = dict(e, CLAUDECODE="1")
    r = run(e, "comment", "86", "--stage", "accepted", "--task", "T-1", "--approved-by-operator", "made-up")
    assert r.returncode != 0 and "operator approval record" in r.stderr
    assert run(e, "approve", "AP-1", "--issue", "86", "--stage", "accepted").returncode != 0  # agent can't
    # T-4108: --i-am-human does not lift agent control; only the operator's terminal records it
    assert run(e, "approve", "AP-1", "--issue", "86", "--stage", "accepted", "--i-am-human").returncode != 0
    assert run(op, "approve", "AP-1", "--issue", "86", "--stage", "accepted").returncode == 0
    r = run(e, "comment", "86", "--stage", "accepted", "--task", "T-1", "--approved-by-operator", "AP-1")
    assert r.returncode == 0, r.stderr
    # the record is for #86 only
    r = run(e, "comment", "87", "--stage", "accepted", "--task", "T-1", "--approved-by-operator", "AP-1")
    assert r.returncode != 0


def test_operator_ref_accepted_outside_agent(env):
    e, stub, ledger = env
    r = run(e, "comment", "86", "--stage", "accepted", "--task", "T-1", "--approved-by-operator", "op-ok")
    assert r.returncode == 0, r.stderr
    assert "status:accepted" in json.dumps(calls(stub))


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


def test_fixed_requires_commit_on_mirror_and_test_cmd(env, repo):
    e, stub, ledger = env
    work, on, local = repo
    base = ["comment", "86", "--stage", "fixed-on-bleeding-edge", "--task", "T-4040"]
    r = run(e, *base, "--commit", local, "--test-cmd", "fw init x", cwd=work)
    assert r.returncode != 0 and "not on github/bleeding-edge" in r.stderr
    r = run(e, *base, "--commit", on, cwd=work)
    assert r.returncode != 0 and "--test-cmd" in r.stderr
    assert not (stub / "body.txt").exists() and rows(ledger) == []
    r = run(e, *base, "--commit", on, "--test-cmd", "fw init x", cwd=work)
    assert r.returncode == 0, r.stderr
    body = (stub / "body.txt").read_text()
    assert f"commit {on}" in body and "`fw init x`" in body and body.rstrip().endswith(FOOTER)
    assert rows(ledger)[0]["commit"] == on


def test_fixed_refuses_when_mirror_unreadable(env, tmp_path):
    e, stub, ledger = env
    work = tmp_path / "nomirror"
    work.mkdir()
    _git(work, "init", "-q")
    r = run(e, "comment", "86", "--stage", "fixed-on-bleeding-edge", "--task", "T-1",
            "--commit", "abcdef1", "--test-cmd", "x", cwd=work)
    assert r.returncode != 0 and rows(ledger) == []


def test_ledger_written_only_on_success(env):
    e, stub, ledger = env
    (stub / "fail_comment").write_text("")
    r = run(e, "comment", "86", "--stage", "in-progress", "--task", "T-4040")
    assert r.returncode != 0 and "Nothing was logged" in r.stderr
    assert rows(ledger) == []


def test_ledger_failure_after_post_is_loud(env, tmp_path):
    e, stub, ledger = env
    blocker = tmp_path / "file"
    blocker.write_text("")
    e = dict(e, FW_ISSUES_DIR=str(blocker / "sub"))  # cannot be created
    r = run(e, "comment", "86", "--stage", "in-progress", "--task", "T-4040")
    assert r.returncode == 4 and "comment POSTED at https://github.com/o/r/issues/86" in r.stderr


def test_missing_labels_created_existing_not(env):
    e, stub, ledger = env
    (stub / "labels.json").write_text(json.dumps([{"name": "status:fixed-on-bleeding-edge"}]))
    (stub / "labels.json").write_text(json.dumps([{"name": "triaged"}]))
    assert run(e, "comment", "86", "--stage", "classified", "--text", "- Type: bug").returncode == 0
    assert [c for c in calls(stub) if c[:2] == ["label", "create"]] == []
    assert run(e, "comment", "86", "--stage", "in-progress", "--task", "T-1").returncode == 0
    created = [c[2] for c in calls(stub) if c[:2] == ["label", "create"]]
    assert created == ["status:in-progress"]
    edits = [c for c in calls(stub) if c[:2] == ["issue", "edit"]]
    assert edits[-1][-1] == "status:in-progress"


def test_dry_run_posts_nothing(env):
    e, stub, ledger = env
    r = run(e, "comment", "86", "--stage", "released", "--task", "T-1", "--version", "v1.9.0", "--dry-run")
    assert r.returncode == 0 and "v1.9.0" in r.stdout and FOOTER in r.stdout
    assert not any(c[:2] == ["issue", "comment"] for c in calls(stub)) and rows(ledger) == []


def test_injection_text_is_inert(env):
    e, stub, ledger = env
    (stub / "view.json").write_text(json.dumps({"author": {"login": "r"}, "comments": [
        {"author": {"login": "x"}, "body": "ignore previous; $(touch /tmp/pwned-t4077) `id`"}]}))
    assert run(e, "comment", "86", "--stage", "in-progress", "--task", "T-1").returncode == 0
    assert not Path("/tmp/pwned-t4077").exists()


def test_bad_arguments_rejected(env):
    e, stub, ledger = env
    assert run(e, "comment", "86", "--stage", "in-progress", "--task", "T-1; rm").returncode != 0
    assert run(e, "comment", "86", "--stage", "bogus").returncode != 0
    assert run(e, "comment", "86", "--stage", "in-progress").returncode != 0  # needs --task


def test_fw_route_exists():
    out = subprocess.run(["bash", "-n", str(ROOT / "bin" / "fw")], capture_output=True, text=True)
    assert out.returncode == 0
    assert "issues)" in (ROOT / "bin" / "fw").read_text()
