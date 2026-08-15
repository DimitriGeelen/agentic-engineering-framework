"""The chunker must never emit a chunk the embedder cannot swallow whole.

T-3010 / OBS-251. The embedder truncates at a hard 512 tokens (measured in T-3009,
`tools/measure_chunk_tokens.py`) and says nothing when it does — the row still looks
indexed. So a chunk over the cap is not "a big chunk", it is content that is in the
database and unreachable by search.

Two independent properties are pinned here:

  CAP     — no emitted chunk exceeds the budget, for any input shape.
  LOSSLESS— no input character is dropped on the way to a chunk.

They are separate because the pre-fix code violated each one in a different place:
the cap leaked through the oversized-paragraph path, and content was lost in the
heading-less fallback (`return [content[:max_chars]]`).

Every test here was observed RED against the pre-fix chunker before the fix landed.
"""

import re
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from web import embeddings as E  # noqa: E402


def _no_ws(s: str) -> str:
    return re.sub(r"\s+", "", s)


def _is_subsequence(needle: str, haystack: str) -> bool:
    """Every char of `needle` appears in `haystack`, in order (dupes allowed)."""
    it = iter(haystack)
    return all(c in it for c in needle)


def _assert_cap(chunks, cap, label):
    over = [(i, len(c)) for i, c in enumerate(chunks) if len(c) > cap]
    assert not over, (
        f"{label}: {len(over)} chunk(s) over the {cap}-char cap "
        f"(largest {max(n for _, n in over)}): {over[:5]}"
    )


def _assert_lossless(original, chunks, label):
    joined = _no_ws("".join(chunks))
    assert _is_subsequence(_no_ws(original), joined), (
        f"{label}: input characters were dropped "
        f"({len(_no_ws(original))} in, {len(joined)} out incl. overlap)"
    )


CAP = E.MAX_CHUNK_CHARS


# --------------------------------------------------------------------------
# CAP — the four shapes that leaked past the pre-fix cap
# --------------------------------------------------------------------------

def test_section_without_paragraph_breaks_is_capped():
    """The origin defect: one heading, one huge run of single-newline lines.

    `_chunk_content` split long sections on "\\n\\n" only, so a section with no
    blank lines produced exactly one paragraph -- appended whole, uncapped.
    This is the shape that produced the 170,873-char chunk in the real corpus.
    """
    body = "\n".join(f"line {i} of governance prose" for i in range(2000))
    content = f"# Heading\n\n{body}"
    chunks = E._chunk_content(content)
    _assert_cap(chunks, CAP, "no-paragraph-break section")
    _assert_lossless(content, chunks, "no-paragraph-break section")


def test_single_paragraph_longer_than_cap_is_split():
    """One paragraph bigger than the cap: nothing downstream split it further."""
    content = "# H\n\n" + ("governance " * 4000)
    chunks = E._chunk_content(content)
    _assert_cap(chunks, CAP, "oversized single paragraph")
    _assert_lossless(content, chunks, "oversized single paragraph")


def test_content_with_no_headings_is_capped_and_kept():
    """Heading-less content hit `return [content[:max_chars]]` -- silent loss."""
    content = "governance " * 4000          # no '#' anywhere
    chunks = E._chunk_content(content)
    _assert_cap(chunks, CAP, "heading-less content")
    _assert_lossless(content, chunks, "heading-less content")


def test_unbroken_run_with_no_whitespace_is_capped():
    """A base64/minified blob has no newline, no blank line, no space to split on.

    The last-resort split must be a hard character cut, or the cap cannot hold.
    """
    content = "A" * 40_000
    chunks = E._chunk_content(content)
    _assert_cap(chunks, CAP, "unbroken run")
    _assert_lossless(content, chunks, "unbroken run")


# --------------------------------------------------------------------------
# The cap must survive what build_index() prepends
# --------------------------------------------------------------------------

def test_cap_holds_after_title_and_overlap_are_prepended():
    """build_index embeds `title + "\\n\\n" + chunk`, and chunks already carry
    CHUNK_OVERLAP chars of the previous chunk. The budget is the *embedded* text,
    so both prefixes have to be reserved -- otherwise the cap is right in the
    chunker and wrong at the embedder, which is the only place it matters.
    """
    title = "A Fairly Long Document Title That Eats Into The Budget"
    body = "\n".join(f"line {i} governance prose here" for i in range(1500))
    content = f"# {title}\n\n{body}"
    chunks = E._chunk_content(content, reserve=len(title) + 2)
    embedded = [
        f"{title}\n\n{c}" if i > 0 else c for i, c in enumerate(chunks)
    ]
    _assert_cap(embedded, CAP, "embedded text (title + overlap + chunk)")


# --------------------------------------------------------------------------
# The budget must derive from the ceiling, not be a magic number
# --------------------------------------------------------------------------

def test_budget_derives_from_the_measured_ceiling():
    """T-3007 step B switches the model; the cap must follow the ceiling.

    Pinning the derivation rather than the value: a future model with a bigger
    context should move MAX_CHUNK_CHARS without anyone hunting for a literal.
    """
    assert E.EMBED_CONTEXT_TOKENS == 512, "T-3009 measured 512"
    assert 1.0 < E.CHARS_PER_TOKEN_FLOOR <= 2.01, (
        "must not exceed the measured minimum ratio (2.01), or the cap stops "
        "being a proof and becomes an average"
    )
    assert E.MAX_CHUNK_CHARS == int(
        E.EMBED_CONTEXT_TOKENS * E.CHARS_PER_TOKEN_FLOOR
    )


@pytest.mark.parametrize("shape", ["headings", "no-headings", "one-line", "blob"])
def test_cap_holds_across_shapes(shape):
    """Cheap breadth: the cap is a property of the function, not of nice input."""
    bodies = {
        "headings": "\n\n".join(f"## S{i}\n\n" + "word " * 300 for i in range(40)),
        "no-headings": "word " * 20_000,
        "one-line": "word " * 20_000,
        "blob": "x" * 60_000,
    }
    chunks = E._chunk_content(bodies[shape])
    _assert_cap(chunks, CAP, shape)
    _assert_lossless(bodies[shape], chunks, shape)
