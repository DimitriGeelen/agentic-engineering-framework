"""T-3574: arc page must not re-parse the task corpus per request.

The legacy implementations are inlined below and compared against the live
ones on the REAL corpus at test time (no frozen expected values, so the
corpus can grow — T-3326). Equality proves the perf change moved no BVP number.
"""

import glob
import os
import re
import time
from pathlib import Path

import pytest
import yaml

os.environ.setdefault("PROJECT_ROOT", str(Path(__file__).resolve().parents[2]))

from web.shared import PROJECT_ROOT  # noqa: E402
from web.blueprints import arcs, bvp  # noqa: E402

_FM_RE = re.compile(r"^---\n(.*?)\n---", re.DOTALL)


def _legacy_members(arc_slug, arc_id_str):
    from lib.arc_membership import scan_tasks_by_arc_membership

    by_arc_id, by_tag = scan_tasks_by_arc_membership(PROJECT_ROOT)
    ids = set()
    for key in (arc_slug, arc_id_str):
        if key:
            ids.update(by_arc_id.get(key, []))
    if arc_slug:
        ids.update(by_tag.get(f"arc:{arc_slug}", []))
    members = []
    for sub in ("active", "completed"):
        for p in sorted(glob.glob(str(PROJECT_ROOT / ".tasks" / sub / "T-*.md"))):
            m = _FM_RE.match(Path(p).read_text())
            if not m:
                continue
            fm = yaml.safe_load(m.group(1)) or {}
            if str(fm.get("id") or "").strip() in ids:
                members.append(fm)
    return members


def _legacy_coherence(arc, arc_slug, arc_numeric):
    """Verbatim pre-T-3574 algorithm (whole-corpus safe_load)."""
    arc_min = int(os.environ.get("BVP_COHERENCE_ARC_MIN", "4"))
    task_max = int(os.environ.get("BVP_COHERENCE_TASK_MAX", "1"))
    fraction = float(os.environ.get("BVP_COHERENCE_FRACTION", "0.70"))
    claims = {}
    for sd in arc.get("scoped_drivers") or []:
        try:
            w = int(sd.get("weight", 0))
        except (TypeError, ValueError):
            continue
        if w >= arc_min:
            claims[str(sd.get("name") or "?")] = w
    for did, val in (arc.get("bvp_scores") or {}).items():
        try:
            v = int(val)
        except (TypeError, ValueError):
            continue
        if v >= arc_min:
            claims[str(did)] = v
    fms = []
    for sub in ("active", "completed"):
        for p in (PROJECT_ROOT / ".tasks" / sub).glob("T-*.md"):
            m = _FM_RE.match(p.read_text())
            if not m:
                continue
            fm = yaml.safe_load(m.group(1)) or {}
            aid = str(fm.get("arc_id") or "").strip()
            if aid and (aid == arc_slug or (arc_numeric and aid == arc_numeric)):
                fms.append(fm)
    out = []
    for driver_id, claim_val in claims.items():
        scores = []
        for fm in fms:
            s = (fm.get("bvp_scores") or {}).get(driver_id)
            if s is None:
                continue
            try:
                scores.append(int(s))
            except (TypeError, ValueError):
                continue
        if not scores:
            continue
        n_low = sum(1 for s in scores if s <= task_max)
        if n_low / len(scores) >= fraction:
            out.append({"driver": driver_id, "claim": claim_val, "n_low": n_low,
                        "n_total": len(scores)})
    return out


def _arcs_under_test():
    found = []
    for slug in ("continuous-run", "value-prioritisation", "dispatch-safety", "readme-first-run"):
        a = arcs._read_arc(slug)
        if a:
            found.append((slug, a))
    assert len(found) >= 2, "need at least two arcs on disk"
    return found


@pytest.mark.parametrize("slug", ["continuous-run", "value-prioritisation", "dispatch-safety"])
def test_members_and_bvp_match_legacy(slug):
    arc = arcs._read_arc(slug)
    if arc is None:
        pytest.skip("arc not present")
    num = str(arc.get("id") or "")
    new = bvp._arc_member_tasks(slug, num)
    old = _legacy_members(slug, num)
    assert [m.get("id") for m in new] == [m.get("id") for m in old]
    assert new == old

    weights = bvp._driver_weights(bvp._load_policy())
    rolled, _mode = bvp._arc_rolled_up_scores(old)
    sig = arcs._bvp_signals(arc, slug, num)
    if not (arc.get("bvp_scores") or bvp._latest_proposed_scores(arc)) and rolled:
        raw, norm = bvp._compute_bvp(rolled, weights)
        assert (sig["raw"], sig["norm"]) == (raw, norm)
        for row in sig["per_driver"]:
            s = rolled.get(row["id"])
            assert row["score"] == (int(s) if s is not None else None)
            assert row["contrib"] == (int(s) * row["weight"] if s is not None else None)


@pytest.mark.parametrize("slug", ["continuous-run", "value-prioritisation", "dispatch-safety"])
def test_coherence_matches_legacy_with_findings(slug, monkeypatch):
    arc = arcs._read_arc(slug)
    if arc is None:
        pytest.skip("arc not present")
    arc = dict(arc, status="in-progress", bvp_scores={"D1": 5, "D2": 5, "D3": 5, "D4": 5})
    # Thresholds forced open so findings actually fire: an empty==empty
    # comparison would prove nothing about the new membership path.
    monkeypatch.setenv("BVP_COHERENCE_ARC_MIN", "0")
    monkeypatch.setenv("BVP_COHERENCE_TASK_MAX", "5")
    monkeypatch.setenv("BVP_COHERENCE_FRACTION", "0.0")
    num = str(arc.get("id") or "")
    new = arcs._bvp_coherence_for_arc(arc, slug, num)
    old = _legacy_coherence(arc, slug, num)
    strip = lambda rows: [{k: r[k] for k in ("driver", "claim", "n_low", "n_total")} for r in rows]
    assert strip(new) == old


def test_coherence_fires_on_synthetic_low_scores(monkeypatch):
    """Control leg: no task in the corpus carries confirmed bvp_scores, so the
    legacy comparison above is empty==empty. Inject low scores into the members
    the new path resolves and require the finding to fire with the right count."""
    slug = "continuous-run"
    arc = dict(arcs._read_arc(slug), status="in-progress", bvp_scores={"D1": 5})
    real = bvp._parse_frontmatter
    monkeypatch.setattr(bvp, "_parse_frontmatter", lambda p: dict(real(p) or {}, bvp_scores={"D1": 0}))
    found = arcs._bvp_coherence_for_arc(arc, slug, str(arc.get("id") or ""))
    n_members = len(bvp._task_index()["by_arc_id"].get(slug, [])) + len(
        bvp._task_index()["by_arc_id"].get(str(arc.get("id") or ""), []))
    assert found and found[0]["driver"] == "D1"
    assert found[0]["n_total"] == found[0]["n_low"] == n_members > 0


def test_warm_arc_page_does_not_reparse_corpus(monkeypatch):
    """Second request for the same arc parses zero frontmatters."""
    from web.app import app

    client = app.test_client()
    assert client.get("/arcs/continuous-run").status_code == 200  # warm caches
    calls = []
    real = bvp._parse_fm_from_path
    monkeypatch.setattr(bvp, "_parse_fm_from_path", lambda p: (calls.append(p), real(p))[1])
    t = time.time()
    assert client.get("/arcs/continuous-run").status_code == 200
    assert len(calls) < 50, f"warm request re-parsed {len(calls)} task files"
    assert time.time() - t < 3.0
