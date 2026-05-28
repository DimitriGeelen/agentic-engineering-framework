"""BVP scatter blueprint — T-1928 (arc-006, value-prioritisation, T-NEW-12a).

Static read-only quadrant scatter at `/bvp`:
  x-axis = composite cost (F8: 0.6×blast_radius + 0.3×tier + 0.1×effort,
                           or Q2 T-shirt fallback S/M/L/XL → 2/4/6/8)
  y-axis = BVP_norm (raw / max-possible against drivers in use, [0,1])

Tasks render as small dots; arcs as larger dots. Cost composite exposes the
3 sub-components in the hover tooltip (the F8 mechanic must remain
diagnosable per artefact §4).

Live weight sliders + commit ship via `fw bvp weight --from-watchtower` (T-1929,
§ACD gate). Read-only fallback when no `weights` data is available.

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


def _driver_names(policy: dict) -> dict[str, str]:
    """T-2080: sister to _driver_weights — return {id: name} so the /bvp
    sliders table can render the human-readable name next to the code.
    Falls back silently when a driver is missing a name field (id stays the
    sole identifier, the template's `|default(...)` handles the absence)."""
    out: dict[str, str] = {}
    for d in (policy.get("protected_drivers") or []):
        if d.get("id"):
            out[d["id"]] = str(d.get("name") or "")
    for d in (policy.get("free_drivers") or []):
        if d.get("id"):
            out[d["id"]] = str(d.get("name") or "")
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

# T-1954: per-file frontmatter cache keyed on path -> (mtime_ns, parsed_fm).
# /bvp scans ~1900 task files per request; the slow part is yaml.safe_load on
# each, not the disk read. Caching parsed frontmatter and invalidating on
# mtime change brings the page from ~17s to <1s on warm cache. Memory cost:
# ~1900 small dicts (a few MB); the Flask process is long-running so the cost
# amortises across requests.
_FM_CACHE: dict[str, tuple[int, dict | None]] = {}


def _parse_frontmatter(path: Path) -> dict | None:
    try:
        mtime_ns = path.stat().st_mtime_ns
    except OSError:
        return None
    cached = _FM_CACHE.get(str(path))
    if cached is not None and cached[0] == mtime_ns:
        return cached[1]
    try:
        text = path.read_text()
    except OSError:
        _FM_CACHE[str(path)] = (mtime_ns, None)
        return None
    m = _FRONTMATTER_RE.match(text)
    if not m:
        _FM_CACHE[str(path)] = (mtime_ns, None)
        return None
    try:
        result: dict | None = yaml.safe_load(m.group(1)) or {}
    except yaml.YAMLError:
        result = None
    _FM_CACHE[str(path)] = (mtime_ns, result)
    return result


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


def _arc_member_tasks(arc_slug: str, arc_id_str: str) -> list[dict]:
    """T-1936: return frontmatter dicts of tasks whose `arc_id:` matches
    the arc slug or canonical arc-NNN id.

    Both `arc_id: value-prioritisation` and `arc_id: arc-006` are accepted
    bindings to the same arc (per T-1849 dual-form rule).
    """
    members: list[dict] = []
    patterns = [
        str(PROJECT_ROOT / ".tasks" / "active" / "T-*.md"),
        str(PROJECT_ROOT / ".tasks" / "completed" / "T-*.md"),
    ]
    targets = {x for x in (arc_slug, arc_id_str) if x}
    for pattern in patterns:
        for p in sorted(glob.glob(pattern)):
            fm = _parse_frontmatter(Path(p))
            if not fm:
                continue
            arc_id = fm.get("arc_id")
            if arc_id and str(arc_id) in targets:
                members.append(fm)
    return members


def _arc_rolled_up_scores(members: list[dict]) -> tuple[dict[str, int] | None, str]:
    """T-1936: mean-aggregate per-driver scores across arc members.

    Returns (scores_dict, mode) where mode ∈ {derived-confirmed,
    derived-proposed, ""}. derived-confirmed requires every contributing
    member to have confirmed `bvp_scores:`. Mixed mode degrades to
    derived-proposed (sovereignty: one proposed input taints the whole).
    """
    if not members:
        return None, ""
    per_driver: dict[str, list[int]] = {}
    any_proposed = False
    for fm in members:
        confirmed = fm.get("bvp_scores") or {}
        if confirmed and isinstance(confirmed, dict):
            for k, v in confirmed.items():
                if isinstance(v, (int, float)):
                    per_driver.setdefault(k, []).append(int(v))
            continue
        proposed = _latest_proposed_scores(fm)
        if proposed:
            any_proposed = True
            for k, v in proposed.items():
                if isinstance(v, (int, float)):
                    per_driver.setdefault(k, []).append(int(v))
    if not per_driver:
        return None, ""
    scores = {k: round(sum(vs) / len(vs)) for k, vs in per_driver.items()}
    mode = "derived-proposed" if any_proposed else "derived-confirmed"
    return scores, mode


def _arc_rolled_up_cost(members: list[dict]) -> tuple[dict | None, str]:
    """T-1936: aggregate cost components across arc members.

    Aggregation:
      - blast_radius: max (arc blast is union)
      - tier: mean rounded
      - effort: sum, clamped to [0, 9] (arcs ARE thick — bigger than tasks)

    Returns (cost_dict, mode) parallel to `_arc_rolled_up_scores`.
    """
    if not members:
        return None, ""
    brs: list[int] = []
    tiers: list[int] = []
    efforts: list[int] = []
    any_proposed = False
    for fm in members:
        ce = fm.get("cost_estimate")
        if not (isinstance(ce, dict) and ce):
            ce = _latest_proposed_cost_estimate(fm)
            if ce:
                any_proposed = True
        if not ce:
            continue
        if isinstance(ce.get("blast_radius"), (int, float)):
            brs.append(int(ce["blast_radius"]))
        if isinstance(ce.get("tier"), (int, float)):
            tiers.append(int(ce["tier"]))
        if isinstance(ce.get("effort"), (int, float)):
            efforts.append(int(ce["effort"]))
    if not brs and not tiers and not efforts:
        return None, ""
    cost = {
        "blast_radius": max(brs) if brs else 0,
        "tier": round(sum(tiers) / len(tiers)) if tiers else 0,
        "effort": min(9, sum(efforts)) if efforts else 0,
    }
    mode = "derived-proposed" if any_proposed else "derived-confirmed"
    return cost, mode


def _collect_arc_points(weights: dict[str, int]) -> list[dict]:
    """T-1934 + T-1936: render arc points.

    Resolution order:
      1. Direct `bvp_scores:` on arc YAML → mode `direct-confirmed`
      2. Direct `bvp_scores_proposed:` → mode `direct-proposed`
      3. Rollup from member tasks via `arc_id:` → mode `derived-{confirmed,proposed}`
      4. Skip (no signal)

    Sovereignty: a direct `bvp_scores:` on the arc always overrides the
    rollup (human authority signal at arc level outranks aggregate).
    """
    points: list[dict] = []
    for p in sorted(glob.glob(str(PROJECT_ROOT / ".context" / "arcs" / "*.yaml"))):
        try:
            data = yaml.safe_load(Path(p).read_text()) or {}
        except yaml.YAMLError:
            continue
        confirmed = data.get("bvp_scores") or {}
        proposed = _latest_proposed_scores(data)
        bvp_mode = ""
        scores: dict | None = None
        rolled_cost: dict | None = None
        cost_mode = ""

        if confirmed:
            scores, bvp_mode = confirmed, "direct-confirmed"
        elif proposed:
            scores, bvp_mode = proposed, "direct-proposed"
        else:
            arc_slug = data.get("slug") or Path(p).stem
            arc_id_str = str(data.get("id") or "")
            members = _arc_member_tasks(arc_slug, arc_id_str)
            scores, bvp_mode = _arc_rolled_up_scores(members)
            if not scores:
                continue
            rolled_cost, cost_mode = _arc_rolled_up_cost(members)

        is_proposed = bvp_mode in ("direct-proposed", "derived-proposed")
        raw, norm = _compute_bvp(scores, weights)

        if rolled_cost is not None:
            cost, br, tier, effort, src = _compute_cost(rolled_cost, default_when_absent=is_proposed)
            if cost_mode and src != "default-medium":
                # cost_mode is "derived-confirmed" or "derived-proposed"; the
                # render-side cares about the provenance ("derived" = rolled up
                # from members), not the confirmed/proposed status of the inputs
                # (already encoded in `is_proposed`). Sufix the source for
                # tooltip diagnosability.
                src = f"{src}-derived"
        else:
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
            # T-1941: surface the 4-tier provenance slug so the scatter tooltip
            # can distinguish direct vs derived (rollup) — the scatter previously
            # collapsed both into `proposed: bool` and lost the rollup signal.
            # Empty string when no scores route emitted a mode (defensive; the
            # `continue` above on `not scores` should make this unreachable).
            "bvp_mode": bvp_mode or "",
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
    # T-2079: htmx clients get HTML fragment (rendered into target div); CLI/API
    # callers continue to receive the JSON envelope. HX-Trigger on success fires
    # a `bvp:reload` event the form's hx-on::after-request listens for.
    if request.headers.get("HX-Request"):
        summary = ", ".join(f"{r['driver']}={r['weight']}" for r in results)
        return (
            f'<p style="color: var(--pico-ins-color);">✓ Committed {len(results)} change(s) ({summary}). Reloading…</p>',
            200,
            {"Content-Type": "text/html", "HX-Trigger": "bvpReload"},
        )
    return json.dumps({"committed": results, "count": len(results)}), 200, {"Content-Type": "application/json"}


@bp.route("/api/bvp/driver/add", methods=["POST"])
def bvp_driver_add():
    """T-1964 (T-1958 A): add a free driver via `fw bvp driver --add`.

    Form fields:
      name      : str (regex [A-Za-z][A-Za-z0-9_-]*)
      weight    : int (0-9)
      rationale : str (≥30 chars, R6)
      drop      : str (optional; required when total drivers = cap=9, M1 add-one-drop-one)

    Validations mirror `lib/bvp.sh:_driver_add` so the form surfaces the same
    refusals the CLI does. §ACD authority + history audit stay in fw.
    """
    name = (request.form.get("name") or "").strip()
    weight_raw = (request.form.get("weight") or "").strip()
    rationale = (request.form.get("rationale") or "").strip()
    drop_id = (request.form.get("drop") or "").strip() or None

    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_-]*", name):
        return "Bad driver name: must match [A-Za-z][A-Za-z0-9_-]*", 400
    try:
        weight = int(weight_raw)
    except ValueError:
        return "Bad weight: must be an integer 0-9", 400
    if not 0 <= weight <= 9:
        return f"Weight {weight} out of range (0-9)", 400
    if len(rationale) < 30:
        return "Rationale must be ≥30 characters (R6).", 400
    if drop_id and drop_id.startswith("D"):
        return f"Cannot drop protected driver {drop_id} (D1-D4 are immutable in identity).", 400

    cmd = [
        "bin/fw", "bvp", "driver",
        "--add", name,
        "--weight", str(weight),
        "--rationale", rationale,
        "--from-watchtower",
    ]
    if drop_id:
        cmd.extend(["--drop", drop_id])
    try:
        result = subprocess.run(
            cmd, cwd=str(PROJECT_ROOT),
            capture_output=True, text=True, timeout=30,
        )
    except (subprocess.SubprocessError, OSError) as e:
        return f"Subprocess error: {e}", 500
    if result.returncode != 0:
        err = (result.stderr or result.stdout or "").strip()
        first = err.splitlines()[0] if err else f"fw bvp driver --add exited {result.returncode}"
        return f"Add failed: {first}", 400
    out = (result.stdout or "").strip()
    # T-2079: htmx clients get HTML fragment; CLI/API callers get JSON.
    if request.headers.get("HX-Request"):
        msg = out or f"Driver {name} added (weight {weight})."
        return (
            f'<span style="color: var(--pico-ins-color);">✓ {msg} Reloading…</span>',
            200,
            {"Content-Type": "text/html", "HX-Trigger": "bvpReload"},
        )
    return json.dumps({"ok": True, "message": out, "name": name, "weight": weight, "dropped": drop_id}), 200, {"Content-Type": "application/json"}


@bp.route("/api/bvp/driver/remove", methods=["POST"])
def bvp_driver_remove():
    """T-1965 (T-1958 B): remove a free driver via `fw bvp driver --remove`.

    Form fields:
      driver    : str (Fn or free-driver id; D1-D4 refused with 400)
      rationale : str (≥30 chars, R6)

    Server refuses D1-D4 (D1-D4 are immutable in identity, CLAUDE.md).
    §ACD authority + history audit stay in fw.
    """
    # T-2079: htmx remove buttons send driver via query string (hx-post URL)
    # and rationale via HX-Prompt header (browser prompt() result). Plain CLI/API
    # callers continue to send both as form fields.
    driver_id = (
        request.args.get("driver")
        or request.form.get("driver")
        or ""
    ).strip()
    rationale = (
        request.headers.get("HX-Prompt")
        or request.form.get("rationale")
        or ""
    ).strip()

    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_-]*", driver_id):
        return f"Bad driver id {driver_id!r}: must match [A-Za-z][A-Za-z0-9_-]*", 400
    if driver_id in ("D1", "D2", "D3", "D4"):
        return f"Cannot remove protected driver {driver_id} (D1-D4 are immutable in identity).", 400
    if len(rationale) < 30:
        return "Rationale must be ≥30 characters (R6).", 400

    cmd = [
        "bin/fw", "bvp", "driver",
        "--remove", driver_id,
        "--rationale", rationale,
        "--from-watchtower",
    ]
    try:
        result = subprocess.run(
            cmd, cwd=str(PROJECT_ROOT),
            capture_output=True, text=True, timeout=30,
        )
    except (subprocess.SubprocessError, OSError) as e:
        return f"Subprocess error: {e}", 500
    if result.returncode != 0:
        err = (result.stderr or result.stdout or "").strip()
        first = err.splitlines()[0] if err else f"fw bvp driver --remove exited {result.returncode}"
        return f"Remove failed: {first}", 400
    out = (result.stdout or "").strip()
    # T-2079: htmx clients get HTML fragment; CLI/API callers get JSON.
    if request.headers.get("HX-Request"):
        msg = out or f"Driver {driver_id} removed."
        return (
            f'<span style="color: var(--pico-ins-color);">✓ {msg} Reloading…</span>',
            200,
            {"Content-Type": "text/html", "HX-Trigger": "bvpReload"},
        )
    return json.dumps({"ok": True, "message": out, "removed": driver_id}), 200, {"Content-Type": "application/json"}


@bp.route("/bvp")
def bvp_scatter():
    policy = _load_policy()
    weights = _driver_weights(policy)
    driver_names = _driver_names(policy)
    task_points = _collect_task_points(weights)
    arc_points = _collect_arc_points(weights)
    return render_template(
        "bvp.html",
        page_title="BVP Quadrant Scatter",
        active_endpoint="bvp.bvp_scatter",
        task_points=task_points,
        arc_points=arc_points,
        weights=weights,
        driver_names=driver_names,
        empty=(not task_points and not arc_points),
    )
