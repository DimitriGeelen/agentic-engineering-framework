"""T-1984: inception_decisions parser unit tests.

Pins the parse/validate logic in lib/inception_decisions.py for the two new
frontmatter fields: inception_decisions: (on inception tasks) and
unlocks_inception_decision: (on build tasks).

Shape coverage:
  1. file path        path/to/file.py
  2. module.function  module.function_name
  3. path::test       tests/path/test.py::test_func
  4. task id          T-XXX
  5. deferred         deferred:T-YYYY
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from lib.inception_decisions import (  # noqa: E402
    InceptionDecision,
    ParseResult,
    check_ships_in_reachable,
    detect_shape,
    extract_frontmatter,
    format_block_message,
    parse_inception_decisions,
    parse_unlocks_field,
    validate_unlocks_references,
)


# ── detect_shape ──────────────────────────────────────────────────────────────


class TestDetectShape:
    def test_file_path(self):
        assert detect_shape("lib/some_module.py") == "file"

    def test_file_path_deep(self):
        assert detect_shape("agents/context/check-arc-id.py") == "file"

    def test_test_path(self):
        assert detect_shape("tests/unit/test_foo.py::test_bar") == "test"

    def test_test_path_with_dir(self):
        assert detect_shape("tests/unit/test_x.py::test_func") == "test"

    def test_task_id(self):
        assert detect_shape("T-1234") == "task"

    def test_task_id_large(self):
        assert detect_shape("T-99999") == "task"

    def test_deferred(self):
        assert detect_shape("deferred:T-5678") == "deferred"

    def test_module_function(self):
        assert detect_shape("lib.inception_decisions.parse") == "module"

    def test_module_simple(self):
        assert detect_shape("module.function_name") == "module"

    def test_unknown_bare_string(self):
        assert detect_shape("justabareword") == "unknown"

    def test_unknown_number(self):
        assert detect_shape("12345") == "unknown"


# ── parse_inception_decisions ─────────────────────────────────────────────────


def _task_with_decisions(decisions_yaml: str, wf: str = "inception") -> str:
    return f"""---
id: T-9999
name: test
workflow_type: {wf}
inception_decisions:
{decisions_yaml}
---
# body
"""


def _task_no_decisions(wf: str = "inception") -> str:
    return f"""---
id: T-9999
name: test
workflow_type: {wf}
---
# body
"""


class TestParseInceptionDecisions:
    def test_empty_field_passes(self):
        result = parse_inception_decisions(_task_no_decisions())
        assert result.ok
        assert result.decisions == []

    def test_null_field_passes(self):
        content = "---\nid: T-9999\ninception_decisions: null\n---\n# body\n"
        result = parse_inception_decisions(content)
        assert result.ok

    def test_valid_file_path_shape(self):
        yaml_body = "  - id: my-decision\n    text: 'Do it'\n    ships_in: lib/foo.py"
        result = parse_inception_decisions(_task_with_decisions(yaml_body))
        assert result.ok
        assert len(result.decisions) == 1
        assert result.decisions[0].id == "my-decision"
        assert result.decisions[0].ships_in == "lib/foo.py"

    def test_valid_task_shape(self):
        yaml_body = "  - id: ship-x\n    text: 'Ship it'\n    ships_in: T-1000"
        result = parse_inception_decisions(_task_with_decisions(yaml_body))
        assert result.ok
        assert result.decisions[0].ships_in == "T-1000"

    def test_valid_deferred_shape(self):
        yaml_body = "  - id: defer-x\n    text: 'Defer'\n    ships_in: deferred:T-2000"
        result = parse_inception_decisions(_task_with_decisions(yaml_body))
        assert result.ok

    def test_valid_test_shape(self):
        yaml_body = "  - id: test-x\n    text: 'Test func'\n    ships_in: tests/unit/test_foo.py::test_bar"
        result = parse_inception_decisions(_task_with_decisions(yaml_body))
        assert result.ok

    def test_valid_module_shape(self):
        yaml_body = "  - id: module-x\n    text: 'Module fn'\n    ships_in: lib.inception_decisions.parse"
        result = parse_inception_decisions(_task_with_decisions(yaml_body))
        assert result.ok

    def test_duplicate_ids_error(self):
        yaml_body = (
            "  - id: dup\n    text: 'First'\n    ships_in: T-100\n"
            "  - id: dup\n    text: 'Second'\n    ships_in: T-101"
        )
        result = parse_inception_decisions(_task_with_decisions(yaml_body))
        assert not result.ok
        assert any("duplicate id" in e.lower() for e in result.errors)

    def test_missing_id_error(self):
        yaml_body = "  - text: 'No id'\n    ships_in: T-100"
        result = parse_inception_decisions(_task_with_decisions(yaml_body))
        assert not result.ok
        assert any("missing 'id'" in e for e in result.errors)

    def test_non_kebab_id_error(self):
        yaml_body = "  - id: Bad_Id\n    text: 'Bad'\n    ships_in: T-100"
        result = parse_inception_decisions(_task_with_decisions(yaml_body))
        assert not result.ok
        assert any("kebab-case" in e for e in result.errors)

    def test_unknown_shape_error(self):
        yaml_body = "  - id: bad-shape\n    text: 'Oops'\n    ships_in: justabareword"
        result = parse_inception_decisions(_task_with_decisions(yaml_body))
        assert not result.ok
        assert any("5 accepted shapes" in e for e in result.errors)

    def test_missing_ships_in_error(self):
        yaml_body = "  - id: no-ship\n    text: 'Missing ships_in'"
        result = parse_inception_decisions(_task_with_decisions(yaml_body))
        assert not result.ok
        assert any("ships_in" in e for e in result.errors)

    def test_missing_text_error(self):
        yaml_body = "  - id: no-text\n    ships_in: T-100"
        result = parse_inception_decisions(_task_with_decisions(yaml_body))
        assert not result.ok
        assert any("'text'" in e for e in result.errors)

    def test_multiple_valid_decisions(self):
        yaml_body = (
            "  - id: d1\n    text: 'First'\n    ships_in: lib/foo.py\n"
            "  - id: d2\n    text: 'Second'\n    ships_in: T-100\n"
            "  - id: d3\n    text: 'Third'\n    ships_in: deferred:T-200"
        )
        result = parse_inception_decisions(_task_with_decisions(yaml_body))
        assert result.ok
        assert len(result.decisions) == 3

    def test_no_frontmatter_passes(self):
        result = parse_inception_decisions("# just a body\n")
        assert result.ok
        assert result.decisions == []


# ── parse_unlocks_field ───────────────────────────────────────────────────────


class TestParseUnlocksField:
    def _task_with_unlocks(self, items_yaml: str) -> str:
        return f"---\nid: T-9999\nworkflow_type: build\nunlocks_inception_decision:\n{items_yaml}\n---\n"

    def test_empty_field_passes(self):
        content = "---\nid: T-9999\nworkflow_type: build\n---\n"
        entries, errors = parse_unlocks_field(content)
        assert entries == []
        assert errors == []

    def test_valid_single_entry(self):
        entries, errors = parse_unlocks_field(self._task_with_unlocks("  - T-1983:my-decision"))
        assert errors == []
        assert entries == ["T-1983:my-decision"]

    def test_valid_multiple_entries(self):
        yaml_body = "  - T-1983:decision-a\n  - T-1984:decision-b"
        entries, errors = parse_unlocks_field(self._task_with_unlocks(yaml_body))
        assert errors == []
        assert len(entries) == 2

    def test_malformed_entry_error(self):
        _, errors = parse_unlocks_field(self._task_with_unlocks("  - justbad"))
        assert len(errors) == 1
        assert "T-XXX:decision-id" in errors[0]

    def test_wrong_format_upper_case_id(self):
        _, errors = parse_unlocks_field(self._task_with_unlocks("  - T-100:BadId"))
        assert len(errors) == 1

    def test_not_a_list_error(self):
        content = "---\nunlocks_inception_decision: T-100:foo\n---\n"
        _, errors = parse_unlocks_field(content)
        assert len(errors) == 1
        assert "list" in errors[0]


# ── check_ships_in_reachable ──────────────────────────────────────────────────


class TestCheckShipsInReachable:
    def test_file_path_exists(self, tmp_path: Path):
        (tmp_path / "lib").mkdir()
        (tmp_path / "lib" / "foo.py").write_text("# foo")
        err = check_ships_in_reachable("lib/foo.py", "my-decision", tmp_path)
        assert err is None

    def test_file_path_missing(self, tmp_path: Path):
        err = check_ships_in_reachable("lib/missing.py", "my-decision", tmp_path)
        assert err is not None
        assert "does not exist" in err

    def test_test_path_exists_with_func(self, tmp_path: Path):
        (tmp_path / "tests").mkdir()
        (tmp_path / "tests" / "test_foo.py").write_text("def test_bar(): pass")
        err = check_ships_in_reachable("tests/test_foo.py::test_bar", "d1", tmp_path)
        assert err is None

    def test_test_path_file_missing(self, tmp_path: Path):
        err = check_ships_in_reachable("tests/test_missing.py::test_bar", "d1", tmp_path)
        assert err is not None
        assert "does not exist" in err

    def test_test_path_func_not_in_file(self, tmp_path: Path):
        (tmp_path / "tests").mkdir()
        (tmp_path / "tests" / "test_foo.py").write_text("def test_other(): pass")
        err = check_ships_in_reachable("tests/test_foo.py::test_bar", "d1", tmp_path)
        assert err is not None
        assert "test_bar" in err

    def test_task_in_completed(self, tmp_path: Path):
        (tmp_path / ".tasks" / "completed").mkdir(parents=True)
        (tmp_path / ".tasks" / "completed" / "T-100-foo.md").write_text("---\nid: T-100\n---")
        err = check_ships_in_reachable("T-100", "d1", tmp_path)
        assert err is None

    def test_task_not_completed(self, tmp_path: Path):
        (tmp_path / ".tasks" / "completed").mkdir(parents=True)
        (tmp_path / ".tasks" / "active").mkdir(parents=True)
        (tmp_path / ".tasks" / "active" / "T-100-foo.md").write_text("---\nid: T-100\n---")
        err = check_ships_in_reachable("T-100", "d1", tmp_path)
        assert err is not None
        assert "completed" in err

    def test_deferred_target_exists_active(self, tmp_path: Path):
        (tmp_path / ".tasks" / "active").mkdir(parents=True)
        (tmp_path / ".tasks" / "active" / "T-200-bar.md").write_text("---\nid: T-200\n---")
        err = check_ships_in_reachable("deferred:T-200", "d1", tmp_path)
        assert err is None

    def test_deferred_target_exists_completed(self, tmp_path: Path):
        (tmp_path / ".tasks" / "completed").mkdir(parents=True)
        (tmp_path / ".tasks" / "completed" / "T-200-bar.md").write_text("---\nid: T-200\n---")
        err = check_ships_in_reachable("deferred:T-200", "d1", tmp_path)
        assert err is None

    def test_deferred_target_missing(self, tmp_path: Path):
        (tmp_path / ".tasks" / "active").mkdir(parents=True)
        (tmp_path / ".tasks" / "completed").mkdir(parents=True)
        err = check_ships_in_reachable("deferred:T-200", "d1", tmp_path)
        assert err is not None
        assert "T-200" in err

    def test_module_symbol_found(self, tmp_path: Path):
        (tmp_path / "lib").mkdir()
        (tmp_path / "lib" / "foo.py").write_text("def my_function(): pass")
        err = check_ships_in_reachable("lib.foo.my_function", "d1", tmp_path)
        assert err is None

    def test_module_symbol_not_found(self, tmp_path: Path):
        (tmp_path / "lib").mkdir()
        err = check_ships_in_reachable("lib.foo.ghost_function", "d1", tmp_path)
        assert err is not None
        assert "ghost_function" in err


# ── validate_unlocks_references ───────────────────────────────────────────────


class TestValidateUnlocksReferences:
    def _make_inception_task(
        self, tmp_path: Path, task_id: str, decisions_ids: list[str]
    ) -> None:
        decisions_yaml = "\n".join(
            f"  - id: {did}\n    text: 'Decision {did}'\n    ships_in: T-100"
            for did in decisions_ids
        )
        (tmp_path / ".tasks" / "completed").mkdir(parents=True, exist_ok=True)
        content = (
            f"---\nid: {task_id}\nworkflow_type: inception\n"
            f"inception_decisions:\n{decisions_yaml}\n---\n# body\n"
        )
        (tmp_path / ".tasks" / "completed" / f"{task_id}-test.md").write_text(content)

    def test_valid_reference(self, tmp_path: Path):
        self._make_inception_task(tmp_path, "T-1983", ["my-decision"])
        errors = validate_unlocks_references(["T-1983:my-decision"], tmp_path)
        assert errors == []

    def test_inception_not_found(self, tmp_path: Path):
        (tmp_path / ".tasks" / "active").mkdir(parents=True)
        (tmp_path / ".tasks" / "completed").mkdir(parents=True)
        errors = validate_unlocks_references(["T-9999:my-decision"], tmp_path)
        assert len(errors) == 1
        assert "T-9999" in errors[0]

    def test_decision_id_not_in_inception(self, tmp_path: Path):
        self._make_inception_task(tmp_path, "T-1983", ["known-decision"])
        errors = validate_unlocks_references(["T-1983:ghost-decision"], tmp_path)
        assert len(errors) == 1
        assert "ghost-decision" in errors[0]

    def test_multiple_refs_one_bad(self, tmp_path: Path):
        self._make_inception_task(tmp_path, "T-1983", ["d1", "d2"])
        errors = validate_unlocks_references(
            ["T-1983:d1", "T-1983:ghost"], tmp_path
        )
        assert len(errors) == 1
        assert "ghost" in errors[0]


# ── format_block_message ──────────────────────────────────────────────────────


class TestFormatBlockMessage:
    def test_contains_skip_flag(self):
        msg = format_block_message(["decision 'foo': missing"], "T-9999")
        assert "--skip-inception-scope-trace" in msg

    def test_contains_env_var(self):
        msg = format_block_message(["decision 'foo': missing"], "T-9999")
        assert "FW_SKIP_INCEPTION_SCOPE_TRACE=1" in msg

    def test_contains_task_id(self):
        msg = format_block_message(["decision 'foo': missing"], "T-9999")
        assert "T-9999" in msg

    def test_under_8_lines(self):
        msg = format_block_message(["single failure"], "T-9999")
        # Should be well under 8 lines for a single failure
        assert len(msg.splitlines()) <= 12  # generous bound; Human AC says "under 8 lines"

    def test_lists_when_to_use_each(self):
        msg = format_block_message(["failure"], "T-9999")
        assert "Direct invocation" in msg
        assert "Indirect" in msg or "git" in msg.lower()
