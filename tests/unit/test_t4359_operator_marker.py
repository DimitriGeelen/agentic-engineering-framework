#!/usr/bin/env python3
"""T-4359 (GitHub #102) — the risk carve-outs were found only through English regexes,
so a Human criterion written in another language matched none of them and went to an
AI reviewer. An `[OPERATOR]` tag at the start of the criterion pins it OPERATOR-ONLY
before any keyword test, in any language; English routing is unchanged."""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from lib.delegation import (  # noqa: E402
    CLASS_TO_DELEGATION,
    OPERATOR_ONLY,
    REVIEWER_JUDGES,
    classify,
    human_criteria,
)


def crit(title, *body):
    text = (
        "---\nid: T-9999\nworkflow_type: build\nowner: human\n---\n\n"
        "## Acceptance Criteria\n\n### Agent\n\n### Human\n"
        + "\n".join([f"- [ ] {title}"] + list(body)) + "\n\n## Verification\n"
    )
    got = human_criteria(text)
    assert len(got) == 1
    return got[0]


DUTCH = ("  **Stappen:**\n  1. Publiceren naar productie",
         "  **Verwacht:** de nieuwe versie staat live")


def test_the_gap_unmarked_dutch_criterion_goes_to_a_reviewer():
    # The defect, pinned: without the tag a non-English irreversible act is not
    # recognised. This documents why the tag exists; it is not the desired state.
    cl = classify(crit("Release gepubliceerd naar productie", *DUTCH))
    assert cl.delegation_class == REVIEWER_JUDGES


def test_operator_tag_pins_a_dutch_criterion_operator_only():
    cl = classify(crit("[OPERATOR] Release gepubliceerd naar productie", *DUTCH))
    assert cl.cls == "operator-marked", cl
    assert cl.delegation_class == OPERATOR_ONLY


def test_operator_tag_beside_another_prefix():
    cl = classify(crit("[REVIEW] [OPERATOR] Veröffentlichung freigeben", "  **Schritte:** 1. freigeben"))
    assert cl.delegation_class == OPERATOR_ONLY


def test_operator_tag_outranks_every_other_signal():
    # A criterion that would otherwise be deterministic (a shell check) still goes to the
    # operator when the author tagged it: the tag is the author's explicit ruling.
    cl = classify(crit("[OPERATOR] doctor is clean",
                       "  **Steps:**\n  1. Run `bin/fw doctor`", "  **Expected:** exit code 0"))
    assert cl.delegation_class == OPERATOR_ONLY


def test_the_tag_must_lead_the_criterion():
    # Mentioning the word inside the text is not a tag.
    cl = classify(crit("Check the [OPERATOR] wording in the docs", *DUTCH))
    assert cl.cls != "operator-marked"


def test_class_is_routed_operator_only_in_the_one_table():
    assert CLASS_TO_DELEGATION["operator-marked"] == OPERATOR_ONLY
