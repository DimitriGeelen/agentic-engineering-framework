"""T-100187: Recommendation-claims validator (T-100186 GO slice A).

Extracts typed evidence claims (file / file:line / T-XXX / module.function)
from an inception task's ## Recommendation section, verifies each read-only,
and writes a ## Recommendation Verdict block atomically.

Pinned invariants:
  - one pass + one fail fixture per claim class
  - overall CONTRADICTED when any claim fails
  - idempotent re-run (verdict block replaced, not duplicated)
  - never modifies ## Recommendation, ## Decision, or AC checkboxes
  - completed/ files never mutated
"""

from __future__ import annotations

import re

import pytest

from lib.reviewer.recommendation_claims import (
    extract_claims,
    extract_recommendation_text,
    render_claims_verdict_md,
    validate_task,
    write_claims_verdict_to_task,
)


# ── fixtures ──────────────────────────────────────────────────────────────────


@pytest.fixture
def project(tmp_path):
    """Synthetic project root: .tasks/{active,completed} + lib/ + a real file."""
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    (tmp_path / ".tasks" / "completed").mkdir(parents=True)
    (tmp_path / "lib").mkdir()
    (tmp_path / "lib" / "target.py").write_text(
        "def real_symbol():\n    return 1\n" + "\n" * 10
    )
    (tmp_path / ".tasks" / "completed" / "T-5001-done-task.md").write_text(
        "---\nid: T-5001\n---\n# done\n"
    )
    return tmp_path


def make_inception(project, rec_body, task_id="T-9100"):
    p = project / ".tasks" / "active" / f"{task_id}-fixture-inception.md"
    p.write_text(
        f"""---
id: {task_id}
name: "fixture inception"
status: started-work
workflow_type: inception
owner: agent
---

# {task_id}: fixture

## Acceptance Criteria

### Agent
- [x] researched
- [ ] not yet done

## Recommendation

{rec_body}

## Decision

(pending)
"""
    )
    return p


# ── extraction ────────────────────────────────────────────────────────────────


def test_extracts_all_four_claim_types():
    text = (
        "**Evidence:**\n"
        "- module at `lib/target.py` and `lib/target.py:5`\n"
        "- symbol `target.real_symbol` reused\n"
        "- shipped by T-5001\n"
    )
    claims = extract_claims(text)
    kinds = {(c.kind, c.raw) for c in claims}
    assert ("file", "lib/target.py") in kinds
    assert ("file_line", "lib/target.py:5") in kinds
    assert ("module", "target.real_symbol") in kinds
    assert ("task", "T-5001") in kinds


def test_extraction_skips_urls_self_ref_and_prose_dots():
    text = (
        "See `https://example.com/a.py` and e.g. this task T-9100.\n"
        "Also `run the tests` (not a claim).\n"
    )
    claims = extract_claims(text, self_task_id="T-9100")
    assert claims == []


def test_recommendation_section_bounded_by_next_heading():
    body = "## Recommendation\n\nGO — see `lib/a.py`\n\n## Decision\n\n`lib/b.py`\n"
    text = extract_recommendation_text(body)
    assert "lib/a.py" in text
    assert "lib/b.py" not in text


# ── per-class pass/fail verification ──────────────────────────────────────────


def test_file_claim_pass_and_fail(project):
    task = make_inception(project, "GO. Evidence: `lib/target.py` and `lib/missing.py`.")
    v = validate_task(task, project)
    by_raw = {c.raw: c.status for c in v.claims}
    assert by_raw["lib/target.py"] == "pass"
    assert by_raw["lib/missing.py"] == "fail"


def test_file_line_claim_pass_and_fail(project):
    task = make_inception(project, "GO. See `lib/target.py:2` and `lib/target.py:9999`.")
    v = validate_task(task, project)
    by_raw = {c.raw: c.status for c in v.claims}
    assert by_raw["lib/target.py:2"] == "pass"
    assert by_raw["lib/target.py:9999"] == "fail"


def test_task_claim_pass_and_fail(project):
    task = make_inception(project, "GO. Shipped by T-5001; see also T-4999.")
    v = validate_task(task, project)
    by_raw = {c.raw: c.status for c in v.claims}
    assert by_raw["T-5001"] == "pass"
    assert by_raw["T-4999"] == "fail"


def test_module_claim_pass_and_fail(project):
    task = make_inception(
        project, "GO. Reuses `target.real_symbol`; also `target.ghost_symbol_xyz`."
    )
    v = validate_task(task, project)
    by_raw = {c.raw: c.status for c in v.claims}
    assert by_raw["target.real_symbol"] == "pass"
    assert by_raw["target.ghost_symbol_xyz"] == "fail"


# ── overall verdict ───────────────────────────────────────────────────────────


def test_overall_confirmed_when_all_pass(project):
    task = make_inception(project, "GO. Evidence: `lib/target.py`, T-5001.")
    assert validate_task(task, project).overall == "CONFIRMED"


def test_overall_contradicted_when_any_fail(project):
    task = make_inception(project, "GO. Evidence: `lib/target.py`, `lib/missing.py`.")
    assert validate_task(task, project).overall == "CONTRADICTED"


def test_overall_unverified_when_no_claims(project):
    task = make_inception(project, "GO because it feels right. No citations.")
    assert validate_task(task, project).overall == "UNVERIFIED"


# ── verdict block write: idempotence + invariants ─────────────────────────────


def test_write_is_idempotent_and_replaces_block(project):
    task = make_inception(project, "GO. Evidence: `lib/target.py`.")
    v1 = validate_task(task, project)
    write_claims_verdict_to_task(task, v1)
    v2 = validate_task(task, project)
    write_claims_verdict_to_task(task, v2)
    content = task.read_text()
    assert content.count("## Recommendation Verdict") == 1
    assert v2.scan_id in content
    assert v1.scan_id not in content


def test_write_never_touches_recommendation_decision_or_acs(project):
    task = make_inception(project, "GO. Evidence: `lib/target.py`, `lib/missing.py`.")
    before = task.read_text()
    rec_before = re.search(
        r"^## Recommendation\s*\n(.*?)(?=^##\s|\Z)", before, re.M | re.S
    ).group(1)
    dec_before = re.search(
        r"^## Decision\s*\n(.*?)(?=^##\s|\Z)", before, re.M | re.S
    ).group(1)
    acs_before = re.findall(r"^- \[.\].*$", before, re.M)

    v = validate_task(task, project)
    write_claims_verdict_to_task(task, v)

    after = task.read_text()
    rec_after = re.search(
        r"^## Recommendation\s*\n(.*?)(?=^##\s|\Z)", after, re.M | re.S
    ).group(1)
    dec_after = re.search(
        r"^## Decision\s*\n(.*?)(?=^##\s|\Z)", after, re.M | re.S
    ).group(1)
    acs_after = re.findall(r"^- \[.\].*$", after, re.M)

    assert rec_after == rec_before
    # Decision was the EOF section before the append; the verdict block's
    # separator newline lands after it, so compare content not trailing ws.
    assert dec_after.rstrip() == dec_before.rstrip()
    assert acs_after == acs_before


def test_refuses_to_mutate_completed_task(project):
    p = project / ".tasks" / "completed" / "T-9101-fixture-inception.md"
    p.write_text(
        "---\nid: T-9101\nworkflow_type: inception\n---\n\n"
        "## Recommendation\n\nGO. `lib/target.py`.\n"
    )
    before = p.read_text()
    v = validate_task(p, project)
    with pytest.raises(ValueError):
        write_claims_verdict_to_task(p, v)
    assert p.read_text() == before


def test_rendered_block_has_table_and_overall(project):
    task = make_inception(project, "GO. Evidence: `lib/target.py`, `lib/missing.py`.")
    v = validate_task(task, project)
    md = render_claims_verdict_md(v)
    assert "## Recommendation Verdict" in md
    assert "**Overall:** CONTRADICTED" in md
    assert "| `lib/target.py` | file | ✓ pass |" in md
    assert "✗ fail" in md
