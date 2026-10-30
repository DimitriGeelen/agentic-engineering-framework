#!/usr/bin/env python3
"""CLI for reviewer-closeable delegation (T-3445, mechanism for D-626).

Two verbs, one module because they share the classifier:

    fw task delegate T-XXX [--dry-run] [--json]
    fw reviewer surface [--json] [--warn-threshold N]

`delegate` is the act D-626 authorises: it classifies a human-owned task's open
Human criteria and reports who closes each one. Until T-4916 it converted the
deterministic ones to `[REVIEWER]` Agent criteria for the static-scan auto-tick;
T-4778 narrowed that tick, which left them no close path, so now every delegable
class stays under `### Human` and closes on a recorded verdict (`fw reviewer
judge`). `delegate --reroute-converted` moves back what an earlier run converted.

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
    REVIEWER_JUDGES,
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


def _fw() -> str:
    """Project-relative fw path: `bin/fw` in the framework repo, else the
    vendored `.agentic-framework/bin/fw` (T-4250; same split as T-1257)."""
    root = _project_root()
    if (root / "bin" / "fw").exists() or not (root / ".agentic-framework" / "bin" / "fw").exists():
        return "bin/fw"
    return ".agentic-framework/bin/fw"


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
    """The close-gate line that makes a PASS verdict the thing that closes the task.

    NOT the form the task spec and CLAUDE.md's `[REVIEWER]` conversion rule both
    prescribe (`bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"`). That
    form is self-defeating HERE, measured on the T-9001 fixture 2026-09-24: the
    reviewer's own `l387-sigpipe-risk` detector flags a streaming command piped
    into a terminal `grep -q`, so writing it into `## Verification` makes the
    reviewer emit a finding against the very line that reads its verdict —
    `Overall: CONCERN`, the grep misses, and the delegated task can never close.
    Every delegated task would have inherited that, which is the difference
    between a mechanism and a trap.

    This is the redirect shape `detect_l387_sigpipe_risk`'s own docstring names
    as the safe rewrite, and CLAUDE.md's `## Verification` guidance calls THE
    DEFAULT. `&&` rather than `;` keeps the reviewer's exit code in the verdict
    (T-3203): a sequence is judged only on its last command.
    """
    out = f"/tmp/.fw-reviewer-{task_id}.out"
    return (
        f'{_fw()} reviewer {task_id} > {out} 2>&1 && '
        f'grep -q "Overall:.*PASS" {out}'
    )


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
        f"- **Left under ### Human:** {ref} (reviewer-judgeable ones are reported, "
        f"not converted — T-3557; nothing closes without an independent verdict)",
        f"- **Close path:** `{_fw()} reviewer judge {task_id}`; a recorded green verdict "
        f"ticks each criterion at close (T-3579, T-4916).",
    ]


def _update_entry_ready(task_id: str) -> list[str]:
    return [
        "",
        f"### {_now()} — delegate ready-to-close [fw-task-delegate]",
        "- **Ruling:** D-626 / T-3557 / T-4156 — no Human criteria, Agent criteria done: "
        "one reviewer-judged close-readiness criterion added; owner unchanged.",
        f"- **Close path:** `{_fw()} reviewer judge {task_id}`; a green verdict ticks it, "
        "red/amber returns findings to remediate.",
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
    if getattr(args, "reroute_converted", False):
        return cmd_reroute(args, path, text, task_id)
    meta = frontmatter(text)
    workflow = str(meta.get("workflow_type") or "")
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
            print(f"  {YELLOW}task touches a render surface (T-1766) — criteria are "
                  f"reviewer-judged, not converted{NC}")
        for c, cl in rows:
            mark = f"{GREEN}→ REVIEWER{NC}" if cl.convertible else f"{YELLOW}stays human{NC}"
            if cl.delegation_class == AGENT_SELF:
                mark = f"{CYAN}agent-self{NC}"
            elif cl.delegation_class == REVIEWER_JUDGES:
                mark = f"{CYAN}reviewer-judged (fw reviewer judge){NC}"
            print(f"  AC#{c.index:<3} {cl.cls:<18} {mark}  {c.title[:72]}")
            print(f"        {cl.reason}")
        if not rows:
            print("  (no open Human criteria)")

    if not rows:
        from lib import unclosable_misfiled as um
        if um.is_unclosable_misfiled(meta, text):
            return _delegate_ready_to_close(task_id, path, text, meta, args, um.carve_out(meta, text))

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
        "reviewer_judgeable": [r["index"] for r in refused
                               if r["delegation_class"] == REVIEWER_JUDGES],
    }
    record["reviewer_judged_count"] = len(record["reviewer_judgeable"])

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
            print(f"  {CYAN}nothing to convert — since T-4916 delegable criteria stay under "
                  f"### Human and close on an independent verdict; no file written{NC}")
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


def _close_readiness_block(task_id: str) -> list[str]:
    # Wording avoids every carve-out/taste vocabulary so classify() lands on
    # REVIEWER-JUDGES; test_t4156 pins that.
    return [
        "- [ ] [REVIEW] Close-readiness: the work meets its Agent criteria and the "
        f"Verification section passes ({task_id}, reviewer-judged, T-4156)",
        "  **Steps:**",
        f"  1. Run `cd {_project_root()} && {_fw()} reviewer judge {task_id}`",
        "  **Expected:** an independent reviewer records a green verdict for this "
        "criterion's current text",
        "  **If not:** remediate the findings the reviewer lists, then re-run the judge",
    ]


def _delegate_ready_to_close(task_id, path, text, meta, args, carve) -> int:
    """T-4156: owner:human, zero Human criteria, Agent criteria all ticked.

    There is nothing to convert, so give the reviewer ladder something to judge:
    one close-readiness criterion. Ownership is NOT touched here; the verdict
    ledger decides that at close. Carve-outs stay with the operator.
    """
    owner = str(meta.get("owner") or "")
    record = {"ts": _now(), "task": task_id, "ruling": RULING, "dry_run": bool(args.dry_run),
              "class": "ready-to-close", "owner_before": owner, "owner_after": owner,
              "carve_out": carve, "converted": [], "refused": []}
    if carve:
        if args.json:
            print(json.dumps(record, indent=2))
        else:
            print(f"{BOLD}Delegation scan — {task_id}{NC}: ready-to-close, but "
                  f"{YELLOW}stays with the operator{NC}\n  {carve}")
            print(f"  next: {_fw()} task review {task_id}")
        return 0
    if args.dry_run:
        if args.json:
            print(json.dumps(record, indent=2))
        else:
            print(f"{BOLD}Delegation scan — {task_id}{NC}: ready-to-close "
                  f"(no Human criteria, Agent criteria done)")
            print(f"  would add one reviewer-judged close-readiness criterion; owner unchanged")
            print(f"  {CYAN}--dry-run: nothing written{NC}")
        return 0

    lines = text.split("\n")
    block = _close_readiness_block(task_id)
    head = next((i for i, ln in enumerate(lines) if re.match(r"^### Human\b", ln)), None)
    if head is not None:
        at = head + 1
        j = at
        while j < len(lines) and not lines[j].strip():
            j += 1
        if j < len(lines) and lines[j].lstrip().startswith("<!--"):
            while j < len(lines) and "-->" not in lines[j]:
                j += 1
            at = j + 1
        lines[at:at] = block
    else:
        from lib.delegation import ac_section_bounds
        _, end = ac_section_bounds(lines)
        if end < 0:
            print(f"{RED}ERROR: {task_id} has no ## Acceptance Criteria{NC}", file=sys.stderr)
            return 2
        lines[end:end] = ["### Human"] + block + [""]
    out = _append_updates(lines, _update_entry_ready(task_id))
    out = _set_frontmatter(out, "last_update", _now())
    path.write_text("\n".join(out), encoding="utf-8")
    ledger = _project_root() / LEDGER
    ledger.parent.mkdir(parents=True, exist_ok=True)
    with ledger.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(record, separators=(",", ":")) + "\n")
    if args.json:
        print(json.dumps(record, indent=2))
    else:
        print(f"  {GREEN}wrote{NC} {path}\n  {GREEN}ledger{NC} {LEDGER}")
        print(f"  owner: {owner} (unchanged; the verdict ledger decides at close)")
        print(f"  next: {_fw()} reviewer judge {task_id}")
    return 0


def _print_outcome(converted, refused, owner, new_owner, task_id, remaining_human) -> None:
    judged = sum(1 for r in refused if r["delegation_class"] == REVIEWER_JUDGES)
    print(f"  converted {len(converted)}, reviewer-judged {judged}, "
          f"left human {len(refused) - judged}")
    if new_owner != owner:
        print(f"  owner: {owner} → {new_owner}")
        print(f"  next: {_fw()} reviewer judge {task_id}")
    elif judged:
        # T-4916: the close path for every reviewer-judged criterion. A recorded green
        # verdict ticks it at close and hands ownership over when nothing else is open.
        print(f"  owner: {owner} (unchanged; the verdict ledger decides at close)")
        print(f"  next: {_fw()} reviewer judge {task_id} --dry-run   (then without --dry-run)")
    elif remaining_human:
        print(f"  owner: {owner} (unchanged — {remaining_human} Human criterion/criteria "
              f"remain, so the task stays the operator's)")
        print(f"  next: {_fw()} task review {task_id}")
    else:
        print(f"  owner: {owner} (unchanged)")


# ── reroute (T-4916) ─────────────────────────────────────────────────────────


def _bare_title(title: str) -> str:
    """A criterion title without its `[REVIEW]`/`[REVIEWER]`/`[RUBBER-STAMP]` prefix."""
    return _PREFIX_SUB_RE.sub("", "- [ ] " + title.strip(), count=1).strip()


def _converted_records(task_id: str) -> list[dict]:
    """This task's real (not dry-run) delegations that converted something, oldest first."""
    out = []
    try:
        with (_project_root() / LEDGER).open(encoding="utf-8") as fh:
            for line in fh:
                try:
                    rec = json.loads(line)
                except ValueError:
                    continue
                if (isinstance(rec, dict) and rec.get("task") == task_id
                        and not rec.get("dry_run") and rec.get("converted")):
                    out.append(rec)
    except OSError:
        pass
    return out


def _human_insert_index(lines: list[str]) -> tuple[list[str], int]:
    """(lines, index) to append criteria at the end of the `### Human` block, creating
    the subhead at the end of `## Acceptance Criteria` when there is none. Subheads
    inside HTML comments (the template's worked examples) do not count."""
    from lib.delegation import _SUBHEAD_RE, _comment_mask, ac_section_bounds

    start, end = ac_section_bounds(lines)
    if start < 0:
        return lines, -1
    mask = _comment_mask(lines)
    human_at = None
    for i in range(start, end):
        m = _SUBHEAD_RE.match(lines[i].strip())
        if m and not mask[i] and m.group(1).lstrip("# ").strip().lower().startswith("human"):
            human_at = i
            break
    if human_at is None:
        at = end
        while at > start and not lines[at - 1].strip():
            at -= 1
        lines = lines[:at] + ["", "### Human"] + lines[at:]
        return lines, at + 2
    stop = end
    for j in range(human_at + 1, end):
        if _SUBHEAD_RE.match(lines[j].strip()) and not mask[j]:
            stop = j
            break
    while stop > human_at + 1 and not lines[stop - 1].strip():
        stop -= 1
    return lines, stop


def cmd_reroute(args, path: Path, text: str, task_id: str) -> int:
    """Move criteria an earlier `delegate` converted back under `### Human` (T-4916).

    Matched against this task's own records in delegations.jsonl, never by guess: an
    authored `[REVIEWER]` Agent criterion (T-1878) is not delegation's to move. The
    criterion's text is carried over unchanged, so its verdict digest is too. The
    owner the conversion changed is restored, so the verdict ledger hands it over
    again at close when nothing else is open.
    """
    records = _converted_records(task_id)
    wanted = [_bare_title(c.get("title", "")) for r in records for c in r["converted"]]
    wanted = [w for w in wanted if w]
    agent = [c for c in parse_criteria(text)
             if c.subhead.lower().startswith("agent") and not c.ticked and c.prefix == "REVIEWER"]
    moves: list[Criterion] = []
    for c in agent:
        bare = _bare_title(c.title)
        for k, w in enumerate(wanted):
            if bare.startswith(w):
                moves.append(c)
                del wanted[k]
                break
    meta = frontmatter(text)
    owner = str(meta.get("owner") or "")
    restore = ""
    for r in reversed(records):
        if r.get("owner_after") != r.get("owner_before"):
            if owner == r.get("owner_after"):
                restore = str(r.get("owner_before") or "")
            break

    if not args.json:
        print(f"{BOLD}Reroute — {task_id}{NC} ({len(records)} converting delegation(s) on record)")
        for c in moves:
            print(f"  Agent AC#{c.index:<3} → ### Human   {c.title.strip()[:72]}")
        if not moves:
            print("  nothing to reroute (no unticked criterion an earlier delegation converted)")
        if restore:
            print(f"  owner: {owner} → {restore} (as before the conversion)")
    record = {"ts": _now(), "task": task_id, "ruling": RULING, "dry_run": bool(args.dry_run),
              "class": "reroute", "rerouted": [{"index": c.index, "title": c.title[:120]}
                                               for c in moves],
              "owner_before": owner, "owner_after": restore or owner,
              "converted": [], "refused": []}
    if args.dry_run or not moves:
        if args.json:
            print(json.dumps(record, indent=2))
        elif args.dry_run and moves:
            print(f"  {CYAN}--dry-run: nothing written{NC}")
        return 0

    lines = text.split("\n")
    cut: set[int] = set()
    blocks: list[list[str]] = []
    for c in moves:
        blocks.append(list(c.lines))
        cut.update(range(c.start, c.end))
    kept = [ln for i, ln in enumerate(lines) if i not in cut]
    kept, at = _human_insert_index(kept)
    moved = [ln for b in blocks for ln in b]
    out = kept[:at] + moved + kept[at:]
    left = [c for c in parse_criteria("\n".join(out))
            if c.subhead.lower().startswith("agent") and not c.ticked and c.prefix == "REVIEWER"]
    if not wanted and not left:
        want = verification_line(task_id)   # the conversion's reviewer-PASS line; its job is gone
        out = [ln for ln in out if ln.strip() != want]
    out = _append_updates(out, [
        "",
        f"### {_now()} — delegate reroute [fw-task-delegate]",
        f"- **Ruling:** {RULING} / T-4916 (operator 2026-10-30, b) — converted criteria go back "
        f"under ### Human and close on an independent verdict",
        f"- **Moved:** {', '.join('Agent AC#%d' % c.index for c in moves)}",
        f"- **Close path:** `{_fw()} reviewer judge {task_id}`",
    ])
    out = _set_frontmatter(out, "last_update", _now())
    if restore:
        out = _set_frontmatter(out, "owner", restore)
    path.write_text("\n".join(out), encoding="utf-8")
    ledger = _project_root() / LEDGER
    ledger.parent.mkdir(parents=True, exist_ok=True)
    with ledger.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(record, separators=(",", ":")) + "\n")
    if args.json:
        print(json.dumps(record, indent=2))
    else:
        print(f"  {GREEN}wrote{NC} {path}\n  {GREEN}ledger{NC} {LEDGER}")
        print(f"  next: {_fw()} reviewer judge {task_id} --dry-run")
    return 0


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
    if args.facts:
        # One TSV line for the audit + doctor rails, so both read the same
        # numbers from the same scan rather than each re-deriving them —
        # the shape lib/fabric_doctor_facts.py uses for the same reason.
        d = report["by_delegation"]
        print("\t".join(str(x) for x in (
            level,
            d[REVIEWER_CLOSEABLE], d[REVIEWER_JUDGES], d[AGENT_SELF], d[OPERATOR_ONLY],
            report["tasks_with_open_human_criteria"], threshold,
            ",".join(report["delegable_tasks"][:5]),
        )))
        return 0
    colour = YELLOW if level == "WARN" else GREEN
    print(f"{BOLD}Delegation surface{NC} ({RULING}, threshold {threshold})")
    print(f"  {colour}{level}{NC}  {message}")
    d = report["by_delegation"]
    print(f"  {REVIEWER_CLOSEABLE:<20} {d[REVIEWER_CLOSEABLE]}")
    print(f"  {REVIEWER_JUDGES:<20} {d[REVIEWER_JUDGES]}")
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
        print(f"  Run: {_fw()} reviewer judge <id> --dry-run")
    return 0


def cmd_classify(args) -> int:
    """T-3963: classify criteria given as TEXT, with no task file.

    Consumers (832) re-implemented the predicate to route checks before a task
    existed. This is the same `classify()` the delegate verb and the close gate
    use, so there is one ruleset, not a copy per project. Bare criteria (no
    `## Acceptance Criteria` heading) are read as Human criteria — the question
    is always "who closes this one?".
    """
    from lib.delegation import classify as _classify, parse_criteria as _parse

    if args.text is not None:
        text = args.text
    elif args.file and args.file != "-":
        try:
            with open(args.file, encoding="utf-8") as fh:
                text = fh.read()
        except OSError as e:
            print(f"{RED}ERROR: cannot read {args.file}: {e}{NC}", file=sys.stderr)
            return 2
    else:
        text = sys.stdin.read()
    if not re.search(r"^##\s+Acceptance Criteria", text, re.M):
        text = "## Acceptance Criteria\n\n### Human\n" + text.strip("\n") + "\n"
    crits = _parse(text)
    if not crits:
        print(f"{RED}ERROR: no '- [ ]' criterion found in the input{NC}", file=sys.stderr)
        return 2
    rows = []
    for c in crits:
        k = _classify(c, workflow_type=args.workflow_type, render_surface=args.render_surface)
        rows.append({"index": c.index, "subhead": c.subhead, "title": c.title.strip(),
                     "class": k.cls, "delegation_class": k.delegation_class,
                     "reason": k.reason})
    if args.json:
        print(json.dumps(rows, indent=2))
        return 0
    for r in rows:
        print(f"{r['subhead'] or '-'} #{r['index']}: {r['delegation_class']} ({r['class']}) — {r['reason']}")
        print(f"    {r['title'][:100]}")
    return 0


def main(argv=None) -> int:
    p = argparse.ArgumentParser(prog="fw delegation", description=__doc__)
    sub = p.add_subparsers(dest="cmd", required=True)

    c = sub.add_parser("classify", help="classify criteria given as text (no task file)")
    src = c.add_mutually_exclusive_group()
    src.add_argument("--text", help="criterion markdown; bare '- [ ] ...' lines are read as Human")
    src.add_argument("--file", help="file with criteria ('-' = stdin, also the default)")
    c.add_argument("--workflow-type", default="", help="e.g. build, inception")
    c.add_argument("--render-surface", action="store_true",
                   help="the task touches a rendering surface (web/templates, static, blueprints)")
    c.add_argument("--json", action="store_true")
    c.set_defaults(fn=cmd_classify)

    d = sub.add_parser("delegate", help="delegate a task's deterministic Human criteria")
    d.add_argument("task_id")
    d.add_argument("--dry-run", action="store_true", help="classify and print; write nothing")
    d.add_argument("--reroute-converted", action="store_true",
                   help="T-4916: move criteria an earlier delegation converted back under ### Human")
    d.add_argument("--json", action="store_true")
    d.set_defaults(fn=cmd_delegate)

    s = sub.add_parser("surface", help="corpus delegation surface report")
    s.add_argument("--json", action="store_true")
    s.add_argument("--warn-threshold", type=int, default=None)
    s.add_argument("--facts", action="store_true",
                   help="one TSV line for the audit and doctor rails")
    s.set_defaults(fn=cmd_surface)

    args = p.parse_args(argv)
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
