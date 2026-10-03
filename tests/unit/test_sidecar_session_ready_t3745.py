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
    assert not inject.project_has_injectable_session()
    ids, _ = _hook(monkeypatch, "prompt", "operator", "tl-none")
    assert ids == ["m1"] and inject.read_claim("m1")["session_id"] == "operator"
    ids2, _ = _hook(monkeypatch, "prompt", "someone-else", "tl-x")
    assert ids2 == []                                          # claimed: not twice


def test_injectable_session_present_plain_session_takes_nothing(proj, monkeypatch):
    _hook(monkeypatch, "stop", "fleet", "tl-fleet")
    _hook(monkeypatch, "prompt", "fleet", "tl-fleet")         # fleet busy
    _store("m1")
    inject.deliver_pending("tick", runner=Termlink(_sessions("tl-fleet")))
    assert inject.project_has_injectable_session()
    ids, _ = _hook(monkeypatch, "prompt", "operator", "tl-op")
    assert ids == []
