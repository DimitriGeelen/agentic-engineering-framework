"""T-5181 (build of T-5152, 832 T-1415): the accepted-miss criterion state `[~]`.

Drives the real surfaces on fixture projects in tmp dirs:
  - `lib/accepted_miss.py accept` (the verb behind `fw task accept-miss`) and its refusals;
  - `agents/task-create/update-task.sh --status work-completed` (P-010) end to end;
  - the episodic summary written at close;
  - `lib/accepted_miss.py audit` (the fw audit section) on committed history.
"""
from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

import pytest
import yaml

FW = Path(__file__).resolve().parents[2]
AM = FW / "lib" / "accepted_miss.py"
UPDATE = FW / "agents" / "task-create" / "update-task.sh"
LEDGER = ".context/reviews/accepted-misses.jsonl"

TASK = """---
id: {tid}
name: "accepted miss fixture"
description: fixture
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
created: 2026-11-16T00:00:00Z
last_update: 2026-11-16T00:00:00Z
---

# {tid}: fixture

## Context

**Background / trigger:** fixture.
**Problem / hypothesis:** fixture.
**Goal:** fixture.
**Expected outcome:** fixture.

## Acceptance Criteria

### Agent
- [x] First thing done
- [{box2}] Run was done the canonical way
  **Expected:** the run report says canonical
- [x] Third thing done
{human}
## Verification

test -f .framework.yaml

## Updates
"""

HUMAN = """
### Human
- [ ] [REVIEW] Operator likes it
  **Steps:** 1. look
  **Expected:** liked
  **If not:** say so
"""


def _env(**extra) -> dict:
    env = {k: v for k, v in os.environ.items() if k not in ("CLAUDECODE", "AI_AGENT")}
    env.update(NO_COLOR="1", FRAMEWORK_ROOT=str(FW))
    env.update(extra)
    return env


def _git(root: Path, *args: str) -> None:
    subprocess.run(["git", "-C", str(root), *args], check=True, capture_output=True)


@pytest.fixture
def proj(tmp_path: Path) -> Path:
    root = tmp_path / "p"
    for d in (".tasks/active", ".tasks/completed", ".context/working", ".context/episodic",
              ".context/project", ".context/reviews"):
        (root / d).mkdir(parents=True)
    (root / ".framework.yaml").write_text("id: TEST\n")
    _git(root, "init", "-q")
    _git(root, "config", "user.email", "t@example.invalid")
    _git(root, "config", "user.name", "t")
    _git(root, "commit", "-q", "--allow-empty", "-m", "init")
    return root


def _task(root: Path, tid: str = "T-9801", box2: str = " ", human: bool = False) -> Path:
    p = root / ".tasks" / "active" / f"{tid}-fixture.md"
    p.write_text(TASK.format(tid=tid, box2=box2, human=HUMAN if human else ""))
    return p


def _accept(root: Path, tid: str, ac: int, reason: str = "operator: run was ad hoc",
            *flags: str, **env) -> subprocess.CompletedProcess:
    return subprocess.run(["python3", str(AM), "accept", tid, "--ac", str(ac), "--reason", reason,
                           *flags], capture_output=True, text=True,
                          env=_env(PROJECT_ROOT=str(root), **env))


def _close(root: Path, tid: str = "T-9801") -> subprocess.CompletedProcess:
    return subprocess.run(["bash", str(UPDATE), tid, "--status", "work-completed"],
                          capture_output=True, text=True, cwd=root,
                          env=_env(PROJECT_ROOT=str(root)), timeout=300)


def _audit(root: Path) -> subprocess.CompletedProcess:
    return subprocess.run(["python3", str(AM), "audit"], capture_output=True, text=True,
                          env=_env(PROJECT_ROOT=str(root)))


# ── the verb ─────────────────────────────────────────────────────────────────

def test_accept_writes_box_annotation_and_ledger_row(proj):
    p = _task(proj)
    r = _accept(proj, "T-9801", 2)
    assert r.returncode == 0, r.stderr
    text = p.read_text()
    assert "- [~] Run was done the canonical way" in text
    rows = [json.loads(ln) for ln in (proj / LEDGER).read_text().splitlines()]
    assert len(rows) == 1
    row = rows[0]
    assert row["task"] == "T-9801" and row["ac"] == 2 and row["id"].startswith("AM-")
    assert row["reason"] == "operator: run was ad hoc" and len(row["digest"]) == 12
    assert f"  **Accepted miss:** {row['id']} — operator: run was ad hoc" in text
    # The annotation sits directly under the title; other criteria are untouched.
    lines = text.splitlines()
    i = lines.index("- [~] Run was done the canonical way")
    assert lines[i + 1].strip().startswith("**Accepted miss:**")
    assert "- [x] First thing done" in text and "- [x] Third thing done" in text


def test_accept_refused_under_agent_control_without_i_am_human(proj):
    p = _task(proj)
    before = p.read_text()
    for env in ({"CLAUDECODE": "1"}, {"AI_AGENT": "x"}):
        r = _accept(proj, "T-9801", 2, "r", **env)
        assert r.returncode == 2
        assert "REFUSED" in r.stderr and "operator" in r.stderr
    assert p.read_text() == before
    assert not (proj / LEDGER).exists()
    r = _accept(proj, "T-9801", 2, "r", "--i-am-human", CLAUDECODE="1")
    assert r.returncode == 0, r.stderr
    assert json.loads((proj / LEDGER).read_text())["by"] == "agent-override"


@pytest.mark.parametrize("ac,needle", [
    (1, "already met"),          # [x]
    (4, "no Agent criterion #4"),  # out of range
    (0, "no Agent criterion #0"),
])
def test_accept_refusals(proj, ac, needle):
    p = _task(proj, human=True)
    before = p.read_text()
    r = _accept(proj, "T-9801", ac)
    assert r.returncode == 1 and needle in r.stderr, r.stderr
    assert p.read_text() == before and not (proj / LEDGER).exists()


def test_accept_refuses_human_criteria(proj):
    # Un-split mode (no ### Agent): the Human criterion is never addressable as an Agent one.
    p = proj / ".tasks" / "active" / "T-9802-fixture.md"
    p.write_text(TASK.format(tid="T-9802", box2=" ", human=HUMAN).replace("### Agent\n", ""))
    r = _accept(proj, "T-9802", 4)
    assert r.returncode == 1 and "Human criterion" in r.stderr, r.stderr
    assert "- [ ] [REVIEW] Operator likes it" in p.read_text()


def test_accept_requires_reason(proj):
    _task(proj)
    r = _accept(proj, "T-9801", 2, "   ")
    assert r.returncode == 1 and "--reason" in r.stderr


# ── P-010 through update-task.sh ─────────────────────────────────────────────

def test_p010_valid_miss_closes_lists_it_and_never_counts_as_met(proj):
    _task(proj)
    assert _accept(proj, "T-9801", 2).returncode == 0
    row = json.loads((proj / LEDGER).read_text())
    r = _close(proj)
    out = r.stdout + r.stderr
    assert r.returncode == 0, out[-3000:]
    assert "2/3 met, closed with 1 accepted miss(es)" in out
    assert row["id"] in out and "Run was done the canonical way" in out
    assert "operator: run was ad hoc" in out
    assert (proj / ".tasks" / "completed" / "T-9801-fixture.md").exists()
    epi = yaml.safe_load((proj / ".context" / "episodic" / "T-9801.yaml").read_text())
    assert epi["accepted_misses"] == [{"id": row["id"], "criterion": "Run was done the canonical way",
                                       "reason": "operator: run was ad hoc"}]
    # Never met: the outcomes list (ticked criteria) does not carry it.
    assert all("canonical" not in str(o) for o in epi.get("outcomes") or [])


def test_p010_bare_tilde_blocks_and_names_criterion(proj):
    _task(proj, box2="~")
    r = _close(proj)
    assert r.returncode != 0
    assert "1/3 agent AC unchecked" in r.stderr
    assert "Run was done the canonical way" in r.stderr and "AC#2" in r.stderr
    assert "without an **Accepted miss:** annotation" in r.stderr
    assert (proj / ".tasks" / "active" / "T-9801-fixture.md").exists()


def test_p010_stale_tilde_after_edit_blocks(proj):
    p = _task(proj)
    assert _accept(proj, "T-9801", 2).returncode == 0
    p.write_text(p.read_text().replace("the run report says canonical", "the report says fine"))
    r = _close(proj)
    assert r.returncode != 0
    assert "stale" in r.stderr and "Run was done the canonical way" in r.stderr


def test_p010_annotation_citing_unknown_id_blocks(proj):
    p = _task(proj)
    assert _accept(proj, "T-9801", 2).returncode == 0
    (proj / LEDGER).write_text("")
    r = _close(proj)
    assert r.returncode != 0 and "has no such row" in r.stderr
    assert p.exists()


@pytest.mark.parametrize("ch", ["?", "-", "o"])
def test_p010_unknown_box_char_blocks(proj, ch):
    _task(proj, box2=ch)
    r = _close(proj)
    assert r.returncode != 0
    assert f"unknown box state [{ch}]" in r.stderr and "Run was done the canonical way" in r.stderr


def test_p010_miss_proposed_line_changes_nothing(proj):
    p = _task(proj)
    p.write_text(p.read_text().replace(
        "  **Expected:** the run report", "  **Miss proposed:** run was ad hoc, see report\n"
        "  **Expected:** the run report"))
    r = _close(proj)
    assert r.returncode != 0 and "1/3 agent AC unchecked" in r.stderr
    # ... and a proposal added after acceptance does not void it (excluded from the digest).
    assert _accept(proj, "T-9801", 2).returncode == 0
    p.write_text(p.read_text().replace("see report", "see report, and more evidence"))
    assert _close(proj).returncode == 0


def test_p010_human_tilde_stays_unchecked(proj):
    p = _task(proj, box2="x", human=True)
    p.write_text(p.read_text().replace("- [ ] [REVIEW] Operator", "- [~] [REVIEW] Operator"))
    r = _close(proj)
    out = r.stdout + r.stderr
    # Agent side all met; the Human [~] is not a tick: partial-complete, stays in active/.
    assert "Human: 0/1 checked" in out, out[-2000:]
    assert p.exists()


# ── audit ────────────────────────────────────────────────────────────────────

def test_audit_fails_on_committed_bare_tilde(proj):
    _task(proj, box2="~")
    _git(proj, "add", "-A")
    _git(proj, "commit", "-qm", "bare")
    r = _audit(proj)
    assert r.returncode == 2 and "T-9801 criterion #2" in r.stdout, r.stdout


def test_audit_passes_on_backed_tilde(proj):
    _task(proj)
    assert _accept(proj, "T-9801", 2).returncode == 0
    _git(proj, "add", "-A")
    _git(proj, "commit", "-qm", "accepted")
    r = _audit(proj)
    assert r.returncode == 0 and "1 committed" in r.stdout, r.stdout


def test_audit_fails_on_non_append_only_ledger(proj):
    _task(proj)
    assert _accept(proj, "T-9801", 2).returncode == 0
    _git(proj, "add", "-A")
    _git(proj, "commit", "-qm", "accepted")
    led = proj / LEDGER
    row = json.loads(led.read_text())
    row["reason"] = "rewritten"
    led.write_text(json.dumps(row, sort_keys=True) + "\n")
    _git(proj, "commit", "-qam", "rewrite")
    r = _audit(proj)
    assert r.returncode == 2 and "append-only" in r.stdout, r.stdout


def test_audit_grandfathers_tilde_older_than_the_module(proj):
    _task(proj, box2="~")
    _git(proj, "add", "-A")
    _git(proj, "commit", "-qm", "legacy")
    (proj / "lib").mkdir()
    (proj / "lib" / "accepted_miss.py").write_text("# anchor\n")
    _git(proj, "add", "-A")
    _git(proj, "commit", "-qm", "module lands")
    r = _audit(proj)
    assert r.returncode == 0 and "1 pre-T-5181 [~] grandfathered" in r.stdout, r.stdout
    # A new bare [~] after the module landed is not grandfathered.
    _task(proj, tid="T-9803", box2="~")
    _git(proj, "add", "-A")
    _git(proj, "commit", "-qm", "new bare")
    r = _audit(proj)
    assert r.returncode == 2 and "T-9803" in r.stdout and "T-9801" not in r.stdout.split("\n")[0]
