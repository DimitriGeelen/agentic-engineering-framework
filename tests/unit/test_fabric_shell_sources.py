r"""T-3122 — detect_bash_sources must resolve source paths, not variable names.

The original implementation recognised `source X` only when X was written under
one of four blessed variable names ($LIB_DIR, $SCRIPT_DIR, $AGENTS_DIR,
$FW_LIB_DIR). It matched the NAME, never the PATH — so 127 of this repo's 194
source statements emitted no edge, including the 88 using the framework's own
`$FRAMEWORK_ROOT/...` idiom. Sibling class to T-3121 (hardcoded
`web|lib|agents|tools` prefix list in the Python detector).

The fixture tree below deliberately avoids the blessed vocabulary: it uses
`tools/helpers/...` and arbitrary variable names, so a fixture written against
the BROKEN code would fail. Per L-599 nothing here asserts against the live
repo or live edge counts, which move under the test.
"""

import importlib.util
import os
import sys

import pytest

_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_ENRICH_PATH = os.path.join(_REPO_ROOT, "agents", "fabric", "lib", "enrich.py")


def _load_enrich():
    spec = importlib.util.spec_from_file_location("fabric_enrich_sh_under_test", _ENRICH_PATH)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


enrich = _load_enrich()
detect = enrich.detect_bash_sources


# ---------------------------------------------------------------------------
# Fixture tree — no blessed names anywhere in the paths
# ---------------------------------------------------------------------------

FIXTURE_FILES = [
    "tools/run.sh",              # the source file under analysis
    "tools/shared.sh",           # sibling of run.sh — the "local wins" target
    "tools/lib/shared.sh",       # same basename one level down — must lose
    "tools/lib/only-in-lib.sh",  # reachable ONLY via the <dir>/lib/ candidate
    "tools/helpers/util.sh",     # project-root-relative target
    "tools/deep/nested.sh",      # a nested script, far from tools/helpers
    ".bashrc",                   # a real file that must never become an edge
]


@pytest.fixture
def tree(tmp_path):
    """Build the fixture tree and return its root as a string."""
    for rel in FIXTURE_FILES:
        p = tmp_path / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text("# fixture\n")
    return str(tmp_path)


def targets(content, source_location, root):
    return [t for t, _rel in detect(content, source_location, root)]


# ---------------------------------------------------------------------------
# Argument shapes — every row must yield the same resolved target
# ---------------------------------------------------------------------------

def test_framework_root_form_resolves(tree):
    """The framework's own idiom — 88 unrecognised statements before T-3122."""
    content = 'source "$FRAMEWORK_ROOT/tools/helpers/util.sh"\n'
    assert targets(content, "tools/deep/nested.sh", tree) == ["tools/helpers/util.sh"]


def test_arbitrary_variable_name_resolves(tree):
    """A one-off lowercase variable is resolved exactly like a blessed one."""
    content = 'source "$my_own_root/tools/helpers/util.sh"\n'
    assert targets(content, "tools/deep/nested.sh", tree) == ["tools/helpers/util.sh"]


def test_braced_variable_form_resolves(tree):
    content = 'source "${ANYTHING_AT_ALL}/tools/helpers/util.sh"\n'
    assert targets(content, "tools/deep/nested.sh", tree) == ["tools/helpers/util.sh"]


def test_dirname_zero_form_resolves(tree):
    """`$(dirname "$0")/...` — resolved relative to the source file's dir."""
    content = 'source "$(dirname "$0")/helpers/util.sh"\n'
    assert targets(content, "tools/run.sh", tree) == ["tools/helpers/util.sh"]


def test_nested_command_substitution_form_resolves(tree):
    """The embedded `&&` must not truncate the argument scan."""
    content = 'source "$(cd "$(dirname "$0")/.." && pwd)/tools/helpers/util.sh"\n'
    assert targets(content, "tools/deep/nested.sh", tree) == ["tools/helpers/util.sh"]


def test_literal_relative_form_resolves(tree):
    """A leading './' is stripped before resolution."""
    content = 'source ./helpers/util.sh\n'
    assert targets(content, "tools/run.sh", tree) == ["tools/helpers/util.sh"]


def test_bare_relative_form_resolves(tree):
    content = 'source helpers/util.sh\n'
    assert targets(content, "tools/run.sh", tree) == ["tools/helpers/util.sh"]


def test_dot_source_form_resolves(tree):
    """`. X` is the same command as `source X`."""
    content = '. "$WHATEVER/tools/helpers/util.sh"\n'
    assert targets(content, "tools/deep/nested.sh", tree) == ["tools/helpers/util.sh"]


# ---------------------------------------------------------------------------
# Resolution order: <dir>/<path> → <dir>/lib/<path> → <root>/<path>
# ---------------------------------------------------------------------------

def test_project_root_relative_resolution_from_nested_script(tree):
    """Candidate (c): nothing local matches, the path is rooted at the project."""
    content = 'source "$R/tools/shared.sh"\n'
    assert targets(content, "tools/deep/nested.sh", tree) == ["tools/shared.sh"]


def test_local_wins_over_lib_subdir(tree):
    """Candidate (a) beats (b): tools/shared.sh, not tools/lib/shared.sh."""
    content = 'source "$SOME_DIR/shared.sh"\n'
    assert targets(content, "tools/run.sh", tree) == ["tools/shared.sh"]


def test_lib_subdir_candidate_still_reachable(tree):
    """Candidate (b) preserves the old $LIB_DIR behaviour — pinned per T-3122 AC3.

    `only-in-lib.sh` exists ONLY at tools/lib/, so the <dir>/lib/ candidate is
    the sole way to reach it. This is the branch the general path replaced.
    """
    content = '. "$LIB_DIR/only-in-lib.sh"\n'
    assert targets(content, "tools/run.sh", tree) == ["tools/lib/only-in-lib.sh"]


# ---------------------------------------------------------------------------
# Guards
# ---------------------------------------------------------------------------

def test_no_self_edge(tree):
    content = 'source "$FRAMEWORK_ROOT/tools/run.sh"\n'
    assert targets(content, "tools/run.sh", tree) == []


def test_no_duplicate_target(tree):
    """Two different spellings of the same file produce one edge."""
    content = (
        'source "$FRAMEWORK_ROOT/tools/helpers/util.sh"\n'
        'source "$other_var/tools/helpers/util.sh"\n'
        '. ./helpers/util.sh\n'
    )
    assert targets(content, "tools/run.sh", tree) == ["tools/helpers/util.sh"]


def test_no_edge_for_path_not_on_disk(tree):
    content = 'source "$FRAMEWORK_ROOT/tools/helpers/missing.sh"\n'
    assert targets(content, "tools/run.sh", tree) == []


def test_system_and_home_sources_ignored(tree):
    """/etc, /usr, /dev, $HOME and ~ are never project edges.

    `.bashrc` exists at the fixture root, so existence-guarding alone would
    have emitted an edge for it — the prefix rejection is what stops it.
    """
    content = (
        'source /etc/profile\n'
        'source /usr/share/thing.sh\n'
        'source /dev/null\n'
        'source "$HOME/.bashrc"\n'
        'source ~/.bashrc\n'
    )
    assert targets(content, "tools/run.sh", tree) == []


def test_source_after_separator_is_seen(tree):
    """`&&`- and `;`-separated source commands are still at command position."""
    content = (
        '[ -f "$X/tools/shared.sh" ] && source "$X/tools/shared.sh"\n'
        'if true; then . "$Y/tools/helpers/util.sh"; fi\n'
    )
    assert sorted(targets(content, "tools/deep/nested.sh", tree)) == [
        "tools/helpers/util.sh",
        "tools/shared.sh",
    ]
