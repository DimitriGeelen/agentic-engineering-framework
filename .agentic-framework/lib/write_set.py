"""Disjoint write-set policy validator (T-2337, arc-011 M1 §3).

Pure static validator: reads the `write_set:` frontmatter field from two task
files and reports whether their declared write sets are `disjoint`, `overlap`,
or `undecidable`. The orchestrator consults this before emitting parallel
dispatch for the arc-011 headline_mechanic (two agents on disjoint write-set
tasks running concurrently).

The `write_set:` field is a list of glob patterns (relative to PROJECT_ROOT)
declaring which paths the task expects to write. Globs expand against the
working tree; the comparison is set intersection on the expanded path strings.

Verdicts:
    disjoint    — both declared, no path overlap of any kind
    converging  — both declared and their DECLARED paths are disjoint, but both
                  tasks write shared framework state (T-3039). Fan out on reads,
                  fan in serially on writes.
    overlap     — both declared, at least one declared path in both
    undecidable — at least one task lacks `write_set:` frontmatter (can't
                  prove safety, default to refuse-to-dispatch)

T-3039 — why `converging` exists, and why `disjoint` alone was a false green:

`disjoint` only ever meant "the two DECLARED sets do not intersect". It never
meant the tasks do not write the same files, because every framework task writes
state no task declares — focus.yaml, inbox.yaml, dispatches.jsonl,
decisions.yaml, learnings.yaml, session.yaml, VERSION. Agents declare *their*
files; the framework writes these underneath them. So the first task ever to
declare a `write_set:` would have received exit 0 — a green light to parallelise
straight into the 27-site shared read-modify-write set measured in
docs/reports/T-3041-write-site-inventory.md, where T-3042 is the live loss
instance (a ledger rewriter erasing concurrently-appended rows).

That had not bitten only because adoption is zero: 0 of 3032 tasks declare the
field, so every real pair returned `undecidable`. Exit 2 is honest, and it was
the only thing standing between this tool and a confident wrong answer.

`converging` maps to exit 1, the same as `overlap`. The exit-code contract
(0/1/2) documented in CLAUDE.md is unchanged on purpose — both mean "do not
naively parallelise". The verdict string and the reported paths carry the
difference, because the two call for different responses: `overlap` means the
tasks edit the same source and should not run together at all; `converging`
means they can run together as long as the write leg is serialised.
"""

from __future__ import annotations

import glob
import os
import re
import sys
from typing import Iterable

try:
    import yaml
except ImportError:
    yaml = None


# ---------------------------------------------------------------------------
# T-3039 A1 — the implicit framework write-set.
#
# Paths every framework task writes without declaring them, because the
# FRAMEWORK writes them on the task's behalf (focus/session bookkeeping, the
# observation queue, project memory). No agent lists these in `write_set:`,
# which is exactly why a declared-set-only comparison could return `disjoint`
# for two tasks guaranteed to collide.
#
# Sourced from docs/reports/T-3041-write-site-inventory.md — NOT from memory.
# Each entry carries its inventory row and its hazard class, because "shared"
# and "unsafe" are different questions and conflating them would make this
# either alarmist or blind:
#
#   lost-update  — concurrent writers silently drop each other's data. These
#                  are what a `converging` verdict is warning about.
#   protected    — shared and read-modify-write, but serialised by a lock, so
#                  concurrency is already safe. Reported, never escalated.
#   append-safe  — single-write() appends under PIPE_BUF (~4KB); atomic on
#                  POSIX with no lock needed. Reported, never escalated.
#
# Adding a path here makes every pair of tasks converge on it, so the hazard
# class must be evidence-backed. Re-derive from the inventory rather than
# extending this list from intuition.
IMPLICIT_WRITE_SET: tuple[tuple[str, str, str], ...] = (
    (
        ".context/inbox.yaml",
        "inventory §1 row 2 — _sed_i RMW *and* append to the same file; a "
        "rewrite silently discards records another principal appended",
        "lost-update",
    ),
    (
        ".context/project/learnings.yaml",
        "inventory §1 rows 1 + 24 — two independent full-rewrite paths, plus "
        "an unlocked L-NNN id race (corpus_max_id read, then written)",
        "lost-update",
    ),
    (
        ".context/project/concerns.yaml",
        "inventory §1 row 5 — load-mutate-dump vs a concurrent append-only "
        "auto-register leg (lib/hook-threshold.py:174)",
        "lost-update",
    ),
    (
        ".context/project/received-learnings.yaml",
        "inventory §1 row 16 — truncate-rewrite with no temp file, from cron",
        "lost-update",
    ),
    (
        ".context/working/focus.yaml",
        "inventory §2 — four writers (focus.sh set/fallback/clear, init.sh "
        "truncate); last writer wins, and it is per-session state",
        "lost-update",
    ),
    (
        ".context/working/session.yaml",
        "inventory §2 — cat> truncate in init.sh/resume.sh vs _sed_i in "
        "focus.sh",
        "lost-update",
    ),
    (
        ".context/working/arc-focus.yaml",
        "inventory §2 — cat> / write_text from lib/arc.sh and the Watchtower "
        "arcs blueprint",
        "lost-update",
    ),
    (
        ".context/dispatches.jsonl",
        "inventory §1 row 4 — was the worst case (update_outcome_row erasing "
        "concurrently-appended rows); serialised by flock in T-3042",
        "protected",
    ),
    (
        ".context/triage-dispositions.jsonl",
        "T-3046 — one disposition row per archived message; appended by "
        "`fw triage route` under keylock.guarding(), same mechanism as "
        "dispatches.jsonl above",
        "protected",
    ),
    (
        ".context/project/decisions.yaml",
        "inventory §3 — single echo >> per entry; atomic while entries stay "
        "under PIPE_BUF",
        "append-safe",
    ),
    (
        ".context/project/metrics-history.yaml",
        "inventory §4 — audit.sh is the only writer and holds "
        ".context/locks/audit.lock for the whole run",
        "protected",
    ),
)

#: Hazard classes that make a shared path worth serialising. Paths outside this
#: set are reported for transparency but never change the verdict.
ESCALATING_HAZARDS = frozenset({"lost-update"})


def implicit_paths(hazards: frozenset[str] | None = None) -> list[str]:
    """Return the implicit framework write-set, optionally filtered by hazard.

    `hazards=None` returns every path; pass ESCALATING_HAZARDS for just the
    ones that can silently lose data.
    """
    return [
        path
        for path, _why, hazard in IMPLICIT_WRITE_SET
        if hazards is None or hazard in hazards
    ]


def _project_root() -> str:
    """Resolve PROJECT_ROOT from env or fall back to git toplevel of CWD."""
    root = os.environ.get("PROJECT_ROOT")
    if root and os.path.isdir(root):
        return root
    # Walk up from CWD looking for .tasks/ — the canonical project marker
    cur = os.path.abspath(os.getcwd())
    while cur != "/":
        if os.path.isdir(os.path.join(cur, ".tasks")):
            return cur
        cur = os.path.dirname(cur)
    return os.getcwd()


def _parse_frontmatter(task_path: str) -> dict:
    """Extract YAML frontmatter from a task file. Returns {} if absent/malformed."""
    if not os.path.isfile(task_path):
        raise FileNotFoundError(task_path)
    with open(task_path, encoding="utf-8") as f:
        text = f.read()
    if not text.startswith("---"):
        return {}
    m = re.match(r"^---\n(.*?)\n---", text, re.DOTALL)
    if not m:
        return {}
    if yaml is None:
        return {}
    try:
        data = yaml.safe_load(m.group(1)) or {}
    except yaml.YAMLError:
        return {}
    return data if isinstance(data, dict) else {}


def read_write_set(task_path: str) -> list[str] | None:
    """Return the raw `write_set:` list from a task file, or None if absent.

    Returns:
        list of glob patterns (str)  — when `write_set:` frontmatter is present
        None                         — when the field is missing or empty
    """
    fm = _parse_frontmatter(task_path)
    ws = fm.get("write_set")
    if ws is None:
        return None
    if isinstance(ws, list) and all(isinstance(p, str) for p in ws):
        # An empty list is still "declared" — the task explicitly writes nothing.
        # Differentiate from missing-field by returning the empty list.
        return ws
    return None


def expand_globs(patterns: Iterable[str], root: str | None = None) -> set[str]:
    """Expand glob patterns against the working tree, return absolute path set.

    Patterns are interpreted relative to `root` (defaults to PROJECT_ROOT).
    Recursive globs (`**`) supported via glob.glob(recursive=True).
    Patterns that don't expand to any existing file are kept as-is (the
    intent is set-membership comparison, not file-existence verification).
    """
    if root is None:
        root = _project_root()
    out: set[str] = set()
    for pat in patterns:
        pat = pat.strip()
        if not pat:
            continue
        # Absolute paths stay absolute; relative are resolved against root
        if not os.path.isabs(pat):
            full = os.path.join(root, pat)
        else:
            full = pat
        # include_hidden=True (Python 3.11+) is REQUIRED — dot-directories
        # like .tasks/, .context/, .fabric/ are first-class in this codebase.
        # Without it, `**/T-*.md` skips .tasks/active/ entirely.
        try:
            matches = glob.glob(full, recursive=True, include_hidden=True)
        except TypeError:
            # Python < 3.11 fallback: walk the tree manually with fnmatch
            import fnmatch
            matches = []
            base_dir = os.path.dirname(full) if "*" in full else full
            # Strip glob characters to find the walk root
            star_idx = full.find("*")
            walk_root = full[:star_idx].rsplit(os.sep, 1)[0] if star_idx > 0 else root
            if os.path.isdir(walk_root):
                for dirpath, _dirnames, filenames in os.walk(walk_root):
                    for fn in filenames:
                        candidate = os.path.join(dirpath, fn)
                        if fnmatch.fnmatch(candidate, full):
                            matches.append(candidate)
        if matches:
            for m in matches:
                out.add(os.path.normpath(m))
        else:
            # Pattern doesn't match anything yet — keep the normalized form
            # so two tasks declaring the same unborn path overlap correctly.
            out.add(os.path.normpath(full))
    return out


def is_disjoint(set_a: set[str], set_b: set[str]) -> bool:
    """Return True iff the two expanded path sets share no element."""
    return set_a.isdisjoint(set_b)


def compare_detail(
    task_a_path: str,
    task_b_path: str,
    root: str | None = None,
    include_implicit: bool = True,
) -> dict:
    """Compare two tasks' write-sets, returning the verdict and its reasons.

    The dict carries `verdict`, plus `declared_overlap` (paths both tasks
    explicitly declared) and `converging` (implicit framework paths that force
    a serial write leg). Callers that only need the word use `compare()`.

    `include_implicit=False` restores the pre-T-3039 declared-only comparison.
    It exists for tests and for callers that have already serialised framework
    state themselves — not as a general escape hatch, because the whole point
    of T-3039 is that the declared-only answer reads safer than it is.
    """
    ws_a = read_write_set(task_a_path)
    ws_b = read_write_set(task_b_path)

    # Implicit convergence is knowable WITHOUT any declaration — it follows
    # from both operands being framework tasks. So compute it even on the
    # undecidable path: today `undecidable` tells an agent nothing at all, and
    # "I cannot compare your declared paths, but these will converge
    # regardless" is strictly more than nothing.
    converging = (
        implicit_paths(ESCALATING_HAZARDS) if include_implicit else []
    )

    if ws_a is None or ws_b is None:
        return {
            "verdict": "undecidable",
            "declared_overlap": [],
            "converging": converging,
            "undeclared": [
                t
                for t, ws in ((task_a_path, ws_a), (task_b_path, ws_b))
                if ws is None
            ],
        }

    paths_a = expand_globs(ws_a, root=root)
    paths_b = expand_globs(ws_b, root=root)
    declared_overlap = sorted(paths_a & paths_b)

    if declared_overlap:
        # A declared collision is the stronger finding: these tasks edit the
        # same files and should not run together at all. Convergence on
        # framework state is true as well but does not change the answer.
        verdict = "overlap"
    elif converging:
        verdict = "converging"
    else:
        verdict = "disjoint"

    return {
        "verdict": verdict,
        "declared_overlap": declared_overlap,
        "converging": converging,
        "undeclared": [],
    }


def compare(
    task_a_path: str,
    task_b_path: str,
    root: str | None = None,
    include_implicit: bool = True,
) -> str:
    """Compare two tasks' write-sets and return the verdict word.

    Returns:
        "disjoint"    — both declared, no overlap of any kind
        "converging"  — both declared, declared paths disjoint, but shared
                        framework state forces a serial write leg (T-3039)
        "overlap"     — both declared, at least one declared path shared
        "undecidable" — at least one task lacks `write_set:` frontmatter
    """
    return compare_detail(
        task_a_path, task_b_path, root=root, include_implicit=include_implicit
    )["verdict"]


def resolve_task_path(task_id: str, root: str | None = None) -> str:
    """Resolve a T-XXX id to its file under .tasks/{active,completed}/.

    Accepts either the bare id (T-2337) or the full path. Raises
    FileNotFoundError when neither active/ nor completed/ contain a match.
    """
    if os.path.isfile(task_id):
        return os.path.abspath(task_id)
    if root is None:
        root = _project_root()
    # Match T-NNNN-*.md (or .yaml) in either active/ or completed/
    for sub in ("active", "completed"):
        d = os.path.join(root, ".tasks", sub)
        if not os.path.isdir(d):
            continue
        for name in os.listdir(d):
            if name.startswith(f"{task_id}-") or name == f"{task_id}.md":
                return os.path.join(d, name)
    raise FileNotFoundError(f"task {task_id} not found under .tasks/")


def check(task_a: str, task_b: str, root: str | None = None) -> tuple[str, int]:
    """Resolve two task ids/paths and compare. Returns (verdict, exit_code).

    Exit codes:
        0 = disjoint
        1 = overlap OR converging
        2 = undecidable

    `converging` deliberately shares exit 1 with `overlap`: the documented
    contract in CLAUDE.md is 0/1/2, and both verdicts mean the same thing to a
    caller branching on the code — do not naively parallelise. Introducing a
    fourth code would silently break every existing `if rc -eq 1` consumer and
    make the shell contract disagree with its own documentation. The verdict
    string carries the distinction for callers that can act on it.
    """
    path_a = resolve_task_path(task_a, root=root)
    path_b = resolve_task_path(task_b, root=root)
    verdict = compare(path_a, path_b, root=root)
    code = {
        "disjoint": 0,
        "overlap": 1,
        "converging": 1,
        "undecidable": 2,
    }[verdict]
    return verdict, code


VERDICT_CODES = {"disjoint": 0, "overlap": 1, "converging": 1, "undecidable": 2}


def _main(argv: list[str]) -> int:
    args = [a for a in argv[1:] if not a.startswith("--")]
    flags = {a for a in argv[1:] if a.startswith("--")}
    if len(args) < 3 or args[0] != "check":
        sys.stderr.write(
            "usage: write_set.py check <T-A> <T-B> [--json] [--declared-only]\n"
        )
        return 64
    try:
        path_a = resolve_task_path(args[1])
        path_b = resolve_task_path(args[2])
    except FileNotFoundError as e:
        sys.stderr.write(f"error: {e}\n")
        return 2

    detail = compare_detail(
        path_a, path_b, include_implicit="--declared-only" not in flags
    )
    verdict = detail["verdict"]
    code = VERDICT_CODES[verdict]

    if "--json" in flags:
        import json

        print(json.dumps(detail, indent=2, sort_keys=True))
        return code

    print(verdict)
    # Name what to do about it. A bare verdict word sends the reader back to
    # the source to find out which paths are implicated — the same
    # asserts-less-than-it-looks failure this task exists to remove.
    if detail["declared_overlap"]:
        sys.stderr.write(
            "declared paths written by both tasks — do not run concurrently:\n"
        )
        for p in detail["declared_overlap"]:
            sys.stderr.write(f"  {p}\n")
    if detail["converging"]:
        sys.stderr.write(
            "shared framework state — fan out on reads, fan in serially on "
            "writes (CLAUDE.md §Execution Model):\n"
        )
        for p in detail["converging"]:
            sys.stderr.write(f"  {p}\n")
    if detail["undeclared"]:
        sys.stderr.write(
            "no write_set: declared, so declared-path overlap is unknown:\n"
        )
        for p in detail["undeclared"]:
            sys.stderr.write(f"  {os.path.basename(p)}\n")
    return code


if __name__ == "__main__":
    sys.exit(_main(sys.argv))
