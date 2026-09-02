"""T-3252: corpus-wide measurement of text loss in extract_recommendation.

Walks every task under .tasks/{active,completed}, re-derives the same marker
spans extract_recommendation uses internally (_REC_MARKER_RE over the raw
section text — not a naive per-line split, which mis-scores an author's bold
marker that happens to wrap across a hard-wrapped line break), and checks
that each span's flattened text is present somewhere in the function's actual
returned fields. A span not found anywhere in the output is a dropped
fragment.

Usage: python3 docs/reports/T-3252-measure-recommendation-loss.py
Reproduce the pre-fix baseline: git stash push -- web/shared.py && \
  python3 docs/reports/T-3252-measure-recommendation-loss.py && git stash pop
"""
import sys, os, re as re_mod, glob

sys.path.insert(0, os.getcwd())
from web.shared import extract_recommendation, _REC_MARKER_RE


def flatten(s: str) -> str:
    s = re_mod.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", s)   # [text](url) -> text
    s = re_mod.sub(r"[`*_]", "", s)                        # emphasis/code markers
    # An author's leading separator dash on a verdict line is intentionally
    # stripped by the fix (the renderer supplies its own) — normalise dashes
    # used as standalone separators out of the comparison so that formatting
    # choice isn't scored as data loss.
    s = re_mod.sub(r"(?:^|\s)[—–-](?:\s|$)", " ", s)
    s = re_mod.sub(r"\s+", " ", s).strip()
    return s.lower()


def measure(files):
    bodies_with_section = 0
    lossy_cards = 0
    dropped_fragments = 0
    examples = []
    for f in files:
        body = open(f, encoding="utf-8", errors="replace").read()
        rec = extract_recommendation(body)
        raw = rec["raw"]
        if not raw.strip():
            continue
        bodies_with_section += 1

        corpus_parts = [
            flatten(rec["rationale"]), flatten(rec["evidence"]),
            flatten(rec.get("other", "")),
            flatten(rec["verdict"] + " " + rec.get("verdict_note", "")),
        ]

        # Re-derive the same spans extract_recommendation iterates over,
        # rather than a naive per-line split — a bold marker that wraps
        # across a line break is one span to the real tokenizer, and must be
        # one span here too, or the measurement disagrees with the function
        # it's measuring for reasons that have nothing to do with data loss.
        matches = list(_REC_MARKER_RE.finditer(raw))
        chunks = []
        preamble = (raw[:matches[0].start()] if matches else raw).strip()
        if preamble:
            chunks.append(preamble)
        for idx, mk in enumerate(matches):
            start = mk.end()
            end = matches[idx + 1].start() if idx + 1 < len(matches) else len(raw)
            span_text = raw[start:end].strip()
            if span_text:
                chunks.append(span_text)

        card_dropped = []
        for chunk in chunks:
            flat = flatten(chunk)
            if len(flat) < 25:
                continue
            if not any(flat in part for part in corpus_parts):
                card_dropped.append(chunk.strip())
        if card_dropped:
            lossy_cards += 1
            dropped_fragments += len(card_dropped)
            examples.append((f, card_dropped))
    return bodies_with_section, lossy_cards, dropped_fragments, examples


if __name__ == "__main__":
    files = glob.glob(".tasks/active/T-*.md") + glob.glob(".tasks/completed/T-*.md")
    bws, lc, df, examples = measure(files)
    print("bodies_with_section:", bws)
    print("lossy_cards:", lc)
    print("dropped_fragments:", df)
    for f, frags in examples:
        print(f)
        for frag in frags:
            print("  ->", frag[:160].replace("\n", " "))
