#!/usr/bin/env python3
"""
T-1689 Spike S-1 — minimal Tier-2 (assembled) Resolver, end-to-end.

NOT production code. Lives in docs/reports/ per inception discipline.
After GO, port to lib/resolver.py.

Validates:
- Workflow lookup with default.yaml fallback (Q12)
- $VAR substitution from task frontmatter + recent dispatches
- Workflow + template SHA capture via git rev-parse
- dispatch_id generation (UUID4)
- dispatches.jsonl append (atomic O_APPEND)
- dispatch-blobs/<YYYY-MM>/<id>/ directory creation
- Telemetry round-trip (read back the row, walk the blob dir)
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Optional

import yaml


# Resolved paths (project root assumed = cwd)
PROJECT_ROOT = Path(os.environ.get("PROJECT_ROOT", os.getcwd()))
WORKFLOWS_DIR = PROJECT_ROOT / ".context" / "project" / "workflows"
DISPATCHES_LOG = PROJECT_ROOT / ".context" / "dispatches.jsonl"
BLOBS_ROOT = PROJECT_ROOT / ".context" / "dispatch-blobs"


# ---------------------------------------------------------------------------
# Step 1: Workflow lookup with Q12 fallback
# ---------------------------------------------------------------------------
class ResolverError(Exception):
    pass


def load_workflow(task_type: str) -> Dict[str, Any]:
    """Q12 fallback: <task_type>.yaml → default.yaml → hard error."""
    primary = WORKFLOWS_DIR / f"{task_type}.yaml"
    fallback = WORKFLOWS_DIR / "default.yaml"

    if primary.exists():
        wf = yaml.safe_load(primary.read_text())
        wf["_source_path"] = str(primary.relative_to(PROJECT_ROOT))
        wf["_resolved_via"] = "primary"
        return wf
    if fallback.exists():
        wf = yaml.safe_load(fallback.read_text())
        wf["_source_path"] = str(fallback.relative_to(PROJECT_ROOT))
        wf["_resolved_via"] = "default-fallback"
        wf["_original_task_type"] = task_type
        return wf
    raise ResolverError(
        f"Framework install bug: neither {primary} nor {fallback} exists. "
        "default.yaml is the Q12 contract — its absence is unrecoverable."
    )


# ---------------------------------------------------------------------------
# Step 2: Tier 2 ($VAR substitution + context selection)
# ---------------------------------------------------------------------------
VAR_PAT = re.compile(r"\$([A-Z][A-Z0-9_]*)")


def assemble_prompt(workflow: Dict[str, Any], task_context: Dict[str, str]) -> str:
    """Tier-2 assembled: load template, substitute $VAR slots, return rendered prompt.

    Sources for $VAR (precedence high → low):
    1. task_context (frontmatter, ACs, etc., passed in by caller)
    2. resolver-injected context (RECENT_DISPATCHES, HEALING_PATTERNS, PROJECT_ROOT)
    3. unresolved → empty string + warning
    """
    template_path = workflow.get("prompt_template")
    if not template_path:
        # inline workflows have no template — that's a caller bug at this stage
        raise ResolverError(
            f"Workflow {workflow.get('task_type')} has no prompt_template "
            "(inline workflows must not reach the resolver)"
        )
    template_full = PROJECT_ROOT / template_path
    if not template_full.exists():
        raise ResolverError(f"prompt_template missing: {template_full}")
    template = template_full.read_text()

    # Resolver-injected context. Cheap stubs for the spike — production would
    # actually mine dispatches.jsonl for last-N entries matching task_type.
    context = {
        "PROJECT_ROOT": str(PROJECT_ROOT),
        "RECENT_DISPATCHES": _recent_dispatches_summary(workflow.get("task_type", "default")),
        "HEALING_PATTERNS": "(none matched)",
    }
    context.update(task_context)  # task context wins precedence

    unresolved = []

    def repl(match: "re.Match[str]") -> str:
        var = match.group(1)
        if var in context:
            return context[var]
        unresolved.append(var)
        return ""

    rendered = VAR_PAT.sub(repl, template)
    if unresolved:
        rendered += f"\n\n<!-- resolver: unresolved $VARs: {sorted(set(unresolved))} -->\n"
    return rendered


def _recent_dispatches_summary(task_type: str, n: int = 3) -> str:
    """Tail dispatches.jsonl for last-N matching task_type. Cheap stub."""
    if not DISPATCHES_LOG.exists():
        return "(no prior dispatches)"
    matches = []
    with DISPATCHES_LOG.open() as f:
        for line in f:
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            if row.get("task_type") == task_type:
                matches.append(row)
    if not matches:
        return f"(no prior {task_type} dispatches)"
    tail = matches[-n:]
    return "\n".join(
        f"- {r.get('ts', '?')} dispatch_id={r.get('dispatch_id')} "
        f"outcome={r.get('outcome', 'pending')}"
        for r in tail
    )


# ---------------------------------------------------------------------------
# Step 3: SHAs via git rev-parse (A-2 validation)
# ---------------------------------------------------------------------------
def git_sha(path: str) -> Optional[str]:
    """git rev-parse HEAD:<path> with mtime fallback flag.

    Returns (sha, is_committed):
    - sha string + True if file is tracked & matches HEAD
    - mtime-hash + False if uncommitted (flagged so v2 can exclude)
    - None if file doesn't exist
    """
    if not (PROJECT_ROOT / path).exists():
        return None
    try:
        result = subprocess.run(
            ["git", "rev-parse", f"HEAD:{path}"],
            cwd=PROJECT_ROOT,
            capture_output=True,
            text=True,
            timeout=2,
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass
    # Fall back to mtime-hash
    import hashlib

    mt = (PROJECT_ROOT / path).stat().st_mtime
    return f"mtime:{hashlib.sha1(f'{path}:{mt}'.encode()).hexdigest()[:12]}"


# ---------------------------------------------------------------------------
# Step 4: Variant selection (Spike S-2)
# ---------------------------------------------------------------------------
import random


def select_variant(workflow: Dict[str, Any]) -> Optional[str]:
    """Weighted-random variant pick. Returns None if no variants declared."""
    variants = workflow.get("variants")
    if not variants:
        return None
    ids = list(variants.keys())
    weights = [variants[v].get("weight", 1.0) for v in ids]
    return random.choices(ids, weights=weights, k=1)[0]


# ---------------------------------------------------------------------------
# Step 5: Telemetry capture (dispatches.jsonl + blob dir)
# ---------------------------------------------------------------------------
DISPATCH_SCHEMA_VERSION = 1


def capture_dispatch(
    *,
    task_id: str,
    workflow: Dict[str, Any],
    rendered_prompt: str,
    variant_id: Optional[str] = None,
    parent_dispatch_id: Optional[str] = None,
    extra: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """Write the dispatches.jsonl row + create the blob directory.

    Returns the envelope dict (caller dispatches it via TermLink/pi/Task).
    """
    dispatch_id = str(uuid.uuid4())
    ts = datetime.now(timezone.utc).isoformat()
    yyyy_mm = ts[:7]
    blob_dir = BLOBS_ROOT / yyyy_mm / dispatch_id
    blob_dir.mkdir(parents=True, exist_ok=True)
    (blob_dir / "prompt.txt").write_text(rendered_prompt)

    workflow_path = workflow.get("_source_path", "")
    workflow_sha = git_sha(workflow_path) if workflow_path else None
    template_path = workflow.get("prompt_template", "")
    template_sha = git_sha(template_path) if template_path else None

    row: Dict[str, Any] = {
        "schema_version": DISPATCH_SCHEMA_VERSION,
        "ts": ts,
        "dispatch_id": dispatch_id,
        "task_id": task_id,
        "parent_dispatch_id": parent_dispatch_id,
        "task_type": workflow.get("_original_task_type") or workflow.get("task_type"),
        "workflow_id": workflow.get("task_type"),
        "workflow_sha": workflow_sha,
        "workflow_resolved_via": workflow.get("_resolved_via"),
        "prompt_strategy": workflow.get("prompt_strategy", "assembled"),
        "prompt_template": template_path,
        "template_sha": template_sha,
        "worker_kind": workflow.get("worker_kind"),
        "model": workflow.get("model"),
        "effort": workflow.get("effort"),
        "variant_id": variant_id,
        "blob_dir": str(blob_dir.relative_to(PROJECT_ROOT)),
        "outcome": "pending",  # back-prop fills this on task completion (T-1690)
    }
    if extra:
        row.update(extra)

    DISPATCHES_LOG.parent.mkdir(parents=True, exist_ok=True)
    with DISPATCHES_LOG.open("a") as f:
        f.write(json.dumps(row) + "\n")

    # Build the Delegation envelope the caller will dispatch
    envelope = {
        "dispatch_id": dispatch_id,
        "task_id": task_id,
        "task_type": row["task_type"],
        "worker_kind": workflow.get("worker_kind"),
        "model": workflow.get("model"),
        "effort": workflow.get("effort"),
        "prompt": rendered_prompt,
        "allowed_tools": workflow.get("allowed_tools", []),
        "cost_cap_usd": workflow.get("cost_cap_usd"),
        "cwd": workflow.get("cwd", "$PROJECT_ROOT").replace("$PROJECT_ROOT", str(PROJECT_ROOT)),
        "env": workflow.get("env", {}),
        "blob_dir": str(blob_dir),
    }
    return envelope


# ---------------------------------------------------------------------------
# End-to-end harness
# ---------------------------------------------------------------------------
def resolve(task_id: str, task_type: str, task_context: Dict[str, str]) -> Dict[str, Any]:
    """Main entry: workflow → assemble → capture → return envelope."""
    workflow = load_workflow(task_type)
    if workflow.get("inline") is True:
        # ADR-0002: inline workflows must never dispatch
        raise ResolverError(
            f"Workflow {task_type} is marked inline:true — Agent must do this "
            "work directly, not dispatch it"
        )
    rendered = assemble_prompt(workflow, task_context)
    variant_id = select_variant(workflow)
    envelope = capture_dispatch(
        task_id=task_id,
        workflow=workflow,
        rendered_prompt=rendered,
        variant_id=variant_id,
    )
    return envelope


# ---------------------------------------------------------------------------
# Spike harness — run with: python3 docs/reports/T-1689-spikes/resolver_spike.py
# ---------------------------------------------------------------------------
def main() -> int:
    print("=" * 60)
    print("T-1689 Spike S-1: end-to-end Tier-2 resolver")
    print("=" * 60)

    # 1. Test Q12 fallback path: ask for a non-existent task_type
    print("\n[1] Workflow lookup (fallback path)")
    t0 = time.perf_counter()
    envelope = resolve(
        task_id="T-1689",
        task_type="nonexistent-spike-type",
        task_context={
            "TASK_ID": "T-1689",
            "TASK_TYPE": "nonexistent-spike-type",
            "TASK_NAME": "v1 Resolver inception spike",
            "TASK_DESCRIPTION": "Validate end-to-end Tier-2 resolver path.",
            "ACCEPTANCE_CRITERIA": "(spike — synthetic)",
        },
    )
    elapsed = (time.perf_counter() - t0) * 1000
    print(f"    resolved via: {load_workflow('nonexistent-spike-type')['_resolved_via']}")
    print(f"    dispatch_id: {envelope['dispatch_id']}")
    print(f"    elapsed: {elapsed:.1f}ms")

    # 2. Verify telemetry round-trip
    print("\n[2] Telemetry round-trip")
    with DISPATCHES_LOG.open() as f:
        last_row = None
        for line in f:
            last_row = json.loads(line)
    assert last_row["dispatch_id"] == envelope["dispatch_id"], "round-trip failed"
    print(f"    dispatches.jsonl row matches: {last_row['dispatch_id']}")
    print(f"    workflow_sha: {last_row['workflow_sha']}")
    print(f"    template_sha: {last_row['template_sha']}")
    print(f"    workflow_resolved_via: {last_row['workflow_resolved_via']}")

    # 3. Verify blob dir exists with prompt
    blob_dir = PROJECT_ROOT / last_row["blob_dir"]
    assert blob_dir.is_dir(), f"blob dir missing: {blob_dir}"
    prompt_blob = blob_dir / "prompt.txt"
    assert prompt_blob.is_file(), "prompt.txt missing in blob dir"
    print(f"    blob dir: {blob_dir.relative_to(PROJECT_ROOT)} (prompt {prompt_blob.stat().st_size}B)")

    # 4. Test inline-workflow rejection
    print("\n[3] Inline-workflow rejection (ADR-0002)")
    try:
        resolve("T-1689", "inception", {})
        print("    FAIL — inline workflow was not rejected")
        return 1
    except ResolverError as e:
        print(f"    ✓ rejected: {e}")

    # 5. Spike S-2: variant selection distribution check (10000 draws for tighter CI)
    print("\n[4] Spike S-2: variant selection (10000 draws)")
    fake_wf = {
        "task_type": "test",
        "variants": {
            "A": {"weight": 0.7},
            "B": {"weight": 0.2},
            "C": {"weight": 0.1},
        },
    }
    n_draws = 10000
    counts = {"A": 0, "B": 0, "C": 0}
    random.seed(42)  # deterministic for reproducibility
    for _ in range(n_draws):
        v = select_variant(fake_wf)
        counts[v] += 1
    expected = {"A": 7000, "B": 2000, "C": 1000}
    print(f"    expected: {expected}")
    print(f"    observed: {counts}")
    for k in expected:
        # 3-sigma tolerance: stddev = sqrt(n*p*(1-p)); threshold = 3*stddev
        p = expected[k] / n_draws
        stddev = (n_draws * p * (1 - p)) ** 0.5
        diff = abs(counts[k] - expected[k])
        ok = diff <= 3 * stddev
        print(f"    {k}: |obs-exp|={diff:.0f}, 3σ={3*stddev:.0f} — {'OK' if ok else 'FAIL'}")
        if not ok:
            return 1

    # 6. Spike S-2 negative: no variants
    no_variant = {"task_type": "test", "variants": None}
    assert select_variant(no_variant) is None
    print("    no-variants case: select_variant returns None ✓")

    # 7. Latency budget end-to-end
    print("\n[5] End-to-end latency (10 dispatches)")
    times = []
    for i in range(10):
        t0 = time.perf_counter()
        resolve(
            task_id="T-1689",
            task_type=f"latency-probe-{i}",
            task_context={"TASK_ID": "T-1689"},
        )
        times.append((time.perf_counter() - t0) * 1000)
    print(f"    avg {sum(times)/len(times):.1f}ms, min {min(times):.1f}ms, max {max(times):.1f}ms")
    if max(times) > 500:
        print(f"    FAIL — max {max(times):.1f}ms exceeds 500ms NO-GO threshold")
        return 1

    print("\n" + "=" * 60)
    print("Spike S-1 + S-2: ALL CHECKS PASS")
    print("=" * 60)
    return 0


if __name__ == "__main__":
    sys.exit(main())
