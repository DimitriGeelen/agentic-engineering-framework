"""T-4053: /approvals and `fw review-queue` separate "ready for you" from
"waiting on the agent" with ONE predicate (web.shared.review_readiness).

Ready = >=1 unchecked Human criterion, every Agent criterion ticked, and no open
reviewer-judged Human criterion lacking a green verdict.
"""

import os
import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, ".")

from web import shared  # noqa: E402

FW_ROOT = Path(__file__).resolve().parents[2]

DETERMINISTIC = """- [ ] [RUBBER-STAMP] Run it
  **Steps:**
  1. Run `ls /tmp`
  **Expected:** output contains `tmp`
  **If not:** fix it
"""
TASTE = """- [ ] [REVIEW] Tone reads clearly
  **Steps:**
  1. Read it
  **Expected:** reads clearly, tone is right
  **If not:** note paragraphs
"""


def _task(tid, agent, human):
    return f"""---
id: {tid}
name: "fixture {tid}"
status: started-work
workflow_type: build
owner: agent
---

# {tid}

## Acceptance Criteria

### Agent
{agent}
### Human
{human}
## Verification
true
"""


@pytest.fixture
def proj(tmp_path, monkeypatch):
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    subprocess.run(["git", "init", "-q", str(tmp_path)], check=True)
    subprocess.run(["git", "-C", str(tmp_path), "-c", "user.name=t", "-c", "user.email=t@t",
                    "commit", "-q", "--allow-empty", "-m", "init"], check=True)
    monkeypatch.setattr(shared, "PROJECT_ROOT", tmp_path)
    shared._READINESS_CACHE.clear()
    shared._LEDGER_CACHE.clear()
    return tmp_path


def _readiness(proj, tid, text):
    p = proj / ".tasks" / "active" / f"{tid}-fixture.md"
    p.write_text(text)
    return shared.review_readiness(tid, "started-work", text, p)


def test_all_agent_ticked_and_open_human_is_ready(proj):
    state, why = _readiness(proj, "T-9001", _task("T-9001", "- [x] done\n", DETERMINISTIC))
    assert (state, why) == ("ready", [])


def test_open_agent_criterion_is_waiting_and_counted(proj):
    state, why = _readiness(proj, "T-9002",
                            _task("T-9002", "- [x] a\n- [ ] b\n- [ ] c\n", DETERMINISTIC))
    assert state == "waiting-on-agent"
    assert any("2 agent criteria open" in r for r in why)


def test_reviewer_judged_human_criterion_without_green_is_waiting(proj):
    state, why = _readiness(proj, "T-9003", _task("T-9003", "- [x] done\n", TASTE))
    assert state == "waiting-on-agent"
    assert any("independent review not green on criterion 1" in r for r in why)


def test_unreadable_ledger_never_reads_as_ready(proj, monkeypatch):
    import verdict_ledger as vl

    def boom(root):
        raise OSError("ledger gone")

    monkeypatch.setattr(vl, "load_ledger", boom)
    state, why = _readiness(proj, "T-9004", _task("T-9004", "- [x] done\n", TASTE))
    assert state == "waiting-on-agent"
    assert why


def test_batch_completion_predicate_unchanged():
    body = _task("T-9005", "- [x] a\n", "- [x] h\n")
    assert shared.is_ready_for_batch_completion("work-completed", body) is True
    assert shared.is_ready_for_batch_completion("started-work", body) is False


def _render(monkeypatch, ready, waiting):
    from web.app import app
    from web.blueprints import approvals as ap

    def row(tid, state, why):
        return {"task_id": tid, "name": f"name {tid}", "status": "started-work",
                "human_acs": [], "unchecked_count": 1, "age_days": 1, "is_stale": False,
                "sort_priority": 2, "verdict": "GO", "state": "GO", "reviewer": {},
                "origin": {}, "readiness": state, "wait_reasons": why}

    rows = [row(t, "ready", []) for t in ready] + \
           [row(t, "waiting-on-agent", ["1 agent criterion open"]) for t in waiting]
    monkeypatch.setattr(ap, "_load_pending_human_acs", lambda: rows)
    for name in ("_load_pending_approvals", "_load_resolved_approvals",
                 "_load_pending_go_decisions", "_load_decided_unclosed",
                 "_load_stale_keystones", "_load_paused_dispatches",
                 "_load_close_ready_arcs", "_load_batch_ready_tasks"):
        monkeypatch.setattr(ap, name, lambda: [], raising=False)
    monkeypatch.setattr(ap, "_count_deferred_inceptions", lambda: 0, raising=False)
    monkeypatch.setattr(ap, "_load_waiting_messages",
                        lambda: {"items": [], "error": None, "warn_hours": 24}, raising=False)
    import web.blueprints.bvp as bvp
    monkeypatch.setattr(bvp, "_load_proposals", lambda: [])
    return app.test_client().get("/approvals/content").get_data(as_text=True)


def test_approvals_renders_ready_group_before_waiting_group(monkeypatch):
    html = _render(monkeypatch, ["T-9101"], ["T-9102"])
    assert "Ready for you" in html and "Waiting on the agent" in html
    assert html.index("Ready for you") < html.index("Waiting on the agent")
    ready_part, waiting_part = html.split("Waiting on the agent", 1)
    assert "T-9101" in ready_part and "T-9102" not in ready_part
    assert "T-9102" in waiting_part and "1 agent criterion open" in waiting_part


def test_ready_count_counts_only_the_ready_group(monkeypatch):
    html = _render(monkeypatch, ["T-9101"], ["T-9102", "T-9103"])
    assert "across 1 task" in html


def test_review_queue_cli_agrees_with_page():
    """The CLI's default --ids and the page's ready group are the same set."""
    from web.blueprints import approvals as ap

    page_ready = {t["task_id"] for t in ap._load_pending_human_acs()
                  if t["readiness"] == "ready"}
    page_all = {t["task_id"] for t in ap._load_pending_human_acs()}
    env = dict(os.environ, PROJECT_ROOT=str(FW_ROOT))
    ids = subprocess.run([str(FW_ROOT / "bin" / "fw"), "review-queue", "--ids"], cwd=FW_ROOT,
                         env=env, capture_output=True, text=True, timeout=180).stdout.split()
    both = subprocess.run([str(FW_ROOT / "bin" / "fw"), "review-queue", "--ids",
                           "--include-waiting"], cwd=FW_ROOT, env=env,
                          capture_output=True, text=True, timeout=180).stdout.split()
    assert set(ids) == page_ready
    assert set(both) == page_all
