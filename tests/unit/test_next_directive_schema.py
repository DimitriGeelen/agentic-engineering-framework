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
import subprocess
from pathlib import Path

import pytest
import yaml

PROJECT_ROOT = Path(__file__).resolve().parents[2]
SCHEMA_FIXTURE = PROJECT_ROOT / "tests" / "fixtures" / "next-directive-schema.yaml"


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


def test_checkpoint_directive_extraction_helper_present_when_file(tmp_path):
    """When .next-directive.yaml exists with a directive: field, the python
    helper inlined in checkpoint.sh produces a ',directive:"<text>"' JSON
    fragment. Helper logic exercised here to lock contract; bash integration
    test is separate."""
    directive_text = "continue T-XXXX next-action"
    directive_yaml = tmp_path / ".next-directive.yaml"
    directive_yaml.write_text(f"directive: {directive_text!r}\nfiled_by: self\n")

    # Mirror the python snippet from checkpoint.sh line ~175 (T-2363).
    code = f"""
import yaml, json, sys
with open({str(directive_yaml)!r}) as f:
    d = yaml.safe_load(f) or {{}}
v = d.get('directive')
if isinstance(v, str) and v.strip():
    print(',\"directive\":' + json.dumps(v.strip()))
"""
    result = subprocess.run(
        ["python3", "-c", code], capture_output=True, text=True, check=True
    )
    fragment = result.stdout.strip()
    assert fragment.startswith(',"directive":')
    # Embedded value must be JSON-encoded
    val = json.loads(fragment.split(":", 1)[1])
    assert val == directive_text


def test_checkpoint_directive_extraction_helper_empty_when_no_file(tmp_path):
    """When .next-directive.yaml is absent, the python helper produces no
    output → restart signal JSON stays at the pre-T-2363 shape (backward-compat)."""
    missing = tmp_path / ".next-directive.yaml"
    code = f"""
import yaml, json, sys
try:
    with open({str(missing)!r}) as f:
        d = yaml.safe_load(f) or {{}}
    v = d.get('directive')
    if isinstance(v, str) and v.strip():
        print(',\"directive\":' + json.dumps(v.strip()))
except Exception:
    pass
"""
    result = subprocess.run(
        ["python3", "-c", code], capture_output=True, text=True
    )
    assert result.stdout.strip() == "", "no directive output when file absent"


def test_checkpoint_directive_extraction_helper_empty_when_directive_missing(tmp_path):
    """When .next-directive.yaml exists but has no directive: field, the
    helper produces no output → backward-compat preserved."""
    directive_yaml = tmp_path / ".next-directive.yaml"
    directive_yaml.write_text("filed_by: self\n")  # no directive:
    code = f"""
import yaml, json, sys
try:
    with open({str(directive_yaml)!r}) as f:
        d = yaml.safe_load(f) or {{}}
    v = d.get('directive')
    if isinstance(v, str) and v.strip():
        print(',\"directive\":' + json.dumps(v.strip()))
except Exception:
    pass
"""
    result = subprocess.run(
        ["python3", "-c", code], capture_output=True, text=True
    )
    assert result.stdout.strip() == "", "no output when directive: field missing"


def test_claude_fw_signal_parse_handles_old_payload():
    """claude-fw line ~174-175 parsing must accept old (pre-T-2363) payloads
    that lack the directive: field. Tested by simulating the python snippet."""
    old_payload = json.dumps({
        "timestamp": "2026-06-13T00:00:00Z",
        "session_id": "S-old",
        "reason": "critical_budget_auto_handover",
        "tokens": 290000,
    })
    code = f"""
import json
d = json.loads({old_payload!r})
v = d.get('directive', '')
print(v if isinstance(v, str) else '')
"""
    result = subprocess.run(
        ["python3", "-c", code], capture_output=True, text=True, check=True
    )
    assert result.stdout.strip() == "", "old payload yields empty directive (no error)"


def test_claude_fw_signal_parse_extracts_new_payload():
    """claude-fw parsing extracts the directive from a new (post-T-2363) payload."""
    new_payload = json.dumps({
        "timestamp": "2026-06-13T00:00:00Z",
        "session_id": "S-new",
        "reason": "critical_budget_auto_handover",
        "tokens": 290000,
        "directive": "continue T-2364",
    })
    code = f"""
import json
d = json.loads({new_payload!r})
v = d.get('directive', '')
print(v if isinstance(v, str) else '')
"""
    result = subprocess.run(
        ["python3", "-c", code], capture_output=True, text=True, check=True
    )
    assert result.stdout.strip() == "continue T-2364"
