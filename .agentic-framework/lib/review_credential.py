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
            checked here, not only by the check-paid-backend hook, and the cost record that
            consumes it is written before the child starts (one approval, one --exec).
            A value containing a newline or control character is refused, so it cannot
            straddle the line-by-line mask.

Exfiltration by registry edit: the credential blocks are read from the registry as
committed at HEAD when the registry is tracked by git; a working-tree edit to any
credential block is refused until it is committed (and so attributable); a git that
cannot answer refuses. `files:` is allowed only on an approval_required backend, so a file
credential reaches a child only under an operator-approved proposal (consumed under a lock,
one approval per --exec). A registered file is opened component by component with
O_NOFOLLOW and must be a regular, private (no group/other read or write) file owned by
root or the caller, at most 64 KiB. What this does NOT stop (same residual as Tier 0,
T-2742): a command run under --exec has the value and can encode it past the output mask,
and a same-user process can commit a registry change (including approval_required, which
set_backend refuses but a hand edit does not). The mask catches accidents, not intent.

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


def validate_credential(bid: str, cred: object, approval_required: bool = True) -> list[str]:
    """Errors for one backend's `credential:` block (called from review_cost.validate)."""
    if not isinstance(cred, dict) or not cred:
        return [f"{bid}: credential must be a non-empty mapping"]
    errs = []
    # Never echo registry text in these messages: a key or value may be a pasted credential.
    n_unknown = sum(1 for k in cred if k not in KEYS)
    if n_unknown:
        errs.append(f"{bid}: credential has {n_unknown} unknown key(s) (allowed: {', '.join(KEYS)})")
    for k, v in cred.items():
        name = f"credential.{k}" if k in KEYS else "a credential key"
        for s in [k] + (v if isinstance(v, list) else [v]):
            if isinstance(s, str) and _looks_like_value(s):
                errs.append(f"{bid}: {name} looks like a credential VALUE — the registry "
                            f"names where a credential is, never what it is")
                break
    src = cred.get("source", "env-file")
    if src not in SOURCES:  # never echo the rejected text: it may be a pasted value
        errs.append(f"{bid}: credential.source must be one of {SOURCES}")
    env, files, note = cred.get("env"), cred.get("files"), cred.get("note")
    if env is not None and (not isinstance(env, str) or not ENV_RE.match(env)):
        errs.append(f"{bid}: credential.env must match {ENV_RE.pattern}")
    if files is not None:
        if not isinstance(files, list) or not files:
            errs.append(f"{bid}: credential.files must be a non-empty list of absolute paths")
        else:
            for n, f in enumerate(files):
                if not isinstance(f, str) or not PATH_RE.match(f) or "/../" in f or f.endswith("/.."):
                    errs.append(f"{bid}: credential.files entry {n} must be an absolute path "
                                f"matching {PATH_RE.pattern}")
    if note is not None and not (isinstance(note, str) and note.strip()):
        errs.append(f"{bid}: credential.note must be non-empty text")
    if files and approval_required is not True:
        # Reading a credential FILE and handing it to a child is allowed only where every
        # --exec needs an operator-approved proposal; otherwise a registry edit on an internal
        # backend could point at any private KEY=VALUE file and pass it to an arbitrary child.
        errs.append(f"{bid}: credential.files is allowed only on a backend with approval_required: "
                    f"true (internal backends use env or the CLI's own login)")
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


def _yaml(text: str, what: str) -> dict:
    """Parse YAML without ever echoing source text (a parser error quotes the offending line)."""
    try:
        doc = yaml.safe_load(text) or {}
    except yaml.YAMLError as e:
        mark = getattr(e, "problem_mark", None)
        raise CredError(f"{what} is not valid YAML" + (f" (line {mark.line + 1})" if mark else ""))
    return doc if isinstance(doc, dict) else {}


def _in_git_tree(path: Path) -> bool:
    return any((d / ".git").exists() for d in path.resolve().parents)


def committed_credentials(path: Path) -> dict[str, dict] | None:
    """{backend id: credential block} from the registry as committed at HEAD, or None when
    the registry is not part of a commit (outside any git work tree, or not in HEAD's tree).
    When it IS in HEAD it fails closed: credential blocks differing from the working tree
    raise. When git cannot be run at all and a `.git` ancestor exists, it raises too.
    Removing the registry from HEAD is itself a commit, attributable like any edit."""
    fail = CredError(f"cannot determine whether the backend registry {path} is committed — "
                     f"refusing (credential locations are read from the committed registry)")
    try:
        top = _git(path, "rev-parse", "--show-toplevel")
        if top.returncode != 0:
            if "not a git repository" in top.stderr:
                return None
            raise fail
        listed = _git(path, "ls-tree", "--name-only", "HEAD", "--", f"./{path.name}")
        if listed.returncode != 0:
            # Only a repository with no refs at all (unborn) has nothing committed; any other
            # failure is operational and refuses.
            refs = _git(path, "for-each-ref", "--count=1")
            if refs.returncode == 0 and not refs.stdout.strip():
                return None
            raise fail
        if not listed.stdout.strip():
            return None
        shown = _git(path, "show", f"HEAD:./{path.name}")
    except (OSError, subprocess.SubprocessError):
        if _in_git_tree(path):
            raise fail
        return None
    if shown.returncode != 0:
        raise fail
    head = _yaml(shown.stdout, f"{path} at HEAD")
    work = _yaml(path.read_text(encoding="utf-8"), str(path))

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
    # Walk the path one component at a time from `/`, each opened relative to its parent's
    # fd with O_NOFOLLOW: no component (parent or final) can be a symlink or be swapped for
    # one between a check and the open.
    parts = [c for c in fpath.split("/") if c]
    dfd = os.open("/", os.O_RDONLY | os.O_DIRECTORY)
    try:
        for comp in parts[:-1]:
            try:
                nfd = os.open(comp, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=dfd)
            except FileNotFoundError:
                return None
            except PermissionError:
                raise CredError(f"{fpath}: not readable by this user")
            except OSError:
                raise CredError(f"{fpath}: passes through a symlink or non-directory — register the real path")
            os.close(dfd)
            dfd = nfd
        try:
            fd = os.open(parts[-1], os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=dfd)
        except FileNotFoundError:
            return None
        except PermissionError:
            raise CredError(f"{fpath}: not readable by this user")
        except OSError:
            raise CredError(f"{fpath}: is a symlink or special file — register the real path")
    finally:
        os.close(dfd)
    with os.fdopen(fd, "rb") as fh:
        return _parse_var(fpath, var, fh)


def _parse_var(fpath: str, var: str, fh) -> str | None:
    st = os.fstat(fh.fileno())
    if not stat.S_ISREG(st.st_mode):
        raise CredError(f"{fpath}: not a regular file")
    if st.st_mode & (stat.S_IWGRP | stat.S_IWOTH):
        raise CredError(f"{fpath}: group/world-writable — refusing to trust it")
    if st.st_mode & (stat.S_IRGRP | stat.S_IROTH):
        # A credential store is private (0600/0400). This also bounds a retargeting registry
        # edit: an ordinary readable file cannot be named as a credential source.
        raise CredError(f"{fpath}: group/world-readable — a credential file must be private (chmod 600)")
    if st.st_uid not in (0, os.geteuid()):
        raise CredError(f"{fpath}: owned by uid {st.st_uid}, not root or the caller")
    if st.st_size > MAX_FILE:
        raise CredError(f"{fpath}: larger than {MAX_FILE} bytes — not a credential env file")
    text = fh.read(MAX_FILE + 1).decode("utf-8", errors="replace")
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
        return var, _single_line(os.environ[var], f"environment ${var}"), f"environment ${var}"
    for f in files:
        val = _read_var(f, var)
        if val:
            return var, _single_line(val, f"file {f}"), f"file {f}"
    tried = ([f"${var}"] if only_file is None else []) + files
    raise CredError(f"no value for {var} (backend {bid!r}, registry {path}: credential.env={var}, "
                    f"credential.files={files}) — tried {', '.join(tried)}")


def _single_line(val: str, where: str) -> str:
    """A credential is one line of printable text. A newline or other control character would
    let the value straddle the line-by-line output mask, so it is refused (not echoed)."""
    if any(ord(c) < 32 or ord(c) == 127 for c in val):
        raise CredError(f"value from {where} contains a newline or control character — refusing")
    return val


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
        task, prop = "", None
        if backend.get("approval_required"):
            task = a.task or _focused_task(rc_._roots()[0])
            prop = rc_.open_approval(task, backend["id"]) if task else None
            if not prop:
                raise CredError(
                    f"backend {backend['id']!r} is paid: --exec needs an approved, unused proposal "
                    f"for {task or 'the focused task (none focused)'}.\n"
                    f"  bin/fw review propose --task {task or 'T-XXX'} --backend {backend['id']} "
                    f"--why '...' --estimate-cost N   (the operator approves it)")
        var, val, _ = resolve(backend, path, a.source)
        if prop is not None:
            # One approval, one use: the cost record that consumes the proposal is written
            # BEFORE the child starts, so a second --exec cannot ride the same approval.
            rc_.log_cost(task=task, backend=backend["id"], tokens=None, cost=None,
                         purpose=f"fw review credential --exec: {os.path.basename(cmd[0])}",
                         proposal_id=prop["id"], evidence=None)
        return run_exec(var, val, cmd)
    except (CredError, rc_.CostError) as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    sys.exit(main(sys.argv[1:]))
