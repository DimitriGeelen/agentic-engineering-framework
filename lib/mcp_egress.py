#!/usr/bin/env python3
"""MCP egress gate (T-5394, G-140): MCP tools that move data off this host need the
operator's approval for each use.

Origin: 050-email-archive (their T-2570) — an agent published the operator's personal data
to a claude.ai artifact through an MCP publish tool when the operator had asked only for
"a link". Our gates on data leaving the host (the send lock T-2548, Tier 0) read Bash
command text; an MCP tool call reached none of them.

One decision point, four callers:
  check     PreToolUse hook body (agents/context/check-mcp-egress.sh, matcher `mcp__.*`):
            reads the hook payload on stdin, exit 0 allow / 2 refuse.
  approve   operator only: one use of one tool (optionally bound to a target string),
            with a TTL. Refused under agent control even with --i-am-human.
  list / status / classify   read-only.
  audit     TAB lines (PASS/WARN/FAIL/INFO) for `fw audit` and `fw doctor`.

Classification is data: policy/mcp-egress.yaml (first matching rule wins), project
additions in .context/project/mcp-egress.yaml (egress only: a project can tighten, never
loosen), then an unknown tool whose name carries an egress verb is egress.

What this does NOT claim (same residual as Tier 0, T-3581): every agent runs as the same
user, so a process that writes the approval ledger directly (from a script, or python) is
indistinguishable from the operator's verb. The Write/Edit/Bash guard refuses the plain
routes (check-human-ac-tick, lib/shell_write_scan.py); a script file is not inspected.
"""
from __future__ import annotations

import argparse
import fcntl
import fnmatch
import json
import os
import re
import secrets
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import yaml

APPROVALS = "mcp-egress-approvals.jsonl"
USES = "mcp-egress-uses.jsonl"
HOOK_NAME = "check-mcp-egress"
DEFAULT_TTL_MIN = 30
MAX_TTL_MIN = 24 * 60
PROBE_TOOL = "mcp__probe__publish_files"
PUBLISH_OVERRIDE = "publish-ban"


class EgressError(Exception):
    """A refusal; the message is shown as-is."""


# ── paths and helpers ────────────────────────────────────────────────────────

def _roots() -> tuple[Path, Path]:
    fw = Path(os.environ.get("FRAMEWORK_ROOT") or Path(__file__).resolve().parent.parent)
    proj = Path(os.environ.get("PROJECT_ROOT") or Path.cwd())
    return proj, fw


def _working() -> Path:
    return _roots()[0] / ".context" / "working"


def _fwc(args: str) -> str:
    """Printed fw command, `cd <root> && <fw path> <args>` (T-5304, lib/fw_command.py)."""
    try:
        sys.path.insert(0, str(_roots()[1]))
        from lib.fw_command import user_command
        return user_command(args, str(_roots()[0]))
    except Exception:
        return f"cd {_roots()[0]} && bin/fw {args}"


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _iso(t: datetime) -> str:
    return t.strftime("%Y-%m-%dT%H:%M:%SZ")


def _parse_ts(s: str) -> datetime | None:
    try:
        return datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    except (TypeError, ValueError):
        return None


def _agent_ancestry() -> bool:
    """True when a Claude process is among this process's ancestors (lib/issues.py, T-4108):
    `env -u CLAUDECODE` clears the variable, not the parent chain."""
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


def _read_rows(path: Path) -> list[dict]:
    rows = []
    if path.is_file():
        for line in path.read_text(errors="replace").splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                r = json.loads(line)
            except ValueError:
                continue
            if isinstance(r, dict):
                rows.append(r)
    return rows


def _append(fd: int, row: dict) -> None:
    os.write(fd, (json.dumps(row, ensure_ascii=False) + "\n").encode())
    os.fsync(fd)


# ── policy ───────────────────────────────────────────────────────────────────

def _load_yaml(path: Path) -> dict:
    data = yaml.safe_load(path.read_text())
    if not isinstance(data, dict):
        raise EgressError(f"{path}: not a mapping")
    return data


def _check_rules(rules, where: str) -> list[dict]:
    if rules is None:
        return []
    if not isinstance(rules, list):
        raise EgressError(f"{where}: rules must be a list")
    out = []
    for i, r in enumerate(rules):
        if not (isinstance(r, dict) and isinstance(r.get("match"), str) and r.get("match")
                and r.get("class") in ("egress", "local", "forbidden") and isinstance(r.get("reason"), str)):
            raise EgressError(f"{where}: rule {i + 1} needs match, class (egress|local|forbidden) and reason")
        out.append({"match": r["match"], "class": r["class"], "reason": r["reason"], "source": where})
    return out


def load_policy() -> dict:
    """Raises EgressError when the framework policy is missing or invalid (the hook then
    fails closed for every MCP tool)."""
    proj, fw = _roots()
    fw_path = fw / "policy" / "mcp-egress.yaml"
    if not fw_path.is_file():
        raise EgressError(f"policy file missing: {fw_path}")
    try:
        data = _load_yaml(fw_path)
    except yaml.YAMLError as e:
        raise EgressError(f"{fw_path}: does not parse ({e.__class__.__name__})")
    rules = _check_rules(data.get("rules"), "policy/mcp-egress.yaml")
    verbs = data.get("unknown_egress_verbs")
    if not (isinstance(verbs, list) and verbs and all(isinstance(v, str) and v for v in verbs)):
        raise EgressError("policy/mcp-egress.yaml: unknown_egress_verbs must be a non-empty list")
    project_rules: list[dict] = []
    ignored: list[str] = []
    pp = proj / ".context" / "project" / "mcp-egress.yaml"
    if pp.is_file():
        try:
            pdata = _load_yaml(pp)
            for r in _check_rules(pdata.get("rules"), ".context/project/mcp-egress.yaml"):
                if r["class"] == "egress":
                    project_rules.append(r)
                else:
                    ignored.append(r["match"])
        except (EgressError, yaml.YAMLError) as e:
            # A broken project file can only have ADDED egress rules: refuse everything rather
            # than silently drop them.
            raise EgressError(f".context/project/mcp-egress.yaml: {e}")
    return {"rules": project_rules + rules, "verbs": verbs, "ignored_local": ignored}


def _tool_part(name: str) -> str:
    # mcp__<server>__<tool>; a server name never contains "__" in practice.
    parts = name.split("__", 2)
    return parts[2] if len(parts) == 3 else name


def classify(name: str, policy: dict) -> tuple[str, str, str]:
    """(class, reason, how) — how is 'rule', 'verb' or 'unclassified'."""
    for r in policy["rules"]:
        if fnmatch.fnmatchcase(name, r["match"]):
            return r["class"], r["reason"], f"rule {r['match']} ({r['source']})"
    words = _tool_part(name).lower()
    for v in policy["verbs"]:
        if re.search(r"(^|[_\-.])" + re.escape(v.lower()) + r"($|[_\-.])", words):
            return ("egress", f"unclassified tool whose name contains '{v}': treated as egress "
                    "until policy/mcp-egress.yaml classifies it", "verb")
    return "local", "unclassified (no egress verb in the name)", "unclassified"


# ── approvals ────────────────────────────────────────────────────────────────

def _open_locked(path: Path) -> int:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd = os.open(path, os.O_RDWR | os.O_APPEND | os.O_CREAT, 0o644)
    fcntl.flock(fd, fcntl.LOCK_EX)
    return fd


def _state() -> tuple[list[dict], dict]:
    approvals = _read_rows(_working() / APPROVALS)
    uses = {u.get("id"): u for u in _read_rows(_working() / USES) if u.get("id")}
    return approvals, uses


def _status_of(a: dict, uses: dict, now: datetime) -> str:
    if a.get("id") in uses:
        return "used"
    exp = _parse_ts(a.get("expires", ""))
    if exp is None or exp <= now:
        return "expired"
    return "open"


def approve(tool: str, reason: str, target: str | None, ttl_min: int,
            override_publish_ban: bool = False) -> dict:
    if _is_agent():
        raise EgressError(
            "REFUSED: approving an MCP egress call is an operator action. It is never run under "
            "agent control (CLAUDECODE/AI_AGENT/CLAUDE_CODE_ENTRYPOINT set, or a Claude process is "
            "an ancestor), and --i-am-human does not lift it (T-5394). The operator runs it in "
            "their own terminal.")
    if not tool.startswith("mcp__") or any(c in tool for c in "*?[]"):
        raise EgressError("give the exact MCP tool name, e.g. mcp__claude-artifacts__publish_files "
                          "(no wildcards: one approval covers one tool)")
    forbidden = classify(tool, load_policy())[0] == "forbidden"
    if forbidden and not override_publish_ban:
        raise EgressError(
            f"REFUSED: {tool} is covered by the publish-to-Anthropic ban (operator ruling "
            "2026-11-24, T-5405); an ordinary approval does not open it. To allow ONE use, "
            "re-run with --override-publish-ban. To switch the ban off for the project: "
            "fw config set PUBLISH_TO_ANTHROPIC allow")
    if override_publish_ban and not forbidden:
        raise EgressError(f"{tool} is not covered by the publish ban; use an ordinary approval "
                          "(without --override-publish-ban)")
    if not reason or not reason.strip():
        raise EgressError("--reason is required: say what may leave the host, and why")
    if not (1 <= ttl_min <= MAX_TTL_MIN):
        raise EgressError(f"--ttl-minutes must be 1..{MAX_TTL_MIN}")
    now = _now()
    row = {"id": "EG-" + secrets.token_hex(4), "tool": tool, "target": target or "",
           "reason": reason.strip(), "ts": _iso(now),
           "expires": _iso(now + timedelta(minutes=ttl_min)), "by": "operator",
           "user": os.environ.get("USER", "")}
    if override_publish_ban:
        row["override"] = PUBLISH_OVERRIDE
    fd = _open_locked(_working() / APPROVALS)
    try:
        _append(fd, row)
    finally:
        os.close(fd)
    return row


def _target_ok(a: dict, tool_input) -> bool:
    t = a.get("target") or ""
    if not t:
        return True
    try:
        blob = json.dumps(tool_input, ensure_ascii=False, sort_keys=True)
    except (TypeError, ValueError):
        return False
    return t in blob


def consume(tool: str, tool_input, tool_use_id: str, override: bool = False) -> dict | None:
    """Consume the oldest open approval for `tool` (and its target). A second fire of the same
    tool_use_id (T-1508 duplicate hook fire) is re-admitted without consuming another."""
    fd = _open_locked(_working() / USES)
    try:
        approvals, uses = _state()
        if tool_use_id:
            for u in uses.values():
                if u.get("tool_use_id") == tool_use_id and u.get("tool") == tool:
                    return {"id": u.get("id"), "duplicate_fire": True}
        now = _now()
        for a in sorted(approvals, key=lambda r: r.get("ts", "")):
            if bool(a.get("override") == PUBLISH_OVERRIDE) != override:
                continue
            if a.get("tool") == tool and _status_of(a, uses, now) == "open" and _target_ok(a, tool_input):
                _append(fd, {"id": a["id"], "tool": tool, "ts": _iso(now),
                             "tool_use_id": tool_use_id or ""})
                return a
        return None
    finally:
        os.close(fd)


# ── hook ─────────────────────────────────────────────────────────────────────

def _deny(lines: list[str]) -> int:
    sys.stderr.write("FW-DENY: mcp-egress (T-5394)\n" + "\n".join(lines) + "\n")
    return 2


def _forbidden(name: str, data: dict, reason: str) -> int:
    _tu = data.get("tool_use_id")
    tuid: str = _tu if isinstance(_tu, str) else ""
    try:
        used = consume(name, data.get("tool_input"), tuid, override=True)
    except OSError as e:
        return _deny([f"BLOCKED: {name} — the approval ledger cannot be read or locked ({e}); "
                      "refused (fail closed).", "Policy: T-5405 (publish ban)"])
    if used:
        if not used.get("duplicate_fire"):
            sys.stderr.write(f"mcp-egress: {name} allowed once by operator override {used['id']} "
                             f"({used.get('reason', '')}); approval now used.\n")
        return 0
    return _deny([
        f"BLOCKED: {name} — publishing to Anthropic is blocked by default in this project ({reason}).",
        "Operator ruling 2026-11-24 (T-5405): no agent publishes to claude.ai artifacts, Claude Docs",
        "or design sync unasked. An ordinary egress approval does not open it. You cannot lift it.",
        "Show the content in the conversation instead. The operator can:",
        "  - allow ONE use, in their own terminal: "
        + _fwc("egress approve " + name + ' --override-publish-ban --reason "<what may leave, and why>"'),
        "  - switch the ban off for this project: " + _fwc("config set PUBLISH_TO_ANTHROPIC allow"),
        "Policy: T-5405 (publish ban), T-5394 (MCP egress gate)",
    ])


def hook_check(raw: str) -> int:
    try:
        data = json.loads(raw)
        if not isinstance(data, dict):
            raise ValueError
    except ValueError:
        return _deny(["BLOCKED: unreadable hook payload for an MCP tool — refused (fail closed).",
                      "Policy: T-5394 (MCP egress gate)"])
    name = data.get("tool_name")
    if not isinstance(name, str) or not name:
        return _deny(["BLOCKED: hook payload has no tool_name — refused (fail closed).",
                      "Policy: T-5394 (MCP egress gate)"])
    if not name.startswith("mcp__"):
        return 0
    try:
        policy = load_policy()
    except EgressError as e:
        return _deny([f"BLOCKED: {name} — the MCP egress policy cannot be read ({e}), so every MCP "
                      "tool is refused (fail closed).",
                      "Fix policy/mcp-egress.yaml (or .context/project/mcp-egress.yaml).",
                      "Policy: T-5394 (MCP egress gate)"])
    cls, reason, _how = classify(name, policy)
    if cls == "forbidden":
        try:
            import publish_ban
            allowed = publish_ban.mode() == "allow"
        except Exception:
            allowed = False
        if allowed:
            # The operator switched the ban off: back to the ordinary classes.
            cls, reason, _how = classify(name, {**policy, "rules": [
                r for r in policy["rules"] if r["class"] != "forbidden"]})
        else:
            return _forbidden(name, data, reason)
    if cls != "egress":
        return 0
    tool_input = data.get("tool_input")
    _tu = data.get("tool_use_id")
    tuid: str = _tu if isinstance(_tu, str) else ""
    try:
        used = consume(name, tool_input, tuid)
    except OSError as e:
        return _deny([f"BLOCKED: {name} — the approval ledger cannot be read or locked ({e}); "
                      "refused (fail closed).", "Policy: T-5394 (MCP egress gate)"])
    if used:
        if not used.get("duplicate_fire"):
            sys.stderr.write(f"mcp-egress: {name} allowed once by operator approval {used['id']} "
                             f"({used.get('reason', '')}); approval now used.\n")
        return 0
    approve_cmd = _fwc("egress approve " + name + ' --reason "<what may leave, and why>"')
    return _deny([
        f"BLOCKED: {name} — this MCP tool can move data off this host ({reason}).",
        "It needs the operator's approval for this one use. You cannot approve it yourself.",
        "Instead, show the content inside the conversation, and ask the operator whether it",
        "may leave the host. If they say yes, they run in their own terminal:",
        "  " + approve_cmd,
        "(add --target <text> to bind the approval to one destination; one approval = one call).",
        "Policy: T-5394 (MCP egress gate, G-140)",
    ])


# ── wiring and inventory (audit) ─────────────────────────────────────────────

def hook_wired(settings: Path) -> bool:
    try:
        d = json.loads(settings.read_text())
    except (OSError, ValueError):
        return False
    for b in (d.get("hooks", {}) or {}).get("PreToolUse", []) or []:
        m = b.get("matcher", "")
        try:
            covers = m in ("", "*") or re.fullmatch(m, PROBE_TOOL) is not None
        except re.error:
            covers = False
        if covers and any(HOOK_NAME in (h.get("command") or "") for h in b.get("hooks", []) or []):
            return True
    return False


def registered_servers() -> tuple[dict, list[str]]:
    """{server: [where registered]} from every file that can be read statically, plus notes on
    what cannot be enumerated."""
    proj, fw = _roots()
    found: dict[str, list[str]] = {}

    def add(name, where):
        found.setdefault(str(name), [])
        if where not in found[str(name)]:
            found[str(name)].append(where)

    def from_json(path: Path, label: str, project_key: str | None = None):
        try:
            d = json.loads(path.read_text())
        except (OSError, ValueError):
            return
        if not isinstance(d, dict):
            return
        for s in (d.get("mcpServers") or {}):
            add(s, label)
        for s in (d.get("enabledMcpjsonServers") or []):
            add(s, label + " (enabled)")
        if project_key:
            p = (d.get("projects") or {}).get(project_key) or {}
            for s in (p.get("mcpServers") or {}):
                add(s, label + " (project)")

    from_json(proj / ".mcp.json", ".mcp.json")
    from_json(proj / ".claude" / "settings.json", ".claude/settings.json")
    from_json(proj / ".claude" / "settings.local.json", ".claude/settings.local.json")
    home = Path(os.environ.get("HOME", "/nonexistent"))
    from_json(home / ".claude.json", "~/.claude.json", str(proj.resolve()))
    from_json(home / ".claude" / "settings.json", "~/.claude/settings.json")
    notes = ["claude.ai connectors and plugin-provided MCP servers (mcp__plugin_*) are not listed "
             "in any file this audit can read; the hook still classifies every call by name at run time",
             "tool lists of third-party servers cannot be enumerated without starting them; the egress "
             "rules that cover each server are listed instead"]
    return found, notes


def _rule_applies(pattern: str, server: str) -> bool:
    prefix = pattern.rsplit("__", 1)[0] if "__" in pattern else pattern
    return fnmatch.fnmatchcase(f"mcp__{server}", prefix)


def audit_lines() -> list[tuple[str, str]]:
    proj, fw = _roots()
    out: list[tuple[str, str]] = []
    try:
        policy = load_policy()
    except EgressError as e:
        return [("FAIL", f"MCP egress policy unreadable: {e} — the hook refuses every MCP tool")]
    settings = proj / ".claude" / "settings.json"
    wired = hook_wired(settings)
    gate = f"gate: PreToolUse {HOOK_NAME}" if wired else "gate: NONE"
    servers, notes = registered_servers()
    egress_total = 0
    for s in sorted(servers):
        egress_rules = [r["match"] for r in policy["rules"]
                        if r["class"] == "egress" and _rule_applies(r["match"], s)]
        tools = []
        if s == "fw":
            try:
                man = json.loads((fw / "agents" / "mcp" / "framework-mcp-manifest.json").read_text())
                tools = [f"mcp__fw__{t['name']}" for t in man.get("tools", []) if t.get("name")]
            except (OSError, ValueError, KeyError, TypeError):
                tools = []
        egress_tools = [t for t in tools if classify(t, policy)[0] == "egress"]
        named = egress_tools or egress_rules
        egress_total += len(named)
        where = ", ".join(servers[s])
        if named:
            shown = ", ".join(n.split("__", 2)[-1] if n.startswith(f"mcp__{s}__") else n for n in named[:12])
            more = f" (+{len(named) - 12} more)" if len(named) > 12 else ""
            out.append(("PASS" if wired else "FAIL",
                        f"MCP server '{s}' [{where}]: egress-capable {shown}{more} — {gate}"))
        else:
            out.append(("PASS" if wired else "WARN",
                        f"MCP server '{s}' [{where}]: no egress rule; tools with egress verbs in "
                        f"their names are refused by default — {gate}"))
    if policy["ignored_local"]:
        out.append(("WARN", ".context/project/mcp-egress.yaml: local rules are ignored (a project can "
                    "only add egress rules): " + ", ".join(policy["ignored_local"][:5])))
    if not wired:
        out.append(("FAIL", f"MCP egress hook not wired in .claude/settings.json (PreToolUse "
                    f"`mcp__.*` → fw hook {HOOK_NAME}): MCP tools can move data off this host "
                    f"ungated. Fix: {_fwc('upgrade')}"))
    else:
        out.append(("PASS", f"MCP egress hook wired ({len(servers)} registered server(s), "
                    f"{egress_total} egress rule(s)/tool(s) gated)"))
    try:
        import publish_ban
        out.extend(publish_ban.audit_lines(proj))
    except Exception as e:  # never hide the ban state behind an import problem
        out.append(("FAIL", f"publishing to Anthropic: state unreadable ({e.__class__.__name__})"))
    for n in notes:
        out.append(("INFO", n))
    return out


# ── CLI ──────────────────────────────────────────────────────────────────────

def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="fw egress", description="MCP egress gate (T-5394)")
    sub = p.add_subparsers(dest="cmd")
    a = sub.add_parser("approve", help="operator: allow ONE use of an egress MCP tool")
    a.add_argument("tool")
    a.add_argument("--reason", required=True)
    a.add_argument("--target", default=None, help="text the call's input must contain")
    a.add_argument("--ttl-minutes", type=int, default=DEFAULT_TTL_MIN)
    a.add_argument("--override-publish-ban", action="store_true",
                   help="operator: allow ONE use of a tool the publish-to-Anthropic ban covers")
    a.add_argument("--i-am-human", action="store_true", help="accepted, but does not lift the agent refusal")
    sub.add_parser("list", help="approvals and their state")
    sub.add_parser("status", help="hook wiring and open approvals")
    c = sub.add_parser("classify", help="class of a tool name")
    c.add_argument("tool")
    sub.add_parser("check", help="PreToolUse hook body (payload on stdin)")
    sub.add_parser("audit", help="TAB lines for fw audit / fw doctor")
    args = p.parse_args(argv)

    try:
        if args.cmd == "check":
            try:
                raw = sys.stdin.read()
            except (OSError, UnicodeDecodeError):
                raw = ""
            return hook_check(raw)
        if args.cmd == "approve":
            row = approve(args.tool, args.reason, args.target, args.ttl_minutes,
                          args.override_publish_ban)
            print(f"approved {row['id']}: one use of {row['tool']}"
                  f"{' (target ' + row['target'] + ')' if row['target'] else ''} until {row['expires']}")
            return 0
        if args.cmd == "list":
            approvals, uses = _state()
            now = _now()
            if not approvals:
                print("no MCP egress approvals recorded")
            for r in approvals:
                print(f"{r.get('id')}  {_status_of(r, uses, now):8}  {r.get('tool')}  "
                      f"target={r.get('target') or '-'}  expires={r.get('expires')}  {r.get('reason', '')}")
            return 0
        if args.cmd == "status":
            proj, _ = _roots()
            wired = hook_wired(proj / ".claude" / "settings.json")
            approvals, uses = _state()
            now = _now()
            open_n = sum(1 for r in approvals if _status_of(r, uses, now) == "open")
            print(f"hook {HOOK_NAME}: {'wired' if wired else 'NOT WIRED'} in .claude/settings.json")
            print(f"open approvals: {open_n}  (total recorded: {len(approvals)}, used: {len(uses)})")
            return 0 if wired else 1
        if args.cmd == "classify":
            cls, reason, how = classify(args.tool, load_policy())
            print(f"{cls}\t{reason}\t{how}")
            return 0
        if args.cmd == "audit":
            for lvl, msg in audit_lines():
                print(f"{lvl}\t{msg}")
            return 0
        p.print_help()
        return 1
    except EgressError as e:
        print(str(e), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
