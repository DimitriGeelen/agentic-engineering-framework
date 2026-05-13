"""Tests for lib/pause_resolve.py — operator-answer capture + re-dispatch.

Origin: T-1809 (dispatch-safety slice 5).
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import pytest

FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FRAMEWORK_ROOT / "lib"))


def _make_dispatch(
    dispatch_id: str,
    task_id: str,
    task_type: str,
    outcome: str,
    terminal_event: dict | None = None,
    retry_of: str | None = None,
):
    row = {
        "schema_version": 1,
        "ts": "2026-05-13T17:00:00+00:00",
        "dispatch_id": dispatch_id,
        "task_id": task_id,
        "task_type": task_type,
        "workflow_id": task_type,
        "worker_kind": "TermLink",
        "model": "sonnet",
        "outcome": outcome,
    }
    if terminal_event is not None:
        row["terminal_event"] = terminal_event
    if retry_of is not None:
        row["retry_of_dispatch_id"] = retry_of
    return row


def _setup_project(tmp_path: Path, dispatches: list[dict]):
    """Build a synthetic project root with workflows + a paused dispatch log."""
    # workflows: minimal `default` workflow with a prompt template.
    wf_dir = tmp_path / ".context" / "project" / "workflows"
    wf_dir.mkdir(parents=True, exist_ok=True)
    (wf_dir / "default.yaml").write_text(
        "task_type: default\n"
        "worker_kind: TermLink\n"
        "model: sonnet\n"
        "effort: medium\n"
        "prompt_template: prompts/default.md\n"
        "allowed_tools: [Read]\n"
        "cost_cap_usd: 1.0\n"
        "cwd: $PROJECT_ROOT\n"
        "allow_pause: true\n"
    )
    (tmp_path / "prompts").mkdir(exist_ok=True)
    (tmp_path / "prompts" / "default.md").write_text(
        "TASK $TASK_ID: $TASK_NAME\n\nACs:\n$ACCEPTANCE_CRITERIA\n"
    )
    # Minimal task file so load_task_frontmatter works.
    (tmp_path / ".tasks" / "active").mkdir(parents=True, exist_ok=True)
    (tmp_path / ".tasks" / "active" / "T-9999-test.md").write_text(
        "---\n"
        "id: T-9999\n"
        'name: "synthetic"\n'
        "workflow_type: build\n"
        "status: started-work\n"
        "owner: agent\n"
        "horizon: now\n"
        "tags: []\n"
        "created: 2026-05-13T00:00:00Z\n"
        "last_update: 2026-05-13T00:00:00Z\n"
        "---\n\n"
        "## Acceptance Criteria\n\n### Agent\n- [ ] do the thing\n"
    )
    # Dispatches log.
    log = tmp_path / ".context" / "dispatches.jsonl"
    log.write_text("\n".join(json.dumps(d) for d in dispatches) + "\n")
    return tmp_path


@pytest.fixture
def synthetic_project(tmp_path, monkeypatch):
    """Module-reload trick: pause_resolve + resolver both bind PROJECT_ROOT at
    import time. Setting the env var alone isn't enough — we have to reimport
    so module-level constants pick up the new value."""
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    # Force fresh imports
    for mod in [
        "pause_resolve",
        "dispatch_pause",
        "resolver",
        "workflow_lint",
    ]:
        sys.modules.pop(mod, None)
    return tmp_path


# ---------------------------------------------------------------------------
# Happy path
# ---------------------------------------------------------------------------


def test_resolve_paused_dispatch_writes_retry_row(synthetic_project):
    _setup_project(synthetic_project, [
        _make_dispatch(
            "abcdef1234567890",
            "T-9999",
            "default",
            "paused",
            terminal_event={
                "type": "pause_requested",
                "question": "Drop the legacy auth shim?",
                "assessment": {"severity": "high", "likelihood": "high"},
            },
        ),
    ])
    from pause_resolve import resolve_pause

    envelope, row = resolve_pause(
        "abcdef1234567890",
        "Yes, drop it — the migration is done.",
    )

    assert envelope["dispatch_id"] != "abcdef1234567890"  # new dispatch
    assert envelope["task_id"] == "T-9999"
    assert row["retry_of_dispatch_id"] == "abcdef1234567890"
    assert row["outcome"] == "pending"

    prompt = envelope["prompt"]
    assert prompt.startswith("[RE-DISPATCH — operator answered your pause]")
    assert "Drop the legacy auth shim?" in prompt
    assert "Yes, drop it — the migration is done." in prompt
    # Risk-policy preamble (allow_pause:true) still appears AFTER the re-dispatch block.
    assert "[RISK POLICY" in prompt
    assert prompt.index("[RE-DISPATCH") < prompt.index("[RISK POLICY")


def test_dry_run_does_not_write_log(synthetic_project):
    _setup_project(synthetic_project, [
        _make_dispatch("d-paused-001", "T-9999", "default", "paused",
                       terminal_event={"type": "pause_requested", "question": "?"}),
    ])
    from pause_resolve import resolve_pause

    log = synthetic_project / ".context" / "dispatches.jsonl"
    before = log.read_text()
    envelope, row = resolve_pause("d-paused-001", "answer", dry_run=True)
    after = log.read_text()
    assert before == after, "dry-run must not append to dispatches.jsonl"
    assert envelope["dispatch_id"]  # still minted


def test_prefix_matching(synthetic_project):
    _setup_project(synthetic_project, [
        _make_dispatch("abc12345-deadbeef", "T-9999", "default", "paused",
                       terminal_event={"type": "pause_requested", "question": "Q?"}),
    ])
    from pause_resolve import resolve_pause

    envelope, row = resolve_pause("abc12345", "answer")
    assert row["retry_of_dispatch_id"] == "abc12345-deadbeef"


# ---------------------------------------------------------------------------
# Error paths
# ---------------------------------------------------------------------------


def test_unknown_dispatch_raises(synthetic_project):
    _setup_project(synthetic_project, [
        _make_dispatch("d-paused", "T-9999", "default", "paused",
                       terminal_event={"type": "pause_requested"}),
    ])
    from pause_resolve import PauseResolveError, resolve_pause

    with pytest.raises(PauseResolveError, match="not found"):
        resolve_pause("nonexistent-id-12", "answer")


def test_non_paused_raises(synthetic_project):
    _setup_project(synthetic_project, [
        _make_dispatch("d-success", "T-9999", "default", "success"),
    ])
    from pause_resolve import PauseResolveError, resolve_pause

    with pytest.raises(PauseResolveError, match="not paused"):
        resolve_pause("d-success", "answer")


def test_already_resolved_raises(synthetic_project):
    _setup_project(synthetic_project, [
        _make_dispatch("d-paused", "T-9999", "default", "paused",
                       terminal_event={"type": "pause_requested", "question": "?"}),
        _make_dispatch("d-retry", "T-9999", "default", "success",
                       retry_of="d-paused"),
    ])
    from pause_resolve import PauseResolveError, resolve_pause

    with pytest.raises(PauseResolveError, match="already resolved"):
        resolve_pause("d-paused", "answer")


def test_empty_answer_raises(synthetic_project):
    _setup_project(synthetic_project, [
        _make_dispatch("d-paused", "T-9999", "default", "paused",
                       terminal_event={"type": "pause_requested"}),
    ])
    from pause_resolve import PauseResolveError, resolve_pause

    with pytest.raises(PauseResolveError, match="non-empty"):
        resolve_pause("d-paused", "")
    with pytest.raises(PauseResolveError, match="non-empty"):
        resolve_pause("d-paused", "   ")


def test_no_dispatches_log(tmp_path, monkeypatch):
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    for mod in ["pause_resolve", "dispatch_pause", "resolver"]:
        sys.modules.pop(mod, None)
    from pause_resolve import PauseResolveError, resolve_pause

    with pytest.raises(PauseResolveError, match="not found"):
        resolve_pause("anything", "answer")


# ---------------------------------------------------------------------------
# resolver.assemble_prompt: re-dispatch block ordering pinned here too
# ---------------------------------------------------------------------------


def test_assemble_prompt_no_pause_resolution_unchanged(synthetic_project):
    _setup_project(synthetic_project, [])
    from resolver import assemble_prompt

    workflow = {
        "task_type": "default",
        "prompt_template": "prompts/default.md",
        "prompt_strategy": "static",
        "allow_pause": False,
    }
    out = assemble_prompt(workflow, {"TASK_ID": "T-1"})
    assert "[RE-DISPATCH" not in out
    assert "[RISK POLICY" not in out


def test_assemble_prompt_redispatch_block_above_risk_preamble(synthetic_project):
    _setup_project(synthetic_project, [])
    from resolver import assemble_prompt

    workflow = {
        "task_type": "default",
        "prompt_template": "prompts/default.md",
        "prompt_strategy": "static",
        "allow_pause": True,
        "pause_threshold": "high",
    }
    out = assemble_prompt(
        workflow,
        {"TASK_ID": "T-1"},
        pause_resolution={"question": "Q?", "answer": "A!"},
    )
    assert "[RE-DISPATCH" in out
    assert "[RISK POLICY" in out
    assert out.index("[RE-DISPATCH") < out.index("[RISK POLICY")
    assert "Q?" in out
    assert "A!" in out


def test_assemble_prompt_redispatch_block_alone_no_risk_preamble(synthetic_project):
    """allow_pause:false but pause_resolution still set: re-dispatch block alone."""
    _setup_project(synthetic_project, [])
    from resolver import assemble_prompt

    workflow = {
        "task_type": "default",
        "prompt_template": "prompts/default.md",
        "prompt_strategy": "static",
        "allow_pause": False,
    }
    out = assemble_prompt(
        workflow,
        {"TASK_ID": "T-1"},
        pause_resolution={"question": "Q?", "answer": "A!"},
    )
    assert "[RE-DISPATCH" in out
    assert "[RISK POLICY" not in out
