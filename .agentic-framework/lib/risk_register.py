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
    args = ap.parse_args(argv)
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
