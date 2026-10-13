"""T-4197 — static_scan severe-gate predicate: FAIL-level severity AND deterministic."""

from pathlib import Path

from lib.reviewer.static_scan import (
    Finding,
    Verdict,
    finding_file_location,
    severe_deterministic_findings,
)


def _f(severity, confidence, location="Verification:line 1"):
    return Finding(
        pattern_id=f"p-{severity}-{confidence}",
        pattern_name="x",
        detection_confidence=confidence,
        lie_severity=severity,
        location=location,
        evidence="e",
    )


def _verdict(findings):
    return Verdict(task_id="T-1", scan_id="R-1", timestamp="t", overall="FAIL",
                   findings=findings, catalogue_version="v")


def test_only_severe_and_deterministic_block():
    fs = [_f("severe", "deterministic"), _f("severe", "heuristic"),
          _f("partial", "deterministic"), _f("complete", "deterministic")]
    got = {f.pattern_id for f in severe_deterministic_findings(_verdict(fs), {})}
    assert got == {"p-severe-deterministic", "p-complete-deterministic"}


def test_thresholds_from_catalogue_are_honoured():
    fs = [_f("severe", "deterministic")]
    assert severe_deterministic_findings(_verdict(fs), {"fail_on_severities": ["complete"]}) == []


def test_section_location_maps_to_file_line(tmp_path: Path):
    p = tmp_path / "T-1-x.md"
    p.write_text("---\nid: T-1\n---\n\n## Verification\nfirst\ntrue\n")
    assert finding_file_location(p, "Verification:line 2") == f"{p}:7"


def test_location_without_line_keeps_label(tmp_path: Path):
    p = tmp_path / "T-1-x.md"
    p.write_text("## Acceptance Criteria\n")
    assert finding_file_location(p, "AC#2 (Agent)") == f"{p} (AC#2 (Agent))"
