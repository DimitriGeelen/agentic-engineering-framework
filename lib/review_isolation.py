#!/usr/bin/env python3
"""Isolated external review runs: `fw review isolated-run` (T-4437).

T-4435's first opencode seat ran with its file and shell tools on, from a directory
inside the repo. It listed ~900 task filenames, read code beyond the redacted bundle and
read the other seats' finished reviews before writing its own. Every external seat had
been launched by hand, and each CLI's default is tools on in the current directory.

This runner makes isolation the default, with no switch to turn it off:

  - the run directory must resolve OUTSIDE the project repo and outside any git work
    tree (symlinks resolved); otherwise refused, exit 2, nothing launched;
  - each seat runs in its own empty directory holding only the bundle; the prompt carries
    the bundle, because the seat has no tool to read files with;
  - tools are off per backend, from the registry's `isolation:` block
    (policy/review-backends.yaml): argv template, a tools-off config file written into
    the run dir and named by an env var, stdin closed. A backend without an `isolation:`
    block is refused;
  - seats run one at a time and every seat's output is held in memory until all seats
    have finished, so no seat can read another's review (codex's read-only sandbox still
    reads the whole disk; a file that does not exist yet cannot be read);
  - the bundle and prompt are refused when they contain an IPv4 address or an internal
    hostname (an internal TLD, or a Host alias from ~/.ssh/config);
  - after the run, a seat whose transcript matches one of its backend's `tool_markers:`
    is labelled `non-independent` in independence.json.

The environment a seat sees is the short allowlist below plus the isolation env, never
the parent's PROJECT_ROOT / CLAUDE_PROJECT_DIR / FW_* variables.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ENV_KEEP = ("HOME", "PATH", "USER", "LOGNAME", "LANG", "LC_ALL", "TERM", "TMPDIR",
            "XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_CACHE_HOME", "XDG_STATE_HOME")
PLACEHOLDERS = ("{binary}", "{model}", "{seat_dir}", "{prompt}")
PH_RE = re.compile(r"\{[a-z_]+\}")
ENV_NAME_RE = re.compile(r"^[A-Z_][A-Z0-9_]*$")
#: Linux MAX_ARG_STRLEN is 131072 bytes; the prompt rides on argv because stdin is closed.
MAX_PROMPT_BYTES = 120_000
IPV4_RE = re.compile(r"(?<![\d.])(?:25[0-5]|2[0-4]\d|1?\d?\d)(?:\.(?:25[0-5]|2[0-4]\d|1?\d?\d)){3}(?![\d.])")
INTERNAL_HOST_RE = re.compile(
    r"\b[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.(?:local|lan|internal|intranet|home|corp|localdomain|home\.arpa)\b")


class IsolationError(Exception):
    """A refusal. The message is shown to the caller as-is."""


# ── registry block ───────────────────────────────────────────────────────────

def validate_isolation(bid: str, iso: object) -> list[str]:
    """Rules for a backend's `isolation:` block; called by review_cost.validate()."""
    if not isinstance(iso, dict):
        return [f"{bid}: isolation must be a mapping"]
    errs: list[str] = []
    argv = iso.get("argv")
    if not isinstance(argv, list) or not argv or not all(isinstance(a, str) for a in argv):
        errs.append(f"{bid}: isolation.argv must be a non-empty list of strings")
    else:
        if argv[0] != "{binary}":
            errs.append(f"{bid}: isolation.argv must start with {{binary}}")
        if "{prompt}" not in argv:
            errs.append(f"{bid}: isolation.argv must pass {{prompt}}")
        for a in argv:
            for ph in PH_RE.findall(a):
                if ph not in PLACEHOLDERS:
                    errs.append(f"{bid}: isolation.argv has unknown placeholder {ph}")
    if iso.get("stdin", "closed") != "closed":
        errs.append(f"{bid}: isolation.stdin must be `closed`")
    env = iso.get("env") or {}
    if not isinstance(env, dict) or not all(isinstance(k, str) and ENV_NAME_RE.match(k)
                                            and isinstance(v, str) for k, v in env.items()):
        errs.append(f"{bid}: isolation.env must map ENV_NAME to a string")
    toc = iso.get("tools_off_config")
    if toc is not None:
        if not isinstance(toc, dict) or not ENV_NAME_RE.match(str(toc.get("env", ""))) \
                or not isinstance(toc.get("content"), dict):
            errs.append(f"{bid}: isolation.tools_off_config needs `env:` (a variable name) and `content:` (a mapping)")
        else:
            tools = toc["content"].get("tools")
            if not isinstance(tools, dict) or not tools or any(v is not False for v in tools.values()):
                errs.append(f"{bid}: isolation.tools_off_config.content.tools must set every tool to false")
    for pat in iso.get("tool_markers") or []:
        try:
            re.compile(pat)
        except (re.error, TypeError) as e:
            errs.append(f"{bid}: bad isolation.tool_markers regex {pat!r}: {e}")
    return errs


# ── refusals ─────────────────────────────────────────────────────────────────

def check_run_dir(run_dir: Path, project_root: Path) -> Path:
    """Resolve the run dir and refuse it inside the repo or any git work tree."""
    real = Path(os.path.realpath(run_dir))
    proj = Path(os.path.realpath(project_root))
    if real == proj or proj in real.parents:
        raise IsolationError(f"run dir {real} is inside the repo ({proj}) — an external review seat must "
                             f"run outside it (T-4437). Use a directory outside the repo, e.g. the default.")
    for anc in (real, *real.parents):
        if (anc / ".git").exists():
            raise IsolationError(f"run dir {real} is inside a git work tree ({anc}) — refused (T-4437)")
    if real.exists() and any(real.iterdir()):
        raise IsolationError(f"run dir {real} is not empty — use a fresh directory")
    return real


def _ssh_aliases() -> set[str]:
    cfg = Path(os.environ.get("HOME", "~")).expanduser() / ".ssh" / "config"
    out: set[str] = set()
    try:
        for line in cfg.read_text(encoding="utf-8", errors="replace").splitlines():
            parts = line.split()
            if len(parts) > 1 and parts[0].lower() in ("host", "hostname"):
                out.update(p for p in parts[1:] if len(p) > 3 and not any(c in p for c in "*?!"))
    except OSError:
        pass
    return out


def find_leaks(text: str) -> list[str]:
    """IPs and internal hostnames in text that is about to leave the host. Never printed back
    in full by the caller: only the kind and the line number."""
    found: list[str] = []
    aliases = _ssh_aliases()
    alias_re = re.compile(r"(?<![A-Za-z0-9_.-])(?:" + "|".join(map(re.escape, sorted(aliases))) + r")(?![A-Za-z0-9_-])") \
        if aliases else None
    for n, line in enumerate(text.splitlines(), 1):
        if IPV4_RE.search(line):
            found.append(f"line {n}: IPv4 address")
        if INTERNAL_HOST_RE.search(line):
            found.append(f"line {n}: internal hostname")
        if alias_re and alias_re.search(line):
            found.append(f"line {n}: ssh host alias")
    return found


# ── seats ────────────────────────────────────────────────────────────────────

def seat_command(backend: dict, *, binary: str, seat_dir: Path, conf_dir: Path,
                 prompt: str, write_config: bool = True) -> tuple[list[str], dict[str, str]]:
    """argv + env for one isolated seat, from the backend's `isolation:` block."""
    iso = backend.get("isolation")
    if not iso:
        raise IsolationError(f"backend {backend['id']!r} has no `isolation:` block in "
                             f"policy/review-backends.yaml — refusing to run it unisolated")
    model = backend.get("model")
    vals = {"{binary}": binary, "{seat_dir}": str(seat_dir), "{prompt}": prompt, "{model}": model or ""}
    argv: list[str] = []
    for tok in iso["argv"]:
        if tok == "{model}" and not model:
            if argv and argv[-1].startswith("-"):
                argv.pop()  # no pinned model: drop the flag with its value
            continue
        # the prompt is substituted whole, never scanned for placeholders of its own
        argv.append(prompt if tok == "{prompt}" else PH_RE.sub(lambda m: vals.get(m.group(0), m.group(0)), tok))
    env = {k: os.environ[k] for k in ENV_KEEP if k in os.environ}
    for k, v in (iso.get("env") or {}).items():
        env[k] = v.replace("{seat_dir}", str(seat_dir))
    toc = iso.get("tools_off_config")
    if toc:
        cf = conf_dir / f"{backend['id']}-tools-off.json"
        if write_config:
            conf_dir.mkdir(parents=True, exist_ok=True)
            cf.write_text(json.dumps(toc["content"], indent=2) + "\n", encoding="utf-8")
        env[toc["env"]] = str(cf)
    return argv, env


def resolve_binary(backend: dict) -> str:
    b = backend.get("binary") or backend.get("worker_kind") or backend["id"]
    found = b if os.path.isabs(b) else shutil.which(b)
    if not found or not os.access(found, os.X_OK):
        raise IsolationError(f"backend {backend['id']!r}: binary {b!r} not found or not executable")
    return found


def tool_use(backend: dict, transcript: str) -> list[str]:
    """The tool_markers that matched this seat's transcript (empty = no tool use seen)."""
    return [p for p in ((backend.get("isolation") or {}).get("tool_markers") or [])
            if re.search(p, transcript, re.MULTILINE)]


def run_panel(backends: list[dict], *, prompt: str, run_dir: Path, project_root: Path,
              out_dir: Path | None = None, timeout: int = 900, dry_run: bool = False,
              log=None, binaries: dict[str, str] | None = None) -> dict:
    """Run the seats one at a time, isolated; write outputs only after the last one ends."""
    leaks = find_leaks(prompt)
    if leaks:
        raise IsolationError("bundle/prompt holds host detail that must not leave this host — refused:\n  "
                             + "\n  ".join(leaks[:20]))
    if len(prompt.encode("utf-8")) > MAX_PROMPT_BYTES:
        raise IsolationError(f"prompt + bundle is over {MAX_PROMPT_BYTES} bytes — shorten the bundle "
                             f"(it rides on argv because the seat's stdin is closed)")
    run = check_run_dir(run_dir, project_root)
    if not backends:
        raise IsolationError("no backends named")
    plans = []
    for b in backends:  # resolve everything before the first launch: a refusal launches nothing
        if not b.get("isolation"):
            raise IsolationError(f"backend {b['id']!r} has no `isolation:` block in "
                                 f"policy/review-backends.yaml — refusing to run it unisolated")
        if b.get("cost_class") == "paid":
            raise IsolationError(f"backend {b['id']!r} is paid — use `fw review propose` first; "
                                 f"isolated-run covers internal backends only")
        plans.append((b, (binaries or {}).get(b["id"])
                      or ((b.get("binary") or b.get("worker_kind") or b["id"]) if dry_run else resolve_binary(b))))
    if dry_run:
        report = {"run_dir": str(run), "seats": []}
        for b, binary in plans:
            argv, env = seat_command(b, binary=binary, seat_dir=run / "seats" / b["id"],
                                     conf_dir=run / "conf", prompt="<prompt>", write_config=False)
            report["seats"].append({"backend": b["id"], "argv": argv, "stdin": "closed",
                                    "isolation_env": sorted(set(env) - set(ENV_KEEP))})
        return report
    run.mkdir(parents=True, exist_ok=True)
    held: list[dict] = []
    try:
        for b, binary in plans:
            seat = run / "seats" / b["id"]
            seat.mkdir(parents=True)
            (seat / "bundle.md").write_text(prompt, encoding="utf-8")
            argv, env = seat_command(b, binary=binary, seat_dir=seat, conf_dir=run / "conf", prompt=prompt)
            try:
                p = subprocess.run(argv, cwd=seat, env=env, stdin=subprocess.DEVNULL,
                                   capture_output=True, text=True, timeout=timeout)
                rc, out, err = p.returncode, p.stdout, p.stderr
            except subprocess.TimeoutExpired as e:
                so = e.stdout or ""
                rc, out, err = 124, so.decode("utf-8", "replace") if isinstance(so, bytes) else so, \
                    f"timed out after {timeout}s"
            extra = sorted(str(x.relative_to(seat)) for x in seat.rglob("*") if x.name != "bundle.md")
            markers = tool_use(b, out + "\n" + err)
            held.append({"backend": b["id"], "rc": rc, "stdout": out, "stderr": err,
                         "tool_markers": markers, "seat_files_written": extra,
                         "independent": not markers and not extra})
            if log:
                log(b["id"])
    finally:
        dest = Path(out_dir) if out_dir else run / "results"
        dest.mkdir(parents=True, exist_ok=True)
        for h in held:
            (dest / f"{h['backend']}.md").write_text(h["stdout"], encoding="utf-8")
            (dest / f"{h['backend']}.stderr.txt").write_text(h["stderr"], encoding="utf-8")
        summary = [{k: h[k] for k in ("backend", "rc", "independent", "tool_markers", "seat_files_written")}
                   | {"label": "independent" if h["independent"] else "non-independent"} for h in held]
        (dest / "independence.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    return {"run_dir": str(run), "out_dir": str(dest), "seats": summary}


# ── CLI ──────────────────────────────────────────────────────────────────────

def main(argv: list[str] | None = None) -> int:
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import review_cost  # noqa: E402  (same dir; keeps one registry parser)
    import tempfile

    ap = argparse.ArgumentParser(prog="fw review isolated-run",
                                 description="Run external review seats isolated: outside the repo, "
                                             "tools off, bundle only, one seat at a time (T-4437)")
    ap.add_argument("--task", required=True)
    ap.add_argument("--backends", required=True, help="comma-separated registry ids, run in this order")
    ap.add_argument("--prompt-file", required=True, help="review instructions")
    ap.add_argument("--bundle", required=True, help="the REDACTED bundle; it is all a seat sees")
    ap.add_argument("--run-dir", help="outside the repo; default: a fresh temp dir")
    ap.add_argument("--out", help="where results land after every seat has finished (default: <run-dir>/results)")
    ap.add_argument("--timeout", type=int, default=900, help="per seat, seconds")
    ap.add_argument("--dry-run", action="store_true", help="print each seat's command; launch nothing")
    a = ap.parse_args(argv)
    proj = Path(os.environ.get("PROJECT_ROOT") or Path.cwd())
    try:
        regs = {b["id"]: b for b in review_cost.load_registry()}
        ids = [x.strip() for x in a.backends.split(",") if x.strip()]
        unknown = [i for i in ids if i not in regs]
        if unknown:
            raise IsolationError(f"unknown backend id(s): {', '.join(unknown)} — see `fw review list-backends`")
        prompt = (Path(a.prompt_file).read_text(encoding="utf-8") + "\n\n---- BUNDLE ----\n\n"
                  + Path(a.bundle).read_text(encoding="utf-8"))
        run_dir = Path(a.run_dir) if a.run_dir else Path(tempfile.mkdtemp(prefix="fw-review-"))

        def _log(bid: str) -> None:
            review_cost.log_cost(task=a.task, backend=bid, purpose="external-review (isolated-run)",
                                 tokens=None, cost=None, proposal_id=None, evidence=None)

        r = run_panel([regs[i] for i in ids], prompt=prompt, run_dir=run_dir, project_root=proj,
                      out_dir=Path(a.out) if a.out else None, timeout=a.timeout, dry_run=a.dry_run,
                      log=None if a.dry_run else _log)
        if a.dry_run and not a.run_dir:
            run_dir.rmdir()  # the temp dir this dry run made, still empty
    except (IsolationError, review_cost.CostError, OSError) as e:
        print(f"REFUSED: {e}", file=sys.stderr)
        return 2
    print(json.dumps(r, indent=2))
    return 1 if any(not s.get("independent", True) for s in r["seats"]) else 0


if __name__ == "__main__":
    sys.exit(main())
