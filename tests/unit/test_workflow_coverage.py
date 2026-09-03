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
                    provider: str | None = None,
                    inline: bool = False):
    """Helper: write a workflow YAML with optional worker_kind/provider/inline.

    Pi workflows must declare a provider (T-1800) — pass ``provider="anthropic"``
    when writing pi fixtures to avoid the missing-provider FAIL.

    T-1872: pass ``inline=True`` to fixture inline workflows (fw inception,
    fw grill, fw design-dialogue) — those are non-resolver-driven and must
    be excluded from staleness detection.
    """
    body = f"name: {name}\n"
    if worker_kind is not None:
        body += f"worker_kind: {worker_kind}\n"
    if provider is not None:
        body += f"provider: {provider}\n"
    if inline:
        body += "inline: true\n"
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


def test_ollama_direct_not_flagged_unroutable(coverage):
    """T-3273: ollama-direct is a VALID_WORKER_KINDS member deliberately
    absent from _DISPATCHERS (fw ask answers synchronously, never spawns).
    It must not be reported as the runtime-trap class this checker exists
    to catch."""
    wc, wf_dir = coverage
    _write_workflow(wf_dir, "wf-pi", "pi", provider="anthropic")
    _write_workflow(wf_dir, "ask", "ollama-direct")

    r = wc.check_workflow_dispatcher_coverage()
    assert r["ok"] is True
    assert r["unroutable_workflows"] == []


def test_ollama_direct_exemption_does_not_widen_to_other_kinds(coverage):
    """The ollama-direct exemption is scoped to that one documented kind —
    a genuinely unroutable worker_kind alongside it must still fail."""
    wc, wf_dir = coverage
    _write_workflow(wf_dir, "ask", "ollama-direct")
    _write_workflow(wf_dir, "wf-task", "Task")

    r = wc.check_workflow_dispatcher_coverage()
    assert r["ok"] is False
    bad = r["unroutable_workflows"]
    assert len(bad) == 1
    assert bad[0]["name"] == "wf-task"


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


# ─── T-1802: enrich_with_dispatch_recency ────────────────────────────────────


def _write_dispatches(path: Path, records: list[dict]):
    """Helper: write list of dispatch records as JSONL."""
    import json
    path.write_text("\n".join(json.dumps(r) for r in records) + "\n")


def test_enrich_with_dispatch_recency_basic(coverage, tmp_path):
    """Two dispatches across two workflows → max ts per workflow surfaces.

    A workflow with multiple dispatches takes the latest ts."""
    wc, wf_dir = coverage
    _write_workflow(wf_dir, "wf-a", "pi", provider="anthropic")
    _write_workflow(wf_dir, "wf-b", "ollama-loop")
    _write_workflow(wf_dir, "wf-c", "TermLink")  # never dispatched

    dispatches = tmp_path / "dispatches.jsonl"
    _write_dispatches(dispatches, [
        {"workflow_id": "wf-a", "ts": "2026-05-01T10:00:00Z", "task_id": "T-100"},
        {"workflow_id": "wf-a", "ts": "2026-05-10T11:00:00Z", "task_id": "T-200"},
        {"workflow_id": "wf-b", "ts": "2026-05-05T12:00:00Z", "task_id": "T-150"},
    ])

    report = wc.check_workflow_dispatcher_coverage()
    enriched = wc.enrich_with_dispatch_recency(report, dispatches_path=dispatches)

    rows = {w["name"]: w for w in enriched["workflows"]}
    # wf-a: latest of two dispatches
    assert rows["wf-a"]["last_dispatched"] == "2026-05-10T11:00:00Z"
    assert rows["wf-a"]["last_dispatch_task_id"] == "T-200"
    # wf-b: single dispatch
    assert rows["wf-b"]["last_dispatched"] == "2026-05-05T12:00:00Z"
    assert rows["wf-b"]["last_dispatch_task_id"] == "T-150"
    # wf-c: never dispatched
    assert rows["wf-c"]["last_dispatched"] is None
    assert rows["wf-c"]["last_dispatch_task_id"] is None


def test_enrich_with_dispatch_recency_missing_path(coverage, tmp_path):
    """Non-existent dispatches path → every row last_dispatched=None.

    Guard against `/orchestrator` crashing on a fresh consumer project."""
    wc, wf_dir = coverage
    _write_workflow(wf_dir, "wf-a", "pi", provider="anthropic")

    nonexistent = tmp_path / "does-not-exist.jsonl"
    report = wc.check_workflow_dispatcher_coverage()
    enriched = wc.enrich_with_dispatch_recency(report, dispatches_path=nonexistent)

    rows = {w["name"]: w for w in enriched["workflows"]}
    assert rows["wf-a"]["last_dispatched"] is None
    assert rows["wf-a"]["last_dispatch_task_id"] is None


def test_enrich_with_dispatch_recency_malformed_jsonl_skipped(coverage, tmp_path):
    """Malformed lines skipped, good lines counted (matches existing helper)."""
    wc, wf_dir = coverage
    _write_workflow(wf_dir, "wf-a", "pi", provider="anthropic")

    dispatches = tmp_path / "dispatches.jsonl"
    # Mix garbage and good
    dispatches.write_text(
        'not valid json\n'
        '{"workflow_id": "wf-a", "ts": "2026-05-10T11:00:00Z", "task_id": "T-200"}\n'
        '[just, a, list]\n'  # non-dict root
        '\n'  # empty line
        '{"workflow_id": "wf-a"}\n'  # missing ts → skipped
    )

    report = wc.check_workflow_dispatcher_coverage()
    enriched = wc.enrich_with_dispatch_recency(report, dispatches_path=dispatches)
    rows = {w["name"]: w for w in enriched["workflows"]}
    assert rows["wf-a"]["last_dispatched"] == "2026-05-10T11:00:00Z"
    assert rows["wf-a"]["last_dispatch_task_id"] == "T-200"


# ─── T-1803: flag_stale_workflows ────────────────────────────────────────────


def test_workflow_never_dispatched_marked_stale(coverage, tmp_path):
    """last_dispatched=None → stale; warn=True; ok unchanged."""
    wc, wf_dir = coverage
    _write_workflow(wf_dir, "wf-cold", "ollama-loop")

    r = wc.check_workflow_dispatcher_coverage()
    r = wc.enrich_with_dispatch_recency(r, dispatches_path=tmp_path / "no-such.jsonl")
    r = wc.flag_stale_workflows(r, now_iso="2026-05-13T00:00:00+00:00")
    assert r["ok"] is True  # still no runtime trap
    assert r["warn"] is True
    names = [w["name"] for w in r["stale_workflows"]]
    assert "wf-cold" in names


def test_workflow_dispatched_recently_not_stale(coverage, tmp_path):
    """Dispatched 1 day ago → not stale."""
    wc, wf_dir = coverage
    _write_workflow(wf_dir, "wf-fresh", "ollama-loop")
    d = tmp_path / "d.jsonl"
    _write_dispatches(d, [
        {"workflow_id": "wf-fresh", "ts": "2026-05-12T00:00:00+00:00", "task_id": "T-1"},
    ])
    r = wc.check_workflow_dispatcher_coverage()
    r = wc.enrich_with_dispatch_recency(r, dispatches_path=d)
    r = wc.flag_stale_workflows(r, now_iso="2026-05-13T00:00:00+00:00")
    assert r["warn"] is False
    assert r["stale_workflows"] == []


def test_workflow_dispatched_long_ago_marked_stale(coverage, tmp_path):
    """Dispatched 91 days ago → stale (threshold=90d default)."""
    wc, wf_dir = coverage
    _write_workflow(wf_dir, "wf-old", "ollama-loop")
    d = tmp_path / "d.jsonl"
    _write_dispatches(d, [
        # 2026-05-13 minus 91d = 2026-02-11
        {"workflow_id": "wf-old", "ts": "2026-02-11T00:00:00+00:00", "task_id": "T-1"},
    ])
    r = wc.check_workflow_dispatcher_coverage()
    r = wc.enrich_with_dispatch_recency(r, dispatches_path=d)
    r = wc.flag_stale_workflows(r, now_iso="2026-05-13T00:00:00+00:00")
    assert r["warn"] is True
    names = [w["name"] for w in r["stale_workflows"]]
    assert "wf-old" in names


def test_warn_false_when_no_stale(coverage, tmp_path):
    """All fresh → warn=False, stale list empty."""
    wc, wf_dir = coverage
    _write_workflow(wf_dir, "wf-a", "ollama-loop")
    _write_workflow(wf_dir, "wf-b", "TermLink")
    d = tmp_path / "d.jsonl"
    _write_dispatches(d, [
        {"workflow_id": "wf-a", "ts": "2026-05-12T00:00:00+00:00", "task_id": "T-1"},
        {"workflow_id": "wf-b", "ts": "2026-05-12T00:00:00+00:00", "task_id": "T-2"},
    ])
    r = wc.check_workflow_dispatcher_coverage()
    r = wc.enrich_with_dispatch_recency(r, dispatches_path=d)
    r = wc.flag_stale_workflows(r, now_iso="2026-05-13T00:00:00+00:00")
    assert r["warn"] is False
    assert r["stale_workflows"] == []


def test_warn_does_not_override_fail(coverage, tmp_path):
    """Workflow unroutable AND stale → ok=False, warn=False (FAIL absorbs WARN)."""
    wc, wf_dir = coverage
    _write_workflow(wf_dir, "wf-task", "Task")  # unroutable → FAIL
    r = wc.check_workflow_dispatcher_coverage()
    r = wc.enrich_with_dispatch_recency(r, dispatches_path=tmp_path / "no-such.jsonl")
    r = wc.flag_stale_workflows(r, now_iso="2026-05-13T00:00:00+00:00")
    assert r["ok"] is False
    # The stale list may be non-empty (wf-task was never dispatched), but
    # warn must be False because ok is False — FAIL absorbs WARN.
    assert r["warn"] is False


def test_threshold_configurable(coverage, tmp_path):
    """stale_threshold_days=1 → workflows dispatched 2d ago are stale."""
    wc, wf_dir = coverage
    _write_workflow(wf_dir, "wf-a", "ollama-loop")
    d = tmp_path / "d.jsonl"
    _write_dispatches(d, [
        {"workflow_id": "wf-a", "ts": "2026-05-11T00:00:00+00:00", "task_id": "T-1"},
    ])
    r = wc.check_workflow_dispatcher_coverage()
    r = wc.enrich_with_dispatch_recency(r, dispatches_path=d)
    r = wc.flag_stale_workflows(
        r, stale_threshold_days=1, now_iso="2026-05-13T00:00:00+00:00",
    )
    names = [w["name"] for w in r["stale_workflows"]]
    assert "wf-a" in names
    assert r["warn"] is True


def test_format_audit_line_warn_state(coverage, tmp_path):
    """format_audit_line surfaces stale names when warn=True and ok=True."""
    wc, wf_dir = coverage
    _write_workflow(wf_dir, "wf-cold", "ollama-loop")
    r = wc.check_workflow_dispatcher_coverage()
    r = wc.enrich_with_dispatch_recency(r, dispatches_path=tmp_path / "no-such.jsonl")
    r = wc.flag_stale_workflows(r, now_iso="2026-05-13T00:00:00+00:00")
    line = wc.format_audit_line(r)
    assert "stale workflow" in line
    assert "wf-cold" in line


def test_enrich_with_dispatch_recency_does_not_mutate_input(coverage, tmp_path):
    """Pure function: input report's workflows still lack last_dispatched."""
    wc, wf_dir = coverage
    _write_workflow(wf_dir, "wf-a", "pi", provider="anthropic")
    dispatches = tmp_path / "dispatches.jsonl"
    _write_dispatches(dispatches, [
        {"workflow_id": "wf-a", "ts": "2026-05-10T11:00:00Z", "task_id": "T-200"},
    ])

    report = wc.check_workflow_dispatcher_coverage()
    # Snapshot input row keys before call
    original_keys = set(report["workflows"][0].keys())

    enriched = wc.enrich_with_dispatch_recency(report, dispatches_path=dispatches)

    # Original report unchanged
    assert set(report["workflows"][0].keys()) == original_keys
    assert "last_dispatched" not in report["workflows"][0]
    # Enriched copy gained the fields
    assert "last_dispatched" in enriched["workflows"][0]


# ─── T-1872: inline workflows excluded from staleness ────────────────────────


def test_inline_workflow_never_dispatched_NOT_stale(coverage, tmp_path):
    """`inline: true` workflows are excluded from staleness premise — they
    are driven by non-resolver flows (fw inception, fw grill, fw design-dialogue)
    and will never appear in dispatches.jsonl by design.

    Before T-1872 this returned warn=True with the inline workflow in
    stale_workflows, polluting the audit signal. After T-1872, inline
    rows are silently skipped.
    """
    wc, wf_dir = coverage
    _write_workflow(wf_dir, "wf-inline", None, inline=True)
    r = wc.check_workflow_dispatcher_coverage()
    r = wc.enrich_with_dispatch_recency(r, dispatches_path=tmp_path / "no-such.jsonl")
    r = wc.flag_stale_workflows(r, now_iso="2026-05-13T00:00:00+00:00")
    assert r["warn"] is False
    assert r["stale_workflows"] == []
    # inline flag is carried into the workflow row
    inline_row = next(w for w in r["workflows"] if w["name"] == "wf-inline")
    assert inline_row.get("inline") is True


def test_inline_with_stale_dispatch_still_NOT_stale(coverage, tmp_path):
    """Even if an inline workflow somehow has an old dispatch record (manual
    test run / legacy data), the inline flag should win — it documents the
    workflow's lifecycle as non-resolver-driven, full stop."""
    wc, wf_dir = coverage
    _write_workflow(wf_dir, "wf-inline-old", None, inline=True)
    d = tmp_path / "d.jsonl"
    _write_dispatches(d, [
        # 2026-05-13 minus 100d would be stale by the 90d threshold
        {"workflow_id": "wf-inline-old", "ts": "2026-02-02T00:00:00+00:00", "task_id": "T-OLD"},
    ])
    r = wc.check_workflow_dispatcher_coverage()
    r = wc.enrich_with_dispatch_recency(r, dispatches_path=d)
    r = wc.flag_stale_workflows(r, now_iso="2026-05-13T00:00:00+00:00")
    assert r["stale_workflows"] == []
    assert r["warn"] is False


def test_non_inline_stale_still_flagged_when_inline_alongside(coverage, tmp_path):
    """Mixing inline + non-inline workflows: the non-inline one (real
    resolver-driven workflow with no dispatch) still surfaces as stale."""
    wc, wf_dir = coverage
    _write_workflow(wf_dir, "wf-inline", None, inline=True)
    _write_workflow(wf_dir, "wf-real-cold", "ollama-loop")
    r = wc.check_workflow_dispatcher_coverage()
    r = wc.enrich_with_dispatch_recency(r, dispatches_path=tmp_path / "no.jsonl")
    r = wc.flag_stale_workflows(r, now_iso="2026-05-13T00:00:00+00:00")
    names = [w["name"] for w in r["stale_workflows"]]
    assert names == ["wf-real-cold"]
    assert r["warn"] is True  # real one IS stale


def test_loader_carries_inline_through(coverage):
    """The workflow loader (`check_workflow_dispatcher_coverage`) must carry
    the inline field into the report row so `flag_stale_workflows` can read it."""
    wc, wf_dir = coverage
    _write_workflow(wf_dir, "wf-inline", None, inline=True)
    _write_workflow(wf_dir, "wf-noninline", "ollama-loop")
    r = wc.check_workflow_dispatcher_coverage()
    rows = {w["name"]: w for w in r["workflows"]}
    assert rows["wf-inline"].get("inline") is True
    assert rows["wf-noninline"].get("inline") is False
