r"""T-3121 — detect_generic_python_imports must see dotted import paths.

The original pattern was `from\s+(\w+)\s+import`; `\w` excludes `.`, so
`from pkg.mod import X` failed outright and `import pkg.mod` was never looked
at at all. These tests build their own fixture tree in tmp_path — per L-599 we
never assert against the live `.fabric/` corpus or live source counts, which
move under the test for reasons unrelated to this rule.
"""

import importlib.util
import os
import sys

import pytest

_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_ENRICH_PATH = os.path.join(_REPO_ROOT, "agents", "fabric", "lib", "enrich.py")


def _load_enrich():
    spec = importlib.util.spec_from_file_location("fabric_enrich_under_test", _ENRICH_PATH)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


enrich = _load_enrich()
detect = enrich.detect_generic_python_imports


def _write(root, relpath, body=""):
    full = os.path.join(str(root), relpath)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w") as fh:
        fh.write(body)
    return relpath


@pytest.fixture
def tree(tmp_path):
    """A minimal project tree:

        app/main.py          <- the source under analysis
        app/sibling.py
        app/pkg/__init__.py
        app/pkg/mod.py
        app/pkg/sub/__init__.py
        app/a/b.py
        app/yaml/parser.py   <- decoy: a real path that must NOT be resolved
    """
    _write(tmp_path, "app/main.py")
    _write(tmp_path, "app/sibling.py")
    _write(tmp_path, "app/pkg/__init__.py")
    _write(tmp_path, "app/pkg/mod.py")
    _write(tmp_path, "app/pkg/sub/__init__.py")
    _write(tmp_path, "app/a/b.py")
    _write(tmp_path, "app/yaml/parser.py")
    return tmp_path


def _targets(content, tree, source="app/main.py"):
    return [t for t, _kind in detect(content, source, str(tree))]


def test_dotted_from_import_resolves_to_module_file(tree):
    assert _targets("from pkg.mod import X\n", tree) == [os.path.join("app", "pkg", "mod.py")]


def test_dotted_from_import_resolves_to_package_init(tree):
    assert _targets("from pkg.sub import X\n", tree) == [
        os.path.join("app", "pkg", "sub", "__init__.py")
    ]


def test_plain_dotted_import_statement_resolves(tree):
    assert _targets("import a.b\n", tree) == [os.path.join("app", "a", "b.py")]


def test_plain_dotted_import_comma_form_resolves_each(tree):
    targets = _targets("import a.b, pkg.mod\n", tree)
    assert sorted(targets) == sorted(
        [os.path.join("app", "a", "b.py"), os.path.join("app", "pkg", "mod.py")]
    )


def test_skip_modules_consults_root_segment(tree):
    """`yaml` is third-party; `from yaml.parser import X` must emit no edge even
    though app/yaml/parser.py exists on disk."""
    assert _targets("from yaml.parser import X\n", tree) == []
    assert _targets("import yaml.parser\n", tree) == []


def test_flat_sibling_import_still_resolves(tree):
    assert _targets("from sibling import X\n", tree) == [os.path.join("app", "sibling.py")]


def test_no_self_edge(tree):
    """A module importing itself must not emit an edge back to its own path."""
    assert _targets("from main import X\nimport main\n", tree, source="app/main.py") == []


def test_no_edge_for_path_not_on_disk(tree):
    assert _targets("from pkg.nonexistent import X\nimport totally.absent\n", tree) == []


def test_duplicate_target_emitted_once(tree):
    content = "from pkg.mod import X\nfrom pkg.mod import Y\nimport pkg.mod\n"
    assert _targets(content, tree) == [os.path.join("app", "pkg", "mod.py")]


def test_root_relative_resolution_from_nested_source(tree):
    """A nested file importing a root-level package (T-3121, strategy 4).

    `app/deep/nested/view.py` doing `from app.pkg.mod import X` means
    `<root>/app/pkg/mod.py`. Strategies 1-3 search only the source's own
    directory and its parent, so from `app/deep/nested/` they cannot reach it
    and the detector returned nothing at all for every nested file.

    This is the case the framework was blind to: `detect_python_imports` carries
    a hardcoded `web|lib|agents|tools` prefix list that resolves root-relative
    for those four names only, so the framework's own nested imports worked and
    a consumer's identical layout did not. The fixture deliberately uses none of
    those four names — with them, this test would pass against the broken code.
    """
    _write(tree, "app/deep/nested/view.py")
    targets = _targets(
        "from app.pkg.mod import X\n", tree, source="app/deep/nested/view.py"
    )
    assert targets == [os.path.join("app", "pkg", "mod.py")]


def test_root_relative_does_not_override_local_resolution(tree):
    """Local resolution still wins — strategy 4 is last, not first.

    `app/pkg/` holds a `mod.py`, and a root-level `mod.py` also exists. A file
    inside `app/pkg/` saying `import mod` must bind to its sibling, not to the
    root one, or adding the fallback would silently re-point existing edges.
    """
    _write(tree, "mod.py")
    targets = _targets("import mod\n", tree, source="app/pkg/other.py")
    assert targets == [os.path.join("app", "pkg", "mod.py")]
