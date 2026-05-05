"""T-1748 / T-1727 forward work — parse_verdict_envelope hardening.

Pins the regex-fallback contract for the v0.5 escalation-scan parser:

    1. Strict YAML path unchanged (160/170 happy-path verdicts must still parse).
    2. Sloppy LLM output (unquoted colon in rationale, missing closing fence,
       no fence at all) now extracts a verdict via regex fallback instead of
       collapsing to PARSE-FAIL.
    3. Verdict is constrained to {real_symptom_fix, false_positive, defer} on
       BOTH paths — regex fallback AND YAML path — so a rationale starting with
       "verdict: maybe" cannot leak through as a real verdict.
    4. Truly unsalvageable inputs (no verdict word anywhere) still return {}.

Origin: T-1727 30-day backlog run produced 10/170 = 5.9% PARSE-FAIL. The
disagreement-rate report names this as v1 promotion forward work — T-1748
implements it directly so the next cron firing produces a tighter signal.
"""

from __future__ import annotations

import importlib.util
from pathlib import Path

import pytest

# The tool ships as `tools/escalation-scan-v0.5.py` — the dot in the filename
# blocks normal `import`, so load via spec for testing.
TOOL_PATH = Path(__file__).resolve().parents[2] / "tools" / "escalation-scan-v0.5.py"


@pytest.fixture(scope="module")
def parser_module():
    spec = importlib.util.spec_from_file_location("v05_tool", TOOL_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# ---------------------------------------------------------------------------
# A2 — happy path unchanged (regression pin)
# ---------------------------------------------------------------------------


def test_strict_yaml_happy_path(parser_module):
    text = """Here is my analysis.

```yaml
verdict: real_symptom_fix
rationale: The task title and body indicate a true symptom fix without RCA
confidence: 0.85
```

Done."""
    out = parser_module.parse_verdict_envelope(text)
    assert out["verdict"] == "real_symptom_fix"
    assert out["confidence"] == 0.85
    assert "symptom fix" in out["rationale"]


def test_strict_yaml_false_positive(parser_module):
    text = """```yaml
verdict: false_positive
rationale: Refactor not a fix
confidence: 0.95
```"""
    out = parser_module.parse_verdict_envelope(text)
    assert out["verdict"] == "false_positive"
    assert out["confidence"] == 0.95


def test_strict_yaml_defer(parser_module):
    text = """```yaml
verdict: defer
rationale: Insufficient context
confidence: 0.5
```"""
    out = parser_module.parse_verdict_envelope(text)
    assert out["verdict"] == "defer"


# ---------------------------------------------------------------------------
# A1 — sloppy outputs that previously yielded PARSE-FAIL now succeed
# ---------------------------------------------------------------------------


def test_unquoted_colon_in_rationale_falls_back_to_regex(parser_module):
    """The exact 5.9% failure mode from T-1727 — unquoted colon aborts yaml."""
    text = """```yaml
verdict: real_symptom_fix
rationale: This is a fix: a clear bug response without RCA explanation
confidence: 0.85
```"""
    out = parser_module.parse_verdict_envelope(text)
    assert out["verdict"] == "real_symptom_fix", (
        f"unquoted colon should now extract via regex, got {out!r}"
    )
    assert out["confidence"] == 0.85


def test_missing_closing_fence_extracts(parser_module):
    text = """```yaml
verdict: false_positive
rationale: Title is misleading
confidence: 0.92"""
    out = parser_module.parse_verdict_envelope(text)
    assert out["verdict"] == "false_positive"


def test_no_fence_at_all_extracts_via_regex(parser_module):
    text = """The task is a refactor, not a bug fix.
verdict: false_positive
confidence: 0.88
rationale: Title contains 'fix' but body shows refactor work"""
    out = parser_module.parse_verdict_envelope(text)
    assert out["verdict"] == "false_positive"
    assert out["confidence"] == 0.88


def test_verdict_with_quoted_value(parser_module):
    text = 'verdict: "real_symptom_fix"\nconfidence: 0.7'
    out = parser_module.parse_verdict_envelope(text)
    assert out["verdict"] == "real_symptom_fix"
    assert out["confidence"] == 0.7


# ---------------------------------------------------------------------------
# A4 — verdict constrained to known words on BOTH paths
# ---------------------------------------------------------------------------


def test_invalid_verdict_word_returns_empty_via_regex(parser_module):
    text = "verdict: maybe\nconfidence: 0.5"
    out = parser_module.parse_verdict_envelope(text)
    assert out == {}, f"verdict 'maybe' must not leak through, got {out!r}"


def test_invalid_verdict_word_in_yaml_returns_empty(parser_module):
    """Even when YAML parses, an invalid verdict word must not leak."""
    text = """```yaml
verdict: maybe
rationale: Unsure
confidence: 0.3
```"""
    out = parser_module.parse_verdict_envelope(text)
    assert out == {}, f"YAML-parsed verdict 'maybe' must not leak, got {out!r}"


def test_verdict_word_inside_rationale_does_not_leak(parser_module):
    """A rationale that *mentions* a verdict word must not be captured as the verdict."""
    text = """```yaml
verdict: foo_bar
rationale: This task involves a real_symptom_fix concept
confidence: 0.8
```"""
    out = parser_module.parse_verdict_envelope(text)
    # YAML path rejects (verdict=foo_bar invalid), then regex fallback runs on
    # full text. The regex requires `verdict:` followed by a valid word —
    # `verdict: foo_bar` does not match. The mention inside rationale should
    # not be captured because the regex anchors on `verdict:`.
    # However the rationale line "rationale: This task involves a real_symptom_fix..."
    # could match if regex is too permissive. Pin: it must not.
    assert out.get("verdict") != "real_symptom_fix" or out.get("verdict") == "", (
        f"verdict word inside rationale leaked: {out!r}"
    )


# ---------------------------------------------------------------------------
# A3 — true unsalvageable inputs still PARSE-FAIL
# ---------------------------------------------------------------------------


def test_empty_string_returns_empty(parser_module):
    assert parser_module.parse_verdict_envelope("") == {}


def test_no_verdict_anywhere_returns_empty(parser_module):
    text = """The model wrote some prose about the task but never gave a verdict.
This is unsalvageable for v0.5 triage purposes."""
    assert parser_module.parse_verdict_envelope(text) == {}


def test_garbage_yaml_with_no_verdict_returns_empty(parser_module):
    text = """```yaml
not: a verdict
something: else
broken: : :
```"""
    out = parser_module.parse_verdict_envelope(text)
    assert out == {}, f"garbage yaml without verdict must PARSE-FAIL, got {out!r}"


# ---------------------------------------------------------------------------
# Confidence clamping (defensive)
# ---------------------------------------------------------------------------


def test_confidence_clamped_to_unit_interval(parser_module):
    text = "verdict: defer\nconfidence: 1.5"
    out = parser_module.parse_verdict_envelope(text)
    assert out["verdict"] == "defer"
    assert 0.0 <= out["confidence"] <= 1.0


def test_negative_confidence_clamped_to_zero(parser_module):
    text = "verdict: defer\nconfidence: -0.3"
    out = parser_module.parse_verdict_envelope(text)
    assert out["confidence"] == 0.0
