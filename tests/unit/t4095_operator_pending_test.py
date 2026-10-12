"""T-4095: fw operator pending reads live state; decided inceptions are never listed or re-asked."""
import json
import os
import subprocess
from pathlib import Path

FW = Path(__file__).resolve().parents[2]


def _task(tid, wt, name, body, status="started-work"):
    return (f"---\nid: {tid}\nname: \"{name}\"\nstatus: {status}\nworkflow_type: {wt}\nowner: agent\n"
            f"horizon: now\ncreated: 2026-10-01T00:00:00Z\nlast_update: 2026-10-01T00:00:00Z\n---\n\n# {tid}\n\n{body}\n")


REC = "## Recommendation\n\n**Recommendation:** GO\n\n**Rationale:** because.\n\n"
DECIDED = "## Decision\n\n**Decision**: GO\n\n**Date**: 2026-10-12T11:11:33Z\n"
UNDECIDED = "## Decision\n\n**Decision**: [GO / NO-GO / DEFER]\n"
READY = "## Acceptance Criteria\n\n### Agent\n- [x] done\n\n### Human\n- [ ] [REVIEW] Publish the release to production and confirm it is live\n  **Steps:**\n  1. look\n  **Expected:** fine\n  **If not:** tell\n"
WAITING = READY.replace("- [x] done", "- [ ] not done")


def _run(root, *args):
    env = {**os.environ, "PROJECT_ROOT": str(root), "FRAMEWORK_ROOT": str(FW)}
    return subprocess.run(["python3", "-I", str(FW / "lib/operator_pending.py"), *args],
                          capture_output=True, text=True, env=env, cwd=root)


def _git(root, *a):
    subprocess.run(["git", "-C", str(root), "-c", "user.email=t@t", "-c", "user.name=t", *a],
                   check=True, capture_output=True)


def _project(tmp_path):
    act = tmp_path / ".tasks" / "active"
    act.mkdir(parents=True)
    (act / "T-9001-decided.md").write_text(_task("T-9001", "inception", "decided one", REC + DECIDED))
    (act / "T-9002-open.md").write_text(_task("T-9002", "inception", "open one", REC + UNDECIDED))
    (act / "T-9003-reverted.md").write_text(_task("T-9003", "inception", "reverted one", REC + UNDECIDED))
    (act / "T-9004-ready.md").write_text(_task("T-9004", "build", "ready one", READY))
    (act / "T-9005-waiting.md").write_text(_task("T-9005", "build", "waiting one", WAITING))
    rm = tmp_path / ".context" / "runme" / "pending-one"
    rm.mkdir(parents=True)
    (rm / "runme.sh").write_text("#!/bin/bash\n")
    (tmp_path / ".context" / "working").mkdir(parents=True)
    (tmp_path / ".context" / "working" / "watchtower.url").write_text("http://wt.test:1234\n")
    subprocess.run(["git", "init", "-q", str(tmp_path)], check=True)
    _git(tmp_path, "add", ".")
    _git(tmp_path, "commit", "-qm", "init")
    _git(tmp_path, "commit", "-q", "--allow-empty", "-m", "T-9003: inception decision NO-GO (via Watchtower)")
    return tmp_path


def test_pending_lists_live_state_only(tmp_path):
    root = _project(tmp_path)
    r = _run(root, "pending", "--json")
    assert r.returncode == 0, r.stderr
    d = json.loads(r.stdout)
    inc = {i["id"] for i in d["inceptions"]}
    assert inc == {"T-9002"}, inc                      # decided (file) and decided (commit) absent
    assert {x["id"] for x in d["reviews"]} == {"T-9004"}  # waiting-on-agent absent
    assert d["waiting_on_agent"] == 1
    assert [x["name"] for x in d["runmes"]] == ["pending-one"]
    text = _run(root, "pending").stdout
    assert "T-9001" not in text and "T-9003" not in text and "T-9005" not in text
    assert "http://wt.test:1234/inception/T-9002" in text


def test_decided_inception_refused_by_review_helper(tmp_path):
    root = _project(tmp_path)
    r = _run(root, "decided", str(root / ".tasks/active/T-9001-decided.md"))
    assert r.returncode == 0 and r.stdout.startswith("already decided: GO on 2026-10-12")
    r = _run(root, "decided", str(root / ".tasks/active/T-9003-reverted.md"))
    assert r.returncode == 0 and "NO-GO" in r.stdout and "via Watchtower" in r.stdout
    assert _run(root, "decided", str(root / ".tasks/active/T-9002-open.md")).returncode == 1
    assert _run(root, "decided", str(root / ".tasks/active/T-9004-ready.md")).returncode == 1


def test_review_emit_prints_no_decide_link_for_decided(tmp_path):
    root = _project(tmp_path)
    script = (f'export PROJECT_ROOT={root} FRAMEWORK_ROOT={FW}; source {FW}/lib/watchtower.sh 2>/dev/null; '
              f'source {FW}/lib/review.sh 2>/dev/null; '
              f'emit_review T-9001; echo "rc=$?"; emit_review_batch T-9001 T-9002')
    r = subprocess.run(["bash", "-c", script], capture_output=True, text=True, cwd=root)
    out = r.stdout
    assert "T-9001: already decided: GO" in out and "rc=0" in out
    assert "/inception/T-9001" not in out
    assert "| T-9001 | inception | already decided: GO" in out
