#!/usr/bin/env python3
"""CLI for reviewer-closeable delegation (T-3445, mechanism for D-626).

Two verbs, one module because they share the classifier:

    fw task delegate T-XXX [--dry-run] [--json]
    fw reviewer surface [--json] [--warn-threshold N]

`delegate` is the act D-626 authorises: it classifies a human-owned task's open
Human criteria, converts the deterministic ones to `[REVIEWER]` Agent criteria
keeping Steps/Expected/If-not verbatim, leaves every carve-out alone, and moves
ownership only when nothing is left for the operator to answer.

It writes ownership directly rather than shelling `fw task update --owner agent`
on purpose. `owner: human` is sticky under R-033 and that path needs
`--skip-human-ownership`, a LOGGED BYPASS — and delegation is not a bypass of
the sovereignty gate, it is the sanctioned transfer the operator ruled for. Its
audit trail is `.context/working/delegations.jsonl`, one line per delegation,
naming the ruling. Using the bypass would have recorded the same act as a gate
circumvention, which is exactly the wrong thing to have in the log.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

_HERE = Path(__file__).resolve().parent
if str(_HERE.parent) not in sys.path:
    sys.path.insert(0, str(_HERE.parent))

from lib.delegation import (  # noqa: E402
    AGENT_SELF,
    OPERATOR_ONLY,
    REVIEWER_CLOSEABLE,
    RULING,
    Criterion,
    classify,
    frontmatter,
    human_criteria,
    parse_criteria,
    surface_scan,
    surface_verdict,
    task_touches_render_surface_cheap,
)

GREEN, YELLOW, RED, CYAN, BOLD, NC = (
    "\033[0;32m", "\033[1;33m", "\033[0;31m", "\033[0;36m", "\033[1m", "\033[0m"
)

DEFAULT_SURFACE_WARN = 50
LEDGER = Path(".context/working/delegations.jsonl")


def _project_root() -> Path:
    return Path(os.environ.get("PROJECT_ROOT") or os.getcwd())


def _framework_root() -> Path:
    return Path(os.environ.get("FRAMEWORK_ROOT") or _HERE.parent)


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


# ── render surface: the authoritative predicate, not the cheap one ───────────


def _render_surface(task_file: Path) -> bool:
    """Ask lib/render_surface.sh, the same predicate the T-1766 close gate uses.

    The corpus report uses the git-free approximation because it walks hundreds
    of tasks; a single delegation can afford the real answer, and it must have
    it — converting a criterion the close gate will then demand back as
    `[REVIEW]` would be a delegation that cannot close.

    Falls back to the cheap scan when bash or the lib is unavailable (a consumer
    checkout mid-upgrade), since a missed carve-out is the one direction that
    must not happen silently.
    """
    lib = _framework_root() / "lib" / "render_surface.sh"
    if lib.is_file():
        try:
            rc = subprocess.run(
                ["bash", "-c", f'source "$1"; task_touches_render_surface "$2"',
                 "_", str(lib), str(task_file)],
                cwd=str(_project_root()),
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=120,
            ).returncode
            return rc == 0
        except (OSError, subprocess.SubprocessError):
            pass
    return task_touches_render_surface_cheap(
        task_file.read_text(encoding="utf-8", errors="replace"), _framework_root()
    )


# ── locating the task ────────────────────────────────────────────────────────


def _find_task(task_id: str) -> tuple[Path | None, str]:
    root = _project_root()
    for sub in ("active", "completed"):
        hits = sorted((root / ".tasks" / sub).glob(f"{task_id}-*.md"))
        hits += [p for p in (root / ".tasks" / sub).glob(f"{task_id}.md")]
        if hits:
            return hits[0], sub
    return None, ""


# ── the conversion ───────────────────────────────────────────────────────────

_PREFIX_SUB_RE = re.compile(r"^(\s*-\s*\[[ xX]\]\s*)(\[(?:REVIEW|REVIEWER|RUBBER-STAMP)\]\s*)?",
                            re.IGNORECASE)


def _to_reviewer_line(raw: str) -> str:
    """Rewrite a criterion's checkbox line as an unticked `[REVIEWER]` one.

    Only the prefix changes. The criterion's own words — and every continuation
    line — are carried over untouched, because the criterion is the same
    question; what changes is who is allowed to answer it.
    """
    m = _PREFIX_SUB_RE.match(raw)
    if not m:
        return raw
    rest = raw[m.end():]
    return f"- [ ] [REVIEWER] {rest}".rstrip()


def _agent_insert_index(lines: list[str]) -> int | None:
    """Line index to insert converted criteria at: end of the `### Agent` block."""
    from lib.delegation import _SUBHEAD_RE, ac_section_bounds

    start, end = ac_section_bounds(lines)
    if start < 0:
        return None
    agent_at = None
    for i in range(start, end):
        m = _SUBHEAD_RE.match(lines[i].strip())
        if m and m.group(1).lstrip("# ").strip().lower().startswith("agent"):
            agent_at = i
            break
    if agent_at is None:
        return None
    stop = end
    for j in range(agent_at + 1, end):
        if _SUBHEAD_RE.match(lines[j].strip()):
            stop = j
            break
    while stop > agent_at + 1 and not lines[stop - 1].strip():
        stop -= 1
    return stop


def _ensure_agent_subhead(lines: list[str]) -> list[str]:
    """Create `### Agent` directly under `## Acceptance Criteria` when absent."""
    from lib.delegation import ac_section_bounds

    if _agent_insert_index(lines) is not None:
        return lines
    start, _ = ac_section_bounds(lines)
    if start < 0:
        return lines
    return lines[:start] + ["", "### Agent", ""] + lines[start:]


def verification_line(task_id: str) -> str:
    return f'bin/fw reviewer {task_id} 2>&1 | grep -q "Overall:.*PASS"'


def _append_verification(lines: list[str], task_id: str) -> tuple[list[str], bool]:
    """Append the reviewer-PASS line to `## Verification`, once.

    Idempotent on the task id, so re-running `delegate` after converting a
    second criterion does not stack duplicate lines.
    """
    want = verification_line(task_id)
    if any(want in line for line in lines):
        return lines, False
    start = None
    for i, line in enumerate(lines):
        if re.match(r"^## Verification[ \t]*$", line):
            start = i + 1
            break
    if start is None:
        return lines + ["", "## Verification", "", want, ""], True
    stop = len(lines)
    for j in range(start, len(lines)):
        if lines[j].startswith("## "):
            stop = j
            break
    at = stop
    while at > start and not lines[at - 1].strip():
        at -= 1
    return lines[:at] + [want] + lines[at:], True


def _update_entry(task_id: str, converted: list[dict], refused: list[dict]) -> list[str]:
    conv = ", ".join(f"AC#{c['index']}" for c in converted) or "none"
    by_class: dict[str, list[str]] = {}
    for r in refused:
        by_class.setdefault(r["class"], []).append(f"AC#{r['index']}")
    ref = "; ".join(f"{k}: {', '.join(v)}" for k, v in sorted(by_class.items())) or "none"
    return [
        "",
        f"### {_now()} — delegate [fw-task-delegate]",
        f"- **Ruling:** {RULING} — reviewer-closeable delegation (operator ruling 2026-09-23)",
        f"- **Converted to [REVIEWER] Agent criteria:** {conv}",
        f"- **Left under ### Human (carve-outs):** {ref}",
        f"- **Close path:** `bin/fw reviewer {task_id}` PASS auto-ticks the converted "
        f"criteria (T-1985); the normal close gates do the rest.",
    ]


def _append_updates(lines: list[str], entry: list[str]) -> list[str]:
    for i in range(len(lines) - 1, -1, -1):
        if re.match(r"^## Updates[ \t]*$", lines[i]):
            stop = len(lines)
            for j in range(i + 1, len(lines)):
                if lines[j].startswith("## "):
                    stop = j
                    break
            at = stop
            while at > i + 1 and not lines[at - 1].strip():
                at -= 1
            return lines[:at] + entry + lines[at:]
    return lines + [""] + ["## Updates"] + entry


def _set_frontmatter(lines: list[str], key: str, value: str) -> list[str]:
    out = list(lines)
    seen = 0
    for i, line in enumerate(out):
        if line.strip() == "---":
            seen += 1
            if seen == 2:
                break
            continue
        if seen == 1 and re.match(rf"^{key}:", line):
            out[i] = f"{key}: {value}"
            return out
    return out


# ── delegate ─────────────────────────────────────────────────────────────────


def cmd_delegate(args) -> int:
    task_id = args.task_id
    path, sub = _find_task(task_id)
    if path is None:
        print(f"{RED}ERROR: task {task_id} not found under .tasks/active or .tasks/completed{NC}",
              file=sys.stderr)
        return 2
    if sub == "completed":
        print(f"{RED}ERROR: {task_id} is in .tasks/completed — a settled task has nothing "
              f"to delegate{NC}", file=sys.stderr)
        return 2

    text = path.read_text(encoding="utf-8", errors="replace")
    meta = frontmatter(text)
    workflow = str(meta.get("workflow_type") or "")
    if workflow.strip().lower() == "inception":
        print(f"{RED}ERROR: {task_id} is workflow_type: inception — the go/no-go is the "
              f"operator's ({RULING} carve-out){NC}", file=sys.stderr)
        print(f"Hand it over instead: bin/fw task review {task_id}", file=sys.stderr)
        return 2

    rs = _render_surface(path)
    criteria = [c for c in human_criteria(text) if not c.ticked]

    rows: list[tuple[Criterion, object]] = [
        (c, classify(c, workflow_type=workflow, render_surface=rs)) for c in criteria
    ]
    converted = [{"index": c.index, "title": c.title[:120], "reason": cl.reason}
                 for c, cl in rows if cl.convertible]
    refused = [{"index": c.index, "title": c.title[:120], "class": cl.cls,
                "delegation_class": cl.delegation_class, "reason": cl.reason}
               for c, cl in rows if not cl.convertible]

    # AC 2: one line per Human criterion with its class. Printed before any
    # write, so --dry-run and the real run show the operator the same table.
    if not args.json:
        print(f"{BOLD}Delegation scan — {task_id}{NC} "
              f"({len(rows)} open Human criterion/criteria; ruling {RULING})")
        if rs:
            print(f"  {YELLOW}task touches a render surface (T-1766) — every criterion "
                  f"stays human{NC}")
        for c, cl in rows:
            mark = f"{GREEN}→ REVIEWER{NC}" if cl.convertible else f"{YELLOW}stays human{NC}"
            if cl.delegation_class == AGENT_SELF:
                mark = f"{CYAN}agent-self{NC}"
            print(f"  AC#{c.index:<3} {cl.cls:<18} {mark}  {c.title[:72]}")
            print(f"        {cl.reason}")
        if not rows:
            print("  (no open Human criteria)")

    remaining_human = len(refused)
    owner = str(meta.get("owner") or "")
    new_owner = owner
    if converted and remaining_human == 0:
        new_owner = "agent"

    record = {
        "ts": _now(),
        "task": task_id,
        "ruling": RULING,
        "dry_run": bool(args.dry_run),
        "render_surface": rs,
        "owner_before": owner,
        "owner_after": new_owner,
        "converted": converted,
        "refused": refused,
    }

    if args.dry_run:
        if args.json:
            print(json.dumps(record, indent=2))
        else:
            print(f"  {CYAN}--dry-run: nothing written{NC}")
            _print_outcome(converted, refused, owner, new_owner, task_id, remaining_human)
        return 0

    if not converted:
        if args.json:
            print(json.dumps(record, indent=2))
        else:
            print(f"  {YELLOW}nothing delegable — no criterion converted, no file "
                  f"written{NC}")
            _print_outcome(converted, refused, owner, new_owner, task_id, remaining_human)
        return 0

    lines = text.split("\n")
    lines = _ensure_agent_subhead(lines)
    # Re-parse against the possibly-shifted line numbers before cutting anything.
    reparsed = {(c.subhead, c.index): c for c in parse_criteria("\n".join(lines))}
    blocks: list[list[str]] = []
    cut: set[int] = set()
    for c, cl in rows:
        if not cl.convertible:
            continue
        cur = reparsed.get((c.subhead, c.index), c)
        body = list(cur.lines)
        body[0] = _to_reviewer_line(body[0])
        blocks.append(body)
        cut.update(range(cur.start, cur.end))

    insert_at = _agent_insert_index(lines)
    out: list[str] = []
    for i, line in enumerate(lines):
        if i == insert_at:
            for b in blocks:
                out.extend(b)
        if i in cut:
            continue
        out.append(line)
    if insert_at is not None and insert_at >= len(lines):
        for b in blocks:
            out.extend(b)

    out, _ = _append_verification(out, task_id)
    out = _append_updates(out, _update_entry(task_id, converted, refused))
    out = _set_frontmatter(out, "last_update", _now())
    if new_owner != owner:
        out = _set_frontmatter(out, "owner", new_owner)

    path.write_text("\n".join(out), encoding="utf-8")

    ledger = _project_root() / LEDGER
    ledger.parent.mkdir(parents=True, exist_ok=True)
    with ledger.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(record, separators=(",", ":")) + "\n")

    if args.json:
        print(json.dumps(record, indent=2))
    else:
        print(f"  {GREEN}wrote{NC} {path}")
        print(f"  {GREEN}ledger{NC} {LEDGER}")
        _print_outcome(converted, refused, owner, new_owner, task_id, remaining_human)
    return 0


def _print_outcome(converted, refused, owner, new_owner, task_id, remaining_human) -> None:
    print(f"  converted {len(converted)}, left human {len(refused)}")
    if new_owner != owner:
        print(f"  owner: {owner} → {new_owner}")
        print(f"  next: bin/fw reviewer {task_id}   (PASS auto-ticks the converted criteria)")
    elif remaining_human:
        print(f"  owner: {owner} (unchanged — {remaining_human} Human criterion/criteria "
              f"remain, so the task stays the operator's)")
        print(f"  next: bin/fw task review {task_id}")
    else:
        print(f"  owner: {owner} (unchanged)")


# ── surface ──────────────────────────────────────────────────────────────────


def cmd_surface(args) -> int:
    threshold = args.warn_threshold
    if threshold is None:
        raw = os.environ.get("FW_DELEGATION_SURFACE_WARN", "")
        try:
            threshold = int(raw)
        except ValueError:
            threshold = DEFAULT_SURFACE_WARN
    report = surface_scan(_project_root(), _framework_root())
    level, message = surface_verdict(report, threshold)
    report["threshold"] = threshold
    report["level"] = level
    report["message"] = message
    if args.json:
        print(json.dumps(report, indent=2))
        return 0
    colour = YELLOW if level == "WARN" else GREEN
    print(f"{BOLD}Delegation surface{NC} ({RULING}, threshold {threshold})")
    print(f"  {colour}{level}{NC}  {message}")
    d = report["by_delegation"]
    print(f"  {REVIEWER_CLOSEABLE:<20} {d[REVIEWER_CLOSEABLE]}")
    print(f"  {AGENT_SELF:<20} {d[AGENT_SELF]}")
    print(f"  {OPERATOR_ONLY:<20} {d[OPERATOR_ONLY]}")
    print("  by class:")
    for cls, n in sorted(report["by_class"].items(), key=lambda kv: -kv[1]):
        if n:
            print(f"    {cls:<20} {n}")
    if report["delegable_tasks"]:
        shown = report["delegable_tasks"][:10]
        more = len(report["delegable_tasks"]) - len(shown)
        print(f"  delegable now: {', '.join(shown)}" + (f" (+{more} more)" if more > 0 else ""))
        print(f"  Run: bin/fw task delegate <id> --dry-run")
    return 0


def main(argv=None) -> int:
    p = argparse.ArgumentParser(prog="fw delegation", description=__doc__)
    sub = p.add_subparsers(dest="cmd", required=True)

    d = sub.add_parser("delegate", help="delegate a task's deterministic Human criteria")
    d.add_argument("task_id")
    d.add_argument("--dry-run", action="store_true", help="classify and print; write nothing")
    d.add_argument("--json", action="store_true")
    d.set_defaults(fn=cmd_delegate)

    s = sub.add_parser("surface", help="corpus delegation surface report")
    s.add_argument("--json", action="store_true")
    s.add_argument("--warn-threshold", type=int, default=None)
    s.set_defaults(fn=cmd_surface)

    args = p.parse_args(argv)
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
