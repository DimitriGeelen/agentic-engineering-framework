"""T-2682: the map ``doc`` comes from a LEADING, non-boilerplate comment only.

Origin: ``parse_map`` took the first comment child of ``<bpmn:definitions>`` with
no positional or content guard. Every generated file ends with the emitter's own
``BPMN DI (visual layout) omitted…`` trailer, so whenever a map's real doc comment
was missing the reader silently adopted that trailer as the map's semantic doc —
the field read plausible-and-wrong rather than empty.

Two failure legs, both observed live before the fix:

1. **Positional** — the designer's save path drops the leading doc comment
   (confirmed on draft-knowledge-leveling v5→v6 and draft-trigger-handling v1→v2).
   The trailing DI comment was then adopted in its place.
2. **Laundering** — once adopted, ``generate`` re-emitted the trailer in LEADING
   position, so the next read could not tell corruption from authored doc.
   aef-audit-cron and aef-session-lifecycle reached the promoted corpus this way.

Leg 2 is why the positional guard alone is insufficient: after one derive→generate
cycle the boilerplate *is* leading. Both guards are load-bearing.
"""

import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tools"))

import corpus_spec  # noqa: E402

BODY = (
    '<bpmn:collaboration id="Collaboration_x">'
    '<bpmn:participant id="Pool_x" name="pool" processRef="Process_x"/>'
    "</bpmn:collaboration>"
    '<bpmn:process id="Process_x" isExecutable="true">'
    '<bpmn:extensionElements><aef:workflowMeta id="m" version="1" '
    'schemaVersion="2" title="m" tier_default="1"/></bpmn:extensionElements>'
    "</bpmn:process>"
)
OPEN = (
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL" '
    'xmlns:aef="http://anchorpoint.framework/aef/extensions" id="Definitions_x" '
    'targetNamespace="https://aef.anchorpoint.dev/workflows">'
)
CLOSE = "</bpmn:definitions>"

REAL_DOC = "designer-corpus D9: what this map actually means."
TRAILER = "BPMN DI (visual layout) omitted in this demo; AEF generates it from node coordinates"


def _doc(xml):
    """Raw doc as parsed. Note: parse_map rstrips each line but preserves LEADING
    whitespace, so ``<!-- text -->`` yields ``" text"``. That is the real contract
    (generate re-emits with ``.strip()``, so round-trip identity is unaffected);
    content assertions below strip, and one test pins the verbatim behaviour."""
    return corpus_spec.parse_map(xml).get("doc")


def _doc_text(xml):
    d = _doc(xml)
    return None if d is None else d.strip()


def test_leading_doc_comment_is_adopted():
    assert _doc_text(f"{OPEN}<!-- {REAL_DOC} -->{BODY}{CLOSE}") == REAL_DOC


def test_leading_whitespace_is_preserved_verbatim():
    """Pinned because generate() strips on emit — if the reader ever started
    stripping too, that asymmetry would be invisible until a diff disagreed."""
    assert _doc(f"{OPEN}<!-- {REAL_DOC} -->{BODY}{CLOSE}") == f" {REAL_DOC}"


def test_trailing_comment_is_never_adopted_as_doc():
    """The designer-save failure leg: real doc gone, only the DI trailer remains."""
    assert _doc(f"{OPEN}{BODY}<!-- {TRAILER} -->{CLOSE}") is None


def test_leading_boilerplate_is_rejected_not_laundered():
    """The laundering leg: a prior bad read re-emitted the trailer in doc position."""
    assert _doc(f"{OPEN}<!-- {TRAILER} -->{BODY}{CLOSE}") is None


def test_real_doc_survives_alongside_the_di_trailer():
    """The healthy shape every generated file has: doc leading, trailer at the end."""
    xml = f"{OPEN}<!-- {REAL_DOC} -->{BODY}<!-- {TRAILER} -->{CLOSE}"
    assert _doc_text(xml) == REAL_DOC


def test_no_comments_at_all_yields_no_doc():
    assert _doc(f"{OPEN}{BODY}{CLOSE}") is None


def test_doc_absent_means_key_absent_not_empty_string():
    """Absence must be detectable — a future doc-presence check keys on the missing
    key, so an empty string would silently satisfy it."""
    assert "doc" not in corpus_spec.parse_map(f"{OPEN}{BODY}{CLOSE}")


def test_boilerplate_match_is_prefix_based_not_exact():
    """Tail wording drifts (demo phrasing, generator notes); the guard must not
    reopen on a variant."""
    variant = f"{TRAILER} — regenerated 2026"
    assert _doc(f"{OPEN}<!-- {variant} -->{BODY}{CLOSE}") is None


def test_authored_doc_merely_mentioning_di_is_kept():
    """Guard is anchored at the start; a doc that discusses DI is still a doc."""
    authored = "This map omits BPMN DI (visual layout) omitted-style trailers on purpose."
    assert _doc_text(f"{OPEN}<!-- {authored} -->{BODY}{CLOSE}") == authored


# --- T-2895: "nothing but the trailer", not "starts with the trailer" -------


def test_rationale_continuing_past_the_trailer_survives():
    """The T-406 mirror. `startswith` alone destroys a real rationale that merely
    OPENS with the trailer's words. Measured on our own aef-task-lifecycle text at
    tests/fixtures/832-outbound/t406-incidental-leading-boilerplate.bpmn, which read
    back empty before this change."""
    comment = f"{TRAILER}\ndesigner-corpus D1 (arc-014, T-2555) — the real rationale."
    got = _doc_text(f"{OPEN}<!-- {comment} -->{BODY}{CLOSE}")
    assert got is not None
    assert "the real rationale" in got


def test_recovered_doc_keeps_the_trailer_line_rather_than_editing_it_out():
    """Preserve, never delete. Stripping the leading line would be tidier and would
    mangle the case this exists to protect — a genuine rationale whose own first
    line happens to begin with those words. The whole defect class is silent
    deletion; the fix must not introduce a smaller version of it."""
    comment = f"{TRAILER}\nsecond line of authored text"
    got = _doc_text(f"{OPEN}<!-- {comment} -->{BODY}{CLOSE}")
    assert got.strip().startswith("BPMN DI")
    assert "second line of authored text" in got


def test_trailer_only_still_suppresses_across_known_variants():
    """T-2682's protection is load-bearing on documents already promoted
    (aef-audit-cron, aef-session-lifecycle). Narrowing must not reopen it — all
    three wordings live in the corpus today."""
    for variant in (
        "BPMN DI (visual layout) omitted in this demo; AEF generates it from node coordinates",
        "BPMN DI (visual layout) omitted in this authored fixture; AEF generates it from node coordinates",
        "BPMN DI (visual layout) omitted; AEF generates it from node coordinates",
    ):
        assert _doc(f"{OPEN}<!-- {variant} -->{BODY}{CLOSE}") is None, variant


def test_trailing_blank_lines_do_not_defeat_suppression():
    """A blank line is not content; whitespace must not smuggle boilerplate in."""
    assert _doc(f"{OPEN}<!-- {TRAILER}\n\n   \n -->{BODY}{CLOSE}") is None


def test_suppression_does_not_consult_producer_identity():
    """Do not 'correct' this to match 832's T-406 fix. Their producer gate works
    because the boilerplate is THEIR text; a laundered document on OUR side carries
    our own exporter stamp (T-2891), so identity gating would preserve exactly the
    corruption this suppresses. Pinned so the reasoning survives the next reader."""
    import inspect

    src = inspect.getsource(corpus_spec._is_boilerplate_comment)
    body = src.split('"""')[-1]
    assert "exporter" not in body
    assert "producer" not in body
