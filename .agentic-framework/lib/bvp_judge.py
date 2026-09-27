#!/usr/bin/env python3
"""lib/bvp_judge.py — judges a PROPOSED BVP score (T-3526, D-662 slice 2 of 3).

T-3524 GO. Producer-not-judge is restored here by separating PARTIES rather than
by putting the operator back in the approval path: `agents/termlink/bvp-estimator/
estimator.py` PROPOSES `bvp_scores_proposed:`; this module JUDGES that proposal.
Neither party writes `bvp_scores:` — that stays the human's door via `fw bvp confirm`
(T-1924), and the T-3523 sticky guard already protects a confirmed score from either
side re-writing it.

── IMPORTS THE CONTRACT, DEFINES NO SECOND ONE ──────────────────────────────────

This module imports `lib.judge_verdict` for every piece of verdict vocabulary
(green/amber/red/unknown, guidance-required, `may_proceed`, `reviewable`). It
defines no local state, no local `reviewable()`, no local guidance rule. See
`lib/judge_verdict.py`'s own docstring for why: arc membership in this repo
reached FIVE disagreeing implementations of one predicate before a full day went
into consolidating them into one file. Two judge agents (this one and T-3527's
arc-driver judge) each carrying their own idea of what amber means is that defect
pre-ordered.

── WHAT IT JUDGES AGAINST (operator ruling, D-662, IW-3) ────────────────────────

1. PRESENCE    — are acceptance/quality criteria on the task AT ALL?
2. SUFFICIENCY — are they substantive enough to justify the score claimed?
3. GOAL HIERARCHY — map the work to its objective at the right level: the task's
   own goal, the arc's, or the project's.

The operator's answer on (3) is what makes this buildable without waiting on
T-3410 (the estimator's own detector-quality follow-up): the yardstick is **the
goal hierarchy, which is written down** —

    - task level:    frontmatter `description:`, or the body `## Context` section
    - arc level:      the task's `arc_id:` resolved to `.context/arcs/<id>.yaml`'s
                      `description:` / `headline_mechanic:`
    - project level:  `policy/value-drivers.yaml`'s `protected_drivers:` (D1-D4),
                      which always exists as the last resort — the project's
                      objective is never unwritten, only sometimes the ONLY level
                      a task can be checked against, which is itself information

— not a rebuild of the estimator's own keyword detectors, which report no-signal
on 83% of 3,350 tasks (T-3408) and therefore cannot serve as a yardstick. This
module does not touch those detectors. T-3410 remains the estimator's own
follow-up; out of scope here, confirmed untouched by this task's diff.

── POPULATION: OPEN TASKS ONLY (D-662, IW-4) ────────────────────────────────────

`judge_task()` calls `judge_verdict.reviewable()` before doing anything else.
Closed work is never rescored — a closed task's score is the record of what was
decided at the time.

── READ-ONLY ────────────────────────────────────────────────────────────────────

This module never writes to a task file. It reads `bvp_scores_proposed:` (the
proposer's door) and never touches `bvp_scores:` (the human's door via `fw bvp
confirm`). There is no write path here to gate.
"""

from __future__ import annotations

import os
import re
from pathlib import Path

import yaml

from lib.judge_verdict import AMBER, GREEN, RED, UNKNOWN, reviewable, verdict

JUDGE_ID = "bvp-score-judge-v1"

PROJECT_ROOT = Path(os.environ.get("PROJECT_ROOT") or
                    os.environ.get("FRAMEWORK_ROOT") or os.getcwd())
POLICY_PATH = PROJECT_ROOT / "policy" / "value-drivers.yaml"
ARCS_DIR = PROJECT_ROOT / ".context" / "arcs"

#: Sufficiency floor: an AC item shorter than this (after stripping prefix
#: markers like [REVIEW]/[REVIEWER]/bold markers) reads as placeholder rather
#: than substantive. Chosen from the template's own shortest real examples
#: ("Tests pass", "Docs updated") sitting just above this floor.
MIN_SUBSTANTIVE_CHARS = 15

#: A driver claimed at or above this level ("framework-level, cross-cutting" per
#: policy/bvp-scoring-rubric.md) needs more than one substantive AC, and needs a
#: task- or arc-level objective (not only the project fallback) to check it
#: against — see _check_sufficiency / _check_goal_hierarchy.
HIGH_CLAIM_FLOOR = 4

_FM_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n?", re.S)
_SECTION_RE_TMPL = r"^## {name}\s*\n(.*?)(?=^## |\Z)"
_HTML_COMMENT_RE = re.compile(r"<!--.*?-->", re.S)
_CHECKBOX_RE = re.compile(r"^\s*-\s*\[[ xX]\]\s*(.+)$", re.M)
_PREFIX_MARKER_RE = re.compile(r"^\[[A-Z][A-Z-]*\]\s*")
_RATIONALE_DRIVER_RE = re.compile(r"([A-Za-z0-9_-]+)\s*=\s*(-?\d+)\s*\(([^)]*)\)")


# ───────────────────────── generic parsing (self-contained on purpose) ─────────
#
# These are plain text-extraction helpers, not verdict vocabulary — writing them
# locally does not reopen the "second implementation" problem the module-level
# docstring warns against. They exist here rather than importing
# lib.reviewer.static_scan's equivalents to avoid coupling this judge's import
# graph to the reviewer's (a much larger module with its own concerns).


def parse_task_file(path: Path) -> tuple[dict, str]:
    """Return (frontmatter_dict, body_str). Both empty/`{}` on parse failure."""
    text = path.read_text()
    m = _FM_RE.match(text)
    if not m:
        return {}, text
    try:
        fm = yaml.safe_load(m.group(1)) or {}
    except yaml.YAMLError:
        fm = {}
    return fm, text[m.end():]


def extract_section(body: str, name: str) -> str:
    """Extract `## {name}` section content (until next `## ` or EOF). "" if absent."""
    pattern = re.compile(_SECTION_RE_TMPL.format(name=re.escape(name)), re.M | re.S)
    m = pattern.search(body)
    return m.group(1) if m else ""


def _strip_html_comments(text: str) -> str:
    return _HTML_COMMENT_RE.sub("", text)


def _extract_ac_items(ac_section: str) -> list[str]:
    """Real (non-template) checkbox items from an Acceptance Criteria section.

    Template example blocks live inside HTML comments in `.tasks/templates/
    default.md`-derived tasks, so stripping comments first is what keeps an
    untouched template from reading as "criteria present."
    """
    cleaned = _strip_html_comments(ac_section)
    return [m.group(1).strip() for m in _CHECKBOX_RE.finditer(cleaned) if m.group(1).strip()]


def _is_substantive(item: str) -> bool:
    stripped = _PREFIX_MARKER_RE.sub("", item).strip("*_ \t")
    return len(stripped) >= MIN_SUBSTANTIVE_CHARS


def _parse_rationale(rationale: str) -> dict[str, tuple[int, str]]:
    """`"D1=4 (body:structural-gate); F3=0 (no-signal)"` -> {"D1": (4, "body:..."), ...}."""
    out: dict[str, tuple[int, str]] = {}
    for m in _RATIONALE_DRIVER_RE.finditer(rationale or ""):
        driver, score_s, ev = m.groups()
        try:
            out[driver] = (int(score_s), ev.strip())
        except ValueError:
            continue
    return out


def _latest_proposal(fm: dict) -> dict | None:
    entries = fm.get("bvp_scores_proposed")
    if not entries or not isinstance(entries, list):
        return None
    latest = entries[-1]
    return latest if isinstance(latest, dict) else None


def _max_claimed_score(scores: dict) -> int:
    vals = []
    for v in (scores or {}).values():
        try:
            vals.append(int(v))
        except (TypeError, ValueError):
            continue
    return max(vals, default=0)


# ───────────────────────── goal hierarchy resolution ───────────────────────────


_PROJECT_DIRECTIVES_CACHE: dict[str, str] | None = None


def _project_directives() -> dict[str, str]:
    """{driver_id: note} for D1-D4 from policy/value-drivers.yaml.

    Cached module-level (mirrors the estimator's rubric-SHA cache pattern) —
    the project's own objective does not change within a process lifetime.
    """
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


def _resolve_arc(fm: dict) -> dict | None:
    """Resolve `arc_id:` to its parsed arc YAML. Slug form first, then the
    `arc-NNN` dual-form scan (T-1849), mirroring the estimator's
    `_resolve_arc_data`. None on any missing/error path."""
    arc_id = fm.get("arc_id")
    if not arc_id or not isinstance(arc_id, str):
        return None
    direct = ARCS_DIR / f"{arc_id}.yaml"
    if direct.is_file():
        try:
            return yaml.safe_load(direct.read_text()) or {}
        except yaml.YAMLError:
            return None
    if ARCS_DIR.is_dir():
        for p in sorted(ARCS_DIR.glob("*.yaml")):
            try:
                data = yaml.safe_load(p.read_text()) or {}
            except yaml.YAMLError:
                continue
            if data.get("id") == arc_id or data.get("slug") == arc_id:
                return data
    return None


def _task_goal(fm: dict, body: str) -> str:
    desc = (fm.get("description") or "").strip()
    if desc:
        return desc
    return _strip_html_comments(extract_section(body, "Context")).strip()


def resolve_goal_hierarchy(fm: dict, body: str) -> tuple[str, str, list[str]]:
    """(level, goal_text, notes). level is one of "task"/"arc"/"project"/"" (unresolved).

    Walks task -> arc -> project, stopping at the first level with written text —
    exactly the ladder D-662 names, checked in the order a reader would check it.
    """
    task_goal = _task_goal(fm, body)
    if task_goal:
        src = "description:" if (fm.get("description") or "").strip() else "## Context"
        return "task", task_goal, [f"task-level objective from {src}"]

    arc = _resolve_arc(fm)
    if arc:
        arc_goal = (arc.get("description") or "").strip() or (arc.get("headline_mechanic") or "").strip()
        if arc_goal:
            return "arc", arc_goal, [f"arc-level objective from arc_id={fm.get('arc_id')!r}"]

    directives = _project_directives()
    if directives:
        combined = "; ".join(f"{k}: {v}" for k, v in sorted(directives.items()))
        return "project", combined, ["no task- or arc-level objective; fell back to the "
                                      "project's own D1-D4 (policy/value-drivers.yaml)"]

    return "", "", ["no readable objective at task, arc, or project level"]


# ───────────────────────── the three D-662 checks ───────────────────────────────


def check_presence(body: str) -> tuple[bool, list[str], str]:
    """(present, items, reason). PRESENCE — are criteria on the task at all?"""
    items = _extract_ac_items(extract_section(body, "Acceptance Criteria"))
    if not items:
        return False, [], "no Acceptance Criteria checkboxes found in the task body"
    return True, items, f"{len(items)} acceptance criteria item(s) found"


def check_sufficiency(items: list[str], scores: dict) -> tuple[bool, list[str]]:
    """(sufficient, evidence). SUFFICIENCY — good enough for the score claimed?

    A higher claimed value demands more substance: `HIGH_CLAIM_FLOOR`+ needs 2
    substantive AC items, anything scored at all needs at least 1. This is
    D-662's "good enough to justify the score claimed" made checkable without a
    keyword detector — it counts what is actually written, not what it says.
    """
    substantive = [i for i in items if _is_substantive(i)]
    max_score = _max_claimed_score(scores)
    evidence = [f"{len(substantive)}/{len(items)} AC item(s) substantive "
                f"(>= {MIN_SUBSTANTIVE_CHARS} chars after stripping prefix markers)"]
    if not substantive:
        return False, evidence + ["every AC item is placeholder-length; none can justify any score"]
    required = 2 if max_score >= HIGH_CLAIM_FLOOR else 1
    if len(substantive) < required:
        return False, evidence + [
            f"max claimed driver score is {max_score}, which requires >= {required} "
            f"substantive AC item(s); found {len(substantive)}"]
    return True, evidence


def check_goal_hierarchy(fm: dict, body: str, proposal: dict) -> tuple[str, str, list[str]]:
    """(state, reason, evidence). state in "pass"/"fail"/"unknown".

    GOAL HIERARCHY — resolves the written-down objective (task -> arc ->
    project) and checks the proposal against it two ways:

    1. Self-consistency: a driver scored > 0 whose OWN rationale says
       "no-signal" contradicts itself — the proposer's own evidence admits it
       found nothing, yet claims value anyway. This is the case D-662 names
       explicitly: "a score claiming high value for work serving no stated
       objective is the case that must be caught."
    2. Level match: a HIGH_CLAIM_FLOOR+ claim resting only on the project-level
       fallback (no task description/Context, no resolvable arc) has nothing
       more specific than "the project has objectives" behind a framework-level
       claim — the goal hierarchy exists precisely so a claim that large can be
       checked against something narrower than the whole project.
    """
    level, _, notes = resolve_goal_hierarchy(fm, body)
    if not level:
        return "unknown", "no readable objective at task, arc, or project level", notes

    scores = proposal.get("scores") or {}
    rationale_map = _parse_rationale(proposal.get("rationale", ""))
    contradictions = []
    for driver, raw_score in scores.items():
        try:
            score_i = int(raw_score)
        except (TypeError, ValueError):
            continue
        if score_i <= 0:
            continue
        _, ev = rationale_map.get(driver, (None, ""))
        if "no-signal" in ev.lower():
            contradictions.append(f"{driver}={score_i} but its own rationale reports 'no-signal'")

    evidence = [f"objective resolved at {level} level"] + notes
    if contradictions:
        return "fail", "; ".join(contradictions), evidence + contradictions

    max_score = _max_claimed_score(scores)
    if level == "project" and max_score >= HIGH_CLAIM_FLOOR:
        reason = (f"claimed max score {max_score} rests only on the project-level fallback "
                  "(no task description/Context and no resolvable arc) — a framework-level "
                  "claim needs a task- or arc-level objective to check it against")
        return "fail", reason, evidence

    return "pass", f"scores are consistent with their own evidence at {level} level", evidence


# ───────────────────────── the combiner ─────────────────────────────────────────


def judge_task(task_path: Path, *, judge_id: str = JUDGE_ID) -> tuple[dict | None, str]:
    """Judge the latest `bvp_scores_proposed:` entry on one task.

    Returns (verdict_dict, reason). `verdict_dict` is None when there is
    nothing to judge — closed task (D-662 IW-4, via `reviewable()`) or no
    proposed score at all — and `reason` says why, so a caller can report a
    skip rather than silently doing nothing (same denominator discipline as
    `judge_verdict.reviewable()` itself).

    Never writes anything. Never touches `bvp_scores:`.
    """
    try:
        fm, body = parse_task_file(task_path)
    except OSError as e:
        return verdict(UNKNOWN, guidance=f"could not read {task_path}: {e}",
                        judged=task_path.stem, judge=judge_id), "read error"

    ok, reason = reviewable(fm)
    if not ok:
        return None, reason

    proposal = _latest_proposal(fm)
    if proposal is None:
        return None, "no bvp_scores_proposed: entry to judge"

    task_id = fm.get("id") or task_path.stem
    scores = proposal.get("scores") or {}

    present, items, presence_reason = check_presence(body)
    if not present:
        v = verdict(
            RED,
            guidance=(f"{task_id} has no acceptance/quality criteria at all; a proposed "
                      f"score of {scores} cannot be justified with nothing written down — "
                      "add Acceptance Criteria before this can be judged, or the score "
                      "should be 0 on every driver."),
            judged=task_id, judge=judge_id, evidence=[presence_reason],
        )
        return v, "presence check failed"

    sufficient, suff_evidence = check_sufficiency(items, scores)
    if not sufficient:
        v = verdict(
            AMBER,
            guidance=(f"{task_id}'s acceptance criteria are too thin to justify the "
                      f"claimed score {scores} — write substantive, specific criteria "
                      "(not placeholder text) or lower the score to match what is "
                      "actually written down."),
            judged=task_id, judge=judge_id, evidence=suff_evidence,
        )
        return v, "sufficiency check failed"

    gh_state, gh_reason, gh_evidence = check_goal_hierarchy(fm, body, proposal)
    if gh_state == "unknown":
        v = verdict(
            UNKNOWN,
            guidance=(f"cannot judge {task_id}'s score against the goal hierarchy: "
                      f"{gh_reason}. Add a description:, a `## Context` goal statement, "
                      "or an `arc_id:` that resolves — the judge needs a written "
                      "objective at some level to check the score against."),
            judged=task_id, judge=judge_id, evidence=gh_evidence,
        )
        return v, "goal hierarchy unresolved"
    if gh_state == "fail":
        v = verdict(
            RED,
            guidance=(f"{task_id}'s proposed score does not hold up against the goal "
                      f"hierarchy: {gh_reason}. Lower the contradicted driver(s) or add "
                      "the objective/evidence the score would need to stand."),
            judged=task_id, judge=judge_id, evidence=gh_evidence,
        )
        return v, "goal hierarchy check failed"

    v = verdict(
        GREEN, guidance="", judged=task_id, judge=judge_id,
        evidence=[presence_reason] + suff_evidence + gh_evidence,
    )
    return v, "judged green"
