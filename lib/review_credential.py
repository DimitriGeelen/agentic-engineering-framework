#!/usr/bin/env python3
"""Vendor credential resolver: `fw review credential <backend> [--check] [--exec -- cmd...]`.

T-3766. Agents kept asking the operator for vendor credentials (the OpenRouter key above
all) that the framework already holds, because the credential's LOCATION lived only in
prose and in agent memory. The location is now a registry fact: each backend in
policy/review-backends.yaml may carry a `credential:` block, and this module is the one
reader of it.

    credential:
      source: env-file             # env-file | cli-login | none
      env: OPENROUTER_API_KEY      # env-file: the variable a runner expects
      files:                       # env-file: ordered KEY=VALUE files to read it from
        - /root/.litellm-openrouter.env
      note: "..."                  # cli-login/none: what authenticates (required there)

The block names WHERE a credential is, never its value; validate_credential() refuses a
value-looking string. Resolution order: the environment variable, then each registered
file in order. A file is parsed line by line for exactly that one variable (KEY=VALUE,
optional `export`, optional quotes) and never sourced as shell.

The value never reaches stdout, stderr, an exception message or a process argument:
  --check   prints which source resolved plus a masked length.
  --exec    runs the command with the variable in its ENVIRONMENT, and rewrites any
            occurrence of the value in the child's stdout/stderr to a mask. A paid backend
            (approval_required) needs an approved, unused proposal for the focused task,
            checked here, not only by the check-paid-backend hook.

Exfiltration by registry edit: the credential blocks are read from the registry as
committed at HEAD when the registry is tracked by git; a working-tree edit to any
credential block is refused until it is committed (and so attributable). A registered
file must be a regular file, not group/world-writable, owned by root or the caller, and
at most 64 KiB. What this does NOT stop (same residual as Tier 0, T-2742): a command run
under --exec has the value and can encode it past the output mask, and a same-user
process can commit a registry change. The mask catches accidents, not intent.

Which store is the source of truth: THIS registry + resolver, for review/dispatch
runners. web/secrets_store.py is Watchtower's own Fernet-encrypted UI key store
(.context/secrets/api-keys.enc) and is not consulted here.
"""
from __future__ import annotations

import argparse
import os
import re
import stat
import subprocess
import sys
import threading
from pathlib import Path

import yaml

SOURCES = ("env-file", "cli-login", "none")
KEYS = ("source", "env", "files", "note")
ENV_RE = re.compile(r"^[A-Z][A-Z0-9_]{1,63}$")
PATH_RE = re.compile(r"^/[A-Za-z0-9._/+-]+$")
#: value-looking: an API-key prefix, or a long unbroken base64/hex-ish run.
VALUE_RES = (re.compile(r"\b(sk|pk|rk)-[A-Za-z0-9_-]{6,}"), re.compile(r"[A-Za-z0-9+=_-]{32,}"))
MAX_FILE = 64 * 1024
MASK = "****"


class CredError(Exception):
    """A refusal. The message never contains a credential value."""


def _looks_like_value(s: str) -> bool:
    return any(r.search(s) for r in VALUE_RES)


def validate_credential(bid: str, cred: object) -> list[str]:
    """Errors for one backend's `credential:` block (called from review_cost.validate)."""
    if not isinstance(cred, dict) or not cred:
        return [f"{bid}: credential must be a non-empty mapping"]
    errs = []
    for k in cred:
        if k not in KEYS:
            errs.append(f"{bid}: credential has unknown key {k!r} (allowed: {', '.join(KEYS)})")
    for k, v in cred.items():
        for s in (v if isinstance(v, list) else [v]):
            if isinstance(s, str) and _looks_like_value(s):
                errs.append(f"{bid}: credential.{k} looks like a credential VALUE — the registry "
                            f"names where a credential is, never what it is")
    src = cred.get("source", "env-file")
    if src not in SOURCES:
        errs.append(f"{bid}: credential.source must be one of {SOURCES}, got {src!r}")
    env, files, note = cred.get("env"), cred.get("files"), cred.get("note")
    if env is not None and (not isinstance(env, str) or not ENV_RE.match(env)):
        errs.append(f"{bid}: credential.env must match {ENV_RE.pattern}")
    if files is not None:
        if not isinstance(files, list) or not files:
            errs.append(f"{bid}: credential.files must be a non-empty list of absolute paths")
        else:
            for f in files:
                if not isinstance(f, str) or not PATH_RE.match(f) or "/../" in f or f.endswith("/.."):
                    errs.append(f"{bid}: credential.files entry {f!r} must be an absolute path "
                                f"matching {PATH_RE.pattern}")
    if note is not None and not (isinstance(note, str) and note.strip()):
        errs.append(f"{bid}: credential.note must be non-empty text")
    if src == "env-file" and not env:
        errs.append(f"{bid}: credential source env-file needs `env:`")
    if src in ("cli-login", "none"):
        if not note:
            errs.append(f"{bid}: credential source {src} needs `note:` saying what authenticates")
        if env or files:
            errs.append(f"{bid}: credential source {src} takes no env/files")
    return errs


# ── committed registry ───────────────────────────────────────────────────────

def _git(path: Path, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["git", "-C", str(path.parent), *args], capture_output=True, text=True, timeout=10)


def committed_credentials(path: Path) -> dict[str, dict] | None:
    """{backend id: credential block} from the registry as committed at HEAD, or None when
    the registry is not inside a git work tree. Raises when it is inside one but untracked,
    unreadable at HEAD, or its credential blocks differ from the working tree."""
    try:
        inside = _git(path, "rev-parse", "--is-inside-work-tree")
    except (OSError, subprocess.SubprocessError):
        return None
    if inside.returncode != 0 or inside.stdout.strip() != "true":
        return None
    shown = _git(path, "show", f"HEAD:./{path.name}")
    if shown.returncode != 0:
        raise CredError(f"the backend registry {path} is in a git work tree but not committed at "
                        f"HEAD — credential locations are read only from the committed registry")
    head = yaml.safe_load(shown.stdout) or {}
    work = yaml.safe_load(path.read_text(encoding="utf-8")) or {}

    def creds(doc: dict) -> dict[str, dict]:
        return {b.get("id"): b.get("credential") for b in (doc.get("backends") or [])
                if isinstance(b, dict) and b.get("credential") is not None}
    h, w = creds(head), creds(work)
    if h != w:
        changed = sorted(k for k in set(h) | set(w) if h.get(k) != w.get(k))
        raise CredError(f"uncommitted change to the credential block of {', '.join(map(str, changed))} "
                        f"in {path} — commit it (task-referenced) before the resolver will use it")
    return h


def credential_for(backend: dict, path: Path) -> dict:
    bid = backend["id"]
    committed = committed_credentials(path)
    cred = committed.get(bid) if committed is not None else backend.get("credential")
    if not cred:
        raise CredError(f"backend {bid!r} has no `credential:` block in {path} — add one "
                        f"(source/env/files, never a value)")
    return cred


def registered_files(path: Path, backends: list[dict]) -> set[str]:
    """Every credential file the committed registry names (the boundary hook's allowlist)."""
    committed = committed_credentials(path)
    src = committed if committed is not None else {b["id"]: b.get("credential") for b in backends}
    out: set[str] = set()
    for cred in src.values():
        if isinstance(cred, dict) and isinstance(cred.get("files"), list):
            out.update(f for f in cred["files"] if isinstance(f, str))
    return out


# ── resolution ───────────────────────────────────────────────────────────────

def _read_var(fpath: str, var: str) -> str | None:
    """The value of `var` in a KEY=VALUE file, or None when the file lacks it or is absent.
    Raises (with no content in the message) when the file is unsafe to read."""
    p = Path(fpath)
    try:
        st = os.lstat(p)
    except FileNotFoundError:
        return None
    except PermissionError:
        raise CredError(f"{fpath}: not readable by this user")
    if stat.S_ISLNK(st.st_mode):
        raise CredError(f"{fpath}: is a symlink — register the target path itself")
    if not stat.S_ISREG(st.st_mode):
        raise CredError(f"{fpath}: not a regular file")
    if st.st_mode & (stat.S_IWGRP | stat.S_IWOTH):
        raise CredError(f"{fpath}: group/world-writable — refusing to trust it")
    if st.st_uid not in (0, os.geteuid()):
        raise CredError(f"{fpath}: owned by uid {st.st_uid}, not root or the caller")
    if st.st_size > MAX_FILE:
        raise CredError(f"{fpath}: larger than {MAX_FILE} bytes — not a credential env file")
    try:
        text = p.read_text(encoding="utf-8", errors="replace")
    except PermissionError:
        raise CredError(f"{fpath}: not readable by this user")
    pat = re.compile(rf"^\s*(?:export\s+)?{re.escape(var)}\s*=(.*)$")
    for line in text.splitlines():
        m = pat.match(line)
        if not m:
            continue
        val = m.group(1).strip()
        if len(val) >= 2 and val[0] == val[-1] and val[0] in "\"'":
            val = val[1:-1]
        elif " #" in val:
            val = val.split(" #", 1)[0].rstrip()
        return val or None
    return None


def resolve(backend: dict, path: Path, only_file: str | None = None) -> tuple[str, str, str]:
    """(variable, value, source description). Raises CredError naming the registry entry."""
    bid = backend["id"]
    cred = credential_for(backend, path)
    src = cred.get("source", "env-file")
    if src != "env-file":
        raise CredError(f"backend {bid!r} has credential source {src}: {cred.get('note')}")
    var, files = cred["env"], list(cred.get("files") or [])
    if only_file is not None:
        if only_file not in files:
            raise CredError(f"--source {only_file!r} is not a registered credential file of {bid!r} "
                            f"(registered: {', '.join(files) or 'none'})")
        files = [only_file]
    elif os.environ.get(var):
        return var, os.environ[var], f"environment ${var}"
    for f in files:
        val = _read_var(f, var)
        if val:
            return var, val, f"file {f}"
    tried = ([f"${var}"] if only_file is None else []) + files
    raise CredError(f"no value for {var} (backend {bid!r}, registry {path}: credential.env={var}, "
                    f"credential.files={files}) — tried {', '.join(tried)}")


def _masked(val: str) -> str:
    return f"{MASK} ({len(val)} chars)"


def _focused_task(proj: Path) -> str:
    f = proj / ".context" / "working" / "focus.yaml"
    if not f.is_file():
        return ""
    m = re.search(r"^current_task:\s*(\S+)", f.read_text(encoding="utf-8"), re.M)
    t = m.group(1).strip("\"'") if m else ""
    return "" if t in ("null", "~") else t


def _pump(src, dst, secret: bytes) -> None:
    """Copy a child stream line by line, masking the secret. A line is the unit, so a value
    split across two reads still masks (it never contains a newline)."""
    for line in iter(src.readline, b""):
        dst.write(line.replace(secret, MASK.encode()))
        dst.flush()
    src.close()


def run_exec(var: str, value: str, cmd: list[str]) -> int:
    env = dict(os.environ)
    env[var] = value
    try:
        proc = subprocess.Popen(cmd, env=env, stdin=sys.stdin, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    except OSError as e:
        raise CredError(f"cannot run {cmd[0]!r}: {e.strerror}")
    secret = value.encode()
    ts = [threading.Thread(target=_pump, args=(proc.stdout, sys.stdout.buffer, secret)),
          threading.Thread(target=_pump, args=(proc.stderr, sys.stderr.buffer, secret))]
    for t in ts:
        t.start()
    rc = proc.wait()
    for t in ts:
        t.join()
    return rc


def main(argv: list[str]) -> int:
    import review_cost as rc_  # sibling module; imported lazily to avoid a cycle

    cmd: list[str] = []
    if "--exec" in argv:
        i = argv.index("--exec")
        argv, cmd = argv[:i], argv[i + 1:]
        if cmd[:1] == ["--"]:
            cmd = cmd[1:]
        if not cmd:
            print("ERROR: --exec needs a command: --exec -- <cmd...>", file=sys.stderr)
            return 1
    ap = argparse.ArgumentParser(prog="fw review credential",
                                 description="Resolve a backend's credential from the registry (T-3766). "
                                             "Never prints the value.")
    ap.add_argument("backend")
    ap.add_argument("--check", action="store_true", help="report which source resolved (masked)")
    ap.add_argument("--source", help="restrict to one REGISTERED credential file")
    ap.add_argument("--task", default="", help="task for the paid-approval check (default: focus)")
    a = ap.parse_args(argv)
    try:
        backend = rc_.get_backend(a.backend)
        path = rc_.policy_path()
        if not cmd:
            cred = credential_for(backend, path)
            src = cred.get("source", "env-file")
            if src != "env-file":
                print(f"{backend['id']}: credential source {src} — {cred.get('note')}")
                return 0
            var, val, where = resolve(backend, path, a.source)
            print(f"{backend['id']}: {var} resolved from {where}: {_masked(val)}")
            return 0
        if backend.get("approval_required"):
            task = a.task or _focused_task(rc_._roots()[0])
            if not task or not rc_.open_approval(task, backend["id"]):
                raise CredError(
                    f"backend {backend['id']!r} is paid: --exec needs an approved, unused proposal "
                    f"for {task or 'the focused task (none focused)'}.\n"
                    f"  bin/fw review propose --task {task or 'T-XXX'} --backend {backend['id']} "
                    f"--why '...' --estimate-cost N   (the operator approves it)")
        var, val, _ = resolve(backend, path, a.source)
        return run_exec(var, val, cmd)
    except (CredError, rc_.CostError) as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    sys.exit(main(sys.argv[1:]))
