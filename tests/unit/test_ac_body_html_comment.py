"""T-1763: Regression tests for HTML-comment leakage in AC body parser.

`web.blueprints.tasks._parse_acceptance_criteria` must NOT pull the
default template's `<!-- Example: ... -->` block into a real AC body.
Before T-1763, the body collector ignored HTML-comment state, so:

  - [ ] [REVIEW] Real AC
    **Steps:** 1. Real step
    **Expected:** Real outcome
    **If not:** Real fallback

  <!-- Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:** 1. Open https://example.com/dashboard
         **Expected:** All panels visible
         **If not:** Screenshot the broken panel
  -->

…rendered the example's Steps/Expected/If-not for the real AC, with a
literal trailing `-->` leaking into "If not".

Symmetric pattern to L-097 (T-204 audit.sh CTL-013 parser).
"""

from __future__ import annotations

from web.blueprints.tasks import _parse_acceptance_criteria


REAL_AC_BODY_FOLLOWED_BY_TEMPLATE_EXAMPLE = """## Acceptance Criteria

### Agent
- [x] Some agent thing

### Human
- [ ] [REVIEW] Confirm gate refusal message is actionable
  **Steps:**
  1. cd /tmp/scratch && fw task update T-FAKE --status work-completed
  2. Read the refusal message
  **Expected:** Message names the missing deliverable and shows bypass syntax
  **If not:** Note which information was missing or unclear


<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

bash -n lib/whatever.sh
"""


def test_html_comment_example_does_not_leak_into_real_ac():
    """The real AC's Steps/Expected/If-not must survive — not be overwritten
    by the template example's content from inside the HTML comment."""
    acs = _parse_acceptance_criteria(REAL_AC_BODY_FOLLOWED_BY_TEMPLATE_EXAMPLE)
    human_acs = [ac for ac in acs if ac["section"] == "human"]
    assert len(human_acs) == 1, f"Expected 1 Human AC, got {len(human_acs)}: {human_acs}"
    ac = human_acs[0]
    assert "gate refusal message is actionable" in ac["text"]

    # Steps must contain the REAL command, not the example URL
    steps_html = "\n".join(ac["steps"])
    assert "T-FAKE" in steps_html, f"Real Steps lost — got: {steps_html!r}"
    assert "example.com/dashboard" not in steps_html, (
        f"Template example leaked into Steps: {steps_html!r}"
    )
    assert "panels load within 2 seconds" not in steps_html, (
        f"Template example leaked into Steps: {steps_html!r}"
    )

    # Expected must be the real one
    assert "missing deliverable" in ac["expected"], (
        f"Real Expected lost — got: {ac['expected']!r}"
    )
    assert "panels visible" not in ac["expected"], (
        f"Template example leaked into Expected: {ac['expected']!r}"
    )

    # If-not must be the real one
    assert "missing or unclear" in ac["if_not"], (
        f"Real If-not lost — got: {ac['if_not']!r}"
    )
    assert "Screenshot the broken panel" not in ac["if_not"], (
        f"Template example leaked into If-not: {ac['if_not']!r}"
    )

    # Trailing comment-close must not appear in any rendered field
    assert "-->" not in steps_html
    assert "-->" not in ac["expected"]
    assert "-->" not in ac["if_not"]


AC_FOLLOWED_ONLY_BY_COMMENT = """## Acceptance Criteria

### Human
- [ ] [REVIEW] Plain AC, no body

<!-- Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:** 1. Do thing
         **Expected:** Things work
         **If not:** File a bug
-->

## Verification
"""


def test_ac_body_with_only_html_comment_renders_empty():
    """An AC with no real body, followed only by a template example
    HTML comment, must render with empty Steps/Expected/If-not — never
    pulling the comment content in."""
    acs = _parse_acceptance_criteria(AC_FOLLOWED_ONLY_BY_COMMENT)
    human_acs = [ac for ac in acs if ac["section"] == "human"]
    assert len(human_acs) == 1
    ac = human_acs[0]
    assert ac["steps"] == []
    assert ac["expected"] == ""
    assert ac["if_not"] == ""


AC_NO_COMMENT_NO_REGRESSION = """## Acceptance Criteria

### Human
- [ ] [REVIEW] Real AC with normal body
  **Steps:**
  1. Step one
  2. Step two
  **Expected:** Outcome
  **If not:** Fallback

## Verification
"""


def test_ac_without_comment_renders_unchanged():
    """No regression for the common case — AC with a normal body and
    no trailing HTML comment renders the way it always has."""
    acs = _parse_acceptance_criteria(AC_NO_COMMENT_NO_REGRESSION)
    human_acs = [ac for ac in acs if ac["section"] == "human"]
    assert len(human_acs) == 1
    ac = human_acs[0]
    steps_html = "\n".join(ac["steps"])
    assert "Step one" in steps_html
    assert "Step two" in steps_html
    assert "Outcome" in ac["expected"]
    assert "Fallback" in ac["if_not"]


SINGLE_LINE_HTML_COMMENT = """## Acceptance Criteria

### Human
- [ ] [REVIEW] Real AC
  **Steps:**
  1. Real step
  **Expected:** Real outcome
  **If not:** Real fallback

<!-- single-line comment with no example -->

## Verification
"""


def test_single_line_html_comment_does_not_swallow_subsequent_content():
    """Defensive: a single-line HTML comment between AC and ## section
    must not break parsing. Verifies the body-loop's open-and-close-
    on-same-line path."""
    acs = _parse_acceptance_criteria(SINGLE_LINE_HTML_COMMENT)
    human_acs = [ac for ac in acs if ac["section"] == "human"]
    assert len(human_acs) == 1
    assert "Real step" in "\n".join(human_acs[0]["steps"])
    assert "Real outcome" in human_acs[0]["expected"]
    assert "Real fallback" in human_acs[0]["if_not"]
