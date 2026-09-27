#!/usr/bin/env python3
"""lib/arc_driver_judge.py — judges an arc-SCOPED DRIVER (T-3527, D-662 slice 3 of 3).

T-3524 GO. This is the second of the two judges the operator ruled for: a driver is
the YARDSTICK a task score gets measured against, and a task score is the
MEASUREMENT — one agent holding both would judge with a yardstick it made itself,
producer-not-judge one level up from T-3526's BVP score judge. This module judges a
proposed or approved arc-scoped driver against the ARC's own goal and objective; it
does not propose drivers (that stays `fw arc approve-driver` / the T-1925 workflow)
and it does not decide `--none` (that stays human-only, T-3429/D-586).

── IMPORTS THE CONTRACT, DEFINES NO SECOND ONE ──────────────────────────────────

This module imports `lib.judge_verdict` for every piece of verdict vocabulary
(green/amber/red/unknown, guidance-required, `may_proceed`). It defines no local
state, no local `reviewable()`, no local guidance rule — see `lib/judge_verdict.py`'s
own docstring and `lib/bvp_judge.py`'s sibling docstring for why: arc membership in
this repo reached FIVE disagreeing implementations of one predicate before a full day
went into consolidating them into one file.

── WRAPS lib/arc-driver-review.sh, DOES NOT REPLACE IT ──────────────────────────

`lib/arc-driver-review.sh` (T-3429, D-586) already answers three STRUCTURAL
questions correctly and stays untouched by this task:

    (a) scorable      — can the estimator actually score this driver?
    (b) distinct      — does it collide with D1-D4 / free_drivers[] / this arc's
                        own scoped_drivers[]?
    (c) distinguishes — does the rationale name a directive it differs from, at
                        sufficient length (D6)?

`run_static_review()` below shells out to the real, unmodified
`_arc_driver_review_run` bash function (sourced fresh, `--dry-run` always) — the
WRAP is literal invocation, not reimplementation. What this module adds is the
judgement those three checks cannot make: whether the driver's rationale actually
connects to something THIS ARC pursues, as opposed to well-formed prose about
D1-D4 that could be pasted onto any arc.

── OBS-559: A TOOLING FAILURE IS NOT A DRIVER-QUALITY FAILURE ───────────────────

Empirically (not merely as a hypothetical), when the estimator module cannot be
executed, check (a)'s failure reason reads:

    "handler table unreadable (AttributeError: module '...' has no attribute
    '_handler_table')"

— NOT the more obvious-sounding "estimator unimportable", because
`importlib.util.spec_from_file_location()` happily returns a spec for any
`.py`-suffixed path regardless of whether the file exists, so `est` in
`arc-driver-review.sh` is left holding a broken-but-non-None module object rather
than `None`. Verified by actually breaking the import (see
`tests/unit/test_arc_driver_judge.py`'s tooling-failure fixture, which points
`FRAMEWORK_ROOT`/`root` at a directory with no `agents/termlink/bvp-estimator/`
at all — a real unimportable state, not a mock). Both phrasings are treated as the
same TOOLING signature by `_is_tooling_failure()`, because the underlying defect —
answering "the check could not run" as if it were "the check ran and failed" — is
one defect regardless of which exception happened to fire first.

A genuine scorability failure (driver really has no handler, no inline `scoring:`
block, no `scoring_file:`) reads differently — "no handler, no inline scoring:
block, no scoring_file: (T-3428)" — and correctly stays a real, RED-worthy finding.
This module tells the two apart by matching the reason text, not by re-deciding
scorability itself; the static check's own words already carry the distinction.

── THE ARC-GOAL YARDSTICK (D-662, applied at arc level not task level) ──────────

`lib.bvp_judge`'s goal-hierarchy check does NOT do semantic/lexical matching
between a proposal's rationale and its objective text — it checks STRUCTURE:
is a written-down objective resolvable at all, and does the proposal's own
evidence self-contradict. The equivalent temptation here — word-overlap between a
driver's rationale and the arc's `description:`/`headline_mechanic:` — was tried
and measured against the live corpus before being rejected: of 8 real,
already-approved scoped/proposed drivers checked, 3 (continuous-run's
"Discard fidelity", onboarding-shape-detection's "unknown-input-safety",
watchtower-redesign's "aesthetic-cohesion") shared ZERO significant vocabulary
with their arc's goal text while being perfectly good drivers — a 37.5% false-positive
rate on data that already passed human/agent review. Good drivers are SUPPOSED to
name what they distinguish from D1-D4, not parrot the arc's own phrasing back.

So this module follows bvp_judge's actual shape instead of the tempting lexical one:

  1. SELF-ADMISSION (mirrors bvp_judge's "no-signal" self-contradiction): does the
     rationale's own text admit doubt about whether it distinguishes anything —
     "weak candidate", "may prefer to [fold this into D3]", "likely to be
     withdrawn", etc.? Calibrated against the full live corpus of
     proposed_scoped_drivers[]/scoped_drivers[] across every arc in
     `.context/arcs/`: exactly 2 hits, both genuine (dispatch-safety's
     "operator-resolution-latency", explicitly flagged "(WEAK candidate per R5)";
     continuous-run's "Loop closure (conditional)", explicitly "likely to be
     withdrawn"), zero false positives. This is the deterministic, measured case
     D-662 names: "a driver that distinguishes nothing the arc actually pursues."
  2. LEVEL MATCH (mirrors bvp_judge's high-claim-on-project-fallback-only): a
     near-max-weight driver (>= HIGH_WEIGHT_FLOOR, close to the M2 cap of 6)
     resting only on the project-level D1-D4 fallback — i.e. the ARC ITSELF has
     no resolvable `description:`/`headline_mechanic:` at all — has nothing
     arc-specific to be checked against. Rare in practice (every in-progress arc in
     this repo currently has non-empty description/headline_mechanic); kept for
     the same reason bvp_judge keeps its analogous branch: absence must not be
     silently favourable.

── POPULATION: NOT A CLOSED ARC ─────────────────────────────────────────────────

`judge_driver()` refuses to judge a `closed`/`abandoned` arc — mirrors D-662's
closed-task rule (a closed thing's record is what was decided at the time) without
reusing `judge_verdict.reviewable()` verbatim, because arc lifecycle states
("draft"/"in-progress"/"closed"/"abandoned", T-1852) are a different vocabulary
from task statuses ("work-completed" etc.) and forcing one function to parse both
would be exactly the kind of cross-domain coupling this module's docstring above
warns against for the estimator. The verdict STATES (green/amber/red/unknown) and
the guidance-required rule are the one shared contract; population scoping is
domain-specific on both sides.

── READ-ONLY ─────────────────────────────────────────────────────────────────────

This module never writes to an arc YAML. `run_static_review()` always passes
`dry_run=true` to the wrapped shell function. There is no write path here to gate.

── OUT OF SCOPE (confirmed by diff) ─────────────────────────────────────────────

The estimator's own detector quality (T-3410), any multi-model judge panel
(D-662 IW-5, deferred not rejected), and `fw arc close`/`fw arc abandon` (closure
decisions, human-gated since T-1671 over four incidents) are untouched by this
module and this task.
"""

from __future__ import annotations

import json
import os
import re
import shlex
import subprocess
from pathlib import Path

import yaml

from lib.judge_verdict import AMBER, GREEN, RED, UNKNOWN, verdict

JUDGE_ID = "arc-driver-judge-v1"

PROJECT_ROOT = Path(os.environ.get("PROJECT_ROOT") or
                     os.environ.get("FRAMEWORK_ROOT") or os.getcwd())
FRAMEWORK_ROOT = Path(os.environ.get("FRAMEWORK_ROOT") or PROJECT_ROOT)
ARCS_DIR = PROJECT_ROOT / ".context" / "arcs"
POLICY_PATH = PROJECT_ROOT / "policy" / "value-drivers.yaml"

#: Arc lifecycle states (T-1852) that are never rescored. Distinct vocabulary
#: from judge_verdict's task-status closed set on purpose — see module docstring.
_CLOSED_ARC_STATUSES = {"closed", "abandoned"}

#: A driver at or above this weight is close to the M2 cap of 6 — "load-bearing".
HIGH_WEIGHT_FLOOR = 5

#: Two substrings that both mean "the wrapped scorability check (a) could not
#: execute", empirically distinct from a genuine "no handler/spec" finding. See
#: the module docstring's OBS-559 section for how each is actually produced.
_TOOLING_FAILURE_SUBSTRINGS = ("estimator unimportable", "handler table unreadable")

#: Calibrated against every proposed_scoped_drivers[]/scoped_drivers[] entry on
#: every arc in .context/arcs/ (see module docstring) — exactly 2 hits, both
#: genuine self-admissions, zero false positives across the rest of the corpus.
_SELF_ADMISSION_MARKERS = (
    "weak candidate",
    "becomes redundant",
    "likely to be withdrawn",
    "may prefer to",
    "flagged for operator",
    "operator may prefer",
    "open question",
    "boundary with",
    "propose only if",
    "approve --none",
)

_norm_strip_re = re.compile(r"[^a-z0-9]+")
_norm_collapse_re = re.compile(r"-+")


def _norm(s) -> str:
    """Same fold as arc-driver-review.sh's norm(): case/whitespace/punctuation
    all become hyphens, so name matching agrees with the wrapped shell check."""
    folded = _norm_strip_re.sub("-", str(s or "").lower())
    return _norm_collapse_re.sub("-", folded).strip("-")


def _is_tooling_failure(reason: str) -> bool:
    r = (reason or "").lower()
    return any(m in r for m in _TOOLING_FAILURE_SUBSTRINGS)


# ───────────────────────── arc / driver lookup (self-contained on purpose) ──────
#
# Plain YAML lookups, not verdict vocabulary — kept local rather than imported
# from lib.bvp_judge to avoid coupling this judge's import graph to that one
# (same rationale bvp_judge.py itself gives for not importing lib.reviewer's
# equivalents).


def resolve_arc_file(arc_id: str, *, arcs_dir: Path | None = None) -> Path | None:
    """Resolve a slug or arc-NNN id to its YAML path. None if not found."""
    d = arcs_dir if arcs_dir is not None else ARCS_DIR
    direct = d / f"{arc_id}.yaml"
    if direct.is_file():
        return direct
    if d.is_dir():
        for p in sorted(d.glob("*.yaml")):
            try:
                data = yaml.safe_load(p.read_text()) or {}
            except yaml.YAMLError:
                continue
            if data.get("id") == arc_id or data.get("slug") == arc_id:
                return p
    return None


def load_arc(arc_file: Path) -> dict:
    try:
        return yaml.safe_load(arc_file.read_text()) or {}
    except (OSError, yaml.YAMLError):
        return {}


def find_driver_entry(arc_data: dict, name: str) -> tuple[dict | None, str]:
    """(entry, where). Proposed first, then approved — an already-approved driver
    is judgeable too (mirrors arc-driver-review.sh's own selection fallback,
    which is how the six unscorable-but-approved drivers the T-3428 audit names
    get a verdict at all)."""
    key = _norm(name)
    for e in (arc_data.get("proposed_scoped_drivers") or []):
        if isinstance(e, dict) and key in {_norm(e.get("name")), _norm(e.get("id"))}:
            return e, "proposed_scoped_drivers"
    for e in (arc_data.get("scoped_drivers") or []):
        if isinstance(e, dict) and key in {_norm(e.get("name")), _norm(e.get("id"))}:
            return e, "scoped_drivers"
    return None, ""


def list_driver_names(arc_data: dict) -> list[str]:
    """Ordered, de-duplicated driver names across proposed + approved, for --all."""
    seen: set[str] = set()
    out: list[str] = []
    for field in ("proposed_scoped_drivers", "scoped_drivers"):
        for e in (arc_data.get(field) or []):
            if not isinstance(e, dict):
                continue
            nm = e.get("name") or e.get("id")
            if not nm:
                continue
            key = _norm(nm)
            if key in seen:
                continue
            seen.add(key)
            out.append(nm)
    return out


# ───────────────────────── the wrap: shell to the real static checks ───────────


#: The real, unmodified script this module wraps — sourced from ITS OWN location
#: on disk (this module lives in lib/, a sibling of arc-driver-review.sh), never
#: from a caller-supplied path. `framework_root` below controls only what the
#: WRAPPED function sees as its own `FRAMEWORK_ROOT` (i.e. where it looks for the
#: estimator) — decoupled on purpose so a test can point the estimator lookup at
#: a directory with no `agents/termlink/bvp-estimator/` at all (a genuine
#: unimportable state) without needing a second copy of arc-driver-review.sh.
_ARC_DRIVER_REVIEW_SH = Path(__file__).resolve().parent / "arc-driver-review.sh"


def run_static_review(arc_file: Path, name: str, *, root: Path | None = None,
                       framework_root: Path | None = None, timeout: int = 30) -> dict:
    """Shell out to the REAL `_arc_driver_review_run` (lib/arc-driver-review.sh),
    always `--dry-run`. This is the WRAP — the static checks are invoked exactly
    as `fw arc review-driver` would invoke them, never reimplemented. Returns the
    parsed JSON dict (with `_rc` added), or an `{"error": ...}` dict if the
    subprocess could not be run/parsed at all (a failure ABOVE check (a) —
    reported as UNKNOWN by the caller, same "could not run" discipline as
    OBS-559 itself)."""
    root = root if root is not None else PROJECT_ROOT
    framework_root = framework_root if framework_root is not None else FRAMEWORK_ROOT
    script = (
        "set -u\n"
        f"FRAMEWORK_ROOT={shlex.quote(str(framework_root))}\n"
        f". {shlex.quote(str(_ARC_DRIVER_REVIEW_SH))}\n"
        f"_arc_driver_review_run {shlex.quote(str(arc_file))} {shlex.quote(str(root))} "
        f"{shlex.quote(name)} true json\n"
    )
    try:
        proc = subprocess.run(["bash", "-c", script], capture_output=True, text=True,
                               timeout=timeout)
    except (OSError, subprocess.TimeoutExpired) as e:
        return {"error": f"could not run wrapped static reviewer: {type(e).__name__}: {e}"}

    stdout = (proc.stdout or "").strip()
    if not stdout:
        return {"error": f"wrapped static reviewer produced no output (rc={proc.returncode}); "
                          f"stderr={proc.stderr.strip()!r}", "_rc": proc.returncode}
    try:
        data = json.loads(stdout.splitlines()[-1])
    except (json.JSONDecodeError, IndexError):
        return {"error": f"could not parse wrapped static reviewer output (rc={proc.returncode}): "
                          f"{stdout!r}", "_rc": proc.returncode}
    if not isinstance(data, dict):
        return {"error": f"wrapped static reviewer output was not a JSON object: {data!r}"}
    data["_rc"] = proc.returncode
    return data


# ───────────────────────── the arc-goal yardstick ───────────────────────────────


_PROJECT_DIRECTIVES_CACHE: dict[str, str] | None = None


def _project_directives() -> dict[str, str]:
    """{driver_id: note} for D1-D4 from policy/value-drivers.yaml. Cached like
    bvp_judge's equivalent — the project's own objective does not change within
    a process lifetime."""
    global _PROJECT_DIRECTIVES_CACHE
    if _PROJECT_DIRECTIVES_CACHE is not None:
        return _PROJECT_DIRECTIVES_CACHE
    out: dict[str, str] = {}
    if POLICY_PATH.is_file():
        try:
            policy = yaml.safe_load(POLICY_PATH.read_text()) or {}
            for d in policy.get("protected_drivers") or []:
                did, note = d.get("id"), (d.get("note") or "").strip()
                if did and note:
                    out[did] = note
        except yaml.YAMLError:
            pass
    _PROJECT_DIRECTIVES_CACHE = out
    return out


def resolve_arc_goal(arc_data: dict) -> tuple[str, str, list[str]]:
    """(level, goal_text, notes). level in "arc"/"project"/"" (unresolved).

    Arc level: description:/headline_mechanic: (either or both, whatever is
    written). Project level: the same D1-D4 fallback bvp_judge uses, which
    "always exists as the last resort" per that module's own docstring."""
    hm = str(arc_data.get("headline_mechanic") or "").strip()
    desc = str(arc_data.get("description") or "").strip()
    goal = " ".join(p for p in (hm, desc) if p)
    if goal:
        srcs = [s for s, present in (("headline_mechanic:", hm), ("description:", desc)) if present]
        return "arc", goal, [f"arc-level objective from {' + '.join(srcs)}"]

    directives = _project_directives()
    if directives:
        combined = "; ".join(f"{k}: {v}" for k, v in sorted(directives.items()))
        return "project", combined, ["no arc-level objective (empty description:/"
                                      "headline_mechanic:); fell back to the project's "
                                      "own D1-D4 (policy/value-drivers.yaml)"]
    return "", "", ["no readable objective at arc or project level"]


def check_self_admission(rationale: str) -> list[str]:
    """Markers the rationale itself uses to admit doubt about whether it
    distinguishes anything. See module docstring for the corpus calibration."""
    low = (rationale or "").lower()
    return [m for m in _SELF_ADMISSION_MARKERS if m in low]


# ───────────────────────── the combiner ─────────────────────────────────────────


def judge_driver(arc_id: str, arc_file: Path, arc_data: dict, name: str, *,
                  judge_id: str = JUDGE_ID, static_review: dict | None = None
                  ) -> tuple[dict | None, str]:
    """Judge one arc-scoped driver (proposed or approved).

    Returns (verdict_dict, reason). `verdict_dict` is None when there is nothing
    to judge (closed arc, driver not found) and `reason` says why — same
    denominator discipline as judge_verdict.reviewable()/bvp_judge.judge_task.

    `static_review` lets a caller (chiefly tests) inject a pre-computed static
    review result instead of shelling out — see run_static_review()'s own
    docstring for why the real path always shells to the unmodified bash check.
    """
    status = str(arc_data.get("status") or "").strip().lower()
    if status in _CLOSED_ARC_STATUSES:
        return None, (f"arc status {status!r} is closed; closed arcs are never rescored "
                       "(mirrors D-662's closed-task rule) — the arc's own scoped_drivers: "
                       "is the record of what was decided while it was open")

    entry, _where = find_driver_entry(arc_data, name)
    if entry is None:
        return None, (f"no driver named {name!r} found in proposed_scoped_drivers[] or "
                       f"scoped_drivers[] on arc {arc_id!r}")

    rationale = str(entry.get("rationale") or "")
    weight = entry.get("weight")
    if weight is None:
        weight = entry.get("weight_suggestion")

    judged = f"{arc_id}/{name}"

    review = static_review if static_review is not None else run_static_review(arc_file, name)
    if review.get("error"):
        v = verdict(
            UNKNOWN,
            guidance=(f"the wrapped static reviewer (lib/arc-driver-review.sh) could not "
                      f"produce a verdict for {name!r} on {arc_id!r}: {review['error']}. Fix "
                      "the underlying failure and re-run — this judge cannot add its own "
                      "quality judgement on top of a check that never ran."),
            judged=judged, judge=judge_id, evidence=[str(review["error"])],
        )
        return v, "static reviewer did not run"

    reviewed_list = review.get("reviewed") or []
    reviewed = reviewed_list[0] if reviewed_list else {}
    checks = reviewed.get("checks") or {}
    if not checks:
        err = review.get("error") or (f"no matching entry in the wrapped reviewer's output "
                                       f"(verdict={review.get('verdict')!r})")
        v = verdict(
            UNKNOWN,
            guidance=(f"the wrapped static reviewer returned no checks for {name!r} on "
                      f"{arc_id!r}: {err}. Fix the underlying failure and re-run."),
            judged=judged, judge=judge_id, evidence=[str(err)],
        )
        return v, "static reviewer returned no checks"

    a, b, c = checks.get("a") or {}, checks.get("b") or {}, checks.get("c") or {}

    real_failures: list[str] = []
    tooling_note = ""
    if b.get("verdict") != "pass":
        real_failures.append(f"(b) distinct: {b.get('reason')}")
    if c.get("verdict") != "pass":
        real_failures.append(f"(c) distinguishes: {c.get('reason')}")
    if a.get("verdict") != "pass":
        reason_a = a.get("reason") or ""
        if _is_tooling_failure(reason_a):
            tooling_note = reason_a
        else:
            real_failures.append(f"(a) scorable: {reason_a}")

    if real_failures:
        evidence = list(real_failures)
        if tooling_note:
            evidence.append(f"(a) scorable also could not run (tooling, not counted as a "
                             f"failure): {tooling_note}")
        v = verdict(
            RED,
            guidance=(f"{name!r} on arc {arc_id!r} fails the wrapped static check(s): "
                      + "; ".join(real_failures) +
                      ". Fix the issue(s) named above before this driver can be approved "
                      "or have its weight tuned."),
            judged=judged, judge=judge_id, evidence=evidence,
        )
        return v, "static check failed"

    admitted = check_self_admission(rationale)
    if admitted:
        # AMBER, not RED: the static checks (a/b/c) already passed — this is not
        # a structural defect, it is the candidate's OWN text expressing doubt.
        # "proceed, and record the guidance against the thing judged" (amber's
        # contract meaning) fits better than a hard block: the operator override
        # path (--i-am-human) may still want to approve it having read the flag.
        v = verdict(
            AMBER,
            guidance=(f"{name!r}'s own rationale admits doubt about whether it distinguishes "
                      f"anything this arc actually pursues (found: {', '.join(admitted)}). "
                      "Record this against the driver before approving: either strengthen "
                      "the rationale to state plainly what this arc pursues that no global "
                      "driver (D1-D4) captures, or withdraw the candidate — the text as "
                      "written argues against itself."),
            judged=judged, judge=judge_id,
            evidence=[f"rationale contains self-admission marker(s): {', '.join(admitted)}"],
        )
        return v, "self-admitted weak candidate"

    level, _goal_text, notes = resolve_arc_goal(arc_data)
    if not level:
        v = verdict(
            UNKNOWN,
            guidance=(f"cannot judge {name!r} against arc {arc_id!r}'s goal: no readable "
                      "objective at arc or project level. Add a description: or "
                      "headline_mechanic: to the arc, or fix policy/value-drivers.yaml."),
            judged=judged, judge=judge_id, evidence=notes,
        )
        return v, "goal hierarchy unresolved"

    if level == "project" and weight is not None:
        try:
            weight_i = int(weight)
        except (TypeError, ValueError):
            weight_i = None
        if weight_i is not None and weight_i >= HIGH_WEIGHT_FLOOR:
            v = verdict(
                RED,
                guidance=(f"{name!r} claims weight {weight_i} (near the M2 cap of 6) but arc "
                          f"{arc_id!r} has no resolvable description:/headline_mechanic: — a "
                          "near-max-weight claim needs something arc-specific to check it "
                          "against, not only the project's own D1-D4. Add the arc's goal text, "
                          "or lower the weight to match what can actually be checked."),
                judged=judged, judge=judge_id, evidence=notes,
            )
            return v, "high weight rests on project fallback only"

    evidence = [f"objective resolved at {level} level"] + notes
    if tooling_note:
        v = verdict(
            UNKNOWN,
            guidance=(f"checks (b)/(c) and the arc-goal check both pass for {name!r}, but static "
                      f"check (a) scorability could not run: {tooling_note}. Fix the estimator "
                      "import/environment and re-run before approving on scorability grounds."),
            judged=judged, judge=judge_id, evidence=evidence + [tooling_note],
        )
        return v, "scorability check unavailable (tooling)"

    v = verdict(GREEN, judged=judged, judge=judge_id, evidence=evidence)
    return v, "judged green"
