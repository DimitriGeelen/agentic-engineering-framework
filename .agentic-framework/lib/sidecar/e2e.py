"""arc-011 sidecar — live end-to-end harness (T-3423, slice 9).

Slices 1-8 each proved one hop in isolation. This module drives ALL of them
against the real thing — real TermLink hub, real `fw termlink dispatch`
worker, real `claude` process reading its inbox — and returns a verdict a
person can repeat: every hop checked from two sides (our ledger and the
hub's own topic state), a JSON record on disk, exit 0 only when the
blocking hops pass.

    H1  ledger      our consult row is INJECTED_*         (slice 2 semantics)
    H2  hub         inbox:<responder circuit> holds our client_msg_id (hub-side)
    H3  worker read the responder topic cursor advanced   (worker ran inbox)
    H4  hub         inbox:<sender circuit> holds the responder's ACK on our conversation
    H5  inbox       inbox.pending(sender) surfaces that ACK
    H6  worker exit fw termlink wait returned 0 and the result carries DONE
    A1  ambient     (--ambient only) H3+H4+H5 with a prompt that never
                    mentions consults — the T-3407 stanza alone carried it

Every collaborator is injectable so the state machine is unit-tested with
fakes; the live run is the same code with the real ones plugged in. A failed
hop is a recorded FAIL, never an exception out of run().
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import time
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path

from . import delivery, inbox, outbox
from . import termlink_transport as transport

NONCE_PREFIX = "SIDECAR-E2E"
ACK_PREFIX = "SIDECAR-E2E-ACK"
DONE_MARKER = "DONE"

HOPS = ("H1", "H2", "H3", "H4", "H5", "H6")
HOP_TITLES = {
    "H1": "ledger: consult row INJECTED_* (our side)",
    "H2": "hub: responder topic holds our client_msg_id",
    "H3": "worker read its inbox (responder cursor advanced)",
    "H4": "hub: sender topic holds the responder's ACK on our conversation",
    "H5": "inbox: sender's inbox surfaces the ACK",
    "H6": "worker exited 0 and its result carries DONE",
    "A1": "ambient: worker answered with NO consult instruction in its prompt",
}


@dataclass
class Config:
    task: str
    timeout: int = 300
    ambient: bool = False
    poll_interval: float = 5.0
    worker_timeout: int = 600
    peer: str | None = None          # T-3426: a real peer agent instead of a dispatched worker
    run_id: str = field(default_factory=lambda: uuid.uuid4().hex[:8])

    @property
    def sender(self) -> str:
        return f"e2e-{self.run_id}-sender"

    @property
    def responder(self) -> str:
        return self.peer if self.peer else f"e2e-{self.run_id}-responder"

    @property
    def mode(self) -> str:
        return "peer" if self.peer else ("ambient" if self.ambient else "explicit")

    def consult_body(self) -> str:
        """What the responder receives. A dispatched worker gets the bare
        nonce (its prompt explains it); a real peer gets the request in
        words, because nothing else we control will."""
        if not self.peer:
            return self.nonce
        return (f"{self.nonce} — joint end-to-end check of the peer-consult sidecar from "
                f"999-Agentic-Engineering-Framework (task {self.task}), now on the "
                f"inbox:<circuit-id> addressing our operator ruled on 2026-09-22 (T-3433). "
                f"Please reply on this conversation ({self.conversation_id}) with the text: "
                f"{self.ack}  — e.g. `fw sidecar send --to {self.sender} "
                f"--conversation {self.conversation_id} --body '{self.ack}'` or a channel post "
                f"to {inbox.inbox_topic(self.sender)} with metadata "
                f"conversation_id={self.conversation_id} and from_agent={self.peer}. "
                f"The legacy topic sidecar:{self.sender} is still drained for one release, so "
                f"a reply there counts too. Any reply carrying the run id counts.")

    @property
    def conversation_id(self) -> str:
        return f"e2e-{self.run_id}"

    @property
    def nonce(self) -> str:
        return f"{NONCE_PREFIX} {self.run_id}"

    @property
    def ack(self) -> str:
        return f"{ACK_PREFIX} {self.run_id}"

    def blocking_hops(self) -> tuple[str, ...]:
        # Peer mode: we control neither the peer's inbox read (H3) nor its
        # process exit (H6); the transport verdict is the four hub-visible hops.
        if self.peer:
            return ("H1", "H2", "H4", "H5")
        # In ambient mode the worker's reaction is the thing under observation,
        # not a transport property, so H3-H5 fold into the informative A1.
        return ("H1", "H2", "H6") if self.ambient else HOPS


# ── prompts ──────────────────────────────────────────────────────────────────

def explicit_prompt(cfg: Config) -> str:
    return (
        f"You are the RESPONDER in an automated end-to-end test of the AEF "
        f"peer-consult sidecar (task {cfg.task}, run {cfg.run_id}). Do exactly "
        f"this and nothing else — no tasks, no file edits, no commits:\n"
        f"1. Run:  bin/fw sidecar inbox --json\n"
        f"2. For every consult whose body contains \"{cfg.nonce}\", run:\n"
        f"   bin/fw sidecar send --to <its \"from\" field> "
        f"--conversation <its \"conversation_id\" field> --body \"{cfg.ack}\"\n"
        f"3. If step 1 printed an empty list, run `sleep 10` and go back to "
        f"step 1 — at most 8 times.\n"
        f"4. Print the single word {DONE_MARKER} as the last line of your final message.\n"
    )


def ambient_prompt(cfg: Config) -> str:
    # Deliberately says nothing about consults, inboxes or replies.
    #
    # No `sleep` in this job: live run 7e013402 backgrounded `sleep 45`,
    # ended its turn "waiting to be notified", and never printed DONE — a
    # headless `claude -p` has no next turn. The un-instructed inbox read
    # comes from the dispatch stanza's yield-point rule, not from idle time.
    return (
        f"You are a worker in an automated framework test (task {cfg.task}, "
        f"run {cfg.run_id}). Your only job: run `date -u` and report the "
        f"output, then print the single word {DONE_MARKER} as the last line "
        f"of your final message. Do not create tasks, edit files, or commit.\n"
    )


# ── real collaborators ───────────────────────────────────────────────────────

def _fw_bin() -> str:
    env = os.environ.get("FW_BIN")
    if env:
        return env
    return str(outbox._root() / "bin" / "fw")


def real_send(sender: str, responder: str, body: str, conversation_id: str):
    cmid = outbox.write_message(from_id=sender, to=responder, body=body,
                                conversation_id=conversation_id)
    return delivery.deliver(cmid, transport.termlink_transport, transport.probe_hub)


def real_dispatch(name: str, task: str, prompt_path: str, timeout: int) -> tuple[int, str]:
    proc = subprocess.run(
        [_fw_bin(), "termlink", "dispatch", "--task", task, "--name", name,
         "--prompt-file", prompt_path, "--timeout", str(timeout)],
        capture_output=True, text=True, timeout=120)
    return proc.returncode, (proc.stdout or "") + (proc.stderr or "")


def real_wait(name: str, timeout: int) -> tuple[int, str]:
    try:
        proc = subprocess.run(
            [_fw_bin(), "termlink", "wait", "--name", name, "--timeout", str(timeout)],
            capture_output=True, text=True, timeout=timeout + 60)
    except subprocess.TimeoutExpired:
        return 124, "fw termlink wait: harness-side timeout"
    return proc.returncode, (proc.stdout or "") + (proc.stderr or "")


def real_result(name: str) -> str:
    proc = subprocess.run([_fw_bin(), "termlink", "result", name],
                          capture_output=True, text=True, timeout=30)
    return proc.stdout or ""


def real_hub_messages(topic: str, cursor: int = 0, limit: int = 200) -> list[dict]:
    try:
        return inbox.default_reader(topic, cursor, limit)
    except Exception as exc:  # hub errors are evidence, not crashes
        return [{"_error": str(exc)}]


def real_inbox(sender: str) -> list[dict]:
    return inbox.pending(sender, advance=True)


def real_cursor(topic: str) -> int:
    return int(inbox.load_state().get("topics", {}).get(topic, {}).get("cursor", 0) or 0)


# ── the run ──────────────────────────────────────────────────────────────────

def _hop(report: dict, hop: str, ok: bool, detail: str) -> None:
    report["hops"][hop] = {"ok": bool(ok), "title": HOP_TITLES[hop], "detail": detail}


def _skip_rest(report: dict, hops, reason: str) -> None:
    for h in hops:
        if h not in report["hops"]:
            _hop(report, h, False, f"not attempted: {reason}")


def _decoded_body(env: dict) -> str:
    try:
        return inbox._decode(env)
    except Exception:
        return ""


def is_ack(cfg: Config, *, sender: str | None, conversation_id: str | None, body: str | None) -> bool:
    """Does a message count as the responder's answer to our consult?

    The conversation id must match and the message must come from the
    responder. The body must carry the run id — the exact `SIDECAR-E2E-ACK
    <run>` token is what the explicit prompt asks for, but an UN-instructed
    worker phrases its own answer: live run 0153e35a replied
    `ack SIDECAR-E2E 0153e35a` on the right conversation and the first
    matcher (exact token only) scored it as no answer. A false negative in
    the ambient measurement is worse than a loose match, because the whole
    point of A1 is to count real answers.
    """
    if conversation_id != cfg.conversation_id:
        return False
    if sender and sender != cfg.responder:
        return False
    text = body or ""
    return cfg.ack in text or cfg.run_id in text


def run(cfg: Config, *, send=real_send, dispatch=real_dispatch, wait=real_wait,
        result=real_result, hub_messages=real_hub_messages, read_inbox=real_inbox,
        cursor=real_cursor, sleep=time.sleep, now=time.monotonic,
        prompt_dir: Path | None = None) -> dict:
    t0 = now()
    report: dict = {
        "run_id": cfg.run_id,
        "task": cfg.task,
        "mode": cfg.mode,
        "peer": cfg.peer,
        "sender": cfg.sender,
        "responder": cfg.responder,
        "conversation_id": cfg.conversation_id,
        "started_at": datetime.now(timezone.utc).isoformat(),
        "hops": {},
        "timings": {},
        "verdict": "FAIL",
    }
    responder_topic = inbox.inbox_topic(cfg.responder)
    sender_topic = inbox.inbox_topic(cfg.sender)
    # T-3433: the sidecar: alias is a READ alias for one release, so a peer
    # that has not switched yet still lands somewhere we look. The record
    # names every topic the run touched — a verdict whose addresses are not
    # written down cannot be repeated.
    responder_topics = [responder_topic] + inbox.legacy_topics(cfg.responder)
    sender_topics = [sender_topic] + inbox.legacy_topics(cfg.sender)
    report["topics"] = {"responder": responder_topics, "sender": sender_topics}

    # 1. send the consult
    cmid = None
    try:
        res = send(cfg.sender, cfg.responder, cfg.consult_body(), cfg.conversation_id)
        cmid = res.client_msg_id
        report["client_msg_id"] = cmid
        report["timings"]["sent"] = round(now() - t0, 2)
        injected = res.delivered and res.state in (outbox.INJECTED_NOW, outbox.INJECTED_LATER)
        _hop(report, "H1", injected,
             f"state={res.state} delivered={res.delivered}"
             + (f" reason={res.reason}" if res.reason else ""))
    except Exception as exc:
        _hop(report, "H1", False, f"send raised: {exc}")
        _skip_rest(report, HOPS, "send failed")
        return _finish(report, cfg, t0, now)

    # 2. dispatch the responder — unless it is a real peer we do not control
    if cfg.peer:
        _hop(report, "H3", True, f"not applicable: {cfg.peer} owns its inbox read (peer mode)")
        _hop(report, "H6", True, f"not applicable: {cfg.peer} owns its process (peer mode)")
        report["dispatch"] = {"rc": None, "tail": "skipped: peer mode"}
    else:
        prompt = ambient_prompt(cfg) if cfg.ambient else explicit_prompt(cfg)
        pdir = prompt_dir or (outbox._root() / ".context" / "sidecar" / "e2e")
        pdir.mkdir(parents=True, exist_ok=True)
        prompt_path = pdir / f"{cfg.run_id}-prompt.md"
        prompt_path.write_text(prompt, encoding="utf-8")
        try:
            rc, out = dispatch(cfg.responder, cfg.task, str(prompt_path), cfg.worker_timeout)
        except Exception as exc:
            rc, out = 1, f"dispatch raised: {exc}"
        report["timings"]["dispatched"] = round(now() - t0, 2)
        report["dispatch"] = {"rc": rc, "tail": out[-600:]}
        if rc != 0:
            _skip_rest(report, ("H3", "H4", "H5", "H6"), f"dispatch rc={rc}")
            # H2 is still worth asking: the hub may hold our message regardless.
            _check_h2(report, hub_messages, responder_topics, cmid)
            return _finish(report, cfg, t0, now)

    # 3. wait for the ACK on the sender's inbox
    deadline = t0 + cfg.timeout
    reply = None
    polls = 0
    while now() < deadline:
        polls += 1
        try:
            for msg in read_inbox(cfg.sender):
                if is_ack(cfg, sender=msg.get("from"), conversation_id=msg.get("conversation_id"),
                          body=msg.get("body")):
                    reply = msg
                    break
        except Exception as exc:
            report.setdefault("inbox_errors", []).append(str(exc))
        if reply:
            report["timings"]["reply_seen"] = round(now() - t0, 2)
            break
        sleep(cfg.poll_interval)
    report["polls"] = polls
    _hop(report, "H5", reply is not None,
         f"reply from {reply.get('from')} @{reply.get('offset')}" if reply
         else f"no ACK on {sender_topic} within {cfg.timeout}s ({polls} polls)")

    # 4. hub-side evidence, both directions
    _check_h2(report, hub_messages, responder_topics, cmid)
    sender_msgs = [m for topic in sender_topics for m in hub_messages(topic, 0, 200)]
    acks = [m for m in sender_msgs
            if is_ack(cfg, sender=(m.get("metadata") or {}).get("from_agent"),
                      conversation_id=(m.get("metadata") or {}).get("conversation_id"),
                      body=_decoded_body(m))]
    errs = [m["_error"] for m in sender_msgs if "_error" in m]
    _hop(report, "H4", bool(acks),
         f"{len(acks)} ACK envelope(s) on {' or '.join(sender_topics)}"
         + (f" from_agent={(acks[0].get('metadata') or {}).get('from_agent')}" if acks else "")
         + (f" hub_error={errs[0]}" if errs else ""))

    if cfg.peer:
        return _finish(report, cfg, t0, now)

    # 5. did the worker read its inbox?
    try:
        cur = cursor(responder_topic)
    except Exception as exc:
        cur, cur_err = 0, str(exc)
    else:
        cur_err = ""
    _hop(report, "H3", cur > 0, f"{responder_topic} cursor={cur}" + (f" error={cur_err}" if cur_err else ""))

    # 6. worker exit + DONE
    remaining = max(60, int(deadline - now()))
    try:
        wrc, wout = wait(cfg.responder, remaining)
    except Exception as exc:
        wrc, wout = 1, f"wait raised: {exc}"
    report["timings"]["worker_exit"] = round(now() - t0, 2)
    try:
        text = result(cfg.responder)
    except Exception as exc:
        text = ""
        wout += f" result raised: {exc}"
    has_done = DONE_MARKER in text
    report["worker"] = {"wait_rc": wrc, "wait_tail": wout[-300:], "result_tail": text[-300:]}
    _hop(report, "H6", wrc == 0 and has_done,
         f"wait rc={wrc} DONE={'yes' if has_done else 'no'}")

    if cfg.ambient:
        h = report["hops"]
        a1 = h["H3"]["ok"] and h["H4"]["ok"] and h["H5"]["ok"]
        _hop(report, "A1", a1,
             "worker read inbox, answered, and the answer arrived — with no consult instruction"
             if a1 else "un-instructed worker did not complete the round trip "
                       f"(H3={h['H3']['ok']} H4={h['H4']['ok']} H5={h['H5']['ok']})")

    return _finish(report, cfg, t0, now)


def _check_h2(report, hub_messages, responder_topics, cmid) -> None:
    if isinstance(responder_topics, str):
        responder_topics = [responder_topics]
    msgs = [m for topic in responder_topics for m in hub_messages(topic, 0, 200)]
    hits = [m for m in msgs if (m.get("metadata") or {}).get("client_msg_id") == cmid]
    errs = [m["_error"] for m in msgs if "_error" in m]
    _hop(report, "H2", bool(hits),
         f"{len(hits)} envelope(s) with our client_msg_id on "
         f"{' or '.join(responder_topics)}"
         + (f" @{hits[0].get('offset')}" if hits else "")
         + (f" hub_error={errs[0]}" if errs else ""))


def _finish(report: dict, cfg: Config, t0: float, now) -> dict:
    for h in HOPS:
        if h not in report["hops"]:
            _hop(report, h, False, "not attempted")
    blocking = cfg.blocking_hops()
    report["blocking_hops"] = list(blocking)
    report["verdict"] = "PASS" if all(report["hops"][h]["ok"] for h in blocking) else "FAIL"
    report["timings"]["total"] = round(now() - t0, 2)
    report["finished_at"] = datetime.now(timezone.utc).isoformat()
    return report


# ── persistence + rendering ─────────────────────────────────────────────────

def report_dir() -> Path:
    d = outbox._root() / ".context" / "sidecar" / "e2e"
    d.mkdir(parents=True, exist_ok=True)
    return d


def write_report(report: dict, directory: Path | None = None) -> Path:
    d = directory or report_dir()
    d.mkdir(parents=True, exist_ok=True)
    path = d / f"{report['run_id']}.json"
    tmp = path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(report, indent=2, sort_keys=True), encoding="utf-8")
    os.replace(tmp, path)
    return path


def render(report: dict) -> str:
    lines = [f"sidecar e2e  run={report['run_id']}  mode={report['mode']}  "
             f"task={report['task']}",
             f"  sender={report['sender']}  responder={report['responder']}"]
    topics = report.get("topics") or {}
    for role in ("sender", "responder"):
        if topics.get(role):
            lines.append(f"  {role} topic: {topics[role][0]}"
                         + (f"   (+ alias {topics[role][1]})" if len(topics[role]) > 1 else ""))
    order = list(HOPS) + (["A1"] if "A1" in report["hops"] else [])
    blocking = set(report.get("blocking_hops", []))
    for h in order:
        hop = report["hops"][h]
        if hop["detail"].startswith("not applicable"):
            mark, tag = "n/a ", ""
        else:
            mark = "PASS" if hop["ok"] else "FAIL"
            tag = "" if h in blocking or h == "A1" else " (informative)"
        lines.append(f"  [{mark}] {h}  {hop['title']}{tag}")
        lines.append(f"         {hop['detail']}")
    t = report.get("timings", {})
    lines.append("  timings: " + ", ".join(f"{k}={v}s" for k, v in t.items()))
    lines.append(f"  verdict: {report['verdict']}")
    return "\n".join(lines)


def preflight() -> tuple[bool, str]:
    """Cheap checks before spending a real worker. (ok, reason)."""
    if not shutil.which(transport.DEFAULT_BINARY if hasattr(transport, "DEFAULT_BINARY") else "termlink"):
        return False, "termlink binary not on PATH"
    probe = transport.probe_hub(None)
    if not probe.ok:
        return False, f"local hub probe refused: {probe.reason}"
    return True, "termlink present, local hub probe ok"


def focused_task(root: Path | None = None) -> str | None:
    f = (root or outbox._root()) / ".context" / "working" / "focus.yaml"
    try:
        for line in f.read_text(encoding="utf-8").splitlines():
            if line.startswith("current_task:"):
                val = line.split(":", 1)[1].strip().strip('"').strip("'")
                return val if val and val != "null" else None
    except OSError:
        return None
    return None
