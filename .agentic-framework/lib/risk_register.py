#!/usr/bin/env python3
"""T-5313 — validate the risk fields of the concerns register.

Risks live in `.context/project/concerns.yaml` as entries with `type: risk`
(T-397). T-5310 (GO 2026-11-20) added optional scoring fields so a risk can be
assessed with ring20's matrix (`.tasks/templates/risk-matrix.md`):

    likelihood: 1-5          impact: 1-5          score: likelihood x impact
    ranking: low | medium | high   (bands: 1-5 low, 6-12 medium, 15-25 high)
    actors:                         # optional per-actor split
      - actor: own-agent-unintentional | human-unintentional |
               outsider-intentional | provider-host | intruder
        how: "<one line>"
        likelihood: 1-5
        impact: 1-5
        mitigated_likelihood: 1-5   # optional, but both mitigated_* or neither
        mitigated_impact: 1-5
    introduced_by: T-XXXX           # the change that introduces the risk
    exists_anyway: true | false     # present in the baseline without the change?
    mitigation_task: T-XXXX         # task in the standing arc "risk"

Every field is optional, so the risks filed before T-5313 still validate. What
is present is checked: ranges, actor names, score arithmetic, band names.

Errors make the register invalid (`fw audit` FAILs). Warnings carry the rule
from the matrix: an open risk assessed with the new fields whose score — or any
actor's unmitigated score — is 6 or more needs a `mitigation_task`, and (T-5314)
any `mitigation_task` must name a task in .tasks/active or .tasks/completed
whose arc is the standing arc 'risk' (arc_id `risk` or its numeric id, read
through lib/arc_membership.py).

CLI:  python3 lib/risk_register.py [--path FILE] [--root DIR] [--json]
      --root is the project whose .tasks/ resolves mitigation_task; default:
      derived from a .context/project/concerns.yaml path, else PROJECT_ROOT/cwd.
Exit: 0 valid (warnings allowed), 1 errors, 2 register unreadable.

Matrix mode (T-5315):  python3 lib/risk_register.py --matrix FILE [--json]
      Checks a filled risk matrix (.tasks/templates/risk-matrix.md): the Summary
      table and one "### Risk N" actor-split table per risk. ERRORs for values
      outside 1-5, a score that is not L x I, a mitigated score that is not
      mitigated L x I, an unknown actor, a summary risk with no filled actor
      table. Lists the risks that need operator acceptance: introduced (NEW or
      PARTLY NEW) with worst mitigated score >= 6, or any score >= 15. An actor
      row with no mitigated values keeps its unmitigated score. An actor table
      may carry an optional "introduced" column (yes/no) saying whether the
      change adds that row; for a PARTLY NEW risk, acceptance then uses the
      worst mitigated score of the "yes" rows only (T-5334). Blank template
      rows are skipped. Exit 0 clean (the acceptance list may be non-empty),
      1 errors, 2 file unreadable.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from typing import Any, Dict, List, Optional, Tuple

ACTORS = (
    "own-agent-unintentional",
    "human-unintentional",
    "outsider-intentional",
    "provider-host",
    "intruder",
)
BANDS = (("low", 1, 5), ("medium", 6, 12), ("high", 15, 25))
MITIGATION_THRESHOLD = 6
CLOSED_STATUSES = {"resolved", "closed", "mitigated", "accepted", "retired"}
NEW_FIELDS = ("actors", "introduced_by", "exists_anyway", "mitigation_task")
_TASK_RE = re.compile(r"^T-\d+$")
RISK_ARC = "risk"
RISK_ARC_NUMERIC = "arc-028"

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from arc_membership import arc_identities, task_arc_membership  # noqa: E402


def band(score: int) -> Optional[str]:
    """Band name for a score, or None for a score no L x I product reaches."""
    for name, lo, hi in BANDS:
        if lo <= score <= hi:
            return name
    return None


def _is_scale(v: Any) -> bool:
    return isinstance(v, int) and not isinstance(v, bool) and 1 <= v <= 5


def _check_pair(where: str, obj: Dict[str, Any], lk: str, ik: str,
                sk: Optional[str], errors: List[str], required: bool) -> Optional[int]:
    """Validate a likelihood/impact pair (and its score); return L x I or None."""
    has_l, has_i = lk in obj, ik in obj
    if required and not (has_l and has_i):
        errors.append(f"{where}: needs both {lk} and {ik}")
        return None
    if has_l != has_i:
        errors.append(f"{where}: {lk} and {ik} must be given together")
        return None
    if not has_l:
        if sk and sk in obj:
            errors.append(f"{where}: {sk} given without {lk} and {ik}")
        return None
    ok = True
    for k in (lk, ik):
        if not _is_scale(obj[k]):
            errors.append(f"{where}: {k} must be an integer 1-5, got {obj[k]!r}")
            ok = False
    if not ok:
        return None
    product = obj[lk] * obj[ik]
    if sk and sk in obj and obj[sk] != product:
        errors.append(f"{where}: {sk} {obj[sk]!r} is not {lk} x {ik} = {product}")
    return product


def _find_task_file(project_root: str, tid: str) -> Optional[str]:
    """Path of task `tid` under .tasks/{active,completed}/, or None."""
    for sub in ("active", "completed"):
        d = os.path.join(project_root, ".tasks", sub)
        if not os.path.isdir(d):
            continue
        for name in sorted(os.listdir(d)):
            if name == f"{tid}.md" or (name.startswith(f"{tid}-") and name.endswith(".md")):
                return os.path.join(d, name)
    return None


def check_mitigation_task(rid: str, tid: str, project_root: str) -> Optional[str]:
    """T-5314: warning text when `tid` is missing or outside the standing arc, else None."""
    path = _find_task_file(project_root, tid)
    if path is None:
        return (f"{rid}: mitigation_task {tid} not found in .tasks/active or .tasks/completed — "
                "file it in the standing arc 'risk' (arc_id: risk) or correct the id")
    membership = task_arc_membership(path)
    arc_id, slugs = membership if membership is not None else (None, [])
    slug, numeric = arc_identities(project_root, RISK_ARC)
    accepted = {RISK_ARC, RISK_ARC_NUMERIC, (slug or "").lower(), (numeric or "").lower()} - {""}
    if (arc_id or "").lower() in accepted or any(t.lower() in accepted for t in slugs):
        return None
    return (f"{rid}: mitigation_task {tid} is not in the standing arc 'risk' "
            f"(arc_id: {arc_id or 'none'}) — set arc_id: risk on {tid}")


def validate_risk(entry: Dict[str, Any],
                  project_root: Optional[str] = None) -> Tuple[List[str], List[str]]:
    """Return (errors, warnings) for one `type: risk` entry.

    With `project_root`, a well-formed `mitigation_task` is also resolved
    against that project's .tasks/ and its arc checked (T-5314)."""
    rid = entry.get("id", "(no id)")
    errors: List[str] = []
    warnings: List[str] = []

    score = _check_pair(rid, entry, "likelihood", "impact", "score", errors, False)
    if "ranking" in entry and score is not None:
        expected = band(score)
        if entry["ranking"] in ("low", "medium", "high") and entry["ranking"] != expected:
            errors.append(f"{rid}: ranking {entry['ranking']!r} does not match score {score} (band {expected})")

    worst_actor = 0
    actors = entry.get("actors")
    if actors is not None:
        if not isinstance(actors, list):
            errors.append(f"{rid}: actors must be a list")
        else:
            for n, a in enumerate(actors, 1):
                where = f"{rid} actors[{n}]"
                if not isinstance(a, dict):
                    errors.append(f"{where}: must be a mapping")
                    continue
                name = a.get("actor")
                if name not in ACTORS:
                    errors.append(f"{where}: actor {name!r} is not one of {', '.join(ACTORS)}")
                s = _check_pair(where, a, "likelihood", "impact", "score", errors, True)
                _check_pair(where, a, "mitigated_likelihood", "mitigated_impact",
                            "mitigated_score", errors, False)
                if s is not None:
                    worst_actor = max(worst_actor, s)

    for key in ("introduced_by", "mitigation_task"):
        v = entry.get(key)
        if v is not None and not (isinstance(v, str) and _TASK_RE.match(v)):
            errors.append(f"{rid}: {key} must be a task id (T-NNNN), got {v!r}")
    if "exists_anyway" in entry and not isinstance(entry["exists_anyway"], bool):
        errors.append(f"{rid}: exists_anyway must be true or false, got {entry['exists_anyway']!r}")

    assessed = any(k in entry for k in NEW_FIELDS)
    is_open = str(entry.get("status", "")).lower() not in CLOSED_STATUSES
    top = max(score or 0, worst_actor)
    if assessed and is_open and top >= MITIGATION_THRESHOLD and not entry.get("mitigation_task"):
        warnings.append(
            f"{rid}: score {top} >= {MITIGATION_THRESHOLD} and no mitigation_task — "
            "file one in the standing arc 'risk' (arc_id: risk)")
    mt = entry.get("mitigation_task")
    if project_root and isinstance(mt, str) and _TASK_RE.match(mt):
        w = check_mitigation_task(rid, mt, project_root)
        if w:
            warnings.append(w)
    return errors, warnings


def validate_register(data: Any,
                      project_root: Optional[str] = None) -> Tuple[List[str], List[str], int]:
    """Validate every risk entry. Return (errors, warnings, risk_count)."""
    if not isinstance(data, dict):
        return ["register is not a mapping"], [], 0
    items = data.get("concerns", data.get("gaps", [])) or []
    errors: List[str] = []
    warnings: List[str] = []
    count = 0
    for entry in items:
        if not isinstance(entry, dict) or entry.get("type") != "risk":
            continue
        count += 1
        e, w = validate_risk(entry, project_root)
        errors.extend(e)
        warnings.extend(w)
    return errors, warnings, count


# ── Matrix mode (T-5315) ─────────────────────────────────────────────────────

ACCEPTANCE_THRESHOLD = 6      # introduced risk still at 6+ after mitigation
HIGH_THRESHOLD = 15           # any risk at 15+ (band "high")
_RISK_HEAD_RE = re.compile(r"^#{2,4}\s+Risk\s+(\d+)\b", re.IGNORECASE)
_PRODUCT_RE = re.compile(r"^\s*(\d+)\s*[x×*]\s*(\d+)\s*$", re.IGNORECASE)
_PRODUCTS = {a * b for a in range(1, 6) for b in range(1, 6)}


def _cells(line: str) -> Optional[List[str]]:
    s = line.strip()
    if not s.startswith("|"):
        return None
    s = s[1:]
    if s.endswith("|"):
        s = s[:-1]
    return [c.strip() for c in s.split("|")]


def _is_rule(cells: List[str]) -> bool:
    return any(cells) and all(re.fullmatch(r":?-{2,}:?", c) for c in cells if c)


def _tables(lines: List[str]) -> List[Tuple[int, List[str], List[Tuple[int, List[str]]]]]:
    """Every markdown table: (header line index, lower-cased header cells, [(line no, cells)])."""
    out = []
    i = 0
    while i < len(lines):
        head = _cells(lines[i])
        rule = _cells(lines[i + 1]) if i + 1 < len(lines) else None
        if head and rule and _is_rule(rule):
            rows = []
            j = i + 2
            while j < len(lines) and _cells(lines[j]) is not None:
                rows.append((j + 1, _cells(lines[j])))
                j += 1
            out.append((i, [h.lower() for h in head], rows))
            i = j
        else:
            i += 1
    return out


def _col(header: List[str], name: str, exact: bool = False) -> Optional[int]:
    for n, h in enumerate(header):
        if (h == name) if exact else h.startswith(name):
            return n
    return None


def _get(row: List[str], idx: Optional[int]) -> str:
    return row[idx] if idx is not None and idx < len(row) else ""


def _scale(where: str, label: str, raw: str, errors: List[str]) -> Optional[int]:
    if raw == "":
        return None
    if re.fullmatch(r"\d+", raw) and 1 <= int(raw) <= 5:
        return int(raw)
    errors.append(f"{where}: {label} must be an integer 1-5, got {raw!r}")
    return None


def _introduced(raw: str) -> Optional[str]:
    """'NEW' / 'PARTLY NEW' when the change introduces the risk, else None."""
    v = raw.strip().strip("*").strip().lower()
    if v.startswith("partly new"):
        return "PARTLY NEW"
    if v.startswith("new"):
        return "NEW"
    return None


def _actor_rows(rn: int, header: List[str], rows, errors: List[str]) -> List[Dict[str, Any]]:
    c_actor = _col(header, "actor", exact=True)
    c_l, c_i = _col(header, "l", exact=True), _col(header, "i", exact=True)
    c_s = _col(header, "score", exact=True)
    c_ml, c_ms = _col(header, "mitigated l"), _col(header, "mitigated score")
    c_intro = _col(header, "introduced")           # T-5334: optional yes/no per row
    filled = []
    for ln, row in rows:
        raw = {k: _get(row, c) for k, c in
               (("l", c_l), ("i", c_i), ("s", c_s), ("ml", c_ml), ("ms", c_ms))}
        if not any(raw.values()):
            continue                              # blank template row
        name = _get(row, c_actor).strip("` ")
        where = f"line {ln} (risk {rn}, {name or 'no actor'})"
        if name not in ACTORS:
            errors.append(f"{where}: actor {name!r} is not one of {', '.join(ACTORS)}")
        lv = _scale(where, "L", raw["l"], errors)
        iv = _scale(where, "I", raw["i"], errors)
        score = None
        if raw["l"] == "" or raw["i"] == "":
            errors.append(f"{where}: needs both L and I")
        elif lv is not None and iv is not None:
            score = lv * iv
            if raw["s"] and raw["s"] != str(score):
                errors.append(f"{where}: score {raw['s']!r} is not L x I = {score}")
        mitigated = None
        if raw["ml"]:
            m = _PRODUCT_RE.match(raw["ml"])
            if not m:
                errors.append(f"{where}: mitigated L x I must read like '2 x 3', got {raw['ml']!r}")
            else:
                ml = _scale(where, "mitigated L", m.group(1), errors)
                mi = _scale(where, "mitigated I", m.group(2), errors)
                if ml is not None and mi is not None:
                    mitigated = ml * mi
                    if raw["ms"] and raw["ms"] != str(mitigated):
                        errors.append(f"{where}: mitigated score {raw['ms']!r} is not "
                                      f"mitigated L x I = {mitigated}")
        elif raw["ms"]:
            if re.fullmatch(r"\d+", raw["ms"]) and int(raw["ms"]) in _PRODUCTS:
                mitigated = int(raw["ms"])
            else:
                errors.append(f"{where}: mitigated score {raw['ms']!r} is not an L x I product (1-25)")
        if mitigated is None:
            mitigated = score                     # no mitigation given: the risk stands
        row_intro = None
        if c_intro is not None:
            v = _get(row, c_intro).strip("*` ").lower()
            if v in ("yes", "no"):
                row_intro = v == "yes"
            else:
                errors.append(f"{where}: introduced must be yes or no, got {_get(row, c_intro)!r}")
        filled.append({"actor": name, "score": score, "mitigated": mitigated,
                       "introduced": row_intro})
    return filled


def parse_matrix(text: str) -> Dict[str, Any]:
    """Check a filled risk matrix. Return {risks, errors, needs_operator_acceptance}."""
    lines = text.splitlines()
    errors: List[str] = []
    summary: Dict[int, Dict[str, Any]] = {}
    actor_tables: Dict[int, List[Dict[str, Any]]] = {}
    intro_col: set = set()                        # risks whose actor table has "introduced"
    headings = [(n, int(m.group(1))) for n, l in enumerate(lines)
                for m in [_RISK_HEAD_RE.match(l.strip())] if m]

    for hidx, header, rows in _tables(lines):
        if _col(header, "actor", exact=True) is not None:
            above = [rn for n, rn in headings if n < hidx]
            if not above:
                errors.append(f"line {hidx + 1}: actor table with no '### Risk N' heading above it")
                continue
            rn = above[-1]
            if _col(header, "introduced") is not None:
                intro_col.add(rn)
            actor_tables.setdefault(rn, []).extend(_actor_rows(rn, header, rows, errors))
        elif _col(header, "risk", exact=True) is not None and _col(header, "introduced") is not None:
            c_n, c_risk = _col(header, "#", exact=True), _col(header, "risk", exact=True)
            c_l, c_i = _col(header, "likelihood"), _col(header, "impact")
            c_s, c_int = _col(header, "score", exact=True), _col(header, "introduced")
            for ln, row in rows:
                name = _get(row, c_risk)
                rl, ri, rs = _get(row, c_l), _get(row, c_i), _get(row, c_s)
                if not (name or rl or ri or rs):
                    continue                      # blank template row
                num = _get(row, c_n)
                if not re.fullmatch(r"\d+", num):
                    errors.append(f"line {ln}: summary row needs a risk number in '#', got {num!r}")
                    continue
                rn = int(num)
                where = f"line {ln} (summary risk {rn})"
                lv = _scale(where, "likelihood", rl, errors)
                iv = _scale(where, "impact", ri, errors)
                if (rl == "") != (ri == ""):
                    errors.append(f"{where}: likelihood and impact must be given together")
                score = lv * iv if lv is not None and iv is not None else None
                if score is not None and rs and rs != str(score):
                    errors.append(f"{where}: score {rs!r} is not likelihood x impact = {score}")
                summary[rn] = {"name": name, "score": score,
                               "introduced": _introduced(_get(row, c_int))}

    for rn in sorted(summary):
        if not actor_tables.get(rn):
            errors.append(f"summary risk {rn} ({summary[rn]['name'] or 'unnamed'}) has no filled "
                          f"'### Risk {rn}' actor table")
    for rn in sorted(actor_tables):
        if actor_tables[rn] and rn not in summary:
            errors.append(f"actor table for risk {rn} has no row in the Summary table")

    risks: List[Dict[str, Any]] = []
    needs: List[Dict[str, Any]] = []
    for rn in sorted(summary):
        s = summary[rn]
        acts = actor_tables.get(rn, [])
        scores = [a["score"] for a in acts if a["score"] is not None]
        if s["score"] is not None:
            scores.append(s["score"])
        mits = [a["mitigated"] for a in acts if a["mitigated"] is not None]
        worst = max(scores) if scores else None
        worst_mit = max(mits) if mits else None
        rec = {"risk": rn, "name": s["name"], "introduced": s["introduced"],
               "worst_score": worst, "worst_band": band(worst) if worst else None,
               "worst_mitigated": worst_mit,
               "mitigated_band": band(worst_mit) if worst_mit else None}
        accept_mit, accept_what = worst_mit, ""
        if s["introduced"] == "PARTLY NEW" and rn in intro_col:
            # T-5334: only the rows the change adds count toward acceptance.
            intro_mits = [a["mitigated"] for a in acts
                          if a.get("introduced") is True and a["mitigated"] is not None]
            accept_mit = max(intro_mits) if intro_mits else None
            rec["introduced_mitigated"] = accept_mit
            accept_what = " (introduced rows)"
            if not any(a.get("introduced") is True for a in acts):
                errors.append(f"PARTLY NEW risk {rn} names no introduced actor row")
        risks.append(rec)
        reasons = []
        if s["introduced"] and accept_mit is not None and accept_mit >= ACCEPTANCE_THRESHOLD:
            reasons.append(f"{s['introduced']} and still {accept_mit}{accept_what} after mitigation")
        if worst is not None and worst >= HIGH_THRESHOLD:
            reasons.append(f"scores {worst} (high)")
        if reasons:
            needs.append({**rec, "reasons": reasons})
    return {"risks": risks, "errors": errors, "needs_operator_acceptance": needs}


def matrix_main(path: str, as_json: bool) -> int:
    try:
        with open(path, encoding="utf-8") as f:
            text = f.read()
    except OSError as exc:
        print(f"cannot read {path}: {exc}", file=sys.stderr)
        return 2
    res = parse_matrix(text)
    if as_json:
        print(json.dumps(res))
    else:
        for e in res["errors"]:
            print(f"ERROR {e}")
        print(f"{len(res['risks'])} risk(s), {len(res['errors'])} error(s)")
        if res["needs_operator_acceptance"]:
            print("needs operator acceptance:")
            for r in res["needs_operator_acceptance"]:
                print(f"  risk {r['risk']} — {r['name']}: {'; '.join(r['reasons'])}")
        else:
            print("needs operator acceptance: none")
    return 1 if res["errors"] else 0


def _default_path() -> str:
    root = os.environ.get("PROJECT_ROOT") or os.getcwd()
    return os.path.join(root, ".context", "project", "concerns.yaml")


def _root_for(path: str) -> str:
    """Project root for a register path: three levels up from
    .context/project/concerns.yaml, else PROJECT_ROOT or cwd."""
    parts = os.path.abspath(path).split(os.sep)
    if len(parts) >= 3 and parts[-3:-1] == [".context", "project"]:
        return os.sep.join(parts[:-3]) or os.sep
    return os.environ.get("PROJECT_ROOT") or os.getcwd()


def main(argv: Optional[List[str]] = None) -> int:
    ap = argparse.ArgumentParser(description="Validate risk fields in the concerns register (T-5313)")
    ap.add_argument("--path", default=None)
    ap.add_argument("--root", default=None,
                    help="project root whose .tasks/ resolves mitigation_task")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--matrix", default=None,
                    help="check a filled risk matrix file instead of the register (T-5315)")
    args = ap.parse_args(argv)
    if args.matrix:
        return matrix_main(args.matrix, args.json)
    path = args.path or _default_path()
    try:
        import yaml
        with open(path) as f:
            data = yaml.safe_load(f)
    except FileNotFoundError:
        print(f"no concerns register at {path}", file=sys.stderr)
        return 2
    except Exception as exc:  # unreadable or unparseable
        print(f"cannot read {path}: {exc}", file=sys.stderr)
        return 2
    errors, warnings, count = validate_register(data, args.root or _root_for(path))
    if args.json:
        print(json.dumps({"risks": count, "errors": errors, "warnings": warnings}))
    else:
        for e in errors:
            print(f"ERROR {e}")
        for w in warnings:
            print(f"WARN  {w}")
        print(f"{count} risk(s), {len(errors)} error(s), {len(warnings)} warning(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
