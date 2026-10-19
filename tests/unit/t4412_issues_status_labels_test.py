"""T-4412: status:* labels are mutually exclusive. Stubbed gh on PATH (the t4077 fake, extended
so `issue view` returns labels and `issue edit` applies them), no network, fixtures in tmp_path."""
import json
import os
import stat
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
WRAP = ("import sys; sys.path.insert(0, %r); import issues; issues._agent_ancestry = lambda: False; "
        "sys.exit(issues.main(sys.argv[1:]))" % str(ROOT / "lib"))

# The stub keeps the issue's label set in labels_on.json so a sequence of stages can be checked.
GH_STUB = r'''#!/usr/bin/env python3
import json, os, sys
d = os.environ["STUB_DIR"]
args = sys.argv[1:]
open(os.path.join(d, "calls.log"), "a").write(json.dumps(args) + "\n")
lp = os.path.join(d, "labels_on.json")
on = json.load(open(lp)) if os.path.exists(lp) else []
if args[:2] == ["api", "user"]:
    print("maint"); sys.exit(0)
if args[:2] == ["issue", "view"]:
    print(json.dumps({"author": {"login": "reporter"}, "title": "t", "body": "", "comments": [],
                      "labels": [{"name": x} for x in on]})); sys.exit(0)
if args[:2] == ["label", "list"]:
    print("[]"); sys.exit(0)
if args[:2] == ["label", "create"]:
    sys.exit(0)
if args[:2] == ["issue", "comment"]:
    sys.stdin.read()
    print("https://github.com/o/r/issues/%s#issuecomment-1" % args[2]); sys.exit(0)
if args[:2] == ["issue", "edit"]:
    for flag, fn in (("--remove-label", "rm"), ("--add-label", "add")):
        if flag in args:
            names = args[args.index(flag) + 1].split(",")
            on = [x for x in on if x not in names] if fn == "rm" else on + [x for x in names if x not in on]
    json.dump(on, open(lp, "w")); sys.exit(0)
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
    e = dict(os.environ, PATH=f"{bindir}:{os.environ['PATH']}", STUB_DIR=str(stub),
             FW_ISSUES_DECISIONS_STANDING_PERMISSION="0", FW_ISSUES_DIR=str(ledger),
             FW_ISSUES_REPO="o/r", FW_ISSUES_GIT_REMOTE="github", PROJECT_ROOT=str(tmp_path))
    for k in ("CLAUDECODE", "AI_AGENT", "CLAUDE_CODE_ENTRYPOINT"):
        e.pop(k, None)
    return e, stub, ledger


def run(env_, *args):
    return subprocess.run([sys.executable, "-c", WRAP, *args], env=env_, capture_output=True, text=True)


def on(stub):
    p = stub / "labels_on.json"
    return json.loads(p.read_text()) if p.exists() else []


def edits(stub):
    p = stub / "calls.log"
    return [c for c in (json.loads(x) for x in p.read_text().splitlines()) if c[:2] == ["issue", "edit"]]


def test_next_stage_replaces_previous_status_label_in_one_edit(env):
    e, stub, ledger = env
    (stub / "labels_on.json").write_text(json.dumps(
        ["bug", "triaged", "area:upgrade", "severity:high", "status:received", "status:accepted"]))
    r = run(e, "comment", "86", "--stage", "in-progress", "--task", "T-1")
    assert r.returncode == 0, r.stderr
    ed = edits(stub)
    assert len(ed) == 1
    assert ed[0][ed[0].index("--remove-label") + 1].split(",") == ["status:received", "status:accepted"]
    assert ed[0][-1] == "status:in-progress"
    assert on(stub) == ["bug", "triaged", "area:upgrade", "severity:high", "status:in-progress"]


def test_legacy_unprefixed_label_removed_and_never_added(env):
    e, stub, ledger = env
    (stub / "labels_on.json").write_text(json.dumps(
        ["bug", "status:fixed-on-bleeding-edge", "fixed-on-bleeding-edge"]))
    r = run(e, "comment", "86", "--stage", "released", "--task", "T-1", "--version", "v1.9.0")
    assert r.returncode == 0, r.stderr
    assert on(stub) == ["bug", "status:released"]
    import importlib
    sys.path.insert(0, str(ROOT / "lib"))
    issues = importlib.import_module("issues")
    assert issues.STAGE_LABELS["fixed-on-bleeding-edge"] == ["status:fixed-on-bleeding-edge"]


def test_classified_removes_no_status_label(env):
    e, stub, ledger = env
    (stub / "labels_on.json").write_text(json.dumps(["status:received"]))
    r = run(e, "comment", "86", "--stage", "classified", "--text", "- Type: bug")
    assert r.returncode == 0, r.stderr
    assert "--remove-label" not in edits(stub)[0]
    assert on(stub) == ["status:received", "triaged"]


def test_status_labels_verb_sets_latest_ledger_stage(env):
    e, stub, ledger = env
    ledger.mkdir()
    (ledger / "intake.jsonl").write_text("".join(json.dumps(r) + "\n" for r in [
        {"issue": 99, "stage": "received"}, {"issue": 99, "stage": "classified+accepted"},
        {"issue": 99, "stage": "in-progress"}, {"issue": 99, "stage": "fixed-on-bleeding-edge"},
        {"issue": 99, "stage": "reply"}, {"issue": 99, "stage": "baseline"},
        {"issue": 98, "stage": "released"}]))
    (stub / "labels_on.json").write_text(json.dumps(
        ["bug", "triaged", "status:received", "status:accepted", "status:in-progress",
         "status:fixed-on-bleeding-edge", "fixed-on-bleeding-edge", "area:doctor"]))
    r = run(e, "status-labels", "99", "--dry-run")
    assert r.returncode == 0, r.stderr
    assert "status:fixed-on-bleeding-edge" in r.stdout and edits(stub) == []
    r = run(e, "status-labels", "99")
    assert r.returncode == 0, r.stderr
    assert on(stub) == ["bug", "triaged", "status:fixed-on-bleeding-edge", "area:doctor"]
    r = run(e, "status-labels", "99")
    assert "unchanged" in r.stdout and len(edits(stub)) == 1
    p = stub / "calls.log"
    assert not any(json.loads(x)[:2] == ["issue", "comment"] for x in p.read_text().splitlines())
