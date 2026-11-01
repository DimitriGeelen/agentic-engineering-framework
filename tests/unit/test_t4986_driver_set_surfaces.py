"""T-4986 (driver sets slice 3): every ranking surface values each task under
its own driver set, and shows refused tasks rather than dropping them.

One mixed corpus (tmp_path) is used throughout:
  - policy/value-drivers.yaml       — the live (default) set, D1-D4 = 9/7/5/3
  - policy/value-drivers-product.yaml — D1-D4 re-weighted 1/9/5/0 + F-TRUST 7
                                       (a free driver only the set has)
  - .context/arcs/prod.yaml          — `driver_set: product`
  - .context/arcs/plain.yaml         — no set (default)
  - .context/arcs/broken-set.yaml    — `driver_set: nosuch` (file missing)

Surfaces covered: `fw bvp` rank/detail/arcs/auto-promote/confirm, the resolver
picker (parity with rank), lib/arc_close_readiness.py and the /bvp blueprint.
Design: docs/reports/T-4961-driver-sets.md §Design point 4, §3, review C3/C4/C7.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "lib"))

LIVE_W = {"D1": 9, "D2": 7, "D3": 5, "D4": 3}
PRODUCT_W = {"D1": 1, "D2": 9, "D3": 5, "D4": 0, "F-TRUST": 7}


def _norm(scores, weights):
    raw = sum(scores[d] * w for d, w in weights.items() if d in scores)
    ws = sum(w for d, w in weights.items() if d in scores)
    return raw / (5 * ws) if ws else 0.0


# ---------------------------------------------------------------- corpus
def _policy(auto_promote=None):
    pol = {
        "version": 1,
        "protected_drivers": [
            {"id": "D1", "name": "Antifragility", "weight": 9},
            {"id": "D2", "name": "Reliability", "weight": 7},
            {"id": "D3", "name": "Usability", "weight": 5},
            {"id": "D4", "name": "Portability", "weight": 3},
        ],
        "free_drivers": [],
    }
    if auto_promote:
        pol["auto_promote"] = auto_promote
    return pol


def _task(root, tid, *, status="started-work", scores=None, cost=None, extra="",
          sub="active", owner="agent"):
    lines = ["---", f"id: {tid}", f'name: "fixture {tid}"', "workflow_type: build",
             f"owner: {owner}", "horizon: now", f"status: {status}"]
    if scores:
        lines.append("bvp_scores: {" + ", ".join(f"{k}: {v}" for k, v in scores.items()) + "}")
    if cost:
        lines.append("cost_estimate: {" + ", ".join(f"{k}: {v}" for k, v in cost.items()) + "}")
    if extra:
        lines.append(extra.rstrip("\n"))
    lines += ["---", "", "## Acceptance Criteria", "", "### Agent", "- [ ] do the real thing", ""]
    (root / ".tasks" / sub / f"{tid}-fixture.md").write_text("\n".join(lines))


@pytest.fixture
def corpus(tmp_path):
    root = tmp_path
    for d in (".tasks/active", ".tasks/completed", ".context/arcs", ".context/working",
              ".context/project/workflows", "policy"):
        (root / d).mkdir(parents=True, exist_ok=True)
    (root / ".context/project/workflows/default.yaml").write_text(
        "task_type: default\nworker_kind: TermLink\nmodel: sonnet\n"
        "prompt_template: prompts/default.md\nstrict_mcp_config: true\n")
    (root / ".context/working/focus.yaml").write_text("current_task: T-9000\n")
    live = _policy({"enabled": True, "bvp_norm_min": 0.8, "cost_max": 2, "max_concurrent": 50})
    (root / "policy/value-drivers.yaml").write_text(yaml.safe_dump(live, sort_keys=False))
    product = _policy()
    for d in product["protected_drivers"]:
        d["weight"] = PRODUCT_W[d["id"]]
    product["free_drivers"].append({
        "id": "F-TRUST", "name": "F-TRUST", "weight": 7,
        "scoring": {"kind": "signals", "levels": {3: {"keywords": ["trust"]}}},
    })
    (root / "policy/value-drivers-product.yaml").write_text(yaml.safe_dump(product, sort_keys=False))
    arcs = root / ".context/arcs"
    (arcs / "prod.yaml").write_text(
        "id: arc-950\nslug: prod\nname: product arc\nstatus: in-progress\ndriver_set: product\n")
    (arcs / "plain.yaml").write_text(
        "id: arc-951\nslug: plain\nname: plain arc\nstatus: in-progress\n")

    # T-1: default set. Under live weights norm = 0.6; it would be 0.2 under product.
    _task(root, "T-8001", scores={"D1": 5, "D2": 1, "D3": 1, "D4": 5},
          cost={"blast_radius": 1, "tier": 1, "effort": 1}, extra="arc_id: plain")
    # T-2: product set. D2 + F-TRUST high: product norm 0.78 (live would be ~0.43).
    _task(root, "T-8002", scores={"D1": 1, "D2": 5, "D3": 1, "D4": 1, "F-TRUST": 5},
          cost={"blast_radius": 1, "tier": 1, "effort": 1}, extra="arc_id: prod")
    # T-3: product set via legacy tag only.
    _task(root, "T-8003", scores={"D1": 2, "D2": 2, "D3": 2, "D4": 2, "F-TRUST": 2},
          cost={"blast_radius": 5, "tier": 5, "effort": 5}, extra="tags: [arc:prod]")
    # T-4: no arc at all (default).
    _task(root, "T-8004", scores={"D1": 3, "D2": 3, "D3": 3, "D4": 3},
          cost={"blast_radius": 2, "tier": 2, "effort": 2})
    return root


def _add_refusal(root):
    """An arc naming a set whose file is missing, and a task in it."""
    (root / ".context/arcs/broken-set.yaml").write_text(
        "id: arc-952\nslug: broken-set\nname: broken\nstatus: in-progress\ndriver_set: nosuch\n")
    _task(root, "T-8009", scores={"D1": 5, "D2": 5, "D3": 5, "D4": 5},
          cost={"blast_radius": 1, "tier": 1, "effort": 1}, extra="arc_id: broken-set")


def _env(root):
    env = os.environ.copy()
    env["PROJECT_ROOT"] = str(root)
    env["FRAMEWORK_ROOT"] = str(ROOT)
    env["FW_BVP_TELEMETRY_PATH"] = str(root / "telemetry.ndjson")
    env.pop("FW_REQUIRE_BVP_CONFIRM_APPROVAL", None)
    return env


def _fw_bvp(root, *args):
    r = subprocess.run([str(ROOT / "bin" / "fw"), "bvp", *args], capture_output=True,
                       text=True, env=_env(root), timeout=60, cwd=str(root))
    return r.stdout, r.stderr, r.returncode


def _rank_rows(out):
    """{task id: line} for every table row of `fw bvp` output."""
    return {m.group(1): line for line in out.splitlines()
            if (m := re.match(r"^(T-\d+)\s", line))}


def _rank_norms(out):
    rows = {}
    for tid, line in _rank_rows(out).items():
        parts = line.split()
        if parts[2] != "-":
            rows[tid] = float(parts[2])
    return rows


# ---------------------------------------------------------------- fw bvp rank
def test_rank_values_each_task_under_its_own_set(corpus):
    out, err, rc = _fw_bvp(corpus)
    assert rc == 0, out + err
    norms = _rank_norms(out)
    assert norms["T-8001"] == pytest.approx(round(_norm({"D1": 5, "D2": 1, "D3": 1, "D4": 5}, LIVE_W), 2))
    assert norms["T-8002"] == pytest.approx(
        round(_norm({"D1": 1, "D2": 5, "D3": 1, "D4": 1, "F-TRUST": 5}, PRODUCT_W), 2))
    rows = _rank_rows(out)
    assert "SET" in out
    assert " product " in rows["T-8002"] and " product " in rows["T-8003"]
    assert "product" not in rows["T-8001"] and "product" not in rows["T-8004"]
    # The product task's set-only driver counts: it outranks the default task.
    order = [t for t in _rank_rows(out)]
    assert order.index("T-8002") < order.index("T-8001")


def test_rank_shows_refused_task_as_row_and_exits_3(corpus):
    _add_refusal(corpus)
    out, err, rc = _fw_bvp(corpus)
    assert rc == 3, out + err
    rows = _rank_rows(out)
    assert "T-8009" in rows, out
    assert "refused:" in rows["T-8009"] and "nosuch" in rows["T-8009"]
    assert "REFUSED: 1 task(s)" in out
    # the other tasks are still ranked
    assert {"T-8001", "T-8002", "T-8004"} <= set(_rank_norms(out))


def test_rank_include_proposed_has_set_column(corpus):
    out, err, rc = _fw_bvp(corpus, "--include-proposed")
    assert rc == 0, out + err
    header = next(line for line in out.splitlines() if line.startswith("TASK"))
    assert "SOURCE" in header and "SET" in header
    assert " product " in _rank_rows(out)["T-8002"]


# ---------------------------------------------------------------- detail
def test_detail_prints_the_set_and_its_weights(corpus):
    out, err, rc = _fw_bvp(corpus, "T-8002")
    assert rc == 0, out + err
    assert "Driver set: product (policy/value-drivers-product.yaml)" in out
    assert re.search(r"^F-TRUST\s+F-TRUST\s+7\s+5\s+35", out, re.M), out
    assert re.search(r"^D2\s+Reliability\s+9\s+5\s+45", out, re.M), out
    out, _, rc = _fw_bvp(corpus, "T-8001")
    assert rc == 0 and "Driver set: default (policy/value-drivers.yaml)" in out


def test_detail_refused_set_is_reported(corpus):
    _add_refusal(corpus)
    out, err, rc = _fw_bvp(corpus, "T-8009")
    assert rc == 3
    assert "Driver set: REFUSED" in out and "nosuch" in out


# ---------------------------------------------------------------- arcs
def _arc_rows(out):
    return {line.split()[1]: line for line in out.splitlines()
            if re.match(r"^(arc-\d+|-)\s", line)}


def test_arcs_roll_up_under_the_arcs_own_set(corpus):
    out, err, rc = _fw_bvp(corpus, "arcs")
    assert rc == 0, out + err
    rows = _arc_rows(out)
    # prod rolls up T-8002 and T-8003 (mean, rounded) under PRODUCT weights.
    mean = {k: round((a + b) / 2) for (k, a), b in zip(
        {"D1": 1, "D2": 5, "D3": 1, "D4": 1, "F-TRUST": 5}.items(), [2, 2, 2, 2, 2])}
    expected = _norm(mean, PRODUCT_W)
    parts = rows["prod"].split()
    assert float(parts[4]) == pytest.approx(round(expected, 2)), rows["prod"]
    assert "product" in rows["prod"]
    assert "product" not in rows["plain"]


def test_arcs_mixed_set_member_is_counted_not_reweighted(corpus):
    # T-8005 is in prod by arc_id and in plain by tag: its own set is refused
    # (arcs disagree), so it is counted as mixed set in both and rolled up in neither.
    _task(corpus, "T-8005", scores={"D1": 0, "D2": 0, "D3": 0, "D4": 0, "F-TRUST": 0},
          cost={"blast_radius": 1, "tier": 1, "effort": 1}, extra="arc_id: prod\ntags: [arc:plain]")
    out, err, rc = _fw_bvp(corpus, "arcs")
    assert rc == 0, out + err
    assert "MIXED SET" in out
    assert re.search(r"prod: 1 member\(s\) — T-8005", out), out
    # The prod roll-up is unchanged by the zero-scored mixed member.
    before = _norm({"D1": 2, "D2": 4, "D3": 2, "D4": 2, "F-TRUST": 4}, PRODUCT_W)
    assert float(_arc_rows(out)["prod"].split()[4]) == pytest.approx(round(before, 2))


def test_arcs_yaml_error_is_a_refused_row(corpus):
    (corpus / ".context/arcs/zzz-bad.yaml").write_text("id: [unclosed\n")
    out, err, rc = _fw_bvp(corpus, "arcs")
    assert rc == 0, out + err
    assert "zzz-bad" in out and "refused: arc file zzz-bad.yaml does not parse" in out
    assert "REFUSED: 1 arc(s)" in out


def test_arcs_refused_set_is_a_row(corpus):
    _add_refusal(corpus)
    out, _, _ = _fw_bvp(corpus, "arcs")
    line = _arc_rows(out)["broken-set"]
    assert "refused:" in line and "nosuch" in line


# ---------------------------------------------------------------- resolver parity
_RESOLVER_DUMP = r"""
import json, resolver
metas = [resolver._read_task_meta(p) for p in sorted(resolver.TASKS_ACTIVE.glob("T-*.md"))]
resolver._annotate_bvp_rank(metas)
print(json.dumps({m["id"]: {"norm": m["bvp_norm"], "quad": m["_quadrant"],
                            "set": m["bvp_driver_set"], "refused": m["bvp_refused"]}
                  for m in metas}))
"""


def _resolver_dump(root):
    r = subprocess.run([sys.executable, "-c", _RESOLVER_DUMP], capture_output=True, text=True,
                       env=_env(root), cwd=str(ROOT / "lib"), timeout=60)
    assert r.returncode == 0, r.stderr
    return json.loads(r.stdout)


def _rank_quads(out):
    return {tid: line.split()[4] for tid, line in _rank_rows(out).items()}


def test_resolver_picker_matches_fw_bvp_rank_on_a_mixed_corpus(corpus):
    """Parity (t2497 shape): same norms, same quadrants, same set per task."""
    out, err, rc = _fw_bvp(corpus)
    assert rc == 0, out + err
    cli_norms, cli_quads, cli_rows = _rank_norms(out), _rank_quads(out), _rank_rows(out)
    dump = _resolver_dump(corpus)
    assert set(dump) == set(cli_norms)
    for tid, d in dump.items():
        assert round(d["norm"], 2) == pytest.approx(cli_norms[tid]), tid
        assert d["quad"] == cli_quads[tid], (tid, d, cli_rows[tid])
        assert (d["set"] or "") == ("product" if " product " in cli_rows[tid] else ""), tid
        assert d["refused"] is None


def test_resolver_records_refusals_in_pick_output(corpus):
    _add_refusal(corpus)
    dump = _resolver_dump(corpus)
    assert dump["T-8009"]["quad"] == "refused" and dump["T-8009"]["norm"] is None
    assert "nosuch" in dump["T-8009"]["refused"]
    r = subprocess.run([sys.executable, str(ROOT / "lib/resolver.py"), "pick", "--json"],
                       capture_output=True, text=True, env=_env(corpus), timeout=60)
    assert r.returncode == 0, r.stderr
    d = json.loads(r.stdout)
    assert "T-8009" in d["bvp_refused"] and "nosuch" in d["bvp_refused"]["T-8009"]
    r = subprocess.run([sys.executable, str(ROOT / "lib/resolver.py"), "pick"],
                       capture_output=True, text=True, env=_env(corpus), timeout=60)
    assert "T-8009" in r.stdout and "refused:" in r.stdout


# ---------------------------------------------------------------- auto-promote
def test_auto_promote_uses_each_tasks_set(corpus):
    # Captured tasks: T-8102 (product) clears bvp_norm_min only under product
    # weights (0.964 vs 0.6 live); T-8101 (default) is HV under live weights.
    _task(corpus, "T-8101", status="captured", scores={"D1": 5, "D2": 5, "D3": 3, "D4": 5},
          cost={"blast_radius": 1, "tier": 1, "effort": 1}, extra="arc_id: plain")
    t2 = {"D1": 1, "D2": 5, "D3": 5, "D4": 1, "F-TRUST": 5}
    _task(corpus, "T-8102", status="captured", scores=t2,
          cost={"blast_radius": 1, "tier": 1, "effort": 1}, extra="arc_id: prod")
    _task(corpus, "T-8103", status="captured", scores={"D1": 5, "D2": 5, "D3": 5, "D4": 5},
          cost={"blast_radius": 1, "tier": 1, "effort": 1}, extra="arc_id: broken-set")
    (corpus / ".context/arcs/broken-set.yaml").write_text(
        "id: arc-952\nslug: broken-set\nstatus: in-progress\ndriver_set: nosuch\n")
    assert _norm(t2, LIVE_W) < 0.8 <= _norm(t2, PRODUCT_W)
    out, err, rc = _fw_bvp(corpus, "auto-promote", "--dry-run")
    assert rc == 0, out + err
    assert re.search(rf"T-8102\s+bvp_norm={_norm(t2, PRODUCT_W):.3f}.*set=product", out), out
    assert "T-8101" in out
    assert "REFUSED: T-8103" in out and "nosuch" in out
    assert not re.search(r"^\s+T-8103\s+bvp_norm", out, re.M)


# ---------------------------------------------------------------- confirm
def test_confirm_records_the_driver_set(corpus):
    _task(corpus, "T-8201", status="captured", extra=(
        "arc_id: prod\nbvp_scores_proposed:\n  - ts: '2026-11-01T00:00:00Z'\n"
        "    driver_set: product\n    scores: {D1: 1, D2: 4, D3: 2, D4: 0, F-TRUST: 3}\n"))
    _task(corpus, "T-8202", status="captured", extra=(
        "arc_id: plain\nbvp_scores_proposed:\n  - ts: '2026-11-01T00:00:00Z'\n"
        "    scores: {D1: 1, D2: 4, D3: 2, D4: 0}\n"))
    for tid in ("T-8201", "T-8202"):
        out, err, rc = _fw_bvp(corpus, "confirm", tid, "--i-am-human")
        assert rc == 0, out + err
    fm1 = yaml.safe_load((corpus / ".tasks/active/T-8201-fixture.md").read_text().split("---")[1])
    fm2 = yaml.safe_load((corpus / ".tasks/active/T-8202-fixture.md").read_text().split("---")[1])
    assert fm1["bvp_scores_driver_set"] == "product"
    assert fm1["bvp_scores"]["F-TRUST"] == 3
    assert "bvp_scores_driver_set" not in fm2

    # The estimator's provenance check (T-4985, C1) now counts the confirmed
    # scores under the product set: nothing foreign, no backfill churn.
    import importlib.util
    spec = importlib.util.spec_from_file_location(
        "_est_t4986", ROOT / "agents/termlink/bvp-estimator/estimator.py")
    est = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(est)
    est.PROJECT_ROOT = corpus
    est.POLICY_PATH = corpus / "policy/value-drivers.yaml"
    est.ARCS_DIR = corpus / ".context/arcs"
    conf, _prop, foreign = est._counting_scores(fm1, "product")
    assert conf["F-TRUST"] == 3 and not foreign
    stale = dict(fm1)
    stale.pop("bvp_scores_driver_set")
    _c, _p, foreign = est._counting_scores(stale, "product")
    assert foreign  # without the record the F-TRUST score reads as a live-file score


# ---------------------------------------------------------------- readiness
def test_readiness_values_members_under_their_own_set(corpus, monkeypatch):
    monkeypatch.setenv("PROJECT_ROOT", str(corpus))
    import arc_close_readiness as acr
    _add_refusal(corpus)
    med = acr.corpus_medians(corpus, framework_root=ROOT)
    assert any(r.startswith("T-8009 (driver set refused") for r in med["refused"])
    # median over the four valued tasks, each under its own set
    vals = sorted([
        _norm({"D1": 5, "D2": 1, "D3": 1, "D4": 5}, LIVE_W),
        _norm({"D1": 1, "D2": 5, "D3": 1, "D4": 1, "F-TRUST": 5}, PRODUCT_W),
        _norm({"D1": 2, "D2": 2, "D3": 2, "D4": 2, "F-TRUST": 2}, PRODUCT_W),
        _norm({"D1": 3, "D2": 3, "D3": 3, "D4": 3}, LIVE_W),
    ])
    assert med["value_median"] == pytest.approx((vals[1] + vals[2]) / 2)
    assert med["n_value"] == 4

    def fm(tid):
        text = next((corpus / ".tasks/active").glob(f"{tid}-*.md")).read_text()
        return yaml.safe_load(text.split("---")[1])

    res = acr.evaluate([("T-8002", fm("T-8002")), ("T-8009", fm("T-8009"))], med,
                       {"present": True, "verdict": "GO", "has_rationale": True},
                       framework_root=ROOT)
    assert not res["l1"]["passed"]
    assert any("T-8009" in o and "driver set refused" in o for o in res["l1"]["offenders"])
    # T-8002 is the most valuable open task under product weights, so L2 names it.
    res = acr.evaluate([("T-8002", fm("T-8002"))], med,
                       {"present": True, "verdict": "GO"}, framework_root=ROOT)
    assert any(o.startswith("T-8002 (hv-") for o in res["l2"]["offenders"]), res


# ---------------------------------------------------------------- /bvp blueprint
@pytest.fixture
def blueprint(corpus, monkeypatch):
    import web.blueprints.bvp as bp
    monkeypatch.setattr(bp, "PROJECT_ROOT", corpus)
    monkeypatch.setattr(bp, "POLICY_PATH", corpus / "policy/value-drivers.yaml")
    monkeypatch.setattr(bp, "PROPOSALS_PATH", corpus / ".context/bvp-driver-proposals.jsonl")
    bp._TASK_INDEX_CACHE.clear()
    return bp


def test_blueprint_points_use_each_tasks_set(blueprint, corpus):
    _add_refusal(corpus)
    refused = []
    pts = {p["id"]: p for p in blueprint._collect_task_points(LIVE_W, refused)}
    assert pts["T-8002"]["driver_set"] == "product"
    assert pts["T-8002"]["bvp_norm"] == pytest.approx(
        round(_norm({"D1": 1, "D2": 5, "D3": 1, "D4": 1, "F-TRUST": 5}, PRODUCT_W), 4))
    assert pts["T-8001"]["driver_set"] is None
    assert pts["T-8001"]["bvp_norm"] == pytest.approx(
        round(_norm({"D1": 5, "D2": 1, "D3": 1, "D4": 5}, LIVE_W), 4))
    assert "T-8009" not in pts
    assert [r["id"] for r in refused] == ["T-8009"] and "nosuch" in refused[0]["reason"]
    arcs = {p["slug"]: p for p in blueprint._collect_arc_points(LIVE_W, refused)}
    assert arcs["prod"]["driver_set"] == "product" and arcs["plain"]["driver_set"] is None
    assert any(r["kind"] == "arc" and r["id"] == "arc-952" for r in refused)


def test_blueprint_cli_parity_for_arcs(blueprint, corpus):
    out, _, _ = _fw_bvp(corpus, "arcs")
    cli = {slug: float(line.split()[4]) for slug, line in _arc_rows(out).items()
           if line.split()[4] != "-"}
    web = {p["slug"]: p["bvp_norm"] for p in blueprint._collect_arc_points(LIVE_W)}
    for slug, v in cli.items():
        assert round(web[slug], 2) == pytest.approx(v), slug


def test_bvp_page_renders_badge_and_refused_rows(blueprint, corpus):
    _add_refusal(corpus)
    from web.app import app
    app.config["TESTING"] = True
    resp = app.test_client().get("/bvp")
    assert resp.status_code == 200
    html = resp.get_data(as_text=True)
    assert 'class="bvp-set-badge" data-driver-set="product"' in html
    assert 'id="bvp-refused"' in html
    assert re.search(r'class="bvp-refused-row".*?T-8009.*?refused: .*?nosuch', html, re.S)
    # default-set rows carry no badge
    row = re.search(r"<td><code>T-8001</code>(.*?)</td>", html, re.S)
    assert row and "bvp-set-badge" not in row.group(1)
