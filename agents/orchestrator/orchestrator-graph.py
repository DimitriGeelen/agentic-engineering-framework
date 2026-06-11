"""Orchestrator-graph: parallel/serial dispatch decision (T-2339, arc-011 M1 §1).

Reads `.tasks/active/T-*.md` frontmatters, builds an in-memory graph of
write-set overlap and explicit dependency edges, and emits a sequence of
`(task_id, dispatch_mode)` decisions where `mode ∈ {parallel, serial}`.

This is the policy decision-maker the arc-011 headline_mechanic depends on
— without it, parallel execution would be racy/accidental rather than
intentional. Consumes T-2337 (`lib.write_set.compare`) for the disjointness
test and T-2338 (`agents/dispatch/yield-point.sh`) as the runtime safety net.

Algorithm:
    1. Read all active tasks, extract write_set + related_tasks frontmatter
    2. Build edges:
       - Write-set overlap edge between every pair of tasks whose write_set
         compare() returns "overlap" or "undecidable" (conservative: undecided
         pairs are serialized to prevent silent collision)
       - Dependency edge from a task to each entry in its related_tasks list,
         when that entry resolves to another active task
    3. Walk the graph greedily emitting parallel-eligible rounds — within a
       round, all tasks have pairwise-disjoint write_sets AND no incoming
       dependency edges from un-emitted tasks
    4. First task in each round is "parallel" if a peer joins it; otherwise
       "serial"

The output ordering is a topological partition: round R completes before
round R+1 starts. Within a round, tasks dispatch in parallel.
"""

from __future__ import annotations

import os
import sys
from typing import Iterable

# Make lib/ importable
_HERE = os.path.dirname(os.path.abspath(__file__))
_FRAMEWORK_ROOT = os.path.dirname(os.path.dirname(_HERE))
sys.path.insert(0, os.path.join(_FRAMEWORK_ROOT, "lib"))

import write_set  # T-2337
import yaml


def _project_root() -> str:
    """Resolve PROJECT_ROOT from env or fall back to FRAMEWORK_ROOT."""
    root = os.environ.get("PROJECT_ROOT")
    if root and os.path.isdir(root):
        return root
    return _FRAMEWORK_ROOT


def _read_frontmatter(path: str) -> dict:
    """Extract YAML frontmatter from a task file. Returns {} on absent/malformed."""
    try:
        with open(path, encoding="utf-8") as f:
            text = f.read()
    except OSError:
        return {}
    if not text.startswith("---"):
        return {}
    import re
    m = re.match(r"^---\n(.*?)\n---", text, re.DOTALL)
    if not m:
        return {}
    try:
        data = yaml.safe_load(m.group(1)) or {}
    except yaml.YAMLError:
        return {}
    return data if isinstance(data, dict) else {}


def _list_active_tasks(root: str | None = None) -> list[str]:
    """Return task file paths in .tasks/active/ sorted by filename."""
    if root is None:
        root = _project_root()
    active = os.path.join(root, ".tasks", "active")
    if not os.path.isdir(active):
        return []
    return sorted(
        os.path.join(active, name)
        for name in os.listdir(active)
        if name.startswith("T-") and name.endswith(".md")
    )


def _task_id_from_path(path: str) -> str:
    """Extract task id from filename. Reads the `id:` field from frontmatter
    when available (authoritative); falls back to filename parse."""
    fm = _read_frontmatter(path)
    fid = fm.get("id")
    if isinstance(fid, str) and fid.startswith("T-"):
        return fid
    name = os.path.basename(path)
    import re
    # T- followed by alphanumeric tokens separated by hyphens, ending at the
    # first `-test` suffix or `.md` extension (so T-PAR-A in T-PAR-A-test.md
    # is the id, T-2337 in T-2337-foo-bar.md is the id).
    m = re.match(r"^(T-[A-Za-z0-9]+(?:-[A-Za-z0-9]+)*?)(?:-test)?\.md$", name)
    if m:
        return m.group(1)
    # Fallback: T- followed by anything up to the next dash
    m = re.match(r"^(T-[^-\.]+)", name)
    return m.group(1) if m else name


def build_graph(task_dir: str | None = None) -> dict:
    """Build the in-memory dispatch graph.

    Returns a dict:
        {
            "tasks": [task_id, ...],                  # ordered (filename sort)
            "paths": {task_id: filepath, ...},
            "overlap_edges": set[frozenset({a, b})],  # write-set conflicts
            "dep_edges": set[(upstream, downstream)], # related_tasks edges
        }
    """
    root = _project_root() if task_dir is None else os.path.dirname(os.path.dirname(task_dir))
    paths = _list_active_tasks(root=root)
    task_ids = [_task_id_from_path(p) for p in paths]
    path_by_id = dict(zip(task_ids, paths))

    overlap_edges: set[frozenset[str]] = set()
    dep_edges: set[tuple[str, str]] = set()

    # Pairwise write-set comparison
    for i, ta in enumerate(task_ids):
        for tb in task_ids[i + 1:]:
            try:
                verdict = write_set.compare(path_by_id[ta], path_by_id[tb], root=root)
            except FileNotFoundError:
                verdict = "undecidable"
            if verdict in ("overlap", "undecidable"):
                overlap_edges.add(frozenset({ta, tb}))

    # Dependency edges from related_tasks frontmatter
    active_set = set(task_ids)
    for ta in task_ids:
        fm = _read_frontmatter(path_by_id[ta])
        related = fm.get("related_tasks") or []
        if isinstance(related, list):
            for r in related:
                if isinstance(r, str) and r in active_set and r != ta:
                    # Edge: r → ta (treat related as upstream by convention)
                    dep_edges.add((r, ta))

    return {
        "tasks": task_ids,
        "paths": path_by_id,
        "overlap_edges": overlap_edges,
        "dep_edges": dep_edges,
    }


def next_dispatch(graph: dict) -> list[tuple[str, str]]:
    """Walk the graph; emit (task_id, mode) tuples in dispatch order.

    Mode semantics:
        "parallel" — task is part of a round with ≥2 mutually-safe peers
        "serial"   — task runs alone in its round, OR has incoming dependency
                     OR is the only safe-pick in its round

    Output ordering: rounds are emitted in topological order. Within a round,
    tasks appear in deterministic order (filename-sorted, from build_graph).
    """
    remaining = list(graph["tasks"])
    overlap = graph["overlap_edges"]
    deps = graph["dep_edges"]
    output: list[tuple[str, str]] = []

    while remaining:
        # Eligible: no incoming dep edge from a still-remaining upstream
        eligible: list[str] = []
        for t in remaining:
            blocked = any(up in remaining for (up, dn) in deps if dn == t)
            if not blocked:
                eligible.append(t)
        if not eligible:
            # Cycle or all-blocked — emit remaining as serial
            for t in remaining:
                output.append((t, "serial"))
            break

        # Build this round greedily: pairwise-disjoint write_set within the round
        round_tasks: list[str] = []
        for t in eligible:
            if all(frozenset({t, r}) not in overlap for r in round_tasks):
                round_tasks.append(t)

        mode = "parallel" if len(round_tasks) > 1 else "serial"
        for t in round_tasks:
            output.append((t, mode))
            remaining.remove(t)

    return output


def _in_flight_dispatches(jsonl_path: str) -> list[dict]:
    """Read .context/dispatches.jsonl, return rows considered in-flight.

    An entry is in-flight when its `outcome` field is missing/empty and
    a parallel entry in `.context/dispatch-outcomes.jsonl` would normally
    backfill it. For pre-flight purposes we conservatively treat any entry
    without an outcome as in-flight.
    """
    import json
    if not os.path.isfile(jsonl_path):
        return []
    in_flight: list[dict] = []
    with open(jsonl_path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(row, dict) and not row.get("outcome"):
                in_flight.append(row)
    return in_flight


def pre_flight_check(
    task_id: str,
    dispatches_jsonl_path: str | None = None,
    root: str | None = None,
) -> tuple[bool, str]:
    """Decide if a task is safe to dispatch given currently in-flight dispatches.

    Returns:
        (True, "")  — no conflict, safe to dispatch
        (False, msg) — conflict found; msg names the in-flight dispatch and path

    Conservative undecidable: a task without `write_set:` frontmatter returns
    (True, "<note>") because pre-flight cannot prove unsafety. The downstream
    §2 yield-point and §3 declaration gate cover this case.
    """
    if root is None:
        root = _project_root()
    if dispatches_jsonl_path is None:
        dispatches_jsonl_path = os.path.join(root, ".context", "dispatches.jsonl")

    try:
        target_path = write_set.resolve_task_path(task_id, root=root)
    except FileNotFoundError as e:
        # Surface upward — caller handles exit-2
        raise

    target_ws = write_set.read_write_set(target_path)
    if target_ws is None:
        return (True, f"task {task_id} has no write_set declared — pre-flight skipped (undecidable)")

    target_paths = write_set.expand_globs(target_ws, root=root)

    for entry in _in_flight_dispatches(dispatches_jsonl_path):
        peer_id = entry.get("task_id") or entry.get("task") or ""
        if not peer_id or peer_id == task_id:
            continue
        try:
            peer_path = write_set.resolve_task_path(peer_id, root=root)
        except FileNotFoundError:
            continue
        peer_ws = write_set.read_write_set(peer_path)
        if peer_ws is None:
            continue
        peer_paths = write_set.expand_globs(peer_ws, root=root)
        conflict = target_paths & peer_paths
        if conflict:
            d_id = entry.get("dispatch_id") or entry.get("id") or "D-?"
            sample = sorted(conflict)[0]
            return (False, f"write_set overlap with in-flight dispatch {d_id}: {sample}")

    return (True, "")


def _main(argv: list[str]) -> int:
    if len(argv) >= 2 and argv[1] in ("--help", "-h", "help"):
        sys.stderr.write(
            "usage: orchestrator-graph.py [next-dispatch | pre-flight <T-XXX>]\n"
            "  next-dispatch  Reads .tasks/active/T-*.md, emits (task_id, mode) per line\n"
            "  pre-flight     Decide if task is safe to dispatch vs in-flight pool\n"
            "                 Exit 0=allowed, 1=refused, 2=task-not-found, 64=usage\n"
        )
        return 0

    cmd = argv[1] if len(argv) >= 2 else "next-dispatch"

    if cmd == "pre-flight":
        if len(argv) < 3:
            sys.stderr.write("usage: orchestrator-graph.py pre-flight <T-XXX>\n")
            return 64
        task_id = argv[2]
        try:
            ok, msg = pre_flight_check(task_id)
        except FileNotFoundError as e:
            sys.stderr.write(f"error: {e}\n")
            return 2
        if ok:
            print(f"allowed{(': ' + msg) if msg else ''}")
            return 0
        sys.stderr.write(f"refused: {msg}\n")
        print("refused")
        return 1

    # Default (or explicit "next-dispatch"): emit dispatch plan
    graph = build_graph()
    for tid, mode in next_dispatch(graph):
        print(f"{tid}\t{mode}")
    return 0


if __name__ == "__main__":
    sys.exit(_main(sys.argv))
