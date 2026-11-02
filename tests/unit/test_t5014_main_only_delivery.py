"""T-5014 — peer mail surfaces only in the project's MAIN session.

ring20, 2026-11-02: the injector typed into the newest READY session; while the
operator's session was mid-turn, a 17-day-old idle background session of the same
project was the only ready one, got the line and surfaced the request there.

TermLink owns the main pin (010 T-3654): `termlink main am-i --session <sid>` →
exit 0 main, 1 not-main (stdout names the holder), 2 unknown (fail closed); a
termlink without the verb keeps today's delivery (said once per session).

termlink is stubbed through FW_TERMLINK_BIN: a small script whose answer per
session id the test controls. `discover` / `pty inject` go to the recorded
runner, as in tests/unit/test_sidecar_session_ready_t3745.py (fixtures copied).
"""

from __future__ import annotations

import io
import json
import os
import stat
import subprocess
import sys
from pathlib import Path

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT))

from lib.sidecar import adapter, hooks, inject, lifecycle, main_session, receiver  # noqa: E402

STUB = r'''#!/usr/bin/env python3
import json, os, sys, time
args = sys.argv[1:]
with open(os.environ["T5014_LOG"], "a") as fh:
    fh.write(" ".join(args) + "\n")
sid = args[args.index("--session") + 1] if "--session" in args else ""
table = json.load(open(os.environ["T5014_MAP"]))
rc, out, err, sleep = table.get(sid, table.get("*", [2, "", "", 0]))
time.sleep(sleep)
sys.stdout.write(out)
sys.stderr.write(err)
sys.exit(rc)
'''

MISSING = [2, "", "error: unrecognized subcommand 'main'\n\nUsage: termlink <COMMAND>\n", 0]


@pytest.fixture
def proj(tmp_path, monkeypatch):
    root = tmp_path / "t5014"
    (root / ".context").mkdir(parents=True)
    (root / ".framework.yaml").write_text("project_name: t5014\n")
    monkeypatch.setenv("PROJECT_ROOT", str(root))
    monkeypatch.setenv("FW_SIDECAR_REGISTRY_DIR", str(tmp_path / "registry"))
    monkeypatch.delenv("FW_REVIEW_WORKER", raising=False)
    monkeypatch.delenv("TERMLINK_SESSION_ID", raising=False)
    monkeypatch.setattr(adapter, "_claude_ancestor_pid", lambda *a, **k: None)
    return root


class MainStub:
    """`termlink main am-i` answered per session id; every call logged."""

    def __init__(self, tmp_path, monkeypatch):
        self.bin = tmp_path / "termlink-stub"
        self.bin.write_text(STUB)
        self.bin.chmod(self.bin.stat().st_mode | stat.S_IXUSR)
        self.map = tmp_path / "main-map.json"
        self.log = tmp_path / "main-calls.log"
        monkeypatch.setenv("FW_TERMLINK_BIN", str(self.bin))
        monkeypatch.setenv("T5014_MAP", str(self.map))
        monkeypatch.setenv("T5014_LOG", str(self.log))
        self.set({})

    def set(self, table: dict):
        self.map.write_text(json.dumps(table))

    def calls(self):
        return self.log.read_text().splitlines() if self.log.exists() else []


@pytest.fixture
def main(proj, tmp_path, monkeypatch):
    return MainStub(tmp_path, monkeypatch)


class Termlink:
    """Answers `discover` with the given sessions; records every inject."""

    def __init__(self, sessions):
        self.sessions, self.injects = sessions, []

    def __call__(self, argv, **_):
        if argv[1] == "discover":
            return subprocess.CompletedProcess(argv, 0, json.dumps({"sessions": self.sessions}), "")
        self.injects.append(argv)
        return subprocess.CompletedProcess(argv, 0, "", "")

    def typed_into(self):
        return [a[3] for a in self.injects]


def _sessions(*ids):
    tag = inject.project_tag()
    return [{"id": i, "tags": ["claude", tag], "metadata": {}} for i in ids]


def _hook(monkeypatch, which, sid, tl):
    monkeypatch.setenv("TERMLINK_SESSION_ID", tl)
    try:
        if which == "stop":
            hooks.stop({"session_id": sid, "transcript_path": f"/tr/{sid}.jsonl"})
            return None
        buf = io.StringIO()
        ids = hooks.prompt({"session_id": sid, "transcript_path": f"/tr/{sid}.jsonl"},
                           out=buf, spawn=False)
        return ids, buf.getvalue()
    finally:
        monkeypatch.delenv("TERMLINK_SESSION_ID")


def _store(mid, **extra):
    env = {"client_msg_id": mid, "from": "peer", "body": f"body-{mid}", "conversation_id": "c"}
    env.update(extra)
    assert receiver.store_message(mid, env)[0]


def _ctx(out: str) -> str:
    return json.loads(out)["hookSpecificOutput"]["additionalContext"] if out else ""


def _ring20(monkeypatch):
    """An older idle background session, then the newer main session goes busy."""
    _hook(monkeypatch, "stop", "bg", "tl-bg")
    _hook(monkeypatch, "stop", "op", "tl-op")
    _hook(monkeypatch, "prompt", "op", "tl-op")      # operator mid-turn


# ── (a) the ring20 case ─────────────────────────────────────────────────────

def test_ring20_idle_background_session_never_receives_main_receives_after_stop(main, monkeypatch):
    main.set({"op": [0, "", "", 0], "bg": [1, "main: op\n", "", 0]})
    _ring20(monkeypatch)
    _store("m1")
    tl = Termlink(_sessions("tl-bg", "tl-op"))
    rep = inject.deliver_pending("test", runner=tl)
    assert tl.injects == [], rep
    assert "main session op busy" in rep["reason"]
    assert inject.read_claim("m1") is None
    # the background session prompts on its own: it surfaces nothing
    ids, out = _hook(monkeypatch, "prompt", "bg", "tl-bg")
    assert ids == [] and out == ""
    # the main's turn ends → it receives
    _hook(monkeypatch, "stop", "op", "tl-op")
    _hook(monkeypatch, "stop", "bg", "tl-bg")       # bg ready too, and newer: still not chosen
    rep = inject.deliver_pending("test", runner=tl)
    assert tl.typed_into() == ["tl-op"] and rep["injected"] == ["m1"]
    assert rep["target_session_id"] == "op" and "main-only delivery" in rep["reason"]
    ids, out = _hook(monkeypatch, "prompt", "op", "tl-op")
    assert ids == ["m1"] and "body-m1" in _ctx(out)


# ── (b) not-main ────────────────────────────────────────────────────────────

def test_not_main_prompt_surfaces_nothing_and_marks_nothing(main, monkeypatch):
    lifecycle.write_config(inject=False)              # hook fallback is the only path
    main.set({"bg": [1, "main: op\n", "", 0], "op": [0, "", "", 0]})
    _store("m1")
    ids, out = _hook(monkeypatch, "prompt", "bg", "tl-bg")
    assert ids == [] and out == ""
    assert inject.read_claim("m1") is None            # not claimed by the background session
    ids, out = _hook(monkeypatch, "prompt", "op", "tl-op")
    assert ids == ["m1"]                              # not marked shown either


def test_not_main_holds_even_a_claim_written_for_it(main, monkeypatch):
    main.set({"bg": [1, "main: op\n", "", 0]})
    _hook(monkeypatch, "stop", "bg", "tl-bg")
    _store("m1")
    inject.claim_for("m1", {"session_id": "bg", "termlink_session": "tl-bg"})
    ids, out = _hook(monkeypatch, "prompt", "bg", "tl-bg")
    assert ids == [] and out == ""


def test_all_candidates_not_main_means_no_target(main, monkeypatch):
    main.set({"*": [1, "main: elsewhere\n", "", 0]})
    _hook(monkeypatch, "stop", "bg", "tl-bg")
    _store("m1")
    tl = Termlink(_sessions("tl-bg"))
    rep = inject.deliver_pending("test", runner=tl)
    assert tl.injects == [] and "main: elsewhere" in rep["reason"]
    assert rep["reason"].startswith(inject.MAIN_ONLY_PREFIX)
    assert "no_recipient" not in rep


# ── (c) unknown ─────────────────────────────────────────────────────────────

def test_unknown_surfaces_nothing_but_says_so_in_one_line(main, monkeypatch):
    lifecycle.write_config(inject=False)
    main.set({"*": [2, "", "lease unreadable\n", 0]})
    _store("m1")
    ids, out = _hook(monkeypatch, "prompt", "op", "tl-op")
    assert ids == []
    assert _ctx(out) == main_session.UNKNOWN_LINE and "\n" not in _ctx(out)
    assert inject.read_claim("m1") is None


def test_unknown_injector_types_nowhere(main, monkeypatch):
    main.set({"*": [2, "", "", 0]})
    _hook(monkeypatch, "stop", "op", "tl-op")
    _store("m1")
    tl = Termlink(_sessions("tl-op"))
    rep = inject.deliver_pending("test", runner=tl)
    assert tl.injects == [] and "main-only delivery unknown" in rep["reason"]


def test_no_waiting_mail_asks_termlink_nothing(main, monkeypatch):
    ids, out = _hook(monkeypatch, "prompt", "op", "tl-op")
    assert ids == [] and out == "" and main.calls() == []


# ── (d) unsupported: today's delivery, said once per session ───────────────

def test_unsupported_keeps_todays_rule_and_says_so_once(main, monkeypatch):
    main.set({"*": MISSING})
    _ring20(monkeypatch)
    _store("m1")
    tl = Termlink(_sessions("tl-bg", "tl-op"))
    rep = inject.deliver_pending("test", runner=tl)
    assert tl.typed_into() == ["tl-bg"], rep          # today's rule: newest READY
    ids, out = _hook(monkeypatch, "prompt", "bg", "tl-bg")
    assert ids == ["m1"]
    assert _ctx(out).count(main_session.UNSUPPORTED_LINE) == 1
    # the frame keeps its place: transcript evidence readers (t3693 e2e) require the
    # context to START with the frame heading, so the notice trails it
    assert _ctx(out).startswith("# Sidecar receiver")
    assert _ctx(out).rstrip().endswith(main_session.UNSUPPORTED_LINE)
    # second delivery to the same session: the line is not repeated
    _hook(monkeypatch, "stop", "bg", "tl-bg")
    _store("m2")
    inject.deliver_pending("test", runner=tl)
    ids, out = _hook(monkeypatch, "prompt", "bg", "tl-bg")
    assert ids == ["m2"] and main_session.UNSUPPORTED_LINE not in _ctx(out)


def test_termlink_absent_reads_unsupported(proj, monkeypatch, tmp_path):
    monkeypatch.setenv("FW_TERMLINK_BIN", str(tmp_path / "no-such-termlink"))
    assert main_session.am_i("op") == (main_session.UNSUPPORTED, "")
    lifecycle.write_config(inject=False)
    _store("m1")
    ids, out = _hook(monkeypatch, "prompt", "op", "tl-op")
    assert ids == ["m1"] and main_session.UNSUPPORTED_LINE in _ctx(out)


# ── (e) urgent only into the main ──────────────────────────────────────────

def test_urgent_goes_only_into_the_main(main, monkeypatch):
    main.set({"op": [0, "", "", 0], "bg": [1, "main: op\n", "", 0]})
    _ring20(monkeypatch)
    _store("n1")
    _store("u1", urgent=True)
    tl = Termlink(_sessions("tl-bg", "tl-op"))
    rep = inject.deliver_pending("test", runner=tl)
    assert tl.typed_into() == ["tl-op"] and rep["injected"] == ["u1"]
    ev = [e for e in receiver.read_events("u1") if e["event"] == "INJECT_ATTEMPT"][0]
    assert ev["urgent_bypass"] is True and ev["target_session_id"] == "op"
    assert inject.read_claim("n1") is None


def test_urgent_with_no_main_goes_nowhere(main, monkeypatch):
    main.set({"*": [1, "main: elsewhere\n", "", 0]})
    _hook(monkeypatch, "stop", "bg", "tl-bg")
    _hook(monkeypatch, "prompt", "bg", "tl-bg")
    _store("u1", urgent=True)
    tl = Termlink(_sessions("tl-bg"))
    rep = inject.deliver_pending("test", runner=tl)
    assert tl.injects == [] and rep["injected"] == []


# ── (f) timeout and errors read unknown ─────────────────────────────────────

def test_termlink_timeout_reads_unknown(main):
    main.set({"*": [0, "", "", 3]})
    assert main_session.am_i("op", timeout=0.3) == (main_session.UNKNOWN, "")


def test_runner_errors_read_unknown_never_raise(proj):
    def boom(*a, **k):
        raise subprocess.TimeoutExpired(a[0], 5)
    assert main_session.am_i("op", runner=boom)[0] == main_session.UNKNOWN

    def perm(*a, **k):
        raise PermissionError("denied")
    assert main_session.am_i("op", runner=perm)[0] == main_session.UNKNOWN
    assert main_session.am_i("", runner=perm)[0] == main_session.UNKNOWN


def test_exit_codes_map_and_holder_is_one_short_line(proj):
    def answer(rc, out="", err=""):
        return lambda argv, **k: subprocess.CompletedProcess(argv, rc, out, err)
    assert main_session.am_i("s", runner=answer(0))[0] == main_session.MAIN
    a, holder = main_session.am_i("s", runner=answer(1, "holder: x\n\x1b[2Jsecond line\n" + "y" * 500))
    assert a == main_session.NOT_MAIN and "\n" not in holder and "\x1b" not in holder
    assert len(holder) <= 120
    assert main_session.am_i("s", runner=answer(2))[0] == main_session.UNKNOWN
    assert main_session.am_i("s", runner=answer(2, err="error: unexpected argument '--session'"))[0] \
        == main_session.UNSUPPORTED
    assert main_session.am_i("s", runner=answer(97, err="refused"))[0] == main_session.UNKNOWN
