"""T-2363 (T-2158 S1) — unit tests for the .next-directive.yaml schema.

Covers:
  - Schema fixture parses as valid YAML.
  - Directive field shape: string, non-empty.
  - Optional fields default-safe (absent OK).
  - Backward-compat: absent .next-directive.yaml → no directive field in
    the restart signal (the bash checkpoint code path is shell-exercised in
    the integration leg; here we cover the python helper logic shape only).
"""

import json
import re
import subprocess
from pathlib import Path

import pytest
import yaml

PROJECT_ROOT = Path(__file__).resolve().parents[2]
SCHEMA_FIXTURE = PROJECT_ROOT / "tests" / "fixtures" / "next-directive-schema.yaml"
CHECKPOINT = PROJECT_ROOT / "agents" / "context" / "checkpoint.sh"
CLAUDE_FW = PROJECT_ROOT / "bin" / "claude-fw"


# T-4380: the helpers below cut the SHIPPED python snippets out of checkpoint.sh
# and bin/claude-fw and run them. The tests used to run a copy written out in the
# test, which stayed green when the shipped snippet was broken or removed.
def _shipped_checkpoint_snippet(directive_file):
    """The `python3 -c "..."` body that checkpoint.sh runs to fold the directive
    into the restart signal, with its bash variable bound to `directive_file`."""
    src = CHECKPOINT.read_text()
    m = re.search(
        r'_directive_json=\$\(python3 -c "\n(.*?)\n" 2>/dev/null\) \|\| _directive_json=""',
        src, re.S)
    assert m, "directive snippet not found in checkpoint.sh - did it move?"
    code = m.group(1).replace("$_directive_file", str(directive_file)).replace('\\"', '"')
    assert "directive" in code
    return code


def _shipped_claude_fw_snippet(signal_file):
    """The `python3 -c "..."` one-liner bin/claude-fw runs to read the directive
    from the restart signal, with its bash variable bound to `signal_file`."""
    src = CLAUDE_FW.read_text()
    m = re.search(r'local_directive=\$\(python3 -c "(.*?)" 2>/dev/null\)', src, re.S)
    assert m, "directive reader not found in bin/claude-fw - did it move?"
    code = m.group(1).replace("$signal_file", str(signal_file))
    assert "json.load" in code
    return code


def test_schema_fixture_exists():
    assert SCHEMA_FIXTURE.is_file(), f"fixture missing at {SCHEMA_FIXTURE}"


def test_schema_fixture_parses_as_yaml():
    with SCHEMA_FIXTURE.open() as f:
        data = yaml.safe_load(f)
    assert isinstance(data, dict), "fixture should parse to a dict"
    assert "directive" in data
    assert "filed_by" in data
    assert "filed_at" in data


def test_schema_required_field_directive_is_string():
    with SCHEMA_FIXTURE.open() as f:
        data = yaml.safe_load(f)
    assert isinstance(data["directive"], str)
    assert data["directive"].strip(), "directive must be non-empty"


def test_schema_optional_fields_present_in_fixture():
    """Optional fields are documented in the fixture for operator reference,
    even though they are not required at write-time."""
    with SCHEMA_FIXTURE.open() as f:
        data = yaml.safe_load(f)
    # expires_at, iteration, max_iterations, tier_ceiling are optional but
    # documented in the fixture for completeness.
    for opt in ("expires_at", "iteration", "max_iterations", "tier_ceiling"):
        assert opt in data, f"optional field {opt} should be documented in fixture"


# KNOWN PRODUCTION BUG (found by T-4380 running the shipped snippet): since T-3989
# (b0758d0fc) the python in agents/context/checkpoint.sh has lost its indentation
# (`try:` is followed by an unindented `with`), so it is a SyntaxError. The 2>/dev/null
# swallows it and the restart signal never carries the directive. The test below
# is the regression test for the fix; strict xfail turns it into a failure the
# moment checkpoint.sh is repaired, so the marker gets removed with the fix.
@pytest.mark.xfail(strict=True, reason="checkpoint.sh directive snippet is a SyntaxError since T-3989")
def test_checkpoint_directive_extraction_helper_present_when_file(tmp_path):
    """When .next-directive.yaml exists with a directive: field, the python
    snippet in checkpoint.sh produces a ',directive:"<text>"' JSON fragment."""
    directive_text = "continue T-XXXX next-action"
    directive_yaml = tmp_path / ".next-directive.yaml"
    directive_yaml.write_text(f"directive: {directive_text!r}\nfiled_by: self\n")

    result = subprocess.run(
        ["python3", "-c", _shipped_checkpoint_snippet(directive_yaml)],
        capture_output=True, text=True, check=True,
    )
    fragment = result.stdout.strip()
    assert fragment.startswith(',"directive":')
    # Embedded value must be JSON-encoded
    val = json.loads(fragment.split(":", 1)[1])
    assert val == directive_text


def test_checkpoint_directive_extraction_helper_empty_when_no_file(tmp_path):
    """When .next-directive.yaml is absent, the shipped snippet produces no
    output -> restart signal JSON stays at the pre-T-2363 shape (backward-compat)."""
    missing = tmp_path / ".next-directive.yaml"
    result = subprocess.run(
        ["python3", "-c", _shipped_checkpoint_snippet(missing)],
        capture_output=True, text=True,
    )
    assert result.stdout.strip() == "", "no directive output when file absent"


def test_checkpoint_directive_extraction_helper_empty_when_directive_missing(tmp_path):
    """When .next-directive.yaml exists but has no directive: field, the
    shipped snippet produces no output -> backward-compat preserved."""
    directive_yaml = tmp_path / ".next-directive.yaml"
    directive_yaml.write_text("filed_by: self\n")  # no directive:
    result = subprocess.run(
        ["python3", "-c", _shipped_checkpoint_snippet(directive_yaml)],
        capture_output=True, text=True,
    )
    assert result.stdout.strip() == "", "no output when directive: field missing"


def test_claude_fw_signal_parse_handles_old_payload(tmp_path):
    """claude-fw's directive reader must accept old (pre-T-2363) payloads
    that lack the directive: field. Runs the shipped one-liner."""
    signal = tmp_path / ".restart-requested"
    signal.write_text(json.dumps({
        "timestamp": "2026-06-13T00:00:00Z",
        "session_id": "S-old",
        "reason": "critical_budget_auto_handover",
        "tokens": 290000,
    }))
    result = subprocess.run(
        ["python3", "-c", _shipped_claude_fw_snippet(signal)],
        capture_output=True, text=True, check=True,
    )
    assert result.stdout.strip() == "", "old payload yields empty directive (no error)"


def test_claude_fw_signal_parse_extracts_new_payload(tmp_path):
    """claude-fw's directive reader extracts the directive from a new
    (post-T-2363) payload. Runs the shipped one-liner."""
    signal = tmp_path / ".restart-requested"
    signal.write_text(json.dumps({
        "timestamp": "2026-06-13T00:00:00Z",
        "session_id": "S-new",
        "reason": "critical_budget_auto_handover",
        "tokens": 290000,
        "directive": "continue T-2364",
    }))
    result = subprocess.run(
        ["python3", "-c", _shipped_claude_fw_snippet(signal)],
        capture_output=True, text=True, check=True,
    )
    assert result.stdout.strip() == "continue T-2364"
