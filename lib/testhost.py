#!/usr/bin/env python3
"""fw testhost — run the R-12 pull-request checks on a throwaway isolated test host (T-5009).

Design: docs/reports/T-5009-isolated-test-host-design.md (VM, no NIC, out-channel B = disks +
live serial log). Phase 3: the controller, built against a stub hypervisor. The Proxmox backend
is phase 4 and refuses until the operator has chosen the node (Q-3).

Subcommands:
  run (--pr N | --commit SHA) [--base REF] [--timeout S] [--backend stub] [--json]
  watch RUN-ID [--no-follow]      tail a run's sanitised serial log
  list [--limit N] [--json]       recent runs from .context/testhost/runs.jsonl

Rules this file enforces:
  - the controller decides the run's state (passed / failed / timeout / infra-error), never
    the guest: a guest's result.json only counts after strict validation;
  - everything the guest writes (serial bytes, result.json, logs) is hostile data: capped,
    sanitised, schema-checked; no path is taken from it and nothing from it is executed;
  - the VM is destroyed on every exit path (also on Ctrl-C, SIGTERM and timeout), and the run
    is infra-error when the pool is not empty afterwards;
  - the guest gets a git bundle of two synthetic commits (the tree of the merge-base, then the
    tree of the head on top), so `git diff base...HEAD` inside the guest names exactly the files
    the change touched, without shipping the repository's history.

Environment: PROJECT_ROOT (repo under test, state dir), FRAMEWORK_ROOT (where guest-run.sh and
pr-checks.sh live), FW_TESTHOST_DIR (state dir override, tests), FW_TESTHOST_GIT_REMOTE (remote
to fetch pull/N/head from), TESTHOST_STUB_POOL (stub pool dir), TESTHOST_STUB_GUEST (stub guest
command, tests). Config (env FW_<KEY> > .framework.yaml > default): TESTHOST_BACKEND,
TESTHOST_TIMEOUT, TESTHOST_SERIAL_CAP_BYTES.
"""
import argparse
import json
import os
import re
import secrets
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import threading
import time
from datetime import datetime, timezone
from pathlib import Path

DEFAULTS = {"TESTHOST_BACKEND": "stub", "TESTHOST_TIMEOUT": "1800",
            "TESTHOST_SERIAL_CAP_BYTES": "5242880"}
RESULT_MAX_BYTES = 64 * 1024
CHECKS_LOG_MAX_BYTES = 1024 * 1024
MAX_PHASES = 16
LINE_MAX = 64 * 1024
STATES = ("passed", "failed", "timeout", "infra-error")
EXIT_CODES = {"passed": 0, "failed": 1, "timeout": 3, "infra-error": 4}


class TesthostError(Exception):
    pass


class Interrupted(BaseException):
    """SIGTERM during a run; a BaseException so it unwinds through the finally like Ctrl-C."""


# ── config and paths ─────────────────────────────────────────────────────────

def _project_root() -> Path:
    return Path(os.environ.get("PROJECT_ROOT") or os.getcwd())


def _framework_root() -> Path:
    return Path(os.environ.get("FRAMEWORK_ROOT") or Path(__file__).resolve().parent.parent)


def config(key: str) -> str:
    """env FW_<KEY> > .framework.yaml > registry default, resolved like fw_config."""
    raw = os.environ.get("FW_" + key)
    if raw in (None, ""):
        try:
            text = (_project_root() / ".framework.yaml").read_text(encoding="utf-8")
        except OSError:
            text = ""
        m = re.search(rf"^{key}:\s*['\"]?([^'\"#\n]+?)['\"]?\s*(#.*)?$", text, re.M)
        raw = m.group(1) if m else ""
    raw = (raw or "").strip()
    return raw or DEFAULTS[key]


def _int_config(key: str) -> int:
    v = config(key)
    if not re.fullmatch(r"[0-9]+", v) or int(v) <= 0:
        raise TesthostError(f"config {key}={v!r} is not a positive integer")
    return int(v)


def state_dir() -> Path:
    d = os.environ.get("FW_TESTHOST_DIR")
    return Path(d) if d else _project_root() / ".context" / "testhost"


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _git(*args, cwd=None, env=None, check=True) -> str:
    p = subprocess.run(["git", *args], cwd=str(cwd or _project_root()), env=env,
                       capture_output=True, text=True)
    if check and p.returncode != 0:
        raise TesthostError(f"git {' '.join(args[:3])} failed: {p.stderr.strip()[:300]}")
    return p.stdout.strip()


def github_remote() -> str:
    """The remote that points at GitHub, like lib/issues.py:_github_remote (URL, not name)."""
    forced = os.environ.get("FW_TESTHOST_GIT_REMOTE")
    if forced:
        return forced
    out = _git("remote", "-v", check=False)
    for line in out.splitlines():
        parts = line.split()
        if len(parts) >= 2 and "github.com" in parts[1]:
            return parts[0]
    return "github"


# ── input: a git bundle of the change ────────────────────────────────────────

def resolve_head(pr=None, commit=None) -> str:
    if pr is not None:
        remote = github_remote()
        ref = f"refs/testhost/pr-{pr}"
        _git("fetch", "--quiet", "--no-tags", remote, f"+refs/pull/{pr}/head:{ref}")
        return _git("rev-parse", "--verify", f"{ref}^{{commit}}")
    if not re.fullmatch(r"[0-9A-Za-z._/~^-]{1,200}", commit or ""):
        raise TesthostError(f"--commit {commit!r} is not a plain revision")
    return _git("rev-parse", "--verify", f"{commit}^{{commit}}")


def make_input(head: str, base_ref: str, dest: Path) -> dict:
    """Write dest/pr.bundle holding refs/heads/base (tree of merge-base) and refs/heads/head
    (tree of head, parent base). Built in a scratch bare repo that borrows this repo's objects
    through alternates, so nothing is written into the repository itself."""
    base = _git("rev-parse", "--verify", f"{base_ref}^{{commit}}")
    mb = _git("merge-base", base, head, check=False)
    if not mb:
        raise TesthostError(f"{base_ref} and {head[:12]} share no history")
    objects = _git("rev-parse", "--path-format=absolute", "--git-common-dir")
    scratch = Path(tempfile.mkdtemp(prefix="fw-testhost-synth-"))
    try:
        _git("init", "-q", "--bare", str(scratch / "s.git"))
        (scratch / "s.git" / "objects" / "info" / "alternates").write_text(
            str(Path(objects) / "objects") + "\n")
        env = dict(os.environ, GIT_AUTHOR_NAME="testhost", GIT_AUTHOR_EMAIL="testhost@invalid",
                   GIT_COMMITTER_NAME="testhost", GIT_COMMITTER_EMAIL="testhost@invalid",
                   GIT_AUTHOR_DATE="2000-01-01T00:00:00Z", GIT_COMMITTER_DATE="2000-01-01T00:00:00Z")
        sgit = scratch / "s.git"
        a = _git("commit-tree", _git("rev-parse", f"{mb}^{{tree}}"), "-m", f"base {mb}",
                 cwd=sgit, env=env)
        b = _git("commit-tree", _git("rev-parse", f"{head}^{{tree}}"), "-p", a, "-m",
                 f"head {head}", cwd=sgit, env=env)
        _git("update-ref", "refs/heads/base", a, cwd=sgit)
        _git("update-ref", "refs/heads/head", b, cwd=sgit)
        dest.mkdir(parents=True, exist_ok=True)
        _git("bundle", "create", "-q", str(dest / "pr.bundle"), "refs/heads/head",
             "refs/heads/base", cwd=sgit)
    finally:
        shutil.rmtree(scratch, ignore_errors=True)
    return {"head": head, "base": base, "merge_base": mb,
            "bundle_bytes": (dest / "pr.bundle").stat().st_size}


# ── backends ─────────────────────────────────────────────────────────────────

class Backend:
    """Hypervisor interface. A vm_id is opaque to the controller."""
    name = "abstract"

    def clone(self) -> str: raise NotImplementedError
    def attach_input(self, vm_id: str, src_dir: Path) -> None: raise NotImplementedError
    def attach_output(self, vm_id: str) -> None: raise NotImplementedError
    def start(self, vm_id: str) -> None: raise NotImplementedError
    def state(self, vm_id: str) -> str: raise NotImplementedError   # running|stopped|absent
    def serial(self, vm_id: str): raise NotImplementedError         # binary stream with .read
    def stop(self, vm_id: str) -> None: raise NotImplementedError
    def read_output(self, vm_id: str) -> Path: raise NotImplementedError
    def destroy(self, vm_id: str) -> None: raise NotImplementedError
    def list_pool(self) -> list: raise NotImplementedError


class ProxmoxBackend(Backend):
    name = "proxmox"

    def __init__(self, *_a, **_k):
        raise TesthostError("backend 'proxmox' is not configured: phase 4, the operator chooses "
                            "the node first (T-5009 Q-3). Use --backend stub.")


class StubBackend(Backend):
    """A 'VM' is a directory in the pool: in/ (input disk), out/ (output disk). start runs the
    guest command as a child process in its own session; its stdout is the serial stream."""
    name = "stub"

    def __init__(self, pool=None, guest=None):
        default_pool = Path(tempfile.gettempdir()) / f"fw-testhost-stub-{os.getuid()}"
        self.pool = Path(pool or os.environ.get("TESTHOST_STUB_POOL") or default_pool)
        self.pool.mkdir(parents=True, exist_ok=True)
        g = guest or os.environ.get("TESTHOST_STUB_GUEST")
        self.guest = g.split() if g else ["bash", str(_framework_root() / "agents" / "testhost"
                                                      / "guest-run.sh")]
        self.procs = {}

    def _dir(self, vm_id: str) -> Path:
        if not re.fullmatch(r"vm-[0-9a-f]{12}", vm_id):
            raise TesthostError(f"bad vm id {vm_id!r}")
        return self.pool / vm_id

    def clone(self) -> str:
        vm_id = "vm-" + secrets.token_hex(6)
        (self._dir(vm_id) / "disk").mkdir(parents=True)
        return vm_id

    def attach_input(self, vm_id, src_dir):
        shutil.copytree(src_dir, self._dir(vm_id) / "in")

    def attach_output(self, vm_id):
        (self._dir(vm_id) / "out").mkdir()

    def start(self, vm_id):
        d = self._dir(vm_id)
        env = dict(os.environ, TMPDIR=str(d / "disk"))
        self.procs[vm_id] = subprocess.Popen(
            [*self.guest, str(d / "in"), str(d / "out")], cwd=str(d / "disk"),
            stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            env=env, start_new_session=True)

    def state(self, vm_id):
        p = self.procs.get(vm_id)
        if p is None:
            return "absent"
        return "running" if p.poll() is None else "stopped"

    def serial(self, vm_id):
        return self.procs[vm_id].stdout

    def stop(self, vm_id):
        p = self.procs.get(vm_id)
        if p is None or p.poll() is not None:
            return
        try:
            os.killpg(p.pid, signal.SIGKILL)   # our own child's session (start_new_session)
        except ProcessLookupError:
            pass
        p.wait(timeout=10)

    def read_output(self, vm_id) -> Path:
        """Copy the output disk's regular top-level files to a fresh reader dir, each capped.
        Real backend: done inside a disposable reader VM."""
        src = self._dir(vm_id) / "out"
        reader = Path(tempfile.mkdtemp(prefix="fw-testhost-reader-"))
        for name in ("result.json", "checks.log"):
            f = src / name
            try:
                st = os.lstat(f)
            except OSError:
                continue
            if not stat.S_ISREG(st.st_mode):
                continue
            cap = RESULT_MAX_BYTES + 1 if name == "result.json" else CHECKS_LOG_MAX_BYTES
            with open(f, "rb") as fin, open(reader / name, "wb") as fout:
                fout.write(fin.read(cap))
        return reader

    def destroy(self, vm_id):
        try:
            self.stop(vm_id)
        finally:
            p = self.procs.pop(vm_id, None)
            if p is not None and p.stdout:
                p.stdout.close()
            shutil.rmtree(self._dir(vm_id), ignore_errors=True)

    def list_pool(self):
        return sorted(x.name for x in self.pool.iterdir() if x.name.startswith("vm-"))


BACKENDS = {"stub": StubBackend, "proxmox": ProxmoxBackend}


def get_backend(name: str) -> Backend:
    if name not in BACKENDS:
        raise TesthostError(f"unknown backend {name!r} (known: {', '.join(BACKENDS)})")
    return BACKENDS[name]()


# ── serial collector ─────────────────────────────────────────────────────────

_ESC_SEQ = re.compile(
    r"\x1b\[[0-?]*[ -/]*[@-~]"                 # CSI
    r"|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)?"      # OSC
    r"|\x1b[PX^_][^\x1b]*(?:\x1b\\)?"           # DCS / SOS / PM / APC
    r"|\x1b[ -/]*[0-~]?"                        # other ESC sequences, lone ESC
    r"|\x9b[0-?]*[ -/]*[@-~]")                  # 8-bit CSI
_CTRL = re.compile(r"[\x00-\x08\x0b-\x1f\x7f-\x9f]")


def sanitize_line(raw: bytes) -> str:
    text = raw.decode("utf-8", errors="replace")
    text = _ESC_SEQ.sub("", text)
    return _CTRL.sub("", text)


class Collector:
    """Reads the hostile serial stream, writes a capped, sanitised log, and keeps draining
    after the cap so the guest never blocks on a full pipe."""

    def __init__(self, stream, log_path: Path, cap: int):
        self.stream, self.log_path, self.cap = stream, log_path, cap
        self.raw_bytes = 0
        self.written = 0
        self.truncated = False
        self.thread = threading.Thread(target=self._run, daemon=True)

    def start(self):
        self.thread.start()

    def join(self, timeout=None):
        self.thread.join(timeout)
        return not self.thread.is_alive()

    def _emit(self, fh, line: str):
        if self.truncated:
            return
        data = line.encode("utf-8")
        if self.written + len(data) > self.cap:
            fh.write(f"\n[testhost: serial log truncated at {self.cap} bytes]\n".encode())
            self.truncated = True
        else:
            fh.write(data)
            self.written += len(data)
        fh.flush()

    def _run(self):
        buf = b""
        fd = self.stream.fileno()
        with open(self.log_path, "ab") as fh:
            while True:
                try:
                    chunk = os.read(fd, 65536)
                except (OSError, ValueError):
                    break
                if not chunk:
                    break
                self.raw_bytes += len(chunk)
                buf += chunk
                while b"\n" in buf or len(buf) > LINE_MAX:
                    if b"\n" in buf:
                        line, buf = buf.split(b"\n", 1)
                    else:
                        line, buf = buf[:LINE_MAX], buf[LINE_MAX:]
                    self._emit(fh, sanitize_line(line) + "\n")
            if buf:
                self._emit(fh, sanitize_line(buf) + "\n")


# ── result validation ────────────────────────────────────────────────────────

_TS = re.compile(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ")
_PHASE = re.compile(r"[a-z][a-z0-9-]{0,31}")


def _is_int(v, lo, hi):
    return type(v) is int and lo <= v <= hi


def validate_result(reader: Path):
    """-> (state, reason, clean_result_or_None). The guest's status is only a claim."""
    f = reader / "result.json"
    try:
        st = os.lstat(f)
    except OSError:
        return "infra-error", "no result.json on the output disk", None
    if not stat.S_ISREG(st.st_mode):
        return "infra-error", "result.json is not a regular file", None
    if st.st_size > RESULT_MAX_BYTES:
        return "infra-error", f"result.json larger than {RESULT_MAX_BYTES} bytes", None
    try:
        doc = json.loads(f.read_bytes().decode("utf-8"))
    except (UnicodeDecodeError, ValueError):
        return "infra-error", "result.json is not valid JSON", None
    want = {"version", "status", "phases", "started", "finished"}
    if not isinstance(doc, dict) or set(doc) != want:
        return "infra-error", "result.json does not match the schema (keys)", None
    if doc["version"] != 1 or type(doc["version"]) is not int:
        return "infra-error", "result.json version is not 1", None
    if doc["status"] not in ("passed", "failed"):
        return "infra-error", "result.json status is not passed|failed", None
    for k in ("started", "finished"):
        if not isinstance(doc[k], str) or not _TS.fullmatch(doc[k]):
            return "infra-error", f"result.json {k} is not a UTC timestamp", None
    phases = doc["phases"]
    if not isinstance(phases, list) or not 0 < len(phases) <= MAX_PHASES:
        return "infra-error", "result.json phases is not a list of 1..16 entries", None
    clean = []
    for p in phases:
        if (not isinstance(p, dict) or set(p) != {"name", "rc", "seconds"}
                or not isinstance(p["name"], str) or not _PHASE.fullmatch(p["name"])
                or not _is_int(p["rc"], 0, 255) or not _is_int(p["seconds"], 0, 10**6)):
            return "infra-error", "result.json phase entry does not match the schema", None
        clean.append({"name": p["name"], "rc": p["rc"], "seconds": p["seconds"]})
    all_ok = all(p["rc"] == 0 for p in clean)
    if doc["status"] == "passed" and not all_ok:
        return "infra-error", "result.json claims passed but a phase failed", None
    state = "passed" if all_ok and doc["status"] == "passed" else "failed"
    return state, "", {"version": 1, "status": doc["status"], "phases": clean,
                       "started": doc["started"], "finished": doc["finished"]}


def copy_checks_log(reader: Path, dest: Path):
    f = reader / "checks.log"
    try:
        if not stat.S_ISREG(os.lstat(f).st_mode):
            return
    except OSError:
        return
    with open(f, "rb") as fin, open(dest, "w", encoding="utf-8") as fout:
        for line in fin.read(CHECKS_LOG_MAX_BYTES).split(b"\n"):
            fout.write(sanitize_line(line) + "\n")


# ── the run ──────────────────────────────────────────────────────────────────

def _append_row(row: dict):
    d = state_dir()
    d.mkdir(parents=True, exist_ok=True)
    with open(d / "runs.jsonl", "a", encoding="utf-8") as fh:
        fh.write(json.dumps(row, sort_keys=True) + "\n")


def run(pr=None, commit=None, base="origin/bleeding-edge", timeout=None, backend=None,
        backend_name=None, on_started=None) -> dict:
    """Run the checks once. Always returns a row (also appended to runs.jsonl) unless the
    input cannot be prepared before any VM exists (then TesthostError)."""
    timeout = timeout or _int_config("TESTHOST_TIMEOUT")
    cap = _int_config("TESTHOST_SERIAL_CAP_BYTES")
    head = resolve_head(pr=pr, commit=commit)
    label = f"pr-{pr}" if pr is not None else f"commit-{head[:9]}"
    run_id = f"{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')}-{label}-{secrets.token_hex(2)}"
    run_dir = state_dir() / run_id
    run_dir.mkdir(parents=True)
    (run_dir / "state").write_text("running\n")
    input_dir = Path(tempfile.mkdtemp(prefix="fw-testhost-input-"))
    started, t0 = _now(), time.monotonic()
    state, reason, result, collector, vm_id, boot_s = None, "", None, None, None, None
    try:
        meta = make_input(head, base, input_dir)
        backend = backend or get_backend(backend_name or config("TESTHOST_BACKEND"))
        vm_id = backend.clone()
        backend.attach_input(vm_id, input_dir)
        backend.attach_output(vm_id)
        backend.start(vm_id)
        boot_s = round(time.monotonic() - t0, 3)
        collector = Collector(backend.serial(vm_id), run_dir / "serial.log", cap)
        collector.start()
        if on_started:
            on_started(backend, vm_id)
        deadline = time.monotonic() + timeout
        while backend.state(vm_id) == "running":
            if time.monotonic() > deadline:
                state, reason = "timeout", f"wall clock {timeout}s exceeded; VM stopped"
                backend.stop(vm_id)
                break
            time.sleep(0.2)
        collector.join(timeout=5)
        if state is None:
            reader = backend.read_output(vm_id)
            try:
                state, reason, result = validate_result(reader)
                copy_checks_log(reader, run_dir / "checks.log")
            finally:
                shutil.rmtree(reader, ignore_errors=True)
    except (KeyboardInterrupt, Interrupted):
        state, reason = "infra-error", "interrupted (Ctrl-C / SIGTERM); VM destroyed"
    except Exception as e:  # noqa: BLE001 — every failure is an infra-error, then destroy
        state, reason = "infra-error", f"{type(e).__name__}: {str(e)[:300]}"
    finally:
        if vm_id is not None and backend is not None:
            try:
                backend.destroy(vm_id)
            except Exception as e:  # noqa: BLE001
                state, reason = "infra-error", f"destroy failed: {str(e)[:200]}"
        if collector is not None:
            collector.join(timeout=5)
        shutil.rmtree(input_dir, ignore_errors=True)
        leftover = []
        if backend is not None:
            try:
                leftover = backend.list_pool()
            except Exception as e:  # noqa: BLE001
                leftover = [f"<list_pool failed: {e}>"]
        if leftover:
            state = "infra-error"
            reason = (reason + "; " if reason else "") + "pool not empty after destroy: " + \
                ", ".join(leftover)
        if result is not None:
            (run_dir / "result.json").write_text(json.dumps(result, indent=2) + "\n")
        row = {"run_id": run_id, "pr": pr, "commit": None if pr is not None else commit,
               "head": head, "base": base, "backend": getattr(backend, "name", None),
               "state": state or "infra-error", "reason": reason, "started": started,
               "finished": _now(), "seconds": round(time.monotonic() - t0, 3),
               "boot_seconds": boot_s,
               "serial_bytes": collector.raw_bytes if collector else 0,
               "serial_written": collector.written if collector else 0,
               "truncated": bool(collector and collector.truncated)}
        (run_dir / "state").write_text(row["state"] + "\n")
        _append_row(row)
    return row


def read_rows() -> list:
    f = state_dir() / "runs.jsonl"
    rows = []
    try:
        for line in f.read_text(encoding="utf-8").splitlines():
            try:
                rows.append(json.loads(line))
            except ValueError:
                continue
    except OSError:
        pass
    return rows


# ── CLI ──────────────────────────────────────────────────────────────────────

def cmd_run(a) -> int:
    def _term(_s, _f):
        raise Interrupted()
    signal.signal(signal.SIGTERM, _term)
    row = run(pr=a.pr, commit=a.commit, base=a.base, timeout=a.timeout, backend_name=a.backend)
    if a.json:
        print(json.dumps(row, sort_keys=True))
    else:
        print(f"run {row['run_id']}: {row['state']}"
              + (f" — {row['reason']}" if row["reason"] else ""))
        print(f"  log: {state_dir() / row['run_id'] / 'serial.log'}"
              f" ({row['serial_written']} bytes{', truncated' if row['truncated'] else ''})")
    return EXIT_CODES[row["state"]]


def cmd_watch(a) -> int:
    if not re.fullmatch(r"[0-9A-Za-z._-]{1,120}", a.run_id):
        raise TesthostError(f"bad run id {a.run_id!r}")
    d = state_dir() / a.run_id
    log, st = d / "serial.log", d / "state"
    if not d.is_dir():
        raise TesthostError(f"no run {a.run_id} in {state_dir()}")
    pos = 0
    while True:
        if log.exists():
            with open(log, "rb") as fh:
                fh.seek(pos)
                data = fh.read()
                pos += len(data)
            sys.stdout.write(data.decode("utf-8", errors="replace"))
            sys.stdout.flush()
        running = st.exists() and st.read_text().strip() == "running"
        if a.no_follow or not running:
            if not a.no_follow and log.exists() and log.stat().st_size > pos:
                continue
            break
        time.sleep(0.5)
    print(f"[testhost: run {a.run_id} state {st.read_text().strip() if st.exists() else '?'}]")
    return 0


def cmd_list(a) -> int:
    rows = read_rows()[-a.limit:]
    if a.json:
        print(json.dumps(rows))
        return 0
    if not rows:
        print("no test-host runs yet")
        return 0
    for r in rows:
        what = f"PR #{r['pr']}" if r.get("pr") is not None else f"commit {str(r.get('head'))[:9]}"
        print(f"{r['run_id']}  {r['state']:<11} {what:<18} base={r['base']} "
              f"{r['seconds']}s serial={r['serial_written']}B"
              f"{' (truncated)' if r.get('truncated') else ''}")
    return 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="fw testhost", description=(__doc__ or "").split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("run", help="run the PR checks on a throwaway test host")
    g = r.add_mutually_exclusive_group(required=True)
    g.add_argument("--pr", type=int)
    g.add_argument("--commit")
    r.add_argument("--base", default="origin/bleeding-edge")
    r.add_argument("--timeout", type=int, default=None)
    r.add_argument("--backend", choices=sorted(BACKENDS), default=None)
    r.add_argument("--json", action="store_true")
    r.set_defaults(fn=cmd_run)
    w = sub.add_parser("watch", help="tail a run's sanitised serial log")
    w.add_argument("run_id")
    w.add_argument("--no-follow", action="store_true")
    w.set_defaults(fn=cmd_watch)
    li = sub.add_parser("list", help="recent runs")
    li.add_argument("--limit", type=int, default=20)
    li.add_argument("--json", action="store_true")
    li.set_defaults(fn=cmd_list)
    a = ap.parse_args(argv)
    try:
        return a.fn(a)
    except TesthostError as e:
        print(f"fw testhost: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
