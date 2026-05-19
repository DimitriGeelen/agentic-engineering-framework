"""T-1937: pin the `fw bvp arcs` CLI rollup contract.

The CLI's cmd_arcs and the web blueprint's _collect_arc_points must
agree on rollup semantics — silent-corpus-migration anti-pattern (T-1850
cluster, L-329). One consumer extending storage shape without sweeping
the other is the failure mode this test guards against.

Sovereignty boundary: estimator-proposed inputs MUST taint the rollup
mode to `derived-proposed`. A single confirmed plus a single proposed
member degrades the whole aggregate.
"""

from __future__ import annotations

import importlib.util
import os
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_ROOT))
os.environ.setdefault("PROJECT_ROOT", str(PROJECT_ROOT))
os.environ.setdefault("FRAMEWORK_ROOT", str(PROJECT_ROOT))


def _load_bvp_module():
    """lib/bvp.sh is a polyglot shell-wraps-python file; load the python body
    by reading from the heredoc-marked region. The script invokes python3 -c
    on its own body in production, so we mirror that here for unit access."""
    bvp_path = PROJECT_ROOT / "lib" / "bvp.sh"
    src = bvp_path.read_text()
    # The python body is everything after the `python3 - <<'PY_BVP_EOF'` line
    # up to `PY_BVP_EOF`. Parse it out.
    start_marker = "python3 - \"$@\" <<'PYEOF'"
    end_marker = "PYEOF"
    i = src.index(start_marker) + len(start_marker)
    j = src.index(end_marker, i)
    body = src[i:j]
    # Strip the trailing `sys.exit(main(sys.argv))` so import doesn't run main.
    body = body.replace("sys.exit(main(sys.argv))", "# (stripped for import)")
    # Write to a tmp .py and import it.
    tmp = PROJECT_ROOT / "tests" / "unit" / "_bvp_cli_imported.py"
    tmp.write_text(body)
    spec = importlib.util.spec_from_file_location("bvp_cli_imported", tmp)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["bvp_cli_imported"] = mod
    spec.loader.exec_module(mod)
    return mod


bvp = _load_bvp_module()


# ----------------------------------------------------------------------------
# _latest_proposed_scores robustness
# ----------------------------------------------------------------------------


def test_latest_proposed_scores_none_when_missing():
    assert bvp._latest_proposed_scores({}) is None


def test_latest_proposed_scores_none_when_malformed():
    assert bvp._latest_proposed_scores({"bvp_scores_proposed": []}) is None
    assert bvp._latest_proposed_scores({"bvp_scores_proposed": [None]}) is None
    assert bvp._latest_proposed_scores({"bvp_scores_proposed": [{}]}) is None
    assert bvp._latest_proposed_scores(
        {"bvp_scores_proposed": [{"scores": "not a dict"}]}) is None


def test_latest_proposed_scores_returns_latest_entry():
    fm = {
        "bvp_scores_proposed": [
            {"scores": {"D1": 1, "D2": 1}},
            {"scores": {"D1": 4, "D2": 3}},  # latest
        ]
    }
    assert bvp._latest_proposed_scores(fm) == {"D1": 4, "D2": 3}


# ----------------------------------------------------------------------------
# _arc_rolled_up_scores aggregation + sovereignty
# ----------------------------------------------------------------------------


def test_rollup_empty_members():
    scores, mode = bvp._arc_rolled_up_scores([])
    assert (scores, mode) == (None, "")


def test_rollup_no_members_with_any_scores():
    members = [{}, {"bvp_scores": {}}]
    scores, mode = bvp._arc_rolled_up_scores(members)
    assert (scores, mode) == (None, "")


def test_rollup_single_confirmed_member():
    members = [{"bvp_scores": {"D1": 4, "D2": 2, "D3": 3, "D4": 1}}]
    scores, mode = bvp._arc_rolled_up_scores(members)
    assert mode == "derived-confirmed"
    assert scores == {"D1": 4, "D2": 2, "D3": 3, "D4": 1}


def test_rollup_mean_aggregates_confirmed():
    members = [
        {"bvp_scores": {"D1": 4, "D2": 0}},
        {"bvp_scores": {"D1": 2, "D2": 2}},
    ]
    scores, mode = bvp._arc_rolled_up_scores(members)
    assert mode == "derived-confirmed"
    assert scores == {"D1": 3, "D2": 1}


def test_rollup_only_proposed():
    members = [
        {"bvp_scores_proposed": [{"scores": {"D1": 4, "D2": 3}}]},
        {"bvp_scores_proposed": [{"scores": {"D1": 2, "D2": 1}}]},
    ]
    scores, mode = bvp._arc_rolled_up_scores(members)
    assert mode == "derived-proposed"
    assert scores == {"D1": 3, "D2": 2}


def test_rollup_mixed_degrades_to_proposed():
    """Sovereignty: a single proposed member taints the whole rollup mode."""
    members = [
        {"bvp_scores": {"D1": 4}},
        {"bvp_scores_proposed": [{"scores": {"D1": 2}}]},
    ]
    scores, mode = bvp._arc_rolled_up_scores(members)
    assert mode == "derived-proposed"
    assert scores == {"D1": 3}


def test_rollup_skips_member_with_no_scores():
    members = [
        {"bvp_scores": {"D1": 5}},
        {},
        {"bvp_scores": {"D1": 1}},
    ]
    scores, mode = bvp._arc_rolled_up_scores(members)
    assert mode == "derived-confirmed"
    assert scores == {"D1": 3}


# ----------------------------------------------------------------------------
# _arc_member_tasks dual-form binding (T-1849)
# ----------------------------------------------------------------------------


def test_member_tasks_matches_both_arc_id_forms(tmp_path, monkeypatch):
    tasks_active = tmp_path / ".tasks" / "active"
    tasks_active.mkdir(parents=True)
    (tmp_path / ".tasks" / "completed").mkdir()
    (tasks_active / "T-99500-slug.md").write_text(
        "---\nid: T-99500\nname: \"slug-form\"\nstatus: started-work\n"
        "workflow_type: build\nowner: agent\nhorizon: now\n"
        "arc_id: value-prioritisation\n---\nbody\n"
    )
    (tasks_active / "T-99501-canon.md").write_text(
        "---\nid: T-99501\nname: \"canon-form\"\nstatus: started-work\n"
        "workflow_type: build\nowner: agent\nhorizon: now\n"
        "arc_id: arc-006\n---\nbody\n"
    )
    (tasks_active / "T-99502-other.md").write_text(
        "---\nid: T-99502\nname: \"other-arc\"\nstatus: started-work\n"
        "workflow_type: build\nowner: agent\nhorizon: now\n"
        "arc_id: other-arc\n---\nbody\n"
    )
    monkeypatch.setattr(bvp, "PROJECT_ROOT", tmp_path)
    members = bvp._arc_member_tasks("value-prioritisation", "arc-006")
    ids = {m["id"] for m in members}
    assert ids == {"T-99500", "T-99501"}


def test_member_tasks_empty_targets():
    """If both targets are empty/None, return empty list (don't match every task)."""
    members = bvp._arc_member_tasks("", "")
    assert members == []
