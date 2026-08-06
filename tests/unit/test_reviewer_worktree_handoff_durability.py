"""T-2825 (G-075 static backstop): tests for detect_worktree_handoff_durability.

Detector fires when a task body contains a handoff command whose `cd` prefix
targets `.claude/worktrees/<name>` chained (via `&&` on one line, per CLAUDE.md's
own no-bare-multi-line rule) to a verb that outlives the current session --
push, Tier 0 approval, task/arc review, inception decide, arc close/approve-driver.
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from lib.reviewer import static_scan as ss  # noqa: E402


def _run(body: str) -> list[ss.Finding]:
    return ss.detect_worktree_handoff_durability(body)


# ───────────────────────── Positive: flagged ─────────────────────────


def test_worktree_push_handoff_flagged():
    body = (
        "## Recommendation\n"
        "cd /opt/999-Agentic-Engineering-Framework/.claude/worktrees/livefire-t2389 "
        "&& git push origin t2353-audit-emit-tasks\n"
    )
    findings = _run(body)
    assert len(findings) == 1
    assert findings[0].pattern_id == "worktree-handoff-durability"
    assert findings[0].lie_severity == "partial"
    assert findings[0].detection_confidence == "heuristic"
    assert "git push" in findings[0].evidence


def test_worktree_tier0_approve_handoff_flagged():
    body = (
        "cd /opt/999-Agentic-Engineering-Framework/.claude/worktrees/feat "
        "&& bin/fw tier0 approve\n"
    )
    findings = _run(body)
    assert any(f.pattern_id == "worktree-handoff-durability" for f in findings)


def test_worktree_task_review_handoff_flagged():
    body = (
        "cd /opt/999-Agentic-Engineering-Framework/.claude/worktrees/feat "
        "&& bin/fw task review T-2825\n"
    )
    findings = _run(body)
    assert any(f.pattern_id == "worktree-handoff-durability" for f in findings)


def test_worktree_inception_decide_handoff_flagged():
    body = (
        "cd /opt/999-Agentic-Engineering-Framework/.claude/worktrees/feat "
        "&& bin/fw inception decide T-608 go --rationale 'approved'\n"
    )
    findings = _run(body)
    assert any(f.pattern_id == "worktree-handoff-durability" for f in findings)


def test_worktree_arc_close_handoff_flagged():
    body = (
        "cd /opt/999-Agentic-Engineering-Framework/.claude/worktrees/feat "
        "&& fw arc close arc-006 --demo none --justification 'x'\n"
    )
    findings = _run(body)
    assert any(f.pattern_id == "worktree-handoff-durability" for f in findings)


def test_multiple_offending_lines_each_flagged():
    body = (
        "cd .../.claude/worktrees/a && git push origin a\n"
        "cd .../.claude/worktrees/b && bin/fw tier0 approve\n"
    )
    findings = _run(body)
    assert len(findings) == 2


# ───────────────────────── Negative: not flagged ─────────────────────────


def test_worktree_cd_without_outliving_verb_not_flagged():
    """Same-session use (e.g. fw work-on right after create) is not flagged."""
    body = "cd /opt/999-Agentic-Engineering-Framework/.claude/worktrees/feat && fw work-on \"thing\" --type build\n"
    assert _run(body) == []


def test_main_repo_path_not_flagged():
    """Durable main-repo path (the CLAUDE.md 'Good' example) is not flagged."""
    body = "git push origin t2353-audit-emit-tasks\n"
    assert _run(body) == []


def test_worktree_mention_without_cd_chain_not_flagged():
    """Bare mention of the path (e.g. prose) without the cd&&verb shape is not flagged."""
    body = "The stranded commits lived in .claude/worktrees/livefire-t2389 until removal.\n"
    assert _run(body) == []


def test_empty_body_no_findings():
    assert _run("") == []


# ───────────────────────── Integration: scan_task plumbing ───────────────────


def test_scan_task_wires_detector(tmp_path):
    (tmp_path / "policy").mkdir()
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    catalogue_path = tmp_path / "policy" / "anti-patterns.yaml"
    catalogue_path.write_text(
        "catalogue_version: test\nverdict_thresholds:\n  fail_on_severities: [complete, severe]\n"
        "  concern_on_severities: [partial, narrow, staleness]\n"
    )
    task_path = tmp_path / ".tasks" / "active" / "T-9002-test.md"
    task_path.write_text(
        "---\nid: T-9002\n---\n\n"
        "## Recommendation\n\n"
        "cd /opt/999-Agentic-Engineering-Framework/.claude/worktrees/feat "
        "&& bin/fw task review T-9002\n"
    )
    import yaml
    catalogue = yaml.safe_load(catalogue_path.read_text())
    verdict = ss.scan_task(task_path, catalogue)
    wt_findings = [f for f in verdict.findings if f.pattern_id == "worktree-handoff-durability"]
    assert len(wt_findings) >= 1
    assert verdict.overall in {"CONCERN", "FAIL"}
