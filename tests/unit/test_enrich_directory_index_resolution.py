"""#71 — a Node directory import must resolve to the directory's index file.

`detect_ts_js_imports` lists `/index.ts`, `/index.js`, … among its candidate
extensions, but tested each candidate with `os.path.exists`, which is **true for a
directory**. For `require('./models')` the first candidate (the empty extension)
matched the *directory* `models`, `break` fired, and every `/index.*` candidate
below it was unreachable. The emitted target was a bare directory path, which
matches no card's `location`, so the edge was discarded downstream — silently,
until the unresolved-target reporting of T-2736 started counting the casualties
and filed them under "directories (detector noise, correctly dropped)".

They were not noise. A directory whose `index.js` exists on disk is a real module
and Node resolves it; the detector's own extension list says it meant to. Measured
on a 726-card consumer project: 218 real edges lost this way, across four index
modules, 20% of all detected JavaScript edges.

These tests call the shipped `detect_ts_js_imports` rather than reimplementing the
candidate loop, so they cannot drift from the producer (L-533).
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "agents" / "fabric" / "lib"))

import enrich  # noqa: E402


@pytest.fixture
def tree(tmp_path):
    """A directory module with an index, a directory module without, and a plain file."""
    (tmp_path / "src").mkdir()
    (tmp_path / "src" / "models").mkdir()
    (tmp_path / "src" / "models" / "index.js").write_text("module.exports = {};\n")
    (tmp_path / "src" / "empty").mkdir()          # a directory with NO index.*
    (tmp_path / "src" / "util.js").write_text("module.exports = {};\n")
    return tmp_path


def _targets(content, tmp_path, source="src/app.js"):
    return {loc for loc, _type in
            enrich.detect_ts_js_imports(content, source, str(tmp_path))}


def test_directory_import_resolves_to_index(tree):
    """The regression. Pre-fix this yielded 'src/models', not the index file."""
    targets = _targets("const m = require('./models');\n", tree)
    assert "src/models/index.js" in targets


def test_directory_import_does_not_emit_the_bare_directory(tree):
    """The other half: emitting the directory is what made the edge unresolvable.

    Asserted separately from the test above because a loop that emitted BOTH would
    satisfy that one while still feeding an unresolvable target downstream.
    """
    targets = _targets("const m = require('./models');\n", tree)
    assert "src/models" not in targets


def test_directory_without_index_emits_nothing(tree):
    """Discrimination control — the fix must not invent an edge that has no file.

    Without this, a change that simply appended '/index.js' unconditionally would
    pass both tests above.
    """
    targets = _targets("const m = require('./empty');\n", tree)
    assert not any(t.startswith("src/empty") for t in targets)


def test_plain_file_import_still_resolves(tree):
    """Control for the ordinary path: isfile must not break non-directory imports."""
    assert "src/util.js" in _targets("const u = require('./util.js');\n", tree)


def test_extensionless_file_import_still_resolves(tree):
    """Control: the extension-completion path, which shares the same loop."""
    assert "src/util.js" in _targets("const u = require('./util');\n", tree)


def test_esm_import_form_resolves_directory_too(tree):
    """The bug was in the shared candidate loop, so every import form inherits the fix."""
    assert "src/models/index.js" in _targets("import m from './models';\n", tree)
