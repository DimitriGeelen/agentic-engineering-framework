#!/usr/bin/env python3
"""T-3445 — the delegation classifier puts each criterion in exactly one class.

Two fixtures per class (AC 1), plus the ambiguous fixture that must land on the
human side. The tie-break is the point of the whole module: a criterion the
classifier cannot read is the operator's, not the agent's.
"""
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from lib.delegation import (  # noqa: E402
    AGENT_SELF,
    CARVE_OUTS,
    CLASS_TO_DELEGATION,
    OPERATOR_ONLY,
    REVIEWER_CLOSEABLE,
    classify,
    classify_task,
    human_criteria,
    parse_criteria,
    surface_scan,
    surface_verdict,
)


def crit(title, *body, subhead="Human", ticked=False):
    """Build one Criterion the way parse_criteria would, from a title + body."""
    lines = [f"- [{'x' if ticked else ' '}] {title}"] + list(body)
    text = (
        "---\nid: T-9999\nworkflow_type: build\nowner: human\n---\n\n"
        "## Acceptance Criteria\n\n### Agent\n\n### Human\n" + "\n".join(lines) + "\n\n## Verification\n"
    )
    got = human_criteria(text)
    assert len(got) == 1, f"fixture parsed to {len(got)} criteria, not 1"
    return got[0]


STEPS = "  **Steps:**\n  1. Run `bin/fw doctor`"
IFNOT = "  **If not:** re-run and read the first failure"


# ── deterministic ────────────────────────────────────────────────────────────

DETERMINISTIC = [
    crit(
        "[REVIEW] Doctor reports the new key",
        STEPS,
        "  **Expected:** `grep -q FW_DELEGATION_SURFACE_WARN` matches and exit code is 0",
        IFNOT,
    ),
    crit(
        "[RUBBER-STAMP] Registry entry present",
        "  **Steps:**\n  1. Open the registry file",
        "  **Expected:** the entry is listed",
        IFNOT,
    ),
]


@pytest.mark.parametrize("c", DETERMINISTIC)
def test_deterministic(c):
    cl = classify(c)
    assert cl.cls == "deterministic", cl
    assert cl.delegation_class == REVIEWER_CLOSEABLE
    assert cl.convertible


# ── taste ────────────────────────────────────────────────────────────────────

TASTE = [
    crit(
        "[REVIEW] Handover summary reads clearly",
        STEPS,
        "  **Expected:** the summary reads as a peer briefing, not a status dump",
        IFNOT,
    ),
    crit(
        "[REVIEW] Section tone matches the surrounding voice",
        STEPS,
        "  **Expected:** paragraph lands without re-reading",
        IFNOT,
    ),
]


@pytest.mark.parametrize("c", TASTE)
def test_taste(c):
    cl = classify(c)
    assert cl.cls == "taste", cl
    assert cl.delegation_class == OPERATOR_ONLY
    assert not cl.convertible


# ── inception-decision ───────────────────────────────────────────────────────


def test_inception_decision_from_workflow_type():
    """Task-level: every open criterion on an inception is the operator's."""
    c = crit(
        "[REVIEW] Confirm the candidate",
        STEPS,
        "  **Expected:** exit code 0",
        IFNOT,
    )
    cl = classify(c, workflow_type="inception")
    assert cl.cls == "inception-decision", cl
    assert cl.delegation_class == OPERATOR_ONLY


def test_inception_decision_from_criterion_text():
    """Criterion-level: go/no-go phrasing on a build task still refuses."""
    c = crit(
        "[REVIEW] Record the outcome",
        STEPS,
        "  **Expected:** the go/no-go is recorded with a rationale",
        IFNOT,
    )
    cl = classify(c, workflow_type="build")
    assert cl.cls == "inception-decision", cl


# ── act-in-the-world ─────────────────────────────────────────────────────────

ACT = [
    crit(
        "[REVIEW] Article is live",
        "  **Steps:**\n  1. Publish the draft",
        "  **Expected:** the page returns 200",
        IFNOT,
    ),
    crit(
        "[REVIEW] Branch is on the remote",
        "  **Steps:**\n  1. Run `git push origin bleeding-edge`",
        "  **Expected:** exit code 0",
        IFNOT,
    ),
]


@pytest.mark.parametrize("c", ACT)
def test_act_in_the_world(c):
    cl = classify(c)
    assert cl.cls == "act-in-the-world", cl
    assert cl.delegation_class == OPERATOR_ONLY


def test_act_in_the_world_outranks_deterministic():
    """A grep-able Expected does not make an irreversible action delegable."""
    c = ACT[1]
    assert classify(c).cls == "act-in-the-world"


# ── tier0-or-bypass ──────────────────────────────────────────────────────────

TIER0 = [
    crit(
        "[REVIEW] Approval is recorded",
        "  **Steps:**\n  1. Run `bin/fw tier0 approve`",
        "  **Expected:** the queue is empty",
        IFNOT,
    ),
    crit(
        "[REVIEW] Close is accepted",
        "  **Steps:**\n  1. Re-run the close with --force",
        "  **Expected:** exit code 0",
        IFNOT,
    ),
]


@pytest.mark.parametrize("c", TIER0)
def test_tier0_or_bypass(c):
    cl = classify(c)
    assert cl.cls == "tier0-or-bypass", cl
    assert cl.delegation_class == OPERATOR_ONLY


# ── sovereignty-field ────────────────────────────────────────────────────────

SOVEREIGN = [
    crit(
        "[REVIEW] Scores are confirmed",
        "  **Steps:**\n  1. Run `bin/fw bvp confirm T-1234`",
        "  **Expected:** exit code 0",
        IFNOT,
    ),
    crit(
        "[REVIEW] The arc is settled",
        "  **Steps:**\n  1. Open the arc page",
        "  **Expected:** arc close is recorded with a demo artefact",
        IFNOT,
    ),
]


@pytest.mark.parametrize("c", SOVEREIGN)
def test_sovereignty_field(c):
    cl = classify(c)
    assert cl.cls == "sovereignty-field", cl
    assert cl.delegation_class == OPERATOR_ONLY


# ── render-surface ───────────────────────────────────────────────────────────

RENDER = [
    crit(
        "[REVIEW] Table columns line up",
        STEPS,
        "  **Expected:** exit code 0",
        IFNOT,
    ),
    crit(
        "[RUBBER-STAMP] Page is reachable",
        STEPS,
        "  **Expected:** the page returns 200",
        IFNOT,
    ),
]


@pytest.mark.parametrize("c", RENDER)
def test_render_surface_outranks_everything(c):
    """Even an author-declared mechanical criterion stays human on a render surface."""
    cl = classify(c, render_surface=True)
    assert cl.cls == "render-surface", cl
    assert cl.delegation_class == OPERATOR_ONLY
    # And the same criterion off a render surface is NOT render-surface — the
    # control leg, so this test measures the flag rather than the fixture text.
    assert classify(c, render_surface=False).cls != "render-surface"


# ── agent-self ───────────────────────────────────────────────────────────────

AGENT = [
    crit(
        "[REVIEW] Refusal is usable",
        STEPS,
        "  **Expected:** the agent reads the refusal and knows which flag to pass",
        IFNOT,
    ),
    crit(
        "[REVIEW] Message helps the tripping agent",
        STEPS,
        "  **Expected:** a tripping agent can recover without asking",
        IFNOT,
    ),
]


@pytest.mark.parametrize("c", AGENT)
def test_agent_self(c):
    cl = classify(c)
    assert cl.cls == "agent-self", cl
    assert cl.delegation_class == AGENT_SELF
    # AGENT-SELF is a routing defect, not a delegation: the verb never converts it.
    assert not cl.convertible


# ── the tie-break ────────────────────────────────────────────────────────────


def test_ambiguous_resolves_to_the_human_side():
    """No Expected clause, no vocabulary hit — the operator keeps it.

    This is the fixture the whole module is calibrated against. A criterion the
    classifier cannot read must not become the agent's by default.
    """
    c = crit("[REVIEW] The change is right", "  **Steps:**\n  1. Look at it")
    cl = classify(c)
    assert cl.cls == "unclassified", cl
    assert cl.delegation_class == OPERATOR_ONLY
    assert not cl.convertible


def test_expected_with_no_mechanical_signal_is_not_deterministic():
    c = crit(
        "[REVIEW] The change is right",
        STEPS,
        "  **Expected:** it is right",
        IFNOT,
    )
    assert classify(c).delegation_class == OPERATOR_ONLY


def test_strategic_marker_suppresses_deterministic():
    """`decide`/`approve` in the title is a human verb whatever Expected says."""
    c = crit(
        "[REVIEW] Approve the wording",
        STEPS,
        "  **Expected:** exit code 0",
        IFNOT,
    )
    assert classify(c).delegation_class == OPERATOR_ONLY


# ── taxonomy invariants ──────────────────────────────────────────────────────


def test_every_class_maps_to_exactly_one_delegation_class():
    assert set(CLASS_TO_DELEGATION.values()) == {
        REVIEWER_CLOSEABLE,
        AGENT_SELF,
        OPERATOR_ONLY,
    }
    for c in CARVE_OUTS:
        assert CLASS_TO_DELEGATION[c] == OPERATOR_ONLY, c


def test_only_deterministic_is_convertible():
    convertible = [k for k in CLASS_TO_DELEGATION if classify_convertible(k)]
    assert convertible == ["deterministic"]


def classify_convertible(cls_name):
    from lib.delegation import CONVERTIBLE_CLASSES

    return cls_name in CONVERTIBLE_CLASSES


# ── parsing ──────────────────────────────────────────────────────────────────


def test_commented_template_examples_are_not_criteria():
    """OBS-047: the shipped template's Human block is one big HTML comment."""
    text = (
        "---\nid: T-1\n---\n\n## Acceptance Criteria\n\n### Agent\n"
        "- [ ] real agent criterion\n\n### Human\n"
        "<!--\n- [ ] [REVIEWER] example from the template\n- [ ] [REVIEW] another example\n-->\n"
        "\n## Verification\n"
    )
    assert human_criteria(text) == []
    assert [c.title for c in parse_criteria(text)] == ["real agent criterion"]


def test_indices_restart_per_subhead():
    text = (
        "---\nid: T-1\n---\n\n## Acceptance Criteria\n\n### Agent\n"
        "- [ ] a1\n- [ ] a2\n\n### Human\n- [ ] h1\n- [ ] h2\n\n## Verification\n"
    )
    got = {(c.subhead, c.index): c.title for c in parse_criteria(text)}
    assert got[("Agent", 1)] == "a1"
    assert got[("Human", 1)] == "h1"
    assert got[("Human", 2)] == "h2"


def test_ticked_criteria_are_excluded_from_the_report(tmp_path):
    f = tmp_path / "T-1-x.md"
    f.write_text(
        "---\nid: T-1\nworkflow_type: build\nowner: human\n---\n\n"
        "## Acceptance Criteria\n\n### Agent\n\n### Human\n"
        "- [x] [REVIEW] already answered\n- [ ] [REVIEW] still open\n\n## Verification\n"
    )
    tc = classify_task(f)
    assert [c.title for c, _ in tc.rows] == ["[REVIEW] still open"]


# ── surface report ───────────────────────────────────────────────────────────


def test_surface_verdict_warns_only_on_the_conjunction():
    warn = {
        "by_delegation": {REVIEWER_CLOSEABLE: 0, AGENT_SELF: 0, OPERATOR_ONLY: 51},
        "tasks_with_open_human_criteria": 40,
    }
    assert surface_verdict(warn, 50)[0] == "WARN"
    # Same operator-only count, one delegable criterion → not the signal.
    ok = {
        "by_delegation": {REVIEWER_CLOSEABLE: 1, AGENT_SELF: 0, OPERATOR_ONLY: 51},
        "tasks_with_open_human_criteria": 40,
    }
    assert surface_verdict(ok, 50)[0] == "OK"
    # Zero delegable but under the threshold → not the signal either.
    small = {
        "by_delegation": {REVIEWER_CLOSEABLE: 0, AGENT_SELF: 0, OPERATOR_ONLY: 50},
        "tasks_with_open_human_criteria": 3,
    }
    assert surface_verdict(small, 50)[0] == "OK"


def test_surface_scan_counts_sum(tmp_path):
    d = tmp_path / ".tasks" / "active"
    d.mkdir(parents=True)
    (d / "T-1-a.md").write_text(
        "---\nid: T-1\nworkflow_type: build\nowner: human\n---\n\n"
        "## Acceptance Criteria\n\n### Agent\n\n### Human\n"
        "- [ ] [REVIEW] Doctor reports it\n  **Expected:** exit code 0\n"
        "- [ ] [REVIEW] It reads clearly\n  **Expected:** the prose reads clearly\n"
        "\n## Verification\n"
    )
    rep = surface_scan(tmp_path, framework_root=ROOT)
    assert rep["tasks_scanned"] == 1
    assert rep["open_criteria"] == 2
    assert sum(rep["by_delegation"].values()) == rep["open_criteria"]
    assert sum(rep["by_class"].values()) == rep["open_criteria"]
    assert rep["by_delegation"][REVIEWER_CLOSEABLE] == 1
    assert rep["delegable_tasks"] == ["T-1"]
