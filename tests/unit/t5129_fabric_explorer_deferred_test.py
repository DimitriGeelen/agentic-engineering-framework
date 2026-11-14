"""T-5129: static guard for the fabric explorer's start-up. The main script is inert
(type text/fe-deferred) and a loader runs it once d3 exists, so an htmx swap, which loads the
d3 <script src> asynchronously, cannot run the explorer before d3 (1409's empty first open)."""
from pathlib import Path

T = (Path(__file__).resolve().parents[2] / "web" / "templates" / "fabric_explorer.html").read_text()


def test_the_explorer_code_is_inert_until_the_loader_runs_it():
    assert '<script type="text/fe-deferred" id="fe-main">' in T
    assert "getElementById('fe-main')" in T
    assert "if (window.d3) { run(); return; }" in T
    assert "tag.onload = run;" in T


def test_the_loader_comes_after_the_explorer_code():
    assert T.index('id="fe-main"') < T.index("getElementById('fe-main')")
