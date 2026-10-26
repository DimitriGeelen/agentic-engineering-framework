"""T-4752: reader for an external backend's conformance mapping (wc-conformance-mapping/0.1).

The reader must refuse the four faults ring20 injected into its own checker (duplicate
id, PASS without evidence, GAP without a task, N/A on a §3 case), and it must take
"may this case be N/A" from the vectors' applicability table, never from the backend's
own exercises_section3 declaration.
"""

from __future__ import annotations

import copy
import importlib.util
import re
import sys
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).resolve().parents[2]
DIR = ROOT / "tests" / "conformance" / "worker-contract"
FIXTURES = DIR / "fixtures"
VECTORS = DIR / "vectors.yaml"
PROPOSAL = ROOT / "docs" / "reports" / "T-4752" / "spec-proposal.md"


def _load(name: str):
    spec = importlib.util.spec_from_file_location(name, DIR / f"{name}.py")
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


check_mapping = _load("check_mapping")
TABLE = check_mapping.na_table(yaml.safe_load(VECTORS.read_text()))


def _fixture(name: str):
    return yaml.safe_load((FIXTURES / f"mapping-{name}.yaml").read_text())


def _errors(doc) -> list[str]:
    return check_mapping.check(doc, TABLE)


def _case(doc, cid):
    return next(c for c in doc["cases"] if c["id"] == cid)


def test_table_comes_from_vectors():
    assert sorted(TABLE) == check_mapping.REQUIRED_IDS
    assert {cid for cid, ok in TABLE.items() if ok} == {"CC-11", "CC-12", "CC-17", "CC-18"}


def test_valid_fixture_passes():
    assert _errors(_fixture("valid")) == []
    assert check_mapping.main(["x", str(FIXTURES / "mapping-valid.yaml")]) == 0


@pytest.mark.parametrize("name, expected", [
    ("dup-id", "CC-01: duplicate id"),
    ("pass-no-evidence", "CC-13: PASS without evidence"),
    ("gap-no-task", "CC-21: GAP names no task"),
    ("na-on-section3", "CC-08: N/A not allowed"),
])
def test_ring20_faults_are_refused(name, expected):
    errs = _errors(_fixture(name))
    assert any(e.startswith(expected) for e in errs), errs
    assert check_mapping.main(["x", str(FIXTURES / f"mapping-{name}.yaml")]) == 1


def test_declaration_cannot_make_a_section3_case_na():
    doc = _fixture("valid")
    c = _case(doc, "CC-01")
    c.update(verdict="N/A", exercises_section3=False)
    errs = _errors(doc)
    assert any("CC-01: N/A not allowed" in e for e in errs)
    assert any("CC-01: exercises_section3" in e for e in errs)


def test_na_on_capability_case_is_allowed():
    doc = _fixture("valid")
    assert _case(doc, "CC-17")["verdict"] == "N/A"
    assert _errors(doc) == []


def test_received_ring20_mapping_fails_on_cc10_only():
    doc = yaml.safe_load((ROOT / "docs/reports/T-4752/received/conformance-map-v0.3.3.yaml").read_text())
    errs = _errors(doc)
    assert errs and all(e.startswith("CC-10:") for e in errs), errs


@pytest.mark.parametrize("mutate, expected", [
    (lambda d: d["cases"].append("CC-26"), "cases[25]: must be a mapping"),
    (lambda d: d["cases"][0].update(id=None), "cases[0]: not a §9 case id"),
    (lambda d: d["cases"][0].update(evidence="x"), "CC-01: PASS without evidence"),
    (lambda d: d["declarations"].update(backend=""), "declarations: backend missing or empty"),
    (lambda d: d["declarations"].update(backend="hub"), "declarations: backend must be"),
    (lambda d: d["declarations"].update(G="0"), "declarations: G must be a number"),
    (lambda d: d.update(spec_version="wc/0.2.1"), "header: spec_version"),
    (lambda d: d.update(format="wc-conformance-mapping/0.2"), "header: format"),
    (lambda d: _case(d, "CC-07").update(tasks="T-1"), "CC-07: GAP names no task"),
    (lambda d: _case(d, "CC-07").update(verdict="pass"), "CC-07: verdict"),
])
def test_malformed_input_is_invalid_not_a_crash(mutate, expected):
    doc = copy.deepcopy(_fixture("valid"))
    mutate(doc)
    errs = _errors(doc)
    assert any(e.startswith(expected) for e in errs), errs


def test_non_mapping_top_level():
    assert _errors([1, 2]) == ["file: top level must be a mapping"]


def test_cli_exit_codes(tmp_path):
    assert check_mapping.main(["x"]) == 2
    broken = tmp_path / "b.yaml"
    broken.write_text("cases: [\n")
    assert check_mapping.main(["x", str(broken)]) == 2
    assert check_mapping.main(["x", str(tmp_path / "absent.yaml")]) == 2


def test_proposal_table_matches_vectors():
    """The §9 applicability table proposed for the spec must not drift from vectors.yaml."""
    rows = re.findall(r"^\| (CC-\d\d) \|[^|]*\|[^|]*\|[^|]*\| (yes|no)\b", PROPOSAL.read_text(), re.M)
    assert [cid for cid, _ in rows] == check_mapping.REQUIRED_IDS
    assert {cid: ans == "yes" for cid, ans in rows} == TABLE
