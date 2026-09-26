"""BVP usage axis — slice 6 of docs/architecture/bvp-feedback-loop.md.

T-3499, arc-006. Answers "is this verb actually being used?", which the operator
asked for directly: *"we should measure if it's actually being used, and it's
used effectively."*

**Why this slice had to start with a writer.** The design doc's §4.3(a) said usage
was already available from "`lib/hook-telemetry.sh` and the existing counters".
It was not: that module counts **hooks**, not verbs — `.hook-counter` holds
`check-active-task`, `budget-gate`, and no fw verb at all. Coverage was zero, not
thin. `bin/fw` now increments `.context/working/.verb-counter` at its single
dispatch point (T-3499); this module reads it.

**The rule that keeps the axis honest — usage is never reported alone.** A verb
nobody calls may be *unused* or merely *unknown*, and the correct response
differs: retire versus surface. So every verb is classified against its
**discoverability**, and a verb that is discoverable but uncalled is reported as
its own class rather than folded in with the rest. An unpaired usage count would
retire features nobody had been told about — which is the same mistake as
arc-020, where a complete, tested capability sat unused because nothing asked
whether it was being called.

**Unmeasured is not zero.** An absent counter yields ``available: False``, never a
corpus of zero-usage verbs. Same discipline as `bvp_outcomes.cost_for_task`
returning None and T-3068's `blast_radius` being unknown-not-zero: a system that
cannot say "I do not know" will learn from numbers it invented.

Pure stdlib.
"""

from __future__ import annotations

import os
import re
from pathlib import Path

COUNTER_REL = os.path.join(".context", "working", ".verb-counter")

#: Verbs deliberately absent from the counter, so the reader does not report them
#: as unused. `hook` is excluded at the writer (already counted per-hook in
#: .hook-counter, and the hottest path), so it can never appear here.
NOT_INSTRUMENTED = frozenset({"hook"})

USED = "used"
DISCOVERABLE_UNUSED = "discoverable-but-unused"
UNDISCOVERABLE_UNUSED = "undiscoverable-and-unused"
NOT_INSTRUMENTED_CLASS = "not-instrumented"

#: A dispatch branch in bin/fw's main `case`: four-space indent, one or more
#: `|`-separated verb names, then `)`. Anchored to the routing marker below so a
#: nested case elsewhere in the file cannot leak verbs into the universe.
_ROUTING_MARKER = "--- Main Command Routing ---"
_BRANCH_RE = re.compile(r"^ {4}([a-z][a-z0-9|-]*)\)\s*$", re.M)


def _root(root=None) -> Path:
    if root:
        return Path(root)
    return Path(os.environ.get("PROJECT_ROOT") or os.environ.get("FRAMEWORK_ROOT") or ".")


def read_counter(root=None) -> dict[str, int] | None:
    """{verb: count} from the flat `key=count` counter, or None if unreadable.

    None means NOT MEASURED. The caller must render that as ``available: False``
    and must not substitute an empty dict, which would read identically to "every
    verb has zero usage" — the precise collapse this module exists to prevent.
    """
    path = _root(root) / COUNTER_REL
    if not path.is_file():
        return None
    out: dict[str, int] = {}
    try:
        for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
            line = line.strip()
            if not line or "=" not in line:
                continue
            key, _, raw = line.partition("=")
            key = key.strip()
            if not key:
                continue
            try:
                out[key] = int(raw.strip())
            except ValueError:
                continue  # a corrupt count is not a zero count; skip the line
    except OSError:
        return None
    return out


def known_verbs(root=None) -> set[str]:
    """The verb universe, parsed from bin/fw's own dispatch `case`.

    Parsed rather than hand-listed because a hand-listed universe drifts the
    moment a verb is added, and a verb missing from the universe is invisible to
    this whole axis — it would never be reported as unused however long it sat
    uncalled.
    """
    path = _root(root) / "bin" / "fw"
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return set()
    cut = text.find(_ROUTING_MARKER)
    if cut >= 0:
        text = text[cut:]
    verbs: set[str] = set()
    for match in _BRANCH_RE.finditer(text):
        for name in match.group(1).split("|"):
            if name:
                verbs.add(name)
    return verbs


def discoverable_verbs(root=None) -> set[str]:
    """Verbs a reader could plausibly find out about.

    Deliberately a PROXY, and named as one: a verb is treated as discoverable if
    it appears in `bin/fw`'s help text or is named in CLAUDE.md. Neither source
    proves anyone actually read it — discoverability is not knowledge. The proxy
    only has to be good enough to keep "never advertised" separable from
    "advertised and still unused", because those two demand opposite responses.
    """
    rootp = _root(root)
    blob = []
    for rel in (("bin", "fw"), ("CLAUDE.md",)):
        try:
            blob.append(rootp.joinpath(*rel).read_text(encoding="utf-8", errors="ignore"))
        except OSError:
            continue
    if not blob:
        return set()
    text = "\n".join(blob)
    found: set[str] = set()
    for verb in known_verbs(root):
        # `fw <verb>` as it appears in help lines, docs and the Quick Reference.
        if re.search(rf"\bfw\s+{re.escape(verb)}\b", text):
            found.add(verb)
    return found


def classify(root=None) -> dict:
    """Per-verb usage paired with discoverability.

    Returns ``available: False`` with no verb rows when the counter is absent,
    rather than reporting every verb as unused.
    """
    counts = read_counter(root)
    if counts is None:
        return {
            "available": False,
            "reason": "verb counter absent — instrumentation has not run yet",
            "verbs": {},
            "totals": {},
        }

    universe = known_verbs(root) | set(counts)
    discoverable = discoverable_verbs(root)

    verbs: dict[str, dict] = {}
    for verb in sorted(universe):
        count = counts.get(verb, 0)
        if verb in NOT_INSTRUMENTED:
            klass = NOT_INSTRUMENTED_CLASS
        elif count > 0:
            klass = USED
        elif verb in discoverable:
            klass = DISCOVERABLE_UNUSED
        else:
            klass = UNDISCOVERABLE_UNUSED
        verbs[verb] = {
            "count": count,
            "discoverable": verb in discoverable,
            "class": klass,
        }

    totals: dict[str, int] = {}
    for row in verbs.values():
        totals[row["class"]] = totals.get(row["class"], 0) + 1

    return {
        "available": True,
        "verbs": verbs,
        "totals": totals,
        "observed_invocations": sum(counts.values()),
        # Stated with every report, like S1's attributable_fraction: a usage
        # census taken over a short window under-reports rare-but-real verbs, and
        # a reader that does not see the window will mistake it for a long record.
        "caveat": ("counts accumulate from first instrumentation only; a low count "
                   "may mean a short observation window, not low value"),
    }


def retirable(root=None) -> list[str]:
    """Verbs it would be defensible to *consider* retiring.

    Only `undiscoverable-and-unused`. A discoverable-but-unused verb is
    explicitly NOT here: nobody calling something that was advertised is a
    different finding from nobody calling something that never was, and the
    second is a documentation failure rather than a dead feature.
    """
    report = classify(root)
    if not report["available"]:
        return []
    return [v for v, row in report["verbs"].items()
            if row["class"] == UNDISCOVERABLE_UNUSED]
