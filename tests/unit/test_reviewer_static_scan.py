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
        "- [x] Real criterion describing what was done\n\n"
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


# ───────────────── v1.1: L-264 fix — grep-of-literal exception ─────────────────


def test_swallowed_errors_l264_grep_of_no_verify_string():
    """Regression for T-1086: grep -c 'git commit --no-verify' must NOT fire."""
    section = "grep -c 'git commit --no-verify' agents/git/lib/hooks.sh\n"
    assert ss.detect_swallowed_errors(section) == []


def test_swallowed_errors_l264_awk_of_no_verify():
    section = "awk '/--no-verify/' file.sh\n"
    assert ss.detect_swallowed_errors(section) == []


def test_swallowed_errors_l264_real_no_verify_still_fires():
    """The fix must not introduce new false-negatives on real --no-verify use."""
    section = "git commit --no-verify -m 'skip'\n"
    assert len(ss.detect_swallowed_errors(section)) == 1


# ───────────── L-369: canonical negative-assertion exempt ─────────────


def test_swallowed_errors_l369_negative_assertion_exempt_basic():
    """`grep PATTERN && exit 1 || true` asserts absence — must not fire."""
    section = "grep -q 'BAD' output.txt && exit 1 || true\n"
    assert ss.detect_swallowed_errors(section) == []


def test_swallowed_errors_l369_negative_assertion_exempt_inline_pipe():
    """Same pattern with command-substitution piped to grep — still exempt."""
    section = "bin/fw verify-acs T-1806 --verbose 2>&1 | grep -q 'NUDGE' && exit 1 || true\n"
    assert ss.detect_swallowed_errors(section) == []


def test_swallowed_errors_l369_negative_assertion_exempt_exit_n():
    """Any exit code in the negative assertion is exempt — not just exit 1."""
    section = "grep -q 'X' file && exit 2 || true\n"
    assert ss.detect_swallowed_errors(section) == []


def test_swallowed_errors_l369_bare_or_true_still_fires():
    """T-1809 pattern: bare `|| true` masking exit code must still fire."""
    section = "bin/fw pause --help 2>&1 | head -3 || true\n"
    assert len(ss.detect_swallowed_errors(section)) == 1


def test_swallowed_errors_l369_redirected_or_true_still_fires():
    """T-1356/T-1360 pattern: redirected `|| true` must still fire."""
    section = "bin/fw doctor >/dev/null 2>&1 || true\n"
    assert len(ss.detect_swallowed_errors(section)) == 1


def test_swallowed_errors_l369_grep_or_true_without_exit_still_fires():
    """`grep PATTERN || true` without && exit is still error-swallowing."""
    section = "grep -rL 'style-guide' docs/ > /dev/null 2>&1 || true\n"
    assert len(ss.detect_swallowed_errors(section)) == 1


# ───────────────── v1.1: empty-output-success ─────────────────


def test_empty_output_success_positive_dev_null():
    f = ss.detect_empty_output_success("bin/fw doctor > /dev/null\n")
    assert len(f) == 1 and f[0].pattern_id == "empty-output-success"


def test_empty_output_success_positive_dev_null_2_1():
    f = ss.detect_empty_output_success("make build > /dev/null 2>&1\n")
    assert len(f) == 1


def test_empty_output_success_negative_grep_q_exempted():
    f = ss.detect_empty_output_success("grep -q 'expected' file.txt > /dev/null\n")
    assert f == []


def test_empty_output_success_negative_test_exempted():
    f = ss.detect_empty_output_success("test -f required.json\n")
    assert f == []


# ───────────────── v1.1: skip-as-pass ─────────────────


def test_skip_as_pass_positive_collect_only():
    f = ss.detect_skip_as_pass("pytest --collect-only tests/\n")
    assert len(f) == 1 and f[0].pattern_id == "skip-as-pass"


def test_skip_as_pass_positive_skip_env():
    f = ss.detect_skip_as_pass("make test SKIP=true\n")
    assert len(f) == 1


def test_skip_as_pass_negative_normal_pytest():
    f = ss.detect_skip_as_pass("pytest tests/unit/\n")
    assert f == []


def test_skip_as_pass_negative_marker_filter():
    f = ss.detect_skip_as_pass("pytest -m unit tests/\n")
    assert f == []


# ───── T-2177: quoted-context + output-assertion suppression ─────


def test_skip_as_pass_negative_quoted_skip_flag_in_grep_pattern():
    """T-1516 empirical FP: --skip-sovereignty inside grep PATTERN argument."""
    line = "test -z \"$(grep -E 'manual fix.*--skip-sovereignty|deserves RCA' agents/audit/audit.sh || true)\"\n"
    f = ss.detect_skip_as_pass(line)
    assert f == [], f"expected no finding when --skip-X is inside quoted grep pattern, got: {[fnd.evidence for fnd in f]}"


def test_skip_as_pass_negative_quoted_dry_run_in_awk():
    """awk/sed PATTERN argument can carry --dry-run as text, not a CLI flag."""
    line = "awk '/--dry-run/ {print}' /var/log/runs.log\n"
    f = ss.detect_skip_as_pass(line)
    assert f == []


def test_skip_as_pass_negative_dry_run_with_grep_assertion():
    """T-2072 empirical FP: --dry-run followed by ; ... | grep -q assertion."""
    line = 'out=$(bin/fw pickup promote-deferred --dry-run 2>&1); echo "$?" | grep -q "^0$"\n'
    f = ss.detect_skip_as_pass(line)
    assert f == [], f"expected no finding when --dry-run line carries a grep assertion, got: {[fnd.evidence for fnd in f]}"


def test_skip_as_pass_negative_collect_only_with_diff_assertion():
    """pytest --collect-only piped into diff is a real assertion."""
    line = "pytest --collect-only tests/ | diff - tests/expected_collection.txt\n"
    f = ss.detect_skip_as_pass(line)
    assert f == []


def test_skip_as_pass_negative_dry_run_with_test_check():
    """--dry-run followed by && test -f is simulation + file check."""
    line = "bin/fw deploy --dry-run && test -f /tmp/deploy.plan\n"
    f = ss.detect_skip_as_pass(line)
    assert f == []


def test_skip_as_pass_positive_bare_skip_preserved():
    """Bare --skip flag with no quoting and no assertion still fires."""
    line = "bash agents/audit/audit.sh --skip-rca\n"
    f = ss.detect_skip_as_pass(line)
    assert len(f) == 1 and f[0].pattern_id == "skip-as-pass"


def test_skip_as_pass_positive_collect_only_preserved():
    """Bare pytest --collect-only (no assertion) still fires (TP regression guard)."""
    f = ss.detect_skip_as_pass("pytest --collect-only tests/\n")
    assert len(f) == 1 and f[0].pattern_id == "skip-as-pass"


def test_skip_as_pass_positive_dry_run_with_devnull_only():
    """--dry-run with > /dev/null (no assertion) still fires — output is discarded."""
    line = "bin/fw deploy --dry-run > /dev/null\n"
    f = ss.detect_skip_as_pass(line)
    assert len(f) == 1


def test_skip_as_pass_positive_pytest_mark_skip_preserved():
    """pytest.mark.skip in verification still fires (TP regression guard)."""
    f = ss.detect_skip_as_pass("pytest tests/foo.py::test_x  # pytest.mark.skip\n")
    assert len(f) == 1


# ───────────────── v1.1: mock-only-integration ─────────────────


def test_mock_only_integration_positive():
    ac = "### Agent\n- [x] Integration tested with real database\n"
    verif = "pytest tests/unit/test_db.py\n"
    f = ss.detect_mock_only_integration(ac, verif)
    assert len(f) == 1 and f[0].pattern_id == "mock-only-integration"


def test_mock_only_integration_positive_e2e_word():
    ac = "### Agent\n- [x] End-to-end flow validated\n"
    verif = "pytest tests/unit/test_flow.py\n"
    f = ss.detect_mock_only_integration(ac, verif)
    assert len(f) == 1


def test_mock_only_integration_negative_real_integration_path():
    ac = "### Agent\n- [x] Integration tested with real database\n"
    verif = "pytest tests/integration/test_db.py\n"
    f = ss.detect_mock_only_integration(ac, verif)
    assert f == []


def test_mock_only_integration_negative_no_integration_in_ac():
    ac = "### Agent\n- [x] Unit test exists for foo\n"
    verif = "pytest tests/unit/test_foo.py\n"
    f = ss.detect_mock_only_integration(ac, verif)
    assert f == []


# ───────────────── v1.1: AC-verify-mismatch ─────────────────


def test_ac_verify_mismatch_positive_unverified_path():
    """v1.2: requires a non-transitive verification (no generic runner)."""
    ac = "### Agent\n- [x] lib/x/foo.py exists with the new helper\n"
    verif = "echo 'done'\n"
    f = ss.detect_ac_verify_mismatch(ac, verif)
    assert len(f) == 1 and f[0].pattern_id == "AC-verify-mismatch"


def test_ac_verify_mismatch_negative_path_referenced():
    ac = "### Agent\n- [x] lib/x/foo.py exists with the new helper\n"
    verif = "test -f lib/x/foo.py\n"
    f = ss.detect_ac_verify_mismatch(ac, verif)
    assert f == []


def test_ac_verify_mismatch_negative_unchecked_ac():
    ac = "### Agent\n- [ ] lib/x/foo.py exists with the new helper\n"
    verif = "bin/fw test unit\n"
    f = ss.detect_ac_verify_mismatch(ac, verif)
    assert f == []


def test_ac_verify_mismatch_skips_human_section():
    ac = "### Human\n- [x] lib/x/foo.py looks right\n"
    verif = "bin/fw test unit\n"
    f = ss.detect_ac_verify_mismatch(ac, verif)
    assert f == []


# ───────────────── v1.1: catalogue v1.1-seed ─────────────────


def test_catalogue_v11_has_eight_patterns(catalogue):
    expected = {"tautology", "empty-body", "swallowed-errors", "output-spoofing",
                "empty-output-success", "skip-as-pass", "mock-only-integration", "AC-verify-mismatch"}
    actual = {p["id"] for p in catalogue["patterns"]}
    assert expected.issubset(actual)


# ───────────────── v1.1: Layer 1 escalation ─────────────────


@pytest.fixture
def escalation_catalogue() -> dict:
    return ss.load_catalogue(ROOT / "policy" / "escalation-patterns.yaml")


def test_escalation_destructive_action_fires_on_force_push(escalation_catalogue):
    triggers = ss.evaluate_escalations(
        ac_section="",
        verif_section="git push --force origin main\n",
        meta={},
        escalation_catalogue=escalation_catalogue,
    )
    ids = {t.trigger_id for t in triggers}
    assert "destructive-action" in ids


def test_escalation_external_publish_fires_on_npm_publish(escalation_catalogue):
    triggers = ss.evaluate_escalations(
        ac_section="",
        verif_section="npm publish --access public\n",
        meta={},
        escalation_catalogue=escalation_catalogue,
    )
    ids = {t.trigger_id for t in triggers}
    assert "external-publish" in ids


def test_escalation_no_fire_on_benign_task(escalation_catalogue):
    triggers = ss.evaluate_escalations(
        ac_section="### Agent\n- [x] foo.py exists\n",
        verif_section="test -f foo.py\n",
        meta={},
        escalation_catalogue=escalation_catalogue,
    )
    assert triggers == []


# ───────────────── v1.1: Layer 2 frontmatter ─────────────────


def test_layer2_risk_high_sets_needs_human(tmp_path, catalogue, escalation_catalogue):
    task_file = tmp_path / ".tasks" / "active" / "T-9999-test.md"
    task_file.parent.mkdir(parents=True)
    task_file.write_text(
        "---\n"
        "id: T-9999\n"
        'name: "Test"\n'
        "status: started-work\n"
        "risk: high\n"
        "---\n\n"
        "# T-9999: Test\n\n"
        "## Acceptance Criteria\n\n### Agent\n- [x] foo exists\n\n"
        "## Verification\n\ntest -f foo\n\n"
    )
    v = ss.scan_task(task_file, catalogue, escalation_catalogue)
    assert v.risk_declared == "high"
    assert v.needs_human is True


def test_layer2_human_signoff_required_sets_needs_human(tmp_path, catalogue, escalation_catalogue):
    task_file = tmp_path / ".tasks" / "active" / "T-9999-test.md"
    task_file.parent.mkdir(parents=True)
    task_file.write_text(
        "---\n"
        "id: T-9999\n"
        "human_signoff: required\n"
        "---\n\n"
        "## Acceptance Criteria\n\n### Agent\n- [x] foo exists\n\n"
        "## Verification\n\ntest -f foo\n\n"
    )
    v = ss.scan_task(task_file, catalogue, escalation_catalogue)
    assert v.human_signoff_declared == "required"
    assert v.needs_human is True


# ───────────────── v1.2: AC-verify-mismatch transitive-coverage (L-265 fix) ─────────────────


def test_ac_verify_mismatch_transitive_fw_test_unit_exempts_lib_path():
    """L-265: AC names lib/foo.sh, verification runs `bin/fw test unit` —
    that runner exercises lib/, so flag should be suppressed."""
    ac = "### Agent\n- [x] lib/x/foo.sh ships with the new helper\n"
    verif = "bin/fw test unit\n"
    f = ss.detect_ac_verify_mismatch(ac, verif)
    assert f == [], f"transitive coverage should suppress; got {f}"


def test_ac_verify_mismatch_transitive_fw_test_unit_exempts_agents_path():
    ac = "### Agent\n- [x] agents/audit/audit.sh works as expected\n"
    verif = "bin/fw test unit\n"
    f = ss.detect_ac_verify_mismatch(ac, verif)
    assert f == []


def test_ac_verify_mismatch_transitive_pytest_exempts_lib():
    ac = "### Agent\n- [x] lib/reviewer/static_scan.py exists\n"
    verif = "pytest tests/unit/\n"
    f = ss.detect_ac_verify_mismatch(ac, verif)
    assert f == []


def test_ac_verify_mismatch_no_runner_no_exemption():
    """Without a transitive runner, the original detection still fires."""
    ac = "### Agent\n- [x] lib/x/foo.sh ships\n"
    verif = "echo 'done'\n"
    f = ss.detect_ac_verify_mismatch(ac, verif)
    assert len(f) == 1


# ───────────────── T-1579: Python-import path coverage ─────────────────


def test_ac_verify_mismatch_python_import_from_exempts_module_path():
    """`from a.b.c import X` directly exercises a/b/c.py — exemption applies."""
    ac = "### Agent\n- [x] web/blueprints/cockpit.py wires NO-REC pill\n"
    verif = 'python3 -c "from web.blueprints.cockpit import get_action_summary; assert True"\n'
    f = ss.detect_ac_verify_mismatch(ac, verif)
    assert f == []


def test_ac_verify_mismatch_python_import_bare_exempts_module_path():
    """`import a.b.c` directly exercises a/b/c.py — exemption applies."""
    ac = "### Agent\n- [x] web/blueprints/cockpit.py wires NO-REC pill\n"
    verif = 'python3 -c "import web.blueprints.cockpit; print(\\"ok\\")"\n'
    f = ss.detect_ac_verify_mismatch(ac, verif)
    assert f == []


def test_ac_verify_mismatch_python_import_exempts_package_init():
    """`from a.b.c import X` covers a/b/c/__init__.py too (package init)."""
    ac = "### Agent\n- [x] web/blueprints/__init__.py exports the new helper\n"
    verif = 'python3 -c "from web.blueprints import cockpit"\n'
    f = ss.detect_ac_verify_mismatch(ac, verif)
    assert f == []


def test_ac_verify_mismatch_python_import_no_match_still_fires():
    """Wrong module imported → AC's path is genuinely not exercised → finding."""
    ac = "### Agent\n- [x] web/blueprints/cockpit.py is wired up\n"
    verif = 'python3 -c "from web.shared import extract_recommendation_state"\n'
    f = ss.detect_ac_verify_mismatch(ac, verif)
    assert len(f) == 1
    assert f[0].pattern_id == "AC-verify-mismatch"


# ───────────────── v1.2: Layer 3 audit ─────────────────


def test_audit_pass_b_runs_and_writes_yaml(tmp_path, monkeypatch):
    from lib.reviewer import audit as audit_mod

    project_root = tmp_path
    (project_root / ".tasks" / "completed").mkdir(parents=True)

    # Create one clean and one dirty completed task
    clean = project_root / ".tasks" / "completed" / "T-1-clean.md"
    clean.write_text(
        "---\nid: T-1\n---\n\n## Acceptance Criteria\n\n### Agent\n- [x] foo done\n\n"
        "## Verification\n\ntest -f file\n"
    )
    dirty = project_root / ".tasks" / "completed" / "T-2-dirty.md"
    dirty.write_text(
        "---\nid: T-2\n---\n\n## Acceptance Criteria\n\n### Agent\n- [x] foo done\n\n"
        "## Verification\n\ntrue\n"
    )

    cat = ss.load_catalogue(ROOT / "policy" / "anti-patterns.yaml")
    esc = ss.load_catalogue(ROOT / "policy" / "escalation-patterns.yaml")
    summary = audit_mod.run_pass_b(project_root, cat, esc)

    assert summary["tasks_scanned"] == 2
    assert summary["totals"]["PASS"] == 1
    assert summary["totals"]["FAIL"] == 1
    out_path = audit_mod.write_audit_yaml(project_root, summary)
    assert out_path.exists()
    loaded = yaml.safe_load(out_path.read_text())
    assert loaded["pass"] == "B"
    assert loaded["catalogue_version"]


def test_layer2_low_risk_does_not_force_needs_human(tmp_path, catalogue, escalation_catalogue):
    task_file = tmp_path / ".tasks" / "active" / "T-9999-test.md"
    task_file.parent.mkdir(parents=True)
    task_file.write_text(
        "---\n"
        "id: T-9999\n"
        "risk: low\n"
        "---\n\n"
        "## Acceptance Criteria\n\n### Agent\n- [x] foo exists\n\n"
        "## Verification\n\ntest -f foo\n\n"
    )
    v = ss.scan_task(task_file, catalogue, escalation_catalogue)
    assert v.risk_declared == "low"
    assert v.needs_human is False  # no Layer 1 triggers, no required signoff


# ───────────────── v1.3 per-AC granular ─────────────────


def test_v13_finding_dataclass_has_ac_fields_default_none():
    f = ss.Finding(
        pattern_id="x", pattern_name="x",
        detection_confidence="deterministic", lie_severity="severe",
        location="loc", evidence="ev",
    )
    assert f.ac_index is None
    assert f.ac_subhead is None
    assert f.ac_text is None
    d = f.to_dict()
    assert "ac_index" in d and "ac_subhead" in d and "ac_text" in d


def test_v13_empty_body_populates_ac_fields():
    section = "### Agent\n- [x] real one\n- [x] TODO\n"
    fs = ss.detect_empty_body(section)
    assert len(fs) == 1
    assert fs[0].ac_index == 2
    assert fs[0].ac_subhead == "Agent"
    assert fs[0].ac_text and "TODO" in fs[0].ac_text


def test_v13_ac_verify_mismatch_populates_ac_fields():
    ac = "### Agent\n- [x] lib/widget/xyz.py exists with thing\n"
    verif = "echo 'no path here'\n"
    fs = ss.detect_ac_verify_mismatch(ac, verif)
    assert len(fs) == 1
    assert fs[0].ac_index == 1
    assert fs[0].ac_subhead == "Agent"
    assert fs[0].ac_text and "lib/widget/xyz.py" in fs[0].ac_text


def test_v13_render_groups_per_ac_findings():
    v = ss.Verdict(
        task_id="T-1", scan_id="R-test", timestamp="2026-04-25T00:00:00Z",
        overall="FAIL", catalogue_version="v1.3-seed",
    )
    v.findings = [
        ss.Finding(
            pattern_id="empty-body", pattern_name="x",
            detection_confidence="deterministic", lie_severity="severe",
            location="AC#1 (Agent)", evidence="[ ] TODO",
            ac_index=1, ac_subhead="Agent", ac_text="TODO",
        ),
        ss.Finding(
            pattern_id="tautology", pattern_name="x",
            detection_confidence="deterministic", lie_severity="severe",
            location="Verification:line 1", evidence="true",
        ),
    ]
    md = ss.render_verdict_md(v)
    assert "Per-AC findings" in md
    assert "Verification-level findings" in md
    assert "AC#1 (Agent)" in md


def test_v13_verdict_section_re_matches_old_versions():
    text = "preamble\n\n## Reviewer Verdict (v1.0)\nold body\n\n## Other\n"
    assert ss._VERDICT_SECTION_RE.search(text) is not None
    text2 = "preamble\n\n## Reviewer Verdict (v1.2)\nold body\n\n## Other\n"
    assert ss._VERDICT_SECTION_RE.search(text2) is not None


def test_version_at_least_v13():
    # v1.3 introduced these fields; v1.4+ keeps them
    assert ss.VERSION >= "v1.3"
    assert ss.SCHEMA_VERSION >= 2


# ───────────────── L-387 SIGPIPE detector (T-2059) ─────────────────
#
# Matrix from T-2057 spike: 15 positives drawn from historical L-387 captures
# (T-1716, T-1838, T-1862, T-1863, T-2008, T-1701, T-1707) and corpus scan,
# 26 negatives covering the safe `out=$(cmd); echo "$out" | grep -q` pattern,
# tempfile + grep -q pattern, finite-upstream forms, and false-positive guards.

L387_POSITIVES = [
    # T-1716 origin shape
    'bin/fw doctor 2>&1 | grep -q "All checks passed"',
    # T-1838 — direct streaming command into terminal grep -q
    'bin/fw doctor | grep -qE "Quick Reference coverage"',
    # T-1862 — wc -l chained into grep -q (last stage still streams)
    'bin/fw audit 2>&1 | grep -cE "FAIL" | grep -q "^0$"',
    # T-1863 — brace-pipeline over fw audit
    '{ bin/fw audit 2>&1; } | grep -q "PASS"',
    # T-2008 — bats output
    'bats tests/unit/test_x.bats | grep -q "ok 5"',
    # T-1701 — fw doctor || true bracketed
    '{ bin/fw doctor 2>&1 || true; } | grep -qE "Cron registry in sync"',
    # T-1707 — fw doctor 2>&1 piped to qE
    'bin/fw doctor 2>&1 | grep -qE "(Cron registry in sync|edited but not generated)"',
    # find streaming
    'find .tasks/active -name "T-*.md" | grep -q "T-2059"',
    # ls glob
    'ls /etc/cron.d/*agentic* | head -1 | grep -q agentic',
    # fw fabric overview (streams)
    'bin/fw fabric overview | grep -q "Subsystems"',
    # fw cron status
    'bin/fw cron status | grep -q registered',
    # python -c emitting via subprocess
    'python3 -m pytest tests/unit/test_x.py | grep -q "1 passed"',
    # grep --quiet long form
    'bin/fw doctor 2>&1 | grep --quiet "OK"',
    # sed pipeline
    'bin/fw fabric drift 2>&1 | sed -n "1,5p" | grep -q clean',
    # awk pipeline
    'bin/fw audit 2>&1 | awk "/PASS/" | grep -q PASS',
]

L387_NEGATIVES = [
    # Safe form #1: capture-then-grep (the documented L-387 fix)
    'out=$(bin/fw doctor 2>&1); echo "$out" | grep -q "OK"',
    'out=$(bin/fw audit 2>&1); echo "$out" | grep -qE "PASS|WARN"',
    'out=$(bats tests/x.bats 2>&1); echo "$out" | grep -q "ok 1"',
    # Safe form #2: tempfile redirect-then-grep
    'bin/fw doctor 2>&1 > /tmp/d; grep -q "OK" /tmp/d',
    'bin/fw audit > /tmp/a 2>&1 && grep -q "PASS" /tmp/a',
    'cmd 2>&1 | tee /tmp/x > /dev/null; grep -q "X" /tmp/x',
    # Bounded upstream — echo/printf are finite
    'echo "yes" | grep -q "yes"',
    'echo "OK" | grep -q OK',
    'printf "ok\\n" | grep -q "ok"',
    'printf "%s\\n" "$value" | grep -q expected',
    # Comments (must be skipped)
    '# bin/fw doctor 2>&1 | grep -q "hidden"',
    '# Example: bin/fw audit | grep -q PASS',
    '## bin/fw doctor | grep -q PATTERN  (illustrative, not a real check)',
    # grep without -q (uses other modes)
    'bin/fw doctor 2>&1 | grep "PATTERN"',
    'bin/fw audit | grep -c "FAIL"',
    'bin/fw doctor 2>&1 | grep -E "WARN"',
    # No pipe at all
    'grep -q "PATTERN" /etc/hosts',
    'grep -q "X" file.txt',
    # Test/conditional shapes — no terminal grep -q in pipe
    'test "$(bin/fw doctor 2>&1 | wc -l)" -gt 0',
    '[ -f /etc/passwd ] && grep -q root /etc/passwd',
    # Capture-via-command-substitution then explicit assignment
    'count=$(bin/fw doctor 2>&1 | grep -c FAIL); [ "$count" -eq 0 ]',
    # Different terminator
    'bin/fw doctor 2>&1 | head -1',
    # Empty / whitespace-only
    '',
    '   ',
    # Newline-only — must not crash
    '\n',
    # Lone EOF heredoc terminator should not trigger the detector
    'EOF',
]


def test_l387_detector_all_positives_flagged():
    """All 15 spike-corpus positives MUST be flagged."""
    for line in L387_POSITIVES:
        f = ss.detect_l387_sigpipe_risk(line + "\n")
        assert f, f"L-387 positive not flagged: {line!r}"
        assert f[0].pattern_id == "l387-sigpipe-risk"
        # `partial` → CONCERN verdict (not FAIL). Bounded-upstream false-negative
        # class makes severe too aggressive given 280+ corpus-flagged lines.
        assert f[0].lie_severity == "partial"


def test_l387_detector_all_negatives_silent():
    """All 26 negatives MUST NOT be flagged."""
    for line in L387_NEGATIVES:
        f = ss.detect_l387_sigpipe_risk(line + "\n")
        assert not f, f"L-387 negative false-positive: {line!r} → {f}"


def test_l387_detector_positive_count_matches_spike_corpus():
    """Matrix size invariant: 15 positives from spike + corpus survey."""
    assert len(L387_POSITIVES) == 15


def test_l387_detector_negative_matrix_minimum_size():
    """At least 26 negatives covering the false-positive classes."""
    assert len(L387_NEGATIVES) >= 26


def test_l387_detector_multi_line_block():
    """Block with mixed lines — flag only the genuine risk."""
    block = (
        "# verify doctor\n"
        "out=$(bin/fw doctor 2>&1); echo \"$out\" | grep -q OK\n"
        "bin/fw audit 2>&1 | grep -q PASS\n"  # ← only this should flag
        "echo finished | grep -q finished\n"
    )
    f = ss.detect_l387_sigpipe_risk(block)
    assert len(f) == 1
    assert "bin/fw audit" in f[0].evidence


def test_l387_detector_finding_location_carries_line_number():
    block = "echo ok\nbin/fw doctor | grep -q OK\n"
    f = ss.detect_l387_sigpipe_risk(block)
    assert f and "line 2" in f[0].location


def test_l387_detector_catalogue_registration():
    """`l387-sigpipe-risk` must be in the catalogue, severity=partial→CONCERN."""
    cat = ss.load_catalogue(CATALOGUE_PATH)
    ids = {p["id"]: p for p in cat["patterns"]}
    assert "l387-sigpipe-risk" in ids
    assert ids["l387-sigpipe-risk"]["lie_severity"] == "partial"
    assert ids["l387-sigpipe-risk"]["detection_confidence"] == "heuristic"


def test_l387_detector_wired_into_scan_task(tmp_path):
    """End-to-end: a task with L-387 in Verification surfaces the finding."""
    task = tmp_path / "T-99387.md"
    task.write_text(
        "---\nid: T-99387\nstatus: started-work\nworkflow_type: build\n"
        "owner: agent\nhorizon: now\nrelated_tasks: []\ntags: []\ncomponents: []\n"
        "created: 2026-05-28T00:00:00Z\nlast_update: 2026-05-28T00:00:00Z\n"
        "date_finished: null\n---\n\n"
        "## Acceptance Criteria\n\n### Agent\n- [x] Some criterion\n\n"
        "## Verification\n\nbin/fw doctor 2>&1 | grep -q \"OK\"\n"
    )
    cat = ss.load_catalogue(CATALOGUE_PATH)
    v = ss.scan_task(task, cat)
    ids = {f.pattern_id for f in v.findings}
    assert "l387-sigpipe-risk" in ids
