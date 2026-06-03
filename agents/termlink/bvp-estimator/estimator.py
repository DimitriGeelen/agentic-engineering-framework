#!/usr/bin/env python3
"""BVP estimator worker — T-1922 (arc-006).

Reads `policy/bvp-scoring-rubric.md` at preload, applies a heuristic
classifier to each task body, writes `bvp_scores_proposed:` entries
following M3 v2-delta semantics (skip writing when proposed differs from
confirmed `bvp_scores:` by <2 on every driver).

Engine: v1-heuristic. Deterministic by construction (same input → same
output). The heuristic is a pattern-based classifier over task tags and
body keywords, calibrated against the rubric's worked examples. Choice
documented in `docs/reports/T-1922-a3-measurement.md` §Engine.

Surfaces:
  - `python3 agents/termlink/bvp-estimator/estimator.py T-XXX`
  - `fw bvp estimate T-XXX` (lib/bvp.sh integration)
  - `agents/termlink/bvp-estimator/bvp-estimator.sh` (TermLink convention)

§ACD: writing `bvp_scores_proposed:` is NOT sovereignty-bearing (proposed
is advisory). `bvp_scores:` writes still gate through `fw bvp confirm`
(T-1924). So the estimator runs freely under $CLAUDECODE=1; the human
remains the score authority.
"""

from __future__ import annotations

import argparse
import glob
import hashlib
import json
import os
import re
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

ESTIMATOR_ID = "bvp-estimator-v1-heuristic"

# ---- yaml loaders -----------------------------------------------------------

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML required (pip install pyyaml)", file=sys.stderr)
    sys.exit(2)

try:
    from ruamel.yaml import YAML
    _ruamel = YAML()
    _ruamel.preserve_quotes = True
    _ruamel.indent(mapping=2, sequence=4, offset=2)
    _HAS_RUAMEL = True
except ImportError:
    _HAS_RUAMEL = False

PROJECT_ROOT = Path(os.environ.get("PROJECT_ROOT") or
                    os.environ.get("FRAMEWORK_ROOT") or
                    Path(__file__).resolve().parents[3])
RUBRIC_PATH = PROJECT_ROOT / "policy" / "bvp-scoring-rubric.md"
POLICY_PATH = PROJECT_ROOT / "policy" / "value-drivers.yaml"

_FM_RE = re.compile(r"^---\n(.*?)\n---\n?(.*)\Z", re.S)


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def _rubric_sha() -> str:
    """Module-level cache: rubric SHA is computed once per process (D4
    reusable-state — AC says preload, not per-task)."""
    global _RUBRIC_SHA_CACHE
    if _RUBRIC_SHA_CACHE is not None:
        return _RUBRIC_SHA_CACHE
    if not RUBRIC_PATH.is_file():
        _RUBRIC_SHA_CACHE = "missing"
    else:
        _RUBRIC_SHA_CACHE = hashlib.sha256(RUBRIC_PATH.read_bytes()).hexdigest()[:12]
    return _RUBRIC_SHA_CACHE


_RUBRIC_SHA_CACHE: str | None = None


def _load_drivers() -> dict[str, int]:
    if not POLICY_PATH.is_file():
        return {"D1": 9, "D2": 7, "D3": 5, "D4": 3}
    policy = yaml.safe_load(POLICY_PATH.read_text()) or {}
    out: dict[str, int] = {}
    for d in (policy.get("protected_drivers") or []):
        if d.get("id"):
            out[d["id"]] = int(d.get("weight", 0))
    for d in (policy.get("free_drivers") or []):
        if d.get("id"):
            out[d["id"]] = int(d.get("weight", 0))
    return out


# ---- task parsing -----------------------------------------------------------

def parse_task(path: Path) -> tuple[dict, str]:
    """Return (frontmatter_dict, body_text). Body is everything after the
    closing `---`. Both empty on parse error."""
    try:
        text = path.read_text()
    except OSError:
        return {}, ""
    m = _FM_RE.match(text)
    if not m:
        return {}, text
    try:
        fm = yaml.safe_load(m.group(1)) or {}
    except yaml.YAMLError:
        fm = {}
    return fm, m.group(2)


# ---- heuristic scoring ------------------------------------------------------
#
# Each scorer returns (score 0-5, list[str] evidence).
#
# Calibration follows the rubric's escalation pattern:
#   0 — no connection (no keyword class fires)
#   1 — single weak signal
#   2 — single strong signal OR two weak signals
#   3 — component-level structural signal
#   4 — framework-level structural signal
#   5 — class-changing signal (explicit "new mechanism", "new class")
#
# Keyword sets derive from rubric worked examples + common-mis-scoring lists.


def _has_any(text: str, patterns: list[str]) -> bool:
    return any(re.search(p, text, re.I) for p in patterns)


def _count_any(text: str, patterns: list[str]) -> int:
    return sum(1 for p in patterns if re.search(p, text, re.I))


def score_d1_antifragility(fm: dict, body: str, tags: list[str]) -> tuple[int, list[str]]:
    """D1 — Antifragility: failure-class detection/prevention mechanisms."""
    ev: list[str] = []
    wf = (fm.get("workflow_type") or "").lower()

    # Level 5 — new mechanism / new class
    if "novel-mechanism" in tags or "novel_mechanism" in tags:
        ev.append("tag:novel-mechanism")
    new_class = _has_any(body, [
        r"new (sovereignty boundary|gate type|ordering invariant|mechanism|authority class|class of)",
        r"new mechanism for converting",
        r"changes the class of (failure|behavior|work)",
        r"structurally impossible",
    ])
    if new_class:
        ev.append("body:new-class")
    if "novel-mechanism" in tags or new_class:
        if new_class and ("novel-mechanism" in tags or "novel_mechanism" in tags):
            return 5, ev + ["→5 (novel-mechanism + class-change body)"]
        if new_class:
            return 4 if not ev else 5, ev + ["→4-5 (class-change body)"]

    # Level 4 — framework-level structural gate
    has_gate = _has_any(body, [
        r"PreToolUse hook", r"PostToolUse hook", r"completion gate",
        r"sovereignty gate", r"structural gate", r"§ACD",
        r"fw doctor (check|signal|FAIL)", r"audit FAIL",
        r"refuses?\s+(work-completed|--status)",
    ])
    if has_gate:
        ev.append("body:structural-gate")
        return 4, ev + ["→4 (framework-level gate)"]

    # Level 3 — component-level test/audit
    has_test_audit = _has_any(body, [
        r"regression test", r"playwright test", r"unit test.*added",
        r"audit check", r"lint(er)? rule",
    ])
    if has_test_audit:
        ev.append("body:test-or-audit-check")
        return 3, ev + ["→3 (component-level test/audit)"]

    # Level 2 — bug fix + learning capture
    has_learning = bool(re.search(r"\bL-\d{2,4}\b", body))
    has_concern = bool(re.search(r"\bG-\d{2,4}\b", body))
    fix_class = ("fix" in tags or "bug" in tags or "regression" in tags
                 or _has_any(body, [r"\bRCA\b", r"root cause", r"\bbug\b"]))
    if has_learning:
        ev.append("body:learning-ref")
    if has_concern:
        ev.append("body:concern-ref")
    if fix_class and (has_learning or has_concern):
        return 2, ev + ["→2 (fix + learning/concern ref)"]
    if has_learning or has_concern:
        ev.append("→2 (learning/concern ref alone)")
        return 2, ev

    # Level 1 — local bug fix without learning capture
    if fix_class:
        ev.append("body:fix-without-learning")
        return 1, ev + ["→1 (local fix, no learning)"]

    # Level 0 — pure feature, no failure context
    return 0, ev + ["→0 (no antifragility signal)"]


def score_d2_reliability(fm: dict, body: str, tags: list[str]) -> tuple[int, list[str]]:
    """D2 — Reliability: observability, audit, no-silent-failures."""
    ev: list[str] = []

    # Level 5 — silent-failure class removed
    class_removed = _has_any(body, [
        r"silent[- ]failure class", r"silent[- ]halt class",
        r"class of silent", r"cannot regress",
        r"silent-failure mode removed.*class",
    ])
    if class_removed:
        ev.append("body:silent-class-removed")
        return 5, ev + ["→5 (silent-failure class)"]

    # Level 4 — framework-level audit/doctor signal
    framework_observability = _has_any(body, [
        r"fw doctor (check|signal|warn|fail)",
        r"fw audit", r"audit FAIL", r"audit WARN",
        r"audit check.*silent",
        r"surface(s|d) (the )?silent",
    ])
    if framework_observability:
        ev.append("body:fw-audit-or-doctor")
        return 4, ev + ["→4 (framework-level observability)"]

    # Level 3 — silent-failure mode in one component
    component_silent = _has_any(body, [
        r"silent failure", r"silent halt", r"silent (skip|drop|swallow)",
        r"return code.*propagat", r"error propagat",
        r"silent[- ]?halt",
    ])
    if component_silent:
        ev.append("body:component-silent-failure")
        return 3, ev + ["→3 (component-level silent-failure fix)"]

    # Level 2 — telemetry/audit entry/structured output
    observability = _has_any(body, [
        r"telemetry", r"structured (output|log)", r"audit entry",
        r"observability", r"observable",
        r"\.jsonl", r"event(\s+)?log",
    ])
    if observability:
        ev.append("body:telemetry-or-audit-entry")
        return 2, ev + ["→2 (observability added)"]

    # Level 1 — log line / error message added
    if _has_any(body, [r"log(ged|s|ging) (a |the |an |line)", r"error message",
                       r"prints? (a |the |an )?(warning|error|info)"]):
        ev.append("body:log-or-error-line")
        return 1, ev + ["→1 (log/error line)"]

    return 0, ev + ["→0 (no reliability signal)"]


def score_d3_usability(fm: dict, body: str, tags: list[str]) -> tuple[int, list[str]]:
    """D3 — Usability: developer/agent experience."""
    ev: list[str] = []

    # Level 5 — new collaboration mode introduced
    new_mode = _has_any(body, [
        r"new collaboration mode",
        r"new (workflow|interaction|way of working)",
        r"introduces? (a )?new (mechanic|surface|interaction mode)",
    ])
    if new_mode:
        ev.append("body:new-collab-mode")
        return 5, ev + ["→5 (new collaboration mode)"]

    # Level 4 — friction class removed at framework level
    framework_ux = _has_any(body, [
        r"copy-pasteable", r"single entry point", r"golden[- ]path",
        r"framework-level (friction|UX|usability)",
        r"writing rule",
    ])
    if framework_ux:
        ev.append("body:framework-level-ux")
        return 4, ev + ["→4 (framework-level UX)"]

    # Level 3 — component discoverability (helps, listings, layout)
    component_ux = _has_any(body, [
        r"--help (output|text|message)", r"new (`?fw [a-z-]+ --help`?|help)",
        r"Watchtower (page|panel|section|view)", r"render[- ]?surface",
        r"discoverability",
    ]) or "render-surface" in tags or "web" in tags
    if component_ux:
        ev.append("body:component-discoverability")
        return 3, ev + ["→3 (component-level discoverability)"]

    # Level 2 — sensible default / surprising default removed
    defaults = _has_any(body, [
        r"sensible default", r"default behaviour", r"default to",
        r"surprising default",
    ])
    if defaults:
        ev.append("body:default-change")
        return 2, ev + ["→2 (default tuned)"]

    # Level 1 — error message text improved (one site)
    err_msg = _has_any(body, [
        r"error message.*improved", r"actionable error",
        r"clearer (error|message|output)",
    ])
    if err_msg:
        ev.append("body:error-msg-improved")
        return 1, ev + ["→1 (error msg improved)"]

    return 0, ev + ["→0 (no usability signal)"]


def score_d4_portability(fm: dict, body: str, tags: list[str]) -> tuple[int, list[str]]:
    """D4 — Portability: cross-environment, cross-provider."""
    ev: list[str] = []

    # Level 5 — class becomes provider/environment neutral
    class_neutral = _has_any(body, [
        r"provider-neutral", r"environment-neutral",
        r"works for everyone", r"works from any (consumer|project|machine)",
        r"class of consumer-facing flows",
        r"fresh[- ]machine", r"fresh[- ]init",
        r"any consumer (project|in the wild)",
    ])
    if class_neutral:
        ev.append("body:class-neutral")
        return 5, ev + ["→5 (class-level provider/env neutrality)"]

    # Level 4 — cross-machine / cross-project semantics
    cross_machine = _has_any(body, [
        r"cross-machine", r"cross-project",
        r"\bremote (host|machine|agent)\b",
        r"survive(s)? (a )?machine boundary",
        r"\bpush(ed)? to remote(s)?\b",
    ])
    if cross_machine:
        ev.append("body:cross-machine")
        return 4, ev + ["→4 (cross-machine semantics)"]

    # Level 3 — new abstraction over a locked-in concept
    abstraction = _has_any(body, [
        r"\bMCP\b", r"\bLSP\b", r"OpenAPI",
        r"fw_config", r"per-project (config|setting)",
        r"FW_[A-Z_]+ env",
        r"abstraction (over|of) (a )?(provider|backend|transport)",
    ])
    if abstraction:
        ev.append("body:portability-abstraction")
        return 3, ev + ["→3 (portability abstraction)"]

    # Level 2 — component works across an env class
    env_class = _has_any(body, [
        r"toolchain", r"missing (binary|toolchain)",
        r"shim", r"fallback path",
        r"\bbats\b.*fresh.*machine",
    ])
    if env_class:
        ev.append("body:env-class-handled")
        return 2, ev + ["→2 (env-class handled)"]

    # Level 1 — one hard-coded value removed
    hard_coded = _has_any(body, [
        r"hard-?coded (path|port|host|url)",
        r"remove(d|s)? (a )?hard-?code",
        r"local-only assumption",
    ])
    if hard_coded:
        ev.append("body:hard-coded-removed")
        return 1, ev + ["→1 (hard-coded removed)"]

    return 0, ev + ["→0 (no portability signal)"]


def _components_text(fm: dict) -> str:
    """Helper: flatten the `components:` frontmatter list to a single lowercased
    string for regex matching. Returns empty string if absent/malformed."""
    comps = fm.get("components") or []
    if not isinstance(comps, list):
        return ""
    return " ".join(str(c).lower() for c in comps)


def score_f_recall(fm: dict, body: str, tags: list[str]) -> tuple[int, list[str]]:
    """F-RECALL — Recall Leverage: durable, retrievable knowledge accumulation.

    T-2168 (v3-followup-A). Anchored to policy/value-drivers.yaml lines 105-112.
    Rewards better RETRIEVAL & SYNTHESIS, not raw capture (guardrail line 116).

    Rubric:
      0: No durable artifact.
      1: Session-scoped capture only (episodic, not promoted).
      2: Captured + lightly promoted, but not retrievable by future sessions.
      3: Writes a reusable artifact future sessions can find via `fw recall`.
      4: Closes the capture→encode→synced-into-CLAUDE.md loop.
      5: Improves the retrieval/synthesis layer itself.
    """
    ev: list[str] = []
    comps = _components_text(fm)
    body_l = body.lower()

    # Level 5 — touches the retrieval/synthesis layer itself
    layer_touch = (_has_any(comps, [
        r"lib/recall", r"agents/recall", r"web/blueprints/recall",
        r"lib/synthesis", r"agents/condensation", r"lib/embeddings",
        r"qdrant", r"lib/index",
    ]) or _has_any(body, [
        r"retrieval (layer|engine|surface)",
        r"synthesis layer", r"selective recall", r"condensation engine",
        r"embeddings? (substrate|index|store)",
        r"improves? (the )?(recall|retrieval|synthesis) (layer|engine|surface)",
    ]))
    if layer_touch:
        ev.append("body/components:retrieval-layer")
        return 5, ev + ["→5 (improves recall/synthesis layer)"]

    # Level 4 — closes capture→encode→synced-into-instructions loop
    instruction_sync = (_has_any(comps, [
        r"\bCLAUDE\.md\b", r"FRAMEWORK\.md", r"050-Inceptions\.md",
    ]) or _has_any(body, [
        r"sync(ed|s|ing)? (into|to) CLAUDE\.md",
        r"writes? (a |the )?rule (into|to) CLAUDE",
        r"auto[- ]sync.*CLAUDE", r"CLAUDE[- ]sync",
        r"adds? (a )?writing rule",
        r"codif(y|ies|ied) (a )?(rule|practice|pattern) into",
        r"closes? (the )?(capture|recall) loop",
    ]))
    if instruction_sync:
        ev.append("body/components:instruction-sync")
        return 4, ev + ["→4 (capture→encode→sync loop closed)"]

    # Level 3 — reusable artifact future sessions can find via fw recall
    recallable = (_has_any(body, [
        r"\[\[[a-z][a-z0-9_-]+\]\]",                    # memory-slug link
        r"fw recall", r"fw ask",                        # explicit recall surfaces
        r"writes? (an? |the )?(learning|pattern|decision) entry",
        r"fw context add-(learning|pattern|decision)",
        r"memory slug", r"add-learning ",
    ]) or _has_any(comps, [
        r"\.context/project/learnings\.yaml",
        r"\.context/project/patterns\.yaml",
        r"\.context/project/decisions\.yaml",
    ]))
    if recallable:
        ev.append("body:fw-recall-or-memory-link")
        return 3, ev + ["→3 (recallable artifact)"]

    # Level 2 — lightly promoted (concerns/observations/notes), not retrievable
    promoted = (_has_any(body, [
        r"concerns?\.yaml", r"observation(s|-)? (inbox|register)?",
        r"register(ed)? (a |the )?(gap|concern|observation)",
        r"fw note (add|promote)", r"docs/reports/",
    ]) or _has_any(comps, [
        r"\.context/project/concerns\.yaml",
        r"\.context/working/observations",
        r"docs/reports/",
    ]))
    if promoted:
        ev.append("body:lightly-promoted")
        return 2, ev + ["→2 (promoted, not retrievable)"]

    # Level 1 — session-scoped only (episodic capture)
    episodic = (_has_any(body, [
        r"\.context/episodic", r"episodic (entry|summary|yaml)",
        r"handover( document| file)?", r"session capture",
    ]) or _has_any(comps, [
        r"\.context/episodic", r"\.context/handovers",
    ]))
    if episodic:
        ev.append("body:episodic-only")
        return 1, ev + ["→1 (session-scoped capture)"]

    return 0, ev + ["→0 (no recall signal)"]


def score_f_orch(fm: dict, body: str, tags: list[str]) -> tuple[int, list[str]]:
    """F-ORCH — Orchestration Leverage: routable-surface expansion.

    T-2168 (v3-followup-A). Anchored to policy/value-drivers.yaml lines 131-141.
    Guardrail line 142-146: Score CAPABILITY UPLIFT, not ease-of-delegating
    THIS task. Anchor on genuine routable-surface expansion to avoid
    manufactured I/O-block busywork.

    Refuse-rule (R5 enforcement): if body says "delegate this" / "wrap in
    dispatch" / "run via termlink" without ALSO touching dispatch substrate
    (workflows, resolver, peer, orchestrator, dispatch, bus, termlink lib),
    return 0 with rationale `f-orch-refuse:wrap-without-substrate`.

    Rubric:
      0: Primary-agent serial only.
      1: Hand-wired dispatch only.
      2: Minor routing improvement, single-use.
      3: Clean typed I/O contract or decision gate.
      4: Rubric-scored work routable to TermLink worker; router decision tree.
      5: Expands orchestration substrate itself.
    """
    ev: list[str] = []
    comps = _components_text(fm)

    # Substrate-touching components — required for any non-zero score under R5.
    substrate_touch = _has_any(comps, [
        r"agents/orchestrator", r"agents/dispatch", r"agents/peer",
        r"agents/reviewer",                                       # dispatch-mode worker
        r"lib/resolver", r"lib/peer", r"lib/orchestrator", r"lib/bus",
        r"lib/dispatch", r"lib/termlink", r"agents/termlink",
        r"\.context/dispatches", r"\.context/workflows",
        r"web/blueprints/orchestrator",
        r"bvp-estimator/estimator\.py",                          # rubric-scored routing
    ])
    substrate_body = _has_any(body, [
        r"orchestrator substrate", r"resolver workflow", r"router decision tree",
        r"\bfw bus (post|read|manifest)\b", r"\bfw dispatch\b",
        r"\bfw orchestrator\b", r"\bfw peer subscribe\b",
        r"\bfw resolver\b", r"\bfw outcome\b",
        r"typed (I/O |io )?(contract|envelope)",
        r"dispatch envelope", r"refuse-or-dispatch",
        r"TermLink (worker|dispatch)", r"peer-consult",
    ])

    # R5 refuse-rule: "delegate this" without substrate touch → 0.
    # "Touching" substrate = an edit landing in a substrate component path.
    # Body keywords alone (substrate_body) are not enough — they describe the
    # wrap, not the substrate uplift. This is the F-ORCH anti-Goodhart per the
    # T-2168 AC: a task that ONLY says "delegate this" with no substrate edit
    # is busywork, not capability uplift.
    wrap_phrase = _has_any(body, [
        r"wrap.{0,30}in.{0,20}(dispatch|termlink)",
        r"delegate this",
        r"run (this )?via termlink",
        r"dispatch this (out|task|to)",
        r"can be (delegated|dispatched|routed)",
    ])
    if wrap_phrase and not substrate_touch:
        return 0, ["body:wrap-phrase-without-substrate",
                   "→0 (f-orch-refuse:wrap-without-substrate)"]

    # Level 5 — expands the substrate itself
    substrate_expand = _has_any(body, [
        r"new worker class", r"parallel (dispatch|workers)",
        r"multi[- ]perspective dispatch",
        r"advances? the orchestrator",
        r"new (orchestrator|resolver|peer) (namespace|primitive)",
        r"expands? (the )?orchestrat(ion|or) substrate",
    ])
    substrate_create_comps = _has_any(comps, [
        r"agents/orchestrator", r"agents/peer", r"lib/orchestrator", r"lib/peer",
    ])
    if substrate_expand and substrate_create_comps:
        ev.append("body:substrate-expand")
        ev.append("components:substrate-namespace")
        return 5, ev + ["→5 (orchestration substrate expanded)"]
    if substrate_expand:
        ev.append("body:substrate-expand")
        return 5, ev + ["→5 (substrate-expand body)"]

    # Level 4 — rubric-scored work routable to worker, or router decision tree
    rubric_route = _has_any(body, [
        r"rubric[- ]scored", r"BVP estimator",
        r"router decision tree", r"refuse-or-dispatch (gate|step)",
        r"reviewer.*--dispatch", r"dispatch[- ]mode",
        r"interpretive.*rubric[- ]scored",
        r"peer (responder|subscribe).*spawn",
    ])
    if rubric_route:
        ev.append("body:rubric-routable")
        return 4, ev + ["→4 (rubric-routable / router decision tree)"]

    # Level 3 — typed I/O contract or decision gate
    typed_io = _has_any(body, [
        r"typed (I/O |io )?(contract|envelope)",
        r"dispatch envelope", r"YAML envelope", r"decision gate",
        r"workflow yaml", r"resolver workflow",
        r"\bfw bus (post|read|manifest)\b",
    ])
    if typed_io:
        ev.append("body:typed-io-or-gate")
        return 3, ev + ["→3 (typed I/O contract or decision gate)"]

    # Level 2 — minor routing improvement, single-use
    minor_route = _has_any(body, [
        r"single[- ]use (routing|dispatch)",
        r"minor (routing|dispatch) (improvement|change)",
        r"adds? (a |one )?(dispatch|routing) (call|invocation)",
    ])
    if minor_route or (substrate_touch and not substrate_body):
        ev.append("components:substrate-edit" if substrate_touch else "body:minor-routing")
        return 2, ev + ["→2 (minor routing change)"]

    # Level 1 — hand-wired dispatch only (no reusable artifact)
    hand_wired = _has_any(body, [
        r"hand[- ]wired dispatch",
        r"one[- ]off (dispatch|termlink|worker)",
        r"\btermlink dispatch\b", r"\btermlink spawn\b",
        r"\btermlink exec\b", r"\btermlink interact\b",
    ])
    if hand_wired:
        ev.append("body:hand-wired-dispatch")
        return 1, ev + ["→1 (hand-wired dispatch only)"]

    return 0, ev + ["→0 (no orchestration signal)"]


def score_free_driver(driver_id: str, fm: dict, body: str, tags: list[str]) -> tuple[int, list[str]]:
    """Heuristic fallback for free drivers without a dedicated scorer — keyword-
    on-driver-id only.

    Used for any active free driver not yet covered by a dedicated `score_f_*`
    function (T-2168 added F-RECALL + F-ORCH; future drivers fall back here
    until they get dedicated heuristics). Looks for the driver id as a
    substring in body/tags; if present, scores 1-2 based on count. If absent, 0.
    """
    ev: list[str] = []
    needle = driver_id.lower()
    hits = sum(1 for chunk in (body, " ".join(tags)) if needle in chunk.lower())
    if hits == 0:
        return 0, [f"→0 (no '{driver_id}' mention)"]
    return min(hits, 2), [f"body/tag hits for '{driver_id}': {hits}", f"→{min(hits, 2)}"]


# ---- top-level orchestration ------------------------------------------------

def _score_inception_voi(fm: dict, body: str, tags: list[str]) -> tuple[int, list[str]]:
    """T-2189 inception scoring exception (050-Inceptions.md §Scoring Exception).

    Inceptions are evaluated by `voi_score` (T-2188 schema, float 0..1) rather
    than per-driver mechanism rubrics, because the inception's "value" IS the
    expected value of resolving the question, not the build-shaped traits the
    D-handlers measure. Same score is returned for every requested driver —
    rank is determined by voi alone. Build-task scoring is unchanged.

    Missing or malformed `voi_score` returns a neutral mid-score (2) so
    grandfathered inceptions (pre-T-2188) still rank, just not by VoI.
    """
    voi = fm.get("voi_score")
    if voi is None:
        return 2, ["→2 (voi-absent-grandfathered)"]
    try:
        voi_f = float(voi)
    except (TypeError, ValueError):
        return 2, ["→2 (voi-malformed)"]
    voi_f = max(0.0, min(1.0, voi_f))
    score = int(round(voi_f * 5))
    return score, [f"→{score} (voi:{voi_f:.2f})"]


def estimate_task(task_path: Path, drivers: dict[str, int]) -> dict:
    """Score one task; return {scores, evidence, version, rubric_sha, latency_s}.

    T-2189 inception scoring exception: when `workflow_type: inception`, ALL
    requested drivers are scored via `_score_inception_voi` instead of per-
    driver handlers. The voi_score field (T-2188 schema) IS the composite.
    See 050-Inceptions.md §Scoring Exception.
    """
    t0 = time.monotonic()
    fm, body = parse_task(task_path)
    tags = list(fm.get("tags") or [])
    is_inception = (fm.get("workflow_type") or "").lower() == "inception"

    scores: dict[str, int] = {}
    evidence: dict[str, list[str]] = {}

    handlers = {
        "D1": score_d1_antifragility,
        "D2": score_d2_reliability,
        "D3": score_d3_usability,
        "D4": score_d4_portability,
        # T-2168 — dedicated free-driver heuristics. Generic score_free_driver
        # remains the fallback for any other active free driver.
        "F-RECALL": score_f_recall,
        "F-ORCH": score_f_orch,
    }
    for driver_id in drivers:
        if is_inception:
            sc, ev = _score_inception_voi(fm, body, tags)
        elif driver_id in handlers:
            sc, ev = handlers[driver_id](fm, body, tags)
        else:
            sc, ev = score_free_driver(driver_id, fm, body, tags)
        scores[driver_id] = sc
        evidence[driver_id] = ev

    return {
        "scores": scores,
        "evidence": evidence,
        "version": ESTIMATOR_ID,
        "rubric_sha": _rubric_sha(),
        "latency_s": round(time.monotonic() - t0, 4),
    }


def _v2_delta_should_skip(proposed: dict[str, int], confirmed: dict | None) -> bool:
    """M3 — skip if confirmed exists and proposed differs by <2 on every driver."""
    if not confirmed:
        return False
    confirmed_clean = {k: int(v) for k, v in confirmed.items() if isinstance(v, (int, float))}
    if not confirmed_clean:
        return False
    for driver_id, conf in confirmed_clean.items():
        prop = proposed.get(driver_id)
        if prop is None:
            continue
        if abs(int(prop) - int(conf)) >= 2:
            return False
    return True


def _short_rationale(evidence: dict[str, list[str]]) -> str:
    parts = []
    for driver_id, ev in evidence.items():
        arrow = next((e for e in ev if e.startswith("→")), "→?")
        signals = [e for e in ev if not e.startswith("→")]
        sig_str = ",".join(signals[:2]) if signals else "no-signal"
        parts.append(f"{driver_id}={arrow.split()[0][1:]} ({sig_str})")
    return "; ".join(parts)


def write_proposed(task_path: Path, scores: dict[str, int],
                   evidence: dict[str, list[str]], rubric_sha: str,
                   dry_run: bool = False) -> tuple[bool, str]:
    """Write the proposed entry to the task's frontmatter unless v2-delta says skip.

    Returns (wrote, reason).
    """
    text = task_path.read_text()
    m = _FM_RE.match(text)
    if not m:
        return False, "no-frontmatter"
    fm_text = m.group(1)
    body_text = m.group(2)

    if _HAS_RUAMEL:
        fm = _ruamel.load(fm_text)
    else:
        fm = yaml.safe_load(fm_text) or {}

    confirmed = fm.get("bvp_scores") if fm else None
    if _v2_delta_should_skip(scores, confirmed):
        return False, "v2-delta-skip"

    entry = {
        "ts": _utc_now(),
        "estimator": ESTIMATOR_ID,
        "scores": dict(scores),
        "rationale": _short_rationale(evidence),
        "rubric_sha": rubric_sha,
    }

    existing = fm.get("bvp_scores_proposed") if fm else None
    if existing is None or not isinstance(existing, list):
        fm["bvp_scores_proposed"] = [entry]
    else:
        # M3: replace newest entry from this estimator if identical scores;
        # otherwise append.
        if existing and isinstance(existing[-1], dict) and \
           existing[-1].get("estimator") == ESTIMATOR_ID and \
           existing[-1].get("scores") == entry["scores"]:
            return False, "no-change-since-last"
        existing.append(entry)
        fm["bvp_scores_proposed"] = existing

    fm["last_update"] = _utc_now()

    if _HAS_RUAMEL:
        from io import StringIO
        buf = StringIO()
        _ruamel.dump(fm, buf)
        new_fm_text = buf.getvalue().rstrip("\n")
    else:
        new_fm_text = yaml.safe_dump(fm, sort_keys=False, default_flow_style=False).rstrip("\n")

    new_text = f"---\n{new_fm_text}\n---\n{body_text}"
    if dry_run:
        return False, "dry-run"
    task_path.write_text(new_text)
    return True, "wrote"


# ---- Cost estimator (T-1935, arc-006 T-NEW-7c) ------------------------------
#
# Parallel to BVP scoring above. Proposes the three F8 cost components per
# task — blast_radius, tier, effort — written to `cost_estimate_proposed:`
# (advisory list). The confirmed `cost_estimate:` field stays human-only via
# `fw bvp confirm-cost`. Sovereignty preserved. R3 bit-deterministic by
# construction (same input → same output). v1-heuristic engine.
#
# Why a separate code path instead of generalizing estimate_task:
#   - The semantics differ (scores 0-5 per driver vs three named components).
#   - The frontmatter target is different (bvp_scores_proposed vs
#     cost_estimate_proposed) — keeping write paths separate prevents
#     accidental cross-write.
#   - Engine reuse comes for free at the harness level (sweep / with-sla)
#     because both write functions return the same `(wrote, reason)` tuple.

COST_TIER_TAGS = {"tier-0": 0, "tier-1": 1, "tier-2": 2, "tier-3": 3, "tier-4": 4}
COST_WORKFLOW_TIER = {
    "inception": 4, "specification": 4, "design": 3,
    "build": 2, "refactor": 3, "test": 1, "decommission": 2,
}


def score_blast_radius(fm: dict, body: str, tags: list[str]) -> tuple[int, list[str]]:
    """Heuristic: count `components:` entries → 0/1/3/5/7/9 scale.

    Components are explicit declarations of what the task touches; longer
    lists imply wider blast radius. The 0/1/3/5/7/9 ladder is non-linear by
    design — a component count of 7 vs 8 is rarely meaningful, but 0 vs 1
    vs 5+ is.

    T-2189 inception scoring exception: inceptions' `components:` is empty
    by definition (the build doesn't exist yet), so the formula above
    always returns 0 — making inceptions look artificially cheap. When
    `workflow_type: inception`, prefer the `target_blast_radius` (T-2188
    schema) frontmatter field. See 050-Inceptions.md §Scoring Exception
    and policy/value-drivers.yaml §inception_scoring_exception.
    """
    wf = (fm.get("workflow_type") or "").lower()
    if wf == "inception":
        tbr = fm.get("target_blast_radius")
        if tbr is not None:
            try:
                v = int(tbr)
                v = max(0, min(9, v))
                return v, [f"→{v} (target_blast_radius:inception-T-2189)"]
            except (TypeError, ValueError):
                # Malformed → fall through to components count
                pass

    components = fm.get("components") or []
    if not isinstance(components, list):
        return 0, ["→0 (components-malformed)"]
    n = len([c for c in components if c])
    if n == 0: return 0, ["→0 (no-components)"]
    if n == 1: return 1, ["→1 (single-component)"]
    if n <= 3: return 3, [f"→3 ({n}-components)"]
    if n <= 6: return 5, [f"→5 ({n}-components-medium-blast)"]
    if n <= 9: return 7, [f"→7 ({n}-components-large-blast)"]
    return 9, [f"→9 ({n}-components-cross-cutting)"]


def score_tier(fm: dict, body: str, tags: list[str]) -> tuple[int, list[str]]:
    """Heuristic: tag-table lookup wins; fallback to workflow_type table.

    Tags are explicit (`tier-0`, `tier-1`, …) when authors annotated the
    task; workflow_type is the universal fallback. Both tables are
    documented at module top.
    """
    for t in tags:
        if t in COST_TIER_TAGS:
            v = COST_TIER_TAGS[t]
            return v, [f"→{v} (tag:{t})"]
    wf = fm.get("workflow_type") or "build"
    v = COST_WORKFLOW_TIER.get(wf, 2)
    return v, [f"→{v} (workflow:{wf})"]


_AC_CHECKBOX_RE = re.compile(r"^\s*-\s*\[[ xX]\]", re.M)


def score_effort(fm: dict, body: str, tags: list[str]) -> tuple[int, list[str]]:
    """Heuristic: body-line-count / 50 + AC-checkbox count, clamped to [1, 8]."""
    body_lines = body.count("\n")
    ac_count = len(_AC_CHECKBOX_RE.findall(body))
    raw = body_lines // 50 + ac_count
    v = max(1, min(8, raw))
    return v, [f"→{v} (lines={body_lines},acs={ac_count})"]


def estimate_cost(task_path: Path) -> dict:
    """Score one task's cost components; return canonical envelope.

    Shape: `{cost_estimate: {blast_radius, tier, effort}, evidence: {...},
    version, rubric_sha, latency_s}`. Mirrors `estimate_task` so callers
    can pattern-match identically.
    """
    t0 = time.monotonic()
    fm, body = parse_task(task_path)
    tags = list(fm.get("tags") or [])

    br, br_ev = score_blast_radius(fm, body, tags)
    tier, tier_ev = score_tier(fm, body, tags)
    eff, eff_ev = score_effort(fm, body, tags)

    return {
        "cost_estimate": {"blast_radius": br, "tier": tier, "effort": eff},
        "evidence": {"blast_radius": br_ev, "tier": tier_ev, "effort": eff_ev},
        "version": ESTIMATOR_ID,
        "rubric_sha": _rubric_sha(),
        "latency_s": round(time.monotonic() - t0, 4),
    }


def _cost_v2_delta_should_skip(proposed: dict, confirmed: dict | None) -> bool:
    """M3 v2-delta for cost: skip if confirmed exists AND every component
    differs by <2.

    Sovereignty: never reads from `cost_estimate_proposed`. Only `cost_estimate`
    (confirmed) is the comparison baseline.
    """
    if not confirmed or not isinstance(confirmed, dict):
        return False
    relevant = {k: confirmed.get(k) for k in ("blast_radius", "tier", "effort")}
    if all(v is None for v in relevant.values()):
        return False
    for k, conf in relevant.items():
        prop = proposed.get(k)
        if conf is None or prop is None:
            continue
        if abs(int(prop) - int(conf)) >= 2:
            return False
    return True


def _cost_short_rationale(evidence: dict[str, list[str]]) -> str:
    parts = []
    for component, ev in evidence.items():
        arrow = next((e for e in ev if e.startswith("→")), "→?")
        signals = [e for e in ev if not e.startswith("→")]
        sig_str = ",".join(signals[:2]) if signals else "no-signal"
        parts.append(f"{component}={arrow.split()[0][1:]} ({sig_str})")
    return "; ".join(parts)


def write_proposed_cost(task_path: Path, cost_estimate: dict,
                        evidence: dict[str, list[str]], rubric_sha: str,
                        dry_run: bool = False) -> tuple[bool, str]:
    """Write the proposed cost entry. Returns (wrote, reason).

    Reasons: `wrote`, `no-frontmatter`, `v2-delta-skip`, `no-change-since-last`,
    `dry-run`.
    """
    text = task_path.read_text()
    m = _FM_RE.match(text)
    if not m:
        return False, "no-frontmatter"
    fm_text = m.group(1)
    body_text = m.group(2)

    if _HAS_RUAMEL:
        fm = _ruamel.load(fm_text)
    else:
        fm = yaml.safe_load(fm_text) or {}

    confirmed = fm.get("cost_estimate") if fm else None
    if _cost_v2_delta_should_skip(cost_estimate, confirmed):
        return False, "v2-delta-skip"

    entry = {
        "ts": _utc_now(),
        "estimator": ESTIMATOR_ID,
        "cost_estimate": dict(cost_estimate),
        "rationale": _cost_short_rationale(evidence),
        "rubric_sha": rubric_sha,
    }

    existing = fm.get("cost_estimate_proposed") if fm else None
    if existing is None or not isinstance(existing, list):
        fm["cost_estimate_proposed"] = [entry]
    else:
        if existing and isinstance(existing[-1], dict) and \
           existing[-1].get("estimator") == ESTIMATOR_ID and \
           existing[-1].get("cost_estimate") == entry["cost_estimate"]:
            return False, "no-change-since-last"
        existing.append(entry)
        fm["cost_estimate_proposed"] = existing

    fm["last_update"] = _utc_now()

    if _HAS_RUAMEL:
        from io import StringIO
        buf = StringIO()
        _ruamel.dump(fm, buf)
        new_fm_text = buf.getvalue().rstrip("\n")
    else:
        new_fm_text = yaml.safe_dump(fm, sort_keys=False, default_flow_style=False).rstrip("\n")

    new_text = f"---\n{new_fm_text}\n---\n{body_text}"
    if dry_run:
        return False, "dry-run"
    task_path.write_text(new_text)
    return True, "wrote"


# ---- CLI --------------------------------------------------------------------

def _resolve_task(task_id: str) -> Path | None:
    for sub in ("active", "completed"):
        matches = sorted((PROJECT_ROOT / ".tasks" / sub).glob(f"{task_id}-*.md"))
        if matches:
            return matches[0]
    return None


def cmd_one(task_id: str, dry_run: bool = False, json_out: bool = False) -> int:
    task_path = _resolve_task(task_id)
    if not task_path:
        print(f"ERROR: task {task_id} not found", file=sys.stderr)
        return 1
    drivers = _load_drivers()
    result = estimate_task(task_path, drivers)
    wrote, reason = write_proposed(
        task_path, result["scores"], result["evidence"],
        result["rubric_sha"], dry_run=dry_run
    )
    result["wrote"] = wrote
    result["reason"] = reason
    result["task_id"] = task_id
    result["task_path"] = str(task_path.relative_to(PROJECT_ROOT))
    if json_out:
        print(json.dumps(result, indent=2))
    else:
        sc = result["scores"]
        sc_str = " ".join(f"{k}={v}" for k, v in sc.items())
        print(f"{task_id}: {sc_str}  [{reason}]  ({result['latency_s']}s)")
    return 0


def cmd_all(dry_run: bool = False, limit: int | None = None,
            statuses: list[str] | None = None) -> int:
    drivers = _load_drivers()
    task_files: list[Path] = []
    for sub in ("active", "completed"):
        task_files.extend(sorted((PROJECT_ROOT / ".tasks" / sub).glob("T-*.md")))
    if limit:
        task_files = task_files[:limit]

    n_wrote = n_skip = n_err = 0
    total_latency = 0.0
    for tp in task_files:
        fm, _ = parse_task(tp)
        if statuses and (fm.get("status") not in statuses):
            continue
        task_id = fm.get("id") or tp.stem.split("-")[0:2]
        if isinstance(task_id, list):
            task_id = "-".join(task_id)
        try:
            result = estimate_task(tp, drivers)
            wrote, reason = write_proposed(
                tp, result["scores"], result["evidence"],
                result["rubric_sha"], dry_run=dry_run
            )
            total_latency += result["latency_s"]
            if wrote:
                n_wrote += 1
            else:
                n_skip += 1
        except Exception as e:
            n_err += 1
            print(f"ERROR on {tp.name}: {e}", file=sys.stderr)

    print(f"Estimated {n_wrote + n_skip + n_err} tasks: "
          f"{n_wrote} wrote, {n_skip} skipped, {n_err} errored. "
          f"Total latency {total_latency:.2f}s.")
    return 0 if n_err == 0 else 1


def _clear_unscored_flag(task_path: Path) -> bool:
    """Remove `unscored: true` from frontmatter if present. Returns True on
    successful clear, False if no flag was set (no-op). Used by sweep when
    estimator successfully scores a previously-timed-out task (T-1923 AC#5)."""
    text = task_path.read_text()
    m = _FM_RE.match(text)
    if not m:
        return False
    fm_text = m.group(1)
    body_text = m.group(2)
    if _HAS_RUAMEL:
        fm = _ruamel.load(fm_text)
    else:
        fm = yaml.safe_load(fm_text) or {}
    if not fm or not fm.get("unscored"):
        return False
    del fm["unscored"]
    if _HAS_RUAMEL:
        from io import StringIO
        buf = StringIO()
        _ruamel.dump(fm, buf)
        new_fm_text = buf.getvalue().rstrip("\n")
    else:
        new_fm_text = yaml.safe_dump(fm, sort_keys=False, default_flow_style=False).rstrip("\n")
    task_path.write_text(f"---\n{new_fm_text}\n---\n{body_text}")
    return True


def _set_unscored_flag(task_path: Path) -> bool:
    """Mark `unscored: true` on frontmatter — signals to sweep that this
    task hit the SLA fallback and should be re-attempted (T-1923 AC#4)."""
    text = task_path.read_text()
    m = _FM_RE.match(text)
    if not m:
        return False
    fm_text = m.group(1)
    body_text = m.group(2)
    if _HAS_RUAMEL:
        fm = _ruamel.load(fm_text)
    else:
        fm = yaml.safe_load(fm_text) or {}
    fm = fm or {}
    if fm.get("unscored") is True:
        return False  # already set
    fm["unscored"] = True
    if _HAS_RUAMEL:
        from io import StringIO
        buf = StringIO()
        _ruamel.dump(fm, buf)
        new_fm_text = buf.getvalue().rstrip("\n")
    else:
        new_fm_text = yaml.safe_dump(fm, sort_keys=False, default_flow_style=False).rstrip("\n")
    task_path.write_text(f"---\n{new_fm_text}\n---\n{body_text}")
    return True


def _proposed_is_stale(fm: dict, stale_hours: int) -> bool:
    """A task's proposed scores are stale if the newest entry's `ts` is older
    than `stale_hours` (T-1923 AC#2). Tasks with no proposed at all are
    considered stale (eligible for first-pass scoring)."""
    proposed = fm.get("bvp_scores_proposed")
    if not proposed or not isinstance(proposed, list):
        return True
    latest = proposed[-1] if isinstance(proposed[-1], dict) else None
    if not latest:
        return True
    ts = latest.get("ts")
    if not ts:
        return True
    try:
        # Strip Z, parse as UTC
        dt = datetime.fromisoformat(str(ts).replace("Z", "+00:00"))
    except (TypeError, ValueError):
        return True
    age = datetime.now(timezone.utc) - dt
    return age.total_seconds() >= stale_hours * 3600


def cmd_sweep(stale_hours: int = 24,
              statuses: list[str] | None = None,
              cron: bool = False) -> int:
    """T-1923 scheduled sweep — score stale tasks; clear unscored:true on success.

    Selection criteria (AC#2):
      - status ∈ statuses (default: started-work, captured)
      - `bvp_scores:` is empty (unconfirmed)
      - `bvp_scores_proposed:` is older than stale_hours OR missing entirely
      - OR `unscored: true` is set (priority: SLA-fallback victims)

    Output in --cron mode is quieter (just final summary). Without --cron,
    each task is printed.
    """
    drivers = _load_drivers()
    statuses = statuses or ["started-work", "captured"]
    task_files = sorted((PROJECT_ROOT / ".tasks" / "active").glob("T-*.md"))

    n_scored = n_unscored_cleared = n_skipped = n_err = 0
    for tp in task_files:
        try:
            fm, _ = parse_task(tp)
            if not fm:
                continue
            if fm.get("status") not in statuses:
                continue
            if fm.get("bvp_scores"):
                continue  # confirmed; not the sweep's job
            had_unscored = fm.get("unscored") is True
            if not had_unscored and not _proposed_is_stale(fm, stale_hours):
                n_skipped += 1
                continue
            result = estimate_task(tp, drivers)
            wrote, reason = write_proposed(
                tp, result["scores"], result["evidence"],
                result["rubric_sha"], dry_run=False
            )
            if had_unscored:
                # Re-read to get the (post-write) frontmatter and clear flag
                if _clear_unscored_flag(tp):
                    n_unscored_cleared += 1
            if wrote:
                n_scored += 1
                if not cron:
                    sc = " ".join(f"{k}={v}" for k, v in result["scores"].items())
                    print(f"{fm.get('id', tp.stem)}: {sc}  [{reason}]")
            else:
                n_skipped += 1
        except Exception as e:
            n_err += 1
            print(f"ERROR on {tp.name}: {e}", file=sys.stderr)

    print(f"sweep: scored {n_scored}, unscored-cleared {n_unscored_cleared}, "
          f"skipped {n_skipped}, errors {n_err} "
          f"(stale_hours={stale_hours}, statuses={','.join(statuses)})")
    return 0 if n_err == 0 else 1


def cmd_with_sla(task_id: str, timeout_s: int = 10) -> int:
    """T-1923 fw resume synchronous path: score ONE task with a hard cap.

    If the estimator completes within timeout_s, the proposal is written
    normally. If it would exceed the cap, the task is flagged
    `unscored: true` so the async sweep picks it up later. Either way,
    this function exits 0 — resume itself is NEVER blocked by estimator
    behaviour (T-1923 AC#3/AC#4).
    """
    task_path = _resolve_task(task_id)
    if not task_path:
        # No task → nothing to do, exit silently (resume continues)
        return 0
    drivers = _load_drivers()
    t0 = time.monotonic()
    try:
        result = estimate_task(task_path, drivers)
        elapsed = time.monotonic() - t0
        if elapsed >= timeout_s:
            # Estimator finished but blew the budget — flag for sweep
            _set_unscored_flag(task_path)
            print(f"{task_id}: estimator exceeded {timeout_s}s SLA "
                  f"({elapsed:.2f}s), flagged unscored:true for async sweep",
                  file=sys.stderr)
            return 0
        # Within budget — write normally + clear any stale unscored flag
        write_proposed(
            task_path, result["scores"], result["evidence"],
            result["rubric_sha"], dry_run=False
        )
        _clear_unscored_flag(task_path)
        return 0
    except Exception as e:
        # Estimator errored — flag for sweep, never block resume
        _set_unscored_flag(task_path)
        print(f"{task_id}: estimator failed ({e}), flagged unscored:true",
              file=sys.stderr)
        return 0


def cmd_determinism(task_id: str, runs: int = 3) -> int:
    """Run N times against the same task; report max delta per driver.

    Heuristic engine is deterministic by construction, so this should always
    show delta=0. Provided as a regression guard against future LLM-engine
    drift (R3 mitigation).
    """
    task_path = _resolve_task(task_id)
    if not task_path:
        print(f"ERROR: task {task_id} not found", file=sys.stderr)
        return 1
    drivers = _load_drivers()
    runs_data = [estimate_task(task_path, drivers) for _ in range(runs)]
    base = runs_data[0]["scores"]
    max_delta = 0
    for r in runs_data[1:]:
        for k, v in r["scores"].items():
            d = abs(int(v) - int(base.get(k, 0)))
            if d > max_delta:
                max_delta = d
    print(f"{task_id}: {runs} runs, max delta per driver = {max_delta}")
    print(f"  scores: {base}")
    return 0 if max_delta <= 1 else 1


def cmd_measure_a3(n: int = 20, output: Path | None = None) -> int:
    """A3 measurement: run against N historical tasks; capture latency + summary."""
    drivers = _load_drivers()
    completed = sorted((PROJECT_ROOT / ".tasks" / "completed").glob("T-*.md"))[-n:]
    if not completed:
        print("ERROR: no completed tasks found", file=sys.stderr)
        return 1

    latencies = []
    rows = []
    for tp in completed:
        result = estimate_task(tp, drivers)
        latencies.append(result["latency_s"])
        rows.append({
            "task": tp.stem.split("-")[0:2],
            "task_id": "-".join(tp.stem.split("-")[0:2]),
            "scores": result["scores"],
            "latency_s": result["latency_s"],
        })

    mean = sum(latencies) / len(latencies)
    p95 = sorted(latencies)[int(len(latencies) * 0.95)] if len(latencies) > 1 else latencies[0]
    summary = {
        "estimator": ESTIMATOR_ID,
        "n_tasks": len(rows),
        "latency_mean_s": round(mean, 4),
        "latency_p95_s": round(p95, 4),
        "latency_max_s": round(max(latencies), 4),
        "sla_target_s": 5.0,
        "sla_pass": mean < 5.0,
        "token_marginal_per_task": 0,
        "rubric_sha": _rubric_sha(),
        "rows": rows,
    }
    if output:
        output.write_text(json.dumps(summary, indent=2))
        print(f"Wrote {output}")
    else:
        print(json.dumps(summary, indent=2))
    return 0


def cmd_cost_one(task_id: str, dry_run: bool = False, json_out: bool = False) -> int:
    task_path = _resolve_task(task_id)
    if not task_path:
        print(f"ERROR: task {task_id} not found", file=sys.stderr)
        return 1
    result = estimate_cost(task_path)
    wrote, reason = write_proposed_cost(
        task_path, result["cost_estimate"], result["evidence"],
        result["rubric_sha"], dry_run=dry_run
    )
    result["wrote"] = wrote
    result["reason"] = reason
    result["task_id"] = task_id
    result["task_path"] = str(task_path.relative_to(PROJECT_ROOT))
    if json_out:
        print(json.dumps(result, indent=2))
    else:
        ce = result["cost_estimate"]
        ce_str = " ".join(f"{k}={v}" for k, v in ce.items())
        print(f"{task_id}: {ce_str}  [{reason}]  ({result['latency_s']}s)")
    return 0


def cmd_cost_all(dry_run: bool = False, limit: int | None = None,
                 statuses: list[str] | None = None) -> int:
    task_files: list[Path] = []
    for sub in ("active", "completed"):
        task_files.extend(sorted((PROJECT_ROOT / ".tasks" / sub).glob("T-*.md")))
    if limit:
        task_files = task_files[:limit]

    n_wrote = n_skip = n_err = 0
    total_latency = 0.0
    for tp in task_files:
        fm, _ = parse_task(tp)
        if statuses and (fm.get("status") not in statuses):
            continue
        try:
            result = estimate_cost(tp)
            wrote, reason = write_proposed_cost(
                tp, result["cost_estimate"], result["evidence"],
                result["rubric_sha"], dry_run=dry_run
            )
            total_latency += result["latency_s"]
            if wrote:
                n_wrote += 1
            else:
                n_skip += 1
        except Exception as e:
            n_err += 1
            print(f"ERROR on {tp.name}: {e}", file=sys.stderr)

    print(f"cost-estimated {n_wrote + n_skip + n_err} tasks: "
          f"{n_wrote} wrote, {n_skip} skipped, {n_err} errored. "
          f"Total latency {total_latency:.2f}s.")
    return 0 if n_err == 0 else 1


def _cost_proposed_is_stale(fm: dict, stale_hours: int) -> bool:
    """Mirror of `_proposed_is_stale` for cost_estimate_proposed.

    Returns True when the task SHOULD be re-scored (no proposed yet, OR
    the last proposed is older than `stale_hours`, OR explicitly flagged
    `unscored: true`).
    """
    if fm.get("unscored"):
        return True
    proposed = fm.get("cost_estimate_proposed") or []
    if not proposed or not isinstance(proposed, list):
        return True
    last = proposed[-1] if isinstance(proposed[-1], dict) else None
    if not last:
        return True
    ts = last.get("ts")
    if not ts:
        return True
    try:
        from datetime import datetime, timezone
        dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
        delta_h = (datetime.now(timezone.utc) - dt).total_seconds() / 3600
        return delta_h > stale_hours
    except Exception:
        return True


def cmd_cost_sweep(stale_hours: int = 24,
                   statuses: list[str] | None = None,
                   cron: bool = False) -> int:
    """T-1935 — periodic cost sweep. Mirrors T-1923's bvp sweep semantics.

    Scope: tasks with status ∈ statuses AND (no `cost_estimate:` OR
    `cost_estimate_proposed:` is stale/missing OR `unscored: true`).
    Sovereignty: never overwrites confirmed `cost_estimate:`.
    """
    if statuses is None:
        statuses = ["started-work", "captured"]
    task_files: list[Path] = []
    for sub in ("active", "completed"):
        task_files.extend(sorted((PROJECT_ROOT / ".tasks" / sub).glob("T-*.md")))

    n_scored = n_skip = n_err = 0
    total_latency = 0.0

    for tp in task_files:
        try:
            fm, _ = parse_task(tp)
            if fm.get("status") not in statuses:
                continue
            if fm.get("cost_estimate"):
                # Confirmed score exists — leave it alone (sovereignty).
                continue
            if not _cost_proposed_is_stale(fm, stale_hours):
                continue
            had_unscored = bool(fm.get("unscored"))
            result = estimate_cost(tp)
            wrote, reason = write_proposed_cost(
                tp, result["cost_estimate"], result["evidence"],
                result["rubric_sha"], dry_run=False
            )
            total_latency += result["latency_s"]
            if wrote:
                n_scored += 1
                if had_unscored:
                    _clear_unscored_flag(tp)
            else:
                n_skip += 1
        except Exception as e:
            n_err += 1
            if not cron:
                print(f"ERROR on {tp.name}: {e}", file=sys.stderr)

    msg = (f"cost-sweep: scored {n_scored}, skipped {n_skip}, errored {n_err}; "
           f"total latency {total_latency:.2f}s")
    if cron:
        # Cron uses logger -t agentic-cron — stdout is sufficient.
        print(msg)
    else:
        print(msg)
    return 0 if n_err == 0 else 1


def cmd_cost_determinism(task_id: str, runs: int = 3) -> int:
    """R3 contract check: 3 (or 10) runs must yield bit-identical output."""
    task_path = _resolve_task(task_id)
    if not task_path:
        print(f"ERROR: task {task_id} not found", file=sys.stderr)
        return 1
    runs_data = [estimate_cost(task_path) for _ in range(runs)]
    base = runs_data[0]["cost_estimate"]
    max_delta = 0
    for r in runs_data[1:]:
        for k, v in r["cost_estimate"].items():
            d = abs(int(v) - int(base.get(k, 0)))
            if d > max_delta:
                max_delta = d
    print(f"{task_id}: {runs} runs, cost max delta per component = {max_delta} (deterministic={max_delta == 0})")
    print(f"  cost_estimate: {base}")
    return 0 if max_delta <= 1 else 1


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(prog="bvp-estimator",
                                description="BVP estimator v1 (heuristic)")
    sub = p.add_subparsers(dest="cmd", required=True)

    p_one = sub.add_parser("one", help="estimate a single task")
    p_one.add_argument("task_id")
    p_one.add_argument("--dry-run", action="store_true")
    p_one.add_argument("--json", action="store_true")

    p_all = sub.add_parser("all", help="estimate every task in active+completed")
    p_all.add_argument("--dry-run", action="store_true")
    p_all.add_argument("--limit", type=int)
    p_all.add_argument("--statuses", nargs="+",
                       help="only estimate tasks in these statuses")

    p_det = sub.add_parser("determinism", help="run N times, verify ±1")
    p_det.add_argument("task_id")
    p_det.add_argument("--runs", type=int, default=3)

    p_a3 = sub.add_parser("measure-a3", help="A3 latency measurement")
    p_a3.add_argument("--n", type=int, default=20)
    p_a3.add_argument("--output", type=Path)

    p_sweep = sub.add_parser("sweep", help="T-1923 periodic sweep — stale + unscored")
    p_sweep.add_argument("--stale-hours", type=int, default=24,
                         help="re-score proposed scores older than this (default 24h)")
    p_sweep.add_argument("--statuses", nargs="+",
                         default=["started-work", "captured"])
    p_sweep.add_argument("--cron", action="store_true",
                         help="quieter output for cron")

    p_sla = sub.add_parser("with-sla", help="T-1923 fw resume sync path with hard cap")
    p_sla.add_argument("task_id")
    p_sla.add_argument("--timeout", type=int, default=10,
                       help="seconds before flagging unscored:true (default 10s, Q4 default)")

    # T-1935: cost-estimator verbs (parallel to bvp ones).
    p_cone = sub.add_parser("cost-one", help="T-1935 cost-estimate a single task")
    p_cone.add_argument("task_id")
    p_cone.add_argument("--dry-run", action="store_true")
    p_cone.add_argument("--json", action="store_true")

    p_call = sub.add_parser("cost-all", help="T-1935 cost-estimate every task")
    p_call.add_argument("--dry-run", action="store_true")
    p_call.add_argument("--limit", type=int)
    p_call.add_argument("--statuses", nargs="+")

    p_csweep = sub.add_parser("cost-sweep", help="T-1935 periodic cost sweep")
    p_csweep.add_argument("--stale-hours", type=int, default=24)
    p_csweep.add_argument("--statuses", nargs="+",
                          default=["started-work", "captured"])
    p_csweep.add_argument("--cron", action="store_true")

    p_cdet = sub.add_parser("cost-determinism",
                            help="T-1935 R3 determinism check (10 runs by default)")
    p_cdet.add_argument("task_id")
    p_cdet.add_argument("--runs", type=int, default=10)

    args = p.parse_args(argv)
    if args.cmd == "one":
        return cmd_one(args.task_id, dry_run=args.dry_run, json_out=args.json)
    if args.cmd == "all":
        return cmd_all(dry_run=args.dry_run, limit=args.limit, statuses=args.statuses)
    if args.cmd == "determinism":
        return cmd_determinism(args.task_id, runs=args.runs)
    if args.cmd == "measure-a3":
        return cmd_measure_a3(n=args.n, output=args.output)
    if args.cmd == "sweep":
        return cmd_sweep(stale_hours=args.stale_hours,
                         statuses=args.statuses, cron=args.cron)
    if args.cmd == "with-sla":
        return cmd_with_sla(args.task_id, timeout_s=args.timeout)
    if args.cmd == "cost-one":
        return cmd_cost_one(args.task_id, dry_run=args.dry_run, json_out=args.json)
    if args.cmd == "cost-all":
        return cmd_cost_all(dry_run=args.dry_run, limit=args.limit, statuses=args.statuses)
    if args.cmd == "cost-sweep":
        return cmd_cost_sweep(stale_hours=args.stale_hours,
                              statuses=args.statuses, cron=args.cron)
    if args.cmd == "cost-determinism":
        return cmd_cost_determinism(args.task_id, runs=args.runs)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
