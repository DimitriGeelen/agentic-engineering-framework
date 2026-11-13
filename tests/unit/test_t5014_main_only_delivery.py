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

_REAL_ANCESTOR = adapter._claude_ancestor_pid   # before any fixture stubs it

STUB = r'''#!/usr/bin/env python3
import json, os, sys, time
args = sys.argv[1:]
with open(os.environ["T5014_LOG"], "a") as fh:
    fh.write(" ".join(args) + "\n")
sid = args[args.index("--session") + 1] if "--session" in args else ""
table = json.load(open(os.environ["T5014_MAP"]))
verb = args[1] if len(args) > 1 and args[0] == "main" else ""
rc, out, err, sleep = table.get(f"{verb}:{sid}", table.get(f"{verb}:*",
                                table.get(sid, table.get("*", [2, "", "", 0]))))
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
    # T-5054: the adapter reads CLAUDE_PROJECT_DIR; without this it reads the developer's own
    # .framework.yaml, and a host running the adapter trial turned every T-5014 claim into one
    # with --origin flags.
    monkeypatch.setenv("CLAUDE_PROJECT_DIR", str(root))
    monkeypatch.delenv("FW_TERMLINK_ADAPTER2", raising=False)
    monkeypatch.delenv("TERMLINK_SIDECAR_SOCKET", raising=False)
    monkeypatch.setenv("FW_SIDECAR_REGISTRY_DIR", str(tmp_path / "registry"))
    monkeypatch.delenv("FW_REVIEW_WORKER", raising=False)
    # the suite may itself run inside a dispatched worker: clear its markers
    monkeypatch.delenv("FW_DISPATCHED_WORKER", raising=False)
    monkeypatch.delenv("FW_REVIEWER_IN_DISPATCH", raising=False)
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

    def verbs(self, verb):
        return [c for c in self.calls() if c.startswith(f"main {verb} ")]


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


def test_no_waiting_mail_claims_but_never_asks_am_i(main, monkeypatch):
    main.set({"*": [0, "", "", 0]})
    ids, out = _hook(monkeypatch, "prompt", "op", "tl-op")
    assert ids == [] and out == ""
    assert main.calls() == ["main claim --session op"]


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


# ── (g) T-5014 follow-up: the main lease is CLAIMED, then asked ─────────────
# 010's build (msgs c84c1c6d, 59d2ec20): nobody holds main until a session claims
# it; a vacant lease answers am-i with exit 1 and the line below.

HELD = "not-main: held by main op-sid@host-a pid 4242 (agent aef) (generation 7)\n"
VACANT = "main of t5014 is vacant (generation 7)\n"


def test_exact_am_i_outputs_pinned(proj):
    def answer(rc, out="", err=""):
        return lambda argv, **k: subprocess.CompletedProcess(argv, rc, out, err)
    assert main_session.ask("s", runner=answer(0)) == (main_session.MAIN, "", False)
    a, holder, vacant = main_session.ask("s", runner=answer(1, HELD))
    assert (a, vacant) == (main_session.NOT_MAIN, False) and holder == HELD.strip()
    a, holder, vacant = main_session.ask("s", runner=answer(1, VACANT))
    assert (a, vacant) == (main_session.NOT_MAIN, True) and holder == VACANT.strip()
    assert main_session.ask("s", runner=answer(2, "", "hub down\n")) == (main_session.UNKNOWN, "", False)
    assert main_session.am_i("s", runner=answer(1, VACANT)) == (main_session.NOT_MAIN, VACANT.strip())


def test_claim_and_release_argv_and_results(proj):
    seen = []

    def answer(rc, out="", err=""):
        def run(argv, **k):
            seen.append(argv[1:])
            return subprocess.CompletedProcess(argv, rc, out, err)
        return run
    assert main_session.claim("s", runner=answer(0)) == main_session.CLAIMED
    assert seen[-1] == ["main", "claim", "--session", "s"]
    assert main_session.claim("s2", runner=answer(1, HELD)) == main_session.REFUSED
    assert main_session.claim("s3", runner=answer(2, "", MISSING[2])) == main_session.UNSUPPORTED
    assert main_session.claim("s4", runner=answer(2, "", "hub down")) == main_session.UNKNOWN
    assert main_session.release("s", runner=answer(0)) == main_session.RELEASED
    assert seen[-1] == ["main", "release", "--session", "s"]

    def boom(*a, **k):
        raise subprocess.TimeoutExpired(a[0], 5)
    assert main_session.claim("s5", runner=boom) == main_session.UNKNOWN
    assert main_session.release("s5", runner=boom) == main_session.UNKNOWN
    assert main_session.claim("", runner=boom) == main_session.UNKNOWN


def test_first_prompt_on_a_vacant_lease_claims_then_surfaces(main, monkeypatch):
    lifecycle.write_config(inject=False)
    state = main.map.parent / "held"
    # am-i: vacant until the claim lands, then main. The stub reads a table, so
    # the claim call itself flips the table (a tiny wrapper script).
    wrapper = main.bin.parent / "termlink-claiming"
    wrapper.write_text(
        "#!/usr/bin/env bash\n"
        f"echo \"$*\" >> \"$T5014_LOG\"\n"
        f"if [ \"$2\" = claim ]; then touch {state}; exit 0; fi\n"
        f"if [ -e {state} ]; then exit 0; fi\n"
        f"printf '%s' '{VACANT.strip()}'; exit 1\n")
    wrapper.chmod(0o755)
    monkeypatch.setenv("FW_TERMLINK_BIN", str(wrapper))
    _store("m1")
    ids, out = _hook(monkeypatch, "prompt", "op", "tl-op")
    assert ids == ["m1"] and "body-m1" in _ctx(out)
    calls = main.calls()
    assert calls[0] == "main claim --session op" and calls[1] == "main am-i --session op"


def test_renewal_is_rate_limited_to_one_claim_per_minute(main, monkeypatch):
    main.set({"*": [0, "", "", 0]})
    _hook(monkeypatch, "prompt", "op", "tl-op")
    _hook(monkeypatch, "stop", "op", "tl-op")
    _hook(monkeypatch, "prompt", "op", "tl-op")
    assert main.verbs("claim") == ["main claim --session op"]
    # a minute later it renews
    stamp = main_session._stamp("op")
    old = stamp.stat().st_mtime - main_session.CLAIM_MIN_INTERVAL_S - 1
    os.utime(stamp, (old, old))
    _hook(monkeypatch, "stop", "op", "tl-op")
    assert len(main.verbs("claim")) == 2


def test_failed_claim_is_not_stamped_so_the_next_prompt_retries(main, monkeypatch):
    main.set({"claim:op": [1, HELD, "", 0], "am-i:op": [1, HELD, "", 0]})
    _hook(monkeypatch, "prompt", "op", "tl-op")
    _hook(monkeypatch, "prompt", "op", "tl-op")
    assert len(main.verbs("claim")) == 2


def test_session_start_forces_a_claim_inside_the_rate_limit(main, monkeypatch):
    main.set({"*": [0, "", "", 0]})
    _hook(monkeypatch, "prompt", "op", "tl-op")
    assert hooks.session_start({"session_id": "op"}, spawn=False) == main_session.CLAIMED
    assert len(main.verbs("claim")) == 2


def test_session_start_cli_reads_hook_input_and_claims(main, monkeypatch, proj):
    """The real entry point, with the real /proc ancestry: run under an
    interactive claude (or none) it claims; run under a `claude -p` worker (as
    when this suite itself is dispatched) it must not."""
    main.set({"*": [0, "", "", 0]})
    headless = adapter._is_headless(_REAL_ANCESTOR())
    env = dict(os.environ, PROJECT_ROOT=str(proj))
    r = subprocess.run([sys.executable, str(FW_ROOT / "lib/sidecar/hooks.py"), "session-start"],
                       input=json.dumps({"session_id": "op"}), text=True, env=env,
                       capture_output=True, timeout=30)
    assert r.returncode == 0, r.stderr
    import time as _t
    for _ in range(100):                      # the claim runs detached
        if main.verbs("claim"):
            break
        _t.sleep(0.05)
    if headless:
        _t.sleep(0.5)
        assert main.verbs("claim") == []
    else:
        assert main.verbs("claim") == ["main claim --session op"]



@pytest.mark.parametrize("env", [("FW_REVIEW_WORKER", "1"), ("FW_DISPATCHED_WORKER", "1"),
                                 ("FW_REVIEWER_IN_DISPATCH", "1")])
def test_review_seats_and_dispatched_workers_never_claim(main, monkeypatch, env):
    main.set({"*": [0, "", "", 0]})
    monkeypatch.setenv(*env)
    lifecycle.write_config(inject=False)
    _store("m1")
    assert hooks.session_start({"session_id": "op"}, spawn=False) is None
    _hook(monkeypatch, "prompt", "op", "tl-op")
    _hook(monkeypatch, "stop", "op", "tl-op")
    assert main.verbs("claim") == []


def test_headless_worker_never_claims(main, monkeypatch):
    main.set({"*": [0, "", "", 0]})
    monkeypatch.setattr(adapter, "_is_headless", lambda pid: True)
    lifecycle.write_config(inject=False)
    _store("m1")
    assert hooks.session_start({"session_id": "w"}, spawn=False) is None
    ids, _ = _hook(monkeypatch, "prompt", "w", "tl-w")
    _hook(monkeypatch, "stop", "w", "tl-w")
    assert ids == [] and main.verbs("claim") == []
    assert not main_session.may_claim({"session_id": "w", "headless": True})
    assert main_session.may_claim({"session_id": "w", "headless": False})


def test_vacant_after_a_failed_claim_shows_one_line_and_no_mail(main, monkeypatch):
    lifecycle.write_config(inject=False)
    main.set({"claim:*": [1, "quiet period: vacant since 1 min\n", "", 0],
              "am-i:*": [1, VACANT, "", 0]})
    _store("m1")
    ids, out = _hook(monkeypatch, "prompt", "op", "tl-op")
    assert ids == [] and _ctx(out) == main_session.VACANT_LINE and "\n" not in _ctx(out)
    assert inject.read_claim("m1") is None


def test_vacant_within_the_rate_limit_retries_the_claim_once(main, monkeypatch):
    lifecycle.write_config(inject=False)
    main.set({"*": [0, "", "", 0]})
    _hook(monkeypatch, "prompt", "op", "tl-op")             # claimed, stamped
    main.set({"claim:*": [1, "cooldown\n", "", 0], "am-i:*": [1, VACANT, "", 0]})
    _store("m1")
    ids, out = _hook(monkeypatch, "prompt", "op", "tl-op")
    assert ids == [] and _ctx(out) == main_session.VACANT_LINE
    assert len(main.verbs("claim")) == 2                  # the forced retry


def test_held_by_another_session_shows_nothing(main, monkeypatch):
    lifecycle.write_config(inject=False)
    main.set({"claim:*": [1, HELD, "", 0], "am-i:*": [1, HELD, "", 0]})
    _store("m1")
    ids, out = _hook(monkeypatch, "prompt", "bg", "tl-bg")
    assert ids == [] and out == ""


def test_unsupported_termlink_claim_is_a_noop_and_delivery_is_todays(main, monkeypatch):
    lifecycle.write_config(inject=False)
    main.set({"*": MISSING})
    assert hooks.session_start({"session_id": "op"}, spawn=False) == main_session.UNSUPPORTED
    _store("m1")
    ids, out = _hook(monkeypatch, "prompt", "op", "tl-op")
    _hook(monkeypatch, "stop", "op", "tl-op")
    assert ids == ["m1"] and _ctx(out).count(main_session.UNSUPPORTED_LINE) == 1
    assert not main_session._stamp("op").exists()


# ── the ledger says why (ring20 via 010, msg d9231506) ─────────────────────

def test_inject_attempt_records_the_main_only_verdict_with_generation(main, monkeypatch):
    main.set({"op": [0, "main: this session is main of p (generation 7)\n", "", 0],
              "bg": [1, "not-main: held by main op@h pid 1 (generation 7)\n", "", 0]})
    _hook(monkeypatch, "stop", "bg", "tl-bg")
    _hook(monkeypatch, "stop", "op", "tl-op")
    _store("m1")
    rep = inject.deliver_pending("test", runner=Termlink(_sessions("tl-bg", "tl-op")))
    assert rep["injected"] == ["m1"]
    att = [e for e in receiver.read_events("m1") if e["event"] == "INJECT_ATTEMPT"]
    assert att and "main session" in att[-1]["main_only"] and "generation 7" in att[-1]["main_only"]


def test_not_main_injector_refusal_is_one_ledger_row(main, monkeypatch):
    main.set({"*": [1, "not-main: held by main elsewhere@h pid 1 (generation 3)\n", "", 0]})
    _hook(monkeypatch, "stop", "bg", "tl-bg")
    _store("m1")
    tl = Termlink(_sessions("tl-bg"))
    inject.deliver_pending("test", runner=tl)
    inject.deliver_pending("test", runner=tl)
    rows = [e for e in receiver.read_events("m1") if e["event"] == "INJECT_BLOCKED"]
    assert len(rows) == 1 and "generation 3" in rows[0]["reason"]


def test_not_main_prompt_records_withheld_once_per_session_and_verdict(main, monkeypatch):
    lifecycle.write_config(inject=False)
    main.set({"bg": [1, "not-main: held by main op@h pid 1 (generation 2)\n", "", 0],
              "op": [0, "", "", 0]})
    _store("m1")
    _hook(monkeypatch, "prompt", "bg", "tl-bg")
    _hook(monkeypatch, "prompt", "bg", "tl-bg")
    rows = [e for e in receiver.read_events("m1") if e["event"] == "SURFACE_WITHHELD"]
    assert len(rows) == 1
    assert rows[0]["session"] == "bg" and rows[0]["main_only"] == "not-main"
    assert "generation 2" in rows[0]["holder"]
