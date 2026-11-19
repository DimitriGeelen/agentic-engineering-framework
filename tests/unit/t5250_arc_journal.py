"""T-5250: arc journal (append-only) + resumability check + update-task.sh event hook.

Every test uses a temporary project root; the real .context/arcs is never touched.
Run: python3 -m pytest tests/unit/t5250_arc_journal.py -q
"""

from __future__ import annotations

import datetime as dt
import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

FW = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW))

from lib import arc_journal as aj  # noqa: E402

CLI = [sys.executable, str(FW / "lib" / "arc_journal.py")]


def _arc(root: Path, slug: str, numeric: str, journal: bool | None) -> Path:
    d = root / ".context" / "arcs"
    d.mkdir(parents=True, exist_ok=True)
    extra = "" if journal is None else f"journal: {'true' if journal else 'false'}\n"
    p = d / f"{slug}.yaml"
    p.write_text(f"id: {numeric}\nslug: {slug}\nname: \"fixture\"\nstatus: in-progress\n{extra}")
    return p


@pytest.fixture
def root(tmp_path, monkeypatch):
    _arc(tmp_path, "demo-arc", "arc-901", journal=True)
    _arc(tmp_path, "plain-arc", "arc-902", journal=None)
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    return tmp_path


def _cli(root, *args):
    env = {**os.environ, "PROJECT_ROOT": str(root)}
    return subprocess.run(CLI + list(args), capture_output=True, text=True, env=env, cwd=root)


# ---------------------------------------------------------------- append / read

def test_append_and_read_back_by_slug_and_numeric(root):
    aj.append("demo-arc", "tried", "agent", text="spike A", result="failed: timeout")
    aj.append("arc-901", "decided", "operator", text="use B", reason="A times out", consequential=True)
    aj.append("demo-arc", "next", "agent", step="build B", owner="agent", deadline="2099-01-01")
    aj.append("demo-arc", "outside", "operator", text="freeze lifted", reason="v1.9 out", where="chat 2026-11-19")
    aj.append("demo-arc", "event", "update-task", task="T-1", **{"from": "captured", "to": "started-work"})
    path = root / ".context" / "arcs" / "demo-arc.journal.jsonl"
    assert path.is_file()
    entries, bad = aj.read("arc-901")
    assert bad == []
    assert [e["kind"] for e in entries] == ["tried", "decided", "next", "outside", "event"]
    for e in entries:
        assert e["ts"].endswith("Z") and e["by"]
    assert entries[1]["consequential"] is True
    assert entries[2]["deadline"] == "2099-01-01"
    assert entries[3]["where"] == "chat 2026-11-19"
    assert entries[4]["from"] == "captured" and entries[4]["to"] == "started-work"


def test_decided_defaults_consequential_false(root):
    row = aj.append("demo-arc", "decided", "agent", text="x", reason="y")
    assert row["consequential"] is False


def test_append_only_never_rewrites_earlier_rows(root):
    aj.append("demo-arc", "tried", "agent", text="one", result="ok")
    path = root / ".context" / "arcs" / "demo-arc.journal.jsonl"
    before = path.read_bytes()
    ino = path.stat().st_ino
    aj.append("demo-arc", "tried", "agent", text="two", result="ok")
    after = path.read_bytes()
    assert after.startswith(before)
    assert path.stat().st_ino == ino  # same file, not replaced
    assert after.count(b"\n") == 2


def test_append_after_torn_line_starts_new_line_and_reports_torn(root):
    path = root / ".context" / "arcs" / "demo-arc.journal.jsonl"
    path.write_text('{"ts": "x", "kind": "tri')  # crash mid-write
    aj.append("demo-arc", "tried", "agent", text="after", result="ok")
    entries, bad = aj.read("demo-arc")
    assert len(entries) == 1 and entries[0]["text"] == "after"
    assert len(bad) == 1 and bad[0]["line"] == 1


def test_concurrent_appends_are_all_kept(root):
    import multiprocessing as mp
    procs = [mp.Process(target=aj.append, args=("demo-arc", "tried", f"w{i}"),
                        kwargs={"text": f"t{i}", "result": "ok", "project_root": str(root)})
             for i in range(8)]
    for p in procs:
        p.start()
    for p in procs:
        p.join()
    entries, bad = aj.read("demo-arc")
    assert bad == [] and len(entries) == 8


@pytest.mark.parametrize("kind,fields,msg", [
    ("nope", {}, "unknown kind"),
    ("tried", {"text": "x"}, "needs 'result'"),
    ("next", {"step": "x"}, "needs 'owner'"),
    ("outside", {"text": "x", "reason": "y"}, "needs 'where'"),
    ("event", {"task": "T-1", "to": "x"}, "needs 'from'"),
    ("next", {"step": "x", "owner": "y", "deadline": "tomorrow"}, "YYYY-MM-DD"),
    ("tried", {"text": "x", "result": "y", "step": "z"}, "does not take"),
])
def test_validation_refuses(root, kind, fields, msg):
    with pytest.raises(aj.JournalError, match=msg):
        aj.append("demo-arc", kind, "agent", **fields)
    assert not (root / ".context" / "arcs" / "demo-arc.journal.jsonl").exists()


def test_missing_by_refused(root):
    with pytest.raises(aj.JournalError, match="by"):
        aj.append("demo-arc", "tried", "", text="x", result="y")


def test_unknown_arc_refused(root):
    with pytest.raises(aj.JournalError, match="unknown arc"):
        aj.append("no-such-arc", "tried", "agent", text="x", result="y")


def test_malformed_line_is_reported_not_dropped(root):
    aj.append("demo-arc", "tried", "agent", text="ok", result="ok")
    path = root / ".context" / "arcs" / "demo-arc.journal.jsonl"
    with open(path, "a") as fh:
        fh.write("garbage\n")
        fh.write(json.dumps({"ts": "t", "kind": "next", "by": "a", "step": "s"}) + "\n")
    entries, bad = aj.read("demo-arc")
    assert len(entries) == 1 and [b["line"] for b in bad] == [2, 3]
    findings, ok = aj.check("demo-arc")
    assert not ok and sum(f["code"] == "MALFORMED_ROW" for f in findings) == 2


# ---------------------------------------------------------------- check

def _codes(findings):
    return {f["code"] for f in findings}


def test_check_resumable(root):
    aj.append("demo-arc", "decided", "operator", text="go", reason="evidence")
    aj.append("demo-arc", "next", "agent", step="build", owner="agent", deadline="2099-12-31")
    findings, ok = aj.check("demo-arc")
    assert ok and findings == []


def test_check_no_next(root):
    aj.append("demo-arc", "tried", "agent", text="x", result="y")
    findings, ok = aj.check("demo-arc")
    assert not ok and _codes(findings) == {"NO_NEXT"}


def test_check_empty_journal_is_no_next(root):
    findings, ok = aj.check("demo-arc")
    assert not ok and _codes(findings) == {"NO_NEXT"}


@pytest.mark.parametrize("kind,fields", [
    ("decided", {"text": "x", "reason": "y"}),
    ("outside", {"text": "x", "reason": "y", "where": "chat"}),
    ("event", {"task": "T-1", "from": "captured", "to": "started-work"}),
])
def test_check_stale_next(root, kind, fields):
    aj.append("demo-arc", "next", "agent", step="old step", owner="agent")
    aj.append("demo-arc", kind, "someone", **fields)
    findings, ok = aj.check("demo-arc")
    assert not ok and _codes(findings) == {"STALE_NEXT"}
    assert "old step" in findings[0]["reason"]


def test_tried_after_next_does_not_make_it_stale(root):
    aj.append("demo-arc", "next", "agent", step="s", owner="agent")
    aj.append("demo-arc", "tried", "agent", text="x", result="y")
    assert aj.check("demo-arc")[1] is True


def test_check_issues_without_decision(root):
    aj.append("demo-arc", "event", "update-task", task="T-7", **{"from": "started-work", "to": "issues"})
    aj.append("demo-arc", "next", "agent", step="s", owner="agent")
    findings, ok = aj.check("demo-arc")
    assert not ok and _codes(findings) == {"ISSUES_WITHOUT_DECISION"}
    assert "T-7" in findings[0]["reason"]
    aj.append("demo-arc", "decided", "agent", text="retry", reason="flake")
    aj.append("demo-arc", "next", "agent", step="s2", owner="agent")
    assert aj.check("demo-arc") == ([], True)


def test_check_deadline_passed_is_informational(root):
    aj.append("demo-arc", "next", "agent", step="s", owner="agent", deadline="2020-01-01")
    findings, ok = aj.check("demo-arc")
    assert ok
    assert _codes(findings) == {"DEADLINE_PASSED"} and findings[0]["blocking"] is False
    # Not passed when today is before the deadline
    findings, ok = aj.check("demo-arc", today=dt.date(2019, 1, 1))
    assert ok and findings == []


# ---------------------------------------------------------------- CLI

def test_cli_append_show_check(root):
    r = _cli(root, "append", "demo-arc", "next", "--by", "agent", "--step", "do it", "--owner", "agent")
    assert r.returncode == 0, r.stderr
    assert json.loads(r.stdout)["step"] == "do it"
    r = _cli(root, "show", "arc-901", "--json")
    assert r.returncode == 0 and json.loads(r.stdout)["entries"][0]["kind"] == "next"
    r = _cli(root, "check", "demo-arc")
    assert r.returncode == 0 and "resumable" in r.stdout
    _cli(root, "append", "demo-arc", "decided", "--by", "op", "--text", "t", "--reason", "r", "--consequential")
    r = _cli(root, "check", "demo-arc", "--json")
    assert r.returncode == 1 and json.loads(r.stdout)["findings"][0]["code"] == "STALE_NEXT"
    assert json.loads(_cli(root, "show", "demo-arc", "--json").stdout)["entries"][1]["consequential"] is True


def test_cli_usage_and_unknown_arc_exit_2(root):
    assert _cli(root, "check", "no-such-arc").returncode == 2
    assert _cli(root, "append", "demo-arc", "bogus", "--by", "x").returncode == 2
    assert _cli(root, "append", "demo-arc", "tried").returncode == 2  # missing --by
    assert _cli(root).returncode == 2


# ---------------------------------------------------------------- arc YAML field compatibility

def test_journal_field_keeps_arc_yaml_valid_and_journal_is_not_yaml(root):
    """Audit's YAML-parse check and arc readers glob *.yaml and need a mapping."""
    import yaml
    aj.append("demo-arc", "tried", "agent", text="x", result="y")
    arcs = root / ".context" / "arcs"
    data = yaml.safe_load((arcs / "demo-arc.yaml").read_text())
    assert isinstance(data, dict) and data["journal"] is True and data["slug"] == "demo-arc"
    assert sorted(p.name for p in arcs.glob("*.yaml")) == ["demo-arc.yaml", "plain-arc.yaml"]
    from lib.arc_membership import arc_identities
    assert arc_identities(root, "arc-901") == ("demo-arc", "arc-901")
    assert aj.journal_enabled("demo-arc") and not aj.journal_enabled("plain-arc")


# ---------------------------------------------------------------- update-task.sh hook

def _task(root: Path, tid: str, arc: str | None) -> Path:
    d = root / ".tasks" / "active"
    d.mkdir(parents=True, exist_ok=True)
    (root / ".tasks" / "completed").mkdir(parents=True, exist_ok=True)
    arc_line = f"arc_id: {arc}\n" if arc else ""
    p = d / f"{tid}-fixture.md"
    p.write_text(f"""---
id: {tid}
name: "fixture"
description: fixture
status: captured
workflow_type: build
owner: agent
horizon: now
{arc_line}created: 2026-11-19T00:00:00Z
last_update: 2026-11-19T00:00:00Z
---

# {tid}: fixture

## Context

**Background / trigger:** test. **Problem / hypothesis:** test. **Goal:** test. **Expected outcome:** test.

## Acceptance Criteria

### Agent
- [ ] Real criterion for the fixture task

## Verification

true

## Updates
""")
    return p


def _update(root: Path, tid: str, status: str):
    for sub in ("working", "episodic", "project"):
        (root / ".context" / sub).mkdir(parents=True, exist_ok=True)
    fy = root / ".framework.yaml"
    if not fy.exists():
        fy.write_text("id: TEST\n")
    env = {k: v for k, v in os.environ.items() if k not in ("CLAUDECODE",)}
    env.update({
        "PROJECT_ROOT": str(root), "FRAMEWORK_ROOT": str(FW), "AGENTS_DIR": str(FW / "agents"),
        "FW_LIB_DIR": str(FW / "lib"), "TASKS_DIR": str(root / ".tasks"),
        "CONTEXT_DIR": str(root / ".context"), "NO_COLOR": "1", "FW_ISSUES_LIFECYCLE": "0",
        "FW_REVIEWER_DISABLED": "1", "WATCHTOWER_URL": "http://test.invalid:3000",
    })
    return subprocess.run(["bash", str(FW / "agents" / "task-create" / "update-task.sh"), tid,
                           "--status", status], capture_output=True, text=True, env=env, cwd=root,
                          timeout=180)


def _status(task: Path) -> str:
    for line in task.read_text().splitlines():
        if line.startswith("status:"):
            return line.split(":", 1)[1].strip()
    return ""


def test_update_task_appends_event_for_opted_in_arc(root):
    t = _task(root, "T-9001", "arc-901")  # numeric form resolves to demo-arc
    r = _update(root, "T-9001", "started-work")
    assert _status(t) == "started-work", r.stdout + r.stderr
    entries, bad = aj.read("demo-arc")
    assert bad == []
    assert [(e["kind"], e["task"], e["from"], e["to"], e["by"]) for e in entries] == \
        [("event", "T-9001", "captured", "started-work", "update-task")]


def test_update_task_no_event_for_arc_without_field(root):
    t = _task(root, "T-9002", "plain-arc")
    _update(root, "T-9002", "started-work")
    assert _status(t) == "started-work"
    assert not (root / ".context" / "arcs" / "plain-arc.journal.jsonl").exists()


def test_update_task_no_event_for_journal_false(root):
    _arc(root, "off-arc", "arc-903", journal=False)
    t = _task(root, "T-9004", "off-arc")
    _update(root, "T-9004", "started-work")
    assert _status(t) == "started-work"
    assert not (root / ".context" / "arcs" / "off-arc.journal.jsonl").exists()


def test_broken_journal_does_not_block_status_change(root):
    t = _task(root, "T-9003", "demo-arc")
    # Journal path is a directory: every append fails with an OSError.
    (root / ".context" / "arcs" / "demo-arc.journal.jsonl").mkdir()
    r = _update(root, "T-9003", "started-work")
    assert _status(t) == "started-work", r.stdout + r.stderr
    assert "arc journal event not written" in r.stderr
