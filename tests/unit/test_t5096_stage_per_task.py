"""T-5096: a per-fix stage (in-progress, fixed-on-bleeding-edge) is posted once per task, not
once per issue, so a follow-up fix on the same issue can be announced (GitHub #98: T-4355,
then T-5095). Every other stage keeps the issue-wide check. Stubbed gh, no network."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(ROOT / "lib"))
from t4077_issues_comment_test import calls, env, rows, run  # noqa: E402,F401  (env is a fixture)
import issues  # noqa: E402

SHA = "5c97873a9f267f9979d92ac69cb17ee12495d64b"


def _posted(stub):
    return len([c for c in calls(stub) if c[:2] == ["issue", "comment"]])


def test_follow_up_fix_posts_and_same_fix_does_not(env):
    # in-progress: the same per-fix rule as fixed-on-bleeding-edge, without its GitHub commit check
    e, stub, ledger = env
    assert run(e, "comment", "98", "--stage", "in-progress", "--task", "T-4355").returncode == 0
    r = run(e, "comment", "98", "--stage", "in-progress", "--task", "T-5095")
    assert r.returncode == 0 and "already posted" not in r.stdout
    assert _posted(stub) == 2
    assert [x["tasks"] for x in rows(ledger)] == [["T-4355"], ["T-5095"]]
    r = run(e, "comment", "98", "--stage", "in-progress", "--task", "T-5095")
    assert r.returncode == 0 and "already posted" in r.stdout
    assert _posted(stub) == 2


def test_issue_wide_stage_still_posts_once(env):
    e, stub, ledger = env
    assert run(e, "comment", "98", "--stage", "classified", "--task", "T-4355", "--text", "x").returncode == 0
    r = run(e, "comment", "98", "--stage", "classified", "--task", "T-5095", "--text", "x")
    assert r.returncode == 0 and "already posted" in r.stdout
    assert _posted(stub) == 1


def test_stage_posted_rules(tmp_path, monkeypatch):
    # cmd_lifecycle uses the same check
    d = tmp_path / "issues"
    d.mkdir()
    (d / "intake.jsonl").write_text(json.dumps(
        {"issue": 98, "stage": "fixed-on-bleeding-edge", "tasks": ["T-4355"]}) + "\n")
    monkeypatch.setattr(issues, "_issues_dir", lambda: d)
    assert issues._stage_posted(98, "fixed-on-bleeding-edge", ["T-4355"])
    assert issues._stage_posted(98, "fixed-on-bleeding-edge", ["T-5095"]) is None
    assert issues._stage_posted(98, "fixed-on-bleeding-edge", None)       # no task: issue-wide
    assert issues._stage_posted(98, "fixed-on-bleeding-edge", [])
    assert issues._stage_posted(99, "fixed-on-bleeding-edge", ["T-4355"]) is None


def test_marker_fallback_on_the_issue_is_per_task(env):
    # the ledger lost the row; the maintainer's own marked comment on GitHub names T-4355
    e, stub, ledger = env
    body = "<!-- aef-intake:stage=in-progress -->\n**[AEF intake] In progress**\n\nTracked as **T-4355**."
    (stub / "view.json").write_text(json.dumps(
        {"author": {"login": "reporter"}, "comments": [{"author": {"login": "maint"}, "body": body}]}))
    r = run(e, "comment", "98", "--stage", "in-progress", "--task", "T-4355")
    assert r.returncode == 0 and "already marked on the issue" in r.stdout
    assert _posted(stub) == 0
    r = run(e, "comment", "98", "--stage", "in-progress", "--task", "T-43550")
    assert r.returncode == 0 and "already" not in r.stdout
    assert _posted(stub) == 1
