"""T-1390 (F4 fix): Unit tests for _extract_rationale_from_recommendation.

Guards against regression of the "Rationale: Recommendation: GO\\n\\nRationale: ..."
double-prefix bug observed on T-1284 and 60+ other decided inceptions (T-1388 F4).
"""
import sys
from pathlib import Path

# Ensure repo root importable
REPO_ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(REPO_ROOT))

from web.blueprints.inception import _extract_rationale_from_recommendation, _extract_recommendation_stance


def test_structured_recommendation_extracts_rationale_body_only():
    """Structured Rec/Rat/Evidence format — returns only the Rationale body."""
    rec = """**Recommendation:** GO

**Rationale:** The current approach fails three directives. The fix is
bounded and reversible.

**Evidence:**
- Finding 1
- Finding 2

See: docs/reports/T-XXX.md"""
    out = _extract_rationale_from_recommendation(rec)
    assert "Recommendation:" not in out, (
        "Extracted rationale must not contain the 'Recommendation:' header"
    )
    assert "Evidence:" not in out, (
        "Extracted rationale must not contain the Evidence section"
    )
    assert "See:" not in out, (
        "Trailing 'See:' marker must not leak into rationale"
    )
    assert "fails three directives" in out
    assert "bounded and reversible" in out


def test_rationale_with_no_evidence_section_extracts_cleanly():
    """Rationale without trailing Evidence section — extracts to end."""
    rec = """**Recommendation:** NO-GO

**Rationale:** Too expensive; existing primitives cover the cases."""
    out = _extract_rationale_from_recommendation(rec)
    assert out.startswith("Too expensive")
    assert "Recommendation:" not in out


def test_unstructured_recommendation_falls_back_to_full_body():
    """Free-form recommendation without markers — returns stripped full body."""
    rec = """Just a plain-text rationale without structured markers. Worth doing."""
    out = _extract_rationale_from_recommendation(rec)
    assert out == "Just a plain-text rationale without structured markers. Worth doing."


def test_bold_markers_stripped_in_fallback():
    """Even in fallback, ** markers are removed."""
    rec = "Some **emphasised** thought without structure."
    out = _extract_rationale_from_recommendation(rec)
    assert "**" not in out
    assert "emphasised" in out


def test_empty_recommendation_returns_empty_string():
    """No Recommendation section — empty string (no crash)."""
    assert _extract_rationale_from_recommendation("") == ""
    assert _extract_rationale_from_recommendation(None) == ""


def test_multiparagraph_rationale_preserved():
    """Rationale that spans multiple paragraphs — all paragraphs included."""
    rec = """**Recommendation:** GO

**Rationale:** First paragraph explaining the fix.

Second paragraph with additional context.

**Evidence:**
- Finding"""
    out = _extract_rationale_from_recommendation(rec)
    assert "First paragraph" in out
    assert "Second paragraph" in out
    assert "Evidence" not in out
    assert "Finding" not in out


def test_rationale_with_build_decomposition_block_stops_at_build():
    """Real-world T-1388 shape: Rationale followed by Build: marker — stops at Build."""
    rec = """**Recommendation:** GO (S-broad).

**Rationale:** Three frictions compound into a broken UX.

**Evidence:**
- Finding

**Build decomposition (after GO):** B1 backend, B2 template, ..."""
    out = _extract_rationale_from_recommendation(rec)
    assert "Three frictions compound" in out
    assert "B1 backend" not in out
    assert "Evidence" not in out


# T-1391 (B3): recommendation stance extraction

def test_stance_extracts_go_from_structured_recommendation():
    rec = "**Recommendation:** GO\n\n**Rationale:** ..."
    assert _extract_recommendation_stance(rec) == "go"


def test_stance_extracts_no_go_including_hyphen_and_underscore():
    assert _extract_recommendation_stance("**Recommendation:** NO-GO\n\n...") == "no-go"
    assert _extract_recommendation_stance("**Recommendation:** NO_GO\n\n...") == "no-go"


def test_stance_extracts_defer():
    assert _extract_recommendation_stance("**Recommendation:** DEFER — need more data") == "defer"


def test_stance_handles_trailing_qualifiers():
    """Real-world T-1388 shape: 'GO (S-broad scope per user selection).' should still yield 'go'."""
    rec = "**Recommendation:** GO (S-broad scope).\n\n**Rationale:** ..."
    assert _extract_recommendation_stance(rec) == "go"


def test_stance_returns_none_on_unstructured():
    assert _extract_recommendation_stance("just free-form text") is None
    assert _extract_recommendation_stance("") is None
    assert _extract_recommendation_stance(None) is None
