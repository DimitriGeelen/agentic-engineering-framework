"""T-4745: a module the unit suite discovers by content must really define a test.

The pytest leg (agents/audit/unit-suite.sh `_discover_pytest`, twin
agents/audit/unit_tier.py `discover`) runs any tests/unit/*.py whose text
matches `def test…` / `class Test…`. That is a grep, so a helper whose docstring
shows a usage example (`    def test_x(hermetic):`) is run as a test file and
graded red on pytest's exit 5. tests/unit/hermetic.py did exactly that in every
slow nightly from 2026-10-20 until it was renamed _hermetic.py.

This walks the same discovery and AST-checks each content-discovered module for
a top-level test function or Test class. Name-discovered files (test_*.py,
*_test.py) are out of scope: their name claims tests, and exit 5 is the right
grade for one that has none.
"""
import ast
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "agents" / "audit"))
import unit_tier  # noqa: E402

NAMED = re.compile(r"(test_.*|.*_test)\.py$")


def _defines_test(tree):
    for node in tree.body:
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and node.name.startswith("test"):
            return True
        if isinstance(node, ast.ClassDef) and node.name.startswith("Test"):
            return True
    return False


def content_discovered_without_tests(suite_dir):
    bad = []
    for name in unit_tier.discover(str(suite_dir)):
        if not name.endswith(".py") or NAMED.match(name):
            continue
        path = Path(suite_dir) / name
        try:
            tree = ast.parse(path.read_text(errors="replace"), filename=str(path))
        except SyntaxError:
            continue  # pytest grades a broken file itself; not this guard's class
        if not _defines_test(tree):
            bad.append(name)
    return bad


def test_corpus_has_no_helper_discovered_as_a_test_file():
    bad = content_discovered_without_tests(ROOT / "tests" / "unit")
    assert not bad, (
        "discovered as pytest files but define no top-level test (pytest exits 5): "
        f"{bad} — prefix helper modules with '_' so discovery skips them")


def test_guard_catches_a_docstring_only_helper(tmp_path):
    (tmp_path / "helper.py").write_text('"""Usage:\n\n    def test_x(fixture):\n        ..."""\n')
    (tmp_path / "_helper.py").write_text('"""    def test_y(): ..."""\n')
    (tmp_path / "real.py").write_text("def test_real():\n    pass\n")
    (tmp_path / "test_named.py").write_text("x = 1\n")
    assert content_discovered_without_tests(tmp_path) == ["helper.py"]
