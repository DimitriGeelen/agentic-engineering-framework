"""Unit tests for lib/reviewer/overrides.py (T-1443 v1.4)."""

from __future__ import annotations

import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from lib.reviewer import overrides as ov  # noqa: E402
from lib.reviewer import static_scan as ss  # noqa: E402


# ───────────────── Load / save ─────────────────


def test_load_empty_file_returns_empty_list(tmp_path):
    p = tmp_path / "overrides.yaml"
    assert ov.load_overrides(p) == []


def test_load_multi_entry_roundtrip(tmp_path):
    p = tmp_path / "overrides.yaml"
    o1 = ov.Override(
        id="OV-aaaa1111", task_id="T-100", pattern_id="AC-verify-mismatch",
        ac_index=2, reason="path generated at runtime",
        expires_at="2099-01-01T00:00:00Z",
        added_by="dimitri", added_at="2026-04-25T11:00:00Z",
    )
    o2 = ov.Override(
        id="OV-bbbb2222", task_id="T-101", pattern_id="output-spoofing",
        ac_index=None, reason="echo is intentional in this script",
        expires_at="2099-01-01T00:00:00Z",
        added_by="agent", added_at="2026-04-25T11:01:00Z",
    )
    ov.save_overrides([o1, o2], p)
    loaded = ov.load_overrides(p)
    assert len(loaded) == 2
    assert loaded[0].id == "OV-aaaa1111"
    assert loaded[1].pattern_id == "output-spoofing"


def test_load_skips_malformed_entries(tmp_path):
    p = tmp_path / "overrides.yaml"
    p.write_text(
        "schema_version: 1\n"
        "overrides:\n"
        "  - id: OV-good\n"
        "    task_id: T-1\n"
        "    pattern_id: tautology\n"
        "    expires_at: 2099-01-01T00:00:00Z\n"
        "    reason: ok\n"
        "  - id: OV-bad\n"  # missing required fields
        "    foo: bar\n"
    )
    loaded = ov.load_overrides(p)
    assert len(loaded) == 1
    assert loaded[0].id == "OV-good"


# ───────────────── Match logic ─────────────────


def _future() -> str:
    return (datetime.now(timezone.utc) + timedelta(days=10)).strftime("%Y-%m-%dT%H:%M:%SZ")


def _past() -> str:
    return (datetime.now(timezone.utc) - timedelta(days=1)).strftime("%Y-%m-%dT%H:%M:%SZ")


def test_match_exact_task_pattern_ac():
    o = ov.Override(id="OV-1", task_id="T-100", pattern_id="empty-body",
                    ac_index=2, reason="r", expires_at=_future(),
                    added_by="x", added_at="x")
    assert ov.is_overridden([o], "T-100", "empty-body", 2) is o
    # different ac → no match
    assert ov.is_overridden([o], "T-100", "empty-body", 3) is None
    # different pattern → no match
    assert ov.is_overridden([o], "T-100", "tautology", 2) is None
    # different task → no match
    assert ov.is_overridden([o], "T-101", "empty-body", 2) is None


def test_match_wildcard_ac_matches_any():
    o = ov.Override(id="OV-1", task_id="T-100", pattern_id="tautology",
                    ac_index=None, reason="r", expires_at=_future(),
                    added_by="x", added_at="x")
    # verification-level finding (ac_index=None) → matches
    assert ov.is_overridden([o], "T-100", "tautology", None) is o
    # AC-bound finding → also matches (wildcard)
    assert ov.is_overridden([o], "T-100", "tautology", 5) is o


def test_match_skips_expired():
    o = ov.Override(id="OV-1", task_id="T-100", pattern_id="empty-body",
                    ac_index=2, reason="r", expires_at=_past(),
                    added_by="x", added_at="x")
    assert ov.is_overridden([o], "T-100", "empty-body", 2) is None


# ───────────────── TTL / expiry ─────────────────


def test_is_expired():
    past = ov.Override(id="OV-1", task_id="T-1", pattern_id="x", ac_index=None,
                       reason="r", expires_at=_past(), added_by="x", added_at="x")
    future = ov.Override(id="OV-2", task_id="T-1", pattern_id="x", ac_index=None,
                         reason="r", expires_at=_future(), added_by="x", added_at="x")
    assert past.is_expired() is True
    assert future.is_expired() is False


def test_malformed_expires_treated_as_expired():
    o = ov.Override(id="OV-bad", task_id="T-1", pattern_id="x", ac_index=None,
                    reason="r", expires_at="not-a-date",
                    added_by="x", added_at="x")
    assert o.is_expired() is True


def test_prune_drops_expired():
    a = ov.Override(id="OV-a", task_id="T-1", pattern_id="x", ac_index=None,
                    reason="r", expires_at=_future(), added_by="x", added_at="x")
    b = ov.Override(id="OV-b", task_id="T-1", pattern_id="x", ac_index=None,
                    reason="r", expires_at=_past(), added_by="x", added_at="x")
    kept, dropped = ov.prune_expired([a, b])
    assert [o.id for o in kept] == ["OV-a"]
    assert [o.id for o in dropped] == ["OV-b"]


# ───────────────── add / remove ─────────────────


def test_add_creates_entry_with_default_ttl(tmp_path, monkeypatch):
    p = tmp_path / "overrides.yaml"
    o = ov.add_override(
        task_id="T-100", pattern_id="empty-body",
        reason="placeholder fixture", path=p,
    )
    assert o.id.startswith("OV-")
    loaded = ov.load_overrides(p)
    assert len(loaded) == 1
    assert loaded[0].id == o.id
    assert loaded[0].is_expired() is False


def test_remove_returns_true_on_success(tmp_path):
    p = tmp_path / "overrides.yaml"
    o = ov.add_override(task_id="T-1", pattern_id="x", reason="r", path=p)
    assert ov.remove_override(o.id, path=p) is True
    assert ov.load_overrides(p) == []


def test_remove_returns_false_when_id_missing(tmp_path):
    p = tmp_path / "overrides.yaml"
    ov.add_override(task_id="T-1", pattern_id="x", reason="r", path=p)
    assert ov.remove_override("OV-nonexistent", path=p) is False


# ───────────────── Integration with scan_task ─────────────────


def _make_task_with_finding(tmp_path: Path) -> Path:
    # Verification uses test -f (not tautology, not output-spoofing) on a
    # different file than the AC names → only AC-verify-mismatch fires.
    p = tmp_path / "T-9999-test.md"
    p.write_text(
        "---\nid: T-9999\n---\n\n"
        "## Acceptance Criteria\n\n"
        "### Agent\n"
        "- [x] lib/x/foo.py exists with thing\n\n"
        "## Verification\n\n"
        "test -f some/other/file.txt\n\n"
    )
    return p


def test_scan_task_suppresses_finding_via_override(tmp_path):
    task = _make_task_with_finding(tmp_path)
    catalogue = ss.load_catalogue(ROOT / "policy" / "anti-patterns.yaml")
    o = ov.Override(
        id="OV-test", task_id="T-9999", pattern_id="AC-verify-mismatch",
        ac_index=1, reason="test", expires_at=_future(),
        added_by="test", added_at="2026-04-25T00:00:00Z",
    )
    v_no_override = ss.scan_task(task, catalogue)
    assert any(f.pattern_id == "AC-verify-mismatch" for f in v_no_override.findings)

    v_with_override = ss.scan_task(task, catalogue, overrides=[o])
    assert not any(f.pattern_id == "AC-verify-mismatch" for f in v_with_override.findings)
    assert len(v_with_override.suppressed) == 1
    assert v_with_override.suppressed[0].pattern_id == "AC-verify-mismatch"


def test_scan_task_does_not_suppress_when_ac_index_differs(tmp_path):
    task = _make_task_with_finding(tmp_path)
    catalogue = ss.load_catalogue(ROOT / "policy" / "anti-patterns.yaml")
    o = ov.Override(
        id="OV-test", task_id="T-9999", pattern_id="AC-verify-mismatch",
        ac_index=99, reason="wrong ac", expires_at=_future(),
        added_by="test", added_at="2026-04-25T00:00:00Z",
    )
    v = ss.scan_task(task, catalogue, overrides=[o])
    # finding NOT suppressed because ac_index doesn't match
    assert any(f.pattern_id == "AC-verify-mismatch" for f in v.findings)
    assert v.suppressed == []


def test_verdict_overall_recomputed_after_suppression(tmp_path):
    task = _make_task_with_finding(tmp_path)
    catalogue = ss.load_catalogue(ROOT / "policy" / "anti-patterns.yaml")
    o = ov.Override(
        id="OV-test", task_id="T-9999", pattern_id="AC-verify-mismatch",
        ac_index=None, reason="t", expires_at=_future(),
        added_by="t", added_at="t",
    )
    v_no = ss.scan_task(task, catalogue)
    v_with = ss.scan_task(task, catalogue, overrides=[o])
    assert v_no.overall == "CONCERN"
    assert v_with.overall == "PASS"  # only finding was suppressed → PASS
