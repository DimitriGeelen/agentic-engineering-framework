"""Unit tests for lib/reviewer/drift.py (T-1483 v1.5)."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from lib.reviewer.drift import (  # noqa: E402
    DriftReport,
    compute_hashes,
    detect_drift,
    extract_file_refs,
    read_baseline,
    write_baseline,
)


# ───────────────── extract_file_refs ─────────────────


def test_extract_refs_finds_paths_in_test_command(tmp_path):
    (tmp_path / "bin").mkdir()
    (tmp_path / "bin" / "fw").write_text("#!/bin/bash\n")
    text = "test -f bin/fw\n"
    refs = extract_file_refs(text, tmp_path)
    assert Path("bin/fw") in refs


def test_extract_refs_finds_paths_in_python_yaml(tmp_path):
    (tmp_path / "policy").mkdir()
    (tmp_path / "policy" / "x.yaml").write_text("a: 1\n")
    text = "python3 -c \"import yaml; yaml.safe_load(open('policy/x.yaml'))\""
    refs = extract_file_refs(text, tmp_path)
    assert Path("policy/x.yaml") in refs


def test_extract_refs_skips_comments(tmp_path):
    (tmp_path / "real.txt").write_text("x")
    text = "# test -f only-in-comment.txt\ntest -f real.txt"
    refs = extract_file_refs(text, tmp_path)
    assert Path("real.txt") in refs
    assert Path("only-in-comment.txt") not in refs


def test_extract_refs_filters_nonexistent(tmp_path):
    text = "test -f does-not-exist.txt"
    refs = extract_file_refs(text, tmp_path)
    # Heuristic doesn't add files that don't exist on disk
    assert Path("does-not-exist.txt") not in refs


def test_extract_refs_handles_empty():
    refs = extract_file_refs("", Path("/tmp"))
    assert refs == set()


# ───────────────── compute_hashes ─────────────────


def test_compute_hashes_returns_sha256(tmp_path):
    f = tmp_path / "x.txt"
    f.write_text("hello")
    h = compute_hashes({Path("x.txt")}, tmp_path)
    assert "x.txt" in h
    assert len(h["x.txt"]) == 64  # SHA-256 hex


def test_compute_hashes_missing_file_returns_empty(tmp_path):
    h = compute_hashes({Path("ghost.txt")}, tmp_path)
    assert h["ghost.txt"] == ""


def test_compute_hashes_changes_with_content(tmp_path):
    f = tmp_path / "x.txt"
    f.write_text("a")
    h1 = compute_hashes({Path("x.txt")}, tmp_path)["x.txt"]
    f.write_text("b")
    h2 = compute_hashes({Path("x.txt")}, tmp_path)["x.txt"]
    assert h1 != h2


# ───────────────── baseline read/write ─────────────────


def test_baseline_round_trip():
    text = "## Reviewer Verdict (v1.0)\n\n- Scan ID: R-foo\n"
    baseline = {"a.txt": "abc", "b.txt": "def"}
    new_text = write_baseline(text, baseline)
    parsed = read_baseline(new_text)
    assert parsed == baseline


def test_baseline_replace_existing():
    text = "## Reviewer Verdict (v1.0)\n<!-- drift-baseline: {\"old\": \"hash\"} -->\n"
    new = write_baseline(text, {"new": "hash"})
    assert read_baseline(new) == {"new": "hash"}
    assert "old" not in new


def test_baseline_no_verdict_section_appends():
    text = "# Some Task\n\nbody only\n"
    new = write_baseline(text, {"a": "h"})
    assert read_baseline(new) == {"a": "h"}
    assert "Reviewer Verdict" in new


def test_baseline_empty_when_absent():
    assert read_baseline("just body, no marker") == {}


# ───────────────── detect_drift end-to-end ─────────────────


def _make_task(tmp_path, task_id, verification, baseline=None):
    (tmp_path / "policy").mkdir(exist_ok=True)
    (tmp_path / "policy" / "x.yaml").write_text("a: 1\n")
    body = f"""---
id: {task_id}
name: "test"
status: work-completed
---

## Verification

{verification}

## Reviewer Verdict (v1.0)

- Overall: PASS
"""
    if baseline is not None:
        import json
        body = body.replace(
            "## Reviewer Verdict (v1.0)\n",
            f"## Reviewer Verdict (v1.0)\n<!-- drift-baseline: {json.dumps(baseline)} -->\n",
        )
    p = tmp_path / f"{task_id}-test.md"
    p.write_text(body)
    return p


def test_detect_drift_unchanged(tmp_path):
    task_path = _make_task(tmp_path, "T-9001", "test -f policy/x.yaml")
    # Compute baseline against current state
    refs = extract_file_refs("test -f policy/x.yaml", tmp_path)
    baseline = compute_hashes(refs, tmp_path)
    task_path = _make_task(tmp_path, "T-9001", "test -f policy/x.yaml", baseline)

    report = detect_drift(task_path, tmp_path)
    assert report.has_drift is False
    assert "policy/x.yaml" in report.unchanged


def test_detect_drift_changed(tmp_path):
    task_path = _make_task(tmp_path, "T-9002", "test -f policy/x.yaml")
    refs = extract_file_refs("test -f policy/x.yaml", tmp_path)
    baseline = compute_hashes(refs, tmp_path)
    task_path = _make_task(tmp_path, "T-9002", "test -f policy/x.yaml", baseline)

    # Mutate the referenced file
    (tmp_path / "policy" / "x.yaml").write_text("CHANGED\n")

    report = detect_drift(task_path, tmp_path)
    assert report.has_drift is True
    assert "policy/x.yaml" in report.changed


def test_detect_drift_missing(tmp_path):
    task_path = _make_task(tmp_path, "T-9003", "test -f policy/x.yaml")
    baseline = {"policy/x.yaml": "0" * 64}
    task_path = _make_task(tmp_path, "T-9003", "test -f policy/x.yaml", baseline)

    # Delete the file
    (tmp_path / "policy" / "x.yaml").unlink()

    report = detect_drift(task_path, tmp_path)
    assert report.has_drift is True
    assert "policy/x.yaml" in report.missing


def test_detect_drift_no_baseline_yields_no_drift(tmp_path):
    # Tasks without a recorded baseline should not falsely flag drift —
    # they have nothing to compare against.
    task_path = _make_task(tmp_path, "T-9004", "test -f policy/x.yaml")
    report = detect_drift(task_path, tmp_path)
    assert report.has_drift is False
    assert "policy/x.yaml" in report.no_baseline


def test_drift_report_render_is_string():
    rep = DriftReport(task_id="T-1", unchanged=["a"], changed=["b"], has_drift=True)
    rendered = rep.render()
    assert "T-1" in rendered
    assert "DRIFT" in rendered
