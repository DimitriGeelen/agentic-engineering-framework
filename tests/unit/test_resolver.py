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


def test_capture_dispatch_sets_worker_git_identity(isolated_root, monkeypatch):
    """T-2917: a dispatch-spawned worker's envelope carries a git identity
    distinct from the operator's, joinable back to this dispatch_id."""
    root, r = isolated_root
    monkeypatch.setenv("FW_DISPATCH_ORIGIN", "systemd:resolver-loop.service")
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
    env = envelope["env"]
    assert env["GIT_AUTHOR_NAME"] == "fw worker (resolver-loop)"
    assert env["GIT_AUTHOR_EMAIL"] == env["GIT_COMMITTER_EMAIL"]
    assert env["GIT_AUTHOR_NAME"] == env["GIT_COMMITTER_NAME"]
    assert env["GIT_AUTHOR_EMAIL"].startswith("dispatch+")
    assert env["GIT_AUTHOR_EMAIL"].endswith("@aef.local")
    # dispatch_id joinability: the email's short id is a prefix of the real dispatch_id.
    short = env["GIT_AUTHOR_EMAIL"].split("+", 1)[1].split("@", 1)[0]
    assert row["dispatch_id"].startswith(short)
    # And it is not any plausible operator identity string.
    assert "Dimitri" not in env["GIT_AUTHOR_NAME"]
    assert "@" not in env["GIT_AUTHOR_NAME"]


def test_capture_dispatch_mechanism_distinguishes_origin(isolated_root, monkeypatch):
    """T-2917 AC: a reader must be able to tell a resolver-loop worker from a
    manually-triggered resolver dispatch by identity name alone."""
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

    monkeypatch.setenv("FW_DISPATCH_ORIGIN", "systemd:resolver-loop.service")
    envelope_loop, _ = r.resolve("T-001", "default", {})

    monkeypatch.setenv("FW_DISPATCH_ORIGIN", "cli:manual-run")
    envelope_cli, _ = r.resolve("T-001", "default", {})

    assert envelope_loop["env"]["GIT_AUTHOR_NAME"] != envelope_cli["env"]["GIT_AUTHOR_NAME"]
    assert "resolver-loop" in envelope_loop["env"]["GIT_AUTHOR_NAME"]
    assert "resolver-cli" in envelope_cli["env"]["GIT_AUTHOR_NAME"]


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


# ---------------------------------------------------------------------------
# T-1806 / ADR-0004 — dispatch-safety slice 2: risk-policy preamble injection
# ---------------------------------------------------------------------------


def test_risk_preamble_contains_core_directives(isolated_root):
    """Baseline preamble must teach Workers the pause protocol explicitly:
    event type, JSON shape, severity x likelihood trigger, threshold,
    no-timeout-fallback rule."""
    _, r = isolated_root
    p = r._risk_policy_preamble({"pause_threshold": "high"})
    assert "pause_requested" in p
    assert "severity" in p.lower()
    assert "likelihood" in p.lower()
    assert "pause_threshold" in p
    assert "high" in p  # threshold value substituted
    assert '"type": "pause_requested"' in p  # JSON shape present
    # Anti-timeout-fallback rule (grid-power)
    assert "silence is not consent" in p or "DO NOT timeout" in p


def test_risk_preamble_default_threshold_is_high(isolated_root):
    """When pause_threshold is not set, the preamble uses `high` as default
    (rare-pause default per ADR-0004)."""
    _, r = isolated_root
    p = r._risk_policy_preamble({})
    assert "is: high" in p or "pause_threshold is: high" in p or " high\n" in p


def test_risk_preamble_substitutes_workflow_threshold(isolated_root):
    """pause_threshold from workflow is substituted into the preamble."""
    _, r = isolated_root
    p = r._risk_policy_preamble({"pause_threshold": "medium"})
    assert "medium" in p
    # Default literal "high" should not appear as the threshold value
    # (it may appear in the severity/likelihood enum literals — that's fine).
    # Check that the explicit threshold value line says "medium":
    assert "is: medium" in p or "threshold is: medium" in p


def test_assemble_prompt_no_preamble_when_allow_pause_absent(isolated_root):
    """allow_pause absent → no preamble injected (existing workflows unchanged)."""
    root, r = isolated_root
    _write_template(root, "prompts/test.md", "BODY")
    _write_workflow(
        root,
        "default",
        {"task_type": "default", "prompt_template": "prompts/test.md"},
    )
    wf = r.load_workflow("default")
    out = r.assemble_prompt(wf, {})
    assert "RISK POLICY" not in out
    assert "pause_requested" not in out
    assert "BODY" in out


def test_assemble_prompt_no_preamble_when_allow_pause_false(isolated_root):
    """Explicit allow_pause: false → no preamble (opt-out is explicit)."""
    root, r = isolated_root
    _write_template(root, "prompts/test.md", "BODY")
    _write_workflow(
        root,
        "default",
        {"task_type": "default", "prompt_template": "prompts/test.md",
         "allow_pause": False},
    )
    wf = r.load_workflow("default")
    out = r.assemble_prompt(wf, {})
    assert "RISK POLICY" not in out


def test_assemble_prompt_injects_preamble_when_allow_pause_true(isolated_root):
    """allow_pause: true → preamble prepended; body still follows."""
    root, r = isolated_root
    _write_template(root, "prompts/test.md", "TASK BODY HERE")
    _write_workflow(
        root,
        "default",
        {"task_type": "default", "prompt_template": "prompts/test.md",
         "allow_pause": True, "pause_threshold": "high"},
    )
    wf = r.load_workflow("default")
    out = r.assemble_prompt(wf, {})
    # Preamble first
    assert out.startswith("[RISK POLICY")
    # Body follows
    assert "TASK BODY HERE" in out
    # Preamble appears before body
    assert out.index("RISK POLICY") < out.index("TASK BODY HERE")


def test_assemble_prompt_preamble_with_static_strategy(isolated_root):
    """static strategy + allow_pause → preamble prepended; body kept verbatim
    (no $VAR substitution)."""
    root, r = isolated_root
    _write_template(root, "prompts/test.md", "Literal $UNIQUEVAR kept verbatim.")
    _write_workflow(
        root,
        "default",
        {"task_type": "default", "prompt_template": "prompts/test.md",
         "prompt_strategy": "static", "allow_pause": True},
    )
    wf = r.load_workflow("default")
    out = r.assemble_prompt(wf, {"UNIQUEVAR": "REPLACED"})
    assert "RISK POLICY" in out
    assert "$UNIQUEVAR" in out  # static: literal $VAR survives
    assert "REPLACED" not in out  # nothing substituted body-side
    # ensure prepend ordering
    assert out.index("RISK POLICY") < out.index("$UNIQUEVAR")


def test_assemble_prompt_custom_preamble_path(isolated_root):
    """Workflow pause_preamble path → custom preamble used."""
    root, r = isolated_root
    _write_template(root, "prompts/test.md", "BODY")
    custom = root / "prompts" / "risk" / "custom.md"
    custom.parent.mkdir(parents=True)
    custom.write_text("[CUSTOM PREAMBLE]\nCustom directive about $PAUSE_THRESHOLD")
    _write_workflow(
        root,
        "default",
        {"task_type": "default", "prompt_template": "prompts/test.md",
         "allow_pause": True, "pause_threshold": "medium",
         "pause_preamble": "prompts/risk/custom.md"},
    )
    wf = r.load_workflow("default")
    out = r.assemble_prompt(wf, {})
    assert "CUSTOM PREAMBLE" in out
    assert "Custom directive about medium" in out  # $PAUSE_THRESHOLD substituted in custom
    assert "RISK POLICY" not in out  # baseline not used


def test_assemble_prompt_custom_preamble_missing_falls_back(isolated_root, capsys):
    """Missing pause_preamble file → warn on stderr, use baseline."""
    root, r = isolated_root
    _write_template(root, "prompts/test.md", "BODY")
    _write_workflow(
        root,
        "default",
        {"task_type": "default", "prompt_template": "prompts/test.md",
         "allow_pause": True,
         "pause_preamble": "prompts/risk/does-not-exist.md"},
    )
    wf = r.load_workflow("default")
    out = r.assemble_prompt(wf, {})
    captured = capsys.readouterr()
    assert "unreadable" in captured.err
    assert "does-not-exist.md" in captured.err
    # Fell back to baseline
    assert "RISK POLICY" in out


# ---------------------------------------------------------------------------
# T-2915: in-flight latch expiry — a dispatch row with no terminal_event must
# NOT exclude its task forever. Both directions are pinned so the test cannot
# pass vacuously: a row within the age bound still latches (worker presumed
# running); a row beyond it no longer does (worker presumed abandoned).
# ---------------------------------------------------------------------------
def _write_open_dispatch(root: Path, task_id: str, age_min: float) -> None:
    """Append a dispatch row with NO terminal_event, timestamped `age_min`
    minutes in the past — simulates a worker that never reported back."""
    import datetime

    log = root / ".context" / "dispatches.jsonl"
    log.parent.mkdir(parents=True, exist_ok=True)
    ts = (
        datetime.datetime.now(datetime.timezone.utc)
        - datetime.timedelta(minutes=age_min)
    ).isoformat()
    row = {
        "schema_version": 1,
        "ts": ts,
        "dispatch_id": f"dd-{task_id}-{age_min}",
        "task_id": task_id,
        "task_type": "default",
        "worker_kind": "TermLink",
        "outcome": None,
        "origin": "test-seed",
    }
    with log.open("a") as f:
        f.write(json.dumps(row) + "\n")


def test_inflight_within_age_bound_still_latches(isolated_root):
    """A dispatch row younger than the age bound is still presumed
    in-flight — the picker must not double-dispatch a worker that may
    genuinely still be running."""
    root, r = isolated_root
    _write_open_dispatch(root, "T-9201", age_min=10)
    inflight = r._inflight_task_ids(max_age_min=60)
    assert "T-9201" in inflight
    stale = r._stale_inflight_ids(max_age_min=60)
    assert "T-9201" not in stale


def test_inflight_beyond_age_bound_expires(isolated_root):
    """A dispatch row older than the age bound is presumed abandoned — it
    must NOT latch its task out of the loop forever (T-2915 origin: nine
    tasks locked out for five weeks by exactly this gap)."""
    root, r = isolated_root
    _write_open_dispatch(root, "T-9202", age_min=500)
    inflight = r._inflight_task_ids(max_age_min=60)
    assert "T-9202" not in inflight
    stale = r._stale_inflight_ids(max_age_min=60)
    assert "T-9202" in stale
    assert stale["T-9202"]["age_min"] > 60


def test_inflight_default_age_bound_is_documented_and_positive(isolated_root):
    """Default resolves from FW_RESOLVER_INFLIGHT_MAX_AGE_MIN, falling back
    to the documented module constant when unset/invalid."""
    root, r = isolated_root
    os.environ.pop("FW_RESOLVER_INFLIGHT_MAX_AGE_MIN", None)
    assert r._inflight_max_age_min() == r._INFLIGHT_MAX_AGE_MIN_DEFAULT
    assert r._inflight_max_age_min() > 0


def test_inflight_age_bound_env_override(isolated_root, monkeypatch):
    """FW_RESOLVER_INFLIGHT_MAX_AGE_MIN overrides the default — used by the
    picker/loop/latched CLI surfaces without a code change."""
    root, r = isolated_root
    monkeypatch.setenv("FW_RESOLVER_INFLIGHT_MAX_AGE_MIN", "30")
    assert r._inflight_max_age_min() == 30
    _write_open_dispatch(root, "T-9203", age_min=45)
    # 45min old, 30min bound → expired.
    assert "T-9203" not in r._inflight_task_ids()
    assert "T-9203" in r._stale_inflight_ids()
