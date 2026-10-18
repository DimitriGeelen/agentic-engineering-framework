"""T-4340: the release leg of the GitHub issue lifecycle (stages 8-9). Stubbed gh, no network.

fw issues release  — posts Released per task in a release range, closes on WORKS, else please-confirm
fw issues sweep    — closes overdue please-confirm issues unless the submitter replied
"""
import json
import os
import stat
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
ISSUES_PY = ROOT / "lib" / "issues.py"

# Neutralise the process-ancestry probe: these tests run under a Claude worker (T-4108).
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
    sys.stdout.write("maint\n"); sys.exit(0)
if args[:2] == ["issue", "list"]:
    sys.stdout.write("[]"); sys.exit(0)
if args[:2] == ["label", "list"]:
    sys.stdout.write("[]"); sys.exit(0)
if args[:2] == ["label", "create"] or args[:2] == ["issue", "edit"]:
    sys.exit(0)
if args[:2] == ["issue", "view"]:
    sys.stdout.write(rd("view.json", '{"state":"OPEN","author":{"login":"rep"},"comments":[]}'))
    sys.exit(0)
if args[:2] == ["issue", "comment"]:
    if os.path.exists(os.path.join(d, "fail_comment")):
        sys.stderr.write("HTTP 503"); sys.exit(1)
    n = args[2]
    k = len([f for f in os.listdir(d) if f.startswith("body-%s-" % n)])
    open(os.path.join(d, "body-%s-%d.txt" % (n, k)), "w").write(sys.stdin.read())
    print("https://github.com/o/r/issues/%s#issuecomment-%d" % (n, k + 1)); sys.exit(0)
if args[:2] == ["issue", "close"]:
    if os.path.exists(os.path.join(d, "fail_close")):
        sys.stderr.write("nope"); sys.exit(1)
    sys.exit(0)
sys.exit(9)
'''

TODAY = datetime.now(timezone.utc).strftime("%Y-%m-%d")


def _git(cwd, *a):
    subprocess.run(["git", "-C", str(cwd), *a], check=True, capture_output=True)


def _task(root, folder, tid, issue=None, owner="agent"):
    lines = ["---", f"id: {tid}", f'name: "fix {tid}"', "status: work-completed", f"owner: {owner}"]
    if issue is not None:
        lines.append(f"github_issue: {issue}")
    lines += ["---", f"# {tid}", "", "## Verification",
              "out=$(python3 -m pytest tests/unit/t4340_regression_test.py -q 2>&1); echo \"$out\" | grep -q passed",
              "test_alpha_regression", "", "## RCA", ""]
    (root / ".tasks" / folder).mkdir(parents=True, exist_ok=True)
    (root / ".tasks" / folder / f"{tid}-fix.md").write_text("\n".join(lines) + "\n")


@pytest.fixture
def env(tmp_path):
    stub = tmp_path / "stub"
    stub.mkdir()
    bindir = tmp_path / "bin"
    bindir.mkdir()
    gh = bindir / "gh"
    gh.write_text(GH_STUB)
    gh.chmod(gh.stat().st_mode | stat.S_IEXEC)
    return dict(os.environ, PATH=f"{bindir}:{os.environ['PATH']}", STUB_DIR=str(stub),
                FW_ISSUES_DIR=str(tmp_path / "issues"), FW_ISSUES_REPO="o/r",
                FW_ISSUES_GIT_REMOTE="github")


@pytest.fixture
def repo(tmp_path):
    """A release range v1.0.0..HEAD with: T-100 completed (issue 7), T-101 still active (issue 8),
    T-102 completed with no github_issue."""
    r = tmp_path / "repo"
    r.mkdir()
    _git(r, "init", "-q", "-b", "master")
    _git(r, "config", "user.email", "t@t.t")
    _git(r, "config", "user.name", "t")
    _git(r, "config", "commit.gpgsign", "false")
    (r / "f").write_text("base\n")
    _git(r, "add", "f")
    _git(r, "commit", "-qm", "base")
    _git(r, "tag", "v1.0.0")
    for tid, issue, folder in (("T-100", 7, "completed"), ("T-101", 8, "active"), ("T-102", None, "completed")):
        _task(r, folder, tid, issue, owner="human" if folder == "active" else "agent")
        (r / "f").write_text(tid + "\n")
        _git(r, "add", "f", ".tasks")
        _git(r, "commit", "-qm", f"{tid}: fix")
    return r


def _field(repo, text):
    d = repo / "docs" / "reports"
    d.mkdir(parents=True, exist_ok=True)
    (d / "field-test-v1.0.1-results.md").write_text(text)


WORKS = """# Field evidence for v1.0.1

## Round 1 — 832

| Fix | 832-Workflow-designer | ring20 |
|---|---|---|
| T-100 fix a | WORKS — upgraded, healthy | — |
| T-101 fix b | WORKS — also fine | — |
"""


def run(env_, repo, *args):
    return subprocess.run([sys.executable, "-c", WRAP, *args], env=dict(env_, PROJECT_ROOT=str(repo)),
                          capture_output=True, text=True)


def release(env_, repo, *extra):
    return run(env_, repo, "release", "v1.0.1", "--range", "v1.0.0..HEAD", "--root", str(repo), *extra)


def calls(env_):
    p = Path(env_["STUB_DIR"]) / "calls.log"
    return [json.loads(x) for x in p.read_text().splitlines()] if p.exists() else []


def bodies(env_, n):
    d = Path(env_["STUB_DIR"])
    return sorted(d.glob(f"body-{n}-*.txt"))


def ledger(env_):
    p = Path(env_["FW_ISSUES_DIR"]) / "intake.jsonl"
    return [json.loads(x) for x in p.read_text().splitlines()] if p.exists() else []


def _closes(env_, n):
    return [c for c in calls(env_) if c[:2] == ["issue", "close"] and c[2] == str(n)]


def test_posts_evidence_and_closes_when_field_says_works(env, repo):
    _field(repo, WORKS)
    r = release(env, repo)
    assert r.returncode == 0, r.stderr
    body = bodies(env, 7)[0].read_text()
    assert "released in **v1.0.1**" in body
    assert "How it was tested:" in body and "test_alpha_regression" in body
    assert "WORKS" in body and "field-test-v1.0.1-results.md" in body
    assert "closed with this release" in body
    assert "please confirm" not in body.lower()
    assert "aef-intake:stage=released" in body and "Dimitri personally" in body
    assert len(_closes(env, 7)) == 1
    # T-101 is still active (awaiting review): held, nothing posted, issue 8 stays open
    assert "hold   #8" in r.stdout
    assert bodies(env, 8) == [] and _closes(env, 8) == []
    # T-102 has no github_issue: never touched
    assert not any(c[2] in ("9", "10") for c in calls(env) if len(c) > 2)


def test_without_positive_field_evidence_asks_to_confirm_and_sets_due_date(env, repo):
    r = release(env, repo)
    assert r.returncode == 0, r.stderr
    body = bodies(env, 7)[0].read_text()
    assert "Please confirm it fixes this" in body and "14 days" in body
    assert "closed with this release" not in body
    assert _closes(env, 7) == []
    row = [x for x in ledger(env) if x.get("issue") == 7 and x.get("stage") == "released"][0]
    due = datetime.strptime(row["due"], "%Y-%m-%d").date()
    assert due == (datetime.now(timezone.utc) + timedelta(days=14)).date()


def test_rerun_is_idempotent(env, repo):
    _field(repo, WORKS)
    assert release(env, repo).returncode == 0
    r = release(env, repo)
    assert r.returncode == 0, r.stderr
    assert len(bodies(env, 7)) == 1
    assert len(_closes(env, 7)) == 1
    assert "already logged" in r.stdout


def test_dry_run_lists_and_posts_nothing(env, repo):
    _field(repo, WORKS)
    r = release(env, repo, "--dry-run")
    assert r.returncode == 0, r.stderr
    assert "would post released on #7" in r.stdout and "would close #7" in r.stdout
    assert "hold   #8" in r.stdout
    assert "dry-run" in r.stdout
    assert not any(c[:2] in (["issue", "comment"], ["issue", "close"], ["issue", "edit"]) for c in calls(env))
    assert ledger(env) == [] and not (Path(env["FW_ISSUES_DIR"]) / "release-pending.jsonl").exists()


def test_failed_github_post_never_fails_release_and_is_recorded(env, repo):
    Path(env["STUB_DIR"], "fail_comment").write_text("")
    r = release(env, repo)
    assert r.returncode == 0
    assert "WARN" in r.stderr and "#7" in r.stderr
    pending = [json.loads(x) for x in (Path(env["FW_ISSUES_DIR"]) / "release-pending.jsonl").read_text().splitlines()]
    assert pending and pending[0]["issue"] == 7 and pending[0]["stage"] == "released"
    assert ledger(env) == []


def test_failed_close_is_retried_without_reposting(env, repo):
    _field(repo, WORKS)
    Path(env["STUB_DIR"], "fail_close").write_text("")
    assert release(env, repo).returncode == 0
    assert len(bodies(env, 7)) == 1
    Path(env["STUB_DIR"], "fail_close").unlink()
    assert release(env, repo).returncode == 0
    assert len(bodies(env, 7)) == 1          # not posted again
    assert len(_closes(env, 7)) == 2         # the close was retried
    assert any(x.get("stage") == "closed-released" for x in ledger(env))


def _age_due(env_, due):
    p = Path(env_["FW_ISSUES_DIR"]) / "intake.jsonl"
    rows = [json.loads(x) for x in p.read_text().splitlines()]
    for r in rows:
        if r.get("stage") == "released" and r.get("due"):
            r["due"] = due
    p.write_text("".join(json.dumps(r) + "\n" for r in rows))


def test_sweep_closes_overdue_please_confirm_with_note(env, repo):
    assert release(env, repo).returncode == 0
    _age_due(env, "2000-01-01")
    r = run(env, repo, "sweep", "--today", TODAY)
    assert r.returncode == 0, r.stderr
    note = bodies(env, 7)[-1].read_text()
    assert "aef-intake:stage=closed-released" in note and "No reply in 14 days" in note
    assert len(_closes(env, 7)) == 1
    assert any(x.get("stage") == "closed-released" and x.get("issue") == 7 for x in ledger(env))


def test_sweep_does_not_close_before_due(env, repo):
    assert release(env, repo).returncode == 0
    r = run(env, repo, "sweep", "--today", "2000-01-01")
    assert r.returncode == 0
    assert _closes(env, 7) == [] and len(bodies(env, 7)) == 1


def test_submitter_reply_after_released_blocks_the_sweep(env, repo):
    assert release(env, repo).returncode == 0
    _age_due(env, "2000-01-01")
    Path(env["STUB_DIR"], "view.json").write_text(json.dumps({
        "state": "OPEN", "author": {"login": "rep"},
        "comments": [{"author": {"login": "rep"}, "createdAt": "2099-01-01T00:00:00Z", "body": "still broken"}]}))
    r = run(env, repo, "sweep", "--today", TODAY)
    assert r.returncode == 0, r.stderr
    assert "keep" in r.stdout and "#7" in r.stdout
    assert _closes(env, 7) == [] and len(bodies(env, 7)) == 1


def test_maintainer_comment_does_not_block_the_sweep(env, repo):
    assert release(env, repo).returncode == 0
    _age_due(env, "2000-01-01")
    Path(env["STUB_DIR"], "view.json").write_text(json.dumps({
        "state": "OPEN", "author": {"login": "rep"},
        "comments": [{"author": {"login": "maint"}, "createdAt": "2099-01-01T00:00:00Z", "body": "x"}]}))
    assert run(env, repo, "sweep", "--today", TODAY).returncode == 0
    assert len(_closes(env, 7)) == 1


def test_sweep_dry_run_closes_nothing(env, repo):
    assert release(env, repo).returncode == 0
    _age_due(env, "2000-01-01")
    before = len(calls(env))
    r = run(env, repo, "sweep", "--today", TODAY, "--dry-run")
    assert r.returncode == 0, r.stderr
    assert "would-close" in r.stdout and "dry-run" in r.stdout
    after = calls(env)[before:]
    assert not any(c[:2] in (["issue", "comment"], ["issue", "close"], ["issue", "edit"]) for c in after)
    assert _closes(env, 7) == []


def test_sync_runs_the_sweep(env, repo):
    """sync is the scheduled step: an overdue please-confirm issue is closed by it too."""
    assert release(env, repo).returncode == 0
    _age_due(env, "2000-01-01")
    r = run(env, repo, "sync")
    assert r.returncode == 0, r.stderr
    assert "sweep:" in r.stdout


def test_field_report_verdicts_only_come_from_table_rows(tmp_path):
    sys.path.insert(0, str(ROOT / "lib"))
    try:
        import issues
    finally:
        sys.path.pop(0)
    p = tmp_path / "field.md"
    p.write_text("""# Field

T-900 was discussed in prose and WORKS everywhere, which is not evidence.

| Fix | proj-a | proj-b |
|---|---|---|
| T-901 good | WORKS — yes | NOT EXERCISED |
| T-902 bad | WORKS — ok | BROKEN → T-903 |
| T-904 unknown | NOT EXERCISED | — |
""")
    v = issues._field_verdicts(p)
    assert "T-900" not in v
    assert v["T-901"]["verdict"] == "works" and "proj-a" in v["T-901"]["evidence"][0]
    assert v["T-902"]["verdict"] == "fails"
    assert v["T-904"]["verdict"] is None
    assert issues._field_verdicts(tmp_path / "missing.md") == {}


def test_release_arguments_are_checked(env, repo):
    r = run(env, repo, "release", "banana", "--range", "v1.0.0..HEAD", "--root", str(repo))
    assert r.returncode == 2 and "vX.Y.Z" in r.stderr
    r = run(env, repo, "release", "v1.0.1", "--range", "nope", "--root", str(repo))
    assert r.returncode == 2 and "A..B" in r.stderr
