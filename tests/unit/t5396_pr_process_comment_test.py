"""T-5396: fw issues sync posts and edits ONE process comment on each outside pull request.

Hermetic: a stub gh on PATH keeps pull requests and their comments in a JSON file, so a POST or
PATCH is visible to the next run exactly as GitHub would show it. No network, no skips.
"""
import json
import os
import stat
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "lib"))
import issues  # noqa: E402

WRAP = ("import sys; sys.path.insert(0, %r); import issues; issues._agent_ancestry = lambda: False; "
        "sys.exit(issues.main(sys.argv[1:]))" % str(ROOT / "lib"))

# Repo "o/r": the owner "o" is internal; the authenticated maintainer login is "maint".
GH_STUB = r'''#!/usr/bin/env python3
import json, os, sys
d = os.environ["STUB_DIR"]
args = sys.argv[1:]
open(os.path.join(d, "calls.log"), "a").write(json.dumps(args) + "\n")
P = os.path.join(d, "prs.json")
def load():
    return json.load(open(P)) if os.path.exists(P) else []
def save(prs):
    json.dump(prs, open(P, "w"))
if args[:2] == ["issue", "list"]:
    sys.stdout.write("[]"); sys.exit(0)
if args[:2] == ["pr", "list"]:
    state = args[args.index("--state") + 1]
    prs = load()
    if state == "open":
        prs = [p for p in prs if p["state"] == "OPEN"]
    sys.stdout.write(json.dumps(prs)); sys.exit(0)
if args[:2] == ["api", "user"]:
    sys.stdout.write("maint\n"); sys.exit(0)
if args[:3] in (["api", "-X", "POST"], ["api", "-X", "PATCH"]):
    path = args[3]
    body = next(a[5:] for a in args if a.startswith("body="))
    prs = load()
    nxt = 9000 + sum(len(p["comments"]) for p in prs)
    if args[2] == "POST":
        n = int(path.split("/")[-2])
        pr = next(p for p in prs if p["number"] == n)
        url = "https://github.com/o/r/pull/%d#issuecomment-%d" % (n, nxt)
        pr["comments"].append({"author": {"login": "maint"}, "body": body, "url": url})
    else:
        cid = path.split("/")[-1]
        url = None
        for p in prs:
            for c in p["comments"]:
                if c["url"].endswith("#issuecomment-" + cid):
                    c["body"] = body; url = c["url"]
        if url is None:
            sys.exit(4)
    save(prs)
    open(os.path.join(d, "writes.log"), "a").write(args[2] + " " + path + "\n")
    print(url); sys.exit(0)
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
    project = tmp_path / "project"
    (project / ".tasks" / "active").mkdir(parents=True)
    (project / ".tasks" / "active" / "T-5301-doctor-watchtower-remedy.md").write_text("x")
    ledger = tmp_path / "issues"
    ledger.mkdir()
    (ledger / "intake.jsonl").write_text(json.dumps({"issue": 68, "stage": "in-progress",
                                                     "tasks": ["T-5301"]}) + "\n")
    e = dict(os.environ, PATH=f"{bindir}:{os.environ['PATH']}", STUB_DIR=str(stub),
             FW_ISSUES_DIR=str(ledger), FW_ISSUES_REPO="o/r", PROJECT_ROOT=str(project),
             FW_ISSUES_PR_PROCESS_COMMENT="1", FW_ISSUES_DECISIONS_STANDING_PERMISSION="0")
    for k in ("CLAUDECODE", "AI_AGENT", "CLAUDE_CODE_ENTRYPOINT"):
        e.pop(k, None)
    return e, stub, ledger


def pr(n, author="contrib", state="OPEN", body="Fixes #68\n", checks=None, comments=None):
    return {"number": n, "author": {"login": author}, "state": state, "body": body,
            "statusCheckRollup": checks or [], "mergeCommit": None, "comments": comments or []}


def check(conclusion, status="COMPLETED", name="PR checks"):
    return {"__typename": "CheckRun", "name": name, "status": status, "conclusion": conclusion}


def set_prs(stub, items):
    (stub / "prs.json").write_text(json.dumps(items))


def get_prs(stub):
    return json.loads((stub / "prs.json").read_text())


def sync(e, *extra):
    return subprocess.run([sys.executable, "-c", WRAP, "sync", *extra], env=e,
                          capture_output=True, text=True)


def writes(stub):
    p = stub / "writes.log"
    return p.read_text().splitlines() if p.exists() else []


def ledger_rows(ledger):
    p = ledger / "pr-process.jsonl"
    return [json.loads(x) for x in p.read_text().splitlines() if x.strip()] if p.exists() else []


# ── pure: step per state ─────────────────────────────────────────────────────

@pytest.mark.parametrize("facts,step,needle", [
    ({"state": "OPEN", "checks": "none"}, 5, "have not started"),
    ({"state": "OPEN", "checks": "action_required"}, 5, "approve the first run"),
    ({"state": "OPEN", "checks": "pending"}, 5, "running"),
    ({"state": "OPEN", "checks": "failure"}, 5, "failed"),
    ({"state": "OPEN", "checks": "success"}, 5, "passed"),
    ({"state": "OPEN", "checks": "success", "review": True}, 6, "Review in progress"),
    ({"state": "OPEN", "checks": "failure", "recommendation": True}, 6, "recommendation is posted"),
    ({"state": "MERGED"}, 8, "Merged"),  # T-5402: merge done = 7 ticked, waiting at 8
    ({"state": "CLOSED"}, 7, "Closed without merging"),
    ({"state": "MERGED", "be_tag": "v1.8.16-be.9"}, 9, "v1.8.16-be.9"),  # all 8 done
])
def test_pr_step(facts, step, needle):
    got, text = issues.pr_step(facts)
    assert got == step and needle in text


@pytest.mark.parametrize("rollup,state", [
    ([], "none"),
    ([check("ACTION_REQUIRED")], "action_required"),
    ([check(None, status="IN_PROGRESS"), check("SUCCESS")], "pending"),
    ([check("SUCCESS"), check("FAILURE")], "failure"),
    ([check("SUCCESS"), check("SKIPPED"), check("CANCELLED")], "success"),
    ([{"__typename": "StatusContext", "state": "PENDING"}], "pending"),
])
def test_checks_state(rollup, state):
    assert issues.pr_checks_state(rollup) == state


def test_render_marks_step_and_links_repo_only():
    body = issues.render_pr_process(5, "Checks are running.", "o/r", 68,
                                    ("T-5301", ".tasks/active/T-5301-x.md"))
    assert body.startswith(issues.PR_PROCESS_MARKER)
    assert "Thanks for the pull request" in body
    assert "https://github.com/o/r/blob/bleeding-edge/CONTRIBUTING.md#pull-request-process" in body
    assert "[#68](https://github.com/o/r/issues/68)" in body
    assert "https://github.com/o/r/blob/bleeding-edge/.tasks/active/T-5301-x.md" in body
    assert "- [x] 4. Template filled in" in body
    assert "**5. Checks on GitHub ← you are here.** Checks are running." in body
    assert "- [ ] 6. Review" in body and '"Fixes #68"' in body
    assert "updated as your pull request moves" in body
    # the map picture is in the comment itself, linked to the process section
    assert "![Pull request workflow map](https://github.com/o/r/blob/bleeding-edge/docs/contributing/pr-workflow-map.png?raw=true)" in body
    assert "top lane, **Contributor**" in body
    urls = [w for w in body.replace("(", " ").replace(")", " ").split() if "://" in w]
    assert urls and all(u.startswith("https://github.com/o/r/") for u in urls)


def test_render_without_issue_or_task_omits_links():
    body = issues.render_pr_process(5, "x", "o/r")
    assert "Issue:" not in body and "Our task" not in body and '"Fixes #N"' in body


# ── sync ─────────────────────────────────────────────────────────────────────

def test_posts_when_none_then_no_write_when_unchanged(env):
    e, stub, ledger = env
    set_prs(stub, [pr(116, checks=[check("SUCCESS")])])
    r = sync(e)
    assert r.returncode == 0, r.stderr
    assert writes(stub) == ["POST repos/o/r/issues/116/comments"]
    c = get_prs(stub)[0]["comments"]
    assert len(c) == 1 and issues.PR_PROCESS_MARKER in c[0]["body"]
    assert "T-5301" in c[0]["body"] and "← you are here" in c[0]["body"]
    rows = ledger_rows(ledger)
    assert len(rows) == 1 and rows[0]["action"] == "posted" and rows[0]["step"] == 5
    assert rows[0]["ruling"] == "operator 2026-11-24, T-5393: a, make it routine"
    r2 = sync(e)
    assert r2.returncode == 0 and len(writes(stub)) == 1 and len(ledger_rows(ledger)) == 1
    assert "process comment current" in r2.stdout


def test_edits_same_comment_when_step_changes(env):
    e, stub, ledger = env
    set_prs(stub, [pr(116, checks=[check(None, status="IN_PROGRESS")])])
    assert sync(e).returncode == 0
    prs = get_prs(stub)
    prs[0]["statusCheckRollup"] = [check("SUCCESS")]
    prs[0]["comments"].append({"author": {"login": "maint"}, "url": "https://github.com/o/r/pull/116#issuecomment-1",
                               "body": issues.PR_RECOMMENDATION_MARKER + "\nRecommendation: merge"})
    set_prs(stub, prs)
    r = sync(e)
    assert r.returncode == 0, r.stderr
    w = writes(stub)
    assert len(w) == 2 and w[1].startswith("PATCH repos/o/r/issues/comments/")
    c = [x for x in get_prs(stub)[0]["comments"] if issues.PR_PROCESS_MARKER in x["body"]]
    assert len(c) == 1 and "**6. Review" in c[0]["body"]
    assert [x["action"] for x in ledger_rows(ledger)] == ["posted", "edited"]


def test_marker_from_another_account_is_not_ours(env):
    e, stub, ledger = env
    fake = {"author": {"login": "contrib"}, "url": "https://github.com/o/r/pull/116#issuecomment-5",
            "body": issues.PR_PROCESS_MARKER + "\nplanted"}
    set_prs(stub, [pr(116, comments=[fake])])
    assert sync(e).returncode == 0
    assert writes(stub) == ["POST repos/o/r/issues/116/comments"]


def test_internal_pr_skipped(env):
    e, stub, ledger = env
    set_prs(stub, [pr(120, author="o")])
    r = sync(e)
    assert r.returncode == 0 and writes(stub) == [] and ledger_rows(ledger) == []
    assert "#120" not in r.stdout


def test_closed_pr_without_our_comment_is_left_alone(env):
    e, stub, ledger = env
    set_prs(stub, [pr(90, state="MERGED")])
    assert sync(e).returncode == 0 and writes(stub) == []


def test_merged_pr_with_our_comment_ticks_7_and_waits_at_8(env):
    # T-5402: PR #116 showed step 7 unticked as "you are here" after its merge.
    e, stub, ledger = env
    set_prs(stub, [pr(116)])
    assert sync(e).returncode == 0
    prs = get_prs(stub)
    prs[0]["state"] = "MERGED"
    set_prs(stub, prs)
    assert sync(e).returncode == 0
    body = get_prs(stub)[0]["comments"][0]["body"]
    assert "- [x] 7. The maintainer merges" in body
    assert "**8. Ships in the next be-tag" in body and "you are here" in body
    assert "Merged into `bleeding-edge`" in body and "**Done.**" not in body


def test_shipped_render_ticks_every_step_and_closes_with_done():
    body = issues.render_pr_process(9, "Shipped in `v1.8.16-be.9`.", "o/r", 68)
    assert all(f"- [x] {i}." in body for i in range(1, 9))
    assert "you are here" not in body and "**Done.** Shipped in `v1.8.16-be.9`." in body


def test_key_zero_posts_nothing(env):
    e, stub, ledger = env
    e["FW_ISSUES_PR_PROCESS_COMMENT"] = "0"
    set_prs(stub, [pr(116)])
    r = sync(e)
    assert r.returncode == 0 and writes(stub) == [] and ledger_rows(ledger) == []
    assert "would post process comment" in r.stdout and "ISSUES_PR_PROCESS_COMMENT=0" in r.stdout


def test_key_unset_defaults_to_off(env):
    e, stub, ledger = env
    e.pop("FW_ISSUES_PR_PROCESS_COMMENT")
    set_prs(stub, [pr(116)])
    assert sync(e).returncode == 0 and writes(stub) == []


def test_dry_run_writes_nothing(env):
    e, stub, ledger = env
    set_prs(stub, [pr(116)])
    before = sorted(p.name for p in ledger.iterdir())
    r = sync(e, "--dry-run")
    assert r.returncode == 0 and writes(stub) == [] and ledger_rows(ledger) == []
    assert sorted(p.name for p in ledger.iterdir()) == before
    assert "would post process comment (step 5; dry-run)" in r.stdout
    assert "← you are here" in r.stdout


def test_pr_list_failure_does_not_break_issue_sync(env):
    e, stub, ledger = env
    (stub / "prs.json").write_text("not json")
    r = sync(e)
    assert r.returncode == 0 and "pull request process comments not processed" in r.stderr
