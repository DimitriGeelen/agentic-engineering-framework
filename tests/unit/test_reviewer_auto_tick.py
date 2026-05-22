"""Tests for v1.5 auto-tick [REVIEWER] Agent ACs (T-1985).

Covers all 9 sovereignty test cases plus helpers.
"""

from __future__ import annotations

import sys
import textwrap
from pathlib import Path
from unittest.mock import patch, MagicMock

import pytest
import yaml

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from lib.reviewer import static_scan as ss
from lib.reviewer.overrides import Override
from datetime import datetime, timedelta, timezone

CATALOGUE_PATH = ROOT / "policy" / "anti-patterns.yaml"


@pytest.fixture
def catalogue() -> dict:
    return ss.load_catalogue(CATALOGUE_PATH)


# ─────────────── Helper fixtures ───────────────


def _make_override(task_id: str, pattern_id: str = "tautology", ac_index: int | None = 1, expired: bool = False) -> Override:
    delta = timedelta(days=-1 if expired else 90)
    exp = (datetime.now(timezone.utc) + delta).strftime("%Y-%m-%dT%H:%M:%SZ")
    return Override(
        id="OV-0001",
        task_id=task_id,
        pattern_id=pattern_id,
        ac_index=ac_index,
        reason="test",
        expires_at=exp,
        added_by="test",
        added_at="2026-01-01T00:00:00Z",
    )


def _make_parsed_ac(
    ac_text: str = "[REVIEWER] some check",
    ac_index: int = 1,
    ac_subhead: str = "Agent",
    ticked: bool = False,
) -> ss.ParsedAC:
    state = "x" if ticked else " "
    raw_line = f"- [{state}] {ac_text}"
    return ss.ParsedAC(
        ac_index=ac_index,
        ac_subhead=ac_subhead,
        ac_text=ac_text,
        ticked=ticked,
        raw_line=raw_line,
    )


# ─────────────── _compute_ac_text_digest ───────────────


def test_digest_is_12_hex_chars():
    d = ss._compute_ac_text_digest("some ac text")
    assert len(d) == 12
    assert all(c in "0123456789abcdef" for c in d)


def test_digest_same_text_same_result():
    assert ss._compute_ac_text_digest("hello") == ss._compute_ac_text_digest("hello")


def test_digest_different_text_different_result():
    assert ss._compute_ac_text_digest("hello") != ss._compute_ac_text_digest("world")


# ─────────────── _feedback_stream_has_tick ───────────────


def test_feedback_stream_has_tick_true(tmp_path):
    fs = tmp_path / "feedback-stream.yaml"
    fs.write_text("---\nkind: auto_tick\npayload:\n  key: auto_tick:T-0001:1:abc123def456\n")
    assert ss._feedback_stream_has_tick("T-0001", 1, "abc123def456", fs) is True


def test_feedback_stream_has_tick_false_missing_entry(tmp_path):
    fs = tmp_path / "feedback-stream.yaml"
    fs.write_text("---\nkind: auto_tick\npayload:\n  key: auto_tick:T-0001:1:abc123def456\n")
    assert ss._feedback_stream_has_tick("T-0001", 1, "different_digest", fs) is False


def test_feedback_stream_has_tick_false_no_file(tmp_path):
    fs = tmp_path / "feedback-stream.yaml"
    assert ss._feedback_stream_has_tick("T-0001", 1, "abc123def456", fs) is False


# ─────────────── _should_auto_tick — 5 negative cases ───────────────


def test_should_auto_tick_positive():
    """(a) tick fires on clean PASS + [REVIEWER] Agent AC."""
    ac = _make_parsed_ac("[REVIEWER] static check passes")
    result = ss._should_auto_tick(ac, findings=[], task_overrides=[], verdict_overall="PASS")
    assert result is True


def test_should_auto_tick_no_tick_on_fail_verdict():
    """(b) no tick on FAIL verdict."""
    ac = _make_parsed_ac("[REVIEWER] static check passes")
    result = ss._should_auto_tick(ac, findings=[], task_overrides=[], verdict_overall="FAIL")
    assert result is False


def test_should_auto_tick_no_tick_on_concern_verdict():
    """(b-variant) no tick on CONCERN verdict."""
    ac = _make_parsed_ac("[REVIEWER] static check passes")
    result = ss._should_auto_tick(ac, findings=[], task_overrides=[], verdict_overall="CONCERN")
    assert result is False


def test_should_auto_tick_no_tick_with_matching_finding():
    """(c) no tick on AC with matching ac_index finding."""
    ac = _make_parsed_ac("[REVIEWER] static check passes", ac_index=2, ac_subhead="Agent")
    finding = ss.Finding(
        pattern_id="tautology",
        pattern_name="Tautological verification",
        detection_confidence="deterministic",
        lie_severity="severe",
        location="AC#2 (Agent)",
        evidence="true",
        ac_index=2,
        ac_subhead="Agent",
        ac_text="[REVIEWER] static check passes",
    )
    result = ss._should_auto_tick(ac, findings=[finding], task_overrides=[], verdict_overall="PASS")
    assert result is False


def test_should_auto_tick_no_tick_already_ticked():
    """(d) no tick on already-[x] AC."""
    ac = _make_parsed_ac("[REVIEWER] already done", ticked=True)
    result = ss._should_auto_tick(ac, findings=[], task_overrides=[], verdict_overall="PASS")
    assert result is False


def test_should_auto_tick_no_tick_with_active_suppress_override():
    """(e) no tick when suppress override targets the AC."""
    ac = _make_parsed_ac("[REVIEWER] check", ac_index=1)
    override = _make_override("T-0001", ac_index=1, expired=False)
    result = ss._should_auto_tick(ac, findings=[], task_overrides=[override], verdict_overall="PASS")
    assert result is False


def test_should_auto_tick_expired_override_does_not_block():
    """(e-expired) expired override is ignored — tick fires."""
    ac = _make_parsed_ac("[REVIEWER] check", ac_index=1)
    override = _make_override("T-0001", ac_index=1, expired=True)
    result = ss._should_auto_tick(ac, findings=[], task_overrides=[override], verdict_overall="PASS")
    assert result is True


def test_should_auto_tick_wildcard_override_does_not_block():
    """(e-wildcard) ac_index=None override suppresses findings but must NOT block ticking a specific AC."""
    ac = _make_parsed_ac("[REVIEWER] check", ac_index=1)
    # Wildcard override (None) suppresses a pattern for the whole task, not a specific AC
    wildcard_override = _make_override("T-0001", ac_index=None, expired=False)
    result = ss._should_auto_tick(ac, findings=[], task_overrides=[wildcard_override], verdict_overall="PASS")
    assert result is True, "wildcard override should not block ticking a specific AC"


def test_should_auto_tick_no_tick_non_reviewer_prefix():
    """(f) no tick on non-[REVIEWER] Agent AC."""
    ac = _make_parsed_ac("plain AC text without reviewer prefix")
    result = ss._should_auto_tick(ac, findings=[], task_overrides=[], verdict_overall="PASS")
    assert result is False


def test_should_auto_tick_no_tick_review_prefix():
    """(f-variant) [REVIEW] prefix (not [REVIEWER]) does not trigger auto-tick."""
    ac = _make_parsed_ac("[REVIEW] human judgment AC")
    result = ss._should_auto_tick(ac, findings=[], task_overrides=[], verdict_overall="PASS")
    assert result is False


def test_should_auto_tick_finding_on_different_ac_does_not_block():
    """Finding on ac_index=3 must not block ac_index=1."""
    ac = _make_parsed_ac("[REVIEWER] check", ac_index=1, ac_subhead="Agent")
    finding = ss.Finding(
        pattern_id="tautology",
        pattern_name="Tautological verification",
        detection_confidence="deterministic",
        lie_severity="severe",
        location="AC#3 (Agent)",
        evidence="true",
        ac_index=3,
        ac_subhead="Agent",
        ac_text="some other AC",
    )
    result = ss._should_auto_tick(ac, findings=[finding], task_overrides=[], verdict_overall="PASS")
    assert result is True


# ─────────────── _parse_agent_acs ───────────────


def test_parse_agent_acs_returns_only_agent():
    section = textwrap.dedent("""\
        ### Agent
        - [ ] [REVIEWER] agent check 1
        - [x] [REVIEWER] agent check 2 already ticked
        ### Human
        - [ ] [REVIEWER] human check (must NOT appear)
    """)
    acs = ss._parse_agent_acs(section)
    assert len(acs) == 2
    assert all(a.ac_subhead == "Agent" for a in acs)
    assert acs[0].ac_text == "[REVIEWER] agent check 1"
    assert acs[1].ticked is True


def test_parse_agent_acs_no_agent_section():
    section = textwrap.dedent("""\
        - [ ] [REVIEWER] top-level AC
    """)
    # No explicit ### Agent subhead → no ACs returned
    acs = ss._parse_agent_acs(section)
    assert acs == []


def test_parse_agent_acs_human_boundary():
    """Human ACs are never included even if [REVIEWER] prefixed."""
    section = textwrap.dedent("""\
        ### Agent
        - [ ] [REVIEWER] valid
        ### Human
        - [ ] [REVIEWER] should not appear
        - [ ] plain human
    """)
    acs = ss._parse_agent_acs(section)
    assert len(acs) == 1
    assert acs[0].ac_text == "[REVIEWER] valid"


# ─────────────── Sovereignty test matrix (9 cases from spec) ───────────────


def _make_task_file(tmp_path: Path, name: str, ac_block: str, verif: str = "python3 -c 'pass'\n") -> Path:
    """Create a minimal task file for sovereignty tests."""
    # Build content without textwrap.dedent to avoid indentation issues with multi-line ac_block
    lines = [
        "---",
        "id: T-9900",
        "name: test task",
        "status: started-work",
        "workflow_type: build",
        "---",
        "",
        "# T-9900",
        "",
        "## Acceptance Criteria",
        "",
    ]
    lines.extend(ac_block.splitlines())
    lines += [
        "",
        "## Verification",
        "",
    ]
    lines.extend(verif.splitlines())
    lines.append("")
    content = "\n".join(lines)
    p = tmp_path / ".tasks" / "active" / f"T-9900-{name}.md"
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(content)
    return p


def test_sovereignty_a_tick_fires_clean_pass(tmp_path, catalogue):
    """(a) tick fires on clean PASS + [REVIEWER] Agent AC."""
    p = _make_task_file(
        tmp_path, "a",
        "### Agent\n- [ ] [REVIEWER] reviewer audit passes — sentinel",
    )
    stream = tmp_path / ".context" / "working" / "feedback-stream.yaml"
    stream.parent.mkdir(parents=True, exist_ok=True)
    verdict = ss.scan_task(p, catalogue)
    assert verdict.overall == "PASS"
    ticked_info, mutations = ss._compute_auto_ticks(p, "T-9900", verdict, [], stream)
    assert len(ticked_info) == 1
    assert len(mutations) == 1
    assert "- [x]" in mutations[0][1]


def test_sovereignty_b_no_tick_fail_verdict(tmp_path, catalogue):
    """(b) no tick on FAIL verdict."""
    p = _make_task_file(
        tmp_path, "b",
        "### Agent\n- [ ] [REVIEWER] should not tick",
        verif="true\n",  # tautology → FAIL
    )
    stream = tmp_path / ".context" / "working" / "feedback-stream.yaml"
    stream.parent.mkdir(parents=True, exist_ok=True)
    verdict = ss.scan_task(p, catalogue)
    assert verdict.overall == "FAIL"
    ticked_info, mutations = ss._compute_auto_ticks(p, "T-9900", verdict, [], stream)
    assert ticked_info == []
    assert mutations == []


def test_sovereignty_c_no_tick_ac_finding(tmp_path, catalogue):
    """(c) no tick on AC with matching ac_index finding (injected via Verdict)."""
    p = _make_task_file(
        tmp_path, "c",
        "### Agent\n- [ ] [REVIEWER] check that has a finding",
    )
    stream = tmp_path / ".context" / "working" / "feedback-stream.yaml"
    stream.parent.mkdir(parents=True, exist_ok=True)
    # Build a verdict with a finding that targets ac_index=1
    injected_finding = ss.Finding(
        pattern_id="tautology",
        pattern_name="Tautological verification",
        detection_confidence="deterministic",
        lie_severity="severe",
        location="AC#1 (Agent)",
        evidence="true",
        ac_index=1,
        ac_subhead="Agent",
        ac_text="[REVIEWER] check that has a finding",
    )
    verdict = ss.scan_task(p, catalogue)
    # Inject finding — finding on ac_index=1 should block tick
    verdict.findings.append(injected_finding)
    ticked_info, mutations = ss._compute_auto_ticks(p, "T-9900", verdict, [], stream)
    assert ticked_info == []


def test_sovereignty_d_no_tick_already_ticked(tmp_path, catalogue):
    """(d) no tick on already-[x] AC."""
    p = _make_task_file(
        tmp_path, "d",
        "### Agent\n- [x] [REVIEWER] already ticked",
    )
    stream = tmp_path / ".context" / "working" / "feedback-stream.yaml"
    stream.parent.mkdir(parents=True, exist_ok=True)
    verdict = ss.scan_task(p, catalogue)
    ticked_info, mutations = ss._compute_auto_ticks(p, "T-9900", verdict, [], stream)
    assert ticked_info == []


def test_sovereignty_e_no_tick_suppress_override(tmp_path, catalogue):
    """(e) no tick when suppress override targets the AC."""
    p = _make_task_file(
        tmp_path, "e",
        "### Agent\n- [ ] [REVIEWER] reviewer check",
    )
    stream = tmp_path / ".context" / "working" / "feedback-stream.yaml"
    stream.parent.mkdir(parents=True, exist_ok=True)
    override = _make_override("T-9900", ac_index=1, expired=False)
    verdict = ss.scan_task(p, catalogue)
    ticked_info, mutations = ss._compute_auto_ticks(p, "T-9900", verdict, [override], stream)
    assert ticked_info == []


def test_sovereignty_f_no_tick_non_reviewer_prefix(tmp_path, catalogue):
    """(f) no tick on non-[REVIEWER] Agent AC."""
    p = _make_task_file(
        tmp_path, "f",
        "### Agent\n- [ ] plain AC without reviewer prefix",
    )
    stream = tmp_path / ".context" / "working" / "feedback-stream.yaml"
    stream.parent.mkdir(parents=True, exist_ok=True)
    verdict = ss.scan_task(p, catalogue)
    ticked_info, mutations = ss._compute_auto_ticks(p, "T-9900", verdict, [], stream)
    assert ticked_info == []


def test_sovereignty_g_no_tick_human_ac(tmp_path, catalogue):
    """(g) no tick on Human AC even with [REVIEWER] prefix and clean verdict."""
    p = _make_task_file(
        tmp_path, "g",
        "### Agent\n- [ ] regular agent ac\n### Human\n- [ ] [REVIEWER] human reviewer ac",
    )
    stream = tmp_path / ".context" / "working" / "feedback-stream.yaml"
    stream.parent.mkdir(parents=True, exist_ok=True)
    verdict = ss.scan_task(p, catalogue)
    ticked_info, mutations = ss._compute_auto_ticks(p, "T-9900", verdict, [], stream)
    # No tick: Agent AC doesn't have [REVIEWER], Human AC is not parsed
    assert ticked_info == []
    # Verify human AC checkbox was not touched
    text = p.read_text()
    assert "- [ ] [REVIEWER] human reviewer ac" in text


def test_sovereignty_h_no_retick_after_human_untick(tmp_path, catalogue):
    """(h) re-scan after human-untick respects feedback-stream and does NOT re-tick."""
    p = _make_task_file(
        tmp_path, "h",
        "### Agent\n- [ ] [REVIEWER] reviewer check passes",
    )
    stream = tmp_path / ".context" / "working" / "feedback-stream.yaml"
    stream.parent.mkdir(parents=True, exist_ok=True)

    verdict = ss.scan_task(p, catalogue)
    ticked_info, mutations = ss._compute_auto_ticks(p, "T-9900", verdict, [], stream)
    assert len(ticked_info) == 1

    # Simulate: write the sovereignty-rail entry (as main() would do)
    entry = ticked_info[0]
    digest = entry["digest"]
    ss.append_feedback_event(
        stream,
        {
            "kind": "auto_tick",
            "timestamp": "2026-01-01T00:00:00Z",
            "scan_id": "R-test",
            "task_id": "T-9900",
            "payload": {
                "key": f"auto_tick:T-9900:1:{digest}",
                "ac_index": 1,
                "digest": digest,
                "text_excerpt": "[REVIEWER] reviewer check passes",
            },
        },
    )

    # Human un-ticks (AC stays as `- [ ]`)
    # Re-scan: sovereignty rail should prevent re-tick
    verdict2 = ss.scan_task(p, catalogue)
    ticked_info2, mutations2 = ss._compute_auto_ticks(p, "T-9900", verdict2, [], stream)
    assert ticked_info2 == [], "sovereignty rail must prevent re-tick after human un-tick"
    assert mutations2 == []


def test_sovereignty_i_retick_after_digest_change(tmp_path, catalogue):
    """(i) AC text changed → new digest → eligible to tick again."""
    p = _make_task_file(
        tmp_path, "i",
        "### Agent\n- [ ] [REVIEWER] original check text",
    )
    stream = tmp_path / ".context" / "working" / "feedback-stream.yaml"
    stream.parent.mkdir(parents=True, exist_ok=True)

    # Write a fake sovereignty-rail entry for the OLD AC text digest
    old_digest = ss._compute_ac_text_digest("[REVIEWER] original check text")
    ss.append_feedback_event(
        stream,
        {
            "kind": "auto_tick",
            "timestamp": "2026-01-01T00:00:00Z",
            "scan_id": "R-old",
            "task_id": "T-9900",
            "payload": {
                "key": f"auto_tick:T-9900:1:{old_digest}",
                "ac_index": 1,
                "digest": old_digest,
                "text_excerpt": "[REVIEWER] original check text",
            },
        },
    )

    # Rewrite the AC text (simulates human editing the task)
    text = p.read_text()
    text = text.replace("[REVIEWER] original check text", "[REVIEWER] updated check text (v2)")
    p.write_text(text)

    # New digest differs → should be eligible to tick
    verdict = ss.scan_task(p, catalogue)
    ticked_info, mutations = ss._compute_auto_ticks(p, "T-9900", verdict, [], stream)
    assert len(ticked_info) == 1, "new digest should allow re-tick"
    new_digest = ss._compute_ac_text_digest("[REVIEWER] updated check text (v2)")
    assert ticked_info[0]["digest"] == new_digest


# ─────────────── Atomic write ───────────────


def test_write_verdict_and_ticks_single_rename(tmp_path, catalogue):
    """Verify write_verdict_to_task uses os.replace (single atomic rename)."""
    p = _make_task_file(
        tmp_path, "atomic",
        "### Agent\n- [ ] [REVIEWER] check passes",
    )
    verdict = ss.scan_task(p, catalogue)
    mutations = [("- [ ] [REVIEWER] check passes", "- [x] [REVIEWER] check passes")]

    rename_calls = []
    real_replace = __import__("os").replace

    def spy_replace(src, dst):
        rename_calls.append((src, dst))
        real_replace(src, dst)

    with patch("os.replace", side_effect=spy_replace):
        ss.write_verdict_to_task(p, verdict, ac_mutations=mutations)

    assert len(rename_calls) == 1, "must be exactly one atomic rename"


# ─────────────── Verdict block format ───────────────


def test_render_verdict_includes_auto_ticked_block():
    """Verdict block reports Auto-ticked count and per-AC lines when ticks exist."""
    from lib.reviewer.static_scan import Verdict
    verdict = Verdict(
        task_id="T-9900",
        scan_id="R-abc",
        timestamp="2026-01-01T00:00:00Z",
        overall="PASS",
        auto_ticked=[
            {"ac_index": 2, "digest": "abc123def456", "text_excerpt": "[REVIEWER] check"},
        ],
    )
    rendered = ss.render_verdict_md(verdict)
    assert "**Auto-ticked:** 1 AC(s)" in rendered
    assert "AC #2: abc123def456 [[REVIEWER] check]" in rendered


def test_render_verdict_no_auto_ticked_block_when_empty():
    """When no ACs are auto-ticked, the Auto-ticked line is absent."""
    from lib.reviewer.static_scan import Verdict
    verdict = Verdict(
        task_id="T-9900",
        scan_id="R-abc",
        timestamp="2026-01-01T00:00:00Z",
        overall="PASS",
    )
    rendered = ss.render_verdict_md(verdict)
    assert "Auto-ticked" not in rendered


# ─────────────── No-mutation on completed/ tasks ───────────────


def test_completed_task_never_mutated(tmp_path, catalogue):
    """_compute_auto_ticks must return no mutations for completed/ tasks."""
    p = tmp_path / ".tasks" / "completed" / "T-9900-test.md"
    p.parent.mkdir(parents=True, exist_ok=True)
    content = "\n".join([
        "---",
        "id: T-9900",
        "name: completed task",
        "status: work-completed",
        "workflow_type: build",
        "---",
        "",
        "# T-9900",
        "",
        "## Acceptance Criteria",
        "",
        "### Agent",
        "- [ ] [REVIEWER] should not be ticked in completed",
        "",
        "## Verification",
        "",
        "python3 -c 'pass'",
        "",
    ])
    p.write_text(content)
    stream = tmp_path / ".context" / "working" / "feedback-stream.yaml"
    stream.parent.mkdir(parents=True, exist_ok=True)
    verdict = ss.scan_task(p, catalogue)
    ticked_info, mutations = ss._compute_auto_ticks(p, "T-9900", verdict, [], stream)
    assert ticked_info == []
    assert mutations == []
