"""T-5054 slice 1 — Claude Code adapter for TermLink's ``termlink.adapter/2`` contract (010 P-44).

The producer side only (scope settled with 010, 2026-11-13; design note
docs/reports/T-5054-adapter2-design.md): each Claude Code hook writes one or more
reports, one JSON object per line WITHOUT an ``op`` field, to the TermLink sidecar's
owner-only send socket named by ``TERMLINK_SIDECAR_SOCKET``. TermLink's meter orders
and checks them (its AL-1); AEF's receiver does not.

    python3 lib/sidecar/adapter2.py <hook>     # session-start | prompt | pre-tool |
                                               # post-tool | stop | session-end

Contract points this module carries (spec pack, 04 v0.4 section 17):

- every report: ``schema, harness, harness_version, agent_id, session_id, event, at_ms``
  plus ``boot_id`` and ``mono_ns`` (host-monotonic ns through suspend, as a DECIMAL
  STRING) when both are known, never one without the other (17.2.a). ``at_ms`` is wall
  time for display only; nothing here orders on it.
- two reports from one hook take two clock reads, so their order is strict.
- prompt origin (17.5): ``automated`` with basis ``doorbell`` (a line a receiver typed),
  ``non-interactive`` (print mode / dispatched worker) or ``harness-mark`` (Claude
  Code's own transcript marks a generated prompt); ``human`` only as ``inferred``;
  ``unknown`` (no basis) when it cannot decide. 17.5.d finding: the transcript marks
  prove a prompt generated, never human.
- the turn fails open: any error prints nothing, exits 0 and appends one line to the
  receiver's hook-errors.log (TermLink 6.3).

Off unless enabled: ``TERMLINK_ADAPTER2=1`` (config or ``FW_TERMLINK_ADAPTER2``) AND a
socket in the environment. Never install it beside TermLink's own ``termlink-sidecar
hook`` entries (010, 17.9); wiring and that guard are slice 3.
"""

from __future__ import annotations

import json
import os
import re
import socket
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
    __package__ = "lib.sidecar"

SCHEMA = "termlink.adapter/2"
HARNESS = "claude-code"
MAX_LINE = 65536
SEND_TIMEOUT_S = 0.5

_BOOT_RE = re.compile(r"^[A-Za-z0-9-]{1,64}$")
_SESSION_RE = re.compile(r"^[A-Za-z0-9._:-]{1,128}$")
_AGENT_SOCK_RE = re.compile(r"^(.+)\.send\.sock$")

# 06 AL-1 check_origin: the only origin/basis pairs a receiver accepts.
VALID_ORIGIN = {"human": {"pty-input", "inferred"},
                "automated": {"doorbell", "non-interactive", "harness-mark", "pty-input"},
                "unknown": {None}}
#: How "no basis" is written on the wire with origin unknown (010 msg 0d44a3d3).
UNKNOWN_BASIS_WIRE = "absent"

# Order fields a pre-P-2 sidecar refuses; the report is sent once more without them
# and the receiver orders it by its own receive stamp (p2 fixture, hook_requests).
ORDER_FIELDS = ("boot_id", "mono_ns")


# ── clocks ──────────────────────────────────────────────────────────────────────

def boot_id() -> str | None:
    """The host's boot identifier, or None. Linux: /proc/sys/kernel/random/boot_id;
    macOS: sysctl kern.bootsessionuuid."""
    raw = ""
    try:
        raw = Path("/proc/sys/kernel/random/boot_id").read_text().strip()
    except OSError:
        if sys.platform == "darwin":
            try:
                raw = subprocess.run(["sysctl", "-n", "kern.bootsessionuuid"], capture_output=True,
                                     text=True, timeout=2).stdout.strip()
            except Exception:
                raw = ""
    return raw if _BOOT_RE.match(raw) else None


def mono_ns() -> str:
    """Host-monotonic ns that counts through suspend, as a decimal string (17.2.a):
    CLOCK_BOOTTIME on Linux; on macOS CLOCK_MONOTONIC, which keeps counting in sleep."""
    clk = getattr(time, "CLOCK_BOOTTIME", None)
    if clk is None:
        clk = time.CLOCK_MONOTONIC
    return str(time.clock_gettime_ns(clk))


class Clock:
    """Injectable clock source. ``tick()`` returns one (at_ms, mono_ns) pair; two calls
    never return the same mono_ns, so two reports from one hook are strictly ordered."""

    def __init__(self, boot=boot_id, mono=mono_ns, wall_ms=None):
        b = boot() if callable(boot) else boot
        self._boot = b if isinstance(b, str) and _BOOT_RE.match(b) else None   # never a malformed id
        self._mono = mono
        self._wall = wall_ms or (lambda: int(time.time() * 1000))
        self._last = -1

    @property
    def boot(self):
        return self._boot

    def tick(self) -> tuple[int, str | None]:
        ns = int(self._mono())
        if ns <= self._last:
            ns = self._last + 1
        self._last = ns
        return self._wall(), str(ns)


# ── reports ─────────────────────────────────────────────────────────────────────

def report(event: str, *, agent_id: str, session_id: str, clock: Clock,
           harness_version: str = "unknown", **fields) -> dict:
    """One adapter/2 report. Key order follows the parity fixtures."""
    at_ms, ns = clock.tick()
    r = {"schema": SCHEMA, "harness": HARNESS, "harness_version": harness_version,
         "agent_id": agent_id, "session_id": session_id, "event": event, "at_ms": at_ms}
    r.update({k: v for k, v in fields.items() if v is not None})
    if clock.boot and ns is not None:          # both or neither (17.2.a)
        r["boot_id"], r["mono_ns"] = clock.boot, ns
    return r


def encode(r: dict) -> bytes:
    if "op" in r:
        raise ValueError("an adapter/2 report never carries 'op' (a line with op is an API call)")
    line = json.dumps(r, separators=(",", ":"), ensure_ascii=True).encode() + b"\n"
    if len(line) > MAX_LINE:
        raise ValueError(f"report is {len(line)} bytes, over the {MAX_LINE}-byte line limit")
    return line


# ── prompt origin (17.5) ────────────────────────────────────────────────────────

def _is_doorbell(prompt: str) -> bool:
    """A line a receiver typed. AEF's own injector line is recognised exactly
    (inject.parse_doorbell); TermLink's doorbell prefix is added when 010 names it."""
    try:
        from . import inject
    except Exception:
        inject = None
    if inject is not None and inject.parse_doorbell(prompt):
        return True
    return bool(TERMLINK_DOORBELL_RE.match(str(prompt or "").lstrip()))


#: TermLink's SI-1 line, typed by both its doorbell and its watchdog (010, 2026-11-13; B-16,
#: termlink-session handler.rs:651): 'sidecar: <N> peer messages waiting, ids <32-hex>[ ...]. ...'.
#: The text cannot tell the two apart, and TermLink's meter accepts basis "doorbell" for both.
TERMLINK_DOORBELL_RE = re.compile(r"^sidecar: \d+ peer messages? waiting, ids [0-9a-f]{32}")

_GENERATED_KINDS = {"task-notification", "peer"}
_GENERATED_TURNS = {"task_notification", "scheduled"}


def _record_text(rec: dict) -> str:
    c = (rec.get("message") or {}).get("content")
    if isinstance(c, str):
        return c
    if isinstance(c, list):
        return "".join(x.get("text", "") for x in c if isinstance(x, dict) and x.get("type") == "text")
    return ""


def transcript_mark(transcript_path: str | None, prompt: str, tail_bytes: int = 262144) -> str | None:
    """'generated' when Claude Code's transcript record for THIS prompt marks it
    generated, 'unmarked' when the record is found without such a mark, None when no
    record for this prompt text is found (the hook may run before it is written)."""
    if not transcript_path or not prompt:
        return None
    try:
        with open(transcript_path, "rb") as fh:
            fh.seek(0, os.SEEK_END)
            fh.seek(max(0, fh.tell() - tail_bytes))
            lines = fh.read().decode("utf-8", "ignore").splitlines()
    except OSError:
        return None
    want = prompt.strip()
    for line in reversed(lines):
        try:
            rec = json.loads(line)
        except ValueError:
            continue
        if rec.get("type") != "user" or "promptId" not in rec or _record_text(rec).strip() != want:
            continue
        kind = (rec.get("origin") or {}).get("kind")
        if (kind in _GENERATED_KINDS or rec.get("turnOrigin") in _GENERATED_TURNS
                or rec.get("scheduledTaskId") or rec.get("promptSource") == "system"):
            return "generated"
        return "unmarked"
    return None


def classify_origin(hook_input: dict, interactive: bool | None) -> tuple[str, str | None]:
    """(origin, basis) per 17.5; every result is a pair the receiver accepts."""
    try:
        prompt = str(hook_input.get("prompt") or "")
        if _is_doorbell(prompt):
            return "automated", "doorbell"
        if interactive is False:
            return "automated", "non-interactive"
        if transcript_mark(hook_input.get("transcript_path"), prompt) == "generated":
            return "automated", "harness-mark"
        if interactive is True:
            return "human", "inferred"
    except Exception:
        _log_error("classify_origin")
    return "unknown", None


# ── hook → reports ──────────────────────────────────────────────────────────────

def _interactive(harness_pid: int | None) -> bool | None:
    try:
        from . import adapter
        return not adapter._is_headless(harness_pid)
    except Exception:
        return None


def _harness_pid() -> int | None:
    try:
        from . import adapter
        return adapter._claude_ancestor_pid()
    except Exception:
        return None


def reports_for(hook: str, hook_input: dict, *, agent_id: str, clock: Clock,
                harness_pid: int | None = None, interactive: bool | None = None,
                harness_version: str = "unknown") -> list[dict]:
    """The reports one Claude Code hook sends, in order (design note, event mapping)."""
    sid = str(hook_input.get("session_id") or "")
    if not _SESSION_RE.match(sid):
        raise ValueError("hook input has no usable session_id")
    kw = {"agent_id": agent_id, "session_id": sid, "clock": clock, "harness_version": harness_version}
    tool = str(hook_input.get("tool_name") or "")[:128] or None
    if hook == "session-start":
        if harness_pid is None:
            raise ValueError("session_start needs harness_pid (17.4.a)")
        return [report("session_start", **kw, harness_pid=int(harness_pid),
                       interactive=bool(interactive), transcript_path=hook_input.get("transcript_path"))]
    if hook == "prompt":
        origin, basis = classify_origin(hook_input, interactive)
        if origin == "unknown":
            # 010 (msg 0d44a3d3, 2026-11-13): TermLink's meter reads a MISSING basis as "" and
            # accepts only the literal "absent" with origin unknown, so an omitted field
            # counted as inconsistent. Say it explicitly on the wire; the claim still omits it.
            basis = UNKNOWN_BASIS_WIRE
        return [report("ready", **kw, state="BUSY"),
                report("prompt_submit", **kw, origin=origin, basis=basis)]
    if hook == "pre-tool":
        return [report("ready", **kw, state="BUSY"), report("tool_start", **kw, tool=tool)]
    if hook == "post-tool":
        return [report("tool_end", **kw, tool=tool)]
    if hook == "stop":
        return [report("turn_stop", **kw), report("ready", **kw, state="READY")]
    if hook == "session-end":
        return [report("session_end", **kw)]
    raise ValueError(f"unknown hook {hook!r}")


# ── transport ───────────────────────────────────────────────────────────────────

def _exchange(sock_path: str, line: bytes, timeout: float) -> dict:
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        s.settimeout(timeout)
        s.connect(sock_path)
        s.sendall(line)
        buf = b""
        while b"\n" not in buf and len(buf) < MAX_LINE:
            chunk = s.recv(4096)
            if not chunk:
                break
            buf += chunk
    return json.loads(buf.split(b"\n", 1)[0] or b"{}")


def _old_sidecar_refusal(reply: dict) -> bool:
    why = str(reply.get("ignored") or reply.get("error") or "")
    return reply.get("ok") is False and any(f in why for f in ORDER_FIELDS)


def send(reports: list[dict], sock_path: str, timeout: float = SEND_TIMEOUT_S) -> list[dict | None]:
    """Write each report on its own connection; return the replies (None on failure).
    A pre-P-2 sidecar that refuses the order fields gets the report once more without
    them. Never raises: the turn fails open."""
    replies: list[dict | None] = []
    for r in reports:
        try:
            reply = _exchange(sock_path, encode(r), timeout)
            if _old_sidecar_refusal(reply) and any(f in r for f in ORDER_FIELDS):
                reply = _exchange(sock_path, encode({k: v for k, v in r.items() if k not in ORDER_FIELDS}),
                                  timeout)
            replies.append(reply)
        except Exception:
            _log_error(f"send {r.get('event')}")
            replies.append(None)
    return replies


def checked_origin(reports: list[dict], replies: list[dict | None]) -> str:
    """The origin the lease claim may use (17.5.e): the receiver's ``origin_checked``,
    or ``unknown`` when the receiver could not be reached or did not apply the prompt;
    never the hook's own ``human``."""
    return checked_pair(reports, replies)[0]


def checked_pair(reports: list[dict], replies: list[dict | None]) -> tuple[str, str | None]:
    """(origin_checked, basis_checked) for the claim; ("unknown", None) when unchecked."""
    for r, reply in zip(reports, replies):
        if r.get("event") == "prompt_submit":
            if reply and reply.get("ok") is True and not reply.get("dropped"):
                o = reply.get("origin_checked")
                if o in VALID_ORIGIN:
                    return o, (reply.get("basis_checked") if o != "unknown" else None)
            return "unknown", None
    return "unknown", None


def hook_reports(hook: str, hook_input: dict) -> dict | None:
    """Slice 2 entry for lib/sidecar/hooks.py: send this hook's reports and return what
    the lease claim needs, or None when the adapter is off (then every claim stays
    exactly as before). Never raises; an unreachable sidecar gives origin unknown.

      prompt        → {"claim": True,  "origin", "basis", "kind": "prompt"}
      stop          → {"claim": False}   (CR-O3: only a human prompt renews the lease)
      session-start → {"claim": True, "kind": "session-start", "interactive"}
      others        → {"claim": False}
    """
    if not enabled():
        return None
    reps: list[dict] = []
    replies: list[dict | None] = []
    interactive = None
    try:
        sock = socket_path()
        agent = agent_id_for(sock)
        if not agent:
            raise ValueError("cannot tell the sidecar's agent id (set TERMLINK_AGENT_ID)")
        _log_hook_keys(hook, hook_input)
        pid = _harness_pid()
        interactive = _interactive(pid)
        reps = reports_for(hook, hook_input, agent_id=agent, clock=Clock(), harness_pid=pid,
                           interactive=interactive)
        replies = send(reps, sock)
    except Exception:
        _log_error(f"hook_reports {hook}")
    if hook == "prompt":
        origin, basis = checked_pair(reps, replies)
        return {"claim": True, "origin": origin, "basis": basis, "kind": "prompt"}
    if hook == "session-start":
        return {"claim": True, "kind": "session-start", "interactive": interactive is True}
    return {"claim": False}


# ── enablement, errors, entry point ─────────────────────────────────────────────

def _project_root() -> Path:
    return Path(os.environ.get("CLAUDE_PROJECT_DIR") or Path(__file__).resolve().parents[2])


def _config(key: str) -> str:
    """env FW_<KEY> > .framework.yaml > ''. A regex read, no YAML import: this runs on every
    tool call, so the off path must cost almost nothing (same reader as lib/testhost.py)."""
    val = os.environ.get("FW_" + key)
    if val:
        return val
    try:
        text = (_project_root() / ".framework.yaml").read_text(encoding="utf-8")
    except OSError:
        return ""
    m = re.search(rf"^\s*{key}:\s*['\"]?([^'\"#\n]+?)['\"]?\s*(#.*)?$", text, re.M)
    return m.group(1).strip() if m else ""


def socket_path() -> str:
    """The sidecar's send socket: ``TERMLINK_SIDECAR_SOCKET`` in the hook's environment (what
    TermLink sets), else the ``TERMLINK_SIDECAR_SOCKET`` config key (T-5054 slice 3: the operator
    sets it once instead of changing the session's environment)."""
    return os.environ.get("TERMLINK_SIDECAR_SOCKET") or _config("TERMLINK_SIDECAR_SOCKET")


#: TermLink's own Claude Code hooks (W1). The adapter never runs beside them (010, 04 17.9).
_W1_HOOK = re.compile(r"termlink[- ]sidecar\s+hook\b")


def w1_hook_files() -> list[str]:
    """Settings files that run TermLink's own sidecar hooks for this session."""
    home = Path(os.environ.get("HOME") or "~").expanduser()
    root = _project_root()
    found = []
    for f in (root / ".claude" / "settings.json", root / ".claude" / "settings.local.json",
              home / ".claude" / "settings.json"):
        try:
            if _W1_HOOK.search(f.read_text(encoding="utf-8", errors="ignore")):
                found.append(str(f))
        except OSError:
            continue
    return found


def enabled() -> bool:
    """On only when the switch is 1, a socket is known, and no settings file runs TermLink's
    own sidecar hooks (never both on one session; a W1 hit is logged and keeps it off)."""
    if _config("TERMLINK_ADAPTER2") != "1" or not socket_path():
        return False
    w1 = w1_hook_files()
    if w1:
        try:
            raise RuntimeError("TERMLINK_ADAPTER2=1 but TermLink's own sidecar hooks run here ("
                               + ", ".join(w1) + "); the adapter stays off")
        except RuntimeError:
            _log_error("w1-guard")
        return False
    return True


def agent_id_for(sock_path: str) -> str | None:
    """The sidecar's agent, from the socket name ``<agent>.send.sock``: the sidecar compares
    ``agent_id`` with exactly that name (010, meter.rs:657). ``TERMLINK_AGENT_ID`` is only a
    cross-check; a mismatch is logged, never sent instead."""
    m = _AGENT_SOCK_RE.match(os.path.basename(sock_path or ""))
    agent = m.group(1) if m else None
    env = os.environ.get("TERMLINK_AGENT_ID")
    if agent and env and env != agent:
        try:
            raise ValueError(f"TERMLINK_AGENT_ID {env!r} differs from the socket's agent {agent!r}; "
                             "using the socket's")
        except ValueError:
            _log_error("agent_id")
    return agent


def _log_error(where: str) -> None:
    try:
        d = _project_root() / ".context" / "sidecar" / "receiver"
        d.mkdir(parents=True, exist_ok=True)
        exc = sys.exc_info()[1]
        with open(d / "hook-errors.log", "a", encoding="utf-8") as fh:
            fh.write(f"{datetime.now(timezone.utc).isoformat()} adapter2 {where}: {exc!r}\n")
    except Exception:
        pass


def _log_hook_keys(hook: str, hook_input: dict) -> None:
    """17.5.d follow-up: record which KEYS Claude Code's hook input carries (names only,
    never values), to settle whether the hook sees the origin marks itself."""
    try:
        d = _project_root() / ".context" / "sidecar"
        with open(d / "adapter2-hook-keys.jsonl", "a", encoding="utf-8") as fh:
            fh.write(json.dumps({"hook": hook, "keys": sorted(hook_input)}) + "\n")
    except Exception:
        pass


def run(hook: str, hook_input: dict) -> list[dict | None]:
    if not enabled():
        return []
    sock = socket_path()
    agent = agent_id_for(sock)
    if not agent:
        raise ValueError("cannot tell the sidecar's agent id (set TERMLINK_AGENT_ID)")
    _log_hook_keys(hook, hook_input)
    pid = _harness_pid()
    reps = reports_for(hook, hook_input, agent_id=agent, clock=Clock(), harness_pid=pid,
                       interactive=_interactive(pid))
    return send(reps, sock)


def main(argv=None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    hook = argv[0] if argv else ""
    try:
        raw = sys.stdin.read() if not sys.stdin.isatty() else ""
        hook_input = json.loads(raw) if raw.strip() else {}
        run(hook, hook_input)
    except Exception:
        _log_error(hook or "main")
    return 0


if __name__ == "__main__":
    sys.exit(main())
