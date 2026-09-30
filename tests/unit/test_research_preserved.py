"""T-3569 — C-001 counts research preserved in the task file itself.

Two failures matter, and they pull in opposite directions:

  * a false finding: an inception that wrote its research into its own
    Problem Statement / Findings / Dialogue Log is reported as having none
    (832 measured 3/3 of their live findings as this);
  * universal coverage: a predicate that counts Recommendation, Decision or
    Updates prose, or template scaffolding, passes every inception and the
    rail goes silent. That one is invisible, so the filled-in-template fixture
    below is load-bearing, not an edge case.
"""

import importlib.util
import json
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
FIX = ROOT / "tests" / "fixtures" / "t3569"


def _load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


rp = _load("research_preserved", ROOT / "lib" / "research_preserved.py")
COMPLETED_SCAN = ROOT / "agents" / "audit" / "completed-task-scan.py"
ACTIVE_SCAN = ROOT / "agents" / "audit" / "active-task-scan.py"

FILLED = (FIX / "filled-template.md").read_text()
SHORT = (FIX / "short-hypothesis.md").read_text()


# ── the predicate ────────────────────────────────────────────────────────────

def test_filled_in_template_with_empty_sections_is_flagged():
    assert rp.research_prose_chars(FILLED) == 0
    assert rp.research_preserved(FILLED) is False


def test_genuine_short_hypothesis_passes():
    assert rp.research_preserved(SHORT) is True


def test_shipped_inception_template_measures_zero():
    tpl = (ROOT / ".tasks" / "templates" / "inception.md").read_text()
    assert rp.research_prose_chars(tpl) == 0


@pytest.mark.parametrize("heading", [
    "Acceptance Criteria", "Verification", "Updates", "Recommendation",
    "Decision", "Decisions", "Go/No-Go Criteria",
])
def test_excluded_sections_never_count(heading):
    text = f"## {heading}\n\n" + ("substantive prose " * 60) + "\n"
    assert rp.research_prose_chars(text) == 0


@pytest.mark.parametrize("heading", [
    "Problem Statement", "Open Questions", "Exploration Plan",
    "Technical Constraints", "Hypothesis", "Hypotheses to test", "Findings",
    "Evidence", "Dialogue Log", "Scope Fence", "Spike 1: probe", "Prior Art",
    "Assumptions", "Candidate Answers", "Investigation Findings",
])
def test_research_sections_count(heading):
    text = f"## {heading}\n\n" + ("x" * 450) + "\n"
    assert rp.research_preserved(text)


def test_comments_and_placeholders_are_stripped():
    text = ("## Findings\n\n<!-- " + "c" * 900 + " -->\n"
            + "[Describe the findings here in detail]\n" * 30)
    assert rp.research_prose_chars(text) == 0


def test_markdown_link_text_is_kept():
    assert rp.research_prose_chars("## Findings\n\n[see here](x)\n") > len("(x)")


# ── teeth: one definition, both scanners import it ───────────────────────────

@pytest.mark.parametrize("scanner", [COMPLETED_SCAN, ACTIVE_SCAN])
def test_scanner_imports_predicate_and_carries_no_section_list(scanner):
    src = scanner.read_text()
    assert "from research_preserved import" in src
    lowered = src.lower()
    for name in ("dialogue log", "prior art", "exploration plan", "technical constraints"):
        assert name not in lowered, f"{scanner.name} restates section '{name}'"


# ── scanner integration ──────────────────────────────────────────────────────

def _task(tid, body_file, workflow="inception", status="work-completed"):
    body = (FIX / body_file).read_text().split("---\n", 2)[2]
    return (f"---\nid: {tid}\nname: \"x\"\ndescription: x\nstatus: {status}\n"
            f"workflow_type: {workflow}\nowner: agent\ncreated: 2026-09-30T00:00:00Z\n"
            f"last_update: 2026-09-30T00:00:00Z\n---\n{body}")


def _run(scanner, *args):
    out = subprocess.run([sys.executable, str(scanner), *map(str, args)],
                         capture_output=True, text=True, check=True)
    return json.loads(out.stdout), out.stderr


@pytest.fixture
def corpus(tmp_path):
    for sub in ("tasks/completed", "tasks/active", "episodic", "reports"):
        (tmp_path / sub).mkdir(parents=True)
    c = tmp_path / "tasks" / "completed"
    (c / "T-9001-a.md").write_text(_task("T-9001", "filled-template.md"))
    (c / "T-9002-b.md").write_text(_task("T-9002", "short-hypothesis.md"))
    return tmp_path


def test_completed_scan_counts_in_task_record(corpus):
    r, _ = _run(COMPLETED_SCAN, corpus / "tasks", corpus / "episodic", corpus / "reports")
    assert r["missing_research"] == ["T-9001"]
    assert r["research_in_task_record"] == ["T-9002"]
    assert r["stats"]["inception_count"] == 2  # coverage does not shrink
    assert r["research_predicate_note"] == ""


def test_active_scan_in_task_record_is_not_missing_nor_unreferenced(corpus):
    a = corpus / "tasks" / "active"
    (a / "T-9003-c.md").write_text(_task("T-9003", "short-hypothesis.md", status="started-work"))
    (a / "T-9004-d.md").write_text(_task("T-9004", "filled-template.md", status="started-work"))
    # A report exists for T-9003 but the task never links it: the in-task
    # record is the research, so this is not the "unreferenced" gap.
    (corpus / "reports" / "T-9003-notes.md").write_text("x")
    r, _ = _run(ACTIVE_SCAN, corpus / "tasks", corpus / "reports")
    issues = {(i["id"], i["type"]) for i in r["research"]["issues"]}
    assert issues == {("T-9004", "missing")}
    assert r["research"]["inception_active"] == 2


def _isolated_scanner(tmp_path, scanner, with_predicate):
    """Copy a scanner into a fake framework root whose lib/ may lack the module."""
    root = tmp_path / "fw"
    (root / "agents" / "audit").mkdir(parents=True)
    (root / "lib").mkdir()
    shutil.copy(scanner, root / "agents" / "audit" / scanner.name)
    shutil.copy(ROOT / "lib" / "task_satisfaction.py", root / "lib")
    if with_predicate:
        shutil.copy(ROOT / "lib" / "research_preserved.py", root / "lib")
    return root / "agents" / "audit" / scanner.name


def test_completed_scan_import_error_falls_back_to_location_only(corpus, tmp_path):
    scanner = _isolated_scanner(tmp_path, COMPLETED_SCAN, with_predicate=False)
    r, err = _run(scanner, corpus / "tasks", corpus / "episodic", corpus / "reports")
    # Never universal coverage: without the predicate, both are flagged.
    assert sorted(r["missing_research"]) == ["T-9001", "T-9002"]
    assert "unavailable" in r["research_predicate_note"]
    assert "unavailable" in err


def test_active_scan_import_error_falls_back_to_location_only(corpus, tmp_path):
    (corpus / "tasks" / "active" / "T-9003-c.md").write_text(
        _task("T-9003", "short-hypothesis.md", status="started-work"))
    scanner = _isolated_scanner(tmp_path, ACTIVE_SCAN, with_predicate=False)
    r, err = _run(scanner, corpus / "tasks", corpus / "reports")
    assert {(i["id"], i["type"]) for i in r["research"]["issues"]} == {("T-9003", "missing")}
    assert "unavailable" in r["research"]["predicate_note"]
    assert "unavailable" in err
