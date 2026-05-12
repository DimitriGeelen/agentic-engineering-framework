#!/usr/bin/env python3
"""
workflow_coverage — audit-time check for workflow → dispatcher coverage.

T-1798 prevention slice: T-1776 surfaced a workflow whose declared
``worker_kind`` had no spawn handler (``default.yaml`` → ``TermLink``,
which raised ``NotImplementedError`` at runtime). The fix landed in T-1797
(added the handler), but the structural blind spot remains: nothing in the
substrate flags this class of gap before it fires.

This helper closes the blind spot. It cross-references every workflow's
declared ``worker_kind`` against the actually-routable set
(``lib.spawn._DISPATCHERS.keys()``) and against the declarable superset
(``lib.resolver.VALID_WORKER_KINDS``), then returns a structured report
for the audit script to render.

Decoupled from the audit driver so unit tests can pin behaviour without
spawning audit.sh.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path
from typing import Any, Dict


PROJECT_ROOT = Path(os.environ.get("PROJECT_ROOT", os.getcwd()))
WORKFLOWS_DIR = PROJECT_ROOT / ".context" / "project" / "workflows"
LIB_DIR = Path(__file__).resolve().parent


def _import_dispatcher_keys() -> set:
    """Read ``_DISPATCHERS.keys()`` from ``lib.spawn`` without side effects.

    spawn.py uses sibling-imports (sys.path insert); add lib/ to path before
    importing. Returns empty set on import failure so the caller can degrade
    gracefully (rather than crashing the audit).
    """
    if str(LIB_DIR) not in sys.path:
        sys.path.insert(0, str(LIB_DIR))
    try:
        import spawn  # noqa: PLC0415 — deferred import by design
    except Exception:
        return set()
    return set(getattr(spawn, "_DISPATCHERS", {}).keys())


def _import_valid_worker_kinds() -> set:
    """Read ``VALID_WORKER_KINDS`` from ``lib.resolver``. Same import
    contract as ``_import_dispatcher_keys``."""
    if str(LIB_DIR) not in sys.path:
        sys.path.insert(0, str(LIB_DIR))
    try:
        import resolver  # noqa: PLC0415
    except Exception:
        return set()
    return set(getattr(resolver, "VALID_WORKER_KINDS", set()))


def _parse_workflows(workflows_dir: Path) -> Dict[str, str]:
    """Return ``{workflow_name: worker_kind}`` for every YAML file in
    ``workflows_dir``. Workflows without a ``worker_kind`` field are
    represented as ``{name: ""}``. Malformed YAML files are skipped.
    """
    import yaml  # local — lazy so module imports without PyYAML

    out: Dict[str, str] = {}
    if not workflows_dir.is_dir():
        return out
    for path in sorted(workflows_dir.glob("*.yaml")):
        try:
            data = yaml.safe_load(path.read_text()) or {}
        except Exception:
            continue
        if not isinstance(data, dict):
            continue
        out[path.stem] = str(data.get("worker_kind") or "")
    return out


def check_workflow_dispatcher_coverage(
    workflows_dir: Path = None,
) -> Dict[str, Any]:
    """Cross-reference workflow worker_kinds against the spawn dispatcher set.

    Returns::

        {
          "workflows": [{"name": str, "worker_kind": str}, ...],
          "routable": [str, ...],                # _DISPATCHERS.keys()
          "valid_kinds": [str, ...],             # VALID_WORKER_KINDS
          "declarable_but_unroutable": [str, ...],  # VALID - routable
          "unroutable_workflows": [{"name", "worker_kind"}, ...],
          "ok": bool                              # True when no unroutables
        }

    Graceful on missing/malformed inputs: returns ok=True with empty lists.
    """
    wf_dir = workflows_dir or WORKFLOWS_DIR
    workflow_kinds = _parse_workflows(wf_dir)
    routable = _import_dispatcher_keys()
    valid = _import_valid_worker_kinds()

    workflows = [
        {"name": name, "worker_kind": wk}
        for name, wk in workflow_kinds.items()
    ]
    unroutable_workflows = [
        {"name": name, "worker_kind": wk}
        for name, wk in workflow_kinds.items()
        if wk and wk not in routable
    ]
    declarable_but_unroutable = sorted(valid - routable) if valid else []

    return {
        "workflows": workflows,
        "routable": sorted(routable),
        "valid_kinds": sorted(valid),
        "declarable_but_unroutable": declarable_but_unroutable,
        "unroutable_workflows": unroutable_workflows,
        "ok": len(unroutable_workflows) == 0,
    }


def format_audit_line(report: Dict[str, Any]) -> str:
    """Compact one-line summary used by audit.sh's PASS/FAIL emitter."""
    n_total = len(report["workflows"])
    n_unroutable = len(report["unroutable_workflows"])
    declarable_unroutable = report["declarable_but_unroutable"]
    if report["ok"]:
        return (
            f"all {n_total} workflows route to a registered dispatcher; "
            f"declarable-but-unroutable: {declarable_unroutable or 'none'}"
        )
    bad = ", ".join(
        f"{w['name']}({w['worker_kind']})"
        for w in report["unroutable_workflows"]
    )
    return f"{n_unroutable}/{n_total} workflows declare an unroutable worker_kind: {bad}"


if __name__ == "__main__":
    import json
    report = check_workflow_dispatcher_coverage()
    print(json.dumps(report, indent=2))
    sys.exit(0 if report["ok"] else 1)
