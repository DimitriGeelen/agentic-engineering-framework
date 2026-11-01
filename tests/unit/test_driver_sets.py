"""Tests for lib/driver_sets.py — driver-set resolver and set-file contract (T-4984).

Every refusal from docs/reports/T-4961-driver-sets.md §Design §1/§4 and the
review fixes (codex C5/C6, opencode 1/4/5/7/8), the valid cases, and the
validate_set contract. Fixtures are a small live file and arcs under tmp_path.
"""

from __future__ import annotations

import copy
import subprocess
import sys
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from lib import driver_sets as ds  # noqa: E402
from lib.driver_sets import DriverSetError  # noqa: E402

LIVE = {
    "version": 3,
    "protected_drivers": [
        {"id": "D1", "name": "Antifragility", "weight": 9, "note": "Gets stronger.\n"},
        {"id": "D2", "name": "Reliability", "weight": 7, "note": "Fewer mistakes.\n"},
        {"id": "D3", "name": "Usability", "weight": 5, "note": "Ergonomics."},
        {"id": "D4", "name": "Portability", "weight": 3, "note": "File-based.\n"},
    ],
    "free_drivers": [
        {"id": "F1", "name": "Focus", "weight": 7},
    ],
    "auto_promote": {"enabled": False},
}


def _product_set():
    s = copy.deepcopy({k: v for k, v in LIVE.items() if k != "auto_promote"})
    s["protected_drivers"][0]["weight"] = 4
    s["protected_drivers"][1]["rubric"] = {"5": "different wording"}
    s["free_drivers"] = [{"id": "F-TRUST", "name": "Trust", "weight": 8}]
    return s


def _write(path: Path, data) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(data, str):
        path.write_text(data)
    else:
        path.write_text(yaml.safe_dump(data, sort_keys=False))
    return path


@pytest.fixture
def proj(tmp_path):
    _write(tmp_path / "policy" / "value-drivers.yaml", LIVE)
    _write(tmp_path / "policy" / "value-drivers-product.yaml", _product_set())
    other = _product_set()
    other["protected_drivers"][2]["weight"] = 1
    _write(tmp_path / "policy" / "value-drivers-ops.yaml", other)
    arcs = tmp_path / ".context" / "arcs"
    _write(arcs / "plain.yaml", {"id": "arc-001", "slug": "plain"})
    _write(arcs / "prod.yaml", {"id": "arc-002", "slug": "prod", "driver_set": "product"})
    _write(arcs / "prod2.yaml", {"id": "arc-003", "slug": "prod2", "driver_set": "product"})
    _write(arcs / "ops.yaml", {"id": "arc-004", "slug": "ops", "driver_set": "ops"})
    _write(arcs / "explicit.yaml", {"id": "arc-005", "slug": "explicit", "driver_set": "default"})
    ds._ARC_CACHE.clear()
    ds._SET_CACHE.clear()
    return tmp_path


def _arc(proj, name, data):
    ds._ARC_CACHE.clear()
    return _write(proj / ".context" / "arcs" / f"{name}.yaml", data)


# --- valid cases ------------------------------------------------------------

def test_no_arc_is_default(proj):
    name, policy = ds.load_for_task({"id": "T-1"}, proj)
    assert name is None
    assert policy["auto_promote"] == {"enabled": False}


def test_arc_without_driver_set_is_default(proj):
    assert ds.resolve_set_name({"arc_id": "plain"}, proj) is None


def test_explicit_default_is_live_file(proj):
    assert ds.resolve_set_name({"arc_id": "explicit"}, proj) is None
    assert ds.set_path("default", proj) == proj / "policy" / "value-drivers.yaml"


def test_named_set_by_slug(proj):
    name, policy = ds.load_for_task({"arc_id": "prod"}, proj)
    assert name == "product"
    assert policy["protected_drivers"][0]["weight"] == 4


def test_named_set_by_arc_nnn_id(proj):
    assert ds.resolve_set_name({"arc_id": "arc-002"}, proj) == "product"


def test_tag_only_member(proj):
    assert ds.resolve_set_name({"tags": ["build", "arc:prod"]}, proj) == "product"


def test_tags_agreeing_on_one_set(proj):
    assert ds.resolve_set_name({"tags": ["arc:prod", "arc:prod2"]}, proj) == "product"


def test_arc_id_and_tag_same_set(proj):
    assert ds.resolve_set_name({"arc_id": "prod", "tags": ["arc:prod2"]}, proj) == "product"


def test_some_tags_missing_is_not_refusal(proj):
    assert ds.resolve_set_name({"tags": ["arc:gone", "arc:prod"]}, proj) == "product"


def test_load_for_arc(proj):
    name, _ = ds.load_for_arc({"slug": "prod", "driver_set": "product"}, proj)
    assert name == "product"
    assert ds.load_for_arc({"slug": "plain"}, proj)[0] is None
    assert ds.load_for_arc(None, proj)[0] is None


# --- refusals ---------------------------------------------------------------

def test_missing_set_file(proj):
    _arc(proj, "ghost", {"slug": "ghost", "driver_set": "nothere"})
    with pytest.raises(DriverSetError) as e:
        ds.load_for_task({"arc_id": "ghost"}, proj)
    msg = str(e.value)
    assert "ghost" in msg and "nothere" in msg and "value-drivers-nothere.yaml" in msg


def test_unreadable_set_file(proj):
    p = proj / "policy" / "value-drivers-product.yaml"
    p.unlink()
    p.mkdir()  # exists, but cannot be read as a file
    with pytest.raises(DriverSetError):
        ds.load_set("product", proj)


def test_invalid_set_file_never_falls_back(proj):
    bad = _product_set()
    del bad["protected_drivers"][1]
    _write(proj / "policy" / "value-drivers-product.yaml", bad)
    with pytest.raises(DriverSetError, match="D2 is missing"):
        ds.load_for_task({"arc_id": "prod"}, proj)


def test_set_file_that_does_not_parse(proj):
    _write(proj / "policy" / "value-drivers-product.yaml", "version: [3\n")
    with pytest.raises(DriverSetError, match="does not parse"):
        ds.load_set("product", proj)


@pytest.mark.parametrize("name", ["Product", "../x", "a.b", "a/b", "1x", "x" * 33, "-x"])
def test_bad_name(proj, name):
    with pytest.raises(DriverSetError, match="invalid"):
        ds.set_path(name, proj)
    _arc(proj, "badname", {"slug": "badname", "driver_set": name})
    with pytest.raises(DriverSetError):
        ds.resolve_set_name({"arc_id": "badname"}, proj)


def test_non_string_driver_set(proj):
    _arc(proj, "num", {"slug": "num", "driver_set": 5})
    with pytest.raises(DriverSetError, match="not a set name"):
        ds.resolve_set_name({"arc_id": "num"}, proj)


@pytest.mark.parametrize("text", ["driver_set:\n", "driver_set: ''\n", "driver_set: '  '\n"])
def test_empty_driver_set(proj, text):
    _arc(proj, "empty", "slug: empty\n" + text)
    with pytest.raises(DriverSetError, match="empty driver_set"):
        ds.resolve_set_name({"arc_id": "empty"}, proj)


def test_arc_id_resolving_to_no_arc(proj):
    with pytest.raises(DriverSetError, match="resolves to no arc"):
        ds.resolve_set_name({"arc_id": "nowhere"}, proj)


def test_every_tag_names_missing_arc(proj):
    with pytest.raises(DriverSetError, match="every arc: tag"):
        ds.resolve_set_name({"tags": ["arc:gone", "arc:also-gone"]}, proj)


def test_arc_id_and_tag_different_sets(proj):
    with pytest.raises(DriverSetError, match="arc_id and arc: tags"):
        ds.resolve_set_name({"arc_id": "prod", "tags": ["arc:ops"]}, proj)


def test_arc_id_default_and_tag_named_set(proj):
    with pytest.raises(DriverSetError, match="arc_id and arc: tags"):
        ds.resolve_set_name({"arc_id": "plain", "tags": ["arc:prod"]}, proj)


def test_two_tags_different_sets(proj):
    with pytest.raises(DriverSetError, match="ambiguous"):
        ds.resolve_set_name({"tags": ["arc:prod", "arc:ops"]}, proj)


def test_duplicate_arc_id(proj):
    _arc(proj, "twin", {"id": "arc-002", "slug": "twin"})
    with pytest.raises(DriverSetError, match="more than one arc file"):
        ds.resolve_set_name({"arc_id": "arc-002"}, proj)


def test_duplicate_arc_slug_vs_filename(proj):
    _arc(proj, "other", {"id": "arc-009", "slug": "prod"})
    with pytest.raises(DriverSetError, match="more than one arc file"):
        ds.resolve_set_name({"arc_id": "prod"}, proj)


def test_duplicate_key_in_arc_file(proj):
    _arc(proj, "dupkey", "slug: dupkey\ndriver_set: product\ndriver_set: ops\n")
    with pytest.raises(DriverSetError, match="duplicate key"):
        ds.resolve_set_name({"arc_id": "dupkey"}, proj)


def test_duplicate_key_in_set_file(proj):
    text = yaml.safe_dump(_product_set(), sort_keys=False) + "version: 3\n"
    _write(proj / "policy" / "value-drivers-product.yaml", text)
    with pytest.raises(DriverSetError, match="duplicate key"):
        ds.load_set("product", proj)


def test_referenced_arc_does_not_parse(proj):
    _arc(proj, "broken", "slug: broken\ndriver_set: [product\n")
    with pytest.raises(DriverSetError, match="does not parse"):
        ds.resolve_set_name({"arc_id": "broken"}, proj)
    with pytest.raises(DriverSetError, match="does not parse"):
        ds.resolve_set_name({"tags": ["arc:broken"]}, proj)


def test_broken_arc_claiming_id_refuses(proj):
    # A file named differently whose raw id line matches: it could be the arc.
    _arc(proj, "zz", "id: arc-002\nslug: [oops\n")
    with pytest.raises(DriverSetError, match="does not parse"):
        ds.resolve_set_name({"arc_id": "arc-002"}, proj)


def test_unrelated_broken_arc_does_not_refuse(proj):
    _arc(proj, "zz", "id: arc-077\nslug: [oops\n")
    assert ds.resolve_set_name({"arc_id": "prod"}, proj) == "product"


def test_set_path_symlink_out_of_policy(proj, tmp_path_factory):
    outside = tmp_path_factory.mktemp("outside") / "value-drivers-evil.yaml"
    _write(outside, _product_set())
    (proj / "policy" / "value-drivers-evil.yaml").symlink_to(outside)
    with pytest.raises(DriverSetError, match="outside"):
        ds.set_path("evil", proj)


# --- validate_set -----------------------------------------------------------

def _v(mutate, path=None):
    s = _product_set()
    mutate(s)
    return ds.validate_set(s, copy.deepcopy(LIVE), path=path)


def test_valid_set_has_no_errors():
    errors, warnings = _v(lambda s: None)
    assert errors == [] and warnings == []


def test_missing_d2():
    errors, _ = _v(lambda s: s["protected_drivers"].pop(1))
    assert any("D2 is missing" in e for e in errors)


def test_renamed_d1():
    errors, _ = _v(lambda s: s["protected_drivers"][0].update(name="Toughness"))
    assert any("D1: 'name' differs" in e for e in errors)


def test_changed_note():
    errors, _ = _v(lambda s: s["protected_drivers"][2].update(note="Other."))
    assert any("D3: 'note' differs" in e for e in errors)


def test_extra_field_on_protected():
    errors, _ = _v(lambda s: s["protected_drivers"][3].update(polarity="x"))
    assert any("D4: 'polarity' differs" in e for e in errors)


def test_weight_and_rubric_may_differ():
    errors, _ = _v(lambda s: s["protected_drivers"][3].update(weight=10, rubric="r"))
    assert errors == []


def test_duplicate_id_in_free():
    errors, _ = _v(lambda s: s["free_drivers"].append({"id": "F-TRUST", "name": "x", "weight": 1}))
    assert any("more than once" in e for e in errors)


def test_free_id_equal_to_protected():
    errors, _ = _v(lambda s: s["free_drivers"].append({"id": "D1", "name": "x", "weight": 1}))
    assert any("both protected_drivers and free_drivers" in e for e in errors)


def test_extra_protected_id():
    errors, _ = _v(lambda s: s["protected_drivers"].append({"id": "D5", "name": "x", "weight": 1}))
    assert any("only D1-D4 are protected" in e for e in errors)


@pytest.mark.parametrize("weight,msg", [
    (True, "not an integer"), (2.5, "not an integer"), ("5", "not an integer"),
    (float("nan"), "not an integer"), (float("inf"), "not an integer"),
    (11, "outside"), (-1, "outside"),
])
def test_bad_weights(weight, msg):
    errors, _ = _v(lambda s: s["free_drivers"][0].update(weight=weight))
    assert any(msg in e for e in errors), errors
    errors, _ = _v(lambda s: s["protected_drivers"][0].update(weight=weight))
    assert any(msg in e for e in errors), errors


@pytest.mark.parametrize("weight", [0, 10])
def test_weight_bounds_inclusive(weight):
    errors, _ = _v(lambda s: s["free_drivers"][0].update(weight=weight))
    assert errors == []


def test_missing_weight():
    errors, _ = _v(lambda s: s["free_drivers"][0].pop("weight"))
    assert any("no weight" in e for e in errors)


def test_missing_section_key():
    errors, _ = _v(lambda s: s.pop("free_drivers"))
    assert any("missing key 'free_drivers'" in e for e in errors)


def test_version_mismatch():
    errors, _ = _v(lambda s: s.update(version=2))
    assert any("version" in e for e in errors)


def test_not_a_mapping():
    errors, _ = ds.validate_set(["x"], LIVE)
    assert errors


@pytest.mark.parametrize("key", ["auto_promote", "inception_scoring_exception"])
def test_project_level_key_warns(key):
    errors, warnings = _v(lambda s: s.update({key: {"enabled": True}}))
    assert errors == []
    assert any(key in w and "project-level" in w for w in warnings)


def test_default_name_warns():
    errors, warnings = _v(lambda s: None, path=Path("policy/value-drivers-default.yaml"))
    assert errors == []
    assert any("reserved" in w for w in warnings)


# --- audit CLI --------------------------------------------------------------

def _audit(proj):
    out = subprocess.run(
        [sys.executable, str(ROOT / "lib" / "driver_sets.py"), "audit", str(proj)],
        capture_output=True, text=True, check=True).stdout
    return [line.split("\t") for line in out.splitlines()]


def test_audit_silent_without_sets(tmp_path):
    _write(tmp_path / "policy" / "value-drivers.yaml", LIVE)
    _write(tmp_path / ".context" / "arcs" / "plain.yaml", {"slug": "plain"})
    assert _audit(tmp_path) == []


def test_audit_ok_and_fail(proj):
    _arc(proj, "ghost", {"slug": "ghost", "driver_set": "nothere"})
    _arc(proj, "broken", "slug: broken\ndriver_set: [x\n")
    rows = _audit(proj)
    levels = {(r[0], r[1]) for r in rows}
    assert ("OK", "prod.yaml") in levels
    assert ("FAIL", "ghost.yaml") in levels
    assert ("FAIL", "broken.yaml") in levels
    ghost = next(r for r in rows if r[1] == "ghost.yaml")
    assert "nothere" in ghost[2] and "ghost" in ghost[2]


def test_audit_warns_on_project_level_key_and_reserved_name(proj):
    s = _product_set()
    s["auto_promote"] = {"enabled": True}
    _write(proj / "policy" / "value-drivers-product.yaml", s)
    _write(proj / "policy" / "value-drivers-default.yaml", _product_set())
    rows = _audit(proj)
    assert any(r[0] == "WARN" and "auto_promote" in r[2] for r in rows)
    assert any(r[0] == "WARN" and r[1] == "value-drivers-default.yaml" for r in rows)


# --- T-4986: a project that names no set has nothing to refuse -----------------

@pytest.fixture
def plain_proj(tmp_path):
    _write(tmp_path / "policy" / "value-drivers.yaml", LIVE)
    arcs = tmp_path / ".context" / "arcs"
    _write(arcs / "plain.yaml", {"id": "arc-001", "slug": "plain"})
    (arcs / "broken.yaml").write_text("id: arc-009\nslug: [unclosed\n")
    ds._ARC_CACHE.clear()
    ds._SET_CACHE.clear()
    return tmp_path


@pytest.mark.parametrize("fm", [
    {"tags": ["arc:bvp"]},                      # stale tag (found on AEF's own /bvp)
    {"arc_id": "no-such-arc"},                  # unresolvable arc_id
    {"arc_id": "broken"},                       # an arc file that does not parse
])
def test_no_set_anywhere_means_live_file_not_refusal(plain_proj, fm):
    assert ds.resolve_set_name(fm, plain_proj) is None


def test_control_same_stale_tag_is_refused_once_any_arc_names_a_set(plain_proj):
    _arc(plain_proj, "prod", {"id": "arc-002", "slug": "prod", "driver_set": "product"})
    _write(plain_proj / "policy" / "value-drivers-product.yaml", _product_set())
    with pytest.raises(ds.DriverSetError):
        ds.resolve_set_name({"tags": ["arc:bvp"]}, plain_proj)
