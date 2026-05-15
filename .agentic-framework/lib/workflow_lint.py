"""Workflow schema linter for `.context/project/workflows/*.yaml`.

Origin: T-1694 (workflow schema check) — heredoc-embedded in `bin/fw doctor`.
Extracted to a standalone module by T-1807 (dispatch-safety slice 3) so the
pause-field rules can be unit-tested without invoking `fw doctor`.

Schema rules (kept in sync with `lib/resolver.py:VALID_WORKER_KINDS`):

  - root must be a mapping with `task_type`
  - inline:true forbids dispatch fields
  - non-inline requires: task_type, worker_kind, model, effort, prompt_template,
    allowed_tools, cost_cap_usd, cwd
  - worker_kind ∈ {Task, TermLink, pi, ollama-loop}
  - prompt_template must resolve to an existing file
  - prompt_strategy ∈ {static, assembled, meta-prompted}
  - meta_model required iff prompt_strategy == meta-prompted
  - default.yaml missing → WARN

Pause-field rules (T-1807):

  - allow_pause if present must be Python bool (not "true"/"yes" strings)
  - pause_threshold if present must be in {low, medium, high}
  - pause_preamble if present must be a path string resolving to a file
  - pause_threshold or pause_preamble without allow_pause:true → WARN (dead config)
  - inline:true forbids the three pause fields (no dispatch envelope)
"""

from __future__ import annotations

import glob
import os
from pathlib import Path
from typing import Any, Dict, List, Tuple

try:
    import yaml
except ImportError:  # pragma: no cover - exercised in environments without yaml
    yaml = None  # type: ignore[assignment]


# Kept in sync with bin/fw and lib/resolver.py:VALID_WORKER_KINDS (T-1734/T-1735).
VALID_WORKER_KINDS = {"Task", "TermLink", "pi", "ollama-loop"}
VALID_PROMPT_STRATEGIES = {"static", "assembled", "meta-prompted"}
VALID_PAUSE_THRESHOLDS = {"low", "medium", "high"}

INLINE_FORBIDDEN_DISPATCH = {
    "worker_kind", "model", "effort", "prompt_template", "prompt_strategy",
    "meta_model", "meta_template", "allowed_tools", "cost_cap_usd", "cwd",
    "provider", "variants", "outcome_evaluator", "env",
}
INLINE_FORBIDDEN_PAUSE = {"allow_pause", "pause_threshold", "pause_preamble"}
INLINE_FORBIDDEN = INLINE_FORBIDDEN_DISPATCH | INLINE_FORBIDDEN_PAUSE

DISPATCH_REQUIRED = {
    "task_type", "worker_kind", "model", "effort", "prompt_template",
    "allowed_tools", "cost_cap_usd", "cwd",
}


def _lint_pause_fields(rel: str, data: Dict[str, Any], project_root: Path) -> List[Tuple[str, str]]:
    """Lint the three pause-related fields per T-1807. Returns (level, msg) tuples."""
    findings: List[Tuple[str, str]] = []

    has_allow_pause = "allow_pause" in data
    allow_pause = data.get("allow_pause")
    if has_allow_pause and not isinstance(allow_pause, bool):
        findings.append((
            "ERROR",
            f"{rel}: allow_pause={allow_pause!r} must be a YAML boolean (true/false), "
            f"got {type(allow_pause).__name__}",
        ))

    if "pause_threshold" in data:
        threshold = data["pause_threshold"]
        if not isinstance(threshold, str) or threshold not in VALID_PAUSE_THRESHOLDS:
            findings.append((
                "ERROR",
                f"{rel}: pause_threshold={threshold!r} not in {sorted(VALID_PAUSE_THRESHOLDS)}",
            ))

    if "pause_preamble" in data:
        preamble = data["pause_preamble"]
        if not isinstance(preamble, str):
            findings.append((
                "ERROR",
                f"{rel}: pause_preamble={preamble!r} must be a path string",
            ))
        else:
            full = project_root / preamble
            if not full.is_file():
                findings.append((
                    "ERROR",
                    f"{rel}: pause_preamble={preamble!r} does not resolve to an existing file",
                ))

    # Dead-config WARN: threshold/preamble set without allow_pause:true.
    # Skip when allow_pause is set to an invalid (non-bool) type — the ERROR
    # above already names that file, no need to pile on a second WARN.
    suppress_dead_warn = has_allow_pause and not isinstance(allow_pause, bool)
    if not suppress_dead_warn and allow_pause is not True:
        for dead_field in ("pause_threshold", "pause_preamble"):
            if dead_field in data:
                findings.append((
                    "WARN",
                    f"{rel}: {dead_field} set but allow_pause is not true — field is dead "
                    f"(Resolver will not read it). Set allow_pause:true to activate.",
                ))

    return findings


def lint_workflows(project_root: str | Path) -> List[Tuple[str, str]]:
    """Lint every workflow yaml under .context/project/workflows/.

    Returns a list of (level, message) tuples where level is one of
    'ERROR' | 'WARN' | 'COUNT'. The COUNT entry's message is the integer
    file-count (as str) so callers can render it without re-globbing.
    """
    root = Path(project_root)
    if yaml is None:
        return [("FAIL", "python3 yaml module missing")]

    wf_dir = root / ".context" / "project" / "workflows"
    files = sorted(glob.glob(str(wf_dir / "*.yaml")))

    findings: List[Tuple[str, str]] = []
    count = 0
    has_default = False

    for f in files:
        rel = os.path.relpath(f, root)
        count += 1
        if os.path.basename(f) == "default.yaml":
            has_default = True
        try:
            with open(f) as fh:
                data = yaml.safe_load(fh) or {}
        except yaml.YAMLError as e:
            findings.append(("ERROR", f"{rel}: YAML parse error: {e}"))
            continue
        if not isinstance(data, dict):
            findings.append(("ERROR", f"{rel}: root must be a mapping"))
            continue
        if "task_type" not in data:
            findings.append(("ERROR", f"{rel}: missing required key 'task_type'"))
        if data.get("inline") is True:
            offenders = INLINE_FORBIDDEN & set(data.keys())
            if offenders:
                findings.append((
                    "ERROR",
                    f"{rel}: inline:true cannot co-exist with dispatch fields: {sorted(offenders)}",
                ))
            continue
        missing = DISPATCH_REQUIRED - set(data.keys())
        if missing:
            findings.append((
                "ERROR",
                f"{rel}: missing required key(s): {sorted(missing)}",
            ))
            continue
        wk = data.get("worker_kind")
        if wk not in VALID_WORKER_KINDS:
            findings.append((
                "ERROR",
                f"{rel}: worker_kind={wk!r} not in {sorted(VALID_WORKER_KINDS)}",
            ))
        pt = data.get("prompt_template")
        if pt and not (root / pt).is_file():
            findings.append((
                "ERROR",
                f"{rel}: prompt_template={pt!r} does not resolve to an existing file",
            ))
        ps = data.get("prompt_strategy", "assembled")
        if ps not in VALID_PROMPT_STRATEGIES:
            findings.append((
                "ERROR",
                f"{rel}: prompt_strategy={ps!r} not in {sorted(VALID_PROMPT_STRATEGIES)}",
            ))
        if ps == "meta-prompted" and "meta_model" not in data:
            findings.append((
                "ERROR",
                f"{rel}: prompt_strategy=meta-prompted requires meta_model",
            ))
        if ps != "meta-prompted" and "meta_model" in data:
            findings.append((
                "ERROR",
                f"{rel}: meta_model set but prompt_strategy={ps!r} (must be meta-prompted)",
            ))

        # T-1807: pause-field rules (only meaningful for non-inline workflows).
        findings.extend(_lint_pause_fields(rel, data, root))

    if not has_default and count > 0:
        findings.append((
            "WARN",
            "default.yaml missing — Q12 fallback will hard-error if any task_type lacks a workflow",
        ))

    findings.append(("COUNT", str(count)))
    return findings


def main(project_root: str) -> int:
    """CLI entry: print findings in the legacy `LEVEL|message` format that
    `bin/fw doctor` parses. Returns 0 (caller does the level-based gating).
    """
    for level, msg in lint_workflows(project_root):
        print(f"{level}|{msg}")
    return 0


if __name__ == "__main__":  # pragma: no cover
    import sys
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "."))
