"""Degenerate-scorer alarm — slice 2 of docs/architecture/bvp-feedback-loop.md.

T-3489, under T-3484. **The control that replaces the removed confirmation
gate**, and the reason S2 ships before S3's auto-apply: auto-applying a scorer
already proven flat would industrialise the defect the revamp exists to remove.

A scorer whose output barely varies across a family of tasks is not judging, it
is emitting a constant wearing a judgement's shape. That is invisible in any
single score — a task scored `D1=4 D2=0 D3=2 D4=2` looks entirely reasonable
alone. It only shows up in the distribution, which is why nothing caught it:
the confirmation gate inspected one task at a time, and was never run anyway
(0 confirmed `bvp_scores` corpus-wide).

**Thresholds are derived from the live corpus, not chosen.** Measured over 3,419
tasks carrying a proposed D1-D4 score:

    family          n     variance D1    D2    D3    D4
    build         2556             2.859 1.913 1.827 1.411
    inception      497             0.196 0.438 0.381 0.195   <- degenerate
    test           162             2.818 0.430 1.679 1.414
    refactor       156             3.639 1.673 1.279 0.972
    specification   25             3.200 3.366 1.978 1.258
    design          20             2.040 3.310 1.200 0.640

`inception` sits an order of magnitude below every other family on D1 and D4, so
`VARIANCE_FLOOR = 0.5` separates it cleanly (inception's worst is 0.438,
build's best is 1.411). Nothing was tuned to make a number come out.

**Two detectors, because flatness has two shapes.**

1. *Per-family variance* — the scorer cannot tell members of one family apart.
2. *Pattern concentration* — a handful of exact score tuples dominate the whole
   corpus. Measured: `(4,0,3,2)` on 465 tasks and `(4,0,2,2)` on 454 — **919
   tasks, 26.9%, on two patterns.** procAsFit round 3 found this shape on a
   39-task backlog; it is corpus-wide. Worse, `(2,2,2,2)` on 440 and
   `(0,0,0,0)` on 550 are the estimator's own no-signal fallbacks: **29% of all
   scored tasks carry a placeholder rather than a judgement.**

Variance alone would miss (2) — a bimodal corpus split between two constants has
respectable variance and zero discrimination.

**Insufficient data is reported as insufficient, never as healthy.** A family
below `MIN_FAMILY` has no meaningful variance, and returning "ok" for it is the
T-3099 false-green class: a check that did not evaluate must not read as a check
that found nothing.

Standalone by construction: imports nothing from the scorer it watches, so it
still runs while the scorer is mid-change. Pure stdlib.
"""

from __future__ import annotations

import glob
import os
import re
import statistics
from collections import Counter, defaultdict

DRIVERS = ("D1", "D2", "D3", "D4")

#: T-3495: **which axis a family is actually scored on.**
#:
#: The first version of this detector measured D1-D4 for every family and so
#: reported `inception` as flat — which it is, and which is DELIBERATE.
#: `estimator.py:2668` cites `050-Inceptions.md §Scoring Exception`: inceptions
#: are scored on `voi_score` + `target_blast_radius` (ruling T-2186/T-2188), not
#: on the four directives. Flagging that trained the reader to dismiss the alarm
#: — the T-3453 inverted-alarm class, in a detector barely an hour old.
#:
#: Declared as a table rather than a branch so the next scoring exception is one
#: entry, not another special case buried in the verdict function.
AXES = {
    "drivers": {
        "fields": DRIVERS,
        # Derived from the corpus: inception's worst D-variance was 0.438,
        # build's best 1.411. Nothing tuned to make a number come out.
        "floor": 0.5,
        "scale": "four directives, integers 0-5",
    },
    "voi": {
        "fields": ("voi_score",),
        # voi_score is a float in 0..1, so the driver floor is meaningless here:
        # 0.5 variance is impossible on that range. 0.01 is a standard deviation
        # of 0.1 — a tenth of the available scale. Measured actual: 0.0008.
        "floor": 0.01,
        "scale": "value-of-information, float 0..1",
    },
}

#: Family → axis name. A family ABSENT here is reported `unknown-axis`, never
#: `ok`: a detector that silently applies the wrong axis to a new workflow type
#: is how this defect happened in the first place (T-3099 discipline — a check
#: that did not evaluate must not read as one that found nothing).
FAMILY_AXIS = {
    "build": "drivers",
    "refactor": "drivers",
    "test": "drivers",
    "specification": "drivers",
    "design": "drivers",
    "decommission": "drivers",
    "inception": "voi",
}

#: Kept for callers that referenced it before the axis table existed.
VARIANCE_FLOOR = AXES["drivers"]["floor"]

#: Fewer members than this and variance says nothing. Reported as
#: `insufficient`, never as a pass.
MIN_FAMILY = 5

#: Share of a corpus held by its top two exact score tuples, above which the
#: scorer is concentrating regardless of variance. Measured today: 26.9%.
CONCENTRATION_CEILING = 0.25

_BLOCK_RE = re.compile(r"^bvp_scores_proposed:\s*\n(.*?)(?=^[a-z_]+:|^---)", re.S | re.M)
_WF_RE = re.compile(r"^workflow_type:\s*(\S+)", re.M)

FIRED = "fired"
OK = "ok"
INSUFFICIENT = "insufficient"
UNKNOWN_AXIS = "unknown-axis"

_VOI_RE = re.compile(r"^voi_score:\s*([0-9.]+)", re.M)
_TBR_RE = re.compile(r"^target_blast_radius:\s*(\d+)", re.M)


def parse_task(text: str) -> tuple[str, dict] | None:
    """(family, measured fields) for a task, or None if it carries none.

    T-3495: returns whatever the task actually carries — D1-D4 for
    driver-scored families, `voi_score` for inceptions — rather than assuming
    every family is scored the same way. The caller picks the axis via
    `FAMILY_AXIS`; this function only reports what is present.
    """
    family_match = _WF_RE.search(text)
    family = family_match.group(1) if family_match else "unknown"
    values: dict[str, float] = {}

    block = _BLOCK_RE.search(text)
    if block:
        found_drivers = {}
        for driver in DRIVERS:
            hit = re.search(rf"^\s+{driver}:\s*(\d+)", block.group(1), re.M)
            if hit:
                found_drivers[driver] = int(hit.group(1))
        # Partial driver sets are not scored: a task with two of four drivers
        # tells us nothing about spread, and averaging it in would invent one.
        if len(found_drivers) == len(DRIVERS):
            values.update(found_drivers)

    voi = _VOI_RE.search(text)
    if voi:
        values["voi_score"] = float(voi.group(1))
    tbr = _TBR_RE.search(text)
    if tbr:
        values["target_blast_radius"] = int(tbr.group(1))

    return (family, values) if values else None


def collect(root: str | os.PathLike = ".") -> list[tuple[str, dict]]:
    out = []
    for pattern in (".tasks/active/T-*.md", ".tasks/completed/T-*.md"):
        for path in glob.glob(os.path.join(str(root), pattern)):
            try:
                text = open(path, encoding="utf-8", errors="ignore").read()
            except OSError:
                continue
            parsed = parse_task(text)
            if parsed:
                out.append(parsed)
    return out


def family_verdicts(rows, floor: float | None = None,
                    min_family: int = MIN_FAMILY) -> list[dict]:
    """Per-family variance verdict, **measured on that family's own axis**.

    Four states, never two: `fired`, `ok`, `insufficient`, `unknown-axis`.

    `floor` overrides the axis's own floor when given — used by tests to probe a
    threshold. Left None in normal use so each axis keeps the floor derived for
    its own scale; a single global floor is what made the pre-T-3495 version
    compare a 0..1 float against a threshold built for 0-5 integers.
    """
    grouped = defaultdict(list)
    for family, values in rows:
        grouped[family].append(values)

    verdicts = []
    for family, members in sorted(grouped.items(), key=lambda kv: -len(kv[1])):
        axis_name = FAMILY_AXIS.get(family)
        if axis_name is None:
            verdicts.append({
                "family": family, "n": len(members), "verdict": UNKNOWN_AXIS,
                "detail": ("no declared scoring axis — add it to FAMILY_AXIS "
                           "rather than letting it default, or the wrong axis "
                           "gets measured silently"),
            })
            continue

        axis = AXES[axis_name]
        fields = axis["fields"]
        active_floor = axis["floor"] if floor is None else floor

        # Only members that actually carry every field of their axis can be
        # compared. A member missing one is skipped, not zero-filled.
        usable = [m for m in members if all(f in m for f in fields)]
        if len(usable) < min_family:
            verdicts.append({
                "family": family, "n": len(members), "axis": axis_name,
                "usable": len(usable), "verdict": INSUFFICIENT,
                "detail": (f"fewer than {min_family} members carry the full "
                           f"{axis_name} axis — variance says nothing"),
            })
            continue

        variance = {f: round(statistics.pvariance([m[f] for m in usable]), 4)
                    for f in fields}
        flat = [f for f, v in variance.items() if v < active_floor]
        modal = Counter(tuple(m[f] for f in fields) for m in usable).most_common(1)[0]
        verdicts.append({
            "family": family, "n": len(usable), "axis": axis_name,
            "scale": axis["scale"], "floor": active_floor,
            "verdict": FIRED if flat else OK,
            "variance": variance,
            "flat_drivers": flat,
            # Name the constant, not just the verdict: "flat" with no value is
            # unactionable — the reader needs to see WHICH constant.
            "modal_pattern": modal,
            "modal_share": round(modal[1] / len(usable), 4),
        })
    return verdicts


def concentration(rows, ceiling: float = CONCENTRATION_CEILING, top: int = 2) -> dict:
    """Share of the corpus on its `top` most common exact tuples.

    Catches the shape variance misses: a corpus split between two constants has
    healthy variance and no discrimination at all.
    """
    # T-3495: only driver-scored rows belong here. Before the axis table an
    # inception row would KeyError on D1 — or worse, be zero-filled and counted
    # as a pattern it never had.
    scored = [s for family, s in rows
              if FAMILY_AXIS.get(family) == "drivers" and all(d in s for d in DRIVERS)]
    if not scored:
        return {"verdict": INSUFFICIENT, "detail": "no driver-scored tasks", "n": 0}
    patterns = Counter(tuple(s[d] for d in DRIVERS) for s in scored)
    leaders = patterns.most_common(top)
    rows = scored  # every share below is of the driver-scored population
    share = sum(c for _, c in leaders) / len(rows)
    return {
        "verdict": FIRED if share > ceiling else OK,
        "n": len(rows),
        "share": round(share, 4),
        "ceiling": ceiling,
        "top": [{"pattern": list(p), "count": c, "share": round(c / len(rows), 4)}
                for p, c in leaders],
        "distinct": len(patterns),
    }


def report(root: str | os.PathLike = ".") -> dict:
    rows = collect(root)
    fams = family_verdicts(rows)
    conc = concentration(rows)
    return {
        "scored_tasks": len(rows),
        "families": fams,
        "concentration": conc,
        "fired": any(f["verdict"] == FIRED for f in fams) or conc["verdict"] == FIRED,
    }


def render(rep: dict) -> str:
    lines = [f"BVP degenerate-scorer alarm — {rep['scored_tasks']} scored task(s)", ""]
    for f in rep["families"]:
        if f["verdict"] == INSUFFICIENT:
            lines.append(f"  [INSUFFICIENT] {f['family']:<14} n={f['n']:<5} {f['detail']}")
            continue
        if f["verdict"] == UNKNOWN_AXIS:
            lines.append(f"  [UNKNOWN-AXIS] {f['family']:<14} n={f['n']:<5} {f['detail']}")
            continue
        tag = "[FIRED]" if f["verdict"] == FIRED else "[ok]   "
        lines.append(f"  {tag} {f['family']:<14} n={f['n']:<5} "
                     f"axis={f['axis']:<8} var={f['variance']}")
        if f["verdict"] == FIRED:
            pattern, count = f["modal_pattern"]
            shown = list(pattern) if len(pattern) > 1 else pattern[0]
            lines.append(f"          flat on {f['flat_drivers']} "
                         f"(floor {f['floor']}); modal {shown} on {count} of "
                         f"{f['n']} ({f['modal_share']:.1%}) — {f['scale']}")
    c = rep["concentration"]
    lines.append("")
    tag = "[FIRED]" if c["verdict"] == FIRED else "[ok]   "
    if c["verdict"] == INSUFFICIENT:
        lines.append(f"  [INSUFFICIENT] concentration — {c['detail']}")
    else:
        lines.append(f"  {tag} concentration  top-2 share={c['share']:.1%} "
                     f"(ceiling {c['ceiling']:.0%}), {c['distinct']} distinct patterns")
        for t in c["top"]:
            lines.append(f"          D1-D4={t['pattern']} on {t['count']} "
                         f"({t['share']:.1%})")
    return "\n".join(lines)


if __name__ == "__main__":  # pragma: no cover
    import sys
    rep = report(sys.argv[1] if len(sys.argv) > 1 else ".")
    print(render(rep))
    sys.exit(1 if rep["fired"] else 0)
