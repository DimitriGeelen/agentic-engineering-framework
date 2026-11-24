#!/usr/bin/env python3
"""hook_wiring — the operator wires hooks; agents prepare the change as a runme (T-5403).

Operator ruling 2026-11-24 ("a"): the operator wires hooks into `.claude/settings.json`;
an agent prepares the change as a one-line runme. Before this, the only check on the file
was `check-settings-edit.sh`, a PostToolUse reminder that never blocks, and a worker wired
a hook by itself (T-5394). An agent that can edit its own gates can switch them off.

Three verbs:

  check     PreToolUse hook body (`fw hook check-hook-wiring`, matcher Write|Edit|Bash).
            Write/Edit: the resulting file is computed and its WIRING (`hooks` and
            `disableAllHooks`) compared with the current file's; under agent control a
            change is refused (exit 2). Other keys pass. A file that does not parse as JSON
            (before or after) is refused under agent control: the wiring cannot be compared.
            Bash: a command that writes the file is refused under agent control. The
            command is read by lib/shell_write_scan.py (`scan(guarded=, mention=)`), the
            same reader as the Human-AC tick guard. `fw init`, `fw upgrade` and
            `fw enforcement baseline` are framework writers: their text writes nothing.
  propose   Writes the operator runme for ONE hook change (add or remove) and prints the
            `bash …/runme.sh` line to hand over. Agents may run it.
  apply     What the runme runs: applies the change and refreshes the enforcement baseline.
            Refused under agent control (env, or a Claude process among the ancestors), so
            an agent running the runme itself does not get the change.

Guarded files: `.claude/settings.json` and `.claude/settings.local.json` (Claude Code reads
hooks and `disableAllHooks` from both), and the `.claude` directory itself as a write target.

What this does NOT see (same boundary as Tier 0, T-2742): a script file a command runs, or
a path built at run time. Such a write is caught after the fact: `fw doctor` / `fw audit`
compare the hooks hash with the enforcement baseline. It is fail-closed against accidents,
not forgery-resistant: an agent running as the same user can still write the file from a
script, which the operator sees as a baseline change.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shlex
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

_LIB = os.path.dirname(os.path.abspath(__file__))
if _LIB not in sys.path:
    sys.path.insert(0, _LIB)

RULING = "operator wires hooks, 2026-11-24, T-5403"
WIRING_KEYS = ("hooks", "disableAllHooks")
SETTINGS_NAMES = ("settings.json", "settings.local.json")
EVENTS = ("PreToolUse", "PostToolUse", "UserPromptSubmit", "Notification", "Stop",
          "SubagentStop", "PreCompact", "SessionStart", "SessionEnd")


class WiringError(Exception):
    pass


# ── agent control (same detection as `fw egress approve`, lib/mcp_egress.py) ─────────

def _agent_ancestry() -> bool:
    """True when a Claude process is among this process's ancestors (T-4108)."""
    pid = os.getppid()
    for _ in range(64):
        if pid <= 1:
            return False
        try:
            argv = Path(f"/proc/{pid}/cmdline").read_bytes().split(b"\0")
            stat = Path(f"/proc/{pid}/stat").read_text()
        except OSError:
            return False
        names = {os.path.basename(x.decode(errors="replace")) for x in argv[:3] if x}
        if names & {"claude", "claude-fw", "claude-code"} or any(
                b"@anthropic-ai/claude-code" in x for x in argv[:3]):
            return True
        try:
            pid = int(stat.rsplit(")", 1)[1].split()[1])
        except (IndexError, ValueError):
            return False
    return False


def _is_agent() -> bool:
    e = os.environ
    return (e.get("CLAUDECODE") == "1" or bool(e.get("AI_AGENT", "").strip())
            or bool(e.get("CLAUDE_CODE_ENTRYPOINT")) or _agent_ancestry())


# ── guarded paths ─────────────────────────────────────────────────────────────────────

def is_settings_path(path: str) -> bool:
    p = os.path.normpath(path.replace("\\", "/"))
    return os.path.basename(p) in SETTINGS_NAMES and \
        os.path.basename(os.path.dirname(p)) == ".claude"


def _guarded(path: str) -> bool:
    """A Bash write target: a settings file, or the `.claude` directory itself."""
    return is_settings_path(path) or os.path.basename(os.path.normpath(path)) == ".claude"


_FULL_RE = re.compile(r"\.claude/+settings(?:\.local)?\.json", re.I)
_BARE_RE = re.compile(r"(?<![\w./-])settings(?:\.local)?\.json", re.I)


def _mention_for(cwd: str | None):
    """A command names the guarded file: the path itself, or a bare `settings.json` word
    in a command that also names `.claude` or runs from inside a `.claude` directory."""
    in_claude = bool(cwd) and os.path.basename(os.path.normpath(cwd)) == ".claude"

    def mention(text: str) -> bool:
        if _FULL_RE.search(text):
            return True
        return bool(_BARE_RE.search(text)) and (in_claude or ".claude" in text)
    return mention


def wiring(data) -> dict:
    if not isinstance(data, dict):
        raise WiringError("settings file is not a JSON object")
    return {k: data.get(k) for k in WIRING_KEYS}


# ── the gate ──────────────────────────────────────────────────────────────────────────

def _fwc(args: str) -> str:
    try:
        from fw_command import user_command
        return user_command(args)
    except Exception:  # noqa: BLE001 — the message must still print
        return f"bin/fw {args}"


def _refuse(what: str, why: list[str]) -> int:
    w = sys.stderr.write
    w("\n══════════════════════════════════════════════════════════\n")
    w("  HOOK WIRING CHANGE BLOCKED — the operator wires hooks\n")
    w("══════════════════════════════════════════════════════════\n\n")
    w(f"  Blocked: {what}\n")
    for line in why[:5]:
        w(f"  Why:     {line}\n")
    w(f"\n  Ruling:  {RULING}. Agents do not change hook wiring in\n")
    w("           .claude/settings.json (hooks, disableAllHooks); they prepare it for the\n")
    w("           operator as a one-line runme.\n\n")
    w("  To proceed, prepare the change and hand the printed `bash …/runme.sh` line over:\n")
    w("    " + _fwc("hook-wiring propose --event PreToolUse --matcher '<matcher>' "
                    "--command '<hook command>' [--remove]") + "\n")
    w("  Other keys (permissions, env, …) may still be edited with the Edit tool.\n")
    w("══════════════════════════════════════════════════════════\n\n")
    return 2


def _apply_edit(old: str, ti: dict) -> str | None:
    """The file after an Edit/MultiEdit, or None when an old_string is not present (the tool
    itself fails then, so nothing is written)."""
    edits = ti.get("edits") if isinstance(ti.get("edits"), list) else [ti]
    text = old
    for e in edits:
        o, n = e.get("old_string", ""), e.get("new_string", "")
        if o == "" or o not in text:
            return None
        text = text.replace(o, n) if e.get("replace_all") else text.replace(o, n, 1)
    return text


def check_write(data: dict) -> int:
    ti = data.get("tool_input", {}) or {}
    path = ti.get("file_path") or ""
    if not path or not is_settings_path(path):
        return 0
    try:
        old = Path(path).read_text()
    except FileNotFoundError:
        old = ""
    except OSError as e:
        return _refuse(f"{data.get('tool_name')} {path}", [f"current file unreadable ({e})"]) \
            if _is_agent() else 0
    if data.get("tool_name") == "Write":
        new = ti.get("content", "")
    else:
        new = _apply_edit(old, ti)
        if new is None:
            return 0
    try:
        before = wiring(json.loads(old)) if old.strip() else wiring({})
        after = wiring(json.loads(new))
    except (ValueError, WiringError) as e:
        if not _is_agent():
            return 0
        return _refuse(f"{data.get('tool_name')} {path}",
                       [f"the file does not parse as a JSON object ({e}); the hook wiring "
                        "cannot be compared, so the edit is refused (fail closed)"])
    if before == after:
        return 0
    changed = [k for k in WIRING_KEYS if before.get(k) != after.get(k)]
    if not _is_agent():
        sys.stderr.write(f"NOTE: hook wiring changed in {path} ({', '.join(changed)}) — "
                         "advisory only, no agent-control signal. Refresh: fw enforcement baseline\n")
        return 0
    return _refuse(f"{data.get('tool_name')} {path}",
                   [f"the edit changes {', '.join(changed)}"])


_HOOK_ENABLE_READONLY = {"--dry-run", "-h", "--help"}


def hook_enable_writes(command: str, depth: int = 0) -> list[str]:
    """`fw hook-enable` (bin/hook-enable.sh) writes hook wiring. Typed by an agent, without
    --dry-run, it is the same change as an Edit and is refused the same way. Read in command
    position (wrappers and assignments skipped, `bash X.sh` and `sh -c '…'` followed)."""
    if "hook-enable" not in command or depth > 3:
        return []
    from shell_write_scan import _segments, _substitutions, _tokens, _unwrap
    found = []
    for text in [command] + _substitutions(command):
        toks = _tokens(text)
        if toks is None:
            if "hook-enable" in text:
                found.append("command names hook-enable and does not tokenise (fail closed)")
            continue
        for seg in _segments(toks):
            argv, _ = _unwrap(seg)
            if argv and os.path.basename(argv[0]) in ("bash", "sh", "zsh", "dash"):
                if len(argv) > 2 and argv[1] == "-c":
                    found += hook_enable_writes(argv[2], depth + 1)
                    continue
                argv = argv[1:]
            if not argv:
                continue
            base = os.path.basename(argv[0])
            if base in ("hook-enable.sh", "hook-enable"):
                args = argv[1:]
            elif base == "fw" and len(argv) > 1 and argv[1] == "hook-enable":
                args = argv[2:]
            else:
                continue
            if not _HOOK_ENABLE_READONLY & set(args):
                found.append("fw hook-enable writes hook wiring into .claude/settings.json")
    return found


def check_bash(data: dict) -> int:
    command = (data.get("tool_input", {}) or {}).get("command", "") or ""
    if not command.strip():
        return 0
    cwd = data.get("cwd") or os.environ.get("PROJECT_ROOT") or os.getcwd()
    mention = _mention_for(cwd)
    from shell_write_scan import Hit, normalised, scan
    hits = [Hit(r) for r in hook_enable_writes(command)]
    if not hits and not mention(normalised(command)) and ".claude" not in command:
        return 0   # fast path: nothing in the text names the file or its directory
    hits += scan(command, cwd, guarded=_guarded, mention=mention)
    if not hits:
        return 0
    if not _is_agent():
        sys.stderr.write(f"NOTE: shell write to .claude/settings (advisory only — no "
                         f"agent-control signal): {hits[0].reason}\n")
        return 0
    return _refuse(f"Bash: {command.strip().splitlines()[0][:150]}",
                   [h.reason + (f"  [{h.target}]" if h.target else "") for h in hits] +
                   ["a shell write's result cannot be compared before it runs, so the "
                    "settings files are not written from Bash under agent control "
                    "(reading with cat, grep or sed -n passes)"])


def hook_check(raw: str) -> int:
    try:
        data = json.loads(raw)
    except ValueError:
        return 0 if not _is_agent() or "settings" not in raw else \
            _refuse("a tool call whose payload does not parse", ["fail closed"])
    tool = data.get("tool_name", "")
    if tool == "Bash":
        return check_bash(data)
    if tool in ("Write", "Edit", "MultiEdit"):
        return check_write(data)
    return 0


# ── the change itself (operator side) ─────────────────────────────────────────────────

def change_settings(data: dict, event: str, matcher: str, command: str, remove: bool) -> bool:
    """Apply one change in place. Returns True when the settings changed."""
    hooks = data.setdefault("hooks", {})
    if not isinstance(hooks, dict):
        raise WiringError("`hooks` is not an object")
    entries = hooks.setdefault(event, [])
    if remove:
        changed = False
        for entry in list(entries):
            if entry.get("matcher", "") != matcher:
                continue
            kept = [h for h in entry.get("hooks", []) if h.get("command") != command]
            if len(kept) != len(entry.get("hooks", [])):
                changed = True
                if kept:
                    entry["hooks"] = kept
                else:
                    entries.remove(entry)
        if not entries:
            hooks.pop(event, None)
        return changed
    for entry in entries:
        if entry.get("matcher", "") == matcher:
            if any(h.get("command") == command for h in entry.get("hooks", [])):
                return False
            entry.setdefault("hooks", []).append({"type": "command", "command": command})
            return True
    entries.append({"matcher": matcher, "hooks": [{"type": "command", "command": command}]})
    return True


def baseline_hash(data: dict) -> str:
    """Same formula as `fw enforcement baseline` (bin/fw) and lib/upgrade.sh _ef_hooks_hash."""
    return hashlib.sha256(json.dumps(data.get("hooks", {}), sort_keys=True).encode()).hexdigest()


def apply(settings: Path, baseline: Path, event: str, matcher: str, command: str,
          remove: bool) -> str:
    if _is_agent():
        raise WiringError("applying a hook wiring change is an operator action — refused under "
                          "agent control (CLAUDECODE/AI_AGENT/CLAUDE_CODE_ENTRYPOINT set, or a "
                          "Claude process is an ancestor). Run the runme in your own terminal "
                          f"({RULING}).")
    text = settings.read_text() if settings.exists() else "{}"
    data = json.loads(text)
    if not isinstance(data, dict):
        raise WiringError(f"{settings} is not a JSON object")
    changed = change_settings(data, event, matcher, command, remove)
    if changed:
        tmp = settings.with_name(settings.name + ".tmp-hook-wiring")
        tmp.write_text(json.dumps(data, indent=2) + "\n")
        os.replace(tmp, settings)
    baseline.parent.mkdir(parents=True, exist_ok=True)
    baseline.write_text(baseline_hash(data) + "\n")
    verb = "removed" if remove else "added"
    return (f"hook {verb}: {event} [{matcher}] {command}" if changed
            else f"no change: {event} [{matcher}] {command} already {verb}") + \
        f"; enforcement baseline refreshed ({baseline})"


def propose(root: Path, event: str, matcher: str, command: str, remove: bool,
            name: str | None) -> str:
    if event not in EVENTS:
        raise WiringError(f"--event must be one of: {', '.join(EVENTS)}")
    if not command.strip():
        raise WiringError("--command is empty")
    root = root.resolve()
    settings = root / ".claude" / "settings.json"
    baseline = root / ".context" / "project" / "enforcement-baseline.sha256"
    slug = re.sub(r"[^A-Za-z0-9]+", "-", command.split()[-1] if command.split() else "hook")
    name = name or ("hook-wiring-" + ("remove-" if remove else "add-") + slug.strip("-")[:40]
                    + "-" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S"))
    line = shlex.join(["python3", os.path.join(_LIB, "hook_wiring.py"), "apply",
                       "--settings", str(settings), "--baseline", str(baseline),
                       "--event", event, "--matcher", matcher, "--command", command]
                      + (["--remove"] if remove else []))
    line = f"cd {shlex.quote(str(root))} && {line}"
    desc = (f"{'Remove' if remove else 'Add'} hook {event} [{matcher}] {command}; refresh the "
            f"enforcement baseline ({RULING})")
    env = dict(os.environ, PROJECT_ROOT=str(root))
    r = subprocess.run(["bash", "-c", 'source "$1"; shift; runme_main new "$@"', "runme",
                        os.path.join(_LIB, "runme.sh"), name, "--desc", desc, "--", line],
                       env=env, capture_output=True, text=True)
    if r.returncode != 0:
        raise WiringError(f"fw runme new failed ({r.returncode}): {r.stderr.strip() or r.stdout.strip()}")
    script = root / ".context" / "runme" / name / "runme.sh"
    if not script.is_file():
        raise WiringError(f"runme not written: {script}")
    return f"bash {script}"


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="fw hook-wiring", description=(__doc__ or "").split("\n\n")[0])
    sub = ap.add_subparsers(dest="verb", required=True)
    sub.add_parser("check", help="PreToolUse hook body (reads the payload on stdin)")
    for v in ("propose", "apply"):
        p = sub.add_parser(v)
        p.add_argument("--event", required=True)
        p.add_argument("--matcher", required=True)
        p.add_argument("--command", required=True)
        p.add_argument("--remove", action="store_true")
        if v == "propose":
            p.add_argument("--name", default=None, help="runme name (default: derived)")
        else:
            p.add_argument("--settings", required=True)
            p.add_argument("--baseline", required=True)
    a = ap.parse_args(argv)
    if a.verb == "check":
        return hook_check(sys.stdin.read())
    try:
        if a.verb == "propose":
            root = Path(os.environ.get("PROJECT_ROOT") or os.getcwd())
            line = propose(root, a.event, a.matcher, a.command, a.remove, a.name)
            print("Runme written. Hand the operator this one line (ruling: "
                  f"{RULING}):\n\n  {line}\n")
            print(f"Then watch it: {_fwc('runme watch ' + Path(line.split()[-1]).parent.name)}")
            return 0
        print(apply(Path(a.settings), Path(a.baseline), a.event, a.matcher, a.command, a.remove))
        return 0
    except (WiringError, OSError, ValueError) as e:
        print(f"REFUSED: {e}" if a.verb == "apply" else f"ERROR: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
