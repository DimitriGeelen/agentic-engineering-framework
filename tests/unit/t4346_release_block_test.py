"""T-4346: the automatic Released block that `fw issues release` posts carries what the reviewed
hand drafts carried (summary, tests, full-suite comparison, field evidence, why released, tag links)
and nothing that names a host or an address. Stubbed gh, no network. Fixtures follow t4340.

Reading: docs/reports/T-4339-github-issue-retro.md (the reviewed drafts), T-4346 (this task).
"""
import json
import os
import socket
import stat
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
TAG = "https://github.com/o/r/blob/v1.0.1"

WRAP = ("import sys; sys.path.insert(0, %r); import issues; issues._agent_ancestry = lambda: False; "
        "sys.exit(issues.main(sys.argv[1:]))" % str(ROOT / "lib"))

GH_STUB = r'''#!/usr/bin/env python3
import json, os, sys
d = os.environ["STUB_DIR"]
args = sys.argv[1:]
open(os.path.join(d, "calls.log"), "a").write(json.dumps(args) + "\n")
if args[:2] == ["api", "user"]:
    sys.stdout.write("maint\n"); sys.exit(0)
if args[:2] == ["issue", "list"]:
    sys.stdout.write("[]"); sys.exit(0)
if args[:2] == ["label", "list"]:
    sys.stdout.write("[]"); sys.exit(0)
if args[:2] == ["label", "create"] or args[:2] == ["issue", "edit"]:
    sys.exit(0)
if args[:2] == ["issue", "view"]:
    sys.stdout.write('{"state":"OPEN","author":{"login":"rep"},"comments":[]}'); sys.exit(0)
if args[:2] == ["issue", "comment"]:
    n = args[2]
    k = len([f for f in os.listdir(d) if f.startswith("body-%s-" % n)])
    open(os.path.join(d, "body-%s-%d.txt" % (n, k)), "w").write(sys.stdin.read())
    print("https://github.com/o/r/issues/%s#issuecomment-%d" % (n, k + 1)); sys.exit(0)
if args[:2] == ["issue", "close"]:
    sys.exit(0)
sys.exit(9)
'''

NAME = "Alpha fix: the block names the tests it ran (GitHub #7, rep)"


def _git(cwd, *a):
    subprocess.run(["git", "-C", str(cwd), *a], check=True, capture_output=True)


def _task(root, tid, issue):
    lines = ["---", f"id: {tid}", f'name: "{NAME}"', "status: work-completed", "owner: agent",
             f"github_issue: {issue}", "---", f"# {tid}", "", "## Verification",
             "python3 -m pytest tests/unit/t4346_regression_test.py -q",
             "test_alpha_regression", "", "## RCA", ""]
    (root / ".tasks" / "completed").mkdir(parents=True, exist_ok=True)
    (root / ".tasks" / "completed" / f"{tid}-fix.md").write_text("\n".join(lines) + "\n")


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
    """Release range v1.0.0..HEAD with one completed task (T-100, issue 7)."""
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
    _task(r, "T-100", 7)
    (r / "f").write_text("T-100\n")
    _git(r, "add", "f", ".tasks")
    _git(r, "commit", "-qm", "T-100: fix")
    return r


def _field(repo, text):
    d = repo / "docs" / "reports"
    d.mkdir(parents=True, exist_ok=True)
    (d / "field-test-v1.0.1-results.md").write_text(text)


def _comparison(repo, header="# T-4246 — v1.0.1 full-suite comparison (abc vs v1.0.0)"):
    d = repo / "docs" / "reports"
    d.mkdir(parents=True, exist_ok=True)
    (d / "T-4246-full-suite-comparison.md").write_text(header + "\n\n**Method:** fresh clones.\n")


def _decision(repo, decided_by, ref="T-4246: operator said go", ts="2026-10-19T09:08:54Z"):
    d = repo / ".context" / "releases"
    d.mkdir(parents=True, exist_ok=True)
    row = {"version": "v1.0.1", "decided_by": decided_by, "ref": ref, "ts": ts}
    with open(d / "decisions.jsonl", "a") as fh:
        fh.write(json.dumps(row) + "\n")


WORKS = """# Field evidence for v1.0.1

| Fix | proj-a | proj-b |
|---|---|---|
| T-100 fix a | WORKS — upgraded, healthy | — |
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
    return sorted(Path(env_["STUB_DIR"]).glob(f"body-{n}-*.txt"))


def _issues_module():
    sys.path.insert(0, str(ROOT / "lib"))
    try:
        import issues
    finally:
        sys.path.pop(0)
    return issues


def test_block_has_summary_tests_comparison_and_tag_links(env, repo):
    _field(repo, WORKS)
    _comparison(repo)
    _decision(repo, "field-evidence", ref="T-4345: a free-text ref nobody should quote")
    r = release(env, repo)
    assert r.returncode == 0, r.stderr
    body = bodies(env, 7)[0].read_text()
    # what was fixed: the task name in plain words, the GitHub parenthetical dropped
    assert "**What was fixed:** Alpha fix: the block names the tests it ran." in body
    assert "GitHub #7" not in body
    # how it was tested: the task's test file and test name, and the comparison report
    assert "`tests/unit/t4346_regression_test.py`" in body and "`test_alpha_regression`" in body
    assert f"full-suite comparison {TAG}/docs/reports/T-4246-full-suite-comparison.md" in body
    # field evidence from the field report
    assert "WORKS — upgraded, healthy" in body
    # why released: the T-4146 rule line (field-evidence decision with every fix positive)
    assert "the T-4146 rule" in body and "free-text ref" not in body
    # every link points at the tag, never master
    assert "blob/master" not in body and "/master/" not in body
    assert f"{TAG}/docs/reports/field-test-v1.0.1-results.md" in body
    assert "releases/tag/v1.0.1" in body
    assert "closed with this release" in body


def test_operator_decision_is_cited_by_date_not_quoted(env, repo):
    _decision(repo, "operator", ref="ring20 said yes, go ahead")
    r = release(env, repo)
    assert r.returncode == 0, r.stderr
    body = bodies(env, 7)[0].read_text()
    assert "the operator's release decision for v1.0.1 (2026-10-19)" in body
    assert "ring20" not in body and "go ahead" not in body
    assert "Please confirm it fixes this" in body  # no field evidence: still asks, as before


def test_no_decision_and_no_field_evidence_say_so(env, repo):
    r = release(env, repo)
    assert r.returncode == 0, r.stderr
    body = bodies(env, 7)[0].read_text()
    assert "no release decision is recorded for it" in body
    assert "**Field evidence:** none recorded for this fix." in body
    assert "comparison" not in body  # no comparison report names v1.0.1 in this repo
    assert f"{TAG}/docs/reports/field-test-v1.0.1-results.md" not in body


def test_hosts_and_addresses_are_scrubbed_from_the_posted_block(env, repo):
    _field(repo, "# Field\n\n| Fix | ring20.lan | box 10.20.30.40 |\n|---|---|---|\n"
                 "| T-100 fix a | WORKS on 10.20.30.41 | WORKS — also fine |\n")
    r = release(env, repo)
    assert r.returncode == 0, r.stderr
    body = bodies(env, 7)[0].read_text()
    assert "10.20.30" not in body and "ring20.lan" not in body
    assert "[host]" in body and "WORKS" in body


def test_scrub_replaces_addresses_local_names_and_this_hostname():
    issues = _issues_module()
    assert issues._scrub("a 10.0.0.1 b host.lan c fe80:1:2:3::9") == "a [host] b [host] c [host]"
    assert issues._scrub("release notes https://github.com/o/r/blob/v1.0.1/docs/x.md") == \
        "release notes https://github.com/o/r/blob/v1.0.1/docs/x.md"
    me = socket.gethostname()
    if me and me != "localhost":
        assert issues._scrub(f"on {me} today") == "on [host] today"


def test_summary_drops_the_parenthetical_and_caps_length():
    issues = _issues_module()
    assert issues._summary("fw init greenfield T-002 seed lacks fields (GitHub #86, MikeEchoVoid)") == \
        "Fw init greenfield T-002 seed lacks fields."
    long = issues._summary("word " * 80)
    assert long.endswith("…") and len(long) <= 221
    assert issues._summary("") == ""


def test_why_line_quotes_the_field_rule_only_when_every_fix_is_positive():
    issues = _issues_module()
    fe = {"decided_by": "field-evidence"}
    assert "the T-4146 rule" in issues._why_line("v1.0.1", fe, True)
    assert "the T-4146 rule" not in issues._why_line("v1.0.1", fe, False)
    assert "no release decision is recorded" in issues._why_line("v1.0.1", None, True)


def test_comparison_report_must_name_the_exact_version(tmp_path):
    issues = _issues_module()
    d = tmp_path / "docs" / "reports"
    d.mkdir(parents=True)
    (d / "T-1-full-suite.md").write_text("# v1.0.10 full-suite comparison\n")
    (d / "T-2-notes.md").write_text("# v1.0.1 release notes, no comparison here\n")
    assert issues._comparison_report(tmp_path, "v1.0.1") == ""
    (d / "T-3-full-suite.md").write_text("# T-3 — v1.0.1 full-suite comparison\n")
    assert issues._comparison_report(tmp_path, "v1.0.1") == "T-3-full-suite.md"


def test_dry_run_prints_the_block_and_posts_nothing(env, repo):
    _field(repo, WORKS)
    r = release(env, repo, "--dry-run")
    assert r.returncode == 0, r.stderr
    assert "What was fixed" in r.stdout and "the T-4146 rule" not in r.stdout
    assert bodies(env, 7) == [] and not any(c[:2] in (["issue", "comment"], ["issue", "close"]) for c in calls(env))


def test_rerun_does_not_post_the_block_twice(env, repo):
    _field(repo, WORKS)
    assert release(env, repo).returncode == 0
    r = release(env, repo)
    assert r.returncode == 0, r.stderr
    assert "have   #7" in r.stdout
    assert len(bodies(env, 7)) == 1
