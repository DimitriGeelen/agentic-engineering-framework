#!/usr/bin/env python3
"""Local backend of the shared dispatched-worker contract, wc/0.3.3 (T-4802).

The §6.2 dispatch-records store: one JSON record per dispatch, every write under
an exclusive flock, crash-atomic by temp file + fsync + rename + directory fsync.
It implements the §3 transition table (T1, T2, T3, T3b, T-RECLAIM, T4, T5, T6,
T6b, T7a-T7d, T8), the closed fence_reject list, per-attempt fencing, the no-overlap
rule of §4.3 and the §3.3 outcome derivation with refusal ahead of rule 1.

Scope (T-4801 option A): store plus conformance adapter only. Nothing in
`fw termlink dispatch` or run.sh writes these records yet, and the evaluation
ledger (dispatches.jsonl, dispatch-outcomes.jsonl) is untouched (T-4435 cond. 4).

Not implemented, on purpose:
- the answer channel (§5): questions can be appended (they are fenced like any
  running-path write), answers, waits and acks are not;
- registry_epoch (I7): the local backend has no registry; its `lost` comes from
  a liveness probe plus absence of evidence after G (§6.3);
- dispatch closure (v0.3.4 draft §4.7): dispatches stay open, as on the hub.

Time, the lock clock, the liveness probe and the worker-dir evidence reader are
all injected, so tests never sleep and never touch real processes.

Standard library only.
"""
from __future__ import annotations

import copy
import errno
import fcntl
import hashlib
import hmac
import json
import os
import re
import secrets
import shutil
import tempfile
import threading
import time
from pathlib import Path

CONTRACT_VERSION = "wc/0.3"
BACKEND = "local"

STATES = ("dispatched", "running", "done", "lost", "unknown")
OUTCOMES = ("succeeded", "failed", "refused", "handback-malformed", "paused")
FENCE_REASONS = ("stale_attempt", "bad_nonce", "bad_credential", "stale_gen",
                 "cas_mismatch", "forbidden_transition", "done_conflict", "dispatch_closed")
STOP_CAUSES = ("deadline_stop", "revoked", "operator_stop")
TERMINAL = ("done", "lost")
RANK = {"dispatched": 0, "running": 1, "unknown": 2, "lost": 3, "done": 4}
# §3.3 "Forbidden (all rejected)". Any other from-state the table has no row for is cas_mismatch.
FORBIDDEN = {("done", "lost"), ("done", "running"), ("lost", "running"), ("lost", "unknown"),
             ("done", "unknown")}

_CROCKFORD = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
DISPATCH_ID_RE = re.compile(r"^D-[0-9A-HJKMNP-TV-Z]{26}$")

#: Per-backend parameters (§2). G is the grace before a probe-confirmed end becomes
#: `lost`; the deadlines are durations from T1 (dispatched) and T2 (running).
DEFAULTS = {
    "G": 120,
    "deadline_dispatched": 60 + 120,      # spawn timeout + G
    "deadline_running": 3600 + 600,       # worker timeout + 10 min
    "lock_timeout": 10,
}


class LockTimeout(Exception):
    pass


def _sha256(text: str) -> str:
    return hashlib.sha256(text.encode()).hexdigest()


def canonical(obj) -> str:
    return json.dumps(obj, sort_keys=True, separators=(",", ":"))


def new_dispatch_id(now_ms: int | None = None) -> str:
    """A fresh D-<ulid>: 48-bit millisecond time + 80 random bits, Crockford base32."""
    ms = int(time.time() * 1000) if now_ms is None else now_ms
    value = (ms & ((1 << 48) - 1)) << 80 | secrets.randbits(80)
    chars = []
    for _ in range(26):
        chars.append(_CROCKFORD[value & 31])
        value >>= 5
    return "D-" + "".join(reversed(chars))


# ── signed completion (§6.5) ───────────────────────────────────────────────
def sign_completion(evidence: dict, key: bytes) -> dict:
    """Return a copy of `evidence` carrying an HMAC-SHA256 signature over its other fields."""
    body = {k: v for k, v in evidence.items() if k != "signature"}
    return {**body, "signature": hmac.new(key, canonical(body).encode(), "sha256").hexdigest()}


def signature_valid(evidence: dict, key: bytes | None) -> bool:
    if not key or not isinstance(evidence, dict) or not isinstance(evidence.get("signature"), str):
        return False
    want = sign_completion(evidence, key)["signature"]
    return hmac.compare_digest(want, evidence["signature"])


def derive_outcome(evidence: dict, dispatch_id: str, attempt: int, nonce_sha256: str) -> str:
    """§3.3 outcome derivation, in the order all three parties run (refusal first, v0.3.4 item 1)."""
    if evidence.get("supervisor_refused"):
        return "refused"
    hb = evidence.get("handback")
    if (not isinstance(hb, dict)
            or hb.get("commission") != dispatch_id
            or hb.get("attempt") != attempt
            or not isinstance(hb.get("nonce"), str)
            or not hmac.compare_digest(_sha256(hb["nonce"]), nonce_sha256)
            or hb.get("status") not in ("complete", "blocked", "paused", "failed")):
        return "handback-malformed"
    exit_code = evidence.get("exit_code")
    if exit_code != 0 or hb.get("status") == "failed":
        return "failed"
    if hb.get("status") == "paused":
        return "paused"
    return "succeeded"


def worker_dir_reader(base: str | Path):
    """Evidence reader for `<base>/<dispatch_id>/a<attempt>/completion.json` (the §6.5 worker dir)."""
    base = Path(base)

    def read(dispatch_id: str, attempt: int):
        path = base / dispatch_id / f"a{attempt}" / "completion.json"
        try:
            return json.loads(path.read_text())
        except (OSError, ValueError):
            return None
    return read


# ── outcomes of a write ────────────────────────────────────────────────────
def _accepted(transition, notices=0, **values):
    out = {"ok": True, "accepted": transition, "notices": notices}
    if values:
        out["values"] = values
    return out


def _fence(reason, notices=0):
    return {"fence_reject": reason, "notices": notices}


def _none(notices=0, **values):
    out = {"ok": True, "no_transition": True, "notices": notices}
    if values:
        out["values"] = values
    return out


class _Reject(Exception):
    def __init__(self, result):
        super().__init__(result)
        self.result = result


class Store:
    """The §6.2 store. Every public write returns a result mapping and never raises on a refusal."""

    def __init__(self, root: str | Path = ".context/dispatch-records", *, signing_key: bytes | None = None,
                 clock=None, monotonic=None, sleep=None, evidence_reader=None, params: dict | None = None):
        self.root = Path(root)
        self.root.mkdir(parents=True, exist_ok=True)
        self.key = signing_key
        self.clock = clock or (lambda: int(time.time()))
        self.monotonic = monotonic or time.monotonic
        self.sleep = sleep or time.sleep
        self.read_evidence = evidence_reader or (lambda dispatch_id, attempt: None)
        self.params = {**DEFAULTS, **(params or {})}

    # ── storage mechanics ──────────────────────────────────────────────
    def _path(self, dispatch_id: str) -> Path:
        if not DISPATCH_ID_RE.match(dispatch_id):
            raise ValueError(f"malformed dispatch id {dispatch_id!r}")
        return self.root / f"{dispatch_id}.json"

    def _acquire(self, dispatch_id: str, timeout: float):
        fd = os.open(self.root / f"{dispatch_id}.lock", os.O_RDWR | os.O_CREAT, 0o600)
        deadline = self.monotonic() + timeout
        while True:
            try:
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
                return fd
            except OSError as exc:
                if exc.errno not in (errno.EAGAIN, errno.EACCES):
                    os.close(fd)
                    raise
            if self.monotonic() >= deadline:
                os.close(fd)
                raise LockTimeout(dispatch_id)
            self.sleep(0.05)

    def _release(self, fd):
        try:
            fcntl.flock(fd, fcntl.LOCK_UN)
        finally:
            os.close(fd)

    def _write(self, record: dict):
        path = self._path(record["dispatch_id"])
        fd, tmp = tempfile.mkstemp(prefix=f".{path.stem}.", suffix=".tmp", dir=self.root)
        # a crash before the rename leaves at most a stray temp file; the record is never half-written
        with os.fdopen(fd, "w") as fh:
            fh.write(json.dumps(record, indent=1, sort_keys=True))
            fh.flush()
            os.fsync(fh.fileno())
        os.replace(tmp, path)
        dfd = os.open(self.root, os.O_RDONLY)
        try:
            os.fsync(dfd)
        finally:
            os.close(dfd)

    def load(self, dispatch_id: str) -> dict | None:
        try:
            return json.loads(self._path(dispatch_id).read_text())
        except FileNotFoundError:
            return None

    def dispatch_ids(self) -> list[str]:
        return sorted(p.stem for p in self.root.glob("D-*.json"))

    def _mutate(self, dispatch_id: str, fn, *, create: bool = False):
        """Lock, read, apply `fn(record) -> result`, write if fn marked the record changed, release.

        A lock timeout fails closed as fence_reject(cas_mismatch) (§6.2)."""
        try:
            fd = self._acquire(dispatch_id, self.params["lock_timeout"])
        except LockTimeout:
            return _fence("cas_mismatch")
        try:
            record = self.load(dispatch_id)
            if record is None and not create:
                return {"error": "no_such_dispatch"}
            box = {"changed": False}
            try:
                result = fn(record, box)
            except _Reject as rej:
                result = rej.result
                if rej.result.get("_log") and record is not None:
                    box["changed"] = True
            if box.get("record") is not None:
                record = box["record"]
            if box["changed"]:
                self._write(record)
            result.pop("_log", None)
            return result
        finally:
            self._release(fd)

    # ── helpers on a loaded record ─────────────────────────────────────
    def _notice(self, record, kind, attempt, **detail):
        record.setdefault("notices", []).append(
            {"kind": kind, "attempt": attempt, "ts": self.clock(), **detail})

    def _log_reject(self, record, attempt, reason, writer, op, notice=None):
        """A fence_reject is a response, logged at dispatch level so no attempt changes (§3.3)."""
        record.setdefault("fence_log", []).append(
            {"attempt": attempt, "reason": reason, "writer": writer, "op": op, "ts": self.clock()})
        notices = 0
        if notice:
            self._notice(record, notice, attempt, reason=reason)
            notices = 1
        return {**_fence(reason, notices), "_log": True}

    def _attempt(self, record, n):
        if not isinstance(n, int) or n < 1 or n > len(record["attempts"]):
            return None
        return record["attempts"][n - 1]

    def _new_attempt(self, record) -> tuple[dict, str, str]:
        n = len(record["attempts"]) + 1
        nonce, token = secrets.token_hex(16), secrets.token_hex(32)
        now = self.clock()
        did = record["dispatch_id"]
        att = {
            "attempt": n, "nonce_sha256": _sha256(nonce), "token_sha256": _sha256(token),
            "state": "dispatched", "outcome": None, "worker_kind": None,
            "session_binding": {"worker_binding": f"{did}:{n}", "session_name": f"tl-{did}-a{n}"},
            "attempt_dispatch_ref": None, "attested": False, "attested_by": None,
            "supervisor_gen": 1, "exit_code": None, "result": None, "handback": None,
            "evidence_digest": None, "history": [], "questions": [], "answers": [],
            "deadline_dispatched": now + self.params["deadline_dispatched"], "deadline_running": None,
            "probe": {"seen_alive": False, "absent_since": None}, "pending_cause": None,
        }
        self._move(att, "dispatched", "hub", "T1")
        record["attempts"].append(att)
        return att, nonce, token

    def _move(self, att, to, writer, transition, **extra):
        """Append one accepted transition (I1). Rank is checked by the callers' CAS rows."""
        entry = {"from": att["state"] if att["history"] else None, "to": to, "writer": writer,
                 "ts": self.clock(), "transition": transition}
        if att.get("pending_cause") and to in ("done", "lost"):
            entry["cause"] = att["pending_cause"]
            att["pending_cause"] = None
        entry.update({k: v for k, v in extra.items() if v is not None})
        att["history"].append(entry)
        att["state"] = to
        if to != "done":
            att["outcome"] = None
        if to in ("running", "unknown", "lost", "done"):
            att["probe"]["absent_since"] = None

    def _check_proof(self, record, att, *, nonce, credential, writer, op, gen=None,
                     running_path=False, lifecycle=True, backend=None):
        """The fence of §3.3 in its fixed order. Raises _Reject; returns nothing on success."""
        if backend is not None and backend != record["backend"]:
            raise _Reject({"refused": "backend_fixed", "notices": 0})
        n = att["attempt"]
        if running_path and n != len(record["attempts"]):
            raise _Reject(self._log_reject(record, n, "stale_attempt", writer, op))
        if not isinstance(nonce, str) or not hmac.compare_digest(_sha256(nonce), att["nonce_sha256"]):
            raise _Reject(self._log_reject(record, n, "bad_nonce", writer, op))
        if lifecycle:
            if writer == "worker" or not isinstance(credential, str) \
                    or not hmac.compare_digest(_sha256(credential), att["token_sha256"]):
                raise _Reject(self._log_reject(record, n, "bad_credential", writer, op))
            if writer == "supervisor" and gen is not None and gen != att["supervisor_gen"]:
                raise _Reject(self._log_reject(record, n, "stale_gen", writer, op))

    def _cas_fail(self, record, att, to, writer, op):
        reason = "forbidden_transition" if (att["state"], to) in FORBIDDEN else "cas_mismatch"
        raise _Reject(self._log_reject(record, att["attempt"], reason, writer, op))

    # ── evidence ───────────────────────────────────────────────────────
    def _bound(self, record, att, evidence) -> bool:
        """A signed completion bound to (dispatch_id, attempt, nonce) (§6.5, T7d's 'evidence')."""
        return (isinstance(evidence, dict) and signature_valid(evidence, self.key)
                and evidence.get("dispatch_id") == record["dispatch_id"]
                and evidence.get("attempt") == att["attempt"]
                and isinstance(evidence.get("nonce"), str)
                and hmac.compare_digest(_sha256(evidence["nonce"]), att["nonce_sha256"]))

    def _finish(self, record, att, evidence, writer, transition):
        """Write `done{outcome}` from verified evidence (I2, I5)."""
        outcome = derive_outcome(evidence, record["dispatch_id"], att["attempt"], att["nonce_sha256"])
        hb = evidence.get("handback") if isinstance(evidence.get("handback"), dict) else None
        digest = _sha256(canonical(evidence))
        self._move(att, "done", writer, transition, evidence_digest=digest)
        att["outcome"] = outcome
        att["exit_code"] = evidence.get("exit_code")
        att["handback"] = hb
        att["evidence_digest"] = digest
        att["result"] = ({"kind": "handback_sha256", "value": _sha256(canonical(hb)),
                          "persisted_at": evidence.get("persisted_at")} if hb else
                         {"kind": "none", "value": None, "persisted_at": evidence.get("persisted_at")})
        return outcome

    def _complete_from_state(self, record, att, evidence, writer, op):
        """§3.3: the transition a completion takes is chosen by the attempt's own state."""
        state = att["state"]
        n = att["attempt"]
        if state == "done":
            if att.get("evidence_digest") == _sha256(canonical(evidence)):
                return {"ok": True, "response": "T8", "notices": 0}
            raise _Reject(self._log_reject(record, n, "done_conflict", writer, op, notice="done_conflict"))
        if state == "lost":
            lost_ts = max(e["ts"] for e in att["history"] if e["to"] == "lost")
            persisted = evidence.get("persisted_at")
            if not isinstance(persisted, (int, float)) or persisted > lost_ts:
                raise _Reject(self._log_reject(record, n, "forbidden_transition", writer, op,
                                               notice="late_evidence"))
            self._finish(record, att, evidence, writer, "T5")
            return _accepted("T5")
        transition = {"running": "T3", "dispatched": "T3b", "unknown": "T7b"}[state]
        self._finish(record, att, evidence, writer, transition)
        return _accepted(transition)

    # ── T1: create and allocate ────────────────────────────────────────
    def create(self, *, dispatch_id: str | None = None, dispatcher: dict | None = None,
               retry_of_dispatch_id: str | None = None, task_id: str | None = None,
               worker_kind: str | None = None) -> dict:
        """New dispatch plus attempt 1 (T1). A caller-chosen id is used as given or refused (§4.1)."""
        if dispatch_id is None:
            dispatch_id = new_dispatch_id()
        elif not isinstance(dispatch_id, str) or not DISPATCH_ID_RE.match(dispatch_id):
            return {"error": "malformed_id", "values": {"substituted_id": None}}

        def fn(record, box):
            if record is not None:
                return {"error": "id_taken", "values": {"substituted_id": None}}
            record = {
                "contract_version": CONTRACT_VERSION, "dispatch_id": dispatch_id, "backend": BACKEND,
                "task_id": task_id, "retry_of_dispatch_id": retry_of_dispatch_id, "closed": None,
                "dispatcher": {"project_agent": None, "session": None, "claude_session_id": None,
                               **(dispatcher or {})},
                "created_at": self.clock(), "attempts": [], "notices": [], "fence_log": [],
                "observations": [],
            }
            att, nonce, token = self._new_attempt(record)
            att["worker_kind"] = worker_kind
            box["record"], box["changed"] = record, True
            return _accepted("T1", dispatch_id=dispatch_id, attempt=1, nonce=nonce,
                             supervisor_token=token, fresh_nonce=True)
        return self._mutate(dispatch_id, fn, create=True)

    def allocate(self, dispatch_id: str, *, worker_kind: str | None = None) -> dict:
        """Attempt N+1 (T1), only when attempt N is done or lost (§4.3). Dispatches are never closed."""
        def fn(record, box):
            last = record["attempts"][-1] if record["attempts"] else None
            if last is not None and last["state"] not in TERMINAL:
                raise _Reject(self._log_reject(record, last["attempt"], "cas_mismatch", "dispatcher", "allocate"))
            used = {a["nonce_sha256"] for a in record["attempts"]}
            att, nonce, token = self._new_attempt(record)
            att["worker_kind"] = worker_kind
            box["changed"] = True
            return _accepted("T1", dispatch_id=dispatch_id, attempt=att["attempt"], nonce=nonce,
                             supervisor_token=token, fresh_nonce=att["nonce_sha256"] not in used)
        return self._mutate(dispatch_id, fn)

    # ── supervisor running-path writes ─────────────────────────────────
    def start(self, dispatch_id, attempt, *, nonce, credential, writer="supervisor", supervisor_gen=None,
              backend=None) -> dict:
        """T2 dispatched -> running."""
        def fn(record, box):
            att = self._attempt(record, attempt)
            if att is None:
                raise _Reject(_fence("stale_attempt"))
            self._check_proof(record, att, nonce=nonce, credential=credential, writer=writer, op="start",
                              gen=supervisor_gen, running_path=True, backend=backend)
            if att["state"] != "dispatched":
                self._cas_fail(record, att, "running", writer, "start")
            self._move(att, "running", writer, "T2")
            att["probe"]["seen_alive"] = True
            att["deadline_running"] = self.clock() + self.params["deadline_running"]
            box["changed"] = True
            return _accepted("T2")
        return self._mutate(dispatch_id, fn)

    def reclaim(self, dispatch_id, attempt, *, nonce, credential, supervisor_gen, writer="supervisor",
                backend=None) -> dict:
        """T-RECLAIM running -> running with supervisor_gen = prev + 1."""
        def fn(record, box):
            att = self._attempt(record, attempt)
            if att is None:
                raise _Reject(_fence("stale_attempt"))
            self._check_proof(record, att, nonce=nonce, credential=credential, writer=writer, op="reclaim",
                              running_path=True, backend=backend)
            if att["state"] != "running":
                self._cas_fail(record, att, "running", writer, "reclaim")
            if supervisor_gen != att["supervisor_gen"] + 1:
                raise _Reject(self._log_reject(record, attempt, "stale_gen", writer, "reclaim"))
            att["supervisor_gen"] = supervisor_gen
            self._move(att, "running", writer, "T-RECLAIM", supervisor_gen=supervisor_gen)
            box["changed"] = True
            return _accepted("T-RECLAIM")
        return self._mutate(dispatch_id, fn)

    def stop(self, dispatch_id, attempt, *, cause) -> dict:
        """A backend stop is an action, not a state: the next terminal history entry carries `cause`."""
        if cause not in STOP_CAUSES:
            return {"error": "bad_cause"}

        def fn(record, box):
            att = self._attempt(record, attempt)
            if att is None or att["state"] in TERMINAL:
                return _none()
            att["pending_cause"] = cause
            box["changed"] = True
            return {"ok": True, "notices": 0}
        return self._mutate(dispatch_id, fn)

    def append_question(self, dispatch_id, attempt, *, nonce, question_id, body, writer="worker") -> dict:
        """Worker-permitted field: fenced by attempt and nonce only (§3.2, §5.2)."""
        def fn(record, box):
            att = self._attempt(record, attempt)
            if att is None:
                raise _Reject(_fence("stale_attempt"))
            self._check_proof(record, att, nonce=nonce, credential=None, writer=writer, op="append_question",
                              running_path=True, lifecycle=False)
            if att["state"] in TERMINAL:
                raise _Reject(self._log_reject(record, attempt, "cas_mismatch", writer, "append_question"))
            att["questions"].append({"question_id": question_id, "body": body, "ts": self.clock()})
            box["changed"] = True
            return {"ok": True, "notices": 0}
        return self._mutate(dispatch_id, fn)

    # ── completion: T3, T3b, T5, T7b, T8 ───────────────────────────────
    def complete(self, dispatch_id, attempt, *, nonce, credential, evidence, writer="supervisor",
                 supervisor_gen=None, backend=None) -> dict:
        """A completion write with signed evidence; the transition follows the attempt's state (§3.3)."""
        def fn(record, box):
            att = self._attempt(record, attempt)
            if att is None:
                raise _Reject(_fence("stale_attempt"))
            self._check_proof(record, att, nonce=nonce, credential=credential, writer=writer, op="complete",
                              gen=supervisor_gen, backend=backend)
            if not self._bound(record, att, evidence):
                # not a signed completion of this attempt: it is no evidence, so no row admits it
                raise _Reject(self._log_reject(record, attempt, "forbidden_transition", writer, "complete"))
            result = self._complete_from_state(record, att, evidence, writer, "complete")
            box["changed"] = result.get("response") != "T8"
            return result
        return self._mutate(dispatch_id, fn)

    # ── sweep writer: T4, T6, T6b, T7a, T7c ────────────────────────────
    def _end_confirmed(self, record, att, writer):
        """A probe-confirmed end: local evidence is read first (§3.2), then T3/T3b/T7b or T4/T7c."""
        evidence = self.read_evidence(record["dispatch_id"], att["attempt"])
        if evidence is not None and self._bound(record, att, evidence):
            return self._complete_from_state(record, att, evidence, writer, "confirm_end")
        if att["state"] in ("running", "dispatched"):
            self._move(att, "lost", writer, "T4")
            return _accepted("T4")
        if att["state"] == "unknown":
            self._move(att, "lost", writer, "T7c")
            return _accepted("T7c")
        self._cas_fail(record, att, "lost", writer, "confirm_end")

    def confirm_end(self, dispatch_id, attempt, *, writer="hub") -> dict:
        """The probe confirmed the attempt's end and G has elapsed."""
        def fn(record, box):
            att = self._attempt(record, attempt)
            if att is None:
                raise _Reject(_fence("stale_attempt"))
            if att["state"] == "lost":
                return _none()
            if att["state"] == "done":
                # done outranks lost: a confirmed end of a done attempt is forbidden, evidence or not
                self._cas_fail(record, att, "lost", writer, "confirm_end")
            result = self._end_confirmed(record, att, writer)
            box["changed"] = True
            return result
        return self._mutate(dispatch_id, fn)

    def observe(self, dispatch_id, attempt, observation, *, writer="hub") -> dict:
        """One liveness-probe observation: alive, absent or undecided (§6.3). Then the clock rules run."""
        if observation not in ("alive", "absent", "undecided"):
            return {"error": "bad_observation"}

        def fn(record, box):
            att = self._attempt(record, attempt)
            if att is None:
                raise _Reject(_fence("stale_attempt"))
            box["changed"] = True
            probe = att["probe"]
            if observation == "alive":
                if att["state"] == "lost":
                    record["observations"].append(
                        {"attempt": attempt, "observation": "alive_while_lost", "ts": self.clock()})
                    self._notice(record, "lost_seen_alive", attempt)
                    return _none(notices=1, observation_logged=True)
                if att["state"] == "unknown":
                    probe["seen_alive"] = True
                    self._move(att, "running", writer, "T7a")
                    return _accepted("T7a")
                if att["state"] in ("running", "dispatched"):
                    probe["seen_alive"] = True
                    probe["absent_since"] = None
                    return _none()
                box["changed"] = False
                return _none()
            if observation == "absent" and att["state"] in ("running", "dispatched", "unknown") \
                    and (probe["seen_alive"] or att["state"] == "running"):
                if probe["absent_since"] is None:
                    probe["absent_since"] = self.clock()
                return self._tick_one(record, att, writer) or _none()
            box["changed"] = False
            return _none()
        result = self._mutate(dispatch_id, fn)
        if result.get("no_transition") and not result.get("notices"):
            tick = self.tick()
            if tick.get("accepted"):
                return tick
        return result

    def _tick_one(self, record, att, writer):
        """The clock rules for one attempt; returns the result of a transition taken, else None."""
        now = self.clock()
        state = att["state"]
        absent = att["probe"]["absent_since"]
        if state in ("running", "dispatched", "unknown") and absent is not None \
                and now >= absent + self.params["G"]:
            return self._end_confirmed(record, att, writer)
        if state == "running" and att["deadline_running"] is not None and now > att["deadline_running"]:
            self._move(att, "unknown", writer, "T6")
            self._notice(record, "unknown", att["attempt"], transition="T6")
            return _accepted("T6", notices=1)
        if state == "dispatched" and now > att["deadline_dispatched"]:
            self._move(att, "unknown", writer, "T6b")
            self._notice(record, "unknown", att["attempt"], transition="T6b")
            return _accepted("T6b", notices=1)
        return None

    def tick(self, *, writer="hub") -> dict:
        """Apply the time rules (G after a confirmed absence, the deadlines) to every open attempt."""
        taken = []
        for did in self.dispatch_ids():
            def fn(record, box):
                out = []
                for att in record["attempts"]:
                    if att["state"] in TERMINAL:
                        continue
                    res = self._tick_one(record, att, writer)
                    if res:
                        out.append(res)
                box["changed"] = bool(out)
                return {"results": out}
            taken.extend(self._mutate(did, fn).get("results", []))
        if not taken:
            return _none()
        first = dict(taken[0])
        first["notices"] = sum(r.get("notices", 0) for r in taken)
        return first

    def sweep(self, probe, *, writer="hub") -> list[dict]:
        """Production sweep: `probe(dispatch_id, attempt) -> alive|absent|undecided` for each open attempt."""
        out = []
        for did in self.dispatch_ids():
            record = self.load(did) or {"attempts": []}
            for att in record["attempts"]:
                if att["state"] in ("dispatched", "running", "unknown", "lost"):
                    out.append(self.observe(did, att["attempt"], probe(did, att["attempt"]), writer=writer))
        return out

    # ── T7d: operator resolve ──────────────────────────────────────────
    def resolve(self, dispatch_id, attempt, *, as_, reason, actor, via="host_cli", agent_session=False,
                override=False, outcome=None, evidence=None) -> dict:
        """`fw worker resolve` (T7d). Bound evidence derives the outcome; anything else is an attestation."""
        if via != "host_cli":
            return {"refused": "not_available", "notices": 0}
        if agent_session and not override:
            return {"refused": "agent_session", "notices": 0}
        if as_ not in ("lost", "done") or not reason:
            return {"error": "bad_resolve"}

        def fn(record, box):
            att = self._attempt(record, attempt)
            if att is None:
                raise _Reject(_fence("stale_attempt"))
            if att["state"] != "unknown":
                self._cas_fail(record, att, as_, "operator", "resolve")
            log = {"actor": actor, "reason": reason, "override": bool(override)}
            if as_ == "lost":
                self._move(att, "lost", "operator", "T7d", **log)
            elif evidence is not None and self._bound(record, att, evidence):
                self._finish(record, att, evidence, "operator", "T7d")
                att["history"][-1].update(log)
            else:
                if outcome not in OUTCOMES:
                    return {"error": "bad_resolve"}
                self._move(att, "done", "operator", "T7d", **log)
                att.update({"outcome": outcome, "attested": True, "attested_by": actor,
                            "evidence_digest": None,
                            "result": {"kind": "none", "value": None, "persisted_at": None}})
            self._notice(record, "resolve", attempt, outcome=att["outcome"], state=att["state"], **log)
            box["changed"] = True
            return _accepted("T7d", notices=1, logged_actor=True, logged_reason=reason)
        return self._mutate(dispatch_id, fn)

    # ── consumers and reads ────────────────────────────────────────────
    def consume(self, dispatch_id, attempt, *, consumer) -> dict:
        """An evaluation-layer consumer naming (dispatch, attempt, result): paused or attested is refused."""
        record = self.load(dispatch_id)
        att = self._attempt(record, attempt) if record else None
        if att is None or att["state"] != "done" or att["outcome"] == "paused" or att["attested"]:
            return {"refused": "not_finished_work", "notices": 0}
        return {"ok": True, "notices": 0, "values": {"dispatch_id": dispatch_id, "attempt": attempt,
                                                     "result": att["result"]}}

    def wait(self, dispatch_id, attempt) -> dict:
        record = self.load(dispatch_id)
        att = self._attempt(record, attempt) if record else None
        if att is None:
            return {"error": "no_such_attempt"}
        return {"ok": True, "notices": 0, "values": {"state": att["state"], "outcome": att["outcome"]}}


# ── conformance adapter (tests/conformance/worker-contract/run_local.py) ───
class _Adapter:
    """Maps the vectors' symbols (n1, c1, E1) to real nonces, tokens and signed completions.

    The clock, the lock clock and the liveness probe are injected: a vector's `advance` moves
    the clock, `sweep` hands the store an explicit probe observation, `hold_lock` holds the real
    flock from a second descriptor while the lock clock is fast-forwarded instead of slept."""

    capabilities = {"supervisor_gen", "caller_chosen_ids"}
    equivalent_routes: set = set()

    def __init__(self, params: dict | None = None):
        self.params = {**DEFAULTS, **(params or {})}
        self.key = secrets.token_bytes(32)
        self._tmp = None
        self._mono_offset = 0.0
        self._hold = None
        self._lock = threading.Lock()

    # injected clocks
    def _now(self):
        return self.now

    def _mono(self):
        return time.monotonic() + self._mono_offset

    def _sleep(self, dt):
        with self._lock:
            hold = self._hold
            if hold is not None:
                self._mono_offset += dt
                if self._mono() >= hold[1]:
                    self._release_hold()
                return
        time.sleep(min(dt, 0.002))

    def _release_hold(self):
        fd, _ = self._hold
        self._hold = None
        fcntl.flock(fd, fcntl.LOCK_UN)
        os.close(fd)

    def _reader(self, dispatch_id, attempt):
        if self.partitioned:
            return None
        ev = worker_dir_reader(self.workers)(dispatch_id, attempt)
        if ev is not None and isinstance(ev.get("persisted_at"), (int, float)) and ev["persisted_at"] > self.now:
            return None     # not yet persisted at this point of injected time
        return ev

    def _store(self):
        return Store(self.root, signing_key=self.key, clock=self._now, monotonic=self._mono,
                     sleep=self._sleep, evidence_reader=self._reader, params=self.params)

    def _param(self, value):
        if isinstance(value, (int, float)):
            return value
        m = re.fullmatch(r"\s*([A-Za-z_]+)\s*(?:([+-])\s*(\d+))?\s*", str(value))
        if not m or m.group(1) not in self.params:
            raise NotImplementedError(f"parameter {value!r}")
        base = self.params[m.group(1)]
        return base + (int(m.group(3)) * (1 if m.group(2) == "+" else -1) if m.group(2) else 0)

    def _sym(self, name):
        """A vector symbol: a known nonce/credential, `none`, or a fresh unknown value."""
        if name is None or name == "none":
            return None
        if name not in self.symbols:
            self.symbols[name] = "unknown-" + secrets.token_hex(8)
        return self.symbols[name]

    # ── reset / seed ───────────────────────────────────────────────────
    def reset(self, given):
        with self._lock:
            if self._hold is not None:
                self._release_hold()
        if self._tmp:
            shutil.rmtree(self._tmp, ignore_errors=True)
        self._tmp = tempfile.mkdtemp(prefix="t4802-dr-")
        self.root = Path(self._tmp) / "dispatch-records"
        self.workers = Path(self._tmp) / "workers"
        self.now = given.get("clock", 0)
        self.symbols: dict = {}
        self.partitioned = False
        self.created: list[str] = []
        self.store = self._store()
        self.evidence: dict = {}
        disp = given.get("dispatch")
        self.primary = disp["dispatch_id"] if disp else None
        if not disp:
            return
        did = disp["dispatch_id"]
        attempts = []
        for g in given.get("attempts") or []:
            nonce, token = secrets.token_hex(16), secrets.token_hex(32)
            self.symbols[g["nonce"]] = nonce
            if g.get("credential"):
                self.symbols[g["credential"]] = token
            attempts.append((g, nonce, token))
        for name, ev in (given.get("evidence") or {}).items():
            self.evidence[name] = self._materialise(did, ev)
        seeded_dirs = set()
        for name in sorted(self.evidence):
            ev = self.evidence[name]
            if ev["attempt"] in seeded_dirs:
                continue
            seeded_dirs.add(ev["attempt"])
            path = self.workers / did / f"a{ev['attempt']}" / "completion.json"
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(ev))
        record = {
            "contract_version": CONTRACT_VERSION, "dispatch_id": did, "backend": BACKEND, "task_id": None,
            "retry_of_dispatch_id": None, "closed": None,
            "dispatcher": {"project_agent": None, "session": disp.get("dispatcher_session"),
                           "claude_session_id": None},
            "created_at": self.now, "attempts": [], "notices": [], "fence_log": [], "observations": [],
        }
        for g, nonce, token in attempts:
            n = g["attempt"]
            state = g["state"]
            ts = g.get("lost_at", self.now) if state == "lost" else self.now
            att = {
                "attempt": n, "nonce_sha256": _sha256(nonce), "token_sha256": _sha256(token),
                "state": state, "outcome": None, "worker_kind": None,
                "session_binding": {"worker_binding": f"{did}:{n}", "session_name": f"tl-{did}-a{n}"},
                "attempt_dispatch_ref": None, "attested": False, "attested_by": None,
                "supervisor_gen": g.get("supervisor_gen", 1), "exit_code": None, "result": None,
                "handback": None, "evidence_digest": None,
                "history": [{"from": None, "to": state, "writer": "seed", "ts": ts, "transition": "seed"}],
                "questions": [], "answers": [],
                "deadline_dispatched": self.now + self.params["deadline_dispatched"],
                "deadline_running": self.now + self.params["deadline_running"] if state == "running" else None,
                "probe": {"seen_alive": bool(g.get("seen_alive_epoch")) or state == "running",
                          "absent_since": None},
                "pending_cause": None,
            }
            if state == "done":
                ev = self.evidence[g["evidence"]]
                att.update({"outcome": g.get("outcome") or derive_outcome(ev, did, n, att["nonce_sha256"]),
                            "exit_code": ev.get("exit_code"), "handback": ev.get("handback"),
                            "evidence_digest": _sha256(canonical(ev)),
                            "result": {"kind": "handback_sha256" if ev.get("handback") else "none",
                                       "value": _sha256(canonical(ev["handback"])) if ev.get("handback") else None,
                                       "persisted_at": ev.get("persisted_at")}})
            record["attempts"].append(att)
        self.store._write(record)

    def _materialise(self, did, ev):
        """A vector evidence entry as the supervisor would persist it: a signed completion (§6.5).

        The vectors' hand-backs carry `commission` (T-4803), and it is passed through as
        given, so a wrong one reaches outcome rule 1. A hand-back without it (an older copy
        of the vectors) gets the dispatch id filled in, as a real one would carry it
        (T-4802 Decisions)."""
        hb = ev.get("handback")
        if isinstance(hb, dict):
            hb = {"commission": did, **hb}
            hb["nonce"] = self._sym(hb.get("nonce"))
        else:
            hb = None
        body = {"dispatch_id": did, "attempt": ev["attempt"], "nonce": self._sym(ev["nonce"]),
                "exit_code": ev.get("exit_code"), "handback": hb, "persisted_at": ev.get("persisted_at")}
        if ev.get("supervisor_refused"):
            body["supervisor_refused"] = True
        return sign_completion(body, self.key) if ev.get("signed") else body

    # ── one step ───────────────────────────────────────────────────────
    def apply(self, step):
        op = step["op"]
        args = step.get("args") or {}
        did = self.primary
        n = step.get("attempt")
        writer = step.get("writer")
        if op == "create":
            res = self.store.create(dispatch_id=args.get("dispatch_id"), dispatcher=args.get("dispatcher"),
                                    retry_of_dispatch_id=args.get("retry_of_dispatch_id"))
            if res.get("accepted"):
                self.created.append(res["values"]["dispatch_id"])
                if self.primary is None:
                    self.primary = res["values"]["dispatch_id"]
            return self._bind(res, step)
        if op == "allocate":
            return self._bind(self.store.allocate(did), step)
        if op == "start":
            return self.store.start(did, n, nonce=self._sym(step.get("nonce")),
                                    credential=self._sym(step.get("credential")), writer=writer,
                                    supervisor_gen=step.get("supervisor_gen"), backend=args.get("backend"))
        if op == "reclaim":
            return self.store.reclaim(did, n, nonce=self._sym(step.get("nonce")),
                                      credential=self._sym(step.get("credential")),
                                      supervisor_gen=step.get("supervisor_gen"), writer=writer,
                                      backend=args.get("backend"))
        if op == "complete":
            backend = args.get("backend")
            return self.store.complete(did, n, nonce=self._sym(step.get("nonce")),
                                       credential=self._sym(step.get("credential")),
                                       evidence=self.evidence.get(step.get("evidence")), writer=writer,
                                       supervisor_gen=step.get("supervisor_gen"),
                                       backend=None if backend is None else
                                       (BACKEND if backend == "under_test" else backend))
        if op == "confirm_end":
            return self.store.confirm_end(did, n)
        if op == "sweep":
            return self.store.observe(did, n, args["observe"])
        if op == "probe_undecided":
            return self.store.observe(did, n, "undecided")
        if op == "advance":
            self.now += self._param(args["by"])
            return self.store.tick()
        if op == "hub_restart":
            # the local authority is this module over the same files: a restart is a fresh Store
            self.store = self._store()
            return {"ok": True, "notices": 0}
        if op in ("kill_supervisor", "dispatcher_lost"):
            return {"ok": True, "notices": 0}
        if op == "partition":
            self.partitioned = True
            return {"ok": True, "notices": 0}
        if op == "heal":
            self.partitioned = False
            return {"ok": True, "notices": 0}
        if op == "stop":
            res = self.store.stop(did, n, cause=args["cause"])
            return {**res, "ok": True} if "error" not in res else res
        if op == "resolve":
            material = args.get("material") or {}
            evidence = self.evidence.get(material.get("ref")) if material.get("kind") == "evidence" else None
            return self.store.resolve(did, n, as_=args["as"], reason=args.get("reason"), actor="operator:conformance",
                                      via=args.get("via", "host_cli"), agent_session=args.get("session") == "agent",
                                      override=bool(args.get("override")), outcome=args.get("outcome"),
                                      evidence=evidence)
        if op == "append_question":
            return self.store.append_question(did, n, nonce=self._sym(step.get("nonce")),
                                              question_id=args.get("question_id"), body=args.get("body"),
                                              writer=writer)
        if op == "consume":
            return self.store.consume(did, n, consumer=args.get("consumer"))
        if op == "wait":
            return self.store.wait(did, n)
        if op == "hold_lock":
            fd = os.open(self.root / f"{did}.lock", os.O_RDWR | os.O_CREAT, 0o600)
            fcntl.flock(fd, fcntl.LOCK_EX)
            with self._lock:
                self._hold = (fd, self._mono() + self._param(args["seconds"]))
            return {"ok": True, "notices": 0}
        if op == "concurrent":
            inner = args["step"]
            results = [None] * args["count"]
            barrier = threading.Barrier(args["count"])

            def run(i):
                barrier.wait()
                results[i] = self.apply(inner)
            threads = [threading.Thread(target=run, args=(i,)) for i in range(args["count"])]
            for t in threads:
                t.start()
            for t in threads:
                t.join()
            return {"results": results}
        raise NotImplementedError(f"op:{op} (answer channel §5 / not offered by the local backend)")

    def _bind(self, res, step):
        """Map a T1's returned nonce and token to the symbols the vector names in `bind`."""
        bind = (step.get("expect") or {}).get("bind") or {}
        values = res.get("values") or {}
        if res.get("accepted") == "T1":
            if "nonce" in bind:
                self.symbols[bind["nonce"]] = values["nonce"]
            if "credential" in bind:
                self.symbols[bind["credential"]] = values["supervisor_token"]
        return res

    # ── snapshot ───────────────────────────────────────────────────────
    def snapshot(self):
        record = self.store.load(self.primary) if self.primary else None
        attempts = {}
        causes = {}
        for att in (record or {}).get("attempts", []):
            key = f"A{att['attempt']}"
            attempts[key] = {
                "state": att["state"], "outcome": att["outcome"],
                "history": [e["to"] for e in att["history"]],
                "exit_code": att["exit_code"], "supervisor_gen": att["supervisor_gen"],
                "attested": att["attested"], "attested_by": att["attested_by"],
                "result_kind": (att["result"] or {}).get("kind"),
                "evidence_digest": att["evidence_digest"],
                "questions": len(att["questions"]), "answers": {},
            }
            for e in att["history"]:
                if e.get("cause"):
                    causes[key] = e["cause"]
        last_created = self.created[-1] if self.created else None
        new_rec = self.store.load(last_created) if last_created else None
        return {
            "attempts": attempts,
            "attempt_count": len(attempts),
            "operator_notices": len((record or {}).get("notices", [])),
            "dispatch_count": len(self.store.dispatch_ids()),
            "history_causes": causes,
            "new_dispatch_retry_of": (new_rec or {}).get("retry_of_dispatch_id"),
        }


def conformance_adapter(params: dict | None = None):
    """Entry point for tests/conformance/worker-contract/run_local.py."""
    import atexit
    adapter = _Adapter(params)
    atexit.register(lambda: adapter._tmp and shutil.rmtree(adapter._tmp, ignore_errors=True))
    return adapter
