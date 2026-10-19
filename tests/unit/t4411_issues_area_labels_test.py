"""T-4411: area from the component fabric, area:/severity: labels at Classified and on refinement.
Stubbed gh on PATH (the t4077/t4078 fake), no network, fixtures in tmp_path."""
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

GH_STUB = r'''#!/usr/bin/env python3
import json, os, sys
d = os.environ["STUB_DIR"]
args = sys.argv[1:]
open(os.path.join(d, "calls.log"), "a").write(json.dumps(args) + "\n")
def rd(n, default=""):
    p = os.path.join(d, n)
    return open(p).read() if os.path.exists(p) else default
if args[:2] == ["issue", "list"]:
    sys.stdout.write(rd("issues.json", "[]")); sys.exit(0)
if args[:2] == ["api", "user"]:
    sys.stdout.write(rd("login.txt", "maint") + "\n"); sys.exit(0)
if args[:2] == ["issue", "view"]:
    sys.stdout.write(rd("view.json", '{"author":{"login":"reporter"},"comments":[],"labels":[]}')); sys.exit(0)
if args[:2] == ["label", "list"]:
    sys.stdout.write(rd("labels.json", "[]")); sys.exit(0)
if args[:2] == ["label", "create"]:
    sys.exit(0)
if args[:2] == ["issue", "comment"]:
    sys.stdin.read()
    print("https://github.com/o/r/issues/%s#issuecomment-1" % args[2]); sys.exit(0)
if args[:2] == ["issue", "edit"]:
    sys.exit(0)
sys.exit(9)
'''

CARD = """id: thing.sh
name: thing
type: script
subsystem: termlink-integration
location: agents/relay/thing.sh
"""


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
    (project / ".fabric" / "components").mkdir(parents=True)
    (project / ".fabric" / "components" / "thing.yaml").write_text(CARD)
    ledger = tmp_path / "issues"
    e = dict(os.environ, PATH=f"{bindir}:{os.environ['PATH']}", STUB_DIR=str(stub),
             FW_ISSUES_DECISIONS_STANDING_PERMISSION="0", FW_ISSUES_DIR=str(ledger),
             FW_ISSUES_REPO="o/r", FW_ISSUES_GIT_REMOTE="nonexistent-remote",
             PROJECT_ROOT=str(project))
    for k in ("CLAUDECODE", "AI_AGENT", "CLAUDE_CODE_ENTRYPOINT"):
        e.pop(k, None)
    return e, stub, ledger, project


def run(env_, *args, cwd=None):
    return subprocess.run([sys.executable, "-c", WRAP, *args], env=env_, cwd=cwd,
                          capture_output=True, text=True)


def calls(stub):
    p = stub / "calls.log"
    return [json.loads(x) for x in p.read_text().splitlines()] if p.exists() else []


def edits(stub):
    return [c for c in calls(stub) if c[:2] == ["issue", "edit"]]


def rows(ledger):
    p = ledger / "intake.jsonl"
    return [json.loads(x) for x in p.read_text().splitlines() if x.strip()] if p.exists() else []


def issue(n, title, body="Plain body.", labels=()):
    return {"number": n, "title": title, "body": body, "author": {"login": "reporter"},
            "labels": [{"name": x} for x in labels], "comments": []}


def sync_one(e, stub, it):
    (stub / "issues.json").write_text(json.dumps([it]))
    r = run(e, "sync")
    assert r.returncode == 0, r.stderr
    return [x for x in rows(Path(e["FW_ISSUES_DIR"])) if x["stage"] == "classified"][-1]


def flag(edit, name):
    return edit[edit.index(name) + 1].split(",") if name in edit else []


def test_path_rule_refines_framework_core(env):
    e, stub, ledger, _ = env
    cls = sync_one(e, stub, issue(201, "Bug: upgrade crashes", "In `lib/upgrade.sh:120` it fails on every run"))
    assert cls["area"] == "upgrade" and cls["severity"] == "high"
    added = flag(edits(stub)[-1], "--add-label")
    assert "triaged" in added and "area:upgrade" in added and "severity:high" in added
    created = [c[2] for c in calls(stub) if c[:2] == ["label", "create"]]
    assert "area:upgrade" in created and "severity:high" in created


def test_fabric_card_subsystem_maps_to_area(env):
    e, stub, ledger, _ = env
    cls = sync_one(e, stub, issue(202, "Bug: relay drops messages", "see agents/relay/thing.sh"))
    assert cls["area"] == "termlink"
    assert "area:termlink" in flag(edits(stub)[-1], "--add-label")


def test_fw_command_resolves(env):
    e, stub, ledger, _ = env
    cls = sync_one(e, stub, issue(203, "Bug: fw doctor warns about a timer", "Run `fw doctor`."))
    assert cls["area"] == "doctor"


def test_strong_area_beats_weak(env):
    e, stub, ledger, _ = env
    cls = sync_one(e, stub, issue(204, "Bug: x", "tests/unit/a.bats and docs/x.md and web/app.py"))
    assert cls["area"] == "watchtower"


def test_nothing_resolves_is_unspecified_and_unlabelled(env):
    e, stub, ledger, _ = env
    cls = sync_one(e, stub, issue(205, "Bug: something odd", "No paths here."))
    assert cls["area"] == "unspecified"
    added = flag(edits(stub)[-1], "--add-label")
    assert not any(x.startswith("area:") for x in added) and "severity:medium" in added


def _task(project, tid, n, components):
    (project / ".tasks" / "active" / f"{tid}-x.md").write_text(
        f"---\nid: {tid}\nname: x\ngithub_issue: {n}\ncomponents: [{', '.join(components)}]\n---\n\n## Verification\n")


def test_labels_verb_replaces_old_area_from_task_components(env):
    e, stub, ledger, project = env
    _task(project, "T-9001", 206, ["lib/upgrade.sh"])
    (stub / "view.json").write_text(json.dumps({
        "author": {"login": "reporter"}, "title": "Bug: watchtower thing", "body": "web/app.py",
        "labels": [{"name": "area:watchtower"}, {"name": "bug"}], "comments": []}))
    r = run(e, "labels", "206", "--task", "T-9001", "--dry-run")
    assert r.returncode == 0, r.stderr
    assert "area:upgrade" in r.stdout and edits(stub) == []
    r = run(e, "labels", "206", "--task", "T-9001")
    assert r.returncode == 0, r.stderr
    ed = edits(stub)
    assert len(ed) == 1
    assert flag(ed[0], "--remove-label") == ["area:watchtower"]
    assert "area:upgrade" in flag(ed[0], "--add-label")
    assert not any(c[:2] == ["issue", "comment"] for c in calls(stub))


def test_labels_verb_reads_severity_from_maintainer_classified_comment(env):
    e, stub, ledger, project = env
    (stub / "view.json").write_text(json.dumps({
        "author": {"login": "reporter"}, "title": "Bug: y", "body": "", "labels": [],
        "comments": [
            {"author": {"login": "reporter"}, "body": "<!-- aef-intake:stage=classified --> severity: low"},
            {"author": {"login": "maint"}, "body": "<!-- aef-intake:stage=classified -->\n"
             "Type: bug. Area: start (`bin/watchtower.sh:401`). Severity: high (exposed)."}]}))
    r = run(e, "labels", "207")
    assert r.returncode == 0, r.stderr
    added = flag(edits(stub)[-1], "--add-label")
    assert "area:watchtower" in added and "severity:high" in added


def test_labels_verb_no_change_no_edit(env):
    e, stub, ledger, project = env
    (stub / "view.json").write_text(json.dumps({
        "author": {"login": "reporter"}, "title": "Bug: y", "body": "web/app.py is wrong",
        "labels": [{"name": "area:watchtower"}, {"name": "severity:medium"}], "comments": []}))
    r = run(e, "labels", "208")
    assert r.returncode == 0, r.stderr
    assert edits(stub) == [] and "unchanged" in r.stdout


def test_lifecycle_closed_refines_area_even_when_post_fails(env):
    e, stub, ledger, project = env
    _task(project, "T-9002", 209, ["lib/upgrade.sh"])
    (stub / "view.json").write_text(json.dumps({
        "author": {"login": "reporter"}, "title": "Bug: z", "body": "",
        "labels": [{"name": "area:watchtower"}, {"name": "severity:low"}], "comments": []}))
    r = run(e, "lifecycle", "T-9002", "--event", "closed", "--root", str(project))
    assert r.returncode == 0, r.stderr
    ed = [x for x in edits(stub) if "--remove-label" in x]
    assert ed and flag(ed[0], "--remove-label") == ["area:watchtower"]
    assert flag(ed[0], "--add-label") == ["area:upgrade"]  # severity kept as it was
