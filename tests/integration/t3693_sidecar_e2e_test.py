"""T-3693 — REAL end-to-end proof for arc-011 sidecar slice 1 (T-3561 AC7/AC8).

Two real interactive Claude Code sessions, each launched with
`claude-fw --termlink` in its own scratch project, each with its own receiver
sidecar (`fw sidecar receiver start`) and the framework's real Stop and
UserPromptSubmit hooks (`fw hook sidecar-receiver-ready|adapter`).

    agent A ──fw sidecar send──► B's receiver ──inject one line──► B's TermLink PTY
                                                                   │ B's prompt hook surfaces
                                                                   ▼ the message; B replies
    A's context ◄── A's prompt hook ◄── inject ◄── A's receiver ◄──fw sidecar send

The nonce is generated here at test time and handed to A as an operator
instruction. B's start-up prompt is "hello" — it never mentions a message.
The transformed nonce (UPPERCASE) is never written by this test: the ONLY
passing assertion is that string appearing in A's receiver store AND in A's own
session transcript as the context A's prompt hook surfaced. Everything else
(ledger states, inject events) is reported as evidence after that verdict.

NEGATIVE CONTROL: the same round trip with B's receiver started --no-inject.
Its verdict must be FAIL, and A's sender ledger must read ESCALATED (set by
`fw sidecar sweep`, the infrastructure) — not silence, not success.

No tick driver exists yet (T-3684). The harness runs `fw sidecar deliver-pending`
every TICK_S seconds in both projects — exactly the call T-3684's tick will
make. Each inject event records its trigger ("on-store" vs "e2e-tick") and the
report prints them, so it is visible which path delivered.

Slow (minutes) and costs real model tokens. Skipped, loudly, when `termlink`,
`claude` or tmux are absent.
"""

from __future__ import annotations

import json
import os
import random
import re
import shutil
import signal
import string
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
FW = str(FW_ROOT / "bin" / "fw")
CLAUDE_FW = str(FW_ROOT / "bin" / "claude-fw")
sys.path.insert(0, str(FW_ROOT))

MISSING = [b for b in ("termlink", "claude", "tmux") if shutil.which(b) is None]
MODEL = os.environ.get("T3693_E2E_MODEL", "sonnet")
ROUND_TRIP_TIMEOUT_S = int(os.environ.get("T3693_E2E_TIMEOUT", "300"))
HANDOVER_DEADLINE_S = 120
TICK_S = 5

needs_live = pytest.mark.skipif(
    bool(MISSING),
    reason=f"T-3693 LIVE E2E NOT RUN — missing on PATH: {', '.join(MISSING)}. "
           "This test is the only proof of T-3561 AC7/AC8; a skip here proves nothing.")


def _log(msg: str) -> None:
    print(f"[t3693-e2e {time.strftime('%H:%M:%S')}] {msg}", flush=True)


def _clean_env(**extra) -> dict:
    keep = ("HOME", "PATH", "USER", "LOGNAME", "SHELL", "LANG", "LC_ALL",
            "TERMLINK_RUNTIME_DIR", "XDG_STATE_HOME")
    env = {k: os.environ[k] for k in keep if k in os.environ}
    env["TERM"] = "xterm-256color"
    env.update(extra)
    return env


def _run(argv, cwd, timeout=60) -> subprocess.CompletedProcess:
    return subprocess.run(argv, cwd=cwd, env=_clean_env(), capture_output=True,
                          text=True, timeout=timeout)


def _project(base: Path, name: str) -> Path:
    root = base / name
    (root / ".context").mkdir(parents=True)
    (root / ".framework.yaml").write_text(f"project_name: {name}\n")
    (root / ".claude").mkdir()
    (root / ".claude" / "settings.json").write_text(json.dumps({
        "permissions": {"allow": ["Bash"]},
        "hooks": {
            "Stop": [{"matcher": "", "hooks": [
                {"type": "command", "command": f"{FW} hook sidecar-receiver-ready"}]}],
            "UserPromptSubmit": [{"matcher": "", "hooks": [
                {"type": "command", "command": f"{FW} hook sidecar-receiver-adapter"}]}],
        }}, indent=2))
    subprocess.run(["git", "init", "-q"], cwd=root, check=False)
    return root


def _tag(root: Path) -> str:
    out = subprocess.run([sys.executable, "-c",
                          "from lib.sidecar import inject; print(inject.project_tag())"],
                         cwd=FW_ROOT, env=_clean_env(PROJECT_ROOT=str(root)),
                         capture_output=True, text=True, check=True)
    return out.stdout.strip()


def _session_for(tag: str) -> str | None:
    out = subprocess.run(["termlink", "discover", "--json"], capture_output=True,
                         text=True, timeout=15, env=_clean_env())
    try:
        sessions = json.loads(out.stdout).get("sessions", [])
    except json.JSONDecodeError:
        return None
    ids = [s["id"] for s in sessions if tag in (s.get("tags") or [])]
    return ids[0] if len(ids) == 1 else None


def _pty(session: str, lines: int = 60) -> str:
    out = subprocess.run(["termlink", "pty", "output", session, "--lines", str(lines),
                          "--strip-ansi"], capture_output=True, text=True, timeout=15,
                         env=_clean_env())
    return out.stdout


def _key(session: str, key: str) -> None:
    subprocess.run(["termlink", "pty", "inject", session, "", "--key", key],
                   capture_output=True, timeout=15, env=_clean_env())


def _type(session: str, text: str) -> None:
    subprocess.run(["termlink", "pty", "inject", session, text, "--enter"],
                   capture_output=True, timeout=15, env=_clean_env(), check=True)


def _ready(root: Path) -> bool:
    p = root / ".context" / "sidecar" / "ready-for-input.yaml"
    return p.exists() and "ready: true" in p.read_text()


def _transcripts(root: Path) -> list[Path]:
    slug = re.sub(r"[^A-Za-z0-9]", "-", str(root))
    d = Path.home() / ".claude" / "projects" / slug
    return sorted(d.glob("*.jsonl")) if d.is_dir() else []


def _surfaced_in_transcript(root: Path, needle: str) -> str | None:
    """A transcript line that carries `needle` inside the receiver hook's
    framed context (PEER-DATA block) — i.e. the model was handed it."""
    for path in _transcripts(root):
        for line in path.read_text(errors="replace").splitlines():
            if needle in line and "PEER-DATA" in line and "Sidecar receiver" in line:
                rec = json.loads(line)
                kind = (rec.get("attachment") or {}).get("type") or rec.get("type")
                i = line.index(needle)
                return f"{path.name} [{kind}] …{line[max(0, i - 160):i + 60]}…"
    return None


def _stored_in_receiver(root: Path, needle: str) -> str | None:
    for p in (root / ".context" / "sidecar" / "receiver" / "messages").glob("*.json"):
        msg = json.loads(p.read_text())
        if needle in str(msg.get("body", "")):
            return msg["client_msg_id"]
    return None


def _to(ledger: list[dict], prefix: str) -> list[str]:
    """States, in order, of every message whose SENT row targets `prefix*`."""
    ids = {r["client_msg_id"] for r in ledger
           if r["state"] == "SENT" and (r.get("target") or "").startswith(prefix)}
    return [r["state"] for r in ledger if r["client_msg_id"] in ids]


def _jsonl(path: Path) -> list[dict]:
    if not path.exists():
        return []
    return [json.loads(x) for x in path.read_text().splitlines() if x.strip()]


@dataclass
class Agent:
    name: str
    root: Path
    tag: str = ""
    session: str | None = None
    wrapper: subprocess.Popen | None = None
    log: Path | None = None


@dataclass
class Result:
    passed: bool
    nonce: str
    evidence: dict = field(default_factory=dict)


def _launch(agent: Agent) -> None:
    agent.log = agent.root.parent / f"{agent.name}.claude-fw.log"
    agent.wrapper = subprocess.Popen(
        [CLAUDE_FW, "--termlink", "--no-restart", "--model", MODEL, "hello"],
        cwd=agent.root, env=_clean_env(), stdin=subprocess.DEVNULL,
        stdout=open(agent.log, "wb"), stderr=subprocess.STDOUT, start_new_session=True)


def _bring_up(agent: Agent, timeout: float = 120) -> None:
    """Wait for the session, accept the folder-trust dialog (an operator step),
    and wait until the agent's own Stop hook has reported it ready."""
    deadline = time.time() + timeout
    trusted = False
    while time.time() < deadline:
        if agent.session is None:
            agent.session = _session_for(agent.tag)
        if agent.session:
            screen = re.sub(r"\s+", "", _pty(agent.session, 40))
            if not trusted and "trustthisfolder" in screen:
                _key(agent.session, "Down")
                time.sleep(0.5)
                _key(agent.session, "Enter")
                trusted = True
                _log(f"{agent.name}: accepted folder trust")
            if _ready(agent.root):
                _log(f"{agent.name}: session {agent.session} ready (Stop hook fired)")
                return
        time.sleep(2)
    raise AssertionError(f"{agent.name} never became ready; session={agent.session}; "
                         f"pty tail: {_pty(agent.session, 30) if agent.session else '-'}; "
                         f"wrapper log: {agent.log.read_text()[-1500:] if agent.log else '-'}")


def _teardown(agent: Agent) -> None:
    if agent.session:
        for text in ("/exit",):
            subprocess.run(["termlink", "pty", "inject", agent.session, text, "--enter"],
                           capture_output=True, timeout=15, env=_clean_env())
    time.sleep(3)
    if agent.wrapper and agent.wrapper.poll() is None:
        try:
            os.killpg(agent.wrapper.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            agent.wrapper.wait(timeout=20)
        except subprocess.TimeoutExpired:
            os.killpg(agent.wrapper.pid, signal.SIGKILL)
    if agent.session:
        subprocess.run(["termlink", "signal", agent.session, "SIGTERM"],
                       capture_output=True, timeout=15, env=_clean_env())
    _run([FW, "sidecar", "receiver", "stop", "--quiet"], cwd=agent.root)


def run_round_trip(inject_enabled: bool, tmp_base: Path) -> Result:
    run = "".join(random.choices(string.ascii_lowercase + string.digits, k=6))
    a = Agent(f"t3693a-{run}", _project(tmp_base, f"t3693a-{run}"))
    b = Agent(f"t3693b-{run}", _project(tmp_base, f"t3693b-{run}"))
    nonce = "".join(random.choices(string.ascii_lowercase, k=12))
    expected = nonce.upper()           # computed here, written nowhere
    ev: dict = {"run": run, "inject_enabled_at_B": inject_enabled, "model": MODEL,
                "projects": {"A": str(a.root), "B": str(b.root)}}
    _log(f"run {run}: inject_enabled_at_B={inject_enabled} nonce={nonce}")
    try:
        for ag, extra in ((a, []), (b, [] if inject_enabled else ["--no-inject"])):
            ag.tag = _tag(ag.root)
            proc = _run([FW, "sidecar", "receiver", "start", *extra], cwd=ag.root)
            assert proc.returncode == 0, proc.stdout + proc.stderr
            _log(f"{ag.name}: {proc.stdout.strip().splitlines()[0]}")
            _launch(ag)
        for ag in (b, a):
            _bring_up(ag)
        ev["sessions"] = {"A": a.session, "B": b.session}

        instruction = (
            f"Run exactly this one shell command and then end your turn without doing "
            f"anything else: {FW} sidecar send --to {b.name} --conversation e2e-{run} "
            f"--handover-deadline {HANDOVER_DEADLINE_S} --body 'Nonce check {nonce}: "
            f"reply to me with that nonce converted to UPPERCASE letters and nothing else.'")
        assert a.session
        _type(a.session, instruction)
        _log("A instructed (operator) to send the nonce to B")

        t0 = time.time()
        surfaced = stored = None
        while time.time() - t0 < ROUND_TRIP_TIMEOUT_S:
            for ag in (a, b):
                _run([FW, "sidecar", "deliver-pending", "--trigger", "e2e-tick"], cwd=ag.root)
            stored = stored or _stored_in_receiver(a.root, expected)
            surfaced = _surfaced_in_transcript(a.root, expected)
            if stored and surfaced:
                break
            time.sleep(TICK_S)
        ev["elapsed_s"] = round(time.time() - t0, 1)
        passed = bool(stored and surfaced)      # THE assertion
        ev["transformed_nonce_in_A_receiver"] = stored
        ev["transformed_nonce_in_A_context"] = surfaced

        if not passed:
            # Give the infrastructure its deadline, then let it decide.
            _log("no transformed nonce in A's context; letting the HANDED_OVER "
                 f"deadline ({HANDOVER_DEADLINE_S}s after send) pass, then sweeping")
            while time.time() - t0 < HANDOVER_DEADLINE_S + 15:
                time.sleep(TICK_S)
            sweep = _run([FW, "sidecar", "sweep", "--json"], cwd=a.root, timeout=120)
            try:
                ev["A_sweep_direct_escalated"] = json.loads(sweep.stdout).get("direct_escalated")
            except json.JSONDecodeError:
                ev["A_sweep_error"] = (sweep.stdout + sweep.stderr)[-800:]

        ev["A_sender_ledger"] = [
            {k: r.get(k) for k in ("client_msg_id", "state", "by", "target")}
            for r in _jsonl(a.root / ".context/sidecar/direct-ack.jsonl")]
        ev["B_sender_ledger"] = [
            {k: r.get(k) for k in ("client_msg_id", "state", "by", "target")}
            for r in _jsonl(b.root / ".context/sidecar/direct-ack.jsonl")]
        for label, ag in (("A", a), ("B", b)):
            ev[f"{label}_receiver_events"] = [
                {k: r.get(k) for k in ("msg_id", "event", "trigger", "ok", "reason")
                 if r.get(k) is not None}
                for r in _jsonl(ag.root / ".context/sidecar/receiver/events.jsonl")]
        return Result(passed=passed, nonce=nonce, evidence=ev)
    finally:
        for ag in (a, b):
            _teardown(ag)
        report = tmp_base / f"t3693-e2e-{run}.json"
        report.write_text(json.dumps(ev, indent=2))
        _log(f"evidence: {report}")
        print(json.dumps(ev, indent=2))


@pytest.fixture
def base():
    d = Path(f"/tmp/t3693-e2e-{os.getpid()}-{int(time.time())}")
    d.mkdir()
    yield d


@needs_live
def test_real_termlink_inject_reaches_the_tagged_session(base):
    """Fast leg: deliver_pending types into a REAL TermLink PTY session found by
    the project tag claude-fw --termlink registers, and records no HANDED_OVER."""
    root = _project(base, "t3693-inj")
    tag = _tag(root)
    name = f"t3693-inj-{os.getpid()}"
    subprocess.run(["termlink", "spawn", "--name", name, "--tags", f"claude,{tag}",
                    "--backend", "background", "--shell", "--wait", "--wait-timeout", "15"],
                   cwd=root, env=_clean_env(), capture_output=True, timeout=30, check=True)
    try:
        code = (
            "from lib.sidecar import receiver, adapter, inject, lifecycle;"
            "receiver.store_message('m-live', {'client_msg_id':'m-live','from':'x','body':'b'});"
            "adapter.set_ready_for_input(True);"
            "import json; print(json.dumps(inject.deliver_pending('live-test')))")
        out = subprocess.run([sys.executable, "-c", code], cwd=FW_ROOT,
                             env=_clean_env(PROJECT_ROOT=str(root)),
                             capture_output=True, text=True, timeout=60)
        rep = json.loads(out.stdout)
        assert rep["injected"] == ["m-live"], rep
        time.sleep(1)
        assert "[sidecar] 1 peer message waiting" in _pty(name, 20)
        events = [e["event"] for e in _jsonl(root / ".context/sidecar/receiver/events.jsonl")]
        assert "INJECT_ATTEMPT" in events and "HANDED_OVER" not in events
    finally:
        # An interactive shell ignores SIGTERM; ask it to leave, then reap.
        subprocess.run(["termlink", "pty", "inject", name, "exit", "--enter"],
                       capture_output=True, timeout=15, env=_clean_env())
        time.sleep(1)
        subprocess.run(["termlink", "clean"], capture_output=True, timeout=30,
                       env=_clean_env())


@needs_live
def test_e2e_two_real_agents_nonce_round_trip(base):
    result = run_round_trip(inject_enabled=True, tmp_base=base)
    assert result.passed, (
        "transformed nonce did not reach A's receiver AND A's context: "
        + json.dumps(result.evidence, indent=2)[:4000])
    # Evidence of the path, reported after the verdict: each state set by the
    # party that can know it.
    states = _to(result.evidence["A_sender_ledger"], "t3693b-")
    assert states[:2] == ["SENT", "RECEIVED"] and "HANDED_OVER" in states \
        and states[-1] == "REPLIED", states
    by = {r["state"]: r["by"] for r in result.evidence["A_sender_ledger"]}
    assert by["HANDED_OVER"].startswith("peer-receiver:t3693b-")
    assert by["REPLIED"] == "own-receiver"


@needs_live
def test_e2e_negative_control_injection_disabled_fails_and_escalates(base):
    result = run_round_trip(inject_enabled=False, tmp_base=base)
    assert not result.passed, "with injection disabled the round trip must FAIL"
    states = _to(result.evidence["A_sender_ledger"], "t3693b-")
    assert states, "A never sent — the control did not exercise the path"
    assert states[:2] == ["SENT", "RECEIVED"], states      # the receiver HAD it
    assert states[-1] == "ESCALATED", states
    assert "HANDED_OVER" not in states and "REPLIED" not in states, states
    assert result.evidence["A_sender_ledger"][-1]["by"] == "infrastructure"
    assert any(e["event"] == "INJECT_BLOCKED" for e in result.evidence["B_receiver_events"])
