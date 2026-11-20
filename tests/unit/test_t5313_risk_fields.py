"""T-5313 — risk fields in the concerns register, and the standing arc.

* a risk carrying every new field validates;
* out-of-range values, unknown actors and wrong arithmetic are errors;
* the risks already in the register (filed before T-5313) still validate;
* the mitigation rule warns on an assessed open risk at 6+ with no task;
* a standing arc is refused by `fw arc close` / `fw arc abandon` and skipped by
  the stale-arc audit check.
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


def _risk(**over):
    base = {
        "id": "R-900",
        "type": "risk",
        "title": "prompt injection",
        "status": "watching",
        "likelihood": 3,
        "impact": 4,
        "score": 12,
        "ranking": "medium",
        "actors": [
            {"actor": "own-agent-unintentional", "how": "follows planted text",
             "likelihood": 3, "impact": 4, "mitigated_likelihood": 2, "mitigated_impact": 2},
            {"actor": "intruder", "how": "on the node",
             "likelihood": 2, "impact": 5},
        ],
        "introduced_by": "T-5313",
        "exists_anyway": False,
        "mitigation_task": "T-5314",
    }
    base.update(over)
    return base


def test_valid_risk_with_all_fields():
    errors, warnings = rr.validate_risk(_risk())
    assert errors == []
    assert warnings == []


@pytest.mark.parametrize("over,needle", [
    ({"likelihood": 6, "score": 24}, "likelihood must be an integer 1-5"),
    ({"impact": 0, "score": 0}, "impact must be an integer 1-5"),
    ({"likelihood": True}, "likelihood must be an integer 1-5"),
    ({"score": 11}, "is not likelihood x impact = 12"),
    ({"ranking": "high"}, "does not match score 12"),
    ({"introduced_by": "yesterday"}, "introduced_by must be a task id"),
    ({"mitigation_task": 42}, "mitigation_task must be a task id"),
    ({"exists_anyway": "yes"}, "exists_anyway must be true or false"),
    ({"actors": "intruder"}, "actors must be a list"),
])
def test_bad_values_are_errors(over, needle):
    errors, _ = rr.validate_risk(_risk(**over))
    assert any(needle in e for e in errors), errors


def test_bad_actor_range_and_name():
    r = _risk(actors=[{"actor": "hacker", "likelihood": 9, "impact": 2}])
    errors, _ = rr.validate_risk(r)
    assert any("actor 'hacker' is not one of" in e for e in errors), errors
    assert any("likelihood must be an integer 1-5" in e for e in errors), errors


def test_actor_needs_both_scores_and_mitigated_pair():
    r = _risk(actors=[{"actor": "provider-host", "likelihood": 1,
                       "mitigated_likelihood": 1}])
    errors, _ = rr.validate_risk(r)
    assert any("needs both likelihood and impact" in e for e in errors), errors
    assert any("mitigated_likelihood and mitigated_impact must be given together" in e
               for e in errors), errors


def test_every_actor_name_accepted():
    actors = [{"actor": a, "likelihood": 1, "impact": 1} for a in rr.ACTORS]
    errors, _ = rr.validate_risk(_risk(actors=actors))
    assert errors == []
    assert set(rr.ACTORS) == {
        "own-agent-unintentional", "human-unintentional", "outsider-intentional",
        "provider-host", "intruder"}


def test_mitigation_rule_warns_without_task():
    r = _risk()
    del r["mitigation_task"]
    errors, warnings = rr.validate_risk(r)
    assert errors == []
    assert len(warnings) == 1 and "no mitigation_task" in warnings[0]
    # closed risks and old-shape risks (no new fields) do not warn
    r["status"] = "mitigated"
    assert rr.validate_risk(r)[1] == []
    old = {"id": "R-1", "type": "risk", "likelihood": 4, "impact": 4, "score": 16,
           "status": "watching"}
    assert rr.validate_risk(old) == ([], [])


def test_bands():
    assert rr.band(5) == "low" and rr.band(6) == "medium"
    assert rr.band(12) == "medium" and rr.band(15) == "high" and rr.band(25) == "high"


def test_existing_register_risks_still_validate():
    data = yaml.safe_load((ROOT / ".context/project/concerns.yaml").read_text())
    errors, _, count = rr.validate_register(data)
    assert count >= 1
    assert errors == []


def test_cli_exit_codes(tmp_path):
    good = tmp_path / "good.yaml"
    good.write_text(yaml.safe_dump({"concerns": [_risk()]}))
    bad = tmp_path / "bad.yaml"
    bad.write_text(yaml.safe_dump({"concerns": [_risk(likelihood=7)]}))
    py = str(ROOT / "lib" / "risk_register.py")
    assert subprocess.run([sys.executable, py, "--path", str(good)]).returncode == 0
    assert subprocess.run([sys.executable, py, "--path", str(bad)],
                          capture_output=True).returncode == 1


# ── standing arc ─────────────────────────────────────────────────────────────

def _arc_yaml(standing):
    return (
        "id: arc-999\nslug: probe\nname: \"probe\"\nstatus: in-progress\n"
        + ("standing: true\n" if standing else "")
        + "anchor_task: T-5310\nheadline_mechanic: \"x\"\n"
    )


def _run_arc_fn(tmp_path, standing, fn):
    arcs = tmp_path / "arcs"
    arcs.mkdir(exist_ok=True)
    (arcs / "probe.yaml").write_text(_arc_yaml(standing))
    script = (
        f'source "{ROOT}/lib/arc.sh" >/dev/null 2>&1; ARCS_DIR="{arcs}"; '
        f'_arc_refuse_standing probe {fn}'
    )
    return subprocess.run(["bash", "-c", script], capture_output=True, text=True)


@pytest.mark.parametrize("fn", ["close", "abandon"])
def test_standing_arc_refused_by_close_and_abandon(tmp_path, fn):
    r = _run_arc_fn(tmp_path, True, fn)
    assert r.returncode == 1
    assert "standing arc" in r.stderr
    assert _run_arc_fn(tmp_path, False, fn).returncode == 0


def test_arc_close_and_abandon_call_the_guard():
    src = (ROOT / "lib" / "arc.sh").read_text()
    assert '_arc_refuse_standing "$id" "close" || return 1' in src
    assert '_arc_refuse_standing "$id" "abandon" || return 1' in src


def test_stale_arc_check_skips_standing_arcs():
    src = (ROOT / "agents" / "audit" / "audit.sh").read_text()
    start = src.index("stale_arc_threshold=")
    loop = src[start:src.index("\"$stale_arc_count\" -eq 0", start)]
    i_status = loop.index('[ "$status_val" = "in-progress" ] || continue')
    i_standing = loop.index("^standing:[[:space:]]*true")
    i_warn = loop.index("has no task commits")
    assert i_status < i_standing < i_warn


def test_risk_arc_is_standing():
    data = yaml.safe_load((ROOT / ".context/arcs/risk.yaml").read_text())
    assert data["slug"] == "risk"
    assert data["standing"] is True
    assert data["status"] == "in-progress"
