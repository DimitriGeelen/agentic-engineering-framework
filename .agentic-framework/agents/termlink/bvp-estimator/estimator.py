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


def _str_safe_load(text):
    """PyYAML safe_load with the implicit timestamp resolver removed, so unquoted
    ISO `2026-06-02T00:00:00Z` datetimes round-trip as strings instead of being
    parsed to a datetime and re-emitted as `2026-06-02 00:00:00+00:00` (which
    churns frontmatter and breaks `...Z`-expecting readers). Used ONLY on the
    no-ruamel fallback path — ruamel round-trip already preserves them.
    Origin: OBS-085 / L-495 (the integrate.py:_str_loader fix, shared here)."""
    class _L(yaml.SafeLoader):
        pass
    _L.yaml_implicit_resolvers = {
        ch: [(t, rx) for t, rx in res if t != "tag:yaml.org,2002:timestamp"]
        for ch, res in yaml.SafeLoader.yaml_implicit_resolvers.items()
    }
    return yaml.load(text, Loader=_L)

PROJECT_ROOT = Path(os.environ.get("PROJECT_ROOT") or
                    os.environ.get("FRAMEWORK_ROOT") or
                    Path(__file__).resolve().parents[3])
RUBRIC_PATH = PROJECT_ROOT / "policy" / "bvp-scoring-rubric.md"
POLICY_PATH = PROJECT_ROOT / "policy" / "value-drivers.yaml"
ARCS_DIR = PROJECT_ROOT / ".context" / "arcs"

_FM_RE = re.compile(r"^---\n(.*?)\n---\n?(.*)\Z", re.S)


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def _atomic_write_text(path: Path, text: str) -> None:
    """T-100191: same-dir temp + os.replace — a kill mid-write must not truncate
    task frontmatter (L-493 non-atomic-YAML-write class)."""
    tmp = Path(str(path) + ".tmp")
    tmp.write_text(text)
    os.replace(tmp, path)


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


def _arc_scoped_drivers_for_task(fm: dict) -> dict[str, int]:
    """T-2357 — return {driver_id: weight} from the task's arc's scoped_drivers.

    Resolves the task's `arc_id:` frontmatter to `.context/arcs/<arc_id>.yaml`
    (slug form, T-1849), falling back to a `arc-NNN` dual-form scan that
    matches each arc YAML's top-level `id:` or `slug:`. Returns the operator-
    approved `scoped_drivers:` map (driver_id → weight). Empty on any
    missing/error path: no arc_id, file missing, YAML parse error, empty
    scoped_drivers.

    Read-only; never mutates arc YAMLs. Does NOT consult
    proposed_scoped_drivers: — only operator-approved scoped_drivers: fires
    here (Sovereignty boundary, T-1924).

    Activates the LATENT handlers shipped in T-2356 (score_d_disjoint,
    score_d_wire_evidence) for arc-tagged tasks. Once the operator approves
    the proposed_scoped_drivers via Watchtower (`fw arc approve-driver
    arc-011 D-DISJOINT --weight 5 --from-watchtower` + same for
    D-WIRE-EVIDENCE), this helper yields them and estimate_task() dispatches.
    """
    arc_id = fm.get("arc_id")
    if not arc_id or not isinstance(arc_id, str):
        return {}

    # Slug form first (cheapest path)
    direct = ARCS_DIR / f"{arc_id}.yaml"
    arc_data: dict | None = None
    if direct.is_file():
        try:
            arc_data = yaml.safe_load(direct.read_text()) or {}
        except yaml.YAMLError:
            return {}
    else:
        # arc-NNN dual-form fallback (T-1849: arc_id may be `arc-011` while
        # the file lives at slug `parallel-execution-aef.yaml`).
        if ARCS_DIR.is_dir():
            for arc_yaml in sorted(ARCS_DIR.glob("*.yaml")):
                try:
                    candidate = yaml.safe_load(arc_yaml.read_text()) or {}
                except yaml.YAMLError:
                    continue
                if (candidate.get("id") == arc_id
                        or candidate.get("slug") == arc_id):
                    arc_data = candidate
                    break

    if not arc_data:
        return {}

    out: dict[str, int] = {}
    for sd in (arc_data.get("scoped_drivers") or []):
        if not isinstance(sd, dict):
            continue
        # T-2358: lib/arc.sh:1258 writes scoped_drivers as `{name, weight,
        # approved_at}` with NO `id:` field (canonical write path). arc-011's
        # `id: D-DISJOINT` shape is the outlier (T-2344 retroactive prompt
        # template). Accept whichever is present, preferring `id` for
        # backwards-compat with arc-011.
        d_key = sd.get("id") or sd.get("name")
        if not d_key or not isinstance(d_key, str):
            continue
        try:
            w = int(sd.get("weight") or 0)
        except (TypeError, ValueError):
            w = 0
        out[d_key] = w
    return out


def _load_driver_aliases() -> dict[str, str]:
    """T-2343: return `{id: name}` for free drivers whose `name:` differs from `id`.

    Lets dispatch reach dedicated handlers when the policy `id` is opaque
    (e.g. F3 for V_PROMPT_QUALITY). Read-only; no policy mutation. Drivers
    without a `name:` field are omitted (no alias needed).
    """
    if not POLICY_PATH.is_file():
        return {}
    try:
        policy = yaml.safe_load(POLICY_PATH.read_text()) or {}
    except yaml.YAMLError:
        return {}
    aliases: dict[str, str] = {}
    for d in (policy.get("free_drivers") or []):
        d_id = d.get("id")
        d_name = d.get("name")
        if d_id and d_name and isinstance(d_name, str) and d_name != d_id:
            aliases[d_id] = d_name
    return aliases


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


def score_v_prompt_quality(fm: dict, body: str, tags: list[str]) -> tuple[int, list[str]]:
    """V_PROMPT_QUALITY — LLM-prompt quality improvement.

    T-2328. Anchored to docs/reports/T-2305-bvp-drivers-batch-2026-06-10.md §5.1.

    Rubric:
      0: No prompt-related work.
      1: Touches a prompt incidentally (changes a prompt string with no quality intent).
      2: Minor improvement (typo, wording cleanup in an instruction).
      3: Meaningful improvement (adds worked example, refines instruction, improves rubric).
      4: Material improvement (new prompt-handler design, restructured patterns, multi-section refinement).
      5: Foundational (new prompt-creation system, framework-level prompt-template patterns,
         prompt-bundle that becomes pattern for other prompts).
    """
    ev: list[str] = []
    comps = _components_text(fm)

    prompt_touch_comps = _has_any(comps, [
        r"policy/prompts/", r"agents/[a-z_-]+/(prompt|preamble)",
        r"policy/bvp-scoring-rubric", r"policy/prompts/bvp-driver-session",
        r"docs/dispatch-templates/",
    ])
    prompt_touch_body = _has_any(body, [
        r"\bprompt\b", r"\binstruction\b", r"\brubric\b", r"\bpickup prompt\b",
        r"prompt[- ](bundle|template|handler|file|skeleton|surface|library)",
    ])
    if not (prompt_touch_comps or prompt_touch_body):
        return 0, ev + ["→0 (no prompt signal)"]

    foundational = _has_any(body, [
        r"new prompt[- ]creation system",
        r"framework[- ]level prompt[- ]template",
        r"prompt[- ]bundle (that )?becomes (a |the )?pattern",
        r"new prompt (subsystem|architecture)",
        r"prompt[- ]library", r"prompt[- ]bundle pattern",
        r"canonical prompt[- ]bundle",
    ])
    if foundational:
        ev.append("body:prompt-foundational")
        return 5, ev + ["→5 (foundational prompt-creation system)"]

    material = _has_any(body, [
        r"new prompt[- ]handler",
        r"restructured (instruction|prompt) (pattern|surface)",
        r"multi[- ]section (prompt )?(refinement|restructure)",
        r"new pickup prompt",
        r"prompt[- ]handler design",
        r"(workflow|sharpening) (prompt|bundle)",
        r"(new |re)design.{0,30}prompt",
    ])
    if material:
        ev.append("body:prompt-material")
        return 4, ev + ["→4 (material prompt restructure)"]

    meaningful = _has_any(body, [
        r"worked example", r"refines? (an? |the )?instruction",
        r"improves? (an? |the )?rubric", r"rubric improvement",
        r"adds? (an? |the )?rubric (level|narrative)",
        r"prompt (improvement|refinement|sharpening)",
        r"scoring[- ]level narrative",
    ])
    if meaningful:
        ev.append("body:prompt-meaningful")
        return 3, ev + ["→3 (meaningful prompt improvement)"]

    minor = _has_any(body, [
        r"fix(es|ed)? (a )?typo in (a |the )?(prompt|instruction|rubric)",
        r"clarif(y|ies|ied) (a |the )?wording",
        r"wording cleanup", r"prompt (wording|cleanup)",
        r"small (prompt|instruction) (cleanup|tweak|fix)",
    ])
    if minor:
        ev.append("body:prompt-minor")
        return 2, ev + ["→2 (minor prompt cleanup)"]

    if prompt_touch_comps or prompt_touch_body:
        ev.append("body/components:prompt-incidental")
        return 1, ev + ["→1 (incidental prompt touch)"]

    return 0, ev + ["→0 (no prompt signal)"]


def score_v_context_fabric(fm: dict, body: str, tags: list[str]) -> tuple[int, list[str]]:
    """V_CONTEXT_FABRIC — memory-layer (working/project/episodic + semantic search).

    T-2328. Anchored to docs/reports/T-2305-bvp-drivers-batch-2026-06-10.md §5.2.

    Rubric:
      0: No Context Fabric work.
      1: Incidental touch (calls fw recall for diagnostics).
      2: Minor improvement (handover bugfix, fw recall reliability fix, doc improvement).
      3: Meaningful improvement (new memory feature, perf optimization, new audit check
         for Context Fabric correctness).
      4: Material improvement (new memory layer addition, retrieval-quality baseline
         measurement, structural Context Fabric enhancement).
      5: Foundational change (new memory architecture, embedder replacement with
         measured quality improvement, new memory primitive).
    """
    ev: list[str] = []
    comps = _components_text(fm)

    fabric_touch_comps = _has_any(comps, [
        r"\.context/working", r"\.context/episodic", r"\.context/project",
        r"\.context/handovers",
        r"lib/recall", r"lib/synthesis", r"lib/embeddings", r"lib/index",
        r"agents/recall", r"agents/condensation", r"agents/handover",
        r"agents/context", r"agents/session-capture",
        r"web/blueprints/recall", r"web/blueprints/handovers",
        r"qdrant",
    ])
    fabric_touch_body = _has_any(body, [
        r"\bContext Fabric\b", r"\b(working|project|episodic) memory\b",
        r"\bfw recall\b", r"\bfw ask\b", r"semantic search",
        r"\bmemory (layer|primitive|architecture|substrate|feature|capture)\b",
        r"\bnew memory\b", r"memory (correctness|integrity)",
        r"handover (file|document|generation|format|bug|fix)",
        r"retrieval[- ](layer|quality|engine|baseline)",
        r"embedder", r"embeddings? (substrate|index|store|model)",
        r"\bepisodic (entry|capture|summary|memory)\b",
    ])
    if not (fabric_touch_comps or fabric_touch_body):
        return 0, ev + ["→0 (no Context Fabric signal)"]

    foundational = _has_any(body, [
        r"new memory architecture",
        r"new memory primitive",
        r"embedder replacement", r"embedder upgrade",
        r"new (working|project|episodic) memory (layer|surface)",
        r"foundational (Context Fabric|memory) (change|overhaul)",
        r"measured (retrieval|recall) quality (improvement|baseline)",
    ])
    if foundational:
        ev.append("body:context-fabric-foundational")
        return 5, ev + ["→5 (foundational Context Fabric change)"]

    material = _has_any(body, [
        r"retrieval[- ]quality baseline",
        r"memory[- ]layer addition",
        r"structural Context Fabric",
        r"new (memory|context) (layer|store|surface)",
        r"comprehensive (handover|memory) (restructure|enhancement)",
        r"semantic (search|index) (rebuild|substrate)",
    ])
    if material:
        ev.append("body:context-fabric-material")
        return 4, ev + ["→4 (material Context Fabric enhancement)"]

    meaningful = _has_any(body, [
        r"new memory (feature|capture|primitive)",
        r"(performance|perf) optimi(s|z)ation.{0,30}(memory|recall|handover|episodic)",
        r"new audit check.{0,30}Context Fabric",
        r"Context Fabric audit",
        r"memory (correctness|integrity) check",
        r"new (handover|episodic|recall) (feature|capability)",
        r"fw recall (improvement|enhancement|quality)",
    ])
    if meaningful:
        ev.append("body:context-fabric-meaningful")
        return 3, ev + ["→3 (meaningful Context Fabric improvement)"]

    minor = _has_any(body, [
        r"handover (bugfix|fix|bug)",
        r"fw recall (bug|fix|reliability)",
        r"memory (doc|documentation) improvement",
        r"small (memory|handover|episodic) (cleanup|fix)",
    ])
    if minor:
        ev.append("body:context-fabric-minor")
        return 2, ev + ["→2 (minor Context Fabric fix)"]

    if fabric_touch_comps or fabric_touch_body:
        ev.append("body/components:context-fabric-incidental")
        return 1, ev + ["→1 (incidental Context Fabric touch)"]

    return 0, ev + ["→0 (no Context Fabric signal)"]


def score_v_component_fabric(fm: dict, body: str, tags: list[str]) -> tuple[int, list[str]]:
    """V_COMPONENT_FABRIC — topology layer (dependency mapping, blast-radius, drift).

    T-2328. Anchored to docs/reports/T-2305-bvp-drivers-batch-2026-06-10.md §5.3.

    Rubric:
      0: No Component Fabric work.
      1: Incidental touch (runs fw fabric for diagnostic purposes).
      2: Minor improvement (bug fix in dependency detection, small speed improvement).
      3: Meaningful improvement (new fabric check, accuracy improvement, drift-detection enhancement).
      4: Material improvement (major restructuring of dependency representation,
         comprehensive blast-radius accuracy work).
      5: Foundational change (new topology primitive, fundamentally improved drift detection,
         structural Component Fabric overhaul).
    """
    ev: list[str] = []
    comps = _components_text(fm)

    fabric_touch_comps = _has_any(comps, [
        r"lib/fabric", r"agents/fabric", r"\.fabric/",
        r"web/blueprints/fabric", r"web/templates/fabric",
    ])
    fabric_touch_body = _has_any(body, [
        r"\bComponent Fabric\b",
        r"\bfw fabric\b", r"\bfabric (check|gate|audit|accuracy|drift|enrich)\b",
        r"\b(blast[- ]radius|dependency mapping|dependency detection)\b",
        r"\bfabric drift\b", r"\bdrift detection\b",
        r"\btopology (primitive|layer|map)\b",
        r"component card", r"\.fabric/components",
        r"\bnew fabric\b",
    ])
    if not (fabric_touch_comps or fabric_touch_body):
        return 0, ev + ["→0 (no Component Fabric signal)"]

    foundational = _has_any(body, [
        r"new topology primitive",
        r"Component Fabric overhaul",
        r"fundamentally improved drift detection",
        r"structural (Component Fabric|topology) (overhaul|change)",
        r"new fabric (architecture|substrate)",
    ])
    if foundational:
        ev.append("body:component-fabric-foundational")
        return 5, ev + ["→5 (foundational Component Fabric change)"]

    material = _has_any(body, [
        r"major restructur(ing|e).{0,30}dependency",
        r"dependency representation (restructure|overhaul)",
        r"comprehensive blast[- ]radius (accuracy|work)",
        r"fabric (re)?structure",
        r"new (component|fabric) (surface|registration|model)",
    ])
    if material:
        ev.append("body:component-fabric-material")
        return 4, ev + ["→4 (material Component Fabric restructure)"]

    meaningful = _has_any(body, [
        r"new fabric check",
        r"fabric accuracy", r"accuracy (improvement|enhancement).{0,30}(fabric|dependency)",
        r"drift[- ]detection (enhancement|improvement)",
        r"blast[- ]radius (improvement|accuracy)",
        r"new (component|fabric) (audit|gate)",
    ])
    if meaningful:
        ev.append("body:component-fabric-meaningful")
        return 3, ev + ["→3 (meaningful Component Fabric improvement)"]

    minor = _has_any(body, [
        r"dependency detection (fix|bug)",
        r"fabric (speed|perf|bug) (fix|improvement)",
        r"small fabric (fix|cleanup)",
        r"\bfix(es|ed)? fabric\b",
    ])
    if minor:
        ev.append("body:component-fabric-minor")
        return 2, ev + ["→2 (minor Component Fabric fix)"]

    if fabric_touch_comps or fabric_touch_body:
        ev.append("body/components:component-fabric-incidental")
        return 1, ev + ["→1 (incidental Component Fabric touch)"]

    return 0, ev + ["→0 (no Component Fabric signal)"]


def score_f_autonomy(fm: dict, body: str, tags: list[str]) -> tuple[int, list[str]]:
    """F-AUTONOMY — Autonomy / Unattended Operation.

    T-2329 (sibling of T-2171 AC#5). Anchored to policy/value-drivers.yaml
    lines 171-195 (currently carved/commented; activation gated by T-2171
    when T-2158 continuous-run cycle lands + L5/L6 milestone operational).
    Handler stays LATENT until policy uncomments the carve — `_load_drivers()`
    won't yield F-AUTONOMY, so estimate_task() won't dispatch here.

    Rubric (policy lines 178-188):
      0: Adds nothing, OR would remove a safety-critical human gate
         (Sovereignty violation — ZERO, never high).
      1: Runs unattended only by hand-wiring; no durable reduction.
      2: Narrow, single-use reduction in human relay.
      3: Closes a feedback loop so signal reaches ACTION without human relay.
      4: Class of low-risk work safely auto-eligible (auto_promote bounded), caps intact.
      5: Replaces REDUNDANT human gate with at-least-as-safe mechanical one,
         or lands L6 autonomy criterion. NEVER removes Tier 0.

    Refuse-rule (R5 sibling, T-2168 F-ORCH precedent): if body indicates
    REMOVING a Tier-0 / safety-critical / irreversible gate without naming
    an at-least-as-safe mechanical replacement, return 0 with rationale
    `f-autonomy-refuse:sovereignty-violation`. Anchors on the policy
    guardrail text (lines 189-192) and CLAUDE.md §Authority Model.
    """
    ev: list[str] = []
    comps = _components_text(fm)

    # ---- R5 refuse-rule (Sovereignty guardrail) ---------------------------
    # Body says "remove tier 0 gate" / "bypass safety gate" / "skip approval"
    # WITHOUT also citing an at-least-as-safe mechanical replacement → 0.
    sovereignty_remove = _has_any(body, [
        r"remov(e|ing|al) (the|a) tier[- ]?0 (gate|approval|check)",
        r"remov(e|ing|al) (the|a) safety[- ]critical (gate|check|approval)",
        r"bypass (the|a) (safety|tier[- ]?0|irreversible) (gate|check|approval)",
        r"remov(e|ing) (the|a)? ?human approval (for|on)",
        r"skip (the|a) tier[- ]?0",
        r"disable (the|a) (safety|tier[- ]?0|approval) (gate|check)",
        r"remove (the|a) approval requirement",
        r"remove (the|a) tier[- ]?0 approval requirement",
    ])
    safe_replacement = _has_any(body, [
        r"at[- ]least[- ]as[- ]safe", r"mechanical (replacement|equivalent|check)",
        r"structural (gate|check) replac",
        r"replac(e|es|ing) (a |the |redundant )?human gate",
    ])
    if sovereignty_remove and not safe_replacement:
        return 0, ev + ["body:sovereignty-remove-without-replacement",
                        "→0 (f-autonomy-refuse:sovereignty-violation)"]

    # ---- Level 5 — replaces REDUNDANT human gate, or lands L6 ------------
    # MUST be at-least-as-safe; MUST NOT remove Tier 0.
    redundant_gate_replace = _has_any(body, [
        r"replac(e|es|ing) (a |the )?redundant human gate",
        r"replac(e|es|ing) (a |the )?human gate with (a |an )?(at[- ]least[- ]as[- ]safe |mechanical )",
        r"l6 autonomy criterion",
        r"closed production[- ]feedback loop",
        r"\bauto[- ]merge (lands|operational|green)",
    ])
    # Defense-in-depth: even at level 5, refuse if Tier-0 removal is implied
    if redundant_gate_replace and not sovereignty_remove:
        ev.append("body:redundant-gate-replace-or-L6")
        return 5, ev + ["→5 (redundant human gate replaced with mechanical, or L6 lands)"]

    # ---- Level 4 — class of low-risk work safely auto-eligible ----------
    auto_promote_class = _has_any(body, [
        r"auto[- ]?promot(e|ion|able)",
        r"\bauto[- ]eligible\b",
        r"hv/lc.*(captured|in[- ]progress).*auto",
        r"class of low[- ]risk work.*auto",
        r"caps? intact",
        r"safely auto[- ]advances?",
    ])
    if auto_promote_class:
        ev.append("body:auto-promote-class-eligibility")
        return 4, ev + ["→4 (low-risk-class auto-eligibility with caps)"]

    # ---- Level 3 — closes feedback loop signal→ACTION without human ----
    feedback_close = _has_any(body, [
        r"clos(e|es|ing) (a |the )?(feedback )?loop",
        r"wires? (observation|signal|feedback) (back )?into (dispatch|action)",
        r"signal[- ]?to[- ]?action without (a )?human",
        r"observation feedback (back )?into dispatch",
        r"feedback loop (without|sans) (a )?human relay",
        r"reaches? action without (a )?human relay",
    ])
    if feedback_close:
        ev.append("body:feedback-loop-closed")
        return 3, ev + ["→3 (feedback loop closes signal→action without human relay)"]

    # ---- Level 2 — narrow single-use reduction in human relay ----------
    narrow_reduce = _has_any(body, [
        r"narrow.{0,20}reduction in human (relay|touch|gate)",
        r"single[- ]use.{0,20}(automation|reduction)",
        r"one[- ]off.{0,20}(automation|gate removal)",
        r"reduc(e|es|ing) (a |one )?human (relay|touchpoint|step)",
    ])
    if narrow_reduce:
        ev.append("body:narrow-single-use-reduction")
        return 2, ev + ["→2 (narrow single-use human-relay reduction)"]

    # ---- Level 1 — hand-wired unattended only, no durable reduction ----
    hand_wired = _has_any(body, [
        r"hand[- ]wired (unattended|run|automation)",
        r"runs? unattended (only )?by hand[- ]wiring",
        r"manual (setup|wiring) for unattended",
        r"no durable reduction",
    ])
    if hand_wired:
        ev.append("body:hand-wired-unattended")
        return 1, ev + ["→1 (hand-wired unattended; no durable reduction)"]

    return 0, ev + ["→0 (no autonomy signal)"]


def score_d_disjoint(fm: dict, body: str, tags: list[str]) -> tuple[int, list[str]]:
    """D-DISJOINT — Disjoint Write-Set Discipline (arc-011 scoped).

    T-2356. Anchored to docs/reports/T-2344-bvp-driver-arc-011.md §Candidate 1.
    Proposed in .context/arcs/parallel-execution-aef.yaml proposed_scoped_drivers
    with weight 5.

    Handler stays LATENT until two events: (1) operator approves the arc-scoped
    driver via Watchtower (`fw arc approve-driver arc-011 D-DISJOINT --weight 5
    --from-watchtower`), AND (2) the estimator's `estimate_task()` dispatch loop
    is extended to resolve arc-scoped drivers when the task's `arc_id:` matches
    an arc with `scoped_drivers:` populated. `_load_drivers()` reads only the
    global policy/value-drivers.yaml today, so this handler is reachable from
    the handlers dict but the dispatch loop never asks for it.

    Rubric (T-2344 §Candidate 1):
      0: No disjointness signal (no write-set / collision / concurrent-write mention).
      1: Incidental reference (mentions disjointness narratively, no structural artefact).
      2: Partial declaration / lint (ad-hoc write-set documentation, convention).
      3: Component-level write-set test (unit test for collision detection,
         lib/write_set.py callable helper, not yet gate-wired).
      4: Framework-level pre-flight gate (PreToolUse hook / `fw write-set check` CLI /
         audit FAIL on overlap — STRUCTURALLY refuses dispatch).
      5: New structural invariant class (mechanism that makes disjointness violation
         structurally impossible at dispatch-envelope construction; new gate type).

    Rewards PRE-FLIGHT collision refusal — distinguishes from D2 (Reliability) which
    rewards POST-HOC observability of the same failure class.
    """
    ev: list[str] = []
    comps = _components_text(fm)

    # Components that signal write-set work
    write_set_comps = _has_any(comps, [
        r"lib/write_?set", r"write[_-]?set\.py",
        r"tests/.*write[_-]?set", r"fw[_-]write[-_]?set",
        r"bin/fw write-set",
    ])
    write_set_body = _has_any(body, [
        r"\bdisjoint(ness)?\b", r"\bwrite[- _]?set\b", r"\bdisjoint write[- _]?set\b",
        r"collision (refusal|prevention|detection|gate)",
        r"concurrent (write|edit) (collision|conflict)",
        r"\bpre[- ]?flight (collision|disjoint|write[- ]?set|gate)",
        r"\bgovernance[- ]plane (corruption|conflict)\b",
    ])
    if not (write_set_comps or write_set_body):
        return 0, ev + ["→0 (no disjointness signal)"]

    # ---- Level 5 — new structural invariant class ----------------------
    new_class = _has_any(body, [
        r"new structural invariant",
        r"new (sovereignty boundary|gate type) (for|on) (write[- ]?set|disjoint)",
        r"structurally impossible.{0,40}(collision|overlap|disjoint)",
        r"capability[- ]overlay.{0,40}(write[- ]?set|disjoint)",
        r"new (mechanism|class) (for )?write[- ]?set (isolation|enforcement)",
        r"dispatch[- ]envelope (write[- ]?set|disjoint) (enforcement|construction)",
    ])
    if new_class:
        ev.append("body:disjoint-new-class")
        return 5, ev + ["→5 (new structural invariant class for disjointness)"]

    # ---- Level 4 — framework-level pre-flight gate ----------------------
    gate = _has_any(body, [
        r"PreToolUse hook.{0,40}(write[- ]?set|disjoint|collision|overlap)",
        r"PostToolUse hook.{0,40}(write[- ]?set|disjoint|collision)",
        r"completion gate.{0,40}(write[- ]?set|disjoint)",
        r"fw write-set check",
        r"audit FAIL.{0,40}(write[- ]?set|disjoint|collision|overlap)",
        r"audit WARN.{0,40}(write[- ]?set|disjoint|collision|overlap)",
        r"structural(ly)? refuses?.{0,40}(dispatch|write[- ]?set|disjoint)",
        r"refuses? (the )?dispatch.{0,40}(overlap|collision|disjoint)",
        r"(disjoint(ness)?|write[- ]?set) (gate|enforcement|verifier)",
    ])
    if gate:
        ev.append("body:framework-disjoint-gate")
        return 4, ev + ["→4 (framework-level disjoint pre-flight gate)"]

    # ---- Level 3 — component-level write-set test or helper ------------
    component_test = _has_any(body, [
        r"(unit|regression|integration) test.{0,40}(write[- ]?set|disjoint|collision)",
        r"tests?/.*write[- ]?set",
        r"lib/write[_-]?set",
        r"write[- ]?set (validator|helper|util|module)",
        r"collision (test|detector|check) (in|added)",
    ])
    # Heavy component touch — write-set / disjoint code edited
    component_touch = _has_any(comps, [
        r"lib/write[_-]?set", r"tests/.*write[_-]?set",
    ])
    if component_test or component_touch:
        if component_test:
            ev.append("body:disjoint-component-test")
        if component_touch:
            ev.append("components:write-set-code")
        return 3, ev + ["→3 (component-level write-set test/helper)"]

    # ---- Level 2 — partial declaration / lint / documentation ----------
    partial = _has_any(body, [
        r"\bwrite[- _]?set:?\s*(scope|declaration|fields?)",
        r"declare(s|d)?.{0,30}(write[- ]?set|scope)",
        r"(disjoint(ness)?|write[- ]?set) (lint|convention|documentation|discipline)",
        r"ad[- ]hoc (write[- ]?set|disjoint)",
        r"(disjoint(ness)?|write[- ]?set) (policy|spec)",
    ])
    if partial:
        ev.append("body:disjoint-partial-or-lint")
        return 2, ev + ["→2 (partial declaration / lint / documentation)"]

    # ---- Level 1 — incidental reference --------------------------------
    if write_set_body or write_set_comps:
        ev.append("body/components:disjoint-incidental")
        return 1, ev + ["→1 (incidental disjointness reference)"]

    return 0, ev + ["→0 (no disjointness signal)"]


def score_d_wire_evidence(fm: dict, body: str, tags: list[str]) -> tuple[int, list[str]]:
    """D-WIRE-EVIDENCE — Wire-Evidence Falsifiability (arc-011 scoped).

    T-2356. Anchored to docs/reports/T-2344-bvp-driver-arc-011.md §Candidate 2.
    Proposed in .context/arcs/parallel-execution-aef.yaml proposed_scoped_drivers
    with weight 4.

    Handler stays LATENT until two events: (1) operator approves the arc-scoped
    driver via Watchtower (`fw arc approve-driver arc-011 D-WIRE-EVIDENCE
    --weight 4 --from-watchtower`), AND (2) the estimator's `estimate_task()`
    dispatch loop is extended to resolve arc-scoped drivers when the task's
    `arc_id:` matches an arc with `scoped_drivers:` populated.

    Rubric (T-2344 §Candidate 2):
      0: No wire-evidence signal.
      1: Incidental log reference (narrative "log says X" without captured artefact).
      2: Narrative claim + one re-runnable command in body (no persisted excerpt).
      3: Component-level evidence artefact (docs/reports evidence file with embedded
         jsonl excerpts + timing.yaml — outside party can re-check by re-running).
      4: Framework-level wire-evidence capture surface (Watchtower page / CLI verb
         that reads dispatches.jsonl / auto-refreshes; `fw orchestrator status`).
      5: New falsifiability primitive class (every dispatch auto-writes wire-evidence
         YAML; structural mechanism makes claim-without-evidence impossible).

    Rewards CAPTURED, RE-RUNNABLE artefacts tied to a specific arc claim. Counters
    G-062 substrate-vs-deliverable conflation at arc-close time. Distinguishes from
    D2 (Reliability) which is satisfied by a log line; this driver requires the
    evidence be re-runnable by an outside party.
    """
    ev: list[str] = []
    comps = _components_text(fm)

    # Components that signal evidence-capture work
    evidence_comps = _has_any(comps, [
        r"\.context/dispatches\.jsonl", r"dispatches\.jsonl",
        r"\.context/dispatch-outcomes\.jsonl", r"dispatch-outcomes\.jsonl",
        r"docs/reports/arc-\d+.*evidence",
        r"web/blueprints/orchestrator", r"web/templates/orchestrator",
        r"fw orchestrator", r"agents/dispatch/", r"timing\.yaml",
    ])
    evidence_body = _has_any(body, [
        r"\bwire[- ]evidence\b", r"\bwire artefact(s)?\b",
        r"\bdispatches?\.jsonl\b",
        r"dispatch[- ]outcomes\.jsonl",
        r"timing\.yaml", r"git status snapshot",
        r"\bfalsifiab(le|ility)\b", r"\bre[- ]runnable\b",
        r"captured (wire )?artefact", r"captured evidence",
        r"headline[- ]mechanic.{0,40}(evidence|fire|captured)",
        r"evidence (file|capture|excerpt|artefact)",
    ])
    if not (evidence_comps or evidence_body):
        return 0, ev + ["→0 (no wire-evidence signal)"]

    # ---- Level 5 — new falsifiability primitive class -------------------
    new_class = _has_any(body, [
        r"new falsifiabil(ity|ities) primitive",
        r"every dispatch auto[- ]writes? (wire )?evidence",
        r"structural(ly)? (mechanism|gate) (makes|prevents) claim[- ]without[- ]evidence",
        r"new (wire )?evidence (primitive|class|mechanism|substrate)",
        r"auto[- ](capture|emit)d? (wire[- ]?)?evidence (yaml|file|row)",
        r"evidence (auto[- ]written|auto[- ]captured) (per|alongside) (dispatch|outcome)",
    ])
    if new_class:
        ev.append("body:wire-evidence-new-class")
        return 5, ev + ["→5 (new falsifiability primitive class)"]

    # ---- Level 4 — framework-level wire-evidence capture surface --------
    framework_surface = _has_any(body, [
        r"Watchtower (page|view|surface).{0,40}(dispatch|orchestrator|evidence|wire)",
        r"/orchestrator/parallel", r"/orchestrator (page|view)",
        r"reads? (\.context/)?dispatches\.jsonl",
        r"fw orchestrator (status|read|explain)",
        r"auto[- ]refreshe?s?.{0,40}(dispatch|evidence|wire)",
        r"htmx.{0,40}(dispatch|orchestrator|evidence|wire)",
        r"(in[- ]flight )?dispatch (cards|view|page)",
    ])
    if framework_surface:
        ev.append("body:framework-wire-evidence-surface")
        return 4, ev + ["→4 (framework-level wire-evidence capture surface)"]

    # ---- Level 3 — component-level evidence artefact -------------------
    component_artefact = _has_any(body, [
        r"docs/reports/.*evidence",
        r"evidence (file|artefact).{0,40}(embedded|excerpts?|timing)",
        r"embedded (dispatches?\.jsonl|jsonl) excerpts?",
        r"captured (jsonl|dispatches) (excerpt|rows)",
        r"timing\.yaml (capture|file|artefact)",
        r"re[- ]runnable (evidence|artefact|capture)",
    ])
    component_touch = _has_any(comps, [
        r"docs/reports/arc-\d+.*evidence",
        r"\.context/dispatches\.jsonl", r"timing\.yaml",
    ])
    if component_artefact or component_touch:
        if component_artefact:
            ev.append("body:wire-evidence-component-artefact")
        if component_touch:
            ev.append("components:evidence-file")
        return 3, ev + ["→3 (component-level evidence artefact)"]

    # ---- Level 2 — narrative claim + one re-runnable command -----------
    narrative_plus_command = _has_any(body, [
        r"`(cat|jq|grep|tail).{0,80}(dispatches?\.jsonl|outcomes?\.jsonl)",
        r"`bin/fw (orchestrator|outcome) (status|read|list|explain)",
        r"`fw orchestrator",
        r"\bre[- ]run(nable)? command\b",
        r"narrative claim.{0,40}(re[- ]runnable|command)",
    ])
    if narrative_plus_command:
        ev.append("body:wire-evidence-narrative-plus-command")
        return 2, ev + ["→2 (narrative claim + one re-runnable command)"]

    # ---- Level 1 — incidental log reference ----------------------------
    if evidence_body or evidence_comps:
        ev.append("body/components:wire-evidence-incidental")
        return 1, ev + ["→1 (incidental log reference)"]

    return 0, ev + ["→0 (no wire-evidence signal)"]


def score_uncertainty_recognition(fm: dict, body: str, tags: list[str]) -> tuple[int, list[str]]:
    """uncertainty-recognition — arc-001 (dispatch-safety) scoped driver.

    T-2359. Anchored to .context/arcs/dispatch-safety.yaml proposed_scoped_drivers
    with weight 5. Rewards worker-DECISION-level recognition of "I don't have
    enough information to proceed safely" — distinct from D1 (Antifragility,
    framework-level stress-strengthening) and D2 (Reliability, framework-level
    no-silent-failures). This driver scores the worker's *epistemic act*
    (pause_requested, severity×likelihood self-assessment, risk-policy preamble).

    Handler stays LATENT until two events: (1) operator approves the arc-scoped
    driver via Watchtower (`fw arc approve-driver dispatch-safety
    uncertainty-recognition --weight 5 --from-watchtower`), AND (2) tasks
    tagged `arc_id: dispatch-safety` dispatch through `estimate_task()` —
    T-2357 already shipped the merge path so condition (2) is automatic once
    (1) lands.

    Rubric (anchored to arc-001 proposed driver rationale):
      0: No worker-DECISION uncertainty signal.
      1: Incidental uncertainty/pause mention (narrative, no structural artefact).
      2: Single risk-policy preamble addition / pause-flag wiring without rubric.
      3: Component-level pause-detection helper or test (e.g. lib/pause_request.py + test).
      4: Framework-level pause-detection gate / risk-policy enforcement hook /
         self-assessment rubric integrated into dispatch flow.
      5: New pause-detection mechanism class — self-assessment becomes a fw
         verb, new structural mechanism for worker-side uncertainty signalling,
         risk-policy preamble structurally enforced.
    """
    ev: list[str] = []
    comps = _components_text(fm)

    uncertainty_comps = _has_any(comps, [
        r"lib/pause", r"pause_request", r"risk[- ]policy",
        r"agents/dispatch/.*pause", r"agents/dispatch/.*risk",
        r"self[- ]assessment",
    ])
    uncertainty_body = _has_any(body, [
        r"\bpause[_-]?requested?\b", r"\bpause[- ]protocol\b",
        r"\bself[- ]assessment\b", r"severity[- _]?times[- _]?likelihood",
        r"severity.{0,10}likelihood", r"risk[- ]policy (preamble|score)",
        r"worker[- ](decision|side|epistemic|uncertainty)",
        r"\buncertainty (recognition|signal|signaling|signalling)\b",
        r"\bproceed safely\b",
        r"epistemic (act|recognition|self[- ]assessment)",
    ])
    if not (uncertainty_comps or uncertainty_body):
        return 0, ev + ["→0 (no uncertainty-recognition signal)"]

    # ---- Level 5 — new pause-detection class -----------------------------
    new_class = _has_any(body, [
        r"new pause[- ]detection (mechanism|class|primitive)",
        r"new self[- ]assessment (mechanism|primitive|class|verb)",
        r"self[- ]assessment becomes a fw verb",
        r"new (mechanism|class) (for )?worker[- ]side uncertainty",
        r"risk[- ]policy preamble structurally enforced",
        r"new pause[- ]protocol (class|mechanism)",
        r"structurally enforces? (the )?pause",
    ])
    if new_class:
        ev.append("body:uncertainty-recognition-new-class")
        return 5, ev + ["→5 (new pause-detection class)"]

    # ---- Level 4 — framework-level pause/risk gate ----------------------
    framework_gate = _has_any(body, [
        r"PreToolUse hook.{0,40}(pause|risk[- ]policy|self[- ]assessment)",
        r"PostToolUse hook.{0,40}(pause|risk[- ]policy)",
        r"audit FAIL.{0,40}(pause|uncertainty|risk[- ]policy)",
        r"audit WARN.{0,40}(pause|uncertainty|risk[- ]policy)",
        r"(risk[- ]policy|self[- ]assessment) (enforcement|hook|gate)",
        r"pause[- ]detection (hook|gate|enforcement)",
        r"framework[- ]level (pause|risk[- ]policy)",
    ])
    if framework_gate:
        ev.append("body:framework-pause-gate")
        return 4, ev + ["→4 (framework-level pause/risk gate)"]

    # ---- Level 3 — component-level pause-detection helper or test --------
    component = _has_any(body, [
        r"(unit|regression|integration) test.{0,40}(pause|uncertainty|risk[- ]policy)",
        r"tests?/.*pause", r"tests?/.*risk[- ]policy",
        r"lib/pause", r"pause[_-]request",
        r"pause[- ]detection (helper|util|module)",
        r"risk[- ]policy (helper|module|test)",
    ])
    component_touch = _has_any(comps, [
        r"lib/pause", r"tests/.*pause", r"risk[- ]policy",
    ])
    if component or component_touch:
        if component:
            ev.append("body:uncertainty-component")
        if component_touch:
            ev.append("components:pause-code")
        return 3, ev + ["→3 (component-level pause helper or test)"]

    # ---- Level 2 — single risk-policy preamble / threshold tweak --------
    single_tweak = _has_any(body, [
        r"(adds?|writes?) (a |the )?risk[- ]policy preamble",
        r"single (pause[- ]flag|risk[- ]policy) (addition|wiring)",
        r"adds? (a |the )?pause[- ]flag( wiring)?",
        r"tunes? (the )?(pause|risk[- ]policy) (threshold|flag)",
        r"narrow .{0,20}(pause|risk[- ]policy)",
    ])
    if single_tweak:
        ev.append("body:uncertainty-single-tweak")
        return 2, ev + ["→2 (single pause/risk-policy wiring)"]

    # ---- Level 1 — incidental --------------------------------------------
    if uncertainty_body or uncertainty_comps:
        ev.append("body/components:uncertainty-incidental")
        return 1, ev + ["→1 (incidental uncertainty mention)"]

    return 0, ev + ["→0 (no uncertainty-recognition signal)"]


def score_severity_likelihood_calibration(fm: dict, body: str, tags: list[str]) -> tuple[int, list[str]]:
    """severity-likelihood-calibration — arc-001 (dispatch-safety) scoped driver.

    T-2359. Anchored to .context/arcs/dispatch-safety.yaml proposed_scoped_drivers
    with weight 4. Rewards calibration quality of the pause-trigger threshold —
    distinct from D2's binary "emits / silent" observability floor. D2 is
    satisfied when ANY signal fires; this driver scores the *quality of when*
    pauses fire (false-positive rate → operator-cost waste; false-negative
    rate → wrong work shipped).

    Handler stays LATENT until operator approves the arc-scoped driver via
    Watchtower (same activation path as score_uncertainty_recognition).

    Rubric:
      0: No calibration signal.
      1: Incidental calibration mention (narrative, no measurement).
      2: Single threshold adjustment with rationale (one pause-flag tweak,
         documented).
      3: Component-level threshold-tuning test or audit script (e.g. compare
         pause rate against retrospective should-have-paused classification).
      4: Framework-level pause-rate audit / live calibration loop (recurring
         calibration check; audit emits WARN on threshold drift).
      5: New calibration mechanism class — live false-positive/false-negative
         auto-audit becomes a structural primitive (e.g. fw verb that compares
         live pause-rate against expected operator-cost budget).
    """
    ev: list[str] = []
    comps = _components_text(fm)

    calibration_comps = _has_any(comps, [
        r"calibration", r"pause[_-]rate", r"threshold[_-]tune",
        r"agents/dispatch/.*calibrat", r"tests/.*calibrat",
    ])
    calibration_body = _has_any(body, [
        r"severity[- ]likelihood (calibration|threshold|tuning)",
        r"\bcalibrat(e|es|ed|ing|ion)\b",
        r"\bfalse[- ]positive\b", r"\bfalse[- ]negative\b",
        r"pause[- ]trigger threshold",
        r"pause[- ]rate (audit|drift|monitoring)",
        r"should[- ]have[- ]paused.{0,20}classification",
        r"threshold[- ]tune?", r"threshold (tweak|adjustment|drift|miscalibration)",
        r"\bpause[- ]flag\b",
        r"audit emits? (a )?WARN.{0,40}(threshold|calibration|pause)",
    ])
    if not (calibration_comps or calibration_body):
        return 0, ev + ["→0 (no calibration signal)"]

    # ---- Level 5 — new calibration class ---------------------------------
    new_class = _has_any(body, [
        r"new calibration (mechanism|class|primitive)",
        r"new (pause[- ]rate|threshold) (audit|monitor) (mechanism|primitive)",
        r"live (false[- ]positive|fp).{0,30}auto[- ]audit",
        r"live (false[- ]negative|fn).{0,30}auto[- ]audit",
        r"new structural (calibration|threshold) (mechanism|primitive)",
        r"fw verb.{0,40}(calibration|pause[- ]rate|threshold)",
    ])
    if new_class:
        ev.append("body:calibration-new-class")
        return 5, ev + ["→5 (new calibration mechanism class)"]

    # ---- Level 4 — framework-level pause-rate audit / live loop ----------
    framework_audit = _has_any(body, [
        r"audit (FAIL|WARN).{0,40}(threshold|calibration|pause[- ]rate)",
        r"live calibration (loop|cycle)",
        r"recurring calibration (check|audit)",
        r"audit emits? (a )?WARN.{0,40}(threshold|calibration|pause)",
        r"pause[- ]rate (audit|monitor) at the framework level",
        r"framework[- ]level (calibration|pause[- ]rate)",
    ])
    if framework_audit:
        ev.append("body:framework-calibration-audit")
        return 4, ev + ["→4 (framework-level pause-rate audit / live loop)"]

    # ---- Level 3 — component-level threshold-tuning test or audit -------
    component = _has_any(body, [
        r"(unit|regression|integration) test.{0,40}(calibration|threshold|pause[- ]rate)",
        r"audit script.{0,40}(calibration|threshold|pause[- ]rate)",
        r"compares? (the )?(live )?pause[- ]rate (against|vs)",
        r"retrospective (should[- ]have[- ]paused|miss(ed)?) (classification|audit)",
    ])
    if component:
        ev.append("body:calibration-component")
        return 3, ev + ["→3 (component-level threshold-tuning test/audit)"]

    # ---- Level 2 — single threshold adjustment with rationale -----------
    single_adjustment = _has_any(body, [
        r"single (threshold|pause[- ]flag) (adjustment|tweak)",
        r"(adjusts?|tunes?|tweaks?) (the |a )?(threshold|pause[- ]flag)",
        r"narrow .{0,20}(threshold|calibration)",
    ])
    if single_adjustment:
        ev.append("body:calibration-single-adjustment")
        return 2, ev + ["→2 (single threshold adjustment)"]

    # ---- Level 1 — incidental --------------------------------------------
    if calibration_body or calibration_comps:
        ev.append("body/components:calibration-incidental")
        return 1, ev + ["→1 (incidental calibration mention)"]

    return 0, ev + ["→0 (no calibration signal)"]


def score_sovereignty_preservation(fm: dict, body: str, tags: list[str]) -> tuple[int, list[str]]:
    """sovereignty-preservation — arc-006 (value-prioritisation) scoped driver.

    T-2359. Anchored to .context/arcs/value-prioritisation.yaml proposed_scoped_drivers
    with weight 5. Rewards work that strengthens the §ACD-gated Sovereign
    boundary — `fw bvp confirm` robustness, Watchtower-only routing for
    Sovereign verbs, --i-am-human / --from-watchtower bypass-parity (per
    L-399 / T-1890). Distinct from global D1-D4 by focusing specifically on
    score-confirmation and weight-adjustment boundary preservation.

    Handler stays LATENT until operator approves the arc-scoped driver via
    Watchtower (`fw arc approve-driver value-prioritisation
    sovereignty-preservation --weight 5 --from-watchtower`).

    Rubric:
      0: No Sovereignty / §ACD signal.
      1: Incidental Sovereign-boundary mention.
      2: Single --i-am-human / --from-watchtower wiring fix or extension.
      3: Component-level Sovereign-verb test or bypass-log assertion
         (e.g. tests verifying CLAUDECODE blocking + flag bypass).
      4: Framework-level §ACD gate or bypass-parity hook (L-399 / T-1890
         producer/consumer parity, sibling parity hooks).
      5: New §ACD primitive class — new Sovereign verb routing pattern,
         new gate type that makes Sovereignty boundary structurally
         unbypassable without logged Tier-2.
    """
    ev: list[str] = []
    comps = _components_text(fm)

    sovereignty_comps = _has_any(comps, [
        r"lib/inception", r"lib/arc", r"lib/bvp",
        r"agents/.*sovereign", r"\.gate-bypass-log",
        r"web/blueprints/inception", r"web/blueprints/approvals",
        r"agents/.*\bbypass\b",
    ])
    sovereignty_body = _has_any(body, [
        r"§ACD", r"Sovereign(ty)?[- ]bound", r"\bSovereign(ty)? boundary\b",
        r"\bSovereign(ty)? gate\b", r"\bSovereign verb\b",
        r"--i-am-human", r"--from-watchtower",
        r"CLAUDECODE.{0,20}(gate|block|refuse)",
        r"score[- ]confirmation boundary",
        r"weight[- ]adjustment boundary",
        r"fw bvp confirm", r"\bbypass[- ]log\b",
        r"\bgate-bypass-log\b", r"Tier[- ]?2 (entry|log|logged)",
        r"L-399", r"T-1890",
        r"producer[- ]consumer parity",
    ])
    if not (sovereignty_comps or sovereignty_body):
        return 0, ev + ["→0 (no sovereignty signal)"]

    # ---- Level 5 — new §ACD primitive class -----------------------------
    new_class = _has_any(body, [
        r"new (§ACD|Sovereign(ty)?) (primitive|class|mechanism|verb)",
        r"new Sovereign verb routing pattern",
        r"structurally unbypassable",
        r"new gate type.{0,40}Sovereign(ty)?",
        r"structurally enforces? (the )?Sovereign(ty)? boundary",
        r"new §ACD gate primitive",
    ])
    if new_class:
        ev.append("body:sovereignty-new-class")
        return 5, ev + ["→5 (new §ACD primitive class)"]

    # ---- Level 4 — framework-level §ACD gate / bypass-parity hook --------
    framework_gate = _has_any(body, [
        r"PreToolUse hook.{0,40}(§ACD|Sovereign|--i-am-human|--from-watchtower)",
        r"PostToolUse hook.{0,40}(§ACD|Sovereign|bypass[- ]log)",
        r"audit FAIL.{0,40}(Sovereign|§ACD|bypass)",
        r"audit WARN.{0,40}(Sovereign|§ACD|bypass)",
        r"producer/consumer parity.{0,40}(Sovereign|§ACD|bypass)",
        r"L-399.{0,20}(parity|fix|extension)",
        r"T-1890.{0,20}(parity|fix|extension)",
        r"framework[- ]level (§ACD|Sovereign(ty)?)",
        r"refuses? (work-completed|--status).{0,40}(§ACD|Sovereign)",
    ])
    if framework_gate:
        ev.append("body:framework-sovereignty-gate")
        return 4, ev + ["→4 (framework-level §ACD gate / bypass-parity hook)"]

    # ---- Level 3 — component-level Sovereign-verb test / bypass-log ----
    component = _has_any(body, [
        r"(unit|regression|integration) test.{0,40}(§ACD|Sovereign|CLAUDECODE|--i-am-human|--from-watchtower)",
        r"bypass[- ]log (assertion|test)",
        r"Sovereign[- ]verb (test|assertion)",
        r"tests?/.*sovereign",
        r"tests?/.*inception_decide",
    ])
    component_touch = _has_any(comps, [
        r"lib/inception", r"\.gate-bypass-log",
        r"tests/.*sovereign",
    ])
    if component or component_touch:
        if component:
            ev.append("body:sovereignty-component")
        if component_touch:
            ev.append("components:sovereignty-code")
        return 3, ev + ["→3 (component-level Sovereign-verb test or bypass-log)"]

    # ---- Level 2 — single --i-am-human / --from-watchtower wiring ------
    single_wiring = _has_any(body, [
        r"adds? (a |the )?--i-am-human (flag|wiring|bypass)",
        r"adds? (a |the )?--from-watchtower (flag|wiring|bypass)",
        r"single (--i-am-human|--from-watchtower) (wiring|fix)",
        r"narrow .{0,20}(--i-am-human|--from-watchtower)",
        r"extends? (the )?bypass[- ](mechanism|wiring) (to|for)",
    ])
    if single_wiring:
        ev.append("body:sovereignty-single-wiring")
        return 2, ev + ["→2 (single --i-am-human/--from-watchtower wiring)"]

    # ---- Level 1 — incidental --------------------------------------------
    if sovereignty_body or sovereignty_comps:
        ev.append("body/components:sovereignty-incidental")
        return 1, ev + ["→1 (incidental Sovereign-boundary mention)"]

    return 0, ev + ["→0 (no sovereignty signal)"]


def score_aesthetic_cohesion(fm: dict, body: str, tags: list[str]) -> tuple[int, list[str]]:
    """aesthetic-cohesion — arc-007 (watchtower-redesign) scoped driver.

    T-2360. Anchored to .context/arcs/watchtower-redesign.yaml proposed_scoped_drivers
    with weight 5. Rewards visual rhythm / typography spacing / palette contrast
    harmony / restraint — qualities a CLI with perfect D3 (Usability) has no
    concern for. arc-007 ships 6 palettes × light/dark + 6 type pairings + 3
    density tiers as user levers; this driver scores whether each slice
    advances the "looks right" axis vs the "works right" axis.

    Handler stays LATENT until operator approves the arc-scoped driver via
    Watchtower (`fw arc approve-driver watchtower-redesign aesthetic-cohesion
    --weight 5 --from-watchtower`).

    Rubric:
      0: No aesthetic signal.
      1: Incidental aesthetic mention.
      2: Single palette/density/typography tweak with rationale.
      3: Component-level aesthetic test or sweep (palette-contrast / typography
         picker / density spacing-scale tests, sibling of T-2004 / T-2029).
      4: Framework-level aesthetic check or design-token-system enforcement
         (typography & density picker axes / palette-contrast lint at audit
         level / contrast-WCAG audit gate).
      5: New aesthetic primitive class — new design-token system, new
         palette-contrast lint as structural mechanism, framework-level
         design-system substrate.
    """
    ev: list[str] = []
    comps = _components_text(fm)

    aesthetic_comps = _has_any(comps, [
        r"web/templates/", r"web/static/(css|js)",
        r"palette", r"typography", r"design[- ]token",
        r"density", r"theme", r"\baccent\b",
    ])
    aesthetic_body = _has_any(body, [
        r"\baesthetic (cohesion|rhythm|harmony|restraint)\b",
        r"\bvisual rhythm\b", r"\btypography (spacing|pairing|picker)\b",
        r"\bpalette (contrast|harmony|swap|picker)\b",
        r"palette[- ]contrast",
        r"\bdesign[- ]token\b", r"\bdensity (tier|picker|spacing)\b",
        r"WCAG contrast", r"contrast (ratio|harmony|lint)",
        r"\baesthetic (cohesion|primitive|substrate)\b",
        r"\bdesign[- ]system substrate\b",
        r"looks right axis",
        r"\bT-2004\b", r"\bT-2029\b",
    ])
    if not (aesthetic_comps or aesthetic_body):
        return 0, ev + ["→0 (no aesthetic signal)"]

    # ---- Level 5 — new aesthetic primitive class ------------------------
    new_class = _has_any(body, [
        r"new design[- ]token system",
        r"new aesthetic (primitive|class|substrate|mechanism)",
        r"new palette[- ]contrast lint",
        r"design[- ]system substrate (lands|ships)",
        r"new (palette|typography|density) (primitive|substrate|system)",
        r"structural design[- ]token (system|substrate|mechanism)",
    ])
    if new_class:
        ev.append("body:aesthetic-new-class")
        return 5, ev + ["→5 (new aesthetic primitive class)"]

    # ---- Level 4 — framework-level aesthetic check ----------------------
    framework_check = _has_any(body, [
        r"audit (FAIL|WARN).{0,40}(contrast|palette|typography|aesthetic|density)",
        r"contrast[- ]lint (gate|hook|enforcement)",
        r"WCAG (contrast )?audit gate",
        r"(typography|density) picker axes",
        r"framework[- ]level (aesthetic|palette|typography)",
        r"design[- ]token enforcement",
    ])
    if framework_check:
        ev.append("body:framework-aesthetic-check")
        return 4, ev + ["→4 (framework-level aesthetic check)"]

    # ---- Level 3 — component-level aesthetic test / sweep ----------------
    component = _has_any(body, [
        r"(unit|regression|integration|playwright) test.{0,40}(palette|typography|density|contrast|aesthetic)",
        r"(palette|aesthetic)[- ]contrast test",
        r"\bpalette-contrast test\b",
        r"typography (picker|pairing) test",
        r"density spacing[- ]scale test",
        r"sibling of T-2004", r"sibling of T-2029",
    ])
    component_touch = _has_any(comps, [
        r"web/static/css", r"web/templates/.*\.html",
        r"tests/.*(palette|typography|density|contrast)",
    ])
    if component or component_touch:
        if component:
            ev.append("body:aesthetic-component")
        if component_touch:
            ev.append("components:aesthetic-code")
        return 3, ev + ["→3 (component-level aesthetic test/sweep)"]

    # ---- Level 2 — single palette/density/typography tweak --------------
    single_tweak = _has_any(body, [
        r"single (palette|density|typography) (tweak|adjustment|fix)",
        r"\btweak(s|ed)? (the |a )?(palette|density|typography|contrast)\b",
        r"adjust(s|ed)? (the |a )?(palette|density|typography|spacing)",
        r"narrow .{0,20}(palette|density|typography|aesthetic)",
    ])
    if single_tweak:
        ev.append("body:aesthetic-single-tweak")
        return 2, ev + ["→2 (single palette/density/typography tweak)"]

    # ---- Level 1 — incidental --------------------------------------------
    if aesthetic_body or aesthetic_comps:
        ev.append("body/components:aesthetic-incidental")
        return 1, ev + ["→1 (incidental aesthetic mention)"]

    return 0, ev + ["→0 (no aesthetic signal)"]


def score_render_fidelity(fm: dict, body: str, tags: list[str]) -> tuple[int, list[str]]:
    """render-fidelity — arc-007 (watchtower-redesign) scoped driver.

    T-2360. Anchored to .context/arcs/watchtower-redesign.yaml proposed_scoped_drivers
    with weight 5. Rewards work that catches VISUAL failures that pass every
    D2 (Reliability) functional check. arc-007 cites concrete instances:
    accent at 3.83:1 contrast (WCAG fail, T-2006), Pico-bridge bleed-through
    in light mode (T-2003), unbounded page height 30-90kpx degradation
    (T-2038 through T-2047). Each shipped under green D2 verification and was
    caught only by eyes-on review.

    Handler stays LATENT until operator approves the arc-scoped driver via
    Watchtower.

    Rubric:
      0: No render-fidelity signal.
      1: Incidental render mention.
      2: Single render-bug fix without structural prevention.
      3: Component-level render-fidelity fix (e.g. one WCAG contrast fix +
         visual-regression test for that accent).
      4: Framework-level render check (audit FAIL on contrast / Playwright
         contrast baseline / unbounded-height detector at framework level).
      5: New render-fidelity primitive class (automated visual-regression
         substrate, Playwright contrast baseline becomes a fw verb, new gate
         type that makes render-fidelity regressions structurally impossible).
    """
    ev: list[str] = []
    comps = _components_text(fm)

    render_comps = _has_any(comps, [
        r"web/templates/", r"web/static/css",
        r"tests/playwright", r"playwright",
    ])
    render_body = _has_any(body, [
        r"\brender[- ]fidelity\b", r"\brender bug\b",
        r"\bWCAG\b", r"\bcontrast\b", r"\bplaywright\b",
        r"\bPico[- ]bridge\b", r"\bpico[- ]bleed\b",
        r"unbounded (page )?height", r"\bpage[- ]height degradation\b",
        r"visual (failure|regression|fidelity)",
        r"eyes[- ]on (review|check)",
        r"\bT-2003\b", r"\bT-2006\b",  # arc-007 rationale-cited siblings
        r"\bT-2038\b|\bT-2039\b|\bT-2040\b|\bT-2041\b",
        r"\bT-2042\b|\bT-2043\b|\bT-2044\b|\bT-2045\b|\bT-2046\b|\bT-2047\b",
        r"3\.83:1", r"30[- ]?90kpx",
    ])
    if not (render_comps or render_body):
        return 0, ev + ["→0 (no render-fidelity signal)"]

    # ---- Level 5 — new render-fidelity primitive class ------------------
    new_class = _has_any(body, [
        r"new render[- ]fidelity (primitive|class|substrate|mechanism)",
        r"automated visual[- ]regression substrate",
        r"playwright contrast baseline.{0,30}(becomes|ships).{0,30}fw verb",
        r"structurally impossible.{0,40}(render|contrast|bleed)",
        r"new gate.{0,40}render[- ]fidelity",
    ])
    if new_class:
        ev.append("body:render-fidelity-new-class")
        return 5, ev + ["→5 (new render-fidelity primitive class)"]

    # ---- Level 4 — framework-level render check ------------------------
    framework_check = _has_any(body, [
        r"audit (FAIL|WARN).{0,40}(contrast|WCAG|height|render|Pico)",
        r"playwright contrast baseline",
        r"unbounded[- ]height detector",
        r"framework[- ]level (render|contrast|height)",
        r"(visual|render)[- ]regression (gate|hook|check)",
        r"contrast[- ]lint at audit level",
    ])
    if framework_check:
        ev.append("body:framework-render-check")
        return 4, ev + ["→4 (framework-level render check)"]

    # ---- Level 3 — component-level render-fidelity fix + test ----------
    component = _has_any(body, [
        r"WCAG contrast fix",
        r"contrast (ratio )?(fix|repair)",
        r"\bPico[- ]bleed (fix|repair)",
        r"unbounded[- ]height (fix|repair)",
        r"playwright.{0,30}(contrast|WCAG|render)",
        r"visual[- ]regression test.{0,40}(accent|contrast)",
    ])
    component_touch = _has_any(comps, [
        r"tests/playwright", r"web/static/css",
    ])
    if component or component_touch:
        if component:
            ev.append("body:render-fidelity-component")
        if component_touch:
            ev.append("components:render-code")
        return 3, ev + ["→3 (component-level render-fidelity fix + test)"]

    # ---- Level 2 — single render-bug fix without prevention -------------
    single_fix = _has_any(body, [
        r"single (render|contrast|visual) (bug |)?fix",
        r"fix(es|ed)?( one)? (a |the )?(render|contrast|visual) (bug|defect|issue)",
        r"one[- ]off (render|contrast|visual) fix",
    ])
    if single_fix:
        ev.append("body:render-single-fix")
        return 2, ev + ["→2 (single render-bug fix without prevention)"]

    # ---- Level 1 — incidental --------------------------------------------
    if render_body or render_comps:
        ev.append("body/components:render-incidental")
        return 1, ev + ["→1 (incidental render mention)"]

    return 0, ev + ["→0 (no render-fidelity signal)"]


def score_theme_portability(fm: dict, body: str, tags: list[str]) -> tuple[int, list[str]]:
    """theme-portability — arc-007 (watchtower-redesign) scoped driver.

    T-2360. Anchored to .context/arcs/watchtower-redesign.yaml proposed_scoped_drivers
    with weight 4. Rewards work that closes the "user picks Editorial once →
    Cockpit/Tasks/Approvals/Fabric/Arcs/Settings all re-theme without manual
    reapply" promise (headline_mechanic acid test). Distinct from D4
    Portability which is about provider/lang/env boundaries; theme-portability
    is about uniformity across surfaces inside THIS app.

    Handler stays LATENT until operator approves the arc-scoped driver via
    Watchtower.

    Rubric:
      0: No theme-portability signal.
      1: Incidental theme mention.
      2: Single missed-surface fix with rationale (e.g. /approvals page
         now respects preset).
      3: Component-level theme fix on 1-2 surfaces (e.g. T-2005-class
         multi-page sweep on a subset).
      4: Framework-level theme apply-sweep — multi-page sweep / token-substrate
         adoption / dark-mode toggle across ALL surfaces.
      5: New theme-portability primitive class — design-token-substrate that
         auto-propagates across every surface, theme-apply becomes a structural
         mechanism that makes missed-surface regressions impossible.
    """
    ev: list[str] = []
    comps = _components_text(fm)

    theme_comps = _has_any(comps, [
        r"web/templates/", r"web/static/css",
        r"theme", r"palette", r"design[- ]token",
    ])
    theme_body = _has_any(body, [
        r"\btheme[- ]portability\b", r"theme (apply|sweep|substrate|toggle)",
        r"preset (applies|re[- ]themes|propagates)",
        r"\bmissed[- ]surface\b", r"(applies|adds?) (a |the )?preset",
        r"multi[- ]page (sweep|theme)",
        r"design[- ]token (substrate|propagation)",
        r"dark[- ]mode toggle",
        r"every surface (inside )?(this app)?",
        r"palette[- ]contrast lint",
        r"\bT-2005\b", r"\bT-2007\b", r"\bT-2031\b",  # arc-007 rationale-cited siblings
        r"Cockpit/Tasks/Approvals/Fabric",
    ])
    if not (theme_comps or theme_body):
        return 0, ev + ["→0 (no theme-portability signal)"]

    # ---- Level 5 — new theme-portability primitive class ---------------
    new_class = _has_any(body, [
        r"new theme[- ]portability (primitive|class|substrate|mechanism)",
        r"design[- ]token[- ]substrate.{0,40}auto[- ]propagat",
        r"theme[- ]apply becomes a structural mechanism",
        r"structurally impossible.{0,40}missed[- ]surface",
        r"every surface.{0,30}auto[- ]propagat",
    ])
    if new_class:
        ev.append("body:theme-new-class")
        return 5, ev + ["→5 (new theme-portability primitive class)"]

    # ---- Level 4 — framework-level theme apply-sweep -------------------
    # NOTE: L4 requires 3+ surfaces, "all/every/across" qualifier, or explicit
    # framework-level wiring. 1-2 surface bodies are L3, not L4 (handled below).
    framework_sweep = _has_any(body, [
        r"multi[- ]page (theme )?sweep (lands|ships)",
        r"token[- ]substrate adoption",
        r"dark[- ]mode toggle.{0,40}(all|every) surface",
        # 3+ surfaces named explicitly (with / or , separators — "and" doesn't count for L4)
        r"(Cockpit|Tasks|Approvals|Fabric|Arcs|Settings)[/,] ?(Cockpit|Tasks|Approvals|Fabric|Arcs|Settings)[/,] ?(Cockpit|Tasks|Approvals|Fabric|Arcs|Settings)",
        r"theme (apply|sweep).{0,40}(all|every|across) (the )?(surfaces|pages)",
        r"framework[- ]level theme",
        r"palette[- ]contrast lint at framework",
    ])
    if framework_sweep:
        ev.append("body:framework-theme-sweep")
        return 4, ev + ["→4 (framework-level theme apply-sweep)"]

    # ---- Level 3 — component-level theme fix on 1-2 surfaces -----------
    component = _has_any(body, [
        r"theme (fix|sweep) on (one|two|1|2|specific) (page|surface|surfaces)",
        r"single[- ]page theme (sweep|fix)",
        r"(adds?|applies) (a )?preset to (one|two|the).{0,30}(page|surface|view)",
    ])
    component_touch = _has_any(comps, [
        r"web/static/css", r"web/templates/",
    ])
    if component or component_touch:
        if component:
            ev.append("body:theme-component")
        if component_touch:
            ev.append("components:theme-code")
        return 3, ev + ["→3 (component-level theme fix on 1-2 surfaces)"]

    # ---- Level 2 — single missed-surface fix ---------------------------
    single_fix = _has_any(body, [
        r"missed[- ]surface fix",
        r"(adds?|applies) (the )?(preset|theme) to (the )?/(approvals|fabric|arcs|settings|cockpit|tasks|review|inception)",
        r"single (theme|preset) fix",
    ])
    if single_fix:
        ev.append("body:theme-single-fix")
        return 2, ev + ["→2 (single missed-surface fix)"]

    # ---- Level 1 — incidental --------------------------------------------
    if theme_body or theme_comps:
        ev.append("body/components:theme-incidental")
        return 1, ev + ["→1 (incidental theme mention)"]

    return 0, ev + ["→0 (no theme-portability signal)"]


def score_feedback_loop_completeness(fm: dict, body: str, tags: list[str]) -> tuple[int, list[str]]:
    """feedback-loop-completeness — arc-005 (inception-review-loop) scoped driver.

    T-2361. Anchored to .context/arcs/inception-review-loop.yaml proposed_scoped_drivers.
    Rewards work that closes the chat-to-file gap — operator intent surviving
    the agent-handoff round-trip and landing back in the next session.
    Distinct from D2 (Reliability) which covers framework-internal observability;
    this driver scores the OUTSIDE-the-framework gap (chat substrate → file
    substrate → next session).

    Handler stays LATENT until operator approves the arc-scoped driver via
    Watchtower.

    Rubric:
      0: No round-trip signal.
      1: Incidental handover/feedback mention.
      2: Single handover section fix (e.g. Suggested First Action no longer empty).
      3: Component-level handover content-quality test (e.g. handover-completeness
         assertion, Next Step population test).
      4: Framework-level handover/session-capture gate (e.g. PreCompact handover
         always emits, completion-percentage audit at framework level).
      5: New round-trip-fidelity primitive class (automated handover-completeness
         audit, new mechanism making round-trip-lossy handovers structurally
         impossible).
    """
    ev: list[str] = []
    comps = _components_text(fm)

    roundtrip_comps = _has_any(comps, [
        r"agents/handover", r"agents/session-capture",
        r"\.context/handovers", r"PreCompact",
        r"web/blueprints/handovers",
    ])
    roundtrip_body = _has_any(body, [
        r"\bhandover (file|document|generation|round[- ]?trip)",
        r"\bsession capture\b", r"\bSession Start Protocol\b",
        r"chat[- ]to[- ]file gap",
        r"operator intent.{0,30}(round[- ]?trip|hand(off|over)|next session)",
        r"feedback[- ]loop (completeness|gap)",
        r"PreCompact hook", r"PreCompact handover",
        r"\b(handover|session) (completeness|fidelity)\b",
        r"Suggested First Action", r"Suggested Action",
        r"round[- ]?trip[- ]fidelity",
    ])
    if not (roundtrip_comps or roundtrip_body):
        return 0, ev + ["→0 (no round-trip signal)"]

    # ---- Level 5 — new round-trip-fidelity primitive class --------------
    new_class = _has_any(body, [
        r"new round[- ]?trip[- ]fidelity (primitive|class|substrate|mechanism)",
        r"automated handover[- ]completeness (audit|substrate)",
        r"new (handover|session) (capture|completeness) (primitive|class|mechanism)",
        r"round[- ]?trip[- ]lossy.{0,40}structurally impossible",
        r"new mechanism.{0,40}(chat[- ]to[- ]file|round[- ]?trip|handover)",
    ])
    if new_class:
        ev.append("body:feedback-loop-new-class")
        return 5, ev + ["→5 (new round-trip-fidelity primitive class)"]

    # ---- Level 4 — framework-level handover gate ------------------------
    framework_gate = _has_any(body, [
        r"PreCompact (hook|handover).{0,40}(always emits|always fires|guaranteed)",
        r"(completion[- ]percentage|completeness) audit.{0,30}(framework|handover|session)",
        r"audit (FAIL|WARN).{0,40}(handover|session capture|completeness)",
        r"framework[- ]level (handover|session capture)",
        r"PreToolUse hook.{0,40}(handover|session capture)",
    ])
    if framework_gate:
        ev.append("body:framework-feedback-loop-gate")
        return 4, ev + ["→4 (framework-level handover/session gate)"]

    # ---- Level 3 — component-level handover quality test ----------------
    component = _has_any(body, [
        r"(unit|regression|integration|playwright) test.{0,40}(handover|session capture|Suggested)",
        r"handover[- ]completeness (assertion|test)",
        r"\bNext Step (population|assertion|fill)",
        r"Suggested (First )?Action (assertion|fill|population)",
    ])
    component_touch = _has_any(comps, [
        r"agents/handover", r"agents/session-capture", r"\.context/handovers",
        r"tests/.*handover",
    ])
    if component or component_touch:
        if component:
            ev.append("body:feedback-loop-component")
        if component_touch:
            ev.append("components:handover-code")
        return 3, ev + ["→3 (component-level handover content-quality)"]

    # ---- Level 2 — single handover section fix --------------------------
    single_fix = _has_any(body, [
        r"(fixes?|fills?|populates?) (the |a )?(handover (section|template)|Suggested First Action|Suggested Action|Next Step)",
        r"narrow .{0,20}(handover|session capture)",
        r"single (handover|session) (section )?fix",
    ])
    if single_fix:
        ev.append("body:feedback-loop-single-fix")
        return 2, ev + ["→2 (single handover section fix)"]

    # ---- Level 1 — incidental --------------------------------------------
    if roundtrip_body or roundtrip_comps:
        ev.append("body/components:feedback-loop-incidental")
        return 1, ev + ["→1 (incidental handover/feedback mention)"]

    return 0, ev + ["→0 (no round-trip signal)"]


def score_estimator_fidelity(fm: dict, body: str, tags: list[str]) -> tuple[int, list[str]]:
    """estimator-fidelity — arc-006 (value-prioritisation) scoped driver.

    T-2361. Anchored to .context/arcs/value-prioritisation.yaml `scoped_drivers`
    (APPROVED 2026-05-21, weight 3). Rewards work that improves agreement between
    BVP estimator-proposed scores and human-confirmed scores. Distinct from D2
    (Reliability): D2 cares "estimator runs without crashing and writes audit
    rows"; this driver cares "the numbers it produces would not embarrass a
    human reviewer". The v2-delta semantic (M3, ≥2 driver-delta between
    proposed and confirmed signals needs-split) is fidelity made operational.

    Unlike T-2356 / T-2359 / T-2360 handlers, arc-006 estimator-fidelity is
    ALREADY APPROVED — so this handler activates for arc-006 member tasks
    immediately on landing (T-2358 helper + T-2357 dispatch wiring already
    route arc-006 tasks through here). Pre-T-2361, arc-006 tasks scoring against
    this driver fell through to `score_free_driver` keyword fallback (0-2
    keyword-match scoring). Post-T-2361, the rubric-anchored 0-5 scoring fires.

    Rubric:
      0: No estimator-fidelity signal.
      1: Incidental estimator/fidelity mention.
      2: Single rubric tweak with rationale (one keyword pattern adjustment).
      3: Component-level fidelity test or rubric refinement (e.g. a new
         dedicated handler shipping with per-level tests — this session's
         T-2356/T-2359/T-2360/T-2361 pattern).
      4: Framework-level estimator-fidelity audit (proposed-vs-confirmed
         delta audit gate at framework level, structural needs-split signal).
      5: New estimator-fidelity primitive class (v2-delta auto-needs-split
         mechanism, structural drift detection, new mechanism making
         confirmed-vs-proposed divergence structurally surfaced).
    """
    ev: list[str] = []
    comps = _components_text(fm)

    fidelity_comps = _has_any(comps, [
        r"agents/termlink/bvp-estimator", r"bvp[- ]estimator",
        r"tests/.*bvp_estimator", r"tests/.*bvp",
        r"lib/bvp",
    ])
    fidelity_body = _has_any(body, [
        r"\bestimator[- ]fidelity\b", r"\bestimator (rubric|score|fidelity|agreement)\b",
        r"v2[- ]delta", r"proposed[- ]vs[- ]confirmed",
        r"\bneeds[- ]split\b", r"\bneeds[- ]split signal\b",
        r"\bbvp[- ]estimator\b", r"score_[a-z_]+",
        r"\bdedicated handler\b", r"per[- ]level (test|rubric)",
        r"BVP heuristic estimator", r"would not embarrass",
        r"confirmed[- ]vs[- ]proposed",
    ])
    if not (fidelity_comps or fidelity_body):
        return 0, ev + ["→0 (no estimator-fidelity signal)"]

    # ---- Level 5 — new estimator-fidelity primitive class ---------------
    new_class = _has_any(body, [
        r"new estimator[- ]fidelity (primitive|class|substrate|mechanism)",
        r"v2[- ]delta auto[- ]needs[- ]split (mechanism|primitive)",
        r"structural (needs[- ]split|drift detection)",
        r"structurally surfaced.{0,40}(confirmed|proposed|delta)",
        r"new mechanism.{0,40}(confirmed[- ]vs[- ]proposed|fidelity)",
    ])
    if new_class:
        ev.append("body:estimator-fidelity-new-class")
        return 5, ev + ["→5 (new estimator-fidelity primitive class)"]

    # ---- Level 4 — framework-level fidelity audit ------------------------
    framework_audit = _has_any(body, [
        r"(proposed[- ]vs[- ]confirmed|confirmed[- ]vs[- ]proposed) delta audit",
        r"audit (FAIL|WARN).{0,40}(estimator|fidelity|delta)",
        r"framework[- ]level (estimator|fidelity)",
        r"structural needs[- ]split signal",
        r"v2[- ]delta (audit|gate)",
    ])
    if framework_audit:
        ev.append("body:framework-estimator-fidelity-audit")
        return 4, ev + ["→4 (framework-level estimator-fidelity audit)"]

    # ---- Level 3 — component-level rubric refinement / dedicated handler ----
    component = _has_any(body, [
        r"new dedicated (handler|scorer)",
        r"per[- ]level test (× ?\d|coverage|suite)",
        r"score_[a-z_]+ (added|implemented)",
        r"(unit|regression) test.{0,40}(estimator|rubric|fidelity)",
        r"(rubric|estimator) refinement",
        r"6[- ]level rubric",
    ])
    component_touch = _has_any(comps, [
        r"agents/termlink/bvp-estimator",
        r"tests/.*bvp_estimator",
    ])
    if component or component_touch:
        if component:
            ev.append("body:estimator-fidelity-component")
        if component_touch:
            ev.append("components:bvp-estimator-code")
        return 3, ev + ["→3 (component-level rubric refinement / dedicated handler)"]

    # ---- Level 2 — single rubric tweak ----------------------------------
    single_tweak = _has_any(body, [
        r"single rubric tweak",
        r"one[- ]off (rubric|estimator) (tweak|adjustment)",
        r"narrow .{0,20}(estimator|rubric|fidelity)",
        r"keyword pattern (adjustment|tweak)",
    ])
    if single_tweak:
        ev.append("body:estimator-fidelity-single-tweak")
        return 2, ev + ["→2 (single rubric tweak)"]

    # ---- Level 1 — incidental --------------------------------------------
    if fidelity_body or fidelity_comps:
        ev.append("body/components:estimator-fidelity-incidental")
        return 1, ev + ["→1 (incidental estimator/fidelity mention)"]

    return 0, ev + ["→0 (no estimator-fidelity signal)"]


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

    # T-2357: merge arc-scoped drivers (from the task's arc YAML's
    # scoped_drivers:) into the dispatch driver set. Global drivers WIN on
    # name collision — operator-approved policy weights take precedence over
    # arc-scoped weights. Skipped for inceptions (voi_score is the composite).
    if not is_inception:
        arc_drivers = _arc_scoped_drivers_for_task(fm)
        if arc_drivers:
            merged = dict(arc_drivers)
            merged.update(drivers)  # passed-in drivers win on collision
            drivers = merged

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
        # T-2328 + T-2343 — dedicated handlers for the V_* batch. Active under
        # the current policy: T-2336 added the drivers with `id: F3 / F1 / F2`
        # and `name: V_PROMPT_QUALITY / V_CONTEXT_FABRIC / V_COMPONENT_FABRIC`.
        # T-2343 wired the dispatch to consult both id and name via
        # _load_driver_aliases() — so these handlers fire under the F3/F1/F2
        # ids without requiring a Sovereign --add to re-canonicalise.
        "V_PROMPT_QUALITY": score_v_prompt_quality,
        "V_CONTEXT_FABRIC": score_v_context_fabric,
        "V_COMPONENT_FABRIC": score_v_component_fabric,
        # T-2329 — sibling of T-2171 AC#5. Latent until T-2171 uncomments
        # the F-AUTONOMY carve in policy/value-drivers.yaml (Sovereign,
        # gated by T-2158 continuous-run cycle + L5/L6 milestone). Carries
        # the Sovereignty refuse-rule (level 0 on Tier-0 / safety-critical
        # gate removal without at-least-as-safe replacement).
        "F-AUTONOMY": score_f_autonomy,
        # T-2356 — arc-011 scoped drivers (proposed via T-2344 batch_propose).
        # Latent in two ways: (1) _load_drivers() reads only global policy, so
        # arc-scoped drivers never reach `drivers:` here today; (2) even after
        # operator approval via Watchtower, dispatch wiring for arc-scoped
        # drivers is a separate slice. Keys match the IDs in arc-011.yaml.
        "D-DISJOINT": score_d_disjoint,
        "D-WIRE-EVIDENCE": score_d_wire_evidence,
        # T-2359 — arc-001 (dispatch-safety) + arc-006 (value-prioritisation)
        # scoped drivers. Latent until operator approves the proposed_scoped_drivers
        # via Watchtower. T-2357 dispatch wiring + T-2358 name-form widening
        # make activation immediate on approval. Keys match canonical name-form
        # per T-2358 / lib/arc.sh:1258.
        "uncertainty-recognition": score_uncertainty_recognition,
        "severity-likelihood-calibration": score_severity_likelihood_calibration,
        "sovereignty-preservation": score_sovereignty_preservation,
        # T-2360 — arc-007 (watchtower-redesign) scoped drivers. Latent until
        # operator approves the proposed_scoped_drivers via Watchtower.
        "aesthetic-cohesion": score_aesthetic_cohesion,
        "render-fidelity": score_render_fidelity,
        "theme-portability": score_theme_portability,
        # T-2361 — arc-005 (inception-review-loop) feedback-loop-completeness:
        # LATENT until operator approves. arc-006 (value-prioritisation)
        # estimator-fidelity: ALREADY APPROVED 2026-05-21 — this handler swaps
        # the score_free_driver keyword fallback for rubric-anchored scoring.
        "feedback-loop-completeness": score_feedback_loop_completeness,
        "estimator-fidelity": score_estimator_fidelity,
    }
    # T-2343: name-alias map for drivers whose policy id differs from their
    # canonical name (e.g. policy id F3, handler key V_PROMPT_QUALITY).
    name_aliases = _load_driver_aliases()
    for driver_id in drivers:
        if is_inception:
            sc, ev = _score_inception_voi(fm, body, tags)
        elif driver_id in handlers:
            sc, ev = handlers[driver_id](fm, body, tags)
        elif name_aliases.get(driver_id) in handlers:
            sc, ev = handlers[name_aliases[driver_id]](fm, body, tags)
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
        fm = _str_safe_load(fm_text) or {}

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
    _atomic_write_text(task_path, new_text)
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


def score_blast_radius(fm: dict, body: str, tags: list[str]) -> tuple[int | None, list[str]]:
    """Heuristic: count `components:` entries → 1/3/5/7/9 scale, or None if unknown.

    T-3068: returns **None, not 0**, when there is no component information.
    `0` is the cheapest value on a term carrying weight 0.6 — more than the other
    two cost terms combined — so scoring "the framework never recorded what this
    touches" as 0 does not present as missing data, it presents as
    *attractiveness*, and an HV/LC filter promotes on exactly that.

    This is not a rare path. `components:` is populated at the `work-completed`
    transition (update-task.sh resolves it from git history), and `fw bvp` excludes
    work-completed by default (T-2223 — the rank answers "what should I work on
    next"). Measured at the time of this change: of the 142 ranked tasks, **4 had
    components**. So the term was unavailable for 97% of the population it ranked,
    and unavailable meant cheapest.

    Nothing is lost by giving up the 0 value: `n == 0` was the only route to it, so
    a returned 0 has always meant "no information" rather than "touches nothing".
    Now it says so. Recorded 0s already in frontmatter are deliberately NOT
    reinterpreted — a stored 0 was a real (if wrong) estimate, and rewriting it
    would destroy the evidence this change rests on.

    Components are explicit declarations of what the task touches; longer
    lists imply wider blast radius. The 1/3/5/7/9 ladder is non-linear by
    design — a component count of 7 vs 8 is rarely meaningful, but 1 vs 5+ is.

    T-2189 inception scoring exception: inceptions' `components:` is empty
    by definition (the build doesn't exist yet), so the count below cannot
    speak for them. When `workflow_type: inception`, prefer the
    `target_blast_radius` (T-2188 schema) frontmatter field. See
    050-Inceptions.md §Scoring Exception and policy/value-drivers.yaml
    §inception_scoring_exception. T-3068 note: T-2189 identified this exact
    shape one population earlier and repaired inceptions only — the same
    sentence was true of the whole non-inception corpus, and nothing re-asked.
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
        return None, ["→? (components-malformed)"]
    n = len([c for c in components if c])
    if n == 0: return None, ["→? (no-components-UNMEASURED-not-zero)"]
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

    # T-3068: `blast_radius: null` is emitted deliberately rather than dropped or
    # defaulted. `compute_cost` (lib/bvp.sh) requires all three terms present and
    # otherwise reports source='absent' — so a null here propagates as "no cost
    # known" all the way to the COST/QUAD columns, instead of a composite quietly
    # assembled from the 0.3 and 0.1 terms while the 0.6 one was never measured.
    # A cost built on an unknown blast radius is unknown, not cheap.
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
    """Render `term=value (reason)` per cost component.

    T-3068: this used to print `(no-signal)` for every term on every task. It
    looked for evidence entries that do NOT start with the arrow, but all three
    cost scorers return exactly one entry and it always starts with the arrow —
    so the `signals` list was empty by construction, and the reason the scorer
    had already computed was thrown away in favour of the words "no-signal".

    Fixing it matters more now than it did: with blast_radius able to come back
    unknown, the parenthetical is the only place the operator can see *why* a cost
    is missing. `blast_radius=? (no-signal)` would say nothing;
    `blast_radius=? (no-components-UNMEASURED-not-zero)` says what to do about it.
    """
    parts = []
    for component, ev in evidence.items():
        arrow = next((e for e in ev if e.startswith("→")), "→?")
        head, _, tail = arrow.partition(" ")
        value = head[1:] or "?"
        # Prefer the scorer's own parenthetical; fall back to any non-arrow
        # entries, which is the shape the original code assumed.
        reason = tail.strip().strip("()") or ",".join(
            e for e in ev if not e.startswith("→")
        ) or "no-signal"
        parts.append(f"{component}={value} ({reason})")
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
        fm = _str_safe_load(fm_text) or {}

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
    _atomic_write_text(task_path, new_text)
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
        fm = _str_safe_load(fm_text) or {}
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
    _atomic_write_text(task_path, f"---\n{new_fm_text}\n---\n{body_text}")
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
        fm = _str_safe_load(fm_text) or {}
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
    _atomic_write_text(task_path, f"---\n{new_fm_text}\n---\n{body_text}")
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
