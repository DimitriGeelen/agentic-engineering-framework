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
import json
import re
import subprocess
from pathlib import Path

import yaml
from flask import Blueprint, render_template, request

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


def _compute_cost(ce: dict | None, *, default_when_absent: bool = False) -> tuple[float | None, float | None, float | None, float | None, str]:
    """Return (composite, blast_radius, tier, effort, source).

    T-1934: when default_when_absent=True (proposed-mode rendering), an
    absent cost_estimate falls back to T-shirt M (4.0) with source
    "default-medium" so the point still renders. The proper cost
    estimator is the T-1935 follow-up.
    """
    if not isinstance(ce, dict):
        if default_when_absent:
            return float(TSHIRT["M"]), None, None, None, "default-medium"
        return None, None, None, None, "absent"
    br, tier, effort = ce.get("blast_radius"), ce.get("tier"), ce.get("effort")
    if br is not None and tier is not None and effort is not None:
        composite = 0.6 * float(br) + 0.3 * float(tier) + 0.1 * float(effort)
        return composite, float(br), float(tier), float(effort), "three-component"
    size = ce.get("size")
    if size and str(size).upper() in TSHIRT:
        v = float(TSHIRT[str(size).upper()])
        return v, None, None, None, "tshirt"
    if default_when_absent:
        return float(TSHIRT["M"]), None, None, None, "default-medium"
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


def _latest_proposed_scores(fm: dict) -> dict | None:
    """T-1934: pull the newest proposed-score entry's scores dict, if any."""
    proposed = fm.get("bvp_scores_proposed")
    if not proposed or not isinstance(proposed, list):
        return None
    latest = proposed[-1] if isinstance(proposed[-1], dict) else None
    if not latest:
        return None
    scores = latest.get("scores")
    if not scores or not isinstance(scores, dict):
        return None
    return scores


def _latest_proposed_cost_estimate(fm: dict) -> dict | None:
    """T-1935: pull the newest proposed cost_estimate entry, if any.

    Returns the inner `cost_estimate` dict (shape `{blast_radius, tier,
    effort}`) — caller treats it identically to a confirmed
    `cost_estimate:` field. Sovereignty: never reads from `cost_estimate:`
    so callers must dispatch to this only when confirmed is absent.
    """
    proposed = fm.get("cost_estimate_proposed")
    if not proposed or not isinstance(proposed, list):
        return None
    latest = proposed[-1] if isinstance(proposed[-1], dict) else None
    if not latest:
        return None
    ce = latest.get("cost_estimate")
    if not ce or not isinstance(ce, dict):
        return None
    return ce


def _resolve_cost_estimate(fm: dict, *, is_proposed: bool) -> tuple[dict | None, str]:
    """T-1935: resolve which cost_estimate to feed into `_compute_cost`.

    Returns (cost_dict, mode_tag) where mode_tag is one of:
      - "confirmed"           — `cost_estimate:` field present
      - "proposed"            — `cost_estimate_proposed:` latest entry
      - "default"             — neither; caller falls back to default-medium

    `is_proposed` parameter tells us whether the BVP point itself is in
    proposed-mode; we route to proposed-cost only in that case (else stay
    strict). This preserves T-1934's confirmed-strict semantics.
    """
    confirmed = fm.get("cost_estimate")
    if isinstance(confirmed, dict) and confirmed:
        return confirmed, "confirmed"
    if is_proposed:
        proposed = _latest_proposed_cost_estimate(fm)
        if proposed:
            return proposed, "proposed"
    return None, "default"


def _collect_task_points(weights: dict[str, int]) -> list[dict]:
    """T-1934: returns both confirmed and proposed points. Confirmed scores
    take precedence (proposed is skipped if confirmed exists for the same
    task — the scatter shows one point per task)."""
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
            confirmed = fm.get("bvp_scores") or {}
            proposed = _latest_proposed_scores(fm)
            if not confirmed and not proposed:
                continue
            is_proposed = not confirmed
            scores = confirmed if confirmed else proposed
            raw, norm = _compute_bvp(scores, weights)
            ce, ce_mode = _resolve_cost_estimate(fm, is_proposed=is_proposed)
            cost, br, tier, effort, src = _compute_cost(ce, default_when_absent=is_proposed)
            if ce_mode == "proposed" and src != "default-medium":
                src = src + "-proposed"
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
                "scores": {k: int(v) for k, v in scores.items() if isinstance(v, (int, float))},
                "proposed": is_proposed,
            })
    return points


def _collect_arc_points(weights: dict[str, int]) -> list[dict]:
    """T-1934: include arcs with proposed scores (advisory) alongside confirmed."""
    points: list[dict] = []
    for p in sorted(glob.glob(str(PROJECT_ROOT / ".context" / "arcs" / "*.yaml"))):
        try:
            data = yaml.safe_load(Path(p).read_text()) or {}
        except yaml.YAMLError:
            continue
        confirmed = data.get("bvp_scores") or {}
        proposed = _latest_proposed_scores(data)
        if not confirmed and not proposed:
            continue
        is_proposed = not confirmed
        scores = confirmed if confirmed else proposed
        raw, norm = _compute_bvp(scores, weights)
        ce, ce_mode = _resolve_cost_estimate(data, is_proposed=is_proposed)
        cost, br, tier, effort, src = _compute_cost(ce, default_when_absent=is_proposed)
        if ce_mode == "proposed" and src != "default-medium":
            src = src + "-proposed"
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
            "scores": {k: int(v) for k, v in scores.items() if isinstance(v, (int, float))},
            "proposed": is_proposed,
        })
    return points


@bp.route("/api/bvp/commit-weights", methods=["POST"])
def bvp_commit_weights():
    """T-1929 (arc-006): commit driver weight changes via `fw bvp weight`.

    Body fields:
      rationale : str (≥30 chars, R6 enforced server-side too)
      changes   : JSON list of {driver: <Dn|free_name>, weight: 0-9}

    Shells once per change to `bin/fw bvp weight --set Dn=N
    --rationale "<...>" --from-watchtower`. Stops on first failure and
    reports it. §ACD + history audit stay in the fw command.
    """
    rationale = (request.form.get("rationale") or "").strip()
    raw_changes = request.form.get("changes") or "[]"
    if len(rationale) < 30:
        return "Rationale must be ≥30 characters (R6).", 400
    try:
        changes = json.loads(raw_changes)
    except json.JSONDecodeError:
        return "Invalid changes payload (not JSON).", 400
    if not isinstance(changes, list) or not changes:
        return "No changes provided.", 400
    if len(changes) > 16:
        return "Too many changes in one commit (max 16).", 400

    results = []
    for change in changes:
        if not isinstance(change, dict):
            return f"Bad change shape: {change!r}", 400
        driver = str(change.get("driver") or "").strip()
        try:
            weight = int(change.get("weight"))
        except (TypeError, ValueError):
            return f"Bad weight for driver {driver!r}", 400
        if not re.fullmatch(r"D\d+|[A-Za-z][A-Za-z0-9_-]*", driver):
            return f"Bad driver name {driver!r}", 400
        if not 0 <= weight <= 9:
            return f"Driver {driver}: weight {weight} out of range (0-9)", 400
        cmd = [
            "bin/fw", "bvp", "weight",
            "--set", f"{driver}={weight}",
            "--rationale", rationale,
            "--from-watchtower",
        ]
        try:
            result = subprocess.run(
                cmd, cwd=str(PROJECT_ROOT),
                capture_output=True, text=True, timeout=30,
            )
        except (subprocess.SubprocessError, OSError) as e:
            return f"Subprocess error on {driver}: {e}", 500
        if result.returncode != 0:
            err = (result.stderr or result.stdout or "").strip()
            first = err.splitlines()[0] if err else f"fw bvp weight exited {result.returncode}"
            return f"Commit failed at {driver}: {first}", 400
        results.append({"driver": driver, "weight": weight})
    return json.dumps({"committed": results, "count": len(results)}), 200, {"Content-Type": "application/json"}


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
