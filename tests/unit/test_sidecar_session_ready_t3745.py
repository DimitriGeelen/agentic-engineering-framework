"""T-3745 — readiness and hand-over are per SESSION, not per project.

055 @117: two Claude sessions in one project (a claude-fw --termlink fleet
agent and the operator's terminal). With one project-wide ready flag, the
operator's Stop marked "ready" while the fleet agent was mid-turn, the
injector typed into the busy one, and the next session to prompt took
HANDED_OVER for mail it never saw.

The stand-in here is the `termlink` binary (a recorded runner). The live
two-real-sessions proof is tests/integration/t3684_sidecar_watcher_e2e_test.py.
"""

from __future__ import annotations

import io
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT))

from lib.sidecar import adapter, hooks, inject, receiver  # noqa: E402


@pytest.fixture
def proj(tmp_path, monkeypatch):
    root = tmp_path / "t3745"
    (root / ".context").mkdir(parents=True)
    (root / ".framework.yaml").write_text("project_name: t3745\n")
    monkeypatch.setenv("PROJECT_ROOT", str(root))
    monkeypatch.setenv("FW_SIDECAR_REGISTRY_DIR", str(tmp_path / "registry"))
    monkeypatch.delenv("FW_REVIEW_WORKER", raising=False)
    monkeypatch.delenv("TERMLINK_SESSION_ID", raising=False)
    # Deterministic whoever runs the suite (an interactive shell, cron, or a
    # `claude -p` worker — which would otherwise read as headless).
    monkeypatch.setattr(adapter, "_claude_ancestor_pid", lambda *a, **k: None)
    return root


class Termlink:
    """Answers `discover` with the given sessions; records every inject, and
    what the claim file held at the instant of typing."""

    def __init__(self, sessions):
        self.sessions, self.injects, self.claims_at_type = sessions, [], []

    def __call__(self, argv, **_):
        if argv[1] == "discover":
            return subprocess.CompletedProcess(argv, 0, json.dumps({"sessions": self.sessions}), "")
        self.injects.append(argv)
        self.claims_at_type.append({m.stem: json.loads(m.read_text())
                                    for m in receiver._messages_dir().glob("*.injected")})
        return subprocess.CompletedProcess(argv, 0, "", "")

    def typed_into(self):
        return [a[3] for a in self.injects]


def _sessions(*ids):
    tag = inject.project_tag()
    return [{"id": i, "tags": ["claude", tag], "metadata": {}} for i in ids]


def _hook(monkeypatch, which, sid, tl):
    """Run the real hook function as it runs inside session `sid` in PTY `tl`."""
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


# ── the 055 scenario ────────────────────────────────────────────────────────

def test_ready_flag_is_keyed_by_session_id_and_carries_termlink_session(proj, monkeypatch):
    _hook(monkeypatch, "stop", "fleet", "tl-fleet")
    rec = json.loads((proj / ".context/sidecar/sessions/fleet.json").read_text())
    assert rec["session_id"] == "fleet" and rec["ready"] is True
    assert rec["termlink_session"] == "tl-fleet"
    assert rec["transcript_path"] == "/tr/fleet.jsonl"


def test_non_urgent_goes_only_to_the_idle_session_never_the_busy_sibling(proj, monkeypatch):
    # both sessions stopped once; then the FLEET agent took a new prompt (busy)
    _hook(monkeypatch, "stop", "fleet", "tl-fleet")
    _hook(monkeypatch, "stop", "operator", "tl-op")
    _hook(monkeypatch, "prompt", "fleet", "tl-fleet")
    _store("m1")
    tl = Termlink(_sessions("tl-fleet", "tl-op"))
    rep = inject.deliver_pending("test", runner=tl)
    assert tl.typed_into() == ["tl-op"], rep
    assert rep["target_session_id"] == "operator"


def test_busy_session_receives_nothing_until_its_own_stop(proj, monkeypatch):
    _hook(monkeypatch, "stop", "fleet", "tl-fleet")
    _hook(monkeypatch, "prompt", "fleet", "tl-fleet")      # busy now
    # the operator's PLAIN terminal (not in a registered PTY) stops — the
    # exact case the project-wide flag got wrong
    _hook(monkeypatch, "stop", "operator", "tl-not-registered")
    adapter.set_ready_for_input(True)
    _store("m1")
    tl = Termlink(_sessions("tl-fleet"))
    rep = inject.deliver_pending("test", runner=tl)
    assert tl.injects == [] and "not ready" in rep["reason"]
    assert not [e for e in receiver.read_events("m1") if e["event"] == "INJECT_BLOCKED"]
    _hook(monkeypatch, "stop", "fleet", "tl-fleet")        # its turn ends
    rep = inject.deliver_pending("test", runner=tl)
    assert tl.typed_into() == ["tl-fleet"] and rep["injected"] == ["m1"]


def test_claim_names_the_target_session_and_exists_before_typing(proj, monkeypatch):
    _hook(monkeypatch, "stop", "fleet", "tl-fleet")
    _store("m1")
    tl = Termlink(_sessions("tl-fleet"))
    inject.deliver_pending("test", runner=tl)
    assert tl.claims_at_type[0]["m1"]["session_id"] == "fleet"
    assert tl.claims_at_type[0]["m1"]["termlink_session"] == "tl-fleet"
    # and the target was marked busy before the line went in
    assert not [r for r in adapter.session_records() if r["ready"]]


def test_handed_over_is_attributed_only_to_the_injected_session(proj, monkeypatch, tmp_path):
    _hook(monkeypatch, "stop", "fleet", "tl-fleet")
    _store("m1")
    inject.deliver_pending("test", runner=Termlink(_sessions("tl-fleet")))
    # the operator's terminal prompts FIRST: it must not take the message
    ids, out = _hook(monkeypatch, "prompt", "operator", "tl-op")
    assert ids == [] and out == ""
    # the injected session's own prompt (the line arriving) surfaces it
    ids, out = _hook(monkeypatch, "prompt", "fleet", "tl-fleet")
    assert ids == ["m1"]
    # evidence is read from THAT session's transcript
    ctx = json.loads(out)["hookSpecificOutput"]["additionalContext"]
    tr = tmp_path / "fleet.jsonl"
    tr.write_text(json.dumps({"type": "attachment", "attachment": {
        "type": "hook_additional_context", "content": [ctx]}}) + "\n")
    assert hooks.finalize(str(tr), ["m1"], wait_s=0)["confirmed"] == ["m1"]
    ho = [e for e in receiver.read_events("m1") if e["event"] == "HANDED_OVER"]
    assert ho and ho[0]["evidence"] == "transcript:fleet.jsonl"


def test_prompt_without_session_id_surfaces_nothing(proj, monkeypatch):
    _store("m1")
    inject._write_claim("m1", datetime.now(timezone.utc), {"session_id": "fleet"})
    assert hooks.prompt({}, out=io.StringIO(), spawn=False) == []


def test_dead_claude_process_reads_not_ready(proj, monkeypatch):
    _hook(monkeypatch, "stop", "gone", "tl-gone")
    path = proj / ".context/sidecar/sessions/gone.json"
    rec = json.loads(path.read_text())
    rec["claude_pid"] = 2 ** 22 + 12345          # no such process
    path.write_text(json.dumps(rec))
    _store("m1")
    tl = Termlink(_sessions("tl-gone"))
    assert inject.deliver_pending("test", runner=tl)["injected"] == []
    assert tl.injects == []


def test_urgent_goes_into_a_busy_session_alone_non_urgent_keeps_waiting(proj, monkeypatch):
    _hook(monkeypatch, "stop", "fleet", "tl-fleet")
    _hook(monkeypatch, "prompt", "fleet", "tl-fleet")      # busy
    _store("n1")
    _store("u1", urgent=True)
    tl = Termlink(_sessions("tl-fleet"))
    rep = inject.deliver_pending("test", runner=tl)
    assert rep["injected"] == ["u1"] and tl.typed_into() == ["tl-fleet"]
    ev = [e for e in receiver.read_events("u1") if e["event"] == "INJECT_ATTEMPT"][0]
    assert ev["urgent_bypass"] is True and ev["target_session_id"] == "fleet"
    assert inject.read_claim("n1") is None


def test_inject_blocked_recorded_once_per_reason(proj, monkeypatch):
    _store("m1")
    tl = Termlink([])
    for _ in range(3):
        inject.deliver_pending("tick", runner=tl)
    blocked = [e for e in receiver.read_events("m1") if e["event"] == "INJECT_BLOCKED"]
    assert len(blocked) == 1 and "no TermLink session" in blocked[0]["reason"]


def test_stop_hook_via_fw_hook_writes_the_session_record(proj):
    e = dict(os.environ, PROJECT_ROOT=str(proj), TERMLINK_SESSION_ID="tl-real")
    subprocess.run([str(FW_ROOT / "bin" / "fw"), "hook", "sidecar-receiver-ready"],
                   input=json.dumps({"session_id": "abc-123", "transcript_path": "/x.jsonl"}),
                   text=True, cwd=proj, env=e, timeout=60, check=True)
    rec = json.loads((proj / ".context/sidecar/sessions/abc-123.json").read_text())
    assert rec["ready"] is True and rec["termlink_session"] == "tl-real"


# ── plain-terminal-only projects (no injection target exists) ───────────────

def test_plain_only_project_prompt_takes_and_claims_unclaimed_mail(proj, monkeypatch):
    """No TermLink session is registered for this project (the injector's last
    decision found none): the prompt hook is the only way in, so the session
    that prompts takes the mail — claimed for itself first, so HANDED_OVER is
    still that session's, proven from its own transcript."""
    _store("m1")
    inject.deliver_pending("tick", runner=Termlink([]))      # publishes: no sessions
    assert inject.injector_found_no_session()
    ids, _ = _hook(monkeypatch, "prompt", "operator", "tl-none")
    assert ids == ["m1"] and inject.read_claim("m1")["session_id"] == "operator"
    ids2, _ = _hook(monkeypatch, "prompt", "someone-else", "tl-x")
    assert ids2 == []                                          # claimed: not twice


def test_injectable_session_present_plain_session_takes_nothing(proj, monkeypatch):
    _hook(monkeypatch, "stop", "fleet", "tl-fleet")
    _hook(monkeypatch, "prompt", "fleet", "tl-fleet")         # fleet busy
    _store("m1")
    inject.deliver_pending("tick", runner=Termlink(_sessions("tl-fleet")))
    assert not inject.injector_found_no_session()
    ids, _ = _hook(monkeypatch, "prompt", "operator", "tl-op")
    assert ids == []


def test_t3936_tagged_session_without_a_record_does_not_block_the_fallback(proj, monkeypatch):
    """T-3936 (G-111): a TermLink session IS registered for the project, but no live Claude
    session record points at it (2026-10-06: a pane whose claude shared the operator's
    session id; 25 messages waited 13 h). Nothing can be injected, so the operator's own
    prompt takes the mail. The control above (fleet WITH a record) still takes nothing."""
    _store("m1")
    inject.deliver_pending("tick", runner=Termlink(_sessions("tl-ghost")))
    assert inject.injector_found_no_session()
    ids, _ = _hook(monkeypatch, "prompt", "operator", "tl-none")
    assert ids == ["m1"] and inject.read_claim("m1")["session_id"] == "operator"


def test_no_injector_decision_on_record_plain_session_takes_nothing(proj, monkeypatch):
    """Seen live (T-3684): a project with a receiver but no injector decision
    on record. A prompting session must not take the mail."""
    _store("m1")
    assert not inject.injector_found_no_session()
    ids, _ = _hook(monkeypatch, "prompt", "worker", "tl-w")
    assert ids == [] and inject.read_claim("m1") is None


def test_headless_session_never_takes_fallback_mail(proj, monkeypatch):
    _store("m1")
    inject.deliver_pending("tick", runner=Termlink([]))      # decided: no sessions
    monkeypatch.setattr(adapter, "_is_headless", lambda pid: True)
    ids, _ = _hook(monkeypatch, "prompt", "claude-p-worker", "tl-w")
    assert ids == [] and inject.read_claim("m1") is None


def test_headless_worker_in_a_tagged_pty_is_never_injected_not_even_urgent(proj, monkeypatch):
    # A dispatched `claude -p` worker runs in a TermLink PTY tagged for the
    # project. Busy or stopped, it is never a target: no urgent bypass into it,
    # no "only registered session" fallback onto its PTY.
    monkeypatch.setattr(adapter, "_is_headless", lambda pid: True)
    _hook(monkeypatch, "stop", "worker", "tl-w")               # its own record says ready
    monkeypatch.setattr(adapter, "_is_headless", lambda pid: False)
    _store("n1")
    _store("u1", urgent=True)
    tl = Termlink(_sessions("tl-w"))
    rep = inject.deliver_pending("tick", runner=tl)
    assert tl.injects == [] and rep["injected"] == []
    assert inject.read_claim("n1") is None and inject.read_claim("u1") is None
    # ...and its PTY does not count as a registered interactive session, so a
    # plain-terminal interactive session may take the mail (T-3745 fallback).
    assert inject.injector_found_no_session() is True
    ids, _ = _hook(monkeypatch, "prompt", "operator-terminal", "")
    assert set(ids) == {"n1", "u1"}


def test_urgent_no_record_fallback_needs_an_interactive_claude_seen_in_the_pty(proj, monkeypatch):
    # codex round 3: a worker PTY registered before its first hook wrote a
    # record was the "only registered session" urgent fallback target.
    _store("u1", urgent=True)
    seen = {}

    def probe(pid):
        seen["pid"] = pid
        return probe.kind
    monkeypatch.setattr(adapter, "claude_in_pty", probe)
    for kind in ("headless", None):
        probe.kind = kind
        tl = Termlink([dict(_sessions("tl-w")[0], pid=4242)])
        rep = inject.deliver_pending("tick", runner=tl)
        assert tl.injects == [] and rep["injected"] == [] and inject.read_claim("u1") is None
        assert seen["pid"] == 4242
    probe.kind = "interactive"
    tl = Termlink([dict(_sessions("tl-op")[0], pid=4243)])
    assert inject.deliver_pending("tick", runner=tl)["injected"] == ["u1"]
    assert tl.typed_into() == ["tl-op"]


def test_headless_session_surfaces_nothing_even_with_a_pty_only_claim(proj, monkeypatch):
    # codex round 3 reproduction: a PTY-only claim (session_id None) naming a
    # worker's PTY; the worker's first prompt hook must not surface it.
    _store("u1", urgent=True)
    inject.claim_for("u1", {"session_id": None, "termlink_session": "tl-w"})
    assert inject.is_claimed_for("u1", {"session_id": "worker", "termlink_session": "tl-w"})
    monkeypatch.setattr(adapter, "_is_headless", lambda pid: True)
    ids, out = _hook(monkeypatch, "prompt", "worker", "tl-w")
    assert ids == [] and "body-u1" not in out
    # an interactive session in that PTY does take it
    monkeypatch.setattr(adapter, "_is_headless", lambda pid: False)
    ids, out = _hook(monkeypatch, "prompt", "operator", "tl-w")
    assert ids == ["u1"] and "body-u1" in out


def test_claude_in_pty_reads_real_processes(tmp_path):
    # A real process tree: shell → `claude` (comm) with or without -p.
    import time
    fake = tmp_path / "claude"
    fake.write_text("#!/bin/bash\nsleep 30\n")
    fake.chmod(0o755)
    for args, want in (([], "interactive"), (["-p", "x"], "headless")):
        sh = subprocess.Popen(["bash", "-c", f"{fake} {' '.join(args)}; true"])
        try:
            got = None
            for _ in range(100):
                got = adapter.claude_in_pty(sh.pid)
                if got:
                    break
                time.sleep(0.05)
            assert got == want
        finally:
            subprocess.run(["pkill", "-P", str(sh.pid)])
            sh.kill()
            sh.wait()
    bare = subprocess.Popen(["sleep", "30"])
    try:
        assert adapter.claude_in_pty(bare.pid) is None
    finally:
        bare.kill()
        bare.wait()


def _execd(pid):
    import time
    for _ in range(100):                       # until the child has exec'd
        if b"time.sleep" in Path(f"/proc/{pid}/cmdline").read_bytes():
            return
        time.sleep(0.02)


def test_is_headless_reads_the_claude_command_line(tmp_path):
    p = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(30)", "-p"])
    try:
        _execd(p.pid)
        assert adapter._is_headless(p.pid) is True
    finally:
        p.kill()
    q = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(30)"])
    try:
        _execd(q.pid)
        assert adapter._is_headless(q.pid) is False
    finally:
        q.kill()
