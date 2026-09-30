#!/usr/bin/env python3
"""review_policy.py — the ONE place the IW-7 review strength is computed (T-3580 round 6).

`fw reviewer judge` (lib/reviewer/judge_cli.py) uses it to pick the rung it dispatches, and the
verdict ledger (lib/verdict_ledger.py) uses the SAME functions to decide which rung a green must
have to count, at `record` and at every `apply`. Before round 6 the rung lived only in the judge,
so a review dispatch could record a green with a lower `--rung` and no run and the ledger ticked
it (second-family review, HIGH: docs/reports/T-3580-second-family-codex.md).

IW-7 (docs/reports/T-3557-agent-reviewer-default.md): impact = max(cost_if_wrong, value_at_stake)
over reversibility, blast radius, audience, value and uncertainty. low -> rung 1 (same-vendor
independent agent), medium -> rung 3 (one TermLink-dispatched reviewer), high -> rung 5 (panel of
three vendors). The weekly spend ceiling may drop the rung one step; that step-down is a
DECISION recorded in the signed review run (`ceiling_decision`) and re-verified by the ledger
(`verify_ceiling_decision`), never a free-text claim.

Impact is monotonic in the criteria it reads: adding criteria can only raise the tier. So the
judge, which scores all the criteria it dispatches together, never asks for less than the ledger
demands for any one of them.
"""

from __future__ import annotations

import json
import os
import re
from datetime import datetime, timedelta, timezone
from pathlib import Path

SPEND_LOG = Path(".context/working/judge-spend.jsonl")
CEILING_KEY = "REVIEWER_JUDGE_WEEKLY_SPEND_CEILING"
DEFAULT_CEILING = 10000.0
#: Estimated USD per dispatched reviewer, by rung. A panel is three seats.
RUNG_COST = {1: 2.0, 2: 2.0, 3: 3.0, 5: 6.0}
#: IW-7: a rung-5 panel is three reviewers from three different vendors.
PANEL_SIZE = 3
TIER_RUNG = {"low": 1, "medium": 3, "high": 5}
_TS = "%Y-%m-%dT%H:%M:%SZ"

_IRREVERSIBLE_RE = re.compile(
    r"\b(publish(?:es|ed|ing)?|deploy(?:s|ed|ing)?|production|credential[s]?|secret[s]?|payment|"
    r"drop\s+table|force[- ]push|delete[sd]?\s+(?:data|branch))\b", re.I)
_CONSUMER_PATH_RE = re.compile(r"(?:^|[\s`'\"(])((?:lib|agents|policy|web|seeds)/[\w./-]+|bin/fw)\b")
_CROSS_PROJECT_RE = re.compile(r"\b(cross[- ]project|peer projects?|consumer projects?|other projects?|external users?)\b", re.I)
_CONSUMER_RE = re.compile(r"\b(consumers?|fw upgrade|vendored|install surface)\b", re.I)
_SECURITY_RE = re.compile(r"\b(security|vulnerab\w*|auth(?:entication|orization)?|sandbox)\b", re.I)
_OBJECTIVE_RE = re.compile(r"\bproject[- ]objectives?\b", re.I)
_RUNG_RE = re.compile(r"^rung-(\d+)\b")


def impact(fm: dict, bodies: list[str]) -> dict:
    """IW-7 impact = max(cost_if_wrong, value_at_stake). Returns {'tier', 'inputs', 'reasons'}
    where inputs records what each axis saw, so the selection is auditable."""
    fm = fm or {}
    crit_text = "\n".join(b or "" for b in (bodies or []))
    # What the change is ABOUT (title, description, the criteria under review) - not the whole
    # task body, which mentions "consumers" and "security" in passing on almost every task.
    scan = f"{fm.get('name', '')}\n{fm.get('description', '')}\n{crit_text}"
    ce = fm.get("cost_estimate") or {}
    blast = ce.get("blast_radius") if isinstance(ce, dict) else None
    comps = fm.get("components") or []
    comps = comps if isinstance(comps, list) else [comps]
    paths = sorted({m for m in _CONSUMER_PATH_RE.findall(scan)} | {str(c) for c in comps
                    if re.match(r"(lib|agents|policy|web|seeds)/|bin/fw", str(c))})
    bvp = fm.get("bvp_scores") or {}
    bvp = bvp if isinstance(bvp, dict) else {}
    voi = fm.get("voi_score")
    conf = fm.get("iw_confidence", fm.get("confidence"))
    tags = [str(t).lower() for t in (fm.get("tags") or [])] if isinstance(fm.get("tags"), list) else []
    inputs = {
        "reversibility": "leaves-repo" if _IRREVERSIBLE_RE.search(scan) else "git-only",
        "blast_radius": blast, "components": len(comps), "consumer_paths": paths[:6],
        "audience": ("cross-project" if _CROSS_PROJECT_RE.search(scan)
                     else "consumers" if (paths or _CONSUMER_RE.search(scan)) else "internal"),
        "value": {"bvp": {k: bvp.get(k) for k in ("D1", "D2") if k in bvp}, "voi_score": voi,
                  "project_objective": bool(_OBJECTIVE_RE.search(scan) or "objective" in tags)},
        "uncertainty": {"confidence": conf,
                        "inception": str(fm.get("workflow_type")) == "inception"},
        "security": bool(_SECURITY_RE.search(scan) or "security" in tags),
    }
    high, medium = [], []
    if isinstance(blast, (int, float)) and blast > 5:
        high.append(f"blast_radius={blast}")
    elif isinstance(blast, (int, float)) and blast >= 3:
        medium.append(f"blast_radius={blast}")
    if len(comps) >= 5:
        high.append(f"components={len(comps)}")
    if isinstance(voi, (int, float)) and voi >= 0.6:
        high.append(f"voi_score={voi}")
    if bvp and ((bvp.get("D1") or 0) > 3 or (bvp.get("D2") or 0) > 3):
        high.append("D1/D2 > 3")
    if inputs["value"]["project_objective"]:
        high.append("project objective")
    if inputs["security"]:
        high.append("security")
    if inputs["audience"] == "cross-project":
        high.append("cross-project audience")
    if inputs["reversibility"] == "leaves-repo":
        high.append("not undone by git revert")
    if isinstance(conf, (int, float)) and conf <= 1:
        high.append(f"confidence={conf}")
    if inputs["audience"] == "consumers":
        medium.append("consumer-facing code (" + (paths[0] if paths else "consumer text") + ")"
                      " [held at medium: IW-7's blast-radius row would count the install surface "
                      "high; see T-3580 Decisions]")
    if inputs["uncertainty"]["inception"]:
        medium.append("inception GO")
    if len(comps) >= 3:
        medium.append(f"components={len(comps)}")
    tier = "high" if high else "medium" if medium else "low"
    return {"tier": tier, "inputs": inputs, "reasons": high if high else medium}


def required_rung(fm: dict, bodies: list[str]) -> tuple[int, str]:
    """(rung, reason) IW-7 demands for these criteria of a task with frontmatter `fm`."""
    imp = impact(fm, bodies)
    return TIER_RUNG[imp["tier"]], "; ".join(imp["reasons"]) if imp["reasons"] else "default"


def rung_label(rung: int, seat: str = "") -> str:
    base = ("rung-1-same-vendor-independent" if rung <= 1 else
            "rung-2-same-vendor-independent" if rung == 2 else
            "rung-3-termlink-single-reviewer" if rung <= 4 else "rung-5-panel")
    return f"{base}:{seat}" if seat else base


def rung_number(label) -> int | None:
    """The rung a label claims (`rung-5-panel:seat` -> 5); None when it names no rung."""
    m = _RUNG_RE.match(str(label or "").strip())
    return int(m.group(1)) if m else None


def step_down(rung: int) -> int:
    return 3 if rung >= 5 else 1


# ── the weekly spend ceiling ─────────────────────────────────────────────────


def config_value(root: Path, key: str, default: str) -> str:
    env = os.environ.get(f"FW_{key}")
    if env:
        return env
    try:
        import yaml

        data = yaml.safe_load((Path(root) / ".framework.yaml").read_text()) or {}
        for scope in (data, data.get("config") or {}):
            if isinstance(scope, dict) and scope.get(key) not in (None, ""):
                return str(scope[key])
    except Exception:
        pass
    return default


def ceiling(root: Path) -> float:
    try:
        return float(config_value(root, CEILING_KEY, str(DEFAULT_CEILING)))
    except ValueError:
        return DEFAULT_CEILING


def _spend_lines(root: Path) -> list[str]:
    p = Path(root) / SPEND_LOG
    try:
        return p.read_text().splitlines()
    except OSError:
        return []


def _spent(lines: list[str], now: datetime) -> float:
    since = now - timedelta(days=7)
    total = 0.0
    for line in lines:
        try:
            r = json.loads(line)
            ts = datetime.strptime(r["ts"], _TS).replace(tzinfo=timezone.utc)
            if since <= ts <= now:
                total += float(r.get("cost", 0))
        except Exception:
            continue
    return total


def weekly_spend(root: Path, now: datetime | None = None) -> float:
    return _spent(_spend_lines(root), now or datetime.now(timezone.utc))


def apply_ceiling(rung: int, reason: str, spent: float, ceil: float) -> tuple[int, str, str]:
    """Drop one rung (5 -> 3 -> 1) when the due rung would take the week past the ceiling.
    Returns (rung, reason, note); note is '' when nothing was dropped."""
    if spent + RUNG_COST.get(rung, 2.0) <= ceil:
        return rung, reason, ""
    lower = step_down(rung)
    if lower == rung or rung <= 1:
        note = (f"weekly spend ceiling reached (spent {spent:g} of {ceil:g}); rung {rung} is "
                f"already the lowest, so it runs at rung {rung} and is not skipped")
        return rung, reason, note
    note = (f"reviewed at rung {lower}, weekly spend ceiling reached (spent {spent:g} of "
            f"{ceil:g}); rung {rung} was due")
    return lower, reason, note


def ceiling_decision(root: Path, due: int, reason: str = "", now: datetime | None = None) -> dict:
    """The judge's rung decision, in a form the ledger can re-derive: the due rung, the granted
    one, and exactly which spend-log lines and clock the spend was computed from."""
    now = (now or datetime.now(timezone.utc)).replace(microsecond=0)
    lines = _spend_lines(root)
    spent, ceil = _spent(lines, now), ceiling(root)
    granted, _r, note = apply_ceiling(due, reason, spent, ceil)
    return {"due": int(due), "granted": int(granted), "spent": spent, "ceiling": ceil,
            "cost": RUNG_COST.get(due, 2.0), "as_of": now.strftime(_TS),
            "spend_lines": len(lines), "note": note}


def verify_ceiling_decision(root: Path, dec) -> str:
    """'' when `dec` (a run's recorded ceiling decision) re-derives: the spend recomputed from the
    same spend-log lines at the same clock, run through `apply_ceiling` with the ceiling configured
    NOW, grants exactly the recorded rung. Else why not. A raised ceiling therefore withdraws a
    step-down: the review is again owed at full strength."""
    if not isinstance(dec, dict):
        return "the run records no ceiling decision"
    try:
        due, granted, n = int(dec["due"]), int(dec["granted"]), int(dec["spend_lines"])
        now = datetime.strptime(str(dec["as_of"]), _TS).replace(tzinfo=timezone.utc)
    except (KeyError, TypeError, ValueError):
        return "the ceiling decision is malformed"
    lines = _spend_lines(root)
    if n > len(lines):
        return (f"the ceiling decision cites {n} spend-log lines; the log has {len(lines)} — the "
                f"spend it was based on is gone")
    spent = _spent(lines[:n], now)
    if abs(spent - float(dec.get("spent", -1))) > 1e-6:
        return f"the ceiling decision records spend {dec.get('spent')}, the spend log says {spent:g}"
    ceil = ceiling(root)
    got, _r, _n = apply_ceiling(due, "", spent, ceil)
    if got != granted:
        return (f"with spend {spent:g} and the configured ceiling {ceil:g}, rung {due} is granted "
                f"{got}, not the recorded {granted}")
    return ""
