"""Unit tests for lib/reviewer/static_scan.py (T-1443 v1.0).

Each detector gets at least 2 positive + 2 negative cases.
Plus tests for: catalogue loading, verdict rendering, sovereignty invariant,
feedback stream append-only, idempotent re-runs.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

import pytest
import yaml

# Allow running tests from repo root without install
ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from lib.reviewer import static_scan as ss  # noqa: E402


CATALOGUE_PATH = ROOT / "policy" / "anti-patterns.yaml"


@pytest.fixture
def catalogue() -> dict:
    return ss.load_catalogue(CATALOGUE_PATH)


# ───────────────── Catalogue ─────────────────


def test_catalogue_has_four_seed_patterns(catalogue):
    ids = {p["id"] for p in catalogue["patterns"]}
    assert {"tautology", "empty-body", "swallowed-errors", "output-spoofing"}.issubset(ids)


def test_catalogue_severity_axes_are_separated(catalogue):
    for p in catalogue["patterns"]:
        assert p["detection_confidence"] in {"deterministic", "heuristic", "semantic"}
        assert p["lie_severity"] in {"complete", "severe", "partial", "narrow", "staleness"}


# ───────────────── Tautology detector ─────────────────


def test_tautology_positive_true():
    f = ss.detect_tautology("true\n")
    assert len(f) == 1 and f[0].pattern_id == "tautology"


def test_tautology_positive_echo_and_true():
    f = ss.detect_tautology("echo 'all good' && true\n")
    assert len(f) == 1


def test_tautology_positive_bracket_equals():
    f = ss.detect_tautology("[ 1 = 1 ]\n")
    assert len(f) == 1


def test_tautology_negative_real_test():
    f = ss.detect_tautology("bin/fw test unit\n")
    assert f == []


def test_tautology_negative_grep():
    f = ss.detect_tautology('grep -q "expected" output.txt\n')
    assert f == []


# ───────────────── Empty-body detector ─────────────────


def test_empty_body_positive_first_criterion():
    section = "### Agent\n- [ ] [First criterion]\n- [ ] [Second criterion]\n"
    f = ss.detect_empty_body(section)
    assert len(f) == 2
    assert all(x.pattern_id == "empty-body" for x in f)


def test_empty_body_positive_todo_checked():
    section = "### Agent\n- [x] TODO\n"
    f = ss.detect_empty_body(section)
    assert len(f) == 1


def test_empty_body_positive_dots():
    section = "### Agent\n- [x] ...\n"
    f = ss.detect_empty_body(section)
    assert len(f) == 1


def test_empty_body_negative_real_content():
    section = "### Agent\n- [x] lib/reviewer/static_scan.py exists\n"
    f = ss.detect_empty_body(section)
    assert f == []


def test_empty_body_negative_review_prefix_with_content():
    section = "### Human\n- [ ] [REVIEW] Layout looks right\n"
    f = ss.detect_empty_body(section)
    assert f == []


# ───────────────── Swallowed-errors detector ─────────────────


def test_swallowed_errors_positive_no_verify():
    f = ss.detect_swallowed_errors("git commit --no-verify -m 'skip'\n")
    assert len(f) == 1


def test_swallowed_errors_positive_or_true():
    f = ss.detect_swallowed_errors("bin/fw test unit 2>/dev/null || true\n")
    assert len(f) == 1


def test_swallowed_errors_positive_set_plus_e():
    f = ss.detect_swallowed_errors("set +e\n")
    assert len(f) == 1


def test_swallowed_errors_negative_clean_test():
    f = ss.detect_swallowed_errors("bin/fw test unit\n")
    assert f == []


def test_swallowed_errors_negative_explicit_fail():
    f = ss.detect_swallowed_errors("command || (echo 'failed' && exit 1)\n")
    assert f == []


# ───────────────── Output-spoofing detector ─────────────────


def test_output_spoofing_positive_echo_pass():
    f = ss.detect_output_spoofing("echo 'TESTS PASS' >> evidence.txt\n")
    assert len(f) == 1 and f[0].lie_severity == "partial"


def test_output_spoofing_positive_printf():
    f = ss.detect_output_spoofing("printf 'BUILD OK\\n'\n")
    assert len(f) == 1


def test_output_spoofing_negative_piped_to_grep():
    f = ss.detect_output_spoofing("./run.sh | tee /tmp/log; grep -q 'PASS' /tmp/log\n")
    assert f == []


def test_output_spoofing_negative_no_success_token():
    f = ss.detect_output_spoofing("echo 'starting build...'\n")
    assert f == []


# ───────────────── Comments and blanks ignored ─────────────────


def test_comments_and_blanks_ignored_for_all_detectors():
    section = "# this is a comment\n\n  # another\n"
    assert ss.detect_tautology(section) == []
    assert ss.detect_swallowed_errors(section) == []
    assert ss.detect_output_spoofing(section) == []


# ───────────────── Verdict computation ─────────────────


def test_verdict_pass_when_no_findings(catalogue):
    overall = ss.compute_overall([], catalogue["verdict_thresholds"])
    assert overall == "PASS"


def test_verdict_fail_on_severe(catalogue):
    f = [
        ss.Finding(
            pattern_id="tautology",
            pattern_name="x",
            detection_confidence="deterministic",
            lie_severity="severe",
            location="x",
            evidence="x",
        )
    ]
    assert ss.compute_overall(f, catalogue["verdict_thresholds"]) == "FAIL"


def test_verdict_concern_on_partial(catalogue):
    f = [
        ss.Finding(
            pattern_id="output-spoofing",
            pattern_name="x",
            detection_confidence="heuristic",
            lie_severity="partial",
            location="x",
            evidence="x",
        )
    ]
    assert ss.compute_overall(f, catalogue["verdict_thresholds"]) == "CONCERN"


# ───────────────── End-to-end scan ─────────────────


def _make_task(tmp_path: Path, name: str, body_extra: str = "") -> Path:
    task_dir = tmp_path / ".tasks" / "active"
    task_dir.mkdir(parents=True)
    task_file = task_dir / f"T-9999-{name}.md"
    task_file.write_text(
        "---\n"
        "id: T-9999\n"
        'name: "Test"\n'
        "status: started-work\n"
        "---\n\n"
        "# T-9999: Test\n\n"
        "## Acceptance Criteria\n\n"
        "### Agent\n"
        "- [x] Real criterion: lib/x.py exists\n\n"
        "## Verification\n\n"
        + body_extra
        + "\n## Decisions\n\nnone\n"
    )
    return task_file


def test_scan_task_clean(tmp_path, catalogue):
    task_file = _make_task(tmp_path, "clean", "bin/fw test unit\n")
    verdict = ss.scan_task(task_file, catalogue)
    assert verdict.overall == "PASS"
    assert verdict.findings == []
    assert verdict.scan_id.startswith("R-")


def test_scan_task_dirty(tmp_path, catalogue):
    task_file = _make_task(tmp_path, "dirty", "true\n")
    verdict = ss.scan_task(task_file, catalogue)
    assert verdict.overall == "FAIL"
    assert any(f.pattern_id == "tautology" for f in verdict.findings)


# ───────────────── Sovereignty invariant ─────────────────


def test_write_verdict_does_not_mutate_ac_checkboxes(tmp_path, catalogue):
    task_file = _make_task(tmp_path, "sovereignty", "bin/fw test unit\n")
    original = task_file.read_text()
    # capture all AC checkbox lines
    ac_lines_before = [ln for ln in original.splitlines() if ln.lstrip().startswith("- [")]
    verdict = ss.scan_task(task_file, catalogue)
    ss.write_verdict_to_task(task_file, verdict)
    after = task_file.read_text()
    ac_lines_after = [ln for ln in after.splitlines() if ln.lstrip().startswith("- [")]
    assert ac_lines_before == ac_lines_after, "AC checkboxes must not be mutated"


def test_write_verdict_idempotent(tmp_path, catalogue):
    task_file = _make_task(tmp_path, "idempotent", "bin/fw test unit\n")
    verdict = ss.scan_task(task_file, catalogue)
    ss.write_verdict_to_task(task_file, verdict)
    first = task_file.read_text()
    # second scan with deterministic findings → same number of verdict sections
    ss.write_verdict_to_task(task_file, verdict)
    second = task_file.read_text()
    assert second.count(ss.VERDICT_HEADER) == 1
    # body length must not balloon
    assert abs(len(second) - len(first)) < 50


# ───────────────── Feedback stream ─────────────────


def test_feedback_stream_initialized_and_appended(tmp_path):
    stream = tmp_path / ".context" / "working" / "feedback-stream.yaml"
    ss.append_feedback_event(
        stream,
        {"kind": "scan_emitted", "timestamp": "2026-04-25T10:00:00Z", "scan_id": "R-abc", "task_id": "T-9999", "payload": {}},
    )
    ss.append_feedback_event(
        stream,
        {"kind": "verdict_recorded", "timestamp": "2026-04-25T10:00:01Z", "scan_id": "R-abc", "task_id": "T-9999", "payload": {}},
    )
    text = stream.read_text()
    assert text.startswith("# Reviewer feedback stream")
    assert text.count("kind: scan_emitted") == 1
    assert text.count("kind: verdict_recorded") == 1
    # Must be parseable as multi-doc YAML
    docs = list(yaml.safe_load_all(text))
    real_docs = [d for d in docs if d]
    assert len(real_docs) == 2


def test_feedback_stream_is_append_only(tmp_path):
    stream = tmp_path / ".context" / "working" / "feedback-stream.yaml"
    ss.append_feedback_event(stream, {"kind": "scan_emitted", "timestamp": "t1", "scan_id": "r1", "task_id": "T-1", "payload": {}})
    first = stream.read_text()
    ss.append_feedback_event(stream, {"kind": "scan_emitted", "timestamp": "t2", "scan_id": "r2", "task_id": "T-2", "payload": {}})
    second = stream.read_text()
    assert second.startswith(first), "earlier events must remain unchanged at file head"
