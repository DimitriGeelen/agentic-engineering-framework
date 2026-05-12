"""T-1798: Unit tests for lib/workflow_coverage.py.

Pins:
  - all-routable case → ok=True
  - unroutable workflow → ok=False
  - missing workflows dir → ok=True, empty results
  - malformed YAML → skipped, not crashing
  - workflow without worker_kind → counted in workflows, not in unroutables
  - format_audit_line emits a compact one-liner

PROJECT_ROOT is set per-fixture so the helper picks up tmp_path-based
workflows. lib/spawn._DISPATCHERS keys are read live (no monkeypatch) —
tests rely on the production set covering pi/ollama-loop/TermLink.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "lib"))


@pytest.fixture
def coverage(monkeypatch, tmp_path):
    """Reload workflow_coverage with PROJECT_ROOT pointing at a tmp dir.

    The module computes ``PROJECT_ROOT`` at import time, so we need a fresh
    import. Returns ``(module, workflows_dir)``.
    """
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    wf_dir = tmp_path / ".context" / "project" / "workflows"
    wf_dir.mkdir(parents=True)

    if "workflow_coverage" in sys.modules:
        del sys.modules["workflow_coverage"]
    import workflow_coverage  # noqa: E402
    return workflow_coverage, wf_dir


def _write_workflow(wf_dir: Path, name: str, worker_kind: str | None,
                    provider: str | None = None):
    """Helper: write a workflow YAML with optional worker_kind/provider.

    Pi workflows must declare a provider (T-1800) — pass ``provider="anthropic"``
    when writing pi fixtures to avoid the missing-provider FAIL.
    """
    body = f"name: {name}\n"
    if worker_kind is not None:
        body += f"worker_kind: {worker_kind}\n"
    if provider is not None:
        body += f"provider: {provider}\n"
    (wf_dir / f"{name}.yaml").write_text(body)


# ─── happy path ──────────────────────────────────────────────────────────────


def test_all_routable_returns_ok(coverage):
    wc, wf_dir = coverage
    # The three currently-routable worker_kinds (pi needs provider).
    _write_workflow(wf_dir, "wf-pi", "pi", provider="anthropic")
    _write_workflow(wf_dir, "wf-ollama", "ollama-loop")
    _write_workflow(wf_dir, "wf-tl", "TermLink")

    r = wc.check_workflow_dispatcher_coverage()
    assert r["ok"] is True
    assert len(r["workflows"]) == 3
    assert r["unroutable_workflows"] == []
    assert r["pi_workflows_missing_provider"] == []


def test_workflow_without_worker_kind_not_unroutable(coverage):
    """A workflow that doesn't declare worker_kind is fine (resolver falls
    back to default.yaml at run time)."""
    wc, wf_dir = coverage
    _write_workflow(wf_dir, "wf-interactive", None)
    _write_workflow(wf_dir, "wf-pi", "pi", provider="anthropic")

    r = wc.check_workflow_dispatcher_coverage()
    assert r["ok"] is True
    assert len(r["workflows"]) == 2
    # The interactive workflow is counted but its worker_kind is empty.
    interactives = [w for w in r["workflows"] if w["name"] == "wf-interactive"]
    assert interactives[0]["worker_kind"] == ""


# ─── failure surface ─────────────────────────────────────────────────────────


def test_unroutable_workflow_fails(coverage):
    """A workflow declaring worker_kind: Task should be flagged."""
    wc, wf_dir = coverage
    _write_workflow(wf_dir, "wf-pi", "pi")
    _write_workflow(wf_dir, "wf-task", "Task")  # declarable but unroutable

    r = wc.check_workflow_dispatcher_coverage()
    assert r["ok"] is False
    bad = r["unroutable_workflows"]
    assert len(bad) == 1
    assert bad[0]["name"] == "wf-task"
    assert bad[0]["worker_kind"] == "Task"


def test_completely_invalid_worker_kind_fails(coverage):
    """A garbage worker_kind isn't in VALID either — still flagged as
    unroutable (the audit doesn't care about the distinction; both produce
    a runtime trap)."""
    wc, wf_dir = coverage
    _write_workflow(wf_dir, "wf-garbage", "frobnicate-3000")

    r = wc.check_workflow_dispatcher_coverage()
    assert r["ok"] is False
    assert r["unroutable_workflows"][0]["worker_kind"] == "frobnicate-3000"


# ─── degradation paths ──────────────────────────────────────────────────────


def test_missing_workflows_dir_returns_ok(monkeypatch, tmp_path):
    """No workflows directory → ok=True, empty workflows list (don't crash
    the audit on a project that hasn't created workflows yet)."""
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    if "workflow_coverage" in sys.modules:
        del sys.modules["workflow_coverage"]
    import workflow_coverage  # noqa: E402

    r = workflow_coverage.check_workflow_dispatcher_coverage()
    assert r["ok"] is True
    assert r["workflows"] == []
    assert r["unroutable_workflows"] == []


def test_malformed_yaml_skipped(coverage):
    """Garbled YAML should be skipped without crashing."""
    wc, wf_dir = coverage
    _write_workflow(wf_dir, "wf-pi", "pi")
    (wf_dir / "wf-broken.yaml").write_text("not: : valid: ::: yaml [\n")

    r = wc.check_workflow_dispatcher_coverage()
    # The good one is parsed; the bad one is skipped silently.
    names = sorted(w["name"] for w in r["workflows"])
    assert names == ["wf-pi"]


def test_yaml_with_non_dict_root_skipped(coverage):
    """Top-level list/scalar should be skipped, not crash."""
    wc, wf_dir = coverage
    (wf_dir / "wf-list.yaml").write_text("- just\n- a\n- list\n")
    (wf_dir / "wf-scalar.yaml").write_text("hello\n")
    _write_workflow(wf_dir, "wf-pi", "pi")

    r = wc.check_workflow_dispatcher_coverage()
    names = sorted(w["name"] for w in r["workflows"])
    assert names == ["wf-pi"]


# ─── declarable_but_unroutable invariant ─────────────────────────────────────


def test_declarable_but_unroutable_reflects_set_difference(coverage):
    """The reported set equals VALID_WORKER_KINDS - _DISPATCHERS.keys().

    Today: {Task}. If a new worker_kind is added to either side, this
    invariant tightens automatically — the test doesn't hardcode {Task}.
    """
    wc, wf_dir = coverage
    r = wc.check_workflow_dispatcher_coverage()
    expected = sorted(set(r["valid_kinds"]) - set(r["routable"]))
    assert r["declarable_but_unroutable"] == expected


# ─── format_audit_line ──────────────────────────────────────────────────────


def test_format_audit_line_ok(coverage):
    wc, wf_dir = coverage
    _write_workflow(wf_dir, "wf-pi", "pi", provider="anthropic")
    line = wc.format_audit_line(wc.check_workflow_dispatcher_coverage())
    assert "all 1 workflows route" in line
    assert "declarable-but-unroutable" in line


def test_format_audit_line_fail_unroutable(coverage):
    wc, wf_dir = coverage
    _write_workflow(wf_dir, "wf-pi", "pi", provider="anthropic")
    _write_workflow(wf_dir, "wf-task", "Task")
    line = wc.format_audit_line(wc.check_workflow_dispatcher_coverage())
    assert "unroutable worker_kind" in line
    assert "wf-task(Task)" in line


# ─── T-1800: provider coverage ──────────────────────────────────────────────


def test_pi_with_provider_returns_ok(coverage):
    """A pi workflow declaring both worker_kind and provider passes."""
    wc, wf_dir = coverage
    _write_workflow(wf_dir, "wf-pi", "pi", provider="anthropic")

    r = wc.check_workflow_dispatcher_coverage()
    assert r["ok"] is True
    assert r["pi_workflows_missing_provider"] == []
    # provider field also surfaced on the workflow row
    rows = [w for w in r["workflows"] if w["name"] == "wf-pi"]
    assert rows[0]["provider"] == "anthropic"


def test_pi_without_provider_fails(coverage):
    """A pi workflow lacking provider raises SpawnError at runtime — flag it."""
    wc, wf_dir = coverage
    _write_workflow(wf_dir, "wf-pi-no-provider", "pi")  # missing provider

    r = wc.check_workflow_dispatcher_coverage()
    assert r["ok"] is False
    bad = r["pi_workflows_missing_provider"]
    assert len(bad) == 1
    assert bad[0]["name"] == "wf-pi-no-provider"
    assert bad[0]["worker_kind"] == "pi"


def test_non_pi_without_provider_not_flagged(coverage):
    """provider is pi-specific; ollama-loop/TermLink workflows don't need it."""
    wc, wf_dir = coverage
    _write_workflow(wf_dir, "wf-ollama", "ollama-loop")  # no provider — fine
    _write_workflow(wf_dir, "wf-tl", "TermLink")  # no provider — fine

    r = wc.check_workflow_dispatcher_coverage()
    assert r["ok"] is True
    assert r["pi_workflows_missing_provider"] == []


def test_format_audit_line_surfaces_missing_provider(coverage):
    wc, wf_dir = coverage
    _write_workflow(wf_dir, "wf-pi-no-prov", "pi")  # missing
    line = wc.format_audit_line(wc.check_workflow_dispatcher_coverage())
    assert "pi workflow(s) missing provider" in line
    assert "wf-pi-no-prov" in line


def test_format_audit_line_combines_both_failure_classes(coverage):
    """When both unroutable AND missing-provider are present, both are
    surfaced in the audit line."""
    wc, wf_dir = coverage
    _write_workflow(wf_dir, "wf-pi-no-prov", "pi")  # missing provider
    _write_workflow(wf_dir, "wf-task", "Task")  # unroutable
    line = wc.format_audit_line(wc.check_workflow_dispatcher_coverage())
    assert "unroutable worker_kind" in line
    assert "pi workflow(s) missing provider" in line
