"""T-3897: every queued approval says where it came from.

Origin: T-3659 — an unratified external proposal, pasted by the operator, sat
in /approvals looking exactly like the operator's own request; GO then errored.
The badge answers "is this mine?" before the operator decides.
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "lib"))

from task_origin import task_origin  # noqa: E402


def test_recorded_origin_beats_inference():
    fm = {"name": "pickup from 010-termlink", "description": "",
          "origin": {"kind": "operator", "source": "", "ref": "2026-10-04"}}
    o = task_origin(fm)
    assert o["kind"] == "operator" and o["inferred"] is False
    assert o["label"] == "from you"


def test_recorded_origin_string_form_parses():
    o = task_origin({"origin": "peer:ring20-dashboard:711087b1"})
    assert (o["kind"], o["source"], o["ref"]) == ("peer", "ring20-dashboard", "711087b1")
    assert o["label"] == "peer request: ring20-dashboard"


def test_inferred_origin_is_labelled_inferred():
    o = task_origin({"name": "x", "description": "pickup from 010-termlink msg 7881482d"})
    assert o["kind"] == "pickup" and o["source"] == "010-termlink" and o["inferred"] is True
    assert o["label"].endswith("(inferred)")


def test_no_evidence_is_unknown_never_operator_or_agent():
    o = task_origin({"name": "Refactor the thing", "description": "make it nicer"})
    assert o["kind"] == "unknown"
    assert o["label"] == "origin unknown"


def test_external_proposal_pasted_by_operator_is_not_from_you():
    """The T-3659 regression: an operator date in the text must not outrank
    an explicit external-proposal signal."""
    body = ("## Recommendation\n\n**Evidence:**\n- The source is the external proposal "
            "\"P-01\" (2026-09-29, unratified), pasted by the operator on 2026-10-01.\n")
    o = task_origin({"name": "P-01 Zero-to-running", "description": ""}, body)
    assert o["kind"] == "proposal", o


def test_unknown_recorded_kind_falls_back_to_inference_not_trust():
    o = task_origin({"name": "n", "description": "d", "origin": {"kind": "boss"}})
    assert o["kind"] == "unknown"


def _render_badge(origin):
    from web.app import app
    with app.app_context():
        tpl = app.jinja_env.get_template("_origin_badge.html")
        return tpl.render(t={"origin": origin})


def test_badge_renders_loud_for_peer_and_quiet_for_operator():
    peer = _render_badge(task_origin({"origin": "peer:832-Workflow-designer"}))
    assert 'data-origin="peer"' in peer and "var(--wt-warn)" in peer
    assert "peer request: 832-Workflow-designer" in peer
    mine = _render_badge(task_origin({"origin": "operator"}))
    assert 'data-origin="operator"' in mine and "var(--wt-warn)" not in mine


def test_badge_marks_inferred():
    html = _render_badge(task_origin({"name": "n", "description": "pickup from 832 msg abcdef12"}))
    assert 'data-inferred="true"' in html and "(inferred)" in html


def test_both_approvals_card_kinds_include_the_badge():
    src = (ROOT / "web/templates/_approvals_content.html").read_text(encoding="utf-8")
    assert src.count('{% include "_origin_badge.html" %}') == 2
    loader = (ROOT / "web/blueprints/approvals.py").read_text(encoding="utf-8")
    assert loader.count('"origin": task_origin(fm, body)') == 2
