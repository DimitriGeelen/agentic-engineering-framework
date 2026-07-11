"""Unit tests for the Child-2 forward compiler (tools/bpmn_to_tasks.py, T-2531).

Verifies the first-slice invariants: aef:uid extraction from <extensionElements>
(IW-1), lane->owner mapping (IW-7), O-1 Lane-wins+warn for a serviceTask in a human
lane, and that every emitted skeleton is parseable YAML frontmatter (never a stub).
"""
import os
import sys

import yaml

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO_ROOT, "tools"))

import bpmn_to_tasks  # noqa: E402

FIXTURE = os.path.join(REPO_ROOT, "tests", "fixtures", "bpmn", "two-lane-sample.bpmn")


def _by_uid(skeletons):
    return {s["uid"]: s for s in skeletons}


def test_extracts_all_task_nodes_with_uid():
    """Each userTask/serviceTask/scriptTask is extracted with its aef:uid (IW-1)."""
    skeletons, _ = bpmn_to_tasks.parse_bpmn(FIXTURE)
    by_uid = _by_uid(skeletons)
    assert set(by_uid) == {"u-review-001", "u-compile-002", "u-escalate-003"}
    # start/end events are NOT tasks — must not appear
    assert len(skeletons) == 3


def test_lane_to_owner_mapping_both_lanes():
    """Human lane -> owner:human; Agent lane -> owner:agent (IW-7)."""
    skeletons, _ = bpmn_to_tasks.parse_bpmn(FIXTURE)
    by_uid = _by_uid(skeletons)
    assert by_uid["u-review-001"]["owner"] == "human"   # userTask, Human lane
    assert by_uid["u-compile-002"]["owner"] == "agent"   # serviceTask, Agent lane


def test_o1_lane_wins_with_warning():
    """A serviceTask in a human lane resolves owner=human (Lane wins) AND warns (O-1)."""
    skeletons, warnings = bpmn_to_tasks.parse_bpmn(FIXTURE)
    by_uid = _by_uid(skeletons)
    assert by_uid["u-escalate-003"]["owner"] == "human"  # Lane wins over serviceTask
    assert any("Task_escalate" in w and "Lane wins" in w for w in warnings)


def test_skeleton_is_real_frontmatter_not_placeholder():
    """Every emitted block round-trips through yaml.safe_load with real fields."""
    out, _ = bpmn_to_tasks.compile_to_tasks(FIXTURE)
    blocks = [b for b in out.split("---") if b.strip()]
    assert len(blocks) == 3
    for b in blocks:
        doc = yaml.safe_load(b)
        assert doc["id"].startswith("u-")
        assert doc["name"]
        assert doc["owner"] in ("human", "agent")
        assert doc["workflow_type"] == "build"
        assert doc["tier"] == 1
        # skeleton, not a template stub
        assert "[First criterion]" not in b


def test_cli_main_emits_stdout(capsys):
    """The CLI entrypoint prints skeletons to stdout and returns 0."""
    rc = bpmn_to_tasks.main(["bpmn_to_tasks.py", FIXTURE])
    assert rc == 0
    captured = capsys.readouterr()
    assert "id: u-review-001" in captured.out
    assert "owner: human" in captured.out
