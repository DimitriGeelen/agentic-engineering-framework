"""T-3061 — the satisfied-but-unclosed detector.

The rail this backs reports candidates for close and never closes anything, so
the failure that matters is not "misses one task". It is either of:

  * reporting a task that is NOT finished, which invites an unevidenced close —
    the exact thing CLAUDE.md's Human Task Completion Rule forbids; or
  * reporting nothing at all, because a zero here is indistinguishable from a
    healthy corpus and nothing would ever prompt anyone to look.

The second is the likelier bug and the harder one to notice, which is why the
template-comment fixtures below are load-bearing rather than edge cases: the
shipped task template contains unticked example ACs inside HTML comments, and
counting them silences the detector across every task in the repo at once.
"""

import importlib.util

from pathlib import Path

import pytest

_SPEC = importlib.util.spec_from_file_location(
    "task_satisfaction",
    Path(__file__).resolve().parents[2] / "lib" / "task_satisfaction.py",
)
ts = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(ts)


@pytest.fixture
def tasks_dir(tmp_path):
    d = tmp_path / ".tasks" / "active"
    d.mkdir(parents=True)
    return d


# Interpolated AC/Verification bodies are multi-line with no indent of their
# own, so this template must not be indented — dedent() would find a common
# prefix of "" and silently no-op, shipping a fixture whose `status:` line is
# indented and therefore invisible to the frontmatter reader. That failure is
# not visible from the negative tests: every one of them passes when the scan
# returns nothing.
_TASK_TEMPLATE = """\
---
id: {task_id}
name: "{name}"
status: {status}
workflow_type: build
---

# {task_id}

## Acceptance Criteria

{acs}

## Verification

{verification}

## Updates
"""


def write_task(d: Path, task_id: str, *, status="started-work", acs="",
               verification="", name="a task") -> Path:
    p = d / f"{task_id}-fixture.md"
    p.write_text(_TASK_TEMPLATE.format(
        task_id=task_id, name=name, status=status,
        acs=acs, verification=verification,
    ))
    return p


# The template's own example ACs, verbatim in shape: unticked, inside a comment.
TEMPLATE_COMMENT = """\
### Agent
- [x] real work, done

### Human
<!-- Criteria requiring human verification. Remove if all agent-verifiable.
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:** 1. Open the page
       - [ ] [REVIEWER] Block message names both bypass mechanisms
-->
"""


# ---------------------------------------------------------------- qualifying

def test_all_agent_acs_ticked_qualifies(tasks_dir):
    write_task(tasks_dir, "T-9001", acs="### Agent\n- [x] one\n- [x] two\n")
    rows = ts.scan(tasks_dir)
    assert [r["id"] for r in rows] == ["T-9001"]
    assert rows[0]["agent_acs"] == 2


def test_no_subsection_headers_treats_all_as_agent(tasks_dir):
    # Pre-T-193 shape. P-010 gates on these the same way, so the detector must.
    write_task(tasks_dir, "T-9002", acs="- [x] one\n- [x] two\n")
    assert [r["id"] for r in ts.scan(tasks_dir)] == ["T-9002"]


def test_template_example_acs_in_comments_do_not_suppress(tasks_dir):
    """The load-bearing case. If comment stripping regresses, this task stops
    qualifying — and so does every other task in the repo, because they all
    carry the same template block. The result is a silent, total no-op."""
    write_task(tasks_dir, "T-9003", acs=TEMPLATE_COMMENT)
    assert [r["id"] for r in ts.scan(tasks_dir)] == ["T-9003"]


def test_issues_status_also_counts(tasks_dir):
    write_task(tasks_dir, "T-9004", status="issues", acs="### Agent\n- [x] done\n")
    assert [r["id"] for r in ts.scan(tasks_dir)] == ["T-9004"]


# ------------------------------------------------------------ NOT qualifying

def test_unticked_agent_ac_does_not_qualify(tasks_dir):
    write_task(tasks_dir, "T-9010", acs="### Agent\n- [x] one\n- [ ] two\n")
    assert ts.scan(tasks_dir) == []


def test_unticked_human_ac_does_not_qualify(tasks_dir):
    # Partial-complete is the CORRECT state — the operator owns it. Reporting
    # it as ready-to-close is the failure that would cause real harm.
    write_task(
        tasks_dir, "T-9011",
        acs="### Agent\n- [x] done\n\n### Human\n- [ ] [REVIEW] check it\n",
    )
    assert ts.scan(tasks_dir) == []


def test_no_acs_at_all_does_not_qualify(tasks_dir):
    # Nothing was ever claimed, so there is nothing to be satisfied.
    write_task(tasks_dir, "T-9012", acs="")
    assert ts.scan(tasks_dir) == []


def test_captured_status_does_not_qualify(tasks_dir):
    # Nobody claimed to be finishing it; ticked boxes on a captured task are
    # not the hygiene gap this rail is about.
    write_task(tasks_dir, "T-9013", status="captured", acs="### Agent\n- [x] done\n")
    assert ts.scan(tasks_dir) == []


def test_only_template_comment_acs_does_not_qualify(tasks_dir):
    # Everything real is commented out, so after stripping there are zero ACs.
    write_task(tasks_dir, "T-9014", acs="### Agent\n<!--\n- [ ] first\n- [ ] second\n-->\n")
    assert ts.scan(tasks_dir) == []


# ------------------------------------------------------- gated vs ungated

def test_real_verification_marks_task_gated(tasks_dir):
    write_task(tasks_dir, "T-9020", acs="### Agent\n- [x] done\n",
               verification="bats tests/unit/x.bats\n")
    assert ts.scan(tasks_dir)[0]["gated"] is True


def test_comment_only_verification_is_ungated(tasks_dir):
    """The shipped Verification template is ~60 lines of guidance and zero
    commands, so 'the section exists' answers nothing. An ungated task's ticked
    boxes are the only evidence it has — that is why the rail separates them."""
    write_task(tasks_dir, "T-9021", acs="### Agent\n- [x] done\n",
               verification="# just guidance\n#\n# more guidance\n")
    assert ts.scan(tasks_dir)[0]["gated"] is False


# ------------------------------------------------------------------ details

def test_unterminated_comment_swallows_remainder(tasks_dir):
    # Matches how a Markdown renderer behaves; the alternative is treating
    # commented-out ACs as live.
    write_task(tasks_dir, "T-9030", acs="### Agent\n- [x] done\n<!-- - [ ] stray\n")
    assert [r["id"] for r in ts.scan(tasks_dir)] == ["T-9030"]


def test_missing_directory_is_survivable(tmp_path):
    assert ts.scan(tmp_path / "nope") == []


def test_results_are_sorted_by_id(tasks_dir):
    for tid in ("T-9042", "T-9041", "T-9043"):
        write_task(tasks_dir, tid, acs="### Agent\n- [x] done\n")
    assert [r["id"] for r in ts.scan(tasks_dir)] == ["T-9041", "T-9042", "T-9043"]


def test_live_corpus_is_neither_empty_nor_everything():
    """Fixtures prove the mechanism; only the real corpus proves the thresholds.

    Both bounds fail in opposite directions and neither is visible in the code:
    zero means the detector shipped as a silent no-op, and near-total means it
    is matching something structural rather than the state we care about.
    """
    root = Path(__file__).resolve().parents[2]
    active = root / ".tasks" / "active"
    if not active.is_dir():
        pytest.skip("no active corpus")
    total = len(list(active.glob("T-*.md")))
    if total < 50:
        pytest.skip(f"corpus too small to bound: {total}")
    rows = ts.scan(active)
    assert 0 < len(rows) < total * 0.5, f"{len(rows)} of {total}"
