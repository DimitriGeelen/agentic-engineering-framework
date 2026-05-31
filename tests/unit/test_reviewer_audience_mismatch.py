"""T-2147 (T-2143 leg B): tests for detect_audience_mismatch.

Detector fires on `[REVIEW]` Human ACs whose subject is agent experience.
Five gates (CLAUDE.md §AC Classification Guidance, audience axis):
  1. AC under `### Human` subhead with `[REVIEW]` prefix (NOT `[REVIEWER]`)
  2. Body or Expected contains agent-as-subject phrasing
  3. Expected does NOT re-anchor on human/operator/user/you as subject
  4. No author opt-out marker present

Origin: T-2139 V1 keystone gate-message AC. The single-axis routing heuristic
(subjective → Human) recursed 4 author rounds with no audience check.
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from lib.reviewer import static_scan as ss  # noqa: E402


# ───────────────────────── Positive cases ─────────────────────────


def test_fires_on_agent_who_trips():
    """AC #4 case (a): 'agent who trips' + [REVIEW] under Human → CONCERN."""
    ac = """
### Human
- [ ] [REVIEW] Block-message stderr reads cleanly to a tripping agent
  **Steps:** Trigger the gate. Read stderr.
  **Expected:** stderr makes the agent unblock itself without operator help
  **If not:** Edit message
"""
    findings = ss.detect_audience_mismatch(ac)
    assert len(findings) == 1
    assert findings[0].pattern_id == "audience-mismatch"
    assert findings[0].ac_index == 1
    assert findings[0].ac_subhead.lower().startswith("human")


def test_fires_on_agent_reads():
    ac = """
### Human
- [ ] [REVIEW] CLI output for the agent feels clean
  **Steps:** Run the command
  **Expected:** agent reads the help text and gets the right next step
  **If not:** Reword
"""
    findings = ss.detect_audience_mismatch(ac)
    assert len(findings) == 1


def test_fires_on_the_agent_will():
    ac = """
### Human
- [ ] [REVIEW] Gate refusal is intuitive
  **Steps:** Trip the gate
  **Expected:** the agent will see the bypass instructions and try them
"""
    findings = ss.detect_audience_mismatch(ac)
    assert len(findings) == 1


# ───────────────────────── Negative cases ─────────────────────────


def test_silent_when_expected_reanchors_on_operator():
    """AC #4 case (b): 'you (operator)' + REVIEW does NOT trigger."""
    ac = """
### Human
- [ ] [REVIEW] Stderr that the agent reads is clear
  **Steps:** Trigger gate
  **Expected:** you (the operator) confirm the message reads clean
  **If not:** Reframe
"""
    findings = ss.detect_audience_mismatch(ac)
    assert len(findings) == 0


def test_silent_when_expected_uses_user_subject():
    """AC #4 case (e): UI for the human user — 'user' as subject."""
    ac = """
### Human
- [ ] [REVIEW] Dashboard agent-activity panel renders
  **Steps:** Open page
  **Expected:** the user sees agent rows highlighted in green
  **If not:** Edit CSS
"""
    findings = ss.detect_audience_mismatch(ac)
    assert len(findings) == 0


def test_silent_under_agent_subhead():
    """AC #4 case (c): Agent-section AC with same phrasing does NOT trigger."""
    ac = """
### Agent
- [ ] [REVIEW] Agent reads the stderr correctly
  **Expected:** stderr matches the integration test
"""
    findings = ss.detect_audience_mismatch(ac)
    assert len(findings) == 0


def test_silent_on_reviewer_prefix():
    """`[REVIEWER]` is prose-mismatch's territory — not this detector's."""
    ac = """
### Human
- [ ] [REVIEWER] Agent reads stderr cleanly
  **Expected:** Reviewer PASS
"""
    findings = ss.detect_audience_mismatch(ac)
    assert len(findings) == 0


def test_silent_with_author_opt_out_marker():
    """AC #4 case (d): explicit opt-out marker suppresses."""
    ac = """
### Human
- [ ] [REVIEW] Agent reads stderr (rewritten to ask the operator)
  **Steps:** Read stderr
  **Expected:** the prose makes sense
"""
    findings = ss.detect_audience_mismatch(ac)
    assert len(findings) == 0


def test_silent_when_audience_marker_present():
    """`audience: operator` marker exempts."""
    ac = """
### Human
- [ ] [REVIEW] Block message reads cleanly to the tripping agent
  audience: operator
  **Steps:** Read it
  **Expected:** clean prose
"""
    findings = ss.detect_audience_mismatch(ac)
    assert len(findings) == 0


def test_silent_on_empty_section():
    assert ss.detect_audience_mismatch("") == []


def test_silent_on_no_human_section():
    ac = """
### Agent
- [ ] Did the work
"""
    assert ss.detect_audience_mismatch(ac) == []


def test_silent_on_human_section_without_review_prefix():
    """No `[REVIEW]` prefix — outside this detector's gate."""
    ac = """
### Human
- [ ] Confirm the agent reads stderr correctly
  **Expected:** stderr matches spec
"""
    assert ss.detect_audience_mismatch(ac) == []


def test_silent_on_rendered_ui_for_user_with_agent_mention():
    """Body mentions agents incidentally; Expected anchors on user."""
    ac = """
### Human
- [ ] [REVIEW] Agents list page renders
  **Steps:** Open /agents
  **Expected:** the user sees a list of agent rows
"""
    findings = ss.detect_audience_mismatch(ac)
    assert len(findings) == 0


# ───────────────────────── Integration into scan_task ─────────────────────────


def test_integrated_in_scan_task(tmp_path):
    """Detector runs as part of scan_task's pipeline."""
    task_file = tmp_path / "T-9951-fixture.md"
    task_file.write_text(
        """---
id: T-9951
name: audience-mismatch-fixture
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-05-31T00:00:00Z
last_update: 2026-05-31T00:00:00Z
date_finished: null
---

# T-9951

## Acceptance Criteria

### Agent
- [x] Did the work

### Human
- [ ] [REVIEW] Stderr reads cleanly to a tripping agent
  **Steps:** Trip gate
  **Expected:** the agent will unblock itself
"""
    )
    catalogue = {"verdict_thresholds": {"fail_on_severities": ["complete", "severe"], "concern_on_severities": ["partial", "narrow", "staleness"]}, "catalogue_version": "test"}
    verdict = ss.scan_task(task_file, catalogue)
    pattern_ids = [f.pattern_id for f in verdict.findings]
    assert "audience-mismatch" in pattern_ids
