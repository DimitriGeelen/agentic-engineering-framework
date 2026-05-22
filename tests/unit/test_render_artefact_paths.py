"""T-1722: render_markdown_safe auto-links artefact paths.

Promoted from T-633's blueprint-private linkifier. Verifies the rendering-
layer contract: bare paths and backticked paths under known artefact prefixes
become clickable /file/ anchors when the path exists; non-existent paths and
out-of-prefix paths are left untouched.
"""

import os
from pathlib import Path

import pytest

# Point the renderer at the framework repo before importing — tests run with
# cwd somewhere else otherwise PROJECT_ROOT defaults to '/' and every existence
# check fails.
_REPO = Path(__file__).resolve().parents[2]
os.environ.setdefault("PROJECT_ROOT", str(_REPO))

from web import shared as _shared  # noqa: E402

# Force-rebind in case shared.py was imported earlier with a stale resolution.
_shared.PROJECT_ROOT = _REPO

from web.shared import PROJECT_ROOT, _auto_link_files, render_markdown_safe  # noqa: E402


@pytest.fixture(autouse=True)
def _pin_project_root_for_linkifier():
    """T-1995: re-pin web.shared.PROJECT_ROOT before every test in this module.

    Root cause of the cross-file flake: tests that `importlib.reload(web.shared)`
    after `monkeypatch.setenv("PROJECT_ROOT", tmp)` — test_arcs_routes,
    test_orchestrator_dispatch_substrate, test_orchestrator_outcome_quality,
    test_arc_membership_web_surfaces — re-run _resolve_project_root() against the
    temp env var. monkeypatch restores the *env var* at teardown but not the
    already-recomputed module global, so web.shared.PROJECT_ROOT is left pointing
    at a now-deleted tmp dir. _auto_link_files() reads that global at call time,
    so every (PROJECT_ROOT / path).exists() check fails and no path is linkified.
    The import-time pin above runs once at collection and cannot recover. Re-pinning
    per test makes these assertions order-independent (prevention, not reorder).
    Restores the prior value on teardown so we don't mask the polluter for others.
    """
    saved = _shared.PROJECT_ROOT
    _shared.PROJECT_ROOT = _REPO
    yield
    _shared.PROJECT_ROOT = saved


def _existing_artefact(prefix_glob: str) -> str:
    """Return a relative path of an existing file matching prefix_glob.

    Falls back to xfail-style skip if nothing matches, so the test stays
    meaningful even if a directory class is empty in some checkout.
    """
    matches = list(PROJECT_ROOT.glob(prefix_glob))
    if not matches:
        pytest.skip(f"no fixture file matches {prefix_glob}")
    return str(matches[0].relative_to(PROJECT_ROOT))


def test_bare_path_becomes_anchor():
    path = _existing_artefact("docs/reports/T-*.md")
    out = render_markdown_safe(f"See {path} for details.")
    assert f'href="/file/{path}"' in out


def test_backticked_path_becomes_anchor_with_code():
    path = _existing_artefact("docs/reports/T-*.md")
    out = render_markdown_safe(f"See `{path}` for details.")
    assert f'href="/file/{path}"' in out
    # Either <code><a>path</a></code> or <a href><code>path</code></a> is
    # acceptable — both render visually as clickable monospace. Markdown2
    # processes backticks before our linkifier so the actual order is the
    # former; we just assert <code> appears together with the anchor and path.
    assert "<code>" in out and "</code>" in out
    assert path in out


def test_nonexistent_path_is_not_linked():
    fake = "docs/reports/T-9999-does-not-exist.md"
    out = render_markdown_safe(f"See {fake} for nothing.")
    assert "/file/" not in out
    # The bare path should still appear as text.
    assert fake in out


def test_already_linked_path_not_double_wrapped():
    path = _existing_artefact("docs/reports/T-*.md")
    src = f"See [the report]({path}) for details."
    out = render_markdown_safe(src)
    # markdown2 produces <a href="path">the report</a>; the linkifier must
    # not also wrap it in /file/.
    # Count anchor tags pointing at this exact path:
    assert out.count(f'href="{path}"') == 1
    assert "/file/" not in out


def test_active_task_path_class():
    path = _existing_artefact(".tasks/active/T-*.md")
    out = render_markdown_safe(f"open {path}")
    assert f'href="/file/{path}"' in out


def test_completed_task_path_class():
    path = _existing_artefact(".tasks/completed/T-*.md")
    out = render_markdown_safe(f"open {path}")
    assert f'href="/file/{path}"' in out


def test_fabric_components_path_class():
    path = _existing_artefact(".fabric/components/*.yaml")
    out = render_markdown_safe(f"see {path}")
    assert f'href="/file/{path}"' in out


def test_context_audits_path_class():
    matches = list(PROJECT_ROOT.glob(".context/audits/**/*.yaml"))
    if not matches:
        pytest.skip("no .context/audits fixtures")
    path = str(matches[0].relative_to(PROJECT_ROOT))
    out = render_markdown_safe(f"see {path}")
    assert f'href="/file/{path}"' in out


def test_source_dir_path_class():
    out = render_markdown_safe("renderer lives in web/shared.py")
    assert 'href="/file/web/shared.py"' in out


def test_url_links_still_work_with_path_extension_present():
    # T-1575 contract regression check: backticked URLs must still wrap.
    out = render_markdown_safe(
        "Visit `http://example.com/x` for the docs/reports/T-1700-litellm-build.md report."
    )
    assert '<a href="http://example.com/x"><code>' in out
    # The path piece, if it exists, also linked:
    if (PROJECT_ROOT / "docs/reports/T-1700-litellm-build.md").exists():
        assert 'href="/file/docs/reports/T-1700-litellm-build.md"' in out


def test_t_nnnn_reference_still_links():
    # T-1575 contract regression check: T-NNNN refs still go to /tasks/T-NNNN.
    out = render_markdown_safe("see T-1700 for details")
    assert 'href="/tasks/T-1700"' in out


def test_auto_link_files_directly_idempotent():
    path = _existing_artefact("docs/reports/T-*.md")
    once = _auto_link_files(f"<p>see {path}</p>")
    twice = _auto_link_files(once)
    assert once == twice  # the (?<!href=") guard prevents re-linking
