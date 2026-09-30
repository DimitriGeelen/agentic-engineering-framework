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
DECISION the ledger computes when it registers the review run (round 7), from the committed cost
ledger, and re-verifies (`verify_ceiling_decision`) at record and apply — never a caller's claim.

Impact is monotonic in the criteria it reads: adding criteria can only raise the tier. So the
judge, which scores all the criteria it dispatches together, never asks for less than the ledger
demands for any one of them.
"""

from __future__ import annotations

import json
import math
import os
import re
import subprocess
from datetime import datetime, timedelta, timezone
from pathlib import Path

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
#
# Round 7 (T-3580; codex HIGH-1 / MEDIUM-2, Claude F1). The step-down is a lever that takes a
# high-impact criterion from rung 5 to rung 3, so every input to it is pinned:
#   * the decision is computed BY THE LEDGER AT REGISTRATION (verdict_ledger.register_run), as of
#     the run's own signed registration time; `verify_ceiling_decision` refuses a decision whose
#     clock is not its run's, so no new run can reuse an old one;
#   * spend comes from the COMMITTED cost ledger (.context/costs/reviews.jsonl at a commit that is
#     an ancestor of HEAD, append-only against git), never from an untracked working file;
#   * ceiling and spend must be finite and >= 0, and the ceiling must be at least CEILING_FLOOR.
#     Anything else — NaN, infinity, negative, malformed, below the floor — means NO step-down.

COST_LEDGER = Path(".context/costs/reviews.jsonl")
#: Cost-ledger purpose prefix of a judge-dispatched seat (judge_cli.COST_PURPOSE).
SPEND_PURPOSE = "reviewer-judge"
CEILING_KEY = "REVIEWER_JUDGE_WEEKLY_SPEND_CEILING"
DEFAULT_CEILING = 10000.0
#: Estimated USD per dispatched reviewer run, by rung. A panel is three seats.
RUNG_COST = {1: 2.0, 2: 2.0, 3: 3.0, 5: 6.0}
#: The lowest ceiling that can step anything down, in the cost ledger's unit (estimated USD, the
#: unit of RUNG_COST). 100 USD funds sixteen rung-5 panels a week; a ceiling below it cannot be a
#: budget for the reviews IW-7 asks for, only a switch that turns every high-impact review into a
#: rung-3 one — so a ceiling below the floor (0 and negatives included) means "no step-down".
CEILING_FLOOR = 100.0


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


def _money(v, *, number: bool = False) -> float | None:
    """A finite, non-negative amount; None for anything else (NaN, inf, negative, bool, garbage).
    `number=True` (recorded values: cost-ledger rows, a decision's spend) also refuses text."""
    if isinstance(v, bool) or (number and not isinstance(v, (int, float))):
        return None
    try:
        f = float(v)
    except (TypeError, ValueError, OverflowError):   # round 8 (codex 4): float(10**400) overflows
        return None
    return f if math.isfinite(f) and f >= 0 else None


def ceiling_status(root: Path) -> tuple[float | None, str]:
    """(ceiling, '') when the configured ceiling can step a rung down; (None, why) when it cannot."""
    raw = config_value(root, CEILING_KEY, str(DEFAULT_CEILING))
    c = _money(raw)
    if c is None:
        return None, f"ceiling {raw!r} is not a finite amount >= 0"
    if c < CEILING_FLOOR:
        return None, f"ceiling {c:g} is below the floor {CEILING_FLOOR:g}"
    return c, ""


def ceiling(root: Path) -> float | None:
    return ceiling_status(root)[0]


def _git(root: Path, *args: str) -> tuple[int, str]:
    try:
        p = subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.SubprocessError):
        return 128, ""
    return p.returncode, p.stdout


def _committed_lines(root: Path, rev: str) -> tuple[list[str] | None, str]:
    """The cost ledger's non-blank lines as committed at `rev`; ([], '') when it was not there."""
    rc, blob = _git(root, "show", f"{rev}:{COST_LEDGER}")
    if rc != 0:
        rc2, _ = _git(root, "rev-parse", "-q", "--verify", f"{rev}^{{commit}}")
        return ([], "") if rc2 == 0 else (None, f"revision {rev[:9]!r} is not a commit")
    return [ln for ln in blob.splitlines() if ln.strip()], ""


#: The purpose `fw reviewer judge` logs for a dispatched seat (judge_cli._log_seat_cost).
_JUDGE_ROW_RE = re.compile(r"^reviewer-judge (\S+) seat (\S+) dispatch (\S+)$")


def _judge_row_cost(root: Path, r: dict, amount: float) -> tuple[float, str]:
    """(round 8, Claude N4) What one committed judge cost row contributes to the weekly spend:
    its amount only when it names a SIGNED review run and a SIGNED dispatch registered for that
    run's seat, for the row's task, that the dispatch runtime actually STARTED — capped at that
    run's per-seat cost (RUNG_COST of the run's rung, split over a panel). Anything else counts
    0: a free-text `reviewer-judge ...` row (any purpose, any --cost, via `fw review cost log`)
    is not evidence that a review was paid for, so it cannot push a rung down. Returns
    (counted, dispatch id or '' when it does not count)."""
    from lib import verdict_ledger as vl  # lazy: verdict_ledger imports this module

    m = _JUDGE_ROW_RE.match(str(r.get("purpose") or "").strip())
    if not m:
        return 0.0, ""
    run_id, seat, did = m.groups()
    run, _why = vl._verified_run(Path(root), run_id)
    drec, _why = vl.dispatch_record(Path(root), did)
    if run is None or drec is None:
        return 0.0, ""
    if (drec.get("run_id"), drec.get("seat")) != (run_id, seat) or run.get("task") != drec.get("task") \
            or str(r.get("task") or "") != str(run.get("task") or ""):
        return 0.0, ""
    starts = vl._starts_for(Path(root), did)
    if len(starts) != 1 or not vl._signed_ok(Path(root), starts[0]):
        return 0.0, ""
    rung = rung_number(run.get("rung")) or 1
    cap = RUNG_COST.get(rung, 2.0) / (PANEL_SIZE if rung >= 5 else 1)
    return min(amount, cap), did


def _spent(lines: list[str], now: datetime, root: Path | None = None) -> tuple[float | None, str]:
    """(estimated USD the judge spent in the 7 days up to `now`, '') from cost-ledger lines; (None,
    why) when a judge record in them is malformed — malformed spend refuses a step-down.
    Round 8 (N4): a judge row counts only as `_judge_row_cost` allows — bound to a signed, started
    run seat and capped — and each dispatch at most once."""
    since = now - timedelta(days=7)
    total = 0.0
    counted: set[str] = set()
    for n, line in enumerate(lines, 1):
        try:
            r = json.loads(line)
        except ValueError:
            return None, f"cost-ledger line {n} is not JSON"
        if not isinstance(r, dict) or not str(r.get("purpose") or "").startswith(SPEND_PURPOSE):
            continue
        try:
            ts = datetime.strptime(str(r.get("ts")), _TS).replace(tzinfo=timezone.utc)
        except ValueError:
            return None, f"cost-ledger line {n} has a malformed ts {r.get('ts')!r}"
        if not since <= ts <= now:
            continue
        if r.get("cost_amount") is None:
            continue                      # an unmetered seat adds nothing it can prove
        amt = _money(r.get("cost_amount"), number=True)
        if amt is None:
            return None, f"cost-ledger line {n} has cost_amount {r.get('cost_amount')!r}, not a finite amount >= 0"
        got, did = _judge_row_cost(root or Path("."), r, amt)
        if not did or did in counted:
            continue
        counted.add(did)
        total += got
        if not math.isfinite(total):          # round 8 (codex 4): an aggregate that overflows
            return None, "the weekly judge spend overflows — not a finite amount"
    return total, ""


def _ledger_fault(root: Path) -> str:
    from lib import verdict_ledger  # lazy: verdict_ledger imports this module
    return verdict_ledger.history_fault(Path(root), COST_LEDGER)


def weekly_spend(root: Path, now: datetime | None = None) -> float | None:
    """Judge spend over the last 7 days from the cost ledger as committed at HEAD; None when it
    cannot be established."""
    lines, _why = _committed_lines(root, "HEAD")
    if lines is None or _ledger_fault(root):
        return None
    return _spent(lines, now or datetime.now(timezone.utc), root)[0]


def apply_ceiling(rung: int, reason: str, spent, ceil) -> tuple[int, str, str]:
    """Drop one rung (5 -> 3 -> 1) when the due rung would take the week past the ceiling.
    Returns (rung, reason, note); note is '' when nothing was dropped. A spend or ceiling that is
    not a finite amount >= 0, or a ceiling below CEILING_FLOOR, never drops anything."""
    s, c = _money(spent), _money(ceil)
    if s is None or c is None or c < CEILING_FLOOR:
        return rung, reason, ""
    if s + RUNG_COST.get(rung, 2.0) <= c:
        return rung, reason, ""
    lower = step_down(rung)
    if lower == rung or rung <= 1:
        note = (f"weekly spend ceiling reached (spent {s:g} of {c:g}); rung {rung} is "
                f"already the lowest, so it runs at rung {rung} and is not skipped")
        return rung, reason, note
    note = (f"reviewed at rung {lower}, weekly spend ceiling reached (spent {s:g} of "
            f"{c:g}); rung {rung} was due")
    return lower, reason, note


def ceiling_decision(root: Path, due: int, reason: str = "", now: datetime | None = None) -> dict:
    """The rung decision for a run registered at `now`: the due rung, the granted one, and exactly
    which committed cost-ledger lines (commit + count) the spend was computed from. Called by
    `verdict_ledger.register_run` with the run's registration time; the judge calls it only to
    preview. Any fault in the inputs grants the due rung, with the fault in `why`."""
    now = (now or datetime.now(timezone.utc)).replace(microsecond=0)
    dec = {"due": int(due), "granted": int(due), "spent": None, "ceiling": None,
           "floor": CEILING_FLOOR, "cost": RUNG_COST.get(due, 2.0), "as_of": now.strftime(_TS),
           "ledger_rev": "", "spend_lines": 0, "note": "", "why": ""}
    ceil, why = ceiling_status(root)
    rc, head = _git(root, "rev-parse", "-q", "--verify", "HEAD")
    head = head.strip() if rc == 0 else ""
    lines, lwhy = _committed_lines(root, head) if head else (None, "the repository has no commit")
    spent, swhy = _spent(lines, now, root) if lines is not None else (None, lwhy)
    hist = _ledger_fault(root) if head else ""
    dec.update(ceiling=ceil, spent=spent, ledger_rev=head, spend_lines=len(lines or []))
    why = why or swhy or (f"cost ledger: {hist}" if hist else "")
    if why:
        dec["why"] = f"no step-down: {why}"
        return dec
    granted, _r, note = apply_ceiling(due, reason, spent, ceil)
    dec.update(granted=int(granted), note=note, why=note)
    return dec


def verify_ceiling_decision(root: Path, dec, run_ts: str = "") -> str:
    """'' when `dec` (the ceiling decision in a signed run registered at `run_ts`) re-derives: its
    clock IS the run's registration time; its cost-ledger commit is an ancestor of HEAD and the
    ledger is append-only against git; the spend recomputed from exactly those committed lines at
    that clock matches; and `apply_ceiling` with the ceiling configured NOW (finite, >= floor)
    grants exactly the recorded rung. Else why not. A raised ceiling therefore withdraws a
    step-down: the review is again owed at full strength."""
    if not isinstance(dec, dict):
        return "the run records no ceiling decision"
    try:
        due, granted, n = int(dec["due"]), int(dec["granted"]), int(dec["spend_lines"])
        now = datetime.strptime(str(dec["as_of"]), _TS).replace(tzinfo=timezone.utc)
        rev = str(dec["ledger_rev"])
    except (KeyError, TypeError, ValueError, OverflowError):
        return "the ceiling decision is malformed"
    recorded = _money(dec.get("spent"), number=True)
    if n < 0 or recorded is None or not re.fullmatch(r"[0-9a-f]{40}", rev):
        return "the ceiling decision is malformed (spend, line count or ledger commit)"
    if not run_ts or str(dec["as_of"]) != str(run_ts):
        return (f"the decision was computed as of {dec['as_of']}, not at its run's registration "
                f"({run_ts or 'unknown'}) — a run's step-down is decided when it is registered")
    if _git(root, "merge-base", "--is-ancestor", rev, "HEAD")[0] != 0:
        return f"its cost-ledger commit {rev[:9]} is not in this history"
    hist = _ledger_fault(root)
    if hist:
        return f"cost ledger: {hist}"
    lines, why = _committed_lines(root, rev)
    if lines is None:
        return why
    if len(lines) != n:
        return (f"the decision cites {n} committed cost-ledger lines at {rev[:9]}; that commit has "
                f"{len(lines)}")
    spent, why = _spent(lines, now, root)
    if spent is None:
        return why
    if abs(spent - recorded) > 1e-6:
        return f"the ceiling decision records spend {dec.get('spent')}, the cost ledger says {spent:g}"
    ceil, why = ceiling_status(root)
    if ceil is None:
        return f"the configured {why} — no step-down"
    got, _r, _n = apply_ceiling(due, "", spent, ceil)
    if got != granted:
        return (f"with spend {spent:g} and the configured ceiling {ceil:g}, rung {due} is granted "
                f"{got}, not the recorded {granted}")
    return ""


def is_step_down(dec) -> bool:
    try:
        return isinstance(dec, dict) and int(dec["granted"]) < int(dec["due"])
    except (KeyError, TypeError, ValueError):
        return False


def disclosure(dec) -> str:
    """'rung R granted, rung D due, <reason>' for a step-down; '' otherwise."""
    if not is_step_down(dec):
        return ""
    return (f"rung {dec['granted']} granted, rung {dec['due']} due, "
            f"{dec.get('note') or dec.get('why') or 'weekly spend ceiling'}")
