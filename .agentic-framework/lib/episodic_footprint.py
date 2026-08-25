#!/usr/bin/env python3
"""Re-mine an episodic's git footprint AFTER the completion commit exists (T-3130).

The problem this exists for
---------------------------
`fw task update T-XXX --status work-completed` generates the episodic, and it
does so BEFORE the commit that carries the task's work. That ordering is not an
accident and must not be changed: the completion gate runs ahead of the commit
precisely so it can block. But it means `episodic.sh`'s `git log --grep=T-XXX`
runs against a history that does not yet contain the commit being described.

For a task whose entire history lands in ONE commit at completion — the common
shape for small tasks — the mined footprint is therefore `commits: 0`, with
`git_mining: ok` beside it. That is worse than a missing value: it is a
*measured* zero, truthful at the instant it was taken and wrong one second
later. Nothing re-asks.

This module is the re-ask. It runs from the post-commit hook, when the commit
exists, and rewrites the four mined counters in place.

What it deliberately does NOT do
--------------------------------
It refuses to touch an episodic whose `git_mining:` is `skipped`. That state is
T-3129's: git could not be reached at generation time, so the counters are
`null` — an absent measurement, not a zero. Post-commit always runs inside a
git repo, so this module *could* fill those in — and that is exactly why it
must not. Silently flipping `skipped` -> `ok` from a different code path would
erase the evidence that generation-time mining failed, which is the signal
T-3129 built. Those are repaired by backfill, under their own task, where the
population is counted.

So: `ok` episodics get refreshed (a measurement taken too early is corrected),
`skipped` ones are left alone (an absent measurement stays absent).

Provenance
----------
A refresh writes `footprint_refreshed_at:` and `footprint_refreshed_by_commit:`
into the metrics block. Those four counters are now written by a different
agent than the rest of the file, and the artefact says so rather than leaving
it to a Decisions entry nobody reads next to the data.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

COUNTER_FIELDS = ("commits", "files_changed", "lines_added", "lines_removed")


def _git(project_root: Path, *args: str) -> str:
    """Run git and return stdout, or '' on any failure."""
    try:
        out = subprocess.run(
            ["git", "-C", str(project_root), *args],
            capture_output=True,
            text=True,
            check=False,
        )
    except OSError:
        return ""
    return out.stdout if out.returncode == 0 else ""


def mine(project_root: Path, task_id: str) -> dict[str, int]:
    """Recompute the four counters exactly as episodic.sh does.

    Same `--all --grep="<id>:"` shape as agents/context/lib/episodic.sh so the
    refreshed value is comparable to the generated one rather than a second,
    subtly different measurement.
    """
    oneline = _git(project_root, "log", "--all", "--oneline", f"--grep={task_id}:")
    commits = len([ln for ln in oneline.splitlines() if ln.strip()])

    numstat = _git(
        project_root, "log", "--all", f"--grep={task_id}:", "--numstat", "--format="
    )
    files: set[str] = set()
    added = removed = 0
    for line in numstat.splitlines():
        parts = line.split("\t")
        if len(parts) != 3:
            continue
        a, r, path = parts
        files.add(path)
        # Binary files render as '-'; they have no line counts to add.
        if a.isdigit():
            added += int(a)
        if r.isdigit():
            removed += int(r)

    return {
        "commits": commits,
        "files_changed": len(files),
        "lines_added": added,
        "lines_removed": removed,
    }


def read_metrics(text: str) -> dict[str, str]:
    """Read the metrics block's scalar fields as raw strings."""
    out: dict[str, str] = {}
    in_block = False
    for line in text.splitlines():
        if re.match(r"^metrics:\s*$", line):
            in_block = True
            continue
        if in_block:
            # The block ends at the next top-level key or a non-indented line.
            if line and not line.startswith((" ", "\t", "#")):
                break
            m = re.match(r"^\s+([A-Za-z_][A-Za-z0-9_]*):\s*(.*?)\s*$", line)
            if m:
                out[m.group(1)] = m.group(2)
    return out


def refresh(
    episodic: Path, project_root: Path, task_id: str, commit: str = ""
) -> tuple[str, dict]:
    """Rewrite the four counters in place. Returns (outcome, detail)."""
    if not episodic.is_file():
        return "no-episodic", {}

    text = episodic.read_text()
    metrics = read_metrics(text)

    if not metrics:
        return "no-metrics-block", {}

    status = metrics.get("git_mining", "")
    if status != "ok":
        # See module docstring: `skipped` belongs to T-3129 and is repaired by
        # backfill, not from here.
        return "skipped-not-refreshable", {"git_mining": status or "(absent)"}

    fresh = mine(project_root, task_id)
    old = {k: metrics.get(k, "") for k in COUNTER_FIELDS}

    if all(old.get(k) == str(fresh[k]) for k in COUNTER_FIELDS):
        return "unchanged", {"values": fresh}

    lines = text.splitlines(keepends=True)
    out: list[str] = []
    in_block = False
    written = set()
    for line in lines:
        if re.match(r"^metrics:\s*$", line.rstrip("\n")):
            in_block = True
            out.append(line)
            continue
        if in_block:
            stripped = line.rstrip("\n")
            if stripped and not stripped.startswith((" ", "\t", "#")):
                in_block = False
            else:
                m = re.match(r"^(\s+)([A-Za-z_][A-Za-z0-9_]*):\s*(.*?)\s*$", stripped)
                if m and m.group(2) in COUNTER_FIELDS:
                    key = m.group(2)
                    out.append(f"{m.group(1)}{key}: {fresh[key]}\n")
                    written.add(key)
                    continue
                # Do not carry a previous refresh's provenance forward; it is
                # rewritten below so repeated refreshes do not accumulate.
                if m and m.group(2) in (
                    "footprint_refreshed_at",
                    "footprint_refreshed_by_commit",
                ):
                    continue
        out.append(line)

    if written != set(COUNTER_FIELDS):
        return "partial-block", {"written": sorted(written)}

    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    prov = [
        f"  footprint_refreshed_at: '{ts}'\n",
        f"  footprint_refreshed_by_commit: {commit or 'unknown'}\n",
    ]

    # Insert provenance directly after the last counter so it reads next to the
    # values it explains, not at the end of the file.
    text_out = "".join(out)
    anchor = re.search(r"^(\s+)lines_removed: .*\n", text_out, re.M)
    if anchor:
        i = anchor.end()
        text_out = text_out[:i] + "".join(prov) + text_out[i:]
    else:
        text_out += "".join(prov)

    episodic.write_text(text_out)
    return "refreshed", {"old": old, "new": fresh}


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("task_id")
    ap.add_argument("--project-root", default=".")
    ap.add_argument("--commit", default="", help="commit sha this refresh hangs off")
    ap.add_argument("--quiet", action="store_true")
    a = ap.parse_args(argv)

    root = Path(a.project_root).resolve()
    episodic = root / ".context" / "episodic" / f"{a.task_id}.yaml"

    outcome, detail = refresh(episodic, root, a.task_id, a.commit)

    if not a.quiet:
        if outcome == "refreshed":
            o, n = detail["old"], detail["new"]
            changed = ", ".join(
                f"{k} {o.get(k)}->{n[k]}" for k in COUNTER_FIELDS if o.get(k) != str(n[k])
            )
            print(f"episodic {a.task_id}: footprint refreshed ({changed})")
        elif outcome == "skipped-not-refreshable":
            print(
                f"episodic {a.task_id}: git_mining={detail['git_mining']} — left alone "
                "(absent measurement is T-3129's, repaired by backfill)"
            )

    # Never fail a commit over this. The hook is best-effort by construction:
    # a stale footprint is a reporting defect, a failed post-commit hook is a
    # workflow defect, and trading the second for the first is a bad deal.
    return 0


if __name__ == "__main__":
    sys.exit(main())
