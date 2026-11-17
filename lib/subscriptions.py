#!/usr/bin/env python3
"""Subscription registry: neutral subscription ids, never account data (T-5200, T-5190 S1).

policy/subscriptions.yaml names each subscription by a label the operator chooses
(`claude-a`, `glm`, ...), its harness and a short description, and assigns worker kinds
(optionally narrowed by host) to an id. Later slices record the id per dispatch (S2).

Authority: the registry is the operator's. add / assign / remove are refused under agent
control (CLAUDECODE=1 or AI_AGENT set), --i-am-human included — the same boundary as
`delegation widen` (T-5180). The Bash text gate (lib/shell_write_scan.py) refuses the
verbs too, because `env -u CLAUDECODE` strips the module's own check.

Account data is refused anywhere in the file, comments included: e-mail addresses, hex
runs of 32+ characters, base64-like runs of 32+ characters, known token prefixes.

CLI:
  subscriptions.py subscription list | show <id> | add <id> --harness H --description D
                   | assign <id> --kind K [--host H] | remove <id>
  subscriptions.py resolve <kind> [--host H]
  subscriptions.py record-id <kind> [--host H]   id | unassigned | unknown (+1 stderr warning); exit 0
  subscriptions.py audit          TSV `LEVEL<TAB>message` for fw audit / fw doctor;
                                  nothing when the file is absent
"""
from __future__ import annotations

import argparse
import datetime as _dt
import json
import os
import re
import sys
from pathlib import Path

import yaml

HARNESSES = ("claude", "glm", "codex", "antigravity", "openrouter", "other")
UNASSIGNED = "unassigned"
UNKNOWN = "unknown"   # T-5201: the registry could not be read — recorded, never blocking
ID_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,47}$")
HOST_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9.-]{0,252}$")
CHANGE_LOG = "subscription-changes.jsonl"

#: Account-looking values. Each entry: (label, regex). Tried against the whole file text.
ACCOUNT_PATTERNS: tuple[tuple[str, re.Pattern], ...] = (
    ("an e-mail address", re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}")),
    ("a token prefix (sk-)", re.compile(r"(?<![A-Za-z0-9])sk-[A-Za-z0-9_-]{6,}")),
    ("a token prefix (ghp_)", re.compile(r"ghp_[A-Za-z0-9]{6,}")),
    ("a token prefix (gho_)", re.compile(r"gho_[A-Za-z0-9]{6,}")),
    ("a token prefix (xoxb-)", re.compile(r"xoxb-[A-Za-z0-9-]{6,}")),
    ("a token prefix (AKIA)", re.compile(r"AKIA[A-Z0-9]{8,}")),
    ("a token prefix (glpat-)", re.compile(r"glpat-[A-Za-z0-9_-]{6,}")),
    ("a hex run of 32+ characters", re.compile(r"(?<![A-Za-z0-9])[0-9A-Fa-f]{32,}(?![A-Za-z0-9])")),
)
#: base64-like: 32+ characters of the base64/base64url alphabet containing a digit and at
#: least two upper- and two lower-case letters (so a long kebab-case word or a path such as
#: docs/reports/T-NNNN-some-title is not a token).
_B64_RUN = re.compile(r"[A-Za-z0-9+/_-]{32,}={0,2}")


class SubscriptionError(Exception):
    """A refusal. The message is shown to the caller as-is."""


# ── paths ────────────────────────────────────────────────────────────────────

def _roots() -> tuple[Path, Path]:
    fw = Path(os.environ.get("FRAMEWORK_ROOT") or Path(__file__).resolve().parent.parent)
    proj = Path(os.environ.get("PROJECT_ROOT") or Path.cwd())
    return proj, fw


def policy_path() -> Path:
    proj, fw = _roots()
    local = proj / "policy" / "subscriptions.yaml"
    return local if local.is_file() else fw / "policy" / "subscriptions.yaml"


def change_log() -> Path:
    return _roots()[0] / ".context" / "costs" / CHANGE_LOG


def _under_agent_control() -> bool:
    return os.environ.get("CLAUDECODE") == "1" or bool(os.environ.get("AI_AGENT", "").strip())


# ── validation ───────────────────────────────────────────────────────────────

def account_values(text: str) -> list[str]:
    """Labels of account-looking values in `text` (deduplicated, in pattern order).
    The values themselves are never returned — an error message must not echo a secret."""
    found: list[str] = []
    for label, rx in ACCOUNT_PATTERNS:
        if rx.search(text) and label not in found:
            found.append(label)
    for m in _B64_RUN.finditer(text):
        s = m.group(0)
        if re.search(r"\d", s) and len(re.findall(r"[A-Z]", s)) >= 2 and len(re.findall(r"[a-z]", s)) >= 2:
            found.append("a base64-like run of 32+ characters")
            break
    return found


def validate(data: object, text: str = "") -> list[str]:
    errs: list[str] = []
    for label in account_values(text):
        errs.append(f"account-looking value: {label} — this file holds neutral ids only, never account data")
    if data is None:
        data = {}
    if not isinstance(data, dict):
        return errs + ["top level must be a mapping with `subscriptions:` and `assignments:`"]
    unknown_top = sorted(set(data) - {"subscriptions", "assignments"})
    if unknown_top:
        errs.append(f"unknown top-level key(s): {', '.join(map(str, unknown_top))}")
    subs = data.get("subscriptions") or []
    assigns = data.get("assignments") or []
    if not isinstance(subs, list):
        errs.append("`subscriptions:` must be a list")
        subs = []
    if not isinstance(assigns, list):
        errs.append("`assignments:` must be a list")
        assigns = []
    ids: set[str] = set()
    for i, s in enumerate(subs):
        where = f"subscriptions[{i}]"
        if not isinstance(s, dict):
            errs.append(f"{where}: must be a mapping")
            continue
        sid = s.get("id")
        if not isinstance(sid, str) or not ID_RE.match(sid):
            errs.append(f"{where}: id {sid!r} must be lowercase a-z 0-9 - (max 48)")
        elif sid in ids:
            errs.append(f"{where}: duplicate id {sid!r}")
        else:
            ids.add(sid)
        if s.get("harness") not in HARNESSES:
            errs.append(f"{where}: unknown harness {s.get('harness')!r} — one of {', '.join(HARNESSES)}")
        if not isinstance(s.get("description"), str) or not s["description"].strip():
            errs.append(f"{where}: description is required")
        extra = sorted(set(s) - {"id", "harness", "description"})
        if extra:
            errs.append(f"{where}: unknown field(s) {', '.join(map(str, extra))}")
    pairs: set[tuple[str, str]] = set()
    for i, a in enumerate(assigns):
        where = f"assignments[{i}]"
        if not isinstance(a, dict):
            errs.append(f"{where}: must be a mapping")
            continue
        kind, host, sub = a.get("kind"), a.get("host"), a.get("subscription")
        if not isinstance(kind, str) or not ID_RE.match(kind):
            errs.append(f"{where}: kind {kind!r} must be a worker kind (lowercase a-z 0-9 -)")
        if host is not None and (not isinstance(host, str) or not HOST_RE.match(host)):
            errs.append(f"{where}: host {host!r} is not a hostname")
        if sub not in ids:
            errs.append(f"{where}: subscription {sub!r} is not defined under `subscriptions:`")
        key = (str(kind), str(host or ""))
        if key in pairs:
            errs.append(f"{where}: duplicate assignment for kind {kind!r}" + (f" host {host!r}" if host else ""))
        pairs.add(key)
        extra = sorted(set(a) - {"kind", "host", "subscription"})
        if extra:
            errs.append(f"{where}: unknown field(s) {', '.join(map(str, extra))}")
    return errs


def load(path: Path | None = None) -> dict:
    """The validated registry ({"subscriptions": [...], "assignments": [...]}). An absent
    file is an empty registry. Raises SubscriptionError when the file does not validate."""
    path = path or policy_path()
    if not path.is_file():
        return {"subscriptions": [], "assignments": []}
    text = path.read_text(encoding="utf-8")
    try:
        data = yaml.safe_load(text)
    except yaml.YAMLError as e:
        raise SubscriptionError(f"{path.name}: not valid YAML ({type(e).__name__})") from None
    errs = validate(data, text)
    if errs:
        raise SubscriptionError(f"{path.name} is invalid:\n  " + "\n  ".join(errs))
    data = data or {}
    return {"subscriptions": list(data.get("subscriptions") or []),
            "assignments": list(data.get("assignments") or [])}


def resolve(worker_kind: str, host: str | None = None, path: Path | None = None) -> str:
    """The subscription id assigned to `worker_kind` on `host`, or "unassigned". A
    host-specific assignment wins over a kind-only one. Raises SubscriptionError when the
    registry is invalid (an invalid registry must not silently read as unassigned)."""
    reg = load(path)
    kind_only = None
    for a in reg["assignments"]:
        if a.get("kind") != worker_kind:
            continue
        if a.get("host"):
            if host and a["host"] == host:
                return a["subscription"]
        elif kind_only is None:
            kind_only = a["subscription"]
    return kind_only or UNASSIGNED


def record_id(worker_kind: str | None, host: str | None = None,
              path: Path | None = None) -> tuple[str, str]:
    """(id, warning) for a record a dispatch or a cost row writes (T-5201, T-5190 S2).

    Never raises: an unreadable or invalid registry gives ("unknown", one-line warning) so
    the caller records that and carries on. `host` defaults to this machine. The id is a
    registry id (S1 validates it against ID_RE), "unassigned" or "unknown" — nothing else
    can come back, so no account-like or host value reaches the record."""
    if host is None:
        import socket
        host = socket.gethostname()
    try:
        sid = resolve(worker_kind or "claude", host, path)
    except Exception as e:  # noqa: BLE001 - any failure to read the registry is "unknown"
        first = str(e).splitlines()[0] if str(e) else type(e).__name__
        return UNKNOWN, f"WARNING: subscription registry unreadable — recorded as \"unknown\" ({first})"
    if sid != UNASSIGNED and not ID_RE.match(str(sid)):
        return UNKNOWN, "WARNING: subscription registry returned a malformed id — recorded as \"unknown\""
    return sid, ""


# ── mutation (operator only) ─────────────────────────────────────────────────

def _refuse_agent(verb: str) -> None:
    if _under_agent_control():
        raise SubscriptionError(
            f"REFUSED: `fw quota subscription {verb}` changes the operator's subscription registry "
            "and is never run under agent control (CLAUDECODE/AI_AGENT set) — --i-am-human does "
            "not open this door (T-5200). Hand the operator the command for their own terminal.")


def _write(reg: dict, path: Path) -> None:
    """Keep the leading comment block (the documented schema), re-dump the data."""
    head: list[str] = []
    if path.is_file():
        for line in path.read_text(encoding="utf-8").splitlines():
            if line.startswith("#") or not line.strip():
                head.append(line)
            else:
                break
    body = yaml.safe_dump({"subscriptions": reg["subscriptions"]}, sort_keys=False, default_flow_style=False) + \
        yaml.safe_dump({"assignments": reg["assignments"]}, sort_keys=False, default_flow_style=False)
    text = ("\n".join(head).rstrip("\n") + "\n" if head else "") + body
    errs = validate(yaml.safe_load(text), text)
    if errs:
        raise SubscriptionError("refusing — the registry would be invalid:\n  " + "\n  ".join(errs))
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".yaml.tmp")
    tmp.write_text(text, encoding="utf-8")
    os.replace(tmp, path)


def _log(action: str, rec: dict) -> None:
    p = change_log()
    p.parent.mkdir(parents=True, exist_ok=True)
    row = {"ts": _dt.datetime.now(_dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
           "action": action, **rec, "by": "human"}
    with p.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(row, sort_keys=True) + "\n")


def add(sid: str, harness: str, description: str) -> dict:
    _refuse_agent("add")
    path = policy_path()
    reg = load(path)
    if any(s["id"] == sid for s in reg["subscriptions"]):
        raise SubscriptionError(f"subscription {sid!r} already exists")
    new = {"id": sid, "harness": harness, "description": description}
    reg["subscriptions"].append(new)
    _write(reg, path)
    _log("add", {"id": sid, "harness": harness})
    return new


def assign(sid: str, kind: str, host: str | None = None) -> dict:
    _refuse_agent("assign")
    path = policy_path()
    reg = load(path)
    before = None
    keep = []
    for a in reg["assignments"]:
        if a.get("kind") == kind and (a.get("host") or None) == (host or None):
            before = a.get("subscription")
        else:
            keep.append(a)
    new = {"kind": kind, **({"host": host} if host else {}), "subscription": sid}
    reg["assignments"] = keep + [new]
    _write(reg, path)
    _log("assign", {"id": sid, "kind": kind, "host": host, "before": before})
    return new


def remove(sid: str) -> int:
    _refuse_agent("remove")
    path = policy_path()
    reg = load(path)
    if not any(s["id"] == sid for s in reg["subscriptions"]):
        raise SubscriptionError(f"unknown subscription id {sid!r}")
    reg["subscriptions"] = [s for s in reg["subscriptions"] if s["id"] != sid]
    dropped = [a for a in reg["assignments"] if a.get("subscription") == sid]
    reg["assignments"] = [a for a in reg["assignments"] if a.get("subscription") != sid]
    _write(reg, path)
    _log("remove", {"id": sid, "dropped_assignments": len(dropped)})
    return len(dropped)


# ── audit ────────────────────────────────────────────────────────────────────

def audit_lines() -> list[tuple[str, str]]:
    path = policy_path()
    if not path.is_file():
        return []
    try:
        reg = load(path)
    except SubscriptionError as e:
        lines = str(e).splitlines()
        return [("FAIL", lines[0] + " " + "; ".join(l.strip() for l in lines[1:4]))]
    return [("PASS", f"Subscription registry valid ({len(reg['subscriptions'])} id(s), "
                     f"{len(reg['assignments'])} assignment(s))")]


# ── CLI ──────────────────────────────────────────────────────────────────────

def _print_list(reg: dict) -> None:
    if not reg["subscriptions"]:
        print(f"No subscriptions registered ({policy_path()}). The operator adds them:")
        print("  bin/fw quota subscription add <id> --harness <harness> --description \"...\"")
        return
    for s in reg["subscriptions"]:
        kinds = [a["kind"] + (f"@{a['host']}" if a.get("host") else "")
                 for a in reg["assignments"] if a.get("subscription") == s["id"]]
        print(f"{s['id']:<16} {s['harness']:<12} {s['description']}"
              + (f"  [kinds: {', '.join(kinds)}]" if kinds else ""))


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="fw quota", description="Subscription registry (T-5200)")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sp = sub.add_parser("subscription", help="list/show/add/assign/remove subscription ids")
    ss = sp.add_subparsers(dest="scmd", required=True)
    ss.add_parser("list")
    sh = ss.add_parser("show"); sh.add_argument("id")
    ad = ss.add_parser("add"); ad.add_argument("id")
    ad.add_argument("--harness", required=True, choices=HARNESSES)
    ad.add_argument("--description", required=True)
    ad.add_argument("--i-am-human", action="store_true", help="accepted, but does not lift the agent refusal")
    asg = ss.add_parser("assign"); asg.add_argument("id")
    asg.add_argument("--kind", required=True); asg.add_argument("--host")
    asg.add_argument("--i-am-human", action="store_true", help="accepted, but does not lift the agent refusal")
    rm = ss.add_parser("remove"); rm.add_argument("id")
    rm.add_argument("--i-am-human", action="store_true", help="accepted, but does not lift the agent refusal")
    rs = sub.add_parser("resolve", help="subscription id for a worker kind")
    rs.add_argument("kind"); rs.add_argument("--host")
    sub.add_parser("audit", help="TSV LEVEL<TAB>message for fw audit / fw doctor")
    ri = sub.add_parser("record-id", help="id to record for a dispatch/cost row; never fails (T-5201)")
    ri.add_argument("kind"); ri.add_argument("--host")
    args = ap.parse_args(argv)
    if args.cmd == "record-id":
        sid, warn = record_id(args.kind, args.host)
        if warn:
            print(warn, file=sys.stderr)
        print(sid)
        return 0
    try:
        if args.cmd == "audit":
            for lvl, msg in audit_lines():
                print(f"{lvl}\t{msg}")
            return 0
        if args.cmd == "resolve":
            print(resolve(args.kind, args.host))
            return 0
        c = args.scmd
        if c == "list":
            _print_list(load())
        elif c == "show":
            reg = load()
            s = next((s for s in reg["subscriptions"] if s["id"] == args.id), None)
            if s is None:
                raise SubscriptionError(f"unknown subscription id {args.id!r}")
            print(yaml.safe_dump(s, sort_keys=False).rstrip())
            asg_ = [a for a in reg["assignments"] if a.get("subscription") == args.id]
            print("assignments:" + ("" if asg_ else " none"))
            for a in asg_:
                print(f"  - kind: {a['kind']}" + (f"  host: {a['host']}" if a.get("host") else ""))
        elif c == "add":
            add(args.id, args.harness, args.description)
            print(f"Added subscription {args.id} ({args.harness}) — logged to .context/costs/{CHANGE_LOG}")
        elif c == "assign":
            assign(args.id, args.kind, args.host)
            print(f"Assigned kind {args.kind}" + (f" on {args.host}" if args.host else "")
                  + f" → {args.id} — logged to .context/costs/{CHANGE_LOG}")
        elif c == "remove":
            n = remove(args.id)
            print(f"Removed subscription {args.id} and {n} assignment(s) — logged to .context/costs/{CHANGE_LOG}")
    except SubscriptionError as e:
        print(str(e), file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
