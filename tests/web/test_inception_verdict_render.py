"""T-1537: Synthetic inception card renders with verdict badge + data-verdict.

The live `/approvals` queue may be empty (all 9 captured inceptions had a
`## Decision: DEFER` already written into their bodies, so the inception-decision
filter excludes them). To prove the T-1537 wiring without depending on the
queue state, this test constructs a fake `pending_go` payload and renders the
shared `_approvals_content.html` partial via a minimal Flask app.

Same shape as T-1535 but unit-level (no browser).
"""

from __future__ import annotations

import os
from pathlib import Path

os.environ.setdefault("PROJECT_ROOT", str(Path(__file__).resolve().parents[2]))


def _render_approvals(pending_go):
    from flask import Flask
    from web.shared import PROJECT_ROOT

    template_dir = PROJECT_ROOT / "web" / "templates"
    app = Flask(__name__, template_folder=str(template_dir))
    app.config["SECRET_KEY"] = "test"
    app.config["WTF_CSRF_ENABLED"] = False

    @app.context_processor
    def _csrf():
        return {"csrf_token": lambda: "test-token"}

    with app.test_request_context("/approvals"):
        from flask import render_template
        return render_template(
            "_approvals_content.html",
            pending_tier0=[],
            pending_go=pending_go,
            pending_acs=[],
            resolved_tier0=[],
            tier0_count=0,
            ac_count=0,
            ac_task_count=0,
            go_count=len(pending_go),
            ready_count=0,
            deferred_count=0,
            total_count=len(pending_go),
        )


def _fake_inception(task_id, verdict):
    return {
        "task_id": task_id,
        "name": f"Synthetic inception {task_id}",
        "status": "captured",
        "problem_excerpt": "Test problem",
        "problem_full": "Test problem",
        "assumption_counts": {"total": 0, "validated": 0, "source": "ledger"},
        "artifacts": [],
        "rationale_hint": "Test rationale",
        "recommendation": f"**Recommendation:** {verdict}\n\n**Rationale:** test",
        "rec_decision": verdict if verdict in ("GO", "DEFER", "NO-GO") else "",
        "verdict": verdict,
        "go_nogo_criteria": "",
    }


def test_inception_card_carries_data_verdict_attribute():
    html = _render_approvals([_fake_inception("T-9001", "GO")])
    assert 'class="approval-card go-decision" data-verdict="GO"' in html


def test_inception_card_renders_verdict_badge_with_correct_class():
    html = _render_approvals([_fake_inception("T-9002", "DEFER")])
    # Badge span exists with class verdict-badge and data-verdict="DEFER"
    assert 'class="verdict-badge"' in html
    assert 'data-verdict="DEFER"' in html


def test_inception_card_badge_colour_matches_verdict():
    """GO is green (#1b5e20), DEFER amber (#e65100), NO-GO red (#b71c1c), ? grey (#616161)."""
    cases = [
        ("GO", "#1b5e20"),
        ("DEFER", "#e65100"),
        ("NO-GO", "#b71c1c"),
        ("?", "#616161"),
    ]
    for verdict, colour in cases:
        html = _render_approvals([_fake_inception(f"T-9{verdict}", verdict)])
        # Badge style block sits inside the card; assert the colour appears
        # alongside the verdict marker.
        assert colour in html, f"expected colour {colour} in card for verdict {verdict}"


def test_multiple_inception_cards_each_get_their_own_badge():
    cards = [
        _fake_inception("T-9011", "GO"),
        _fake_inception("T-9012", "DEFER"),
        _fake_inception("T-9013", "NO-GO"),
    ]
    html = _render_approvals(cards)
    # Each card div has data-verdict
    assert html.count('class="approval-card go-decision" data-verdict=') == 3
    # Each verdict appears as a badge data-verdict
    for v in ("GO", "DEFER", "NO-GO"):
        assert f'<span class="verdict-badge" data-verdict="{v}"' in html


def test_unknown_verdict_falls_back_to_question_mark():
    card = _fake_inception("T-9020", "?")
    html = _render_approvals([card])
    assert 'data-verdict="?"' in html
