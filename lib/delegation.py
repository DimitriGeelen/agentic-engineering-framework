#!/usr/bin/env python3
"""Reviewer-closeable delegation — criterion classifier and corpus surface (T-3445).

Mechanism for D-626 (operator ruling 2026-09-23, verbatim: *"if it is not high
risk, agent can use the reviewer agent which is critical for review and with a
positive outcome close it"*).

The ruling already existed; nothing reached it. Every deterministic Human
criterion in this corpus is written `[REVIEW]`, `[REVIEW]` means "human only",
so the delegation the operator granted classified zero criteria as delegable
(832's measurement over 342 open criteria: REVIEWER-CLOSEABLE 0, OPERATOR-ONLY
212). This module is the missing predicate: it says, per criterion, whether the
agent may take it.

WHAT THIS IS NOT. It does not change what the reviewer checks, and it does not
weaken a carve-out. Six classes stay human — always, with no bypass flag in this
module — and the tie-break is `unclassified` → OPERATOR-ONLY, i.e. **when in
doubt, human**.

REUSE, NOT REBUILD. The vocabularies are imported from the reviewer's own
detectors so there is exactly one definition of each:

  * `_HUMAN_AC_TASTE_RE`      — T-1947 prose vocabulary  → class `taste`
  * `_HUMAN_AC_MECHANICAL_RE` — T-1896/T-1897 grep-able  → class `deterministic`
  * `_HUMAN_AC_STRATEGIC_RE`  — decide/approve/sign-off  → suppresses deterministic
  * `_AGENT_AS_SUBJECT_RE` + `_HUMAN_SUBJECT_RE` + `_AUDIENCE_OPT_OUT_RE`
                              — T-2147 audience axis     → class `agent-self`
  * `RENDER_SURFACE_PATTERNS` — read out of lib/render_surface.sh (T-1766), the
                                single source of truth its own header insists on

The deterministic gate is deliberately the SAME shape as
`static_scan.detect_human_ac_mechanical_signal`: strategic-free title,
taste-free title, an `**Expected:**` clause that exists, is taste-free, and
carries a mechanical signal. A criterion with no Expected clause is not
deterministic — it is `unclassified`, and unclassified is human.
"""

from __future__ import annotations

import functools
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable, Optional

_HERE = Path(__file__).resolve().parent
if str(_HERE.parent) not in sys.path:
    sys.path.insert(0, str(_HERE.parent))

from lib.reviewer.static_scan import (  # noqa: E402
    _AC_LINE_RE,
    _AGENT_AS_SUBJECT_RE,
    _AUDIENCE_OPT_OUT_RE,
    _HUMAN_AC_MECHANICAL_RE,
    _HUMAN_AC_STRATEGIC_RE,
    _HUMAN_AC_TASTE_RE,
    _HUMAN_SUBJECT_RE,
)

RULING = "D-626"

# ── Class taxonomy ───────────────────────────────────────────────────────────
#
# Seven criterion classes named by the task spec, plus `agent-self` (the T-2143
# audience axis, which AC 4's three-way roll-up needs) and `unclassified` (the
# tie-break sink). Every class maps to exactly one delegation class.
#
# 832's predicate uses the same three delegation classes with sub-reasons. Ours
# adds `render-surface` (their corpus has no P-013 gate) and drops `owner-human`
# as a reason — ownership is the thing delegation CHANGES, so using it as a
# reason to refuse delegation would make the verb unable to ever fire.

REVIEWER_CLOSEABLE = "REVIEWER-CLOSEABLE"
AGENT_SELF = "AGENT-SELF"
OPERATOR_ONLY = "OPERATOR-ONLY"

CLASS_TO_DELEGATION = {
    "deterministic": REVIEWER_CLOSEABLE,
    "agent-self": AGENT_SELF,
    "taste": OPERATOR_ONLY,
    "inception-decision": OPERATOR_ONLY,
    "act-in-the-world": OPERATOR_ONLY,
    "tier0-or-bypass": OPERATOR_ONLY,
    "sovereignty-field": OPERATOR_ONLY,
    "render-surface": OPERATOR_ONLY,
    "unclassified": OPERATOR_ONLY,
}

# Only `deterministic` converts. `agent-self` is a ROUTING defect (the criterion
# should never have been a Human criterion at all — T-2143); fixing it is an
# author-time edit, not an act of delegation, so this verb reports it and leaves
# it alone.
CONVERTIBLE_CLASSES = frozenset({"deterministic"})

CARVE_OUTS = (
    "taste",
    "inception-decision",
    "act-in-the-world",
    "tier0-or-bypass",
    "sovereignty-field",
    "render-surface",
)

# ── Carve-out vocabularies ───────────────────────────────────────────────────

# Tier 0 approvals and every logged-bypass mechanism. A criterion that asks the
# operator to approve a Tier 0 action or to wave a gate through is the single
# thing the enforcement tiers exist to keep in human hands.
_TIER0_OR_BYPASS_RE = re.compile(
    r"""(?ix)
    (
        \btier[\s-]?0\b                      |
        \bfw\s+tier0\b                       |
        --force\b                            |
        --skip-[a-z-]+                       |
        \bFW_ALLOW_[A-Z0-9_]+                |
        \bFW_SKIP_[A-Z0-9_]+                 |
        --no-verify\b                        |
        \bforce[- ]push\b                    |
        \bhard\s+reset\b                     |
        \bbypass\s+(the\s+)?gate\b           |
        \bgate\s+bypass\b
    )
    """
)

# Sovereignty fields: the writes whose whole point is that a human made them.
# `fw bvp confirm`, arc close / driver approval / abandon, and any ownership
# change. Delegating one of these would delegate the sovereignty boundary
# itself.
_SOVEREIGNTY_FIELD_RE = re.compile(
    r"""(?ix)
    (
        \bbvp\s+confirm\b                        |
        \bbvp_scores\b                           |
        \barc\s+close\b                          |
        \bclose\s+the\s+arc\b                    |
        \barc\s+approve-driver\b                 |
        \barc\s+abandon\b                        |
        \barc\s+remove-driver\b                  |
        \barc\s+set-scoped-weight\b              |
        \bapprove\s+(the\s+)?(proposed\s+)?driver\b |
        \bscoped[\s-]driver\b                    |
        \bchange\s+(the\s+)?owner(ship)?\b       |
        \bowner:\s*(human|agent)\b               |
        \breassign\s+ownership\b                 |
        \bsovereign(ty)?\b
    )
    """
)

# Inception go/no-go. Task-level `workflow_type: inception` is checked
# separately (see `classify`); this catches the criterion-level phrasing on a
# non-inception task.
_INCEPTION_DECISION_RE = re.compile(
    r"""(?ix)
    (
        \bgo\s*/\s*no-?go\b                  |
        \bno-?go\b                           |
        \bfw\s+inception\s+decide\b          |
        \binception\s+decision\b             |
        \bGO\s+or\s+NO-GO\b                  |
        \brecommendation:\s*(GO|NO-GO|DEFER)\b
    )
    """
)

# Act-in-the-world: an irreversible effect outside this repository. The AC
# Classification Guidance calls this "irreversible external action"; delegating
# it would let a static scan authorise something no scan can undo.
_ACT_IN_THE_WORLD_RE = re.compile(
    r"""(?ix)
    (
        \bpublish(es|ed|ing)?\b              |
        \bdeploy(s|ed|ing|ment)?\b           |
        \brelease\s+(to|the)\b               |
        \btag-and-release\b                  |
        \bship\s+to\s+production\b           |
        \bproduction\b                       |
        \bsend(s|ing)?\s+(an?\s+)?(email|message|notification|dm|post) |
        \bpost(s|ed|ing)?\s+to\s+           |
        \bgit\s+push\b                       |
        \bpush\s+to\s+(origin|master|remote|production) |
        \bmerge\s+to\s+master\b              |
        \bpay(ment|s)?\b                     |
        \binvoice\b                          |
        \bdelete\s+(the\s+)?remote\b         |
        \bdrop\s+table\b                     |
        \bexternal\s+service\b               |
        \bcustomer(s|-facing)?\b
    )
    """
)

# `[RUBBER-STAMP]` / `[REVIEWER]` prefixes: the author has already declared the
# criterion mechanical. CLAUDE.md's own conversion rules say both SHOULD be
# Agent criteria; a Human criterion carrying either prefix is a conversion that
# never happened.
_PREFIX_RE = re.compile(r"^\[(REVIEW|REVIEWER|RUBBER-STAMP)\]", re.IGNORECASE)
_EXPECTED_RE = re.compile(
    r"\*\*Expected:?\*\*\s*(.*?)(?=\n\s*\*\*(?:If\s+not|Steps|Why|Origin)|\Z)",
    re.DOTALL | re.IGNORECASE,
)


# ── Render surface (single source of truth: lib/render_surface.sh) ───────────


@functools.lru_cache(maxsize=8)
def _render_surface_patterns_cached(root: str) -> tuple[str, ...]:
    src = Path(root) / "lib" / "render_surface.sh"
    try:
        text = src.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ()
    m = re.search(r"^RENDER_SURFACE_PATTERNS=\((.*?)^\)", text, re.MULTILINE | re.DOTALL)
    if not m:
        return ()
    return tuple(re.findall(r'"([^"]+)"', m.group(1)))


def render_surface_patterns(framework_root: Optional[Path] = None) -> list[str]:
    """Read RENDER_SURFACE_PATTERNS out of lib/render_surface.sh.

    Parsed rather than copied on purpose. That file's header says drift between
    consumers was the T-1764 root cause and names itself the single source of
    truth; a second hand-maintained copy here would be the same bug with a new
    file name. Returns [] when the file is unreadable — the caller then simply
    never classifies anything `render-surface`, which is a missed carve-out, so
    `classify` also accepts an explicit `render_surface` flag from the
    authoritative bash predicate.
    """
    root = Path(framework_root) if framework_root else _HERE.parent
    return list(_render_surface_patterns_cached(str(root)))


_PATH_TOKEN_RE = re.compile(
    r"(?:^|[\s`'\"(])((?:web|lib|bin|agents|tests|tools|prompts|policy|deploy|docs)"
    r"/[A-Za-z0-9_/.-]+\.(?:html|j2|css|js|py|md|yaml|yml|sh|bats|json|toml))"
)


def _fnmatch_any(path: str, patterns: Iterable[str]) -> bool:
    import fnmatch

    return any(fnmatch.fnmatch(path, p) for p in patterns)


def task_touches_render_surface_cheap(
    text: str, framework_root: Optional[Path] = None, meta: Optional[dict] = None
) -> bool:
    """Components + body path scan — the git-free half of the T-1766 predicate.

    `lib/render_surface.sh:task_touches_render_surface` runs `git log --all
    --grep` per task, which is right for ONE task at close time and far too slow
    for a corpus sweep (the surface report walks every active task on every
    `fw audit` and `fw doctor`). This is its documented FALLBACK leg, applied
    unconditionally. It over-reports (a task that only *discusses* web/ counts —
    L-435's false-positive class) and over-reporting pushes criteria toward
    OPERATOR-ONLY, which is the safe direction for an advisory count.

    `fw task delegate` does NOT use this: it calls the authoritative bash
    predicate, so the decision that actually converts a criterion is the same
    one the close gate will make.
    """
    patterns = render_surface_patterns(framework_root)
    if not patterns:
        return False
    fm = re.match(r"^---\s*\n(.*?)\n---\s*\n", text, re.DOTALL)
    candidates: list[str] = []
    if meta is None:
        meta = frontmatter(text)
    comps = meta.get("components") or []
    if isinstance(comps, list):
        candidates += [str(c).strip() for c in comps if c]
    body = text[fm.end():] if fm else text
    candidates += _PATH_TOKEN_RE.findall(body)
    return any(_fnmatch_any(p, patterns) for p in candidates)


# ── Criterion parsing ────────────────────────────────────────────────────────


@dataclass
class Criterion:
    """One acceptance criterion, with the raw lines needed to move it verbatim."""

    index: int                      # 1-based, per subhead — matches the P-010 counter
    subhead: str                    # "Agent" / "Human" / "" when un-split
    title: str                      # checkbox line body, prefix included
    ticked: bool
    start: int                      # 0-based line index of the checkbox line
    end: int                        # 0-based line index AFTER the last body line
    lines: list[str] = field(default_factory=list)   # checkbox line + continuations

    @property
    def prefix(self) -> str:
        m = _PREFIX_RE.match(self.title.strip())
        return m.group(1).upper() if m else ""

    @property
    def body_text(self) -> str:
        return "\n".join(self.lines)

    @property
    def expected(self) -> str:
        m = _EXPECTED_RE.search("\n".join(self.lines[1:]))
        return m.group(1).strip() if m else ""


def _comment_mask(lines: list[str]) -> list[bool]:
    """Line indices falling inside an HTML comment.

    The shipped template's whole `### Human` block is a `<!-- … -->` block
    carrying worked examples that LOOK like criteria. Counting them is OBS-047
    (9+ closed tasks carry that false positive); a delegation verb that
    converted them would edit documentation into live criteria.
    """
    text = "\n".join(lines)
    mask = [False] * len(lines)
    for m in re.finditer(r"<!--.*?-->", text, re.DOTALL):
        first = text.count("\n", 0, m.start())
        last = text.count("\n", 0, m.end())
        for i in range(first, min(last + 1, len(lines))):
            mask[i] = True
    return mask


_AC_HEADING_RE = re.compile(r"^## Acceptance Criteria[ \t]*$")
_L2_RE = re.compile(r"^## ")
_SUBHEAD_RE = re.compile(r"^#{3,}\s+(\S.*?)\s*$")


def ac_section_bounds(lines: list[str]) -> tuple[int, int]:
    """(start, end) line indices of the `## Acceptance Criteria` body.

    FIRST-WINS and anchored, matching `lib/section-extract.sh:extract_ac_section`
    — same policy, same reason (the heading is written once, near the top).
    Returns (-1, -1) when absent.
    """
    start = -1
    for i, line in enumerate(lines):
        if _AC_HEADING_RE.match(line):
            start = i + 1
            break
    if start < 0:
        return -1, -1
    for j in range(start, len(lines)):
        if _L2_RE.match(lines[j]):
            return start, j
    return start, len(lines)


def parse_criteria(text: str) -> list[Criterion]:
    """Every criterion under `## Acceptance Criteria`, with its full body.

    Indices restart at each subhead — the same counter `static_scan` and the
    P-010 gate use, so a reported AC#N here is the AC#N the reviewer will tick.
    """
    lines = text.split("\n")
    start, end = ac_section_bounds(lines)
    if start < 0:
        return []
    mask = _comment_mask(lines)

    out: list[Criterion] = []
    subhead = ""
    counter = 0
    cur: Optional[Criterion] = None

    def close(at: int) -> None:
        nonlocal cur
        if cur is None:
            return
        stop = at
        while stop > cur.start + 1 and not lines[stop - 1].strip():
            stop -= 1
        cur.end = stop
        cur.lines = lines[cur.start:stop]
        out.append(cur)
        cur = None

    for i in range(start, end):
        if mask[i]:
            continue
        line = lines[i]
        sub = _SUBHEAD_RE.match(line.strip())
        if sub:
            close(i)
            subhead = sub.group(1).lstrip("# ").strip()
            counter = 0
            continue
        m = _AC_LINE_RE.match(line)
        if m:
            close(i)
            counter += 1
            cur = Criterion(
                index=counter,
                subhead=subhead,
                title=m.group("body"),
                ticked=m.group("state").lower() == "x",
                start=i,
                end=i + 1,
            )
    close(end)
    return out


def human_criteria(text: str) -> list[Criterion]:
    """Criteria under a `### Human` subhead (suffix-tolerant, per T-3288)."""
    return [c for c in parse_criteria(text) if c.subhead.lower().startswith("human")]


# ── Classification ───────────────────────────────────────────────────────────


@dataclass
class Classification:
    cls: str
    delegation_class: str
    reason: str

    @property
    def convertible(self) -> bool:
        return self.cls in CONVERTIBLE_CLASSES


def _m(rx: re.Pattern, s: str) -> str:
    m = rx.search(s)
    return m.group(0).strip() if m else ""


def classify(
    criterion: Criterion,
    *,
    workflow_type: str = "",
    render_surface: bool = False,
) -> Classification:
    """Put one criterion in exactly one class.

    PRECEDENCE — every carve-out outranks `deterministic`, so a criterion that
    is both grep-able and act-in-the-world stays human. The order within the
    carve-outs is by severity of getting it wrong: an approval you cannot undo
    outranks prose you can re-word.

      1. render-surface     (task-level; no test settles layout — T-1766)
      2. tier0-or-bypass    (the tier the human owns by definition)
      3. sovereignty-field  (the write whose point is that a human made it)
      4. inception-decision (go/no-go is the operator's, always)
      5. act-in-the-world   (irreversible, outside this repo)
      6. taste              (T-1947 vocabulary — the reviewer cannot read prose)
      7. deterministic      (same five gates as the reviewer's own detector)
      8. agent-self         (T-2143: wrong audience, not a delegation question)
      9. unclassified       → OPERATOR-ONLY. The tie-break. When in doubt, human.
    """
    title = criterion.title
    body = criterion.body_text

    if render_surface:
        return Classification(
            "render-surface", OPERATOR_ONLY,
            "task touches a render surface (T-1766): layout is settled by eyes, not tests",
        )

    hit = _m(_TIER0_OR_BYPASS_RE, body)
    if hit:
        return Classification("tier0-or-bypass", OPERATOR_ONLY,
                              f"tier-0 / bypass approval ({hit!r})")

    hit = _m(_SOVEREIGNTY_FIELD_RE, body)
    if hit:
        return Classification("sovereignty-field", OPERATOR_ONLY,
                              f"sovereignty field ({hit!r})")

    if str(workflow_type).strip().lower() == "inception":
        return Classification("inception-decision", OPERATOR_ONLY,
                              "task is workflow_type: inception — go/no-go is the operator's")
    hit = _m(_INCEPTION_DECISION_RE, body)
    if hit:
        return Classification("inception-decision", OPERATOR_ONLY,
                              f"asks for a go/no-go decision ({hit!r})")

    hit = _m(_ACT_IN_THE_WORLD_RE, body)
    if hit:
        return Classification("act-in-the-world", OPERATOR_ONLY,
                              f"irreversible external action ({hit!r})")

    # Taste before deterministic, per T-1947: prose vocabulary in the criterion
    # wins over incidental mechanical vocabulary in its Expected clause. This is
    # static_scan's Gate 2b, applied as a class rather than as a suppression.
    hit = _m(_HUMAN_AC_TASTE_RE, title)
    if hit:
        return Classification("taste", OPERATOR_ONLY,
                              f"taste vocabulary in the criterion ({hit!r})")

    det = _deterministic_reason(criterion)
    if det:
        return Classification("deterministic", REVIEWER_CLOSEABLE, det)

    if _is_agent_self(criterion):
        return Classification("agent-self", AGENT_SELF,
                              "subject is agent experience (T-2143) — belongs under ### Agent, "
                              "not delegated from ### Human")

    return Classification("unclassified", OPERATOR_ONLY,
                          "no deterministic signal — tie-break is human")


def _deterministic_reason(criterion: Criterion) -> str:
    """Non-empty reason when the criterion is a shell-settleable check.

    Two routes in:
      (a) the author already declared it mechanical with `[RUBBER-STAMP]` or
          `[REVIEWER]` — CLAUDE.md says both SHOULD be Agent criteria, so a
          Human one is a conversion that never happened; or
      (b) the reviewer's own five-gate mechanical-signal test passes.
    """
    title = criterion.title.strip()
    if _HUMAN_AC_STRATEGIC_RE.search(title):
        return ""
    prefix = criterion.prefix
    if prefix in ("RUBBER-STAMP", "REVIEWER"):
        return f"author declared it mechanical ([{prefix}])"
    expected = criterion.expected
    if not expected:
        return ""
    if _HUMAN_AC_TASTE_RE.search(expected):
        return ""
    mech = _HUMAN_AC_MECHANICAL_RE.search(expected)
    if not mech:
        return ""
    return f"Expected clause is a shell check ({mech.group(0).strip()!r})"


def _is_agent_self(criterion: Criterion) -> bool:
    """T-2147's audience test, reused as a class rather than as a finding."""
    body = criterion.body_text
    if _AUDIENCE_OPT_OUT_RE.search(body):
        return False
    if not _AGENT_AS_SUBJECT_RE.search(body):
        return False
    return not _HUMAN_SUBJECT_RE.search(criterion.expected or body)


# ── Task-level helpers ───────────────────────────────────────────────────────


def frontmatter(text: str) -> dict:
    """Parse the YAML frontmatter, falling back to a key regex on malformed YAML.

    Uses libyaml's C loader when it is present. That is not micro-optimisation:
    the surface report walks every active task on every `fw audit` and every
    `fw doctor`, and pure-python yaml was 91% of an 11s scan over 473 tasks
    (measured with cProfile, T-3445). A check the operator waits 11 seconds for
    is a check that gets skipped.
    """
    m = re.match(r"^---\s*\n(.*?)\n---\s*\n", text, re.DOTALL)
    if not m:
        return {}
    try:
        import yaml

        try:
            loader = yaml.CSafeLoader
        except AttributeError:
            loader = yaml.SafeLoader
        return yaml.load(m.group(1), Loader=loader) or {}
    except Exception:
        out = {}
        for key in ("id", "status", "workflow_type", "owner", "horizon"):
            km = re.search(rf"^{key}:\s*(.+)$", m.group(1), re.MULTILINE)
            if km:
                out[key] = km.group(1).strip().strip("\"'")
        return out


@dataclass
class TaskClassification:
    task_id: str
    path: Path
    workflow_type: str
    owner: str
    render_surface: bool
    rows: list[tuple[Criterion, Classification]]

    def by_delegation(self) -> dict[str, int]:
        counts = {REVIEWER_CLOSEABLE: 0, AGENT_SELF: 0, OPERATOR_ONLY: 0}
        for _, cl in self.rows:
            counts[cl.delegation_class] += 1
        return counts


def classify_task(
    path: Path,
    *,
    text: Optional[str] = None,
    open_only: bool = True,
    render_surface: Optional[bool] = None,
    framework_root: Optional[Path] = None,
) -> TaskClassification:
    """Classify a task file's Human criteria.

    `open_only` keeps the report to criteria that are still UNTICKED — a ticked
    criterion has already been answered, and counting answered ones would make
    the surface report measure history rather than delegable work.
    """
    if text is None:
        text = Path(path).read_text(encoding="utf-8", errors="replace")
    meta = frontmatter(text)
    rs = (
        render_surface
        if render_surface is not None
        else task_touches_render_surface_cheap(text, framework_root, meta)
    )
    wt = str(meta.get("workflow_type") or "")
    rows = []
    for c in human_criteria(text):
        if open_only and c.ticked:
            continue
        rows.append((c, classify(c, workflow_type=wt, render_surface=rs)))
    return TaskClassification(
        task_id=str(meta.get("id") or Path(path).name.split("-")[0]),
        path=Path(path),
        workflow_type=wt,
        owner=str(meta.get("owner") or ""),
        render_surface=rs,
        rows=rows,
    )


# ── Corpus surface (AC 4 — 832's ask (a)) ────────────────────────────────────


def surface_scan(project_root: Path, framework_root: Optional[Path] = None) -> dict:
    """Count open Human criteria across active tasks, by class.

    Active tasks only. A completed task's criteria are settled; including them
    would report a backlog that no longer exists and would grow monotonically
    forever, which is the shape of a number nobody reads.
    """
    tasks_dir = Path(project_root) / ".tasks" / "active"
    by_class: dict[str, int] = {k: 0 for k in CLASS_TO_DELEGATION}
    by_delegation = {REVIEWER_CLOSEABLE: 0, AGENT_SELF: 0, OPERATOR_ONLY: 0}
    tasks_with_open = 0
    total_tasks = 0
    delegable_tasks: list[str] = []

    if tasks_dir.is_dir():
        for f in sorted(tasks_dir.glob("T-*.md")):
            total_tasks += 1
            try:
                tc = classify_task(f, framework_root=framework_root)
            except OSError:
                continue
            if not tc.rows:
                continue
            tasks_with_open += 1
            for _, cl in tc.rows:
                by_class[cl.cls] = by_class.get(cl.cls, 0) + 1
                by_delegation[cl.delegation_class] += 1
            if any(cl.convertible for _, cl in tc.rows):
                delegable_tasks.append(tc.task_id)

    return {
        "tasks_scanned": total_tasks,
        "tasks_with_open_human_criteria": tasks_with_open,
        "open_criteria": sum(by_delegation.values()),
        "by_delegation": by_delegation,
        "by_class": by_class,
        "delegable_tasks": delegable_tasks,
    }


def surface_verdict(report: dict, threshold: int) -> tuple[str, str]:
    """(level, message) for the audit/doctor line.

    WARN when REVIEWER-CLOSEABLE is 0 while OPERATOR-ONLY exceeds the threshold.
    That conjunction — and not either half alone — is the signal 832 asked for:
    a corpus with no delegable criteria is unremarkable if it has few criteria,
    and a corpus with many operator-only criteria is unremarkable if some of
    them are being delegated. Both at once means the ruling reaches nothing.
    """
    d = report["by_delegation"]
    rc, oo = d[REVIEWER_CLOSEABLE], d[OPERATOR_ONLY]
    base = (
        f"reviewer-closeable {rc}, agent-self {d[AGENT_SELF]}, operator-only {oo} "
        f"(open Human criteria across {report['tasks_with_open_human_criteria']} active task(s))"
    )
    if rc == 0 and oo > threshold:
        return "WARN", (
            f"Delegation surface: {base} — the {RULING} delegation reaches nothing"
        )
    return "OK", f"Delegation surface: {base}"


if __name__ == "__main__":  # pragma: no cover — smoke path
    print(json.dumps(surface_scan(Path(sys.argv[1] if len(sys.argv) > 1 else ".")), indent=2))
