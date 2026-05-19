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


def score_free_driver(driver_id: str, fm: dict, body: str, tags: list[str]) -> tuple[int, list[str]]:
    """Heuristic fallback for free drivers — keyword-on-driver-id only.

    Free drivers don't yet have rubric sections (per R9 rubric reversibility),
    so we score conservatively. Looks for the driver id as a substring in
    body/tags; if present, scores 1-2 based on count. If absent, 0.
    """
    ev: list[str] = []
    needle = driver_id.lower()
    hits = sum(1 for chunk in (body, " ".join(tags)) if needle in chunk.lower())
    if hits == 0:
        return 0, [f"→0 (no '{driver_id}' mention)"]
    return min(hits, 2), [f"body/tag hits for '{driver_id}': {hits}", f"→{min(hits, 2)}"]


# ---- top-level orchestration ------------------------------------------------

def estimate_task(task_path: Path, drivers: dict[str, int]) -> dict:
    """Score one task; return {scores, evidence, version, rubric_sha, latency_s}."""
    t0 = time.monotonic()
    fm, body = parse_task(task_path)
    tags = list(fm.get("tags") or [])

    scores: dict[str, int] = {}
    evidence: dict[str, list[str]] = {}

    handlers = {
        "D1": score_d1_antifragility,
        "D2": score_d2_reliability,
        "D3": score_d3_usability,
        "D4": score_d4_portability,
    }
    for driver_id in drivers:
        if driver_id in handlers:
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

    args = p.parse_args(argv)
    if args.cmd == "one":
        return cmd_one(args.task_id, dry_run=args.dry_run, json_out=args.json)
    if args.cmd == "all":
        return cmd_all(dry_run=args.dry_run, limit=args.limit, statuses=args.statuses)
    if args.cmd == "determinism":
        return cmd_determinism(args.task_id, runs=args.runs)
    if args.cmd == "measure-a3":
        return cmd_measure_a3(n=args.n, output=args.output)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
