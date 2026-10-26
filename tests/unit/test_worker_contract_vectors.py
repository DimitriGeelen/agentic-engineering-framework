"""T-4520: schema check and local runner for the shared worker-contract vectors.

The vectors file is shared with TermLink and ring20, so the check must refuse the
mistakes that would silently weaken conformance: a missing case, a fence reason the
spec does not define, n/a on a §3 transition row (N2), or a path into AEF's tree.
The runner must never report `pass` for a vector it did not run.
"""

from __future__ import annotations

import copy
import importlib.util
import sys
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).resolve().parents[2]
DIR = ROOT / "tests" / "conformance" / "worker-contract"
VECTORS = DIR / "vectors.yaml"


def _load(name: str):
    sys.path.insert(0, str(DIR))
    spec = importlib.util.spec_from_file_location(name, DIR / f"{name}.py")
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


check_vectors = _load("check_vectors")
run_local = _load("run_local")


@pytest.fixture()
def doc():
    return yaml.safe_load(VECTORS.read_text())


def _errors(doc) -> list[str]:
    return check_vectors.Checker().check(doc)


def _vec(doc, vid):
    return next(v for v in doc["vectors"] if v["id"] == vid)


# ── schema check ──────────────────────────────────────────────────────────
def test_shipped_file_is_valid(doc):
    assert _errors(doc) == []
    assert [v["id"] for v in doc["vectors"]] == [f"CC-{i:02d}" for i in range(1, 26)]


def test_cli_exit_codes(tmp_path, doc):
    assert check_vectors.main(["x", str(VECTORS)]) == 0
    del doc["vectors"][0]
    bad = tmp_path / "v.yaml"
    bad.write_text(yaml.safe_dump(doc))
    assert check_vectors.main(["x", str(bad)]) == 1
    broken = tmp_path / "b.yaml"
    broken.write_text("vectors: [\n")
    assert check_vectors.main(["x", str(broken)]) == 2


def test_missing_case_is_refused(doc):
    doc["vectors"] = [v for v in doc["vectors"] if v["id"] != "CC-13"]
    assert any("missing cases: CC-13" in e for e in _errors(doc))


def test_duplicate_id_is_refused(doc):
    doc["vectors"].append(copy.deepcopy(doc["vectors"][0]))
    assert any("duplicate id" in e for e in _errors(doc))


def test_unknown_fence_reason_is_refused(doc):
    _vec(doc, "CC-02")["steps"][1]["expect"] = {"fence_reject": "too_late"}
    assert any("not a §3.3 reason" in e for e in _errors(doc))


def test_n2_transition_case_may_not_be_na(doc):
    _vec(doc, "CC-08")["applicability"]["n_a_allowed"] = True
    assert any("N2" in e for e in _errors(doc))


def test_n2_capability_na_needs_named_capability(doc):
    app = _vec(doc, "CC-18")["applicability"]
    app["requires"] = ["supervisor_gen"]
    assert any("N2" in e for e in _errors(doc))


def test_backend_path_is_refused(doc):
    _vec(doc, "CC-01")["title"] = "see .context/dispatch-records/x.json"
    assert any("backend-specific path" in e for e in _errors(doc))


def test_unknown_op_is_refused(doc):
    _vec(doc, "CC-23")["steps"][0]["op"] = "teleport"
    assert any("unknown op 'teleport'" in e for e in _errors(doc))


def test_variant_vector_must_defer_then(doc):
    _vec(doc, "CC-05")["then"] = {}
    assert any("judged_by" in e for e in _errors(doc))


def test_outcome_without_done_breaks_i2(doc):
    _vec(doc, "CC-02")["then"]["final"]["A1"] = {"state": "lost", "outcome": "succeeded"}
    assert any("I2" in e for e in _errors(doc))


# ── runner ────────────────────────────────────────────────────────────────
def test_runner_without_backend_reports_not_implemented(doc):
    assert not run_local.LOCAL_BACKEND.exists(), "local backend now exists: update this test"
    results = [run_local.run_vector(v, None, "no local backend") for v in doc["vectors"]]
    assert len(results) == 25
    assert {r["status"] for r in results} == {"not-implemented"}
    cc17 = next(r for r in results if r["id"] == "CC-17")
    assert "capability:registry_epoch" in cc17["missing"]
    assert "op:sweep" in cc17["missing"]


def test_runner_cli_never_passes_without_backend(capsys):
    assert run_local.main(["--json"]) == 0
    import json
    out = json.loads(capsys.readouterr().out)
    assert out["backend_found"] is False
    assert out["counts"] == {"not-implemented": 25}
    assert run_local.main(["--require-implemented"]) == 3


class ScriptedAdapter:
    """Answers each step with its own expect and reports the vector's `then` as its
    snapshot. Plumbing only: it proves the interpreter wires steps and assertions,
    and the `lie` switch proves a wrong answer is a fail, not a pass."""

    def __init__(self, caps, then_by_given, lie=False, missing_op=None):
        self.capabilities = set(caps)
        self.then_by_given = then_by_given
        self.lie = lie
        self.missing_op = missing_op
        self.steps = 0

    def reset(self, given):
        self.given = given
        self.steps = 0

    def apply(self, step):
        if step["op"] == self.missing_op:
            raise NotImplementedError(f"op:{step['op']}")
        self.steps += 1
        exp = step["expect"]
        if step["op"] == "concurrent":
            n = step["args"]["count"]
            return {"results": [exp["exactly_one"]] + [exp["rest_any_of"][0]] * (n - 1)}
        exp = exp["any_of"][0] if "any_of" in exp else exp
        if self.lie:
            return {"accepted": "T1"} if "accepted" not in exp else {"fence_reject": "bad_nonce"}
        return dict(exp)

    def snapshot(self):
        then = self.then_by_given
        attempts = {}
        for key, final in (then.get("final") or {}).items():
            row = {k: (v["any_of"][0] if isinstance(v, dict) and "any_of" in v
                       else ("x" if isinstance(v, dict) and v.get("present") else v))
                   for k, v in final.items()}
            row["history"] = (then.get("admissible_histories") or {}).get(key, [[None]])[0]
            attempts[key] = row
        extra = {k: v for k, v in then.items() if k not in {"final", "admissible_histories"}}
        return {"attempts": attempts, **extra}


def test_runner_passes_only_after_running_steps(doc):
    vec = _vec(doc, "CC-02")
    adapter = ScriptedAdapter(set(), vec["then"])
    r = run_local.run_vector(vec, adapter, "scripted")
    assert r["status"] == "pass"
    assert adapter.steps == len(vec["steps"])


def test_runner_wrong_answer_is_fail(doc):
    vec = _vec(doc, "CC-02")
    r = run_local.run_vector(vec, ScriptedAdapter(set(), vec["then"], lie=True), "scripted")
    assert r["status"] == "fail"


def test_runner_missing_op_is_not_implemented(doc):
    vec = _vec(doc, "CC-23")
    r = run_local.run_vector(vec, ScriptedAdapter(set(), vec["then"], missing_op="append_question"), "s")
    assert r["status"] == "not-implemented"
    assert "op:append_question" in r["missing"]


def test_runner_capability_case_is_na_without_capability(doc):
    vec = _vec(doc, "CC-17")
    r = run_local.run_vector(vec, ScriptedAdapter(set(), {}), "s")
    assert r["status"] == "n/a"


def test_runner_transition_case_with_no_applicable_variant_fails(doc):
    vec = _vec(doc, "CC-14")  # needs supervisor_gen or lease
    r = run_local.run_vector(vec, ScriptedAdapter(set(), {}), "s")
    assert r["status"] == "fail"
    assert "N2" in r["reason"]


# ── equivalent route on a variant (T-4793) ────────────────────────────────
class EquivalentAdapter(ScriptedAdapter):
    """Declares CC-16/supervisor-refusal as an equivalent route and answers it with
    (or, with silent=True, without) the "equivalent" string."""

    def __init__(self, then, silent=False, route="CC-16/supervisor-refusal"):
        super().__init__(set(), then)
        self.equivalent_routes = {route}
        self.silent = silent

    def apply(self, step):
        result = super().apply(step)
        if not self.silent:
            result["equivalent"] = "derive_outcome(E1) -> refused (rule 2)"
        return result


def _variant(doc, vid, name):
    vec = copy.deepcopy(_vec(doc, vid))
    vec["variants"] = [v for v in vec["variants"] if v["name"] == name]
    return vec


def test_cc16_supervisor_refusal_offers_an_equivalent(doc):
    var = next(v for v in _vec(doc, "CC-16")["variants"] if v["name"] == "supervisor-refusal")
    assert "derivation" in var["equivalent"]
    assert "requires" not in var
    assert _vec(doc, "CC-16")["applicability"]["requires"] == []


def test_variant_unknown_key_and_empty_equivalent_are_refused(doc):
    bad = copy.deepcopy(doc)
    _vec(bad, "CC-16")["variants"][0]["equivalnt"] = "typo"
    assert any("unknown key 'equivalnt'" in e for e in _errors(bad))
    bad = copy.deepcopy(doc)
    _vec(bad, "CC-16")["variants"][2]["equivalent"] = "  "
    assert any("equivalent must be a non-empty string" in e for e in _errors(bad))


def test_reference_backend_passes_all_cc16_variants_by_real_path(doc):
    vec = _vec(doc, "CC-16")
    results = []
    for var in vec["variants"]:
        one = copy.deepcopy(vec)
        one["variants"] = [var]
        r = run_local.run_vector(one, ScriptedAdapter(set(), var["then"]), "reference")
        assert r["status"] == "pass", r
        assert "equivalent" not in r["variants"][0]
        results.append(r)
    assert len(results) == 6


def test_equivalent_route_passes_and_is_named(doc):
    vec = _variant(doc, "CC-16", "supervisor-refusal")
    r = run_local.run_vector(vec, EquivalentAdapter(vec["variants"][0]["then"]), "s")
    assert r["status"] == "pass", r
    assert r["variants"][0]["equivalent"] == "derive_outcome(E1) -> refused (rule 2)"


def test_equivalent_route_taken_silently_fails(doc):
    vec = _variant(doc, "CC-16", "supervisor-refusal")
    r = run_local.run_vector(vec, EquivalentAdapter(vec["variants"][0]["then"], silent=True), "s")
    assert r["status"] == "fail"
    assert "taken silently" in r["variants"][0]["reason"]


def test_equivalent_on_a_variant_without_one_fails(doc):
    vec = _variant(doc, "CC-16", "exit-1")
    adapter = EquivalentAdapter(vec["variants"][0]["then"], route="CC-16/supervisor-refusal")
    r = run_local.run_vector(vec, adapter, "s")
    assert r["status"] == "fail"
    assert "offers no equivalent" in r["variants"][0]["reason"]
    adapter = EquivalentAdapter(vec["variants"][0]["then"], route="CC-16/exit-1")
    r = run_local.run_vector(vec, adapter, "s")
    assert r["status"] == "fail"
    assert "offers no equivalent" in r["variants"][0]["reason"]
