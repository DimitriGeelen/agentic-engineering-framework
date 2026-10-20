"""T-2680: pin the silent-zero store-grep detector (T-2679 Slice 1).

The bug family: a grep against a .context/ store that matches nothing after the
store is reshaped, exits 0 and reads as "no items". T-2676 (harvest.sh) and
T-2677 (audit graduation counter) were dead for months in exactly this shape.

Both directions are asserted: the verbatim pre-fix shapes must be flagged, and
their indent-tolerant fixes (plus greps of non-store files) must not be — a
detector that only proves it fires cannot be told apart from one that always does.
"""

import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from lib import silent_zero_scan as sz  # noqa: E402
from lib.reviewer import static_scan as ss  # noqa: E402


def rules(text):
    return [r for _p, _l, r, _s in sz.scan_text(text)]


# ── verbatim pre-fix shapes ──────────────────────────────────────────────

def test_t2676_harvest_fixed_indent_grep_flagged():
    # lib/harvest.sh before 08590b30b
    text = (
        'harvest_patterns() {\n'
        '    local project_file="$1"\n'
        '    project_patterns=$(grep "^    pattern:" "$project_file" 2>/dev/null'
        " | sed 's/.*pattern:[[:space:]]*//' | tr -d '\"' || true)\n"
        '}\n'
    )
    assert rules(text) == ["fixed-indent-store-grep"]


def test_t2677_audit_counter_flagged_both_rules():
    # agents/audit/audit.sh before dabb1f84a
    text = (
        'LEARNINGS_FILE="$CONTEXT_DIR/project/learnings.yaml"\n'
        "learning_count=$(grep -c '^  - id: L-' \"$LEARNINGS_FILE\" 2>/dev/null) || learning_count=0\n"
    )
    assert sorted(rules(text)) == ["fixed-indent-store-grep", "zero-fallback-count"]


def test_literal_context_path_echo_zero_flagged():
    text = 'n=$(grep -c "^  - id: G-" .context/project/concerns.yaml 2>/dev/null || echo 0)\n'
    assert sorted(rules(text)) == ["fixed-indent-store-grep", "zero-fallback-count"]


def test_variable_resolved_through_assignment():
    text = (
        'local store="$CONTEXT_DIR/project/x.yaml"\n'
        'grep "^  - id: X-" "$store"\n'
    )
    assert rules(text) == ["fixed-indent-store-grep"]


# ── negatives: the fixes and the look-alikes ─────────────────────────────

@pytest.mark.parametrize("pattern", [
    "^[[:space:]]*pattern:",
    "^ *pattern:",
    "^  *pattern:",
    "^ +pattern:",
    "^\\s*pattern:",
    "pattern:",
])
def test_indent_tolerant_patterns_not_flagged(pattern):
    text = f'grep -E "{pattern}" .context/project/patterns.yaml\n'
    assert rules(text) == []


def test_non_store_file_not_flagged():
    assert rules('grep "^  pass:" build.log\n') == []


def test_stdin_grep_not_flagged():
    assert rules('cat x.yaml | grep "^  - id: L-"\n') == []


def test_comment_line_not_flagged():
    assert rules('# old: grep "^  - id: L-" .context/project/learnings.yaml\n') == []


def test_count_without_fallback_not_zero_fallback():
    text = 'n=$(grep -cE "^[[:space:]]*id: L-" .context/project/learnings.yaml)\n'
    assert rules(text) == []


def test_count_fallback_on_non_context_file_not_flagged():
    assert rules('n=$(grep -c ERROR app.log || echo 0)\n') == []


# ── reviewer wiring ──────────────────────────────────────────────────────

def test_reviewer_detector_flags_verification_line():
    verif = (
        "# comment\n"
        "bin/fw doctor\n"
        "test \"$(grep -c '^  - id: L-' .context/project/learnings.yaml || echo 0)\" -gt 0\n"
    )
    found = ss.detect_silent_zero_store_grep(verif)
    assert {f.pattern_id for f in found} == {"silent-zero-store-grep"}
    assert all(f.lie_severity == "partial" for f in found)
    assert all(f.location == "Verification:line 3" for f in found)


def test_reviewer_detector_silent_on_clean_verification():
    verif = "grep -cE '^[[:space:]]*id: L-' .context/project/learnings.yaml\n"
    assert ss.detect_silent_zero_store_grep(verif) == []


def test_catalogue_registers_pattern():
    import yaml
    cat = yaml.safe_load((ROOT / "policy" / "anti-patterns.yaml").read_text())
    entry = [p for p in cat["patterns"] if p["id"] == "silent-zero-store-grep"]
    assert entry and entry[0]["detector_ref"].endswith(":detect_silent_zero_store_grep")
    for ex in entry[0]["examples_positive"]:
        assert ss.detect_silent_zero_store_grep(ex), ex
    for ex in entry[0]["examples_negative"]:
        assert not ss.detect_silent_zero_store_grep(ex), ex


# ── CLI ──────────────────────────────────────────────────────────────────

def test_cli_reports_path_line_rule(tmp_path):
    (tmp_path / "lib").mkdir()
    (tmp_path / "lib" / "a.sh").write_text(
        'x\ngrep "^    name:" .context/project/practices.yaml\n'
    )
    (tmp_path / "lib" / "b.sh").write_text('grep -E "^[[:space:]]*name:" .context/project/practices.yaml\n')
    out = subprocess.run(
        [sys.executable, str(ROOT / "lib" / "silent_zero_scan.py"), "--root", str(tmp_path)],
        capture_output=True, text=True, check=True,
    ).stdout
    assert out.splitlines() == [
        'lib/a.sh:2: fixed-indent-store-grep: grep "^    name:" .context/project/practices.yaml'
    ]
