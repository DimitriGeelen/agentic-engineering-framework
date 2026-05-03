"""T-1696: Unit tests for lib/resolver.py.

Pinned behaviors:
- Q12 fallback: <task_type>.yaml → default.yaml → ResolverError
- Inline workflow rejection (ADR-0002)
- Variant selection: weighted random with deterministic seed
- Telemetry capture: dry-run skips writes; real dispatch round-trips JSONL
- Tier 3 (meta-prompted) substrate-only mode falls through to assembled
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import pytest

# Resolve framework root from this test file so PROJECT_ROOT works in CI.
FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FRAMEWORK_ROOT / "lib"))


@pytest.fixture
def isolated_root(tmp_path, monkeypatch):
    """Spin up a fake project root so tests don't pollute the real
    .context/dispatches.jsonl. Reload the resolver module each time so it
    picks up the new PROJECT_ROOT."""
    (tmp_path / ".context" / "project" / "workflows").mkdir(parents=True)
    (tmp_path / ".context" / "project").mkdir(exist_ok=True)
    (tmp_path / "prompts").mkdir(exist_ok=True)
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    # Force reimport so module-level constants pick up new PROJECT_ROOT
    if "resolver" in sys.modules:
        del sys.modules["resolver"]
    import resolver as r  # noqa: E402

    return tmp_path, r


def _write_workflow(root: Path, name: str, body: dict) -> None:
    import yaml

    (root / ".context" / "project" / "workflows" / f"{name}.yaml").write_text(
        yaml.safe_dump(body)
    )


def _write_template(root: Path, rel: str, body: str) -> Path:
    full = root / rel
    full.parent.mkdir(parents=True, exist_ok=True)
    full.write_text(body)
    return full


# ---------------------------------------------------------------------------
# Q12 fallback
# ---------------------------------------------------------------------------
def test_q12_primary_match(isolated_root):
    root, r = isolated_root
    _write_workflow(root, "build", {"task_type": "build", "worker_kind": "TermLink"})
    wf = r.load_workflow("build")
    assert wf["_resolved_via"] == "primary"
    assert wf["task_type"] == "build"


def test_q12_fallback_to_default(isolated_root):
    root, r = isolated_root
    _write_workflow(root, "default", {"task_type": "default", "worker_kind": "TermLink"})
    wf = r.load_workflow("nonexistent-type")
    assert wf["_resolved_via"] == "default-fallback"
    assert wf["_original_task_type"] == "nonexistent-type"


def test_q12_hard_error_no_default(isolated_root):
    root, r = isolated_root
    with pytest.raises(r.ResolverError, match="default.yaml"):
        r.load_workflow("anything")


# ---------------------------------------------------------------------------
# Inline rejection (ADR-0002)
# ---------------------------------------------------------------------------
def test_inline_workflow_rejected(isolated_root):
    root, r = isolated_root
    _write_workflow(root, "inception", {"task_type": "inception", "inline": True})
    with pytest.raises(r.ResolverError, match="inline"):
        r.resolve("T-001", "inception", {})


# ---------------------------------------------------------------------------
# Prompt assembly
# ---------------------------------------------------------------------------
def test_assembled_var_substitution(isolated_root):
    root, r = isolated_root
    _write_template(root, "prompts/test.md", "Hello $TASK_NAME for $TASK_ID.")
    _write_workflow(
        root,
        "default",
        {
            "task_type": "default",
            "worker_kind": "TermLink",
            "model": "sonnet",
            "prompt_template": "prompts/test.md",
        },
    )
    wf = r.load_workflow("default")
    out = r.assemble_prompt(wf, {"TASK_ID": "T-1", "TASK_NAME": "demo"})
    assert "Hello demo for T-1." in out


def test_assembled_unresolved_var_marked(isolated_root):
    root, r = isolated_root
    _write_template(root, "prompts/test.md", "Has $UNKNOWN here.")
    _write_workflow(
        root, "default", {"task_type": "default", "prompt_template": "prompts/test.md"}
    )
    wf = r.load_workflow("default")
    out = r.assemble_prompt(wf, {})
    assert "Has  here." in out
    assert "unresolved" in out
    assert "UNKNOWN" in out


def test_static_strategy_skips_substitution(isolated_root):
    root, r = isolated_root
    _write_template(root, "prompts/test.md", "Literal $VAR not expanded.")
    _write_workflow(
        root,
        "default",
        {
            "task_type": "default",
            "prompt_template": "prompts/test.md",
            "prompt_strategy": "static",
        },
    )
    wf = r.load_workflow("default")
    out = r.assemble_prompt(wf, {"VAR": "expanded"})
    assert out == "Literal $VAR not expanded."


def test_meta_prompted_substrate_only_falls_through(isolated_root):
    """meta-prompted with meta_model_enabled=False behaves as assembled."""
    root, r = isolated_root
    _write_template(root, "prompts/test.md", "Hi $TASK_ID")
    _write_workflow(
        root,
        "default",
        {
            "task_type": "default",
            "prompt_template": "prompts/test.md",
            "prompt_strategy": "meta-prompted",
            "meta_model_enabled": False,
        },
    )
    wf = r.load_workflow("default")
    out = r.assemble_prompt(wf, {"TASK_ID": "T-1"})
    assert out == "Hi T-1"
    assert "META-PROMPT" not in out


def test_meta_prompted_enabled_emits_envelope(isolated_root):
    root, r = isolated_root
    _write_template(root, "prompts/test.md", "Seed for $TASK_ID")
    _write_workflow(
        root,
        "default",
        {
            "task_type": "default",
            "prompt_template": "prompts/test.md",
            "prompt_strategy": "meta-prompted",
            "meta_model_enabled": True,
            "meta_model": "claude-haiku-4-5",
        },
    )
    wf = r.load_workflow("default")
    out = r.assemble_prompt(wf, {"TASK_ID": "T-1"})
    assert "META-PROMPT" in out
    assert "claude-haiku-4-5" in out
    assert "Seed for T-1" in out


# ---------------------------------------------------------------------------
# Variant selection
# ---------------------------------------------------------------------------
def test_select_variant_no_variants_returns_none(isolated_root):
    _, r = isolated_root
    assert r.select_variant({"task_type": "x"}) is None


def test_select_variant_distribution_3sigma(isolated_root):
    """10000 draws @ 3σ tolerance — same harness as the spike (T-1689 S-2)."""
    import random

    _, r = isolated_root
    wf = {"variants": {"A": {"weight": 0.7}, "B": {"weight": 0.2}, "C": {"weight": 0.1}}}
    n = 10000
    counts = {"A": 0, "B": 0, "C": 0}
    random.seed(42)
    for _ in range(n):
        counts[r.select_variant(wf)] += 1
    expected = {"A": 7000, "B": 2000, "C": 1000}
    for k, exp in expected.items():
        p = exp / n
        sigma_3 = 3 * (n * p * (1 - p)) ** 0.5
        assert abs(counts[k] - exp) <= sigma_3, f"{k}: |{counts[k]}-{exp}| > 3σ={sigma_3:.0f}"


# ---------------------------------------------------------------------------
# Telemetry capture
# ---------------------------------------------------------------------------
def test_capture_dispatch_writes_jsonl_and_blob(isolated_root):
    root, r = isolated_root
    _write_template(root, "prompts/test.md", "Hi")
    _write_workflow(
        root,
        "default",
        {
            "task_type": "default",
            "worker_kind": "TermLink",
            "model": "sonnet",
            "prompt_template": "prompts/test.md",
        },
    )
    envelope, row = r.resolve("T-001", "default", {})
    assert envelope["dispatch_id"] == row["dispatch_id"]
    log = root / ".context" / "dispatches.jsonl"
    assert log.exists()
    last = json.loads(log.read_text().strip().splitlines()[-1])
    assert last["dispatch_id"] == envelope["dispatch_id"]
    assert last["task_id"] == "T-001"
    assert last["task_type"] == "default"
    blob_dir = root / row["blob_dir"]
    assert blob_dir.is_dir()
    assert (blob_dir / "prompt.txt").is_file()


def test_dry_run_skips_writes(isolated_root):
    root, r = isolated_root
    _write_template(root, "prompts/test.md", "Hi")
    _write_workflow(root, "default", {"task_type": "default", "prompt_template": "prompts/test.md"})
    log = root / ".context" / "dispatches.jsonl"
    assert not log.exists()
    envelope, row = r.resolve("T-001", "default", {}, dry_run=True)
    assert not log.exists(), "dry-run should not append to JSONL"
    blob_dir = root / row["blob_dir"]
    assert not blob_dir.exists(), "dry-run should not mkdir blob"
    assert envelope["dispatch_id"] == row["dispatch_id"]


# ---------------------------------------------------------------------------
# Healing patterns + recent dispatches
# ---------------------------------------------------------------------------
def test_healing_patterns_loads_from_yaml(isolated_root):
    root, r = isolated_root
    (root / ".context" / "project" / "patterns.yaml").write_text(
        "failure_patterns:\n"
        "  - id: FP-001\n"
        "    pattern: 'Demo'\n"
        "    mitigation: 'Use the new approach'\n"
        "    date_learned: 2026-05-01\n"
    )
    out = r._healing_patterns_summary("anything")
    assert "FP-001" in out
    assert "Demo" in out


def test_healing_patterns_no_yaml_returns_friendly(isolated_root):
    _, r = isolated_root
    out = r._healing_patterns_summary("anything")
    assert "no patterns.yaml" in out


def test_recent_dispatches_summary_filters_task_type(isolated_root):
    root, r = isolated_root
    log = root / ".context" / "dispatches.jsonl"
    log.parent.mkdir(parents=True, exist_ok=True)
    log.write_text(
        json.dumps({"task_type": "build", "dispatch_id": "abc", "ts": "2026-05-03"}) + "\n"
        + json.dumps({"task_type": "test", "dispatch_id": "def", "ts": "2026-05-03"}) + "\n"
    )
    out = r._recent_dispatches_summary("build")
    assert "abc" in out
    assert "def" not in out


def test_few_shot_examples_loader(isolated_root):
    root, r = isolated_root
    examples = root / "prompts" / "examples" / "build"
    examples.mkdir(parents=True)
    (examples / "ex1.md").write_text("Example body 1")
    out = r._few_shot_examples("build")
    assert "Example body 1" in out
    assert "Example: ex1" in out


# ---------------------------------------------------------------------------
# Atomic write helper (D-074)
# ---------------------------------------------------------------------------
def test_atomic_write_uses_per_call_tmp(isolated_root, tmp_path):
    _, r = isolated_root
    target = tmp_path / "out.txt"
    r.atomic_write_text(target, "hello")
    assert target.read_text() == "hello"
    # Verify no leftover .tmp file
    leftover = list(tmp_path.glob("*.tmp.*"))
    assert leftover == []
