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

from web.shared import mtime_cached_get

from web.shared import PROJECT_ROOT

bp = Blueprint("bvp", __name__)

# PROJECT_ROOT deliberate (T-2648/OBS-097 allowlist): value-drivers.yaml is a
# per-project policy INSTANCE seeded from the framework template by
# `fw bvp driver --init` (T-2229) — not a framework-owned asset.
POLICY_PATH = PROJECT_ROOT / "policy" / "value-drivers.yaml"
PROPOSALS_PATH = PROJECT_ROOT / ".context" / "bvp-driver-proposals.jsonl"
TSHIRT = {"S": 2, "M": 4, "L": 6, "XL": 8}


def _load_proposals(state_filter: str | None = "pending") -> list[dict]:
    """T-2332 (T-2330 S2): read .context/bvp-driver-proposals.jsonl and apply
    state machine. Each proposal id has one or more rows; the last row's state
    wins. Default returns only `state: pending` rows (queue surface usage).
    Pass `state_filter=None` for full history.
    """
    if not PROPOSALS_PATH.exists():
        return []
    by_id: dict[str, dict] = {}
    order: list[str] = []
    try:
        with open(PROPOSALS_PATH) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    row = json.loads(line)
                except json.JSONDecodeError:
                    continue
                pid = row.get("id")
                if not pid:
                    continue
                if pid not in by_id:
                    by_id[pid] = row
                    order.append(pid)
                else:
                    merged = dict(by_id[pid])
                    merged["state"] = row.get("state", merged.get("state"))
                    merged["decision_ts"] = row.get("ts")
                    merged["decision_actor"] = row.get("actor")
                    merged["decision_rationale"] = row.get("rationale_decision")
                    by_id[pid] = merged
    except OSError:
        return []
    rows = [by_id[pid] for pid in order]
    if state_filter:
        rows = [r for r in rows if r.get("state") == state_filter]
    return rows


def _append_proposal_state_change(proposal_id: str, new_state: str, rationale_decision: str | None = None) -> bool:
    """Append a state-change row to the JSONL. Returns True on success."""
    from datetime import datetime, timezone
    ts = datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")
    row = {
        "id": proposal_id,
        "ts": ts,
        "state": new_state,
        "actor": "operator-watchtower",
    }
    if rationale_decision:
        row["rationale_decision"] = rationale_decision
    try:
        PROPOSALS_PATH.parent.mkdir(exist_ok=True)
        with open(PROPOSALS_PATH, "a") as f:
            f.write(json.dumps(row) + "\n")
        return True
    except OSError:
        return False


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


# T-2084: per-driver 0-5 scoring rubric for inline hover/expand on /bvp.
# Source: policy/bvp-scoring-rubric.md (D1-D4 formal tables); free drivers
# (F1+) parsed from policy/value-drivers.yaml `rationale` field which embeds
# the 0-5 levels inline. Missing rubric → empty list; template renders no
# expand block for that driver (graceful degrade).
# PROJECT_ROOT deliberate — per-project instance, seeded by --init (T-2229).
RUBRIC_PATH = PROJECT_ROOT / "policy" / "bvp-scoring-rubric.md"


def _driver_rubrics(policy: dict) -> dict[str, list[tuple[str, str]]]:
    """Return {driver_id: [(label, desc), …]}.

    `label` is a single score (`"3"`) or an inclusive range (`"1–2"`) — the
    template renders it as `**<label>** — <desc>`. Range labels collapse
    adjacent rows that share a description; T-2086 source intent of the
    `1–2 — desc` syntax in value-drivers.yaml is "one row covering two scores",
    not "two identical rows".

    Protected drivers (D1-D4): parsed from `policy/bvp-scoring-rubric.md`'s
    per-driver `### Score criteria` markdown table — one row per score.
    Free drivers (F1+):        parsed from each driver's `rationale` in
                               value-drivers.yaml, which embeds the levels
                               inline as "<n> — <desc>" or "<lo>–<hi> — <desc>".
    Drivers without parseable rubric → omitted; the template `{% if rubric %}`
    gate skips them silently.
    """
    import re as _re

    out: dict[str, list[tuple[str, str]]] = {}

    # Protected — rubric.md per-driver tables. Always single-score labels.
    if RUBRIC_PATH.exists():
        try:
            text = RUBRIC_PATH.read_text()
        except OSError:
            text = ""
        # `## <id> — <name>` … `### Score criteria` … `| **<n>** | <desc> |`
        section_pat = _re.compile(
            r"^## ([DF]\d+) — [^\n]+?$.*?### Score criteria\s*\n\n"
            r"(\|.*?(?=\n##|\Z))",
            _re.M | _re.DOTALL,
        )
        row_pat = _re.compile(r"\| \*\*(\d)\*\* \| (.+?) \|")
        for m in section_pat.finditer(text):
            did = m.group(1)
            rows = row_pat.findall(m.group(2))
            scored = {int(s): d.strip() for s, d in rows}
            if all(i in scored for i in range(6)):
                out[did] = [(str(i), scored[i]) for i in range(6)]

    # Free drivers — two sources, in priority order:
    #   1. Structured `rubric:` YAML field (canonical, used by F-RECALL/F-ORCH/V_*).
    #      Shape: {0: "...", 1: "...", 2: "...", 3: "...", 4: "...", 5: "..."}.
    #      Rendered as single-score labels matching the protected-driver shape.
    #   2. Inline level enumeration in `rationale:` text (legacy fallback).
    #      Accepts: "0 — desc", "1–2 — desc" (en-dash range), "1-2 — desc".
    #      Source order preserved; a range stays one entry (T-2086).
    line_pat = _re.compile(
        r"^\s*(\d)(?:\s*[–\-]\s*(\d))?\s*—\s*(.+?)\s*$", _re.M
    )
    for d in (policy.get("free_drivers") or []):
        did = d.get("id")
        if not did or did in out:
            continue
        # T-2336: prefer structured `rubric:` YAML field when present.
        rubric_yaml = d.get("rubric")
        if isinstance(rubric_yaml, dict) and all(i in rubric_yaml for i in range(6)):
            out[did] = [(str(i), str(rubric_yaml[i]).strip()) for i in range(6)]
            continue
        rationale = str(d.get("rationale") or "")
        if not rationale:
            continue
        ranges: list[tuple[int, int, str]] = []  # (lo, hi, desc), source order
        for m in line_pat.finditer(rationale):
            lo = int(m.group(1))
            hi = int(m.group(2)) if m.group(2) else lo
            if 0 <= lo <= hi <= 5:
                ranges.append((lo, hi, m.group(3).strip()))
        # Validate exact 0-5 coverage with no overlap; otherwise skip (graceful).
        covered: set[int] = set()
        ok = True
        for lo, hi, _desc in ranges:
            for s in range(lo, hi + 1):
                if s in covered:
                    ok = False
                    break
                covered.add(s)
            if not ok:
                break
        if ok and covered == set(range(6)):
            out[did] = [
                (str(lo) if lo == hi else f"{lo}–{hi}", desc)
                for lo, hi, desc in ranges
            ]

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

# T-1954/T-2109: per-file frontmatter cache keyed on path -> (mtime_ns, parsed_fm).
# /bvp scans ~1900 task files per request; the slow part is yaml.safe_load on
# each, not the disk read. Caching parsed frontmatter and invalidating on
# mtime change brings the page from ~17s to <1s on warm cache. Memory cost:
# ~1900 small dicts (a few MB); the Flask process is long-running so the cost
# amortises across requests.
# T-2109: migrated from local stat+cache logic to shared.mtime_cached_get (the
# 5th re-implementation of this pattern is what triggered promotion).
_FM_CACHE: dict[str, tuple[int, dict | None]] = {}


def _parse_fm_from_path(path: Path) -> dict | None:
    """Read + parse frontmatter from path, returning None on any failure."""
    try:
        text = path.read_text()
    except OSError:
        return None
    m = _FRONTMATTER_RE.match(text)
    if not m:
        return None
    try:
        result: dict | None = yaml.safe_load(m.group(1)) or {}
    except yaml.YAMLError:
        return None
    return result


def _parse_frontmatter(path: Path) -> dict | None:
    return mtime_cached_get(path, _parse_fm_from_path, _FM_CACHE, default=None)


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
            # T-2192 (T-2186 slice 6): surface workflow_type + inception scoring
            # fields so the scatter can style inceptions distinctly. None values
            # are emitted on non-inception points so the JS doesn't need to test
            # presence — `d.voi_score !== null` is a clean tooltip-guard.
            wf = (fm.get("workflow_type") or "").strip() or None
            tbr_val = fm.get("target_blast_radius")
            voi_val = fm.get("voi_score")
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
                "workflow_type": wf,
                "target_blast_radius": int(tbr_val) if isinstance(tbr_val, (int, float)) else None,
                "voi_score": float(voi_val) if isinstance(voi_val, (int, float)) else None,
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


@bp.route("/api/bvp/driver/propose", methods=["POST"])
def bvp_driver_propose():
    """T-2332 (T-2330 S2): file a pending driver proposal — NON-Sovereign.

    Shells out to `bin/fw bvp driver --propose` (T-2331). Storage is
    .context/bvp-driver-proposals.jsonl (append-only JSONL). Approve/Reject
    actions handle the Sovereign rail.

    Form fields: name, weight, rationale (≥30 chars), drop (optional), task (optional).
    """
    name = (request.form.get("name") or "").strip()
    weight_raw = (request.form.get("weight") or "").strip()
    rationale = (request.form.get("rationale") or "").strip()
    drop_id = (request.form.get("drop") or "").strip() or None
    task_id = (request.form.get("task") or "").strip() or None

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

    cmd = [
        "bin/fw", "bvp", "driver",
        "--propose", name,
        "--weight", str(weight),
        "--rationale", rationale,
    ]
    if drop_id:
        cmd.extend(["--drop", drop_id])
    if task_id:
        cmd.extend(["--task", task_id])
    try:
        result = subprocess.run(
            cmd, cwd=str(PROJECT_ROOT),
            capture_output=True, text=True, timeout=30,
        )
    except (subprocess.SubprocessError, OSError) as e:
        return f"Subprocess error: {e}", 500
    if result.returncode != 0:
        err = (result.stderr or result.stdout or "").strip()
        first = err.splitlines()[0] if err else f"fw bvp driver --propose exited {result.returncode}"
        return f"Propose failed: {first}", 400
    out = (result.stdout or "").strip()
    if request.headers.get("HX-Request"):
        msg = out.splitlines()[0] if out else f"Proposal for {name} filed (state: pending)."
        return (
            f'<span style="color: var(--pico-ins-color);">✓ {msg} Reloading…</span>',
            200,
            {"Content-Type": "text/html", "HX-Trigger": "bvpReload"},
        )
    return json.dumps({"ok": True, "message": out, "name": name, "weight": weight}), 200, {"Content-Type": "application/json"}


@bp.route("/api/bvp/driver/approve", methods=["POST"])
def bvp_driver_approve():
    """T-2332 (T-2330 S2): operator-side Sovereign approve.

    Reads the pending proposal, runs `fw bvp driver --add --from-watchtower`
    with its stored fields, then appends `state: approved` row on success.
    Refuses on already-decided / missing-id proposals.
    """
    proposal_id = (request.args.get("id") or request.form.get("id") or "").strip()
    if not re.fullmatch(r"P-[a-f0-9]+", proposal_id):
        return f"Bad proposal id {proposal_id!r}", 400

    pending = {p["id"]: p for p in _load_proposals(state_filter="pending")}
    proposal = pending.get(proposal_id)
    if not proposal:
        return f"Proposal {proposal_id} not in pending state (already decided or missing).", 404

    cmd = [
        "bin/fw", "bvp", "driver",
        "--add", proposal["name"],
        "--weight", str(proposal["weight"]),
        "--rationale", proposal["rationale"],
        "--from-watchtower",
    ]
    if proposal.get("drop"):
        cmd.extend(["--drop", proposal["drop"]])
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
        return f"Approve failed: {first}", 400
    if not _append_proposal_state_change(proposal_id, "approved"):
        return f"Driver added but state-change row failed to append (manual recovery needed)", 500
    out = (result.stdout or "").strip()
    if request.headers.get("HX-Request"):
        msg = out or f"Proposal {proposal_id} approved → driver added."
        return (
            f'<span style="color: var(--pico-ins-color);">✓ {msg} Reloading…</span>',
            200,
            {"Content-Type": "text/html", "HX-Trigger": "bvpReload"},
        )
    return json.dumps({"ok": True, "approved": proposal_id, "name": proposal["name"], "message": out}), 200, {"Content-Type": "application/json"}


@bp.route("/api/bvp/driver/reject", methods=["POST"])
def bvp_driver_reject():
    """T-2332 (T-2330 S2): operator-side Reject — appends state:rejected row.

    Rationale-decision comes from `HX-Prompt` header (browser prompt() result)
    same pattern as the `--remove` endpoint (T-2079). NOT Sovereign — rejecting
    is the absence of a policy edit, not a policy edit itself.
    """
    proposal_id = (request.args.get("id") or request.form.get("id") or "").strip()
    rationale_decision = (
        request.headers.get("HX-Prompt")
        or request.form.get("rationale_decision")
        or ""
    ).strip()

    if not re.fullmatch(r"P-[a-f0-9]+", proposal_id):
        return f"Bad proposal id {proposal_id!r}", 400
    if len(rationale_decision) < 30:
        return "Reject rationale must be ≥30 characters (matches propose R6 floor).", 400

    pending = {p["id"]: p for p in _load_proposals(state_filter="pending")}
    if proposal_id not in pending:
        return f"Proposal {proposal_id} not in pending state (already decided or missing).", 404

    if not _append_proposal_state_change(proposal_id, "rejected", rationale_decision):
        return f"State-change row failed to append.", 500
    if request.headers.get("HX-Request"):
        return (
            f'<span style="color: var(--pico-del-color);">✗ Proposal {proposal_id} rejected. Reloading…</span>',
            200,
            {"Content-Type": "text/html", "HX-Trigger": "bvpReload"},
        )
    return json.dumps({"ok": True, "rejected": proposal_id, "rationale_decision": rationale_decision}), 200, {"Content-Type": "application/json"}


@bp.route("/bvp")
def bvp_scatter():
    policy = _load_policy()
    weights = _driver_weights(policy)
    driver_names = _driver_names(policy)
    driver_rubrics = _driver_rubrics(policy)
    task_points = _collect_task_points(weights)
    arc_points = _collect_arc_points(weights)
    pending_proposals = _load_proposals(state_filter="pending")
    return render_template(
        "bvp.html",
        page_title="BVP Quadrant Scatter",
        active_endpoint="bvp.bvp_scatter",
        task_points=task_points,
        arc_points=arc_points,
        weights=weights,
        driver_names=driver_names,
        driver_rubrics=driver_rubrics,
        pending_proposals=pending_proposals,
        empty=(not task_points and not arc_points),
    )
