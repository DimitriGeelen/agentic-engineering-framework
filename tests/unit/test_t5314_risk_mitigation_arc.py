"""T-5314 — a risk's mitigation_task must exist and sit in the standing arc 'risk'.

* a task with arc_id `risk` or `arc-028` (slug and arc-NNN forms) → no warning;
* a task in another arc, or in none → warning naming risk id, task id, arc_id;
* a mitigation_task that is not a task → "not found" warning;
* without a project root the check is skipped (validate_risk stays pure);
* the live register still exits 0.
"""

import pathlib
import subprocess
import sys

import pytest
import yaml

ROOT = pathlib.Path(__file__).resolve().parents[2]
if str(ROOT / "lib") not in sys.path:
    sys.path.insert(0, str(ROOT / "lib"))

import risk_register as rr  # noqa: E402


def _project(tmp_path, tasks):
    """tmp project: arc file for 'risk' plus task files {tid: (subdir, arc_line)}."""
    arcs = tmp_path / ".context" / "arcs"
    arcs.mkdir(parents=True)
    (arcs / "risk.yaml").write_text("id: arc-028\nslug: risk\nstanding: true\n")
    for tid, (sub, arc_line) in tasks.items():
        d = tmp_path / ".tasks" / sub
        d.mkdir(parents=True, exist_ok=True)
        fm = f"---\nid: {tid}\nname: mitigate\n{arc_line}status: started-work\n---\n\nbody\n"
        (d / f"{tid}-mitigate.md").write_text(fm)
    return str(tmp_path)


def _risk(tid):
    return {"id": "R-950", "type": "risk", "status": "watching",
            "likelihood": 2, "impact": 4, "score": 8, "ranking": "medium",
            "mitigation_task": tid}


@pytest.mark.parametrize("arc_line", ["arc_id: risk\n", "arc_id: arc-028\n",
                                      "arc_id: \"risk\"  # standing\n"])
def test_task_in_standing_arc_no_warning(tmp_path, arc_line):
    root = _project(tmp_path, {"T-9001": ("active", arc_line)})
    errors, warnings = rr.validate_risk(_risk("T-9001"), root)
    assert errors == [] and warnings == []


def test_completed_task_in_arc_no_warning(tmp_path):
    root = _project(tmp_path, {"T-9002": ("completed", "arc_id: risk\n")})
    assert rr.validate_risk(_risk("T-9002"), root) == ([], [])


def test_task_outside_arc_warns(tmp_path):
    root = _project(tmp_path, {"T-9003": ("active", "arc_id: dispatch-safety\n")})
    _, warnings = rr.validate_risk(_risk("T-9003"), root)
    assert len(warnings) == 1
    w = warnings[0]
    assert "R-950" in w and "T-9003" in w and "not in the standing arc 'risk'" in w
    assert "arc_id: dispatch-safety" in w


def test_task_with_no_arc_warns_none(tmp_path):
    root = _project(tmp_path, {"T-9004": ("active", "")})
    _, warnings = rr.validate_risk(_risk("T-9004"), root)
    assert len(warnings) == 1 and "(arc_id: none)" in warnings[0]


def test_missing_task_warns(tmp_path):
    root = _project(tmp_path, {})
    _, warnings = rr.validate_risk(_risk("T-9999"), root)
    assert len(warnings) == 1
    assert "R-950" in warnings[0] and "T-9999 not found" in warnings[0]


def test_prefix_does_not_match_longer_id(tmp_path):
    # T-900 must not resolve to T-9005-....md
    root = _project(tmp_path, {"T-9005": ("active", "arc_id: risk\n")})
    _, warnings = rr.validate_risk(_risk("T-900"), root)
    assert len(warnings) == 1 and "T-900 not found" in warnings[0]


def test_no_root_skips_check():
    assert rr.validate_risk(_risk("T-9999")) == ([], [])


def test_cli_derives_root_from_register_path(tmp_path):
    root = _project(tmp_path, {"T-9006": ("active", "arc_id: other\n")})
    reg = pathlib.Path(root) / ".context" / "project" / "concerns.yaml"
    reg.parent.mkdir(parents=True)
    reg.write_text(yaml.safe_dump({"concerns": [_risk("T-9006")]}))
    r = subprocess.run([sys.executable, str(ROOT / "lib" / "risk_register.py"),
                        "--path", str(reg)], capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    assert "WARN  R-950: mitigation_task T-9006 is not in the standing arc" in r.stdout


def test_live_register_exits_zero():
    r = subprocess.run([sys.executable, str(ROOT / "lib" / "risk_register.py")],
                       cwd=ROOT, capture_output=True, text=True)
    assert r.returncode == 0, r.stdout + r.stderr
