"""T-3428 (OBS-463 leg 2) — a driver scores from a declarative `scoring:` spec,
not only from the hardcoded handler table.

T-3427 stopped an unscorable driver distorting the ranking; it could not make a
project's or an arc's driver actually WORK. Pinned here: each signal kind
matches and is reported in evidence; highest-level-wins; no-signal is a
measured 0 with `L0` evidence (distinct from T-3427's `unscored`); template
stripping means a task whose only "match" is template prose scores 0; invalid
specs are refused with named errors; `has_scorer` is true for a valid spec;
the estimator dispatches specs end-to-end for policy and arc-scoped drivers;
`--add --scoring-file` writes the block and is not refused; and the audit rail
names an unscorable driver while staying silent when every driver is scorable.
"""

from __future__ import annotations

import importlib.util
import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "agents" / "termlink" / "bvp-estimator"))
os.environ.setdefault("PROJECT_ROOT", str(ROOT))
os.environ.setdefault("FRAMEWORK_ROOT", str(ROOT))

import estimator  # noqa: E402


_LOADS = 0


def _load_bvp_module(project_root: Path):
    """lib/bvp.sh is a bash wrapper around a Python heredoc; extract the body
    the way tests/unit/test_t3427_unscored_driver.py does and import it under a
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
    tmp = project_root / f"_bvp_cli_t3428_{_LOADS}.py"
    tmp.write_text(body)
    name = f"bvp_cli_t3428_{_LOADS}"
    spec = importlib.util.spec_from_file_location(name, tmp)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture(autouse=True)
def _restore_root():
    """Several tests re-point PROJECT_ROOT at a sandbox; the estimator module is
    imported once with ROOT and caches the template lines, so put the env back
    or later tests in this file read the sandbox's (absent) template."""
    yield
    os.environ["PROJECT_ROOT"] = str(ROOT)
    os.environ["FRAMEWORK_ROOT"] = str(ROOT)


def _fm(**kw):
    base = {"id": "T-0001", "name": "fixture", "workflow_type": "build", "tags": []}
    base.update(kw)
    return base


def _spec(**levels):
    return {"kind": "signals", "strip_template": True, "levels": dict(levels)}


# ── each signal kind matches, and is named in the evidence ────────────────────

def test_keyword_signal_matches_and_is_reported():
    spec = _spec(**{"2": {"keywords": ["streichliste"]}})
    sc, ev = estimator.score_declarative(spec, _fm(), "a Streichliste finding", [])
    assert sc == 2
    assert "L2:keyword=streichliste" in ev


def test_keyword_signal_matches_name_and_description_not_only_body():
    spec = _spec(**{"1": {"keywords": ["oauth"]}})
    sc, _ = estimator.score_declarative(
        spec, _fm(name="add OAuth flow"), "body says nothing", [])
    assert sc == 1
    sc, _ = estimator.score_declarative(
        spec, _fm(description="wires oauth"), "body says nothing", [])
    assert sc == 1


def test_paths_signal_matches_components_via_fnmatch():
    spec = _spec(**{"3": {"paths": ["tools/*.py"]}})
    sc, ev = estimator.score_declarative(
        spec, _fm(components=["tools/lint.py"]), "no keywords here", [])
    assert sc == 3
    assert any(e.startswith("L3:path=tools/*.py~tools/lint.py") for e in ev), ev


def test_paths_signal_matches_a_path_named_in_the_body():
    """ACs and Verification name files in prose; that is where most tasks
    declare what they touched, since `components:` is only populated at close."""
    spec = _spec(**{"4": {"paths": ["docs/reports/*.md"]}})
    sc, ev = estimator.score_declarative(
        spec, _fm(), "- [ ] writes `docs/reports/T-1-analysis.md`", [])
    assert sc == 4
    assert any("docs/reports/T-1-analysis.md" in e for e in ev), ev


def test_paths_signal_ignores_glob_tokens_in_the_body():
    """A body token with glob metacharacters is a PATTERN, not a path, and would
    only ever self-match. Task bodies quote their own spec."""
    spec = _spec(**{"4": {"paths": ["docs/reports/*.md"]}})
    sc, ev = estimator.score_declarative(
        spec, _fm(), 'the spec says paths: ["docs/reports/*.md"] and nothing else', [])
    assert sc == 0, ev


def test_frontmatter_signal_is_a_case_insensitive_string_compare():
    spec = _spec(**{"5": {"frontmatter": {"workflow_type": "build"}}})
    sc, ev = estimator.score_declarative(spec, _fm(workflow_type="BUILD"), "", [])
    assert sc == 5
    assert "L5:frontmatter=workflow_type=build" in ev
    sc, _ = estimator.score_declarative(spec, _fm(workflow_type="test"), "", [])
    assert sc == 0


def test_frontmatter_signal_on_an_absent_key_does_not_match():
    spec = _spec(**{"3": {"frontmatter": {"voi_score": "0.5"}}})
    sc, _ = estimator.score_declarative(spec, _fm(), "", [])
    assert sc == 0


def test_tags_signal_matches_any_tag():
    spec = _spec(**{"2": {"tags": ["audit"]}})
    sc, ev = estimator.score_declarative(spec, _fm(), "", ["bvp", "Audit"])
    assert sc == 2
    assert "L2:tag=audit" in ev


# ── any-of within a level, highest level wins across levels ───────────────────

def test_a_level_matches_on_any_one_of_its_signals():
    spec = _spec(**{"3": {"keywords": ["absent-word"], "tags": ["present"]}})
    sc, _ = estimator.score_declarative(spec, _fm(), "", ["present"])
    assert sc == 3


def test_highest_matching_level_wins_and_lower_matches_are_still_reported():
    spec = _spec(**{
        "1": {"keywords": ["alpha"]},
        "3": {"keywords": ["beta"]},
        "5": {"keywords": ["gamma"]},
    })
    sc, ev = estimator.score_declarative(spec, _fm(), "alpha beta gamma", [])
    assert sc == 5
    assert "L1:keyword=alpha" in ev and "L3:keyword=beta" in ev
    assert any(e.startswith("→5") for e in ev)


def test_a_middle_level_wins_when_the_top_does_not_match():
    spec = _spec(**{
        "1": {"keywords": ["alpha"]},
        "3": {"keywords": ["beta"]},
        "5": {"keywords": ["gamma"]},
    })
    sc, _ = estimator.score_declarative(spec, _fm(), "alpha beta only", [])
    assert sc == 3


# ── no signal is a MEASURED zero, not T-3427's "unscored" ─────────────────────

def test_no_matching_level_scores_zero_with_L0_evidence():
    spec = _spec(**{"1": {"keywords": ["nowhere-in-this-text"]}})
    sc, ev = estimator.score_declarative(spec, _fm(), "unrelated prose", [])
    assert sc == 0
    assert "L0: no signal" in ev
    # and NOT the T-3427 unscored wording — the driver has a mechanism
    assert not any("unscored" in e for e in ev)


def test_declarative_matches_reports_every_declared_level_even_when_empty():
    spec = _spec(**{"1": {"keywords": ["alpha"]}, "4": {"keywords": ["zzz"]}})
    ladder = estimator.declarative_matches(spec, _fm(), "alpha", [])
    assert sorted(ladder) == [1, 4]
    assert ladder[1] and ladder[4] == []


# ── template stripping: the 1409-sprind trap ─────────────────────────────────

def _template_keyword() -> str:
    """A phrase that exists ONLY in the task template's guidance prose."""
    tpl = (ROOT / ".tasks" / "templates" / "default.md").read_text()
    for cand in ("REHEARSING A LINE BY HAND", "Mutable-corpus anchor",
                 "PRODUCING command's exit code"):
        if cand in tpl:
            return cand
    pytest.skip("task template does not carry a known guidance phrase")


def test_template_prose_is_stripped_so_a_template_only_match_scores_zero():
    phrase = _template_keyword()
    tpl_lines = [ln for ln in (ROOT / ".tasks" / "templates" / "default.md")
                 .read_text().splitlines() if phrase in ln]
    assert tpl_lines, phrase
    body = "## Context\n\nA task about nothing in particular.\n\n" + "\n".join(tpl_lines)
    spec = _spec(**{"5": {"keywords": [phrase]}})
    sc, ev = estimator.score_declarative(spec, _fm(), body, [])
    assert sc == 0, ev
    assert "L0: no signal" in ev


def test_strip_template_false_lets_the_same_template_prose_match():
    """The control leg: the zero above is stripping working, not the keyword
    simply being absent."""
    phrase = _template_keyword()
    tpl_lines = [ln for ln in (ROOT / ".tasks" / "templates" / "default.md")
                 .read_text().splitlines() if phrase in ln]
    body = "\n".join(tpl_lines)
    spec = _spec(**{"5": {"keywords": [phrase]}})
    spec["strip_template"] = False
    sc, _ = estimator.score_declarative(spec, _fm(), body, [])
    assert sc == 5


def test_an_author_written_line_survives_stripping_even_quoting_a_template_word():
    """Stripping is line-exact, not fuzzy — otherwise a task legitimately about
    the template could never score."""
    phrase = _template_keyword()
    body = f"## Context\n\nThis task changes how {phrase} reads for authors.\n"
    spec = _spec(**{"5": {"keywords": [phrase]}})
    sc, _ = estimator.score_declarative(spec, _fm(), body, [])
    assert sc == 5


# ── validation ───────────────────────────────────────────────────────────────

def test_valid_spec_has_no_errors():
    assert estimator.validate_scoring_spec(
        _spec(**{"1": {"keywords": ["x"]}, "5": {"tags": ["y"]}})) == []


@pytest.mark.parametrize("spec,needle", [
    ({"kind": "signals", "levels": {7: {"keywords": ["x"]}}}, "levels[7]"),
    ({"kind": "signals", "levels": {0: {"keywords": ["x"]}}}, "levels[0]"),
    ({"kind": "signals", "levels": {1: {"keywords": []}}}, "non-empty list"),
    ({"kind": "signals", "levels": {1: {"keywords": ["", "  "]}}}, "not a non-empty string"),
    ({"kind": "signals", "levels": {1: {"bogus": ["x"]}}}, "unknown signal kind"),
    ({"kind": "signals", "levels": {1: {}}}, "at least one signal"),
    ({"kind": "signals", "levels": {}}, "non-empty mapping"),
    ({"kind": "signals"}, "non-empty mapping"),
    ({"levels": {1: {"tags": ["x"]}}}, "kind: missing"),
    ({"kind": "regex", "levels": {1: {"tags": ["x"]}}}, "unknown kind"),
    ({"kind": "signals", "strip_template": "yes",
      "levels": {1: {"tags": ["x"]}}}, "strip_template"),
    ({"kind": "signals", "levels": {1: {"frontmatter": {"k": ["a"]}}}}, "must be a scalar"),
    ({"kind": "signals", "levels": {1: {"frontmatter": {}}}}, "flat mapping"),
    ({"kind": "signals", "wat": 1, "levels": {1: {"tags": ["x"]}}}, "unknown key"),
    ("not-a-mapping", "must be a mapping"),
])
def test_invalid_specs_are_refused_with_a_named_error(spec, needle):
    errors = estimator.validate_scoring_spec(spec)
    assert errors, spec
    assert any(needle in e for e in errors), (needle, errors)


def test_load_scoring_spec_returns_none_when_absent_and_the_block_when_present():
    assert estimator.load_scoring_spec({"id": "F9"}) is None
    assert estimator.load_scoring_spec({"id": "F9", "scoring": {}}) is None
    assert estimator.load_scoring_spec("not-a-dict") is None
    block = {"kind": "signals", "levels": {1: {"tags": ["x"]}}}
    assert estimator.load_scoring_spec({"id": "F9", "scoring": block}) == block


def test_load_scoring_spec_returns_a_malformed_block_so_it_can_be_reported():
    """A present-but-broken spec must not vanish into 'this driver has no
    spec' — that is the silent-failure shape the whole task is about."""
    bad = {"kind": "nope"}
    got = estimator.load_scoring_spec({"id": "F9", "scoring": bad})
    assert got == bad
    assert estimator.validate_scoring_spec(got)


# ── has_scorer ───────────────────────────────────────────────────────────────

def test_has_scorer_true_for_a_candidate_entry_carrying_a_valid_spec():
    entry = {"scoring": _spec(**{"1": {"tags": ["x"]}})}
    assert not estimator.has_scorer("F4", "Streichliste finding quality")
    assert estimator.has_scorer("F4", "Streichliste finding quality", entry)


def test_has_scorer_false_for_a_candidate_entry_whose_spec_is_invalid():
    entry = {"scoring": {"kind": "signals", "levels": {9: {"tags": ["x"]}}}}
    assert not estimator.has_scorer("F4", "Streichliste finding quality", entry)


def test_has_scorer_still_true_for_handler_backed_drivers():
    for d in ("D1", "D2", "D3", "D4", "F-RECALL", "F-AUTONOMY"):
        assert estimator.has_scorer(d), d


# ── estimator end-to-end, policy and arc legs ────────────────────────────────

def _sandbox_policy(tmp_path: Path, free_entry: dict) -> Path:
    (tmp_path / "policy").mkdir(parents=True, exist_ok=True)
    (tmp_path / "policy" / "value-drivers.yaml").write_text(yaml.safe_dump({
        "version": 3,
        "protected_drivers": [{"id": "D2", "name": "Reliability", "weight": 7}],
        "free_drivers": [free_entry],
    }))
    shutil.copytree(ROOT / ".tasks" / "templates", tmp_path / ".tasks" / "templates")
    return tmp_path


def _reload_estimator(project_root: Path):
    """Re-import the estimator against a sandbox root (POLICY_PATH, ARCS_DIR and
    the template-line cache are all resolved at import time)."""
    os.environ["PROJECT_ROOT"] = str(project_root)
    spec = importlib.util.spec_from_file_location(
        f"estimator_t3428_{project_root.name}",
        ROOT / "agents" / "termlink" / "bvp-estimator" / "estimator.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _write_task(tmp_path: Path, task_id: str, fm_extra: str, body: str) -> Path:
    d = tmp_path / ".tasks" / "active"
    d.mkdir(parents=True, exist_ok=True)
    tp = d / f"{task_id}-fixture.md"
    tp.write_text(f"---\nid: {task_id}\nname: fixture\nstatus: started-work\n"
                  f"workflow_type: build\n{fm_extra}---\n\n{body}\n")
    return tp


def test_estimate_task_scores_a_policy_driver_from_its_spec(tmp_path):
    root = _sandbox_policy(tmp_path, {
        "id": "F4", "name": "Streichliste finding quality", "weight": 8,
        "scoring": _spec(**{"1": {"keywords": ["finding"]},
                            "4": {"keywords": ["streichliste"], "tags": ["audit"]}}),
    })
    est = _reload_estimator(root)
    task = _write_task(root, "T-0001", "tags: [audit]\n",
                       "## Context\n\nA finding about the Streichliste.")
    res = est.estimate_task(task, {"D2": 7, "F4": 8})
    assert res["scores"]["F4"] == 4, res["evidence"]
    assert any("L4:keyword=streichliste" in e for e in res["evidence"]["F4"])
    # not the T-3427 unscored path any more
    assert not any("unscored" in e for e in res["evidence"]["F4"])


def test_estimate_task_scores_a_spec_driver_zero_when_nothing_matches(tmp_path):
    """And the key is PRESENT at 0 — a measured zero stays in the denominator,
    unlike T-3427's omitted unscored driver."""
    root = _sandbox_policy(tmp_path, {
        "id": "F4", "name": "Streichliste finding quality", "weight": 8,
        "scoring": _spec(**{"3": {"keywords": ["nowhere-in-this-task"]}}),
    })
    est = _reload_estimator(root)
    task = _write_task(root, "T-0002", "", "## Context\n\nUnrelated prose.")
    res = est.estimate_task(task, {"D2": 7, "F4": 8})
    assert res["scores"]["F4"] == 0
    assert "L0: no signal" in res["evidence"]["F4"]


def test_estimate_task_leaves_a_driver_with_an_invalid_spec_unscored(tmp_path):
    root = _sandbox_policy(tmp_path, {
        "id": "F4", "name": "Streichliste finding quality", "weight": 8,
        "scoring": {"kind": "signals", "levels": {9: {"keywords": ["finding"]}}},
    })
    est = _reload_estimator(root)
    task = _write_task(root, "T-0003", "", "## Context\n\nA finding.")
    res = est.estimate_task(task, {"D2": 7, "F4": 8})
    assert "F4" not in res["scores"]
    assert any("unscored" in e for e in res["evidence"]["F4"])


def test_a_handler_outranks_a_spec_on_the_same_driver(tmp_path):
    """Dispatch is handler → alias → spec. A policy edit must not silently
    displace the richer mechanism."""
    root = _sandbox_policy(tmp_path, {
        "id": "F-RECALL", "name": "Recall Leverage", "weight": 6,
        "scoring": _spec(**{"5": {"keywords": ["unrelated-token"]}}),
    })
    est = _reload_estimator(root)
    task = _write_task(root, "T-0004", "", "## Context\n\nunrelated-token only.")
    res = est.estimate_task(task, {"F-RECALL": 6})
    # the spec would have said 5; the handler's own evidence shape is present
    assert not any(e.startswith("L5:") for e in res["evidence"]["F-RECALL"])


def test_estimate_task_scores_an_arc_scoped_driver_from_its_spec(tmp_path):
    root = _sandbox_policy(tmp_path, {"id": "D2x", "name": "unused", "weight": 1})
    arcs = root / ".context" / "arcs"
    arcs.mkdir(parents=True)
    (arcs / "my-arc.yaml").write_text(yaml.safe_dump({
        "id": "arc-099", "slug": "my-arc", "status": "in-progress",
        "scoped_drivers": [{
            "name": "unknown-input-safety", "weight": 4,
            "scoring": _spec(**{"2": {"keywords": ["unrecognised"]},
                                "5": {"paths": ["lib/*.sh"]}}),
        }],
    }))
    est = _reload_estimator(root)
    task = _write_task(root, "T-0005", "arc_id: my-arc\n",
                       "## Context\n\nHandles unrecognised input in `lib/onboard.sh`.")
    res = est.estimate_task(task, {"D2": 7})
    assert res["scores"]["unknown-input-safety"] == 5, res["evidence"]
    assert any("lib/onboard.sh" in e for e in res["evidence"]["unknown-input-safety"])


def test_arc_scoped_specs_resolve_through_the_arc_NNN_dual_form(tmp_path):
    """T-1849 dual form: arc_id may be `arc-099` while the file is slug-named."""
    root = _sandbox_policy(tmp_path, {"id": "D2x", "name": "unused", "weight": 1})
    arcs = root / ".context" / "arcs"
    arcs.mkdir(parents=True)
    (arcs / "my-arc.yaml").write_text(yaml.safe_dump({
        "id": "arc-099", "slug": "my-arc", "status": "in-progress",
        "scoped_drivers": [{"name": "dual-form", "weight": 3,
                            "scoring": _spec(**{"3": {"tags": ["x"]}})}],
    }))
    est = _reload_estimator(root)
    task = _write_task(root, "T-0006", "arc_id: arc-099\ntags: [x]\n", "## Context\n\n.")
    res = est.estimate_task(task, {})
    assert res["scores"]["dual-form"] == 3


def test_inception_voi_still_preempts_declarative_specs(tmp_path):
    root = _sandbox_policy(tmp_path, {
        "id": "F4", "name": "spec driver", "weight": 8,
        "scoring": _spec(**{"5": {"keywords": ["finding"]}}),
    })
    est = _reload_estimator(root)
    task = _write_task(root, "T-0007",
                       "voi_score: 0.2\n", "## Context\n\nA finding.")
    task.write_text(task.read_text().replace("workflow_type: build",
                                             "workflow_type: inception"))
    res = est.estimate_task(task, {"F4": 8})
    assert res["scores"]["F4"] == 1          # round(0.2 × 5)
    assert any("voi" in e for e in res["evidence"]["F4"])


# ── fw bvp driver --add --scoring-file ───────────────────────────────────────

@pytest.fixture()
def sandbox(tmp_path):
    (tmp_path / "policy").mkdir()
    shutil.copy(ROOT / "policy" / "value-drivers.yaml",
                tmp_path / "policy" / "value-drivers.yaml")
    (tmp_path / ".context").mkdir()
    return tmp_path


_ADD_ARGS = ["--weight", "8",
             "--rationale", "a rationale long enough to satisfy the thirty-char rule",
             "--drop", "F-AUTONOMY", "--drop-name", "Autonomy / Unattended Operation",
             "--i-am-human"]


def test_driver_add_with_a_valid_scoring_file_writes_the_block_and_is_not_refused(
        sandbox, capsys):
    spec_file = sandbox / "spec.yaml"
    spec_file.write_text(yaml.safe_dump(
        _spec(**{"1": {"keywords": ["finding"]}, "4": {"tags": ["audit"]}})))
    mod = _load_bvp_module(sandbox)
    rc = mod._driver_add(["--add", "Streichliste finding quality",
                          "--scoring-file", str(spec_file)] + _ADD_ARGS)
    out = capsys.readouterr()
    assert rc == 0, out.err
    assert "UNSCORED" not in out.out
    assert "+scoring-spec" in out.out
    policy = yaml.safe_load((sandbox / "policy" / "value-drivers.yaml").read_text())
    entry = next(d for d in policy["free_drivers"]
                 if d["name"] == "Streichliste finding quality")
    assert entry["scoring"]["kind"] == "signals"
    assert sorted(int(k) for k in entry["scoring"]["levels"]) == [1, 4]


def test_the_written_block_is_what_the_estimator_then_dispatches_on(sandbox, capsys):
    """The join: --add writes it, the estimator reads it. Neither side alone
    proves the feature (L-399 producer/consumer parity)."""
    spec_file = sandbox / "spec.yaml"
    spec_file.write_text(yaml.safe_dump(_spec(**{"4": {"keywords": ["streichliste"]}})))
    mod = _load_bvp_module(sandbox)
    assert mod._driver_add(["--add", "Streichliste finding quality",
                            "--scoring-file", str(spec_file)] + _ADD_ARGS) == 0
    capsys.readouterr()
    shutil.copytree(ROOT / ".tasks" / "templates", sandbox / ".tasks" / "templates")
    est = _reload_estimator(sandbox)
    policy = yaml.safe_load((sandbox / "policy" / "value-drivers.yaml").read_text())
    new_id = next(d["id"] for d in policy["free_drivers"]
                  if d["name"] == "Streichliste finding quality")
    task = _write_task(sandbox, "T-0008", "", "## Context\n\nAbout the Streichliste.")
    res = est.estimate_task(task, {new_id: 8})
    assert res["scores"][new_id] == 4, res["evidence"]


def test_driver_add_refuses_an_invalid_scoring_file_and_writes_nothing(sandbox, capsys):
    spec_file = sandbox / "bad.yaml"
    spec_file.write_text("kind: nope\nlevels:\n  7: {keywords: []}\n")
    mod = _load_bvp_module(sandbox)
    rc = mod._driver_add(["--add", "Streichliste finding quality",
                          "--scoring-file", str(spec_file)] + _ADD_ARGS)
    err = capsys.readouterr().err
    assert rc == 2
    assert "not a valid scoring spec" in err
    assert "unknown kind" in err and "levels[7]" in err
    assert "--validate-scoring" in err
    assert "Streichliste" not in (sandbox / "policy" / "value-drivers.yaml").read_text()


def test_driver_add_refuses_a_missing_scoring_file(sandbox, capsys):
    mod = _load_bvp_module(sandbox)
    rc = mod._driver_add(["--add", "x name", "--scoring-file",
                          str(sandbox / "nope.yaml")] + _ADD_ARGS)
    assert rc == 2
    assert "no such file" in capsys.readouterr().err


def test_the_t3427_refusal_still_fires_without_a_scoring_file(sandbox, capsys):
    mod = _load_bvp_module(sandbox)
    rc = mod._driver_add(["--add", "Streichliste finding quality"] + _ADD_ARGS)
    err = capsys.readouterr().err
    assert rc == 2
    assert "no scorer" in err
    # and now points at the real fix, not only the bypass
    assert "--scoring-file" in err and "--allow-unscored" in err


def test_validate_scoring_accepts_the_shipped_example_and_rejects_a_broken_one(
        sandbox, capsys):
    mod = _load_bvp_module(sandbox)
    assert mod._driver_validate_scoring(
        ["--validate-scoring", str(ROOT / "policy" / "driver-scoring-example.yaml")]) == 0
    assert "valid scoring spec" in capsys.readouterr().out
    bad = sandbox / "bad.yaml"
    bad.write_text("kind: signals\nlevels: {}\n")
    assert mod._driver_validate_scoring(["--validate-scoring", str(bad)]) == 2
    assert "INVALID" in capsys.readouterr().err


def test_read_scoring_file_accepts_both_the_bare_and_the_wrapped_shape(sandbox):
    mod = _load_bvp_module(sandbox)
    bare = sandbox / "bare.yaml"
    bare.write_text(yaml.safe_dump(_spec(**{"2": {"tags": ["x"]}})))
    wrapped = sandbox / "wrapped.yaml"
    wrapped.write_text(yaml.safe_dump({"scoring": _spec(**{"2": {"tags": ["x"]}})}))
    for f in (bare, wrapped):
        spec, errors = mod._read_scoring_file(str(f))
        assert errors == [], (f, errors)
        assert spec["kind"] == "signals"


# ── the audit / doctor rail ──────────────────────────────────────────────────

def _run_rail(project_root: Path):
    script = (f'source "{ROOT}/lib/bvp-scorability.sh"; '
              f'fw_bvp_unscorable_drivers "{project_root}"; echo "rc=$?"')
    env = dict(os.environ, FRAMEWORK_ROOT=str(ROOT), PROJECT_ROOT=str(project_root))
    p = subprocess.run(["bash", "-c", script], capture_output=True, text=True, env=env)
    return p.stdout


def test_rail_names_an_unscorable_driver(tmp_path):
    root = _sandbox_policy(tmp_path, {"id": "F4", "name": "no mechanism here",
                                      "weight": 8})
    out = _run_rail(root)
    assert "rc=0" in out
    assert "F4" in out and "no-mechanism" in out


def test_rail_is_silent_when_every_active_driver_is_scorable(tmp_path):
    root = _sandbox_policy(tmp_path, {
        "id": "F4", "name": "has a spec", "weight": 8,
        "scoring": _spec(**{"1": {"tags": ["x"]}}),
    })
    out = _run_rail(root)
    assert out.strip() == "rc=0", out


def test_rail_reports_an_invalid_spec_as_its_own_class(tmp_path):
    root = _sandbox_policy(tmp_path, {
        "id": "F4", "name": "has a broken spec", "weight": 8,
        "scoring": {"kind": "signals", "levels": {9: {"tags": ["x"]}}},
    })
    out = _run_rail(root)
    assert "invalid-spec" in out and "F4" in out
    assert "no-mechanism" not in out


def test_rail_flags_an_arc_scoped_driver_without_a_mechanism(tmp_path):
    root = _sandbox_policy(tmp_path, {"id": "F4", "name": "has a spec", "weight": 8,
                                      "scoring": _spec(**{"1": {"tags": ["x"]}})})
    arcs = root / ".context" / "arcs"
    arcs.mkdir(parents=True)
    (arcs / "live.yaml").write_text(yaml.safe_dump({
        "id": "arc-099", "slug": "live", "status": "in-progress",
        "scoped_drivers": [{"name": "nameless-axis", "weight": 4}]}))
    out = _run_rail(root)
    assert "nameless-axis" in out and "no-mechanism" in out
    assert "arcs/live.yaml" in out


def test_rail_ignores_scoped_drivers_on_closed_and_abandoned_arcs(tmp_path):
    root = _sandbox_policy(tmp_path, {"id": "F4", "name": "has a spec", "weight": 8,
                                      "scoring": _spec(**{"1": {"tags": ["x"]}})})
    arcs = root / ".context" / "arcs"
    arcs.mkdir(parents=True)
    for status in ("closed", "abandoned"):
        (arcs / f"{status}.yaml").write_text(yaml.safe_dump({
            "id": f"arc-{status}", "slug": status, "status": status,
            "scoped_drivers": [{"name": f"{status}-axis", "weight": 4}]}))
    out = _run_rail(root)
    assert out.strip() == "rc=0", out


def test_rail_returns_rc1_and_says_nothing_without_a_policy_file(tmp_path):
    out = _run_rail(tmp_path)
    assert out.strip() == "rc=1", out


def test_rail_does_not_flag_handler_backed_drivers(tmp_path):
    """Control leg: the real policy file's five free drivers are all
    handler-backed, so the rail must be silent about all of them. Pins the
    INVARIANT (no free driver flagged), not a live count — the arc corpus moves."""
    root = tmp_path / "real"
    (root / "policy").mkdir(parents=True)
    shutil.copy(ROOT / "policy" / "value-drivers.yaml",
                root / "policy" / "value-drivers.yaml")
    out = _run_rail(root)
    assert "rc=0" in out
    for line in out.splitlines():
        assert "policy/value-drivers.yaml" not in line, line
