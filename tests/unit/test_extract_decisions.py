"""T-3015 — decision extraction from a block-structured task file.

Every verdict here is pinned against a DISCRIMINATING fixture: one that produces
the opposite verdict. PL-206 — a control that can fail is still worthless if its
stimulus was built so it never would. The unfilled-template leg is first because
it is the state 77% of real tasks are in, and it is the state that was never
tested; the filled-template leg exists so "extracts nothing" cannot pass as
success.
"""

import importlib.util
import pathlib

import pytest
import yaml

_MODULE_PATH = (
    pathlib.Path(__file__).resolve().parents[2]
    / "agents"
    / "context"
    / "lib"
    / "extract_decisions.py"
)
_spec = importlib.util.spec_from_file_location("extract_decisions", _MODULE_PATH)
ed = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ed)


# The template's Decisions block, verbatim from .tasks/templates/default.md.
UNFILLED = """# T-1: a task

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates
"""

FILLED = """# T-2: a task

## Decisions

### 2026-08-15 — how to parse the section
- **Chose:** strip comment spans before parsing
- **Why:** the placeholders are gone because they were never content
- **Rejected:** a placeholder-regex filter, which removes the tell

## Updates
"""


def load(text):
    return ed.parse(text)


def test_unfilled_template_yields_no_decisions():
    """The modal case, and the one that was never tested."""
    assert load(UNFILLED) == []


def test_filled_section_still_yields_its_decision():
    """Discriminating counterpart: 'extracts nothing' must not pass as success."""
    entries = load(FILLED)
    assert len(entries) == 1
    assert entries[0]["topic"] == "2026-08-15 — how to parse the section"
    assert entries[0]["chose"] == "strip comment spans before parsing"


def test_placeholder_text_is_absent_because_the_span_was_stripped():
    """Not because a regex matched the words — the distinction 832 drew."""
    assert "what was decided" not in ed.to_yaml(load(UNFILLED))


def test_a_real_decision_whose_prose_mentions_the_template_words_survives():
    """The regex fix would have eaten this. The span fix must not."""
    text = """## Decisions

### 2026-08-15 — naming
- **Chose:** reject the phrase '[what was decided]' from generated output
- **Why:** it reads as real content

## Updates
"""
    entries = load(text)
    assert len(entries) == 1
    assert "what was decided" in entries[0]["chose"]


def test_multi_line_value_is_captured_whole():
    """Symptom 2 — the one with no tell."""
    text = """## Decisions

### 2026-08-15 — scope
- **Chose:** count duplicate element ids over BPMN-namespace elements only,
  and report the rest separately so the caller can tell them apart
- **Why:** short

## Updates
"""
    entries = load(text)
    chose = entries[0]["chose"]
    assert chose.endswith("tell them apart"), chose
    assert "BPMN-namespace" in chose


def test_single_line_value_is_not_glued_to_the_next_field():
    """Discriminating counterpart to the fold: folding must stop at a new label."""
    entries = load(FILLED)
    assert entries[0]["chose"] == "strip comment spans before parsing"
    assert "Why" not in entries[0]["chose"]


def test_blank_line_closes_a_value():
    text = """## Decisions

### 2026-08-15 — t
- **Chose:** first

trailing prose that is not part of the value

## Updates
"""
    assert load(text)[0]["chose"] == "first"


def test_no_silent_cap():
    """Symptom 3. 25 entries in, 25 entries out — the old head -20 dropped 5."""
    body = "## Decisions\n\n"
    for i in range(25):
        body += f"### 2026-08-15 — topic {i}\n- **Chose:** choice {i}\n\n"
    body += "## Updates\n"
    entries = load(body)
    assert len(entries) == 25
    assert entries[24]["chose"] == "choice 24"


@pytest.mark.parametrize(
    "value",
    [
        "it's got an apostrophe",
        "it has `backticks` in it",
        'it has "double quotes" in it',
        "it has a backslash \\ in it",
        "it's got 'both' \"kinds\" and `ticks`",
    ],
)
def test_emitted_yaml_parses_with_hostile_values(value):
    """L-392 / L-385 / T-1871 regression guard."""
    text = f"## Decisions\n\n### 2026-08-15 — t\n- **Chose:** {value}\n\n## Updates\n"
    parsed = yaml.safe_load("decisions:\n" + ed.to_yaml(load(text)))
    assert parsed["decisions"][0]["chose"] == value


def test_all_three_fields_are_emitted():
    entries = load(FILLED)
    body = yaml.safe_load("decisions:\n" + ed.to_yaml(entries))["decisions"][0]
    assert body["chose"] and body["rationale"]
    assert body["alternatives_rejected"] == [
        "a placeholder-regex filter, which removes the tell"
    ]


def test_decision_singular_section_is_not_swept_in():
    """`## Decision` follows `## Decisions` in the template; only one is ours."""
    text = """## Decisions

### 2026-08-15 — mine
- **Chose:** keep

## Decision

### 2026-08-15 — not mine
- **Chose:** ignore

## Updates
"""
    entries = load(text)
    assert len(entries) == 1
    assert entries[0]["topic"].endswith("mine")
