"""T-3427 (OBS-463) — a free driver with no scorer is UNSCORED, and the add
verb says so before the Sovereign spends the slot.

Origin: a consumer added a weight-8 driver; it scored 0 on 46/50 tasks
(score_free_driver grepped for its own id), entered the ranking denominator
and ranked every real task lower. Pinned here: has_scorer() over the hoisted
handler table; the estimator omits unscorable drivers from `scores` (with an
evidence line) instead of writing 0; compute_bvp leaves an omitted driver out
of the weight sum; `fw bvp driver --add` refuses without --allow-unscored.
"""

from __future__ import annotations

import importlib.util
import os
import shutil
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "agents" / "termlink" / "bvp-estimator"))
os.environ.setdefault("PROJECT_ROOT", str(ROOT))
os.environ.setdefault("FRAMEWORK_ROOT", str(ROOT))

import estimator  # noqa: E402


_LOADS = 0


def _load_bvp_module(project_root: Path):
    """lib/bvp.sh is a bash wrapper around a Python heredoc; extract the body
    the way tests/unit/test_bvp_cli_arcs_rollup.py does and import it under a
    sandboxed PROJECT_ROOT (the module reads the env at import time)."""
    global _LOADS
    _LOADS += 1
    os.environ["PROJECT_ROOT"] = str(project_root)
    os.environ["FRAMEWORK_ROOT"] = str(ROOT)
    src = (ROOT / "lib" / "bvp.sh").read_text()
    start = "python3 - \"$@\" <<'PYEOF'"
    i = src.index(start) + len(start)
    j = src.index("PYEOF", i)
    body = src[i:j].replace("sys.exit(main(sys.argv))", "# (stripped for import)")
    tmp = project_root / f"_bvp_cli_t3427_{_LOADS}.py"
    tmp.write_text(body)
    name = f"bvp_cli_t3427_{_LOADS}"
    spec = importlib.util.spec_from_file_location(name, tmp)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


# ── has_scorer over the hoisted table ────────────────────────────────────────

def test_has_scorer_true_for_core_and_aliased_free_drivers():
    for d in ("D1", "D2", "D3", "D4", "F-RECALL", "F-AUTONOMY"):
        assert estimator.has_scorer(d), d
    # policy ids reach handlers through the alias map (F3 -> V_PROMPT_QUALITY etc.)
    aliases = estimator._load_driver_aliases()
    for pid, name in aliases.items():
        if name in estimator._handler_table():
            assert estimator.has_scorer(pid), pid
    # and by name directly
    assert estimator.has_scorer("F9", "V_COMPONENT_FABRIC")


def test_has_scorer_false_for_a_driver_that_is_only_a_name():
    assert not estimator.has_scorer("F4")
    assert not estimator.has_scorer("F4", "Streichliste finding quality")


def test_loop_and_table_dispatch_on_the_same_keys():
    # Every handler name the loop can reach is in the table has_scorer reads.
    table = estimator._handler_table()
    assert "D1" in table and "estimator-fidelity" in table
    assert all(callable(v) for v in table.values())


# ── the estimator omits an unscorable driver instead of writing 0 ─────────────

def _fm(**kw):
    base = {"id": "T-0001", "workflow_type": "build", "tags": []}
    base.update(kw)
    return base


def test_unscorable_driver_is_omitted_from_scores_with_an_evidence_line(tmp_path):
    task = tmp_path / "T-0001-fixture.md"
    task.write_text(
        "---\nid: T-0001\nname: fixture\nstatus: started-work\nworkflow_type: build\n"
        "tags: [F4]\n---\n\n## Context\n\nMentions F4 twice: F4 F4. Adds a structural gate to fw audit.\n",
        encoding="utf-8")
    res = estimator.estimate_task(task, {"D2": 7, "F4": 8})
    assert "D2" in res["scores"]
    assert "F4" not in res["scores"]                    # not 0 — absent, despite four literal 'F4's
    assert any("unscored" in e and "F4" in e for e in res["evidence"]["F4"])


# ── compute_bvp leaves an omitted driver out of the weight sum ────────────────

def test_compute_bvp_excludes_omitted_drivers(tmp_path):
    mod = _load_bvp_module(tmp_path)
    weights = {"D1": 9, "D2": 7, "F4": 8}
    raw, norm, used = mod.compute_bvp({"D1": 5, "D2": 5}, weights)
    assert used == ["D1", "D2"]
    assert raw == 5 * 9 + 5 * 7
    assert norm == 1.0                                   # no dilution by the absent F4
    raw0, norm0, used0 = mod.compute_bvp({"D1": 5, "D2": 5, "F4": 0}, weights)
    assert norm0 < 1.0 and "F4" in used0                # what the old 0 did


# ── fw bvp driver --add refuses an unscorable driver unless told otherwise ────

@pytest.fixture()
def sandbox(tmp_path):
    (tmp_path / "policy").mkdir()
    shutil.copy(ROOT / "policy" / "value-drivers.yaml", tmp_path / "policy" / "value-drivers.yaml")
    (tmp_path / ".context").mkdir()
    return tmp_path


def test_driver_add_refuses_a_driver_with_no_scorer(sandbox, capsys):
    mod = _load_bvp_module(sandbox)
    rc = mod._driver_add(["--add", "Streichliste finding quality", "--weight", "8",
                          "--rationale", "a rationale long enough to satisfy the thirty-char rule",
                          "--drop", "F-AUTONOMY", "--drop-name", "Autonomy / Unattended Operation",
                          "--i-am-human"])
    err = capsys.readouterr().err
    assert rc == 2
    assert "no scorer" in err and "--allow-unscored" in err
    # nothing written
    policy = (sandbox / "policy" / "value-drivers.yaml").read_text()
    assert "Streichliste" not in policy


def test_driver_add_with_allow_unscored_proceeds_and_says_so(sandbox, capsys):
    mod = _load_bvp_module(sandbox)
    rc = mod._driver_add(["--add", "Streichliste finding quality", "--weight", "8",
                          "--rationale", "a rationale long enough to satisfy the thirty-char rule",
                          "--drop", "F-AUTONOMY", "--drop-name", "Autonomy / Unattended Operation",
                          "--allow-unscored", "--i-am-human"])
    out = capsys.readouterr()
    assert rc == 0, out.err
    assert "UNSCORED" in out.out


def test_driver_add_of_a_scorable_name_is_not_refused(sandbox, capsys):
    mod = _load_bvp_module(sandbox)
    # a name that IS a handler key must not trip the guard
    rc = mod._driver_add(["--add", "F-ORCH", "--weight", "3",
                          "--rationale", "a rationale long enough to satisfy the thirty-char rule",
                          "--drop", "F-AUTONOMY", "--drop-name", "Autonomy / Unattended Operation",
                          "--i-am-human"])
    out = capsys.readouterr()
    assert rc == 0, out.err
    assert "UNSCORED" not in out.out
