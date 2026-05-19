"""T-1938: pin `fw bvp` / `fw bvp T-XXX` proposed-fallback contract.

Sibling parity to T-1937 (arc-level). Drift sites: cmd_rank (no fallback)
and cmd_detail cost section (no fallback). Sovereignty: bare `fw bvp`
remains confirmed-only by default; --include-proposed is explicit opt-in.
"""

from __future__ import annotations

import importlib.util
import os
import subprocess
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_ROOT))
os.environ.setdefault("PROJECT_ROOT", str(PROJECT_ROOT))
os.environ.setdefault("FRAMEWORK_ROOT", str(PROJECT_ROOT))


def _load_bvp_module():
    bvp_path = PROJECT_ROOT / "lib" / "bvp.sh"
    src = bvp_path.read_text()
    start_marker = "python3 - \"$@\" <<'PYEOF'"
    end_marker = "PYEOF"
    i = src.index(start_marker) + len(start_marker)
    j = src.index(end_marker, i)
    body = src[i:j].replace("sys.exit(main(sys.argv))", "# (stripped for import)")
    tmp = PROJECT_ROOT / "tests" / "unit" / "_bvp_cli_imported_1938.py"
    tmp.write_text(body)
    spec = importlib.util.spec_from_file_location("bvp_cli_imported_1938", tmp)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["bvp_cli_imported_1938"] = mod
    spec.loader.exec_module(mod)
    return mod


bvp = _load_bvp_module()


# ----------------------------------------------------------------------------
# _latest_proposed_cost_estimate robustness (CLI-side parity with web blueprint)
# ----------------------------------------------------------------------------


def test_latest_proposed_cost_estimate_none_paths():
    assert bvp._latest_proposed_cost_estimate({}) is None
    assert bvp._latest_proposed_cost_estimate({"cost_estimate_proposed": []}) is None
    assert bvp._latest_proposed_cost_estimate({"cost_estimate_proposed": [None]}) is None
    assert bvp._latest_proposed_cost_estimate({"cost_estimate_proposed": [{}]}) is None
    assert bvp._latest_proposed_cost_estimate(
        {"cost_estimate_proposed": [{"cost_estimate": "not a dict"}]}) is None


def test_latest_proposed_cost_estimate_returns_latest():
    fm = {
        "cost_estimate_proposed": [
            {"cost_estimate": {"blast_radius": 9, "tier": 9, "effort": 9}},
            {"cost_estimate": {"blast_radius": 1, "tier": 2, "effort": 3}},
        ]
    }
    assert bvp._latest_proposed_cost_estimate(fm) == {
        "blast_radius": 1, "tier": 2, "effort": 3,
    }


# ----------------------------------------------------------------------------
# cmd_rank: end-to-end via subprocess (uses tmp PROJECT_ROOT via env)
# ----------------------------------------------------------------------------


def _write_task_with_proposed(tmp_path, task_id, scores=None, proposed=None,
                              cost_proposed=None):
    tasks_active = tmp_path / ".tasks" / "active"
    tasks_active.mkdir(parents=True, exist_ok=True)
    (tmp_path / ".tasks" / "completed").mkdir(exist_ok=True)
    lines = [
        "---",
        f"id: {task_id}",
        f"name: \"{task_id} test\"",
        "status: started-work",
        "workflow_type: build",
        "owner: agent",
        "horizon: now",
    ]
    if scores:
        lines.append("bvp_scores:")
        for k, v in scores.items():
            lines.append(f"  {k}: {v}")
    if proposed:
        lines.append("bvp_scores_proposed:")
        lines.append("  - ts: '2026-05-19T20:00:00Z'")
        lines.append("    scores:")
        for k, v in proposed.items():
            lines.append(f"      {k}: {v}")
    if cost_proposed:
        lines.append("cost_estimate_proposed:")
        lines.append("  - ts: '2026-05-19T20:00:00Z'")
        lines.append("    cost_estimate:")
        for k, v in cost_proposed.items():
            lines.append(f"      {k}: {v}")
    lines.append("---")
    lines.append("body")
    (tasks_active / f"{task_id}-test.md").write_text("\n".join(lines) + "\n")


def _run_fw_bvp(tmp_path, *args):
    """Invoke bin/fw bvp under a tmp PROJECT_ROOT."""
    env = os.environ.copy()
    # The fw shim uses framework's bin/fw — point PROJECT_ROOT at tmp.
    env["PROJECT_ROOT"] = str(tmp_path)
    # policy/value-drivers.yaml must exist; copy minimal one.
    policy_dir = tmp_path / "policy"
    policy_dir.mkdir(exist_ok=True)
    (policy_dir / "value-drivers.yaml").write_text(
        "weights:\n"
        "  D1: 9\n  D2: 7\n  D3: 5\n  D4: 3\n"
        "protected_drivers:\n"
        "  - {id: D1, name: Antifragility, weight: 9}\n"
        "  - {id: D2, name: Reliability, weight: 7}\n"
        "  - {id: D3, name: Usability, weight: 5}\n"
        "  - {id: D4, name: Portability, weight: 3}\n"
        "free_drivers: []\n"
        "auto_promote:\n  enabled: false\n"
    )
    (tmp_path / ".context").mkdir(exist_ok=True)
    (tmp_path / ".context" / "arcs").mkdir(exist_ok=True)
    result = subprocess.run(
        [str(PROJECT_ROOT / "bin" / "fw"), "bvp", *args],
        capture_output=True, text=True, env=env, timeout=20,
    )
    return result.stdout, result.stderr, result.returncode


def test_cmd_rank_default_confirmed_only(tmp_path):
    """Sovereignty default: bare `fw bvp` shows only confirmed-score tasks."""
    _write_task_with_proposed(tmp_path, "T-99001",
                              proposed={"D1": 4, "D2": 3, "D3": 3, "D4": 2})
    out, _err, _rc = _run_fw_bvp(tmp_path)
    # No confirmed scores anywhere → "No tasks have bvp_scores: set yet."
    assert "No tasks have `bvp_scores:` set yet" in out
    assert "T-99001" not in out
    # Help-text nudge to --include-proposed visible.
    assert "--include-proposed" in out


def test_cmd_rank_include_proposed_falls_back(tmp_path):
    _write_task_with_proposed(tmp_path, "T-99002",
                              proposed={"D1": 5, "D2": 2, "D3": 3, "D4": 1})
    out, _err, _rc = _run_fw_bvp(tmp_path, "--include-proposed")
    assert "T-99002" in out
    # SOURCE column distinguishes proposed.
    assert "proposed" in out
    assert "SOURCE" in out


def test_cmd_rank_confirmed_bypasses_proposed(tmp_path):
    """A task with both confirmed and proposed ranks via confirmed (sovereignty)."""
    _write_task_with_proposed(
        tmp_path, "T-99003",
        scores={"D1": 5, "D2": 5, "D3": 5, "D4": 5},  # confirmed
        proposed={"D1": 0, "D2": 0, "D3": 0, "D4": 0},  # ignored
    )
    out, _err, _rc = _run_fw_bvp(tmp_path, "--include-proposed")
    assert "T-99003" in out
    assert "confirmed" in out
    # Confirmed scores (all 5s) yield BVP 24*5 = 120, norm 1.00
    assert "1.00" in out


def test_cmd_rank_cost_falls_back_to_proposed_under_include_proposed(tmp_path):
    _write_task_with_proposed(
        tmp_path, "T-99004",
        proposed={"D1": 4, "D2": 3, "D3": 3, "D4": 2},
        cost_proposed={"blast_radius": 5, "tier": 3, "effort": 2},
    )
    out, _err, _rc = _run_fw_bvp(tmp_path, "--include-proposed")
    assert "T-99004" in out
    # cost = 0.6*5 + 0.3*3 + 0.1*2 = 4.1
    assert "4.1" in out


# ----------------------------------------------------------------------------
# cmd_detail: cost section now reads proposed when confirmed absent
# ----------------------------------------------------------------------------


def test_cmd_detail_shows_proposed_cost_when_confirmed_absent(tmp_path):
    _write_task_with_proposed(
        tmp_path, "T-99005",
        proposed={"D1": 4, "D2": 2, "D3": 3, "D4": 1},
        cost_proposed={"blast_radius": 2, "tier": 1, "effort": 4},
    )
    out, _err, _rc = _run_fw_bvp(tmp_path, "T-99005")
    assert "PROPOSED (estimator)" in out
    # 0.6*2 + 0.3*1 + 0.1*4 = 1.9
    assert "1.90" in out


def test_cmd_detail_confirmed_label_when_confirmed_cost_present(tmp_path):
    """When cost_estimate: is present, label says CONFIRMED."""
    tasks_active = tmp_path / ".tasks" / "active"
    tasks_active.mkdir(parents=True)
    (tmp_path / ".tasks" / "completed").mkdir()
    (tasks_active / "T-99006-test.md").write_text(
        "---\n"
        "id: T-99006\nname: \"T-99006 test\"\nstatus: started-work\n"
        "workflow_type: build\nowner: agent\nhorizon: now\n"
        "bvp_scores:\n  D1: 5\n  D2: 5\n  D3: 5\n  D4: 5\n"
        "cost_estimate:\n  blast_radius: 3\n  tier: 2\n  effort: 1\n"
        "---\nbody\n"
    )
    out, _err, _rc = _run_fw_bvp(tmp_path, "T-99006")
    assert "CONFIRMED" in out
    assert "PROPOSED (estimator)" not in out
