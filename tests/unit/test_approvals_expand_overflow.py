"""T-2406: /approvals Verifications overflow has a visible expand-affordance + ?expand=verifications opt-in.

Origin: operator reported "Verifications header shows 184 but task rows don't render".
Cards DO render (178 of them) but 168 are wrapped in a `<details class="ac-overflow">` element
that defaults closed; the summary was a thin dashed border (sub-perceptual). T-2103 had set
`_ac_cap = 10` to fix the T-2038 unbounded-list page-height class. The right fix preserves
the cap and surfaces the overflow visually + adds a `?expand=verifications` escape hatch.

These tests drive the *real* approvals route with a stubbed `_load_pending_human_acs` returning
a controlled list of >10 task entries, then assert:
  - Default render: overflow `<details>` is closed (preserves T-2103 page-height cap)
  - Default render: "Expand all" link points at `?expand=verifications` (operator opt-in surface)
  - Default render: summary uses promoted button styling, not the dashed-border footnote
  - `?expand=verifications`: overflow `<details>` renders OPEN
  - `?expand=verifications`: "Collapse overflow" link points back at /approvals (reverse path)
  - Card count invariant: same number of `human-ac-group` cards in both modes (data unchanged)
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))


def _client():
    from web.app import app
    return app.test_client()


def _fake_pending_acs(n: int):
    """N task entries with one unchecked Human AC each — drives the overflow path."""
    out = []
    for i in range(n):
        tid = f"T-{9000 + i}"
        out.append({
            "task_id": tid,
            "name": f"fake task {i}",
            "status": "work-completed",
            "human_acs": [{
                "checked": False,
                "section": "human",
                "text": "verify",
                "confidence": "rubber-stamp",
                "line_idx": 1,
                "steps": [],
                "expected": "",
                "if_not": "",
            }],
            "age_days": 1,
            "is_stale": False,
            "sort_priority": 2,
            "verdict": "GO",
            "state": "OK",
            "reviewer": {"overall": "PASS", "findings": 0, "needs_human": False},
        })
    return out


def _patch_loaders(monkeypatch, n_acs: int):
    """Stub out the four other section loaders so only Verifications renders."""
    from web.blueprints import approvals
    monkeypatch.setattr(approvals, "_load_pending_approvals", lambda: [])
    monkeypatch.setattr(approvals, "_load_resolved_approvals", lambda: [])
    monkeypatch.setattr(approvals, "_load_pending_go_decisions", lambda: [])
    monkeypatch.setattr(approvals, "_load_pending_human_acs", lambda: _fake_pending_acs(n_acs))
    monkeypatch.setattr(approvals, "_count_deferred_inceptions", lambda: 0)
    monkeypatch.setattr(approvals, "_load_paused_dispatches", lambda: [])
    monkeypatch.setattr(approvals, "_load_close_ready_arcs", lambda _=0.80: [])


def test_default_render_overflow_closed_with_expand_link(monkeypatch):
    """Default ?expand absent → overflow closed + ‘Expand all’ link points at opt-in URL."""
    _patch_loaders(monkeypatch, n_acs=20)
    html = _client().get("/approvals").get_data(as_text=True)
    # Overflow <details> renders WITHOUT the open attribute (T-2103 cap preserved)
    assert '<details class="ac-overflow" style="margin:0.75rem 0;" >' in html or \
           '<details class="ac-overflow" style="margin:0.75rem 0;">' in html
    assert '<details class="ac-overflow" style="margin:0.75rem 0;" open>' not in html
    # Operator opt-in link points at the canonical expand URL
    assert '/approvals?expand=verifications' in html


def test_default_render_overflow_summary_is_button_styled(monkeypatch):
    """The promoted summary uses solid accent background (button-like), not the old dashed border."""
    _patch_loaders(monkeypatch, n_acs=20)
    html = _client().get("/approvals").get_data(as_text=True)
    # New button-styled summary
    assert "background:var(--wt-accent, var(--pico-primary))" in html
    # The thin dashed-border footnote is gone
    assert "border:1px dashed var(--pico-muted-border-color); border-radius:6px;\">Show " not in html


def test_expanded_render_overflow_open_with_collapse_link(monkeypatch):
    """?expand=verifications → overflow OPEN + ‘Collapse’ link points back to /approvals."""
    _patch_loaders(monkeypatch, n_acs=20)
    html = _client().get("/approvals?expand=verifications").get_data(as_text=True)
    # Overflow <details> renders WITH the open attribute
    assert '<details class="ac-overflow" style="margin:0.75rem 0;" open>' in html
    # Reverse-path link surfaces
    assert 'Collapse overflow' in html


def test_card_count_identical_in_default_and_expanded(monkeypatch):
    """The data layer is unchanged — both modes render the same `human-ac-group` count."""
    _patch_loaders(monkeypatch, n_acs=25)
    default_html = _client().get("/approvals").get_data(as_text=True)
    expanded_html = _client().get("/approvals?expand=verifications").get_data(as_text=True)
    default_cards = default_html.count('class="approval-card human-ac-group"')
    expanded_cards = expanded_html.count('class="approval-card human-ac-group"')
    assert default_cards == 25, f"default rendered {default_cards} cards, expected 25"
    assert expanded_cards == 25, f"expanded rendered {expanded_cards} cards, expected 25"


def test_no_overflow_when_under_cap(monkeypatch):
    """If pending_acs <= _ac_cap (10), no overflow `<details>` and no expand-all link surface."""
    _patch_loaders(monkeypatch, n_acs=5)
    html = _client().get("/approvals").get_data(as_text=True)
    assert '<details class="ac-overflow"' not in html
    assert '/approvals?expand=verifications' not in html


def test_htmx_content_fragment_respects_expand(monkeypatch):
    """The htmx polling fragment /approvals/content honours ?expand=verifications too."""
    _patch_loaders(monkeypatch, n_acs=15)
    html = _client().get("/approvals/content?expand=verifications").get_data(as_text=True)
    assert '<details class="ac-overflow" style="margin:0.75rem 0;" open>' in html
