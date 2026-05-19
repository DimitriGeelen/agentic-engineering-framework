"""BVP scatter blueprint — T-1928 (arc-006, value-prioritisation, T-NEW-12a).

Static read-only quadrant scatter at `/bvp`:
  x-axis = composite cost (F8: 0.6×blast_radius + 0.3×tier + 0.1×effort,
                           or Q2 T-shirt fallback S/M/L/XL → 2/4/6/8)
  y-axis = BVP_norm (raw / max-possible against drivers in use, [0,1])

Tasks render as small dots; arcs as larger dots. Cost composite exposes the
3 sub-components in the hover tooltip (the F8 mechanic must remain
diagnosable per artefact §4).

Read-only by design. Live weight sliders + commit ship in T-1929 (T-NEW-12b).

Math intentionally duplicates `lib/bvp.sh:_bvp_python_engine` (~30 LOC, two
formulas) rather than subprocess'ing `fw bvp` per request. The formulas are
documented in 040-ValueDrivers.md; tests pin them in `lib/bvp.sh`.
"""

from __future__ import annotations

import glob
import re
from pathlib import Path

import yaml
from flask import Blueprint, render_template

from web.shared import PROJECT_ROOT

bp = Blueprint("bvp", __name__)

POLICY_PATH = PROJECT_ROOT / "policy" / "value-drivers.yaml"
TSHIRT = {"S": 2, "M": 4, "L": 6, "XL": 8}


def _load_policy() -> dict:
    if not POLICY_PATH.exists():
        return {}
    try:
        return yaml.safe_load(POLICY_PATH.read_text()) or {}
    except yaml.YAMLError:
        return {}


def _driver_weights(policy: dict) -> dict[str, int]:
    out: dict[str, int] = {}
    for d in (policy.get("protected_drivers") or []):
        if d.get("id"):
            out[d["id"]] = int(d.get("weight", 0))
    for d in (policy.get("free_drivers") or []):
        if d.get("id"):
            out[d["id"]] = int(d.get("weight", 0))
    return out


def _compute_bvp(scores: dict, weights: dict[str, int]) -> tuple[int, float]:
    raw = 0
    weight_sum = 0
    for d_id, w in weights.items():
        if d_id in scores:
            raw += int(scores[d_id]) * w
            weight_sum += w
    if weight_sum == 0:
        return 0, 0.0
    return raw, raw / (5 * weight_sum)


def _compute_cost(ce: dict | None) -> tuple[float | None, float | None, float | None, float | None, str]:
    """Return (composite, blast_radius, tier, effort, source)."""
    if not isinstance(ce, dict):
        return None, None, None, None, "absent"
    br, tier, effort = ce.get("blast_radius"), ce.get("tier"), ce.get("effort")
    if br is not None and tier is not None and effort is not None:
        composite = 0.6 * float(br) + 0.3 * float(tier) + 0.1 * float(effort)
        return composite, float(br), float(tier), float(effort), "three-component"
    size = ce.get("size")
    if size and str(size).upper() in TSHIRT:
        v = float(TSHIRT[str(size).upper()])
        return v, None, None, None, "tshirt"
    return None, None, None, None, "absent"


_FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---", re.DOTALL)


def _parse_frontmatter(path: Path) -> dict | None:
    try:
        text = path.read_text()
    except OSError:
        return None
    m = _FRONTMATTER_RE.match(text)
    if not m:
        return None
    try:
        return yaml.safe_load(m.group(1)) or {}
    except yaml.YAMLError:
        return None


def _collect_task_points(weights: dict[str, int]) -> list[dict]:
    points: list[dict] = []
    patterns = [
        str(PROJECT_ROOT / ".tasks" / "active" / "T-*.md"),
        str(PROJECT_ROOT / ".tasks" / "completed" / "T-*.md"),
    ]
    for pattern in patterns:
        for p in sorted(glob.glob(pattern)):
            fm = _parse_frontmatter(Path(p))
            if not fm:
                continue
            scores = fm.get("bvp_scores") or {}
            if not scores:
                continue
            raw, norm = _compute_bvp(scores, weights)
            cost, br, tier, effort, src = _compute_cost(fm.get("cost_estimate"))
            if cost is None:
                continue
            points.append({
                "kind": "task",
                "id": fm.get("id") or Path(p).stem,
                "name": (fm.get("name") or "")[:80],
                "bvp_raw": raw,
                "bvp_norm": round(norm, 4),
                "cost": round(cost, 3),
                "cost_source": src,
                "blast_radius": br,
                "tier": tier,
                "effort": effort,
                "status": fm.get("status") or "-",
            })
    return points


def _collect_arc_points(weights: dict[str, int]) -> list[dict]:
    points: list[dict] = []
    for p in sorted(glob.glob(str(PROJECT_ROOT / ".context" / "arcs" / "*.yaml"))):
        try:
            data = yaml.safe_load(Path(p).read_text()) or {}
        except yaml.YAMLError:
            continue
        scores = data.get("bvp_scores") or {}
        if not scores:
            continue
        raw, norm = _compute_bvp(scores, weights)
        cost, br, tier, effort, src = _compute_cost(data.get("cost_estimate"))
        points.append({
            "kind": "arc",
            "id": data.get("id") or Path(p).stem,
            "slug": data.get("slug") or Path(p).stem,
            "name": (data.get("name") or "")[:80],
            "bvp_raw": raw,
            "bvp_norm": round(norm, 4),
            "cost": round(cost, 3) if cost is not None else None,
            "cost_source": src,
            "blast_radius": br,
            "tier": tier,
            "effort": effort,
            "status": data.get("status") or "-",
        })
    return points


@bp.route("/bvp")
def bvp_scatter():
    policy = _load_policy()
    weights = _driver_weights(policy)
    task_points = _collect_task_points(weights)
    arc_points = _collect_arc_points(weights)
    return render_template(
        "bvp.html",
        page_title="BVP Quadrant Scatter",
        active_endpoint="bvp.bvp_scatter",
        task_points=task_points,
        arc_points=arc_points,
        weights=weights,
        empty=(not task_points and not arc_points),
    )
