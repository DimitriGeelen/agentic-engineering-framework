#!/usr/bin/env python3
"""Review and dispatch cost: backend registry, cost ledger, paid-approval proposals.

T-3583 (operator ruling 2026-09-30) — every review or dispatch records its cost, internal
included; paid backends need an approved proposal first. Rebuilt in T-3586: the T-3583
version kept multi-line JSON in a `.jsonl` file, never enforced approval on logging,
let an agent approve its own proposal, and had no audit surface.

Files:
  policy/review-backends.yaml          the registry — operator-owned, extensible by DATA edit
  .context/costs/reviews.jsonl         one cost record per review/dispatch (JSON Lines)
  .context/costs/proposals.jsonl       paid-backend proposals: `proposed` / `approved` events
  .context/costs/registry-changes.jsonl  every registry mutation made through this module

The registry is the only vendor list: nothing here names a backend except PINNED_PAID,
which is a rule about one backend, not a list of backends to choose from. A backend
added to the YAML is picked up by every verb below with no code change.

Authority (operator, 2026-09-30: "OpenRouter is always paid, but those internal
subscriptions we can get extra"):
  - PINNED_PAID backends are `paid` + `approval_required: true`, always. A registry that
    says otherwise does not load, so nothing can be logged or dispatched against it.
  - Changing a backend's class or approval_required is an operator action: refused under
    CLAUDECODE=1 unless --i-am-human, and logged either way.
  - Adding an INTERNAL backend is allowed for an agent, and logged for the operator.
    Adding a paid one is an operator action (it is a class decision).
  - Approving a proposal is an operator action (refused under CLAUDECODE=1 unless
    --i-am-human).
"""
from __future__ import annotations

import argparse
import datetime as _dt
import json
import os
import re
import secrets
import sys
from pathlib import Path

import yaml

PINNED_PAID = ("openrouter",)
CLASSES = ("internal", "paid")
REQUIRED = ("id", "name", "harness_class", "cost_class", "approval_required", "cost_estimate_method")
ID_RE = re.compile(r"^[a-z0-9][a-z0-9-]*$")
#: T-3580 round 8: a pinned worker model name (an alias or full id: letters, digits, . _ : / -).
MODEL_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:/-]*$")
UNMETERED_SUB = "unmetered (subscription)"


class CostError(Exception):
    """A refusal. The message is shown to the caller as-is."""


# ── paths ────────────────────────────────────────────────────────────────────

def _roots() -> tuple[Path, Path]:
    fw = Path(os.environ.get("FRAMEWORK_ROOT") or Path(__file__).resolve().parent.parent)
    proj = Path(os.environ.get("PROJECT_ROOT") or Path.cwd())
    return proj, fw


def policy_path() -> Path:
    proj, fw = _roots()
    local = proj / "policy" / "review-backends.yaml"
    return local if local.is_file() else fw / "policy" / "review-backends.yaml"


def ledger(name: str) -> Path:
    return _roots()[0] / ".context" / "costs" / name


def _now() -> str:
    return _dt.datetime.now(_dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _is_agent() -> bool:
    return os.environ.get("CLAUDECODE") == "1"


def _append(path: Path, rec: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(rec, sort_keys=True) + "\n")


def read_jsonl(path: Path) -> tuple[list[dict], list[int]]:
    """Records plus the 1-based line numbers that did not parse as a JSON object."""
    recs, bad = [], []
    if not path.is_file():
        return recs, bad
    for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        try:
            obj = json.loads(line)
        except ValueError:
            bad.append(n)
            continue
        (recs.append(obj) if isinstance(obj, dict) else bad.append(n))
    return recs, bad


# ── registry ─────────────────────────────────────────────────────────────────

def validate(backends: object) -> list[str]:
    errs: list[str] = []
    if not isinstance(backends, list) or not backends:
        return ["registry has no `backends:` list"]
    seen = set()
    for i, b in enumerate(backends):
        if not isinstance(b, dict):
            errs.append(f"entry {i} is not a mapping")
            continue
        bid = b.get("id")
        for f in REQUIRED:
            if f not in b or b[f] in (None, ""):
                errs.append(f"{bid or f'entry {i}'}: missing `{f}`")
        if bid is not None and not ID_RE.match(str(bid)):
            errs.append(f"{bid}: id must match {ID_RE.pattern}")
        if bid in seen:
            errs.append(f"{bid}: duplicate id")
        seen.add(bid)
        cls = b.get("cost_class")
        if cls not in CLASSES:
            errs.append(f"{bid}: cost_class must be one of {CLASSES}, got {cls!r}")
        if not isinstance(b.get("approval_required"), bool):
            errs.append(f"{bid}: approval_required must be true/false")
        if cls == "paid" and b.get("approval_required") is not True:
            errs.append(f"{bid}: a paid backend must have approval_required: true")
        for pat in b.get("match") or []:
            try:
                re.compile(pat)
            except re.error as e:
                errs.append(f"{bid}: bad match regex {pat!r}: {e}")
        # T-3580 round 5: `worker_kind` + `vendor` are the ONE kind→vendor mapping the dispatcher
        # and the verdict ledger use. A kind needs a vendor; one kind never maps to two vendors.
        kind, vend = b.get("worker_kind"), b.get("vendor")
        if kind is not None and (not isinstance(kind, str) or not ID_RE.match(kind)):
            errs.append(f"{bid}: worker_kind must match {ID_RE.pattern}")
        if vend is not None and (not isinstance(vend, str) or not ID_RE.match(vend)):
            errs.append(f"{bid}: vendor must match {ID_RE.pattern}")
        if kind and not vend:
            errs.append(f"{bid}: worker_kind {kind!r} has no vendor")
        # T-3580 round 8 (N2): the ONE model a review worker of this kind is launched with. Absent
        # means the worker's own default; a review dispatch cannot choose another.
        mdl = b.get("model")
        if mdl is not None and (not isinstance(mdl, str) or not MODEL_RE.match(mdl)):
            errs.append(f"{bid}: model must match {MODEL_RE.pattern}")
    kv: dict = {}
    for b in backends:
        if isinstance(b, dict) and b.get("worker_kind") and b.get("vendor"):
            if kv.setdefault(b["worker_kind"], b["vendor"]) != b["vendor"]:
                errs.append(f"{b.get('id')}: worker_kind {b['worker_kind']!r} maps to two vendors "
                            f"({kv[b['worker_kind']]!r} and {b['vendor']!r})")
    for pid in PINNED_PAID:
        b = next((x for x in backends if isinstance(x, dict) and x.get("id") == pid), None)
        if b is None:
            errs.append(f"{pid}: pinned-paid backend is missing from the registry")
        elif b.get("cost_class") != "paid" or b.get("approval_required") is not True:
            errs.append(f"{pid}: is pinned paid + approval_required (operator ruling "
                        f"2026-09-30) and cannot be reclassified")
    return errs


def load_registry(path: Path | None = None) -> list[dict]:
    path = path or policy_path()
    if not path.is_file():
        raise CostError(f"backend registry not found: {path}")
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    backends = data.get("backends") if isinstance(data, dict) else None
    errs = validate(backends)
    if errs:
        raise CostError("backend registry is invalid — refusing:\n  " + "\n  ".join(errs)
                        + f"\n  ({path})")
    return backends  # type: ignore[return-value]


def worker_vendors(path: Path | None = None) -> dict[str, str]:
    """{worker kind: vendor} — the ONE mapping (T-3580 round 5). The dispatcher prints it
    (`fw termlink worker-kinds --vendors`) and the verdict ledger derives every review
    dispatch's vendor from it; free text never names a vendor."""
    return {b["worker_kind"]: b["vendor"] for b in load_registry(path)
            if b.get("worker_kind") and b.get("vendor")}


def worker_models(path: Path | None = None) -> dict[str, str]:
    """{worker kind: model} for the kinds whose registry entry pins one (T-3580 round 8). A review
    dispatch of that kind is launched with exactly that model; a kind with none uses its default."""
    return {b["worker_kind"]: b["model"] for b in load_registry(path)
            if b.get("worker_kind") and b.get("model")}


def get_backend(bid: str) -> dict:
    for b in load_registry():
        if b["id"] == bid:
            return b
    raise CostError(f"unknown backend id: {bid!r} — see `fw review list-backends`")


def _log_registry_change(action: str, backend: dict, *, before: dict | None, override: bool) -> None:
    _append(ledger("registry-changes.jsonl"), {
        "ts": _now(), "action": action, "id": backend["id"],
        "cost_class": backend["cost_class"], "approval_required": backend["approval_required"],
        "before": before,
        "by": ("human-override" if override else "agent") if _is_agent() else "human",
    })


def _yaml_scalar(v: object) -> str:
    return json.dumps(v) if isinstance(v, str) else ("true" if v is True else "false" if v is False else str(v))


def add_backend(*, bid: str, name: str, cost_class: str, harness_class: str,
                approval_required: bool | None, method: str, description: str,
                match: list[str], i_am_human: bool) -> dict:
    """Append a backend block to the registry. Text append, not a YAML re-dump, so the
    operator's comments survive."""
    backends = load_registry()
    if any(b["id"] == bid for b in backends):
        raise CostError(f"backend {bid!r} already exists — use `fw review backend set`")
    if cost_class == "paid" and _is_agent() and not i_am_human:
        raise CostError("adding a PAID backend is an operator action (a class decision) — "
                        "refused under CLAUDECODE=1. An agent may add an internal backend; "
                        "the operator passes --i-am-human.")
    if approval_required is None:
        approval_required = cost_class == "paid"
    new = {"id": bid, "name": name, "harness_class": harness_class, "cost_class": cost_class,
           "approval_required": approval_required, "cost_estimate_method": method,
           "description": description}
    if match:
        new["match"] = match
    errs = validate(backends + [new])
    if errs:
        raise CostError("refusing — the registry would be invalid:\n  " + "\n  ".join(errs))
    path = policy_path()
    lines = [f"\n  - id: {bid}"]
    for k in ("name", "harness_class", "cost_class", "approval_required", "cost_estimate_method", "description"):
        lines.append(f"    {k}: {_yaml_scalar(new[k])}")
    if match:
        lines.append("    match:")
        lines += [f"      - {_yaml_scalar(p)}" for p in match]
    text = path.read_text(encoding="utf-8").rstrip("\n") + "\n" + "\n".join(lines) + "\n"
    path.write_text(text, encoding="utf-8")
    load_registry(path)  # re-validate what is on disk
    _log_registry_change("add", new, before=None, override=i_am_human)
    return new


def set_backend(*, bid: str, cost_class: str | None, approval_required: bool | None,
                i_am_human: bool) -> dict:
    backends = load_registry()
    cur = next((b for b in backends if b["id"] == bid), None)
    if cur is None:
        raise CostError(f"unknown backend id: {bid!r}")
    if cost_class is None and approval_required is None:
        raise CostError("nothing to change: pass --class and/or --approval-required")
    if bid in PINNED_PAID and (cost_class not in (None, "paid") or approval_required is False):
        raise CostError(f"{bid} is pinned paid + approval_required (operator ruling "
                        f"2026-09-30) and cannot be reclassified — not even with --i-am-human")
    if _is_agent() and not i_am_human:
        raise CostError("changing a backend's class or approval_required is an operator action "
                        "— refused under CLAUDECODE=1. The operator passes --i-am-human.")
    after = dict(cur)
    if cost_class is not None:
        after["cost_class"] = cost_class
    if approval_required is not None:
        after["approval_required"] = approval_required
    errs = validate([after if b["id"] == bid else b for b in backends])
    if errs:
        raise CostError("refusing — the registry would be invalid:\n  " + "\n  ".join(errs))
    path = policy_path()
    out, inside = [], False
    for line in path.read_text(encoding="utf-8").splitlines(keepends=True):
        m = re.match(r"^  - id:\s*(\S+)", line)
        if m:
            inside = m.group(1).strip("\"'") == bid
        elif inside and re.match(r"^    cost_class:", line):
            line = f"    cost_class: {after['cost_class']}\n"
        elif inside and re.match(r"^    approval_required:", line):
            line = f"    approval_required: {_yaml_scalar(after['approval_required'])}\n"
        out.append(line)
    path.write_text("".join(out), encoding="utf-8")
    reread = next(b for b in load_registry(path) if b["id"] == bid)
    if (reread["cost_class"], reread["approval_required"]) != (after["cost_class"], after["approval_required"]):
        raise CostError(f"registry edit for {bid} did not take — check the block's layout in {path}")
    _log_registry_change("set", after, override=i_am_human,
                         before={"cost_class": cur["cost_class"], "approval_required": cur["approval_required"]})
    return after


# ── proposals ────────────────────────────────────────────────────────────────

def proposals() -> dict[str, dict]:
    """id -> merged proposal ({... , status: pending|approved})."""
    out: dict[str, dict] = {}
    for r in read_jsonl(ledger("proposals.jsonl"))[0]:
        pid, ev = r.get("id"), r.get("event")
        if ev == "proposed" and pid:
            out[pid] = {**r, "status": "pending"}
        elif ev == "approved" and pid in out:
            out[pid].update(status="approved", approved_ts=r.get("ts"), approved_by=r.get("by"),
                            approval_reason=r.get("reason"))
    return out


def _consumed() -> set[str]:
    return {r["proposal_id"] for r in read_jsonl(ledger("reviews.jsonl"))[0] if r.get("proposal_id")}


def open_approval(task: str, backend: str) -> dict | None:
    """An approved, not-yet-used proposal for this task and backend. Approval is per request:
    logging a cost record against a proposal consumes it."""
    used = _consumed()
    for p in proposals().values():
        if (p["status"] == "approved" and p.get("task") == task and p.get("backend") == backend
                and p["id"] not in used):
            return p
    return None


def propose(*, task: str, backend: str, why: str, est_cost: float | None, est_tokens: int | None) -> dict:
    b = get_backend(backend)
    if not b["approval_required"]:
        raise CostError(f"{backend} is {b['cost_class']} with no approval requirement — "
                        f"just log it: fw review cost log --task {task} --backend {backend} ...")
    if not why.strip():
        raise CostError("--why is required: state the value or risk that justifies the spend")
    rec = {"event": "proposed", "id": f"RP-{secrets.token_hex(4)}", "ts": _now(), "task": task,
           "backend": backend, "class": b["cost_class"], "why": why,
           "estimate_cost": est_cost, "estimate_tokens": est_tokens}
    _append(ledger("proposals.jsonl"), rec)
    return rec


def approve(*, pid: str, i_am_human: bool, reason: str) -> dict:
    if _is_agent() and not i_am_human:
        raise CostError("approving a paid proposal is an operator action — refused under "
                        "CLAUDECODE=1. Hand it to the operator (Watchtower /approvals or "
                        "their own terminal with --i-am-human).")
    p = proposals().get(pid)
    if p is None:
        raise CostError(f"no proposal {pid!r}")
    if p["status"] == "approved":
        raise CostError(f"{pid} is already approved")
    rec = {"event": "approved", "id": pid, "ts": _now(), "reason": reason,
           "by": ("human-override" if i_am_human else "agent") if _is_agent() else "human"}
    _append(ledger("proposals.jsonl"), rec)
    return rec


# ── cost records ─────────────────────────────────────────────────────────────

def log_cost(*, task: str, backend: str, purpose: str, tokens: int | None, cost: float | None,
             proposal_id: str | None, evidence: str | None) -> dict:
    if not re.match(r"^T-\d+$", task):
        raise CostError(f"--task must be a task id (T-NNN), got {task!r}")
    if not purpose.strip():
        raise CostError("--purpose is required")
    b = get_backend(backend)
    if b["approval_required"]:
        p = proposals().get(proposal_id or "")
        if not proposal_id or p is None:
            raise CostError(f"{backend} needs an approved proposal: "
                            f"fw review propose --task {task} --backend {backend} --why '...'"
                            f", then log with --proposal-id")
        if p["status"] != "approved" or p.get("task") != task or p.get("backend") != backend:
            raise CostError(f"{proposal_id} is not an approved proposal for {task} on {backend}")
        if proposal_id in _consumed():
            raise CostError(f"{proposal_id} was already used — approval is per request")
    metered = tokens is not None or cost is not None
    rec = {"ts": _now(), "task": task, "backend": backend, "class": b["cost_class"],
           "purpose": purpose, "tokens": tokens, "cost_amount": cost,
           "metering": "metered" if metered else (UNMETERED_SUB if b["harness_class"] == "subscription" else "unmetered"),
           "proposal_id": proposal_id, "evidence": evidence}
    _append(ledger("reviews.jsonl"), rec)
    return rec


def _week(ts: str) -> str:
    try:
        d = _dt.datetime.strptime(ts[:10], "%Y-%m-%d").date()
    except (TypeError, ValueError):
        return "unknown"
    y, w, _ = d.isocalendar()
    return f"{y}-W{w:02d}"


def weekly(recs: list[dict], weeks: int | None = None) -> list[tuple[str, str, str, int, int, float]]:
    """(week, backend, class, records, metered, cost_sum), newest week first."""
    agg: dict[tuple[str, str, str], list] = {}
    for r in recs:
        k = (_week(r.get("ts", "")), str(r.get("backend")), str(r.get("class")))
        a = agg.setdefault(k, [0, 0, 0.0])
        a[0] += 1
        if r.get("metering") == "metered" or r.get("cost_amount") is not None or r.get("tokens") is not None:
            a[1] += 1
        try:
            a[2] += float(r.get("cost_amount") or 0)
        except (TypeError, ValueError):
            pass
    keep = sorted({k[0] for k in agg}, reverse=True)[:weeks] if weeks else None
    rows = [(k[0], k[1], k[2], v[0], v[1], v[2]) for k, v in agg.items() if keep is None or k[0] in keep]
    return sorted(rows, key=lambda r: (-int(r[0].replace("-W", "")) if r[0] != "unknown" else 0, r[1]))


def unapproved_paid(recs: list[dict]) -> list[dict]:
    """Paid-class cost records with no approved proposal for the same task and backend."""
    props = proposals()
    bad = []
    for r in recs:
        if r.get("class") != "paid":
            continue
        p = props.get(r.get("proposal_id") or "")
        if not p or p["status"] != "approved" or p.get("task") != r.get("task") or p.get("backend") != r.get("backend"):
            bad.append(r)
    return bad


def audit_lines(weeks: int = 4) -> list[tuple[str, str]]:
    """(level, message) for `fw audit`. Levels: PASS WARN FAIL INFO."""
    out: list[tuple[str, str]] = []
    try:
        load_registry()
        out.append(("PASS", f"Review-backend registry valid ({policy_path().name})"))
    except CostError as e:
        out.append(("FAIL", str(e).splitlines()[0] + " — " + "; ".join(l.strip() for l in str(e).splitlines()[1:3])))
    recs, bad = read_jsonl(ledger("reviews.jsonl"))
    if bad:
        out.append(("WARN", f"Review cost ledger: {len(bad)} unparseable line(s) (first at line {bad[0]}) in .context/costs/reviews.jsonl"))
    if not recs:
        out.append(("INFO", "Review cost ledger: no records yet (.context/costs/reviews.jsonl)"))
    for wk, be, cls, n, metered, total in weekly(recs, weeks):
        cost = f", cost {total:.2f}" if metered else ", unmetered"
        out.append(("INFO", f"Review cost {wk}: {be} ({cls}) — {n} record(s){cost}"))
    for r in unapproved_paid(recs):
        out.append(("WARN", f"Paid review with no approved proposal: {r.get('task')} on {r.get('backend')} at {r.get('ts')} (proposal_id={r.get('proposal_id')})"))
    if recs and not unapproved_paid(recs):
        n_paid = sum(1 for r in recs if r.get("class") == "paid")
        out.append(("PASS", f"Review cost ledger: {len(recs)} record(s), {n_paid} paid — each with an approved proposal"))
    return out


# ── hook support ─────────────────────────────────────────────────────────────

def match_backends(command: str) -> list[dict]:
    """Backends whose `match:` patterns (default: the id as a word) hit a Bash command."""
    hits = []
    for b in load_registry():
        pats = b.get("match") or [rf"\b{re.escape(b['id'])}\b"]
        if any(re.search(p, command) for p in pats):  # case-sensitive; a pattern may opt in with (?i)
            hits.append(b)
    return hits


def check_command(command: str, task: str | None) -> tuple[int, str]:
    """PreToolUse verdict: (0, reminder-or-'') to allow, (2, reason) to block."""
    try:
        hits = match_backends(command)
    except CostError as e:
        # A broken registry must not silently wave paid calls through; but it also must
        # not block every Bash call. Block only if the pinned names appear.
        if any(re.search(rf"\b{p}\b", command, re.I) for p in PINNED_PAID):
            return 2, f"Paid-backend guard: registry invalid, refusing a {PINNED_PAID} call.\n{e}"
        return 0, ""
    msgs = []
    for b in hits:
        if b["approval_required"]:
            if not task:
                return 2, (f"Paid backend {b['id']} ({b['cost_class']}) needs an approved proposal, "
                           f"and no task is focused. bin/fw work-on T-XXX, then "
                           f"bin/fw review propose --task T-XXX --backend {b['id']} --why '...' --estimate-cost N")
            if not open_approval(task, b["id"]):
                return 2, (f"Paid backend {b['id']} needs an approved, unused proposal for {task}.\n"
                           f"  bin/fw review propose --task {task} --backend {b['id']} --why 'value/risk' --estimate-cost N\n"
                           f"  The operator approves it: bin/fw review approve RP-XXXX (their terminal, or --i-am-human).\n"
                           f"  Propose when value or risk is high: cost is not a reason not to ask.")
            msgs.append(f"Paid backend {b['id']}: approved proposal on file — log it afterwards with "
                        f"bin/fw review cost log --task {task} --backend {b['id']} --purpose ... --proposal-id <id>")
        else:
            msgs.append(f"Internal backend {b['id']}: log the cost when done — "
                        f"bin/fw review cost log --task {task or 'T-XXX'} --backend {b['id']} --purpose ...")
    return 0, "\n".join(msgs)


# ── CLI ──────────────────────────────────────────────────────────────────────

def _bool(s: str) -> bool:
    if s.lower() in ("true", "yes", "1"):
        return True
    if s.lower() in ("false", "no", "0"):
        return False
    raise argparse.ArgumentTypeError("expected true or false")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="fw review", description="Review/dispatch cost (T-3583, T-3586)")
    sub = ap.add_subparsers(dest="cmd")

    c = sub.add_parser("cost", help="cost ledger").add_subparsers(dest="sub")
    lg = c.add_parser("log")
    lg.add_argument("--task", required=True); lg.add_argument("--backend", required=True)
    lg.add_argument("--purpose", required=True); lg.add_argument("--tokens", type=int)
    lg.add_argument("--cost", type=float); lg.add_argument("--proposal-id"); lg.add_argument("--evidence")
    rp = c.add_parser("report"); rp.add_argument("--weeks", type=int, default=4); rp.add_argument("--json", action="store_true")

    pr = sub.add_parser("propose")
    pr.add_argument("--task", required=True); pr.add_argument("--backend", required=True)
    pr.add_argument("--why", required=True); pr.add_argument("--estimate-cost", type=float)
    pr.add_argument("--estimate-tokens", type=int)

    apv = sub.add_parser("approve")
    apv.add_argument("proposal", nargs="?"); apv.add_argument("--proposal-id")
    apv.add_argument("--i-am-human", action="store_true"); apv.add_argument("--reason", default="")

    sub.add_parser("list-backends")
    sub.add_parser("list-proposals")

    bk = sub.add_parser("backend", help="registry edits").add_subparsers(dest="sub")
    ad = bk.add_parser("add")
    ad.add_argument("--id", required=True); ad.add_argument("--name", required=True)
    ad.add_argument("--class", dest="cls", choices=CLASSES, required=True)
    ad.add_argument("--harness-class", default="subscription")
    ad.add_argument("--approval-required", type=_bool)
    ad.add_argument("--cost-estimate-method", default="unmetered")
    ad.add_argument("--description", default="")
    ad.add_argument("--match", action="append", default=[])
    ad.add_argument("--i-am-human", action="store_true")
    st = bk.add_parser("set")
    st.add_argument("--id", required=True); st.add_argument("--class", dest="cls", choices=CLASSES)
    st.add_argument("--approval-required", type=_bool); st.add_argument("--i-am-human", action="store_true")

    sub.add_parser("audit")
    hk = sub.add_parser("check-command"); hk.add_argument("--task", default="")

    a = ap.parse_args(argv)
    try:
        if a.cmd == "cost" and a.sub == "log":
            r = log_cost(task=a.task, backend=a.backend, purpose=a.purpose, tokens=a.tokens,
                         cost=a.cost, proposal_id=a.proposal_id, evidence=a.evidence)
            print(f"Logged: {r['task']} {r['backend']} ({r['class']}, {r['metering']}) — {r['purpose']}")
        elif a.cmd == "cost" and a.sub == "report":
            recs, _ = read_jsonl(ledger("reviews.jsonl"))
            rows = weekly(recs, a.weeks)
            if a.json:
                print(json.dumps([dict(zip(("week", "backend", "class", "records", "metered", "cost"), r)) for r in rows]))
            else:
                print(f"{'WEEK':<10} {'BACKEND':<14} {'CLASS':<9} {'RECORDS':>7} {'METERED':>7} {'COST':>9}")
                for r in rows:
                    print(f"{r[0]:<10} {r[1]:<14} {r[2]:<9} {r[3]:>7} {r[4]:>7} {r[5]:>9.2f}")
        elif a.cmd == "propose":
            r = propose(task=a.task, backend=a.backend, why=a.why, est_cost=a.estimate_cost, est_tokens=a.estimate_tokens)
            print(f"Proposal {r['id']} ({r['backend']}, {r['task']}) is pending operator approval.")
        elif a.cmd == "approve":
            pid = a.proposal_id or a.proposal
            if not pid:
                raise CostError("usage: fw review approve RP-XXXX [--i-am-human] [--reason ...]")
            approve(pid=pid, i_am_human=a.i_am_human, reason=a.reason)
            print(f"Approved {pid}.")
        elif a.cmd == "list-backends":
            print(f"{'ID':<14} {'CLASS':<9} {'APPROVAL':<9} {'HARNESS':<13} NAME")
            for b in load_registry():
                print(f"{b['id']:<14} {b['cost_class']:<9} {str(b['approval_required']).lower():<9} {b['harness_class']:<13} {b['name']}")
        elif a.cmd == "list-proposals":
            used = _consumed()
            for p in proposals().values():
                st_ = "used" if p["id"] in used else p["status"]
                print(f"{p['id']}  {st_:<8} {p['backend']:<12} {p['task']:<8} {p.get('why', '')}")
        elif a.cmd == "backend" and a.sub == "add":
            b = add_backend(bid=a.id, name=a.name, cost_class=a.cls, harness_class=a.harness_class,
                            approval_required=a.approval_required, method=a.cost_estimate_method,
                            description=a.description, match=a.match, i_am_human=a.i_am_human)
            print(f"Added {b['id']} ({b['cost_class']}) — logged to .context/costs/registry-changes.jsonl")
        elif a.cmd == "backend" and a.sub == "set":
            b = set_backend(bid=a.id, cost_class=a.cls, approval_required=a.approval_required, i_am_human=a.i_am_human)
            print(f"Set {b['id']}: class={b['cost_class']} approval_required={str(b['approval_required']).lower()} — logged")
        elif a.cmd == "audit":
            for lvl, msg in audit_lines():
                print(f"{lvl}\t{msg}")
        elif a.cmd == "check-command":
            rc, msg = check_command(sys.stdin.read(), a.task or None)
            if msg:
                print(msg, file=sys.stderr)
            return rc
        else:
            ap.print_help()
            return 1
    except CostError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
