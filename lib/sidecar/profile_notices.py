"""T-5236 — one operator notice per (user, hub) when a send has no usable hubs.toml profile.

Operator ruling 2026-11-18 (question 4, option 1 + remediation option 1). A send whose
sender has no hubs.toml profile for the target hub (or whose profile's secret is broken)
keeps retrying exactly as before; this module only makes the gap reach the operator:

  * ONE notice per (user, hub), never one per retry or per sender — re-observations bump
    `last_seen` and the waiting-message count on the same row;
  * the exact fix: `termlink fleet reauth <profile>` when the profile exists but its secret
    is broken (one command, so a runme is prepared for it — never run here), or the
    hubs.toml lines to add when the profile is missing;
  * resolved by itself when a later send to that hub is delivered;
  * `stale(days=7)` is what the daily audit reports.

Ledger: <project>/.context/sidecar/hub-profile-notices.jsonl, one JSON row per (user, hub):
  {user, host, hub, kind, fix, runme, first_seen, last_seen, messages_waiting,
   waiting_ids, messages_final, resolved_at}
Nothing here writes credentials or hubs.toml, and nothing contacts a hub.
"""

from __future__ import annotations

import fcntl
import getpass
import json
import os
import re
import socket
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

if __package__ in (None, ""):   # run as a script: `python3 lib/sidecar/profile_notices.py stale`
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
    from lib.sidecar import outbox
else:
    from . import outbox

MISSING = "missing-profile"
BROKEN = "broken-profile"
STALE_DAYS = 7
_ADDR = re.compile(r"^[A-Za-z0-9.\-]+:\d+$")


def ledger_path(root: Path | None = None) -> Path:
    return Path(root or outbox._root()) / ".context" / "sidecar" / "hub-profile-notices.jsonl"


def current_user() -> str:
    try:
        return getpass.getuser()
    except Exception:
        return str(os.getuid())


def current_host() -> str:
    return socket.gethostname()


def _now(now: datetime | None = None) -> str:
    return (now or datetime.now(timezone.utc)).isoformat(timespec="seconds")


# ── the fix text ──────────────────────────────────────────────────────────────

def missing_fix(hub: str, home: str | None = None) -> str:
    """The hubs.toml lines to add for a hub this user has no profile for."""
    home = home or str(Path.home())
    if _ADDR.match(hub):
        name, address = re.sub(r"[^A-Za-z0-9_-]", "-", hub), hub
    else:
        name, address = hub, f"<host:port of hub {hub}>"
    return (f"add to {home}/.termlink/hubs.toml:\n"
            f"[hubs.{name}]\n"
            f"address = \"{address}\"\n"
            f"secret_file = \"{home}/.termlink/secrets/{name}.hex\"\n"
            f"then place hub {hub}'s secret (hex) in that secret_file — the operator's step; "
            f"agents never write credentials")


def broken_fix(profile: str) -> str:
    return f"termlink fleet reauth {profile}"


def gap(kind: str, hub: str, profile: str | None = None, home: str | None = None) -> dict:
    """The structured gap a probe attaches to its ProbeResult."""
    if kind == BROKEN:
        return {"kind": BROKEN, "hub": hub, "profile": profile or hub,
                "fix": broken_fix(profile or hub), "command": broken_fix(profile or hub)}
    return {"kind": MISSING, "hub": hub, "profile": None,
            "fix": missing_fix(hub, home), "command": None}


def fix_detail(g: dict, user: str | None = None, host: str | None = None) -> str:
    """One line for the NOT-delivered reason: hub, user and the exact fix."""
    who = f"user {user or current_user()} on host {host or current_host()}"
    if g["kind"] == BROKEN:
        return (f"{who} has a broken hubs.toml profile {g['profile']} for hub {g['hub']}; "
                f"fix: `{g['fix']}`")
    return (f"{who} has no hubs.toml profile for hub {g['hub']}; fix: "
            + " / ".join(ln for ln in g["fix"].splitlines() if ln.strip()))


# ── ledger ────────────────────────────────────────────────────────────────────

def _read(path: Path) -> list[dict]:
    rows = []
    if path.is_file():
        for line in path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line:
                try:
                    rows.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
    return rows


def _write(path: Path, rows: list[dict]) -> None:
    tmp = path.with_suffix(".jsonl.tmp")
    tmp.write_text("".join(json.dumps(r, sort_keys=True) + "\n" for r in rows), encoding="utf-8")
    os.replace(tmp, path)


class _Locked:
    def __init__(self, path: Path):
        self.path = path

    def __enter__(self):
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.fh = open(self.path.with_suffix(".lock"), "w")
        fcntl.flock(self.fh, fcntl.LOCK_EX)
        return _read(self.path)

    def __exit__(self, *exc):
        fcntl.flock(self.fh, fcntl.LOCK_UN)
        self.fh.close()


def _prepare_runme(user: str, hub: str, command: str) -> str | None:
    """A one-command fix comes as a prepared runme (`fw runme new`). Prepared, never run."""
    fw = Path(__file__).resolve().parents[2]
    script = fw / "lib" / "runme.sh"
    if not script.is_file():
        return None
    name = "hub-profile-" + re.sub(r"[^A-Za-z0-9._-]", "-", f"{user}-{hub}")
    env = dict(os.environ, PROJECT_ROOT=str(outbox._root()), FRAMEWORK_ROOT=str(fw))
    try:
        proc = subprocess.run(
            ["bash", "-c", 'source "$1"; shift; runme_main "$@"', "runme", str(script), "new", name,
             "--desc", f"T-5236: repair the hubs.toml profile of user {user} for hub {hub}",
             "--", command],
            capture_output=True, text=True, timeout=20, env=env)
    except (OSError, subprocess.SubprocessError):
        return None
    if proc.returncode != 0:
        return None
    line = next((ln.strip() for ln in proc.stdout.splitlines() if ln.strip().startswith("bash ")), "")
    return line or None


def record(g: dict, client_msg_id: str | None, *, final: bool = False,
           user: str | None = None, host: str | None = None,
           now: datetime | None = None, make_runme=_prepare_runme) -> dict:
    """Record (or bump) the one notice for (user, hub). Returns the row."""
    user, host = user or current_user(), host or current_host()
    ts = _now(now)
    path = ledger_path()
    with _Locked(path) as rows:
        row = next((r for r in rows if r.get("user") == user and r.get("hub") == g["hub"]), None)
        if row is None:
            row = {"user": user, "hub": g["hub"], "first_seen": ts, "waiting_ids": [],
                   "messages_final": 0, "runme": None}
            rows.append(row)
        elif row.get("resolved_at"):
            # The same pair failing again reopens its one notice.
            row.update(first_seen=ts, waiting_ids=[], messages_final=0, resolved_at=None)
        if row.get("kind") != g["kind"]:
            row["runme"] = None   # a different gap needs a different fix
        row.update(host=host, kind=g["kind"], profile=g.get("profile"), fix=g["fix"],
                   last_seen=ts, resolved_at=None)
        if client_msg_id:
            if final:
                row["messages_final"] = int(row.get("messages_final") or 0) + 1
                row["waiting_ids"] = [i for i in row["waiting_ids"] if i != client_msg_id]
            elif client_msg_id not in row["waiting_ids"]:
                row["waiting_ids"].append(client_msg_id)
        row["messages_waiting"] = len(row["waiting_ids"])
        if g.get("command") and not row.get("runme") and make_runme:
            row["runme"] = make_runme(user, g["hub"], g["command"])
        _write(path, rows)
        return dict(row)


def resolve(hub: str | None, client_msg_id: str | None = None, *, user: str | None = None,
            now: datetime | None = None) -> int:
    """A send to `hub` was delivered: resolve this user's notice for it, and any notice
    that was waiting on this very message. Returns the number resolved."""
    path = ledger_path()
    if not hub or not path.is_file():
        return 0
    user = user or current_user()
    n = 0
    with _Locked(path) as rows:
        for r in rows:
            if r.get("resolved_at") or r.get("hub") != hub:
                continue
            if r.get("user") == user or (client_msg_id and client_msg_id in r.get("waiting_ids", [])):
                r["resolved_at"] = _now(now)
                n += 1
        if n:
            _write(path, rows)
    return n


def pending(root: Path | None = None) -> list[dict]:
    return [r for r in _read(ledger_path(root)) if not r.get("resolved_at")]


def stale(days: int = STALE_DAYS, now: datetime | None = None,
          root: Path | None = None) -> list[dict]:
    cutoff = (now or datetime.now(timezone.utc)) - timedelta(days=days)
    out = []
    for r in pending(root):
        try:
            if datetime.fromisoformat(r["first_seen"]) <= cutoff:
                out.append(r)
        except (KeyError, ValueError):
            out.append(r)   # an undatable notice is reported, not hidden
    return out


def summary(r: dict) -> str:
    """The operator line: user X on host Y has no profile for hub Z; N messages waiting; fix: …"""
    what = ("has no hubs.toml profile" if r.get("kind") == MISSING
            else f"has a broken hubs.toml profile ({r.get('profile')})")
    n = int(r.get("messages_waiting") or 0)
    fix = (f"run {r['runme']}" if r.get("runme")
           else " / ".join(ln for ln in str(r.get("fix") or "").splitlines() if ln.strip()))
    extra = f" (+{r['messages_final']} refused, resend after the fix)" if r.get("messages_final") else ""
    return (f"user {r.get('user')} on host {r.get('host')} {what} for hub {r.get('hub')}; "
            f"{n} message{'' if n == 1 else 's'} waiting{extra}; fix: {fix}")


def main(argv: list[str]) -> int:
    cmd = argv[0] if argv else "pending"
    as_json = "--json" in argv
    if cmd == "pending":
        rows = pending()
    elif cmd == "stale":
        days = STALE_DAYS
        if "--days" in argv:
            days = int(argv[argv.index("--days") + 1])
        rows = stale(days)
    else:
        print("usage: profile_notices.py pending|stale [--days N] [--json]", file=sys.stderr)
        return 2
    if as_json:
        print(json.dumps([dict(r, summary=summary(r)) for r in rows]))
    else:
        for r in rows:
            print(f"{summary(r)} (since {r.get('first_seen')})")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
