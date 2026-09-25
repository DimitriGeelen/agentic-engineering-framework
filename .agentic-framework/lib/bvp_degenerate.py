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

#: Below this per-driver variance a family is not being discriminated.
#: Derived: inception's worst measured is 0.438, build's best is 1.411.
VARIANCE_FLOOR = 0.5

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


def parse_task(text: str) -> tuple[str, dict] | None:
    """(family, {D1..D4}) for a task carrying a full proposed score, else None."""
    block = _BLOCK_RE.search(text)
    if not block:
        return None
    scores = {}
    for driver in DRIVERS:
        found = re.search(rf"^\s+{driver}:\s*(\d+)", block.group(1), re.M)
        if found:
            scores[driver] = int(found.group(1))
    if len(scores) != len(DRIVERS):
        return None
    family = _WF_RE.search(text)
    return (family.group(1) if family else "unknown"), scores


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


def family_verdicts(rows, floor: float = VARIANCE_FLOOR,
                    min_family: int = MIN_FAMILY) -> list[dict]:
    """Per-family variance verdict. Three states, never two."""
    grouped = defaultdict(list)
    for family, scores in rows:
        grouped[family].append(scores)

    verdicts = []
    for family, members in sorted(grouped.items(), key=lambda kv: -len(kv[1])):
        if len(members) < min_family:
            verdicts.append({
                "family": family, "n": len(members), "verdict": INSUFFICIENT,
                "detail": f"fewer than {min_family} scored members — variance says nothing",
            })
            continue
        variance = {d: round(statistics.pvariance([m[d] for m in members]), 3)
                    for d in DRIVERS}
        flat = [d for d, v in variance.items() if v < floor]
        verdicts.append({
            "family": family, "n": len(members),
            "verdict": FIRED if flat else OK,
            "variance": variance,
            "flat_drivers": flat,
            # Name the constant, not just the verdict: "flat" with no value is
            # unactionable — the operator needs to see WHICH constant.
            "modal_pattern": Counter(
                tuple(m[d] for d in DRIVERS) for m in members).most_common(1)[0]
            if members else None,
        })
    return verdicts


def concentration(rows, ceiling: float = CONCENTRATION_CEILING, top: int = 2) -> dict:
    """Share of the corpus on its `top` most common exact tuples.

    Catches the shape variance misses: a corpus split between two constants has
    healthy variance and no discrimination at all.
    """
    if not rows:
        return {"verdict": INSUFFICIENT, "detail": "no scored tasks", "n": 0}
    patterns = Counter(tuple(s[d] for d in DRIVERS) for _, s in rows)
    leaders = patterns.most_common(top)
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
        tag = "[FIRED]" if f["verdict"] == FIRED else "[ok]   "
        lines.append(f"  {tag} {f['family']:<14} n={f['n']:<5} var={f['variance']}")
        if f["verdict"] == FIRED:
            pattern, count = f["modal_pattern"]
            lines.append(f"          flat on {f['flat_drivers']}; "
                         f"modal D1-D4={list(pattern)} on {count} of {f['n']}")
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
