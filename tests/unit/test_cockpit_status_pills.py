"""T-2023 (arc-007 S3a): cockpit status colours use per-palette semantic tokens.

The cockpit's audit badge (.wt-badge-pass/warn/fail) and work-queue status
(.wt-queue-status.*) used hardcoded hexes that defeat the foundation palette. This
slice maps them onto --wt-success/--wt-warn/--wt-danger/--wt-info so they re-theme.

Assertions are scoped to the named status RULES (not global hex absence — the
cockpit has many inline-style hexes deferred to a follow-up slice). The per-palette
re-theming itself is proven in tests/playwright/test_cockpit_status_pills.py; the
contrast/taste check is the Human [REVIEW] AC.
"""

from __future__ import annotations

from pathlib import Path

TEMPLATE = Path(__file__).resolve().parents[2] / "web" / "templates" / "cockpit.html"


def _css() -> str:
    return TEMPLATE.read_text()


def test_audit_badges_use_semantic_tokens():
    css = _css()
    assert ".wt-badge-pass { background:var(--wt-success)" in css
    assert ".wt-badge-warn { background:var(--wt-warn)" in css
    assert ".wt-badge-fail { background:var(--wt-danger)" in css
    # the old hardcoded badge fills are gone
    assert ".wt-badge-pass { background:#2e7d32" not in css
    assert ".wt-badge-warn { background:#f9a825" not in css
    assert ".wt-badge-fail { background:#c62828" not in css


def test_queue_status_pills_use_tokens():
    css = _css()
    # base pill + per-status semantic colours
    assert "var(--wt-danger)" in css and ".wt-queue-status.issues" in css
    assert "var(--wt-info)" in css and ".wt-queue-status.started-work" in css
    assert ".wt-queue-status.captured" in css and "var(--wt-muted)" in css
    assert ".wt-queue-status.work-completed" in css and "var(--wt-success)" in css
    # rendered as a pill (rounded, padded), not plain coloured text
    assert "border-radius:999px" in css
    # the old hardcoded queue-status colour rules are gone
    assert ".wt-queue-status.issues { color:#c62828" not in css
    assert ".wt-queue-status.started-work { color:#1565c0" not in css


def test_template_still_compiles():
    """Guard against a malformed inline <style> breaking the page."""
    import sys
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
    from web.app import app
    app.jinja_env.get_template("cockpit.html")  # raises on syntax error
