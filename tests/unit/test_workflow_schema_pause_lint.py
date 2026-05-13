"""Tests for the workflow schema linter (lib/workflow_lint.py).

Origin: T-1807 (dispatch-safety slice 3). Pins the three pause-field rules
plus regression coverage for the legacy schema rules extracted from bin/fw.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FRAMEWORK_ROOT / "lib"))

from workflow_lint import lint_workflows  # noqa: E402


def _write_workflow(root: Path, name: str, body: str) -> Path:
    """Drop a workflow yaml into a synthetic project root."""
    wf_dir = root / ".context" / "project" / "workflows"
    wf_dir.mkdir(parents=True, exist_ok=True)
    path = wf_dir / name
    path.write_text(body)
    return path


def _make_valid_dispatch(extra: str = "") -> str:
    """Return a minimally-valid non-inline dispatch workflow."""
    return (
        "task_type: synthetic\n"
        "worker_kind: TermLink\n"
        "model: sonnet\n"
        "effort: medium\n"
        "prompt_template: prompts/sample.md\n"
        "allowed_tools: [Read]\n"
        "cost_cap_usd: 1.0\n"
        "cwd: $PROJECT_ROOT\n"
        + extra
    )


def _setup_with_template(root: Path, name: str = "default.yaml", extra: str = "") -> None:
    """Create a workflow + the prompt_template file it references so the
    non-pause checks don't fire."""
    (root / "prompts").mkdir(exist_ok=True)
    (root / "prompts" / "sample.md").write_text("sample prompt body\n")
    _write_workflow(root, name, _make_valid_dispatch(extra))


def _levels(findings):
    """Project (level, message) tuples to (level, prefix-of-message) for assertions."""
    return [(lvl, msg) for lvl, msg in findings if lvl != "COUNT"]


# ---------------------------------------------------------------------------
# Existing schema rules — regression coverage after extraction.
# ---------------------------------------------------------------------------


def test_existing_repo_workflows_still_lint_clean():
    """Real workflows in this repo must remain clean after refactor."""
    findings = lint_workflows(FRAMEWORK_ROOT)
    errors = [m for lvl, m in findings if lvl == "ERROR"]
    assert errors == [], f"existing workflows regressed: {errors}"


def test_minimal_valid_workflow_passes(tmp_path):
    _setup_with_template(tmp_path)
    assert _levels(lint_workflows(tmp_path)) == []


def test_missing_task_type_errors(tmp_path):
    (tmp_path / "prompts").mkdir()
    (tmp_path / "prompts" / "sample.md").write_text("x\n")
    _write_workflow(
        tmp_path, "default.yaml",
        "worker_kind: TermLink\nmodel: sonnet\neffort: medium\n"
        "prompt_template: prompts/sample.md\nallowed_tools: [Read]\n"
        "cost_cap_usd: 1.0\ncwd: $PROJECT_ROOT\n",
    )
    findings = _levels(lint_workflows(tmp_path))
    assert any("missing required key 'task_type'" in m for lvl, m in findings if lvl == "ERROR")


def test_invalid_worker_kind_errors(tmp_path):
    _setup_with_template(tmp_path)
    # Overwrite with bad worker_kind
    _write_workflow(tmp_path, "default.yaml", _make_valid_dispatch().replace(
        "worker_kind: TermLink", "worker_kind: bogus"
    ))
    findings = _levels(lint_workflows(tmp_path))
    assert any("worker_kind='bogus'" in m for lvl, m in findings if lvl == "ERROR")


# ---------------------------------------------------------------------------
# T-1807: allow_pause type rule.
# ---------------------------------------------------------------------------


def test_allow_pause_true_passes(tmp_path):
    _setup_with_template(tmp_path, extra="allow_pause: true\n")
    assert _levels(lint_workflows(tmp_path)) == []


def test_allow_pause_false_passes(tmp_path):
    _setup_with_template(tmp_path, extra="allow_pause: false\n")
    assert _levels(lint_workflows(tmp_path)) == []


def test_allow_pause_string_errors(tmp_path):
    """YAML 'yes' becomes True under safe_load; quoted 'true' stays string."""
    _setup_with_template(tmp_path, extra='allow_pause: "true"\n')
    findings = _levels(lint_workflows(tmp_path))
    assert any(
        lvl == "ERROR" and "allow_pause=" in m and "must be a YAML boolean" in m
        for lvl, m in findings
    ), f"expected allow_pause string ERROR; got: {findings}"


def test_allow_pause_int_errors(tmp_path):
    _setup_with_template(tmp_path, extra="allow_pause: 1\n")
    findings = _levels(lint_workflows(tmp_path))
    assert any(
        lvl == "ERROR" and "allow_pause=1" in m for lvl, m in findings
    ), f"expected allow_pause=1 ERROR; got: {findings}"


# ---------------------------------------------------------------------------
# T-1807: pause_threshold value rule.
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("threshold", ["low", "medium", "high"])
def test_pause_threshold_valid_values(tmp_path, threshold):
    _setup_with_template(tmp_path, extra=f"allow_pause: true\npause_threshold: {threshold}\n")
    assert _levels(lint_workflows(tmp_path)) == []


def test_pause_threshold_invalid_errors(tmp_path):
    _setup_with_template(
        tmp_path, extra="allow_pause: true\npause_threshold: catastrophic\n"
    )
    findings = _levels(lint_workflows(tmp_path))
    assert any(
        lvl == "ERROR" and "pause_threshold='catastrophic'" in m
        for lvl, m in findings
    ), f"expected threshold ERROR; got: {findings}"


# ---------------------------------------------------------------------------
# T-1807: pause_preamble path rule.
# ---------------------------------------------------------------------------


def test_pause_preamble_existing_file_passes(tmp_path):
    (tmp_path / "prompts" / "risk").mkdir(parents=True)
    (tmp_path / "prompts" / "risk" / "custom.md").write_text("custom preamble\n")
    _setup_with_template(
        tmp_path, extra="allow_pause: true\npause_preamble: prompts/risk/custom.md\n",
    )
    assert _levels(lint_workflows(tmp_path)) == []


def test_pause_preamble_missing_file_errors(tmp_path):
    _setup_with_template(
        tmp_path, extra="allow_pause: true\npause_preamble: prompts/risk/nowhere.md\n",
    )
    findings = _levels(lint_workflows(tmp_path))
    assert any(
        lvl == "ERROR" and "pause_preamble='prompts/risk/nowhere.md'" in m
        and "does not resolve" in m
        for lvl, m in findings
    ), f"expected preamble missing-file ERROR; got: {findings}"


def test_pause_preamble_non_string_errors(tmp_path):
    _setup_with_template(tmp_path, extra="allow_pause: true\npause_preamble: 42\n")
    findings = _levels(lint_workflows(tmp_path))
    assert any(
        lvl == "ERROR" and "pause_preamble=42" in m and "path string" in m
        for lvl, m in findings
    ), f"expected preamble type ERROR; got: {findings}"


# ---------------------------------------------------------------------------
# T-1807: dead-config WARN.
# ---------------------------------------------------------------------------


def test_dead_threshold_without_allow_pause_warns(tmp_path):
    _setup_with_template(tmp_path, extra="pause_threshold: high\n")
    findings = _levels(lint_workflows(tmp_path))
    assert any(
        lvl == "WARN" and "pause_threshold set but allow_pause is not true" in m
        for lvl, m in findings
    ), f"expected dead-config WARN; got: {findings}"


def test_dead_preamble_with_allow_pause_false_warns(tmp_path):
    (tmp_path / "prompts" / "risk").mkdir(parents=True)
    (tmp_path / "prompts" / "risk" / "custom.md").write_text("x\n")
    _setup_with_template(
        tmp_path, extra="allow_pause: false\npause_preamble: prompts/risk/custom.md\n",
    )
    findings = _levels(lint_workflows(tmp_path))
    assert any(
        lvl == "WARN" and "pause_preamble set but allow_pause is not true" in m
        for lvl, m in findings
    ), f"expected dead preamble WARN; got: {findings}"


def test_allow_pause_true_with_threshold_no_warn(tmp_path):
    _setup_with_template(
        tmp_path, extra="allow_pause: true\npause_threshold: medium\n",
    )
    findings = lint_workflows(tmp_path)
    warns = [m for lvl, m in findings if lvl == "WARN"]
    assert all("pause_" not in m for m in warns), f"unexpected pause-related WARN: {warns}"


def test_invalid_allow_pause_suppresses_dead_warn(tmp_path):
    """If allow_pause has the wrong type, the type ERROR is enough — don't
    pile on a dead-config WARN naming a field the operator may also have
    set deliberately. The ERROR is the actionable signal."""
    _setup_with_template(
        tmp_path, extra='allow_pause: "true"\npause_threshold: high\n',
    )
    findings = _levels(lint_workflows(tmp_path))
    pause_warns = [m for lvl, m in findings if lvl == "WARN" and "pause_threshold set but" in m]
    assert pause_warns == [], f"dead-config WARN should be suppressed; got: {pause_warns}"


# ---------------------------------------------------------------------------
# T-1807: inline workflows forbid pause fields.
# ---------------------------------------------------------------------------


def test_inline_workflow_forbids_allow_pause(tmp_path):
    _write_workflow(
        tmp_path, "design.yaml",
        "task_type: design\ninline: true\nallow_pause: true\n",
    )
    findings = _levels(lint_workflows(tmp_path))
    assert any(
        lvl == "ERROR" and "inline:true cannot co-exist" in m and "allow_pause" in m
        for lvl, m in findings
    ), f"expected inline-pause ERROR; got: {findings}"


def test_inline_workflow_forbids_pause_preamble(tmp_path):
    _write_workflow(
        tmp_path, "design.yaml",
        "task_type: design\ninline: true\npause_preamble: prompts/risk/x.md\n",
    )
    findings = _levels(lint_workflows(tmp_path))
    assert any(
        lvl == "ERROR" and "inline:true cannot co-exist" in m and "pause_preamble" in m
        for lvl, m in findings
    ), f"expected inline-preamble ERROR; got: {findings}"


def test_inline_workflow_clean(tmp_path):
    _write_workflow(tmp_path, "design.yaml", "task_type: design\ninline: true\n")
    findings = _levels(lint_workflows(tmp_path))
    # The default.yaml-missing WARN fires (count > 0, no default.yaml).
    errors = [m for lvl, m in findings if lvl == "ERROR"]
    assert errors == [], f"clean inline workflow regressed: {errors}"


# ---------------------------------------------------------------------------
# Count + default.yaml WARN sanity.
# ---------------------------------------------------------------------------


def test_count_reported(tmp_path):
    _setup_with_template(tmp_path, name="default.yaml")
    _write_workflow(tmp_path, "second.yaml", _make_valid_dispatch())
    findings = lint_workflows(tmp_path)
    count_entries = [m for lvl, m in findings if lvl == "COUNT"]
    assert count_entries == ["2"], f"expected COUNT=2; got: {count_entries}"


def test_missing_default_warns(tmp_path):
    _setup_with_template(tmp_path, name="other.yaml")
    findings = lint_workflows(tmp_path)
    assert any(
        lvl == "WARN" and "default.yaml missing" in m for lvl, m in findings
    )
