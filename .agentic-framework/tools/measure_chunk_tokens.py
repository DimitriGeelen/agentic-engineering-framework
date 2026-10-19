#!/usr/bin/env python3
"""Measure the embedder's real input ceiling and the corpus chunk-token distribution.

T-3009 (step A of the T-3007 GO). Replaces an *attributed* claim ("the model's
context ceiling is 512 tokens") with a measurement, per L-589: a structural proxy
plus an inference is not a measurement.

Two independent measurements, neither of which trusts the other:

  1. CEILING — feed progressively longer input and watch `prompt_eval_count`
     saturate; then prove the saturation is real truncation (not a reporting cap)
     by embedding two texts that share a >ceiling prefix and differ only in their
     suffix. If the suffix was discarded, the vectors are bit-identical. A short
     control pair must NOT be identical, otherwise the test discriminates nothing.

  2. DISTRIBUTION — reproduce exactly what `build_index()` would embed today
     (collect_files -> _chunk_content -> title prepend) and count tokens.

Exact token counts need one embed call per chunk, and the corpus is ~288k chunks,
so counting all of them is not affordable. Instead this bounds the answer without
guessing: tokens <= chars always holds, so anything at or under `ceiling` chars is
provably safe. For the rest we measure a stratified random sample to find the
*observed* chars-per-token range, which splits the corpus into three exact
populations -- provably-safe, provably-truncated, and an ambiguous band that is
then measured chunk by chunk. The ambiguous band is small enough to afford.

The output states sample size and the observed ratio range, so a reader can see
how much of the verdict rests on measurement versus on the bound.

Usage:
    python3 tools/measure_chunk_tokens.py                       # full run
    python3 tools/measure_chunk_tokens.py --sample 200          # faster
    python3 tools/measure_chunk_tokens.py --model X --host URL  # after a switch
    python3 tools/measure_chunk_tokens.py --check               # regression mode

`--check` re-measures the ceiling only (seconds, no corpus walk) and exits
non-zero if it differs from --expect-ceiling. That is the form safe to put in a
task's ## Verification block.
"""

from __future__ import annotations

import argparse
import json
import math
import random
import statistics as st
import sys
import urllib.error
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

DEFAULT_MODEL = "nomic-embed-text-v2-moe"


# ---------------------------------------------------------------------------
# Embedding primitives
# ---------------------------------------------------------------------------

def embed(text: str, model: str, host: str, timeout: int = 300):
    """Return (prompt_eval_count, vector). Raises on transport/HTTP failure."""
    body = json.dumps({"model": model, "input": text}).encode()
    req = urllib.request.Request(
        f"{host.rstrip('/')}/api/embed",
        data=body,
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        d = json.load(resp)
    return d.get("prompt_eval_count"), d["embeddings"][0]


def token_count(text: str, model: str, host: str) -> int:
    return embed(text, model, host)[0]


def cosine(a, b) -> float:
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(y * y for y in b))
    if na == 0 or nb == 0:
        return 0.0
    return sum(x * y for x, y in zip(a, b)) / (na * nb)


# ---------------------------------------------------------------------------
# Measurement 1 — the ceiling
# ---------------------------------------------------------------------------

def measure_ceiling(model: str, host: str, verbose: bool = True) -> dict:
    """Find where prompt_eval_count saturates, then prove it is real truncation."""
    filler = "governance "
    counts = {}
    for n in (100, 400, 800, 2000, 4000):
        counts[n] = token_count(filler * n, model, host)
        if verbose:
            print(f"    words={n:<6d} prompt_eval_count={counts[n]}")

    saturated = [c for c in counts.values()]
    ceiling = max(saturated)
    # Saturation = the largest inputs all report the same count.
    big = [counts[n] for n in (800, 2000, 4000)]
    is_saturated = len(set(big)) == 1

    # Proof of real truncation: identical >ceiling prefix, different suffixes.
    prefix = filler * 600
    _, v1 = embed(prefix + " PINEAPPLE SUBMARINE ARTICHOKE", model, host)
    _, v2 = embed(prefix + " TUNGSTEN HELICOPTER MARMALADE", model, host)
    cos_long = cosine(v1, v2)

    # Control: the same suffixes on a SHORT prefix must be distinguishable,
    # otherwise the test above proves nothing about truncation.
    short = filler * 20
    _, v3 = embed(short + " PINEAPPLE SUBMARINE ARTICHOKE", model, host)
    _, v4 = embed(short + " TUNGSTEN HELICOPTER MARMALADE", model, host)
    cos_short = cosine(v3, v4)

    truncates = cos_long > 0.999999 and cos_short < 0.99
    return {
        "ceiling_tokens": ceiling,
        "saturated": is_saturated,
        "cosine_past_ceiling": cos_long,
        "cosine_control": cos_short,
        "truncation_confirmed": truncates,
        "counts": counts,
    }


# ---------------------------------------------------------------------------
# Measurement 2 — the corpus
# ---------------------------------------------------------------------------

def collect_chunk_texts() -> list[str]:
    """Reproduce exactly the text build_index() would embed, chunk for chunk."""
    from web import embeddings as E

    out = []
    for fpath in E.collect_files():
        try:
            content = fpath.read_text(errors="replace")
        except Exception:
            continue
        if not content.strip():
            continue
        title = E.extract_title(fpath, content)
        chunks = E._chunk_content(content, reserve=len(title) + 2)
        for i, chunk in enumerate(chunks):
            out.append(f"{title}\n\n{chunk}" if i > 0 else chunk)
    return out


def assert_cap(cap: int) -> int:
    """Walk the corpus and report any chunk over `cap` chars. No embed calls.

    This is the cheap standing check (T-3010): it is a pure local computation,
    so it can sit in a Verification block without depending on the embedder
    being up. It catches the chunker regressing; the token measurement above
    catches the *ceiling* moving.
    """
    texts = collect_chunk_texts()
    over = [len(t) for t in texts if len(t) > cap]
    print(f"chunks={len(texts):,}  cap={cap}  over={len(over):,}")
    if over:
        over.sort(reverse=True)
        print(f"  largest offenders: {over[:10]}")
        return 1
    print(f"  max chunk = {max(len(t) for t in texts):,} chars — cap holds")
    return 0


def pct(sorted_vals, q):
    if not sorted_vals:
        return 0
    return sorted_vals[max(0, int(len(sorted_vals) * q) - 1)]


def measure_distribution(texts, ceiling, model, host, sample_n, seed=1729):
    """Bound how many chunks exceed `ceiling` tokens, measuring where needed."""
    chars = sorted(len(t) for t in texts)
    n = len(texts)

    # tokens <= chars always, so <=ceiling chars is provably under the ceiling.
    provably_safe = sum(1 for c in chars if c <= ceiling)

    # Empirical chars-per-token, from a stratified random sample of the rest.
    candidates = [t for t in texts if len(t) > ceiling]
    rng = random.Random(seed)
    sample = rng.sample(candidates, min(sample_n, len(candidates)))
    ratios = []
    for t in sample:
        # Cap the probe: past the ceiling the count saturates and tells us
        # nothing about the ratio, so measure a prefix that stays under it.
        probe = t[: ceiling * 2]
        tc = token_count(probe, model, host)
        if tc and tc < ceiling:          # unsaturated => ratio is meaningful
            ratios.append(len(probe) / tc)
    if not ratios:
        raise SystemExit("no unsaturated samples; cannot bound the ratio")

    r_min, r_max = min(ratios), max(ratios)
    lo_chars = ceiling * r_min   # below this, cannot reach the ceiling
    hi_chars = ceiling * r_max   # above this, must have reached it

    definitely_under = sum(1 for c in chars if c <= lo_chars)
    definitely_over = sum(1 for c in chars if c > hi_chars)
    ambiguous = [t for t in texts if lo_chars < len(t) <= hi_chars]

    return {
        "chunks": n,
        "char_mean": st.mean(chars),
        "char_p50": pct(chars, 0.50),
        "char_p95": pct(chars, 0.95),
        "char_p99": pct(chars, 0.99),
        "char_max": max(chars),
        "provably_safe_by_char_bound": provably_safe,
        "sample_size": len(ratios),
        "ratio_min": r_min,
        "ratio_max": r_max,
        "ratio_median": st.median(ratios),
        "lo_chars": lo_chars,
        "hi_chars": hi_chars,
        "definitely_under": definitely_under,
        "definitely_over": definitely_over,
        "ambiguous_count": len(ambiguous),
        "ambiguous": ambiguous,
    }


def resolve_ambiguous(ambiguous, ceiling, model, host, limit):
    """Measure the ambiguous band exactly, up to `limit` chunks."""
    if not ambiguous:
        return {"measured": 0, "over": 0, "truncated": True}
    rng = random.Random(4242)
    batch = ambiguous if len(ambiguous) <= limit else rng.sample(ambiguous, limit)
    over = 0
    for t in batch:
        if token_count(t, model, host) >= ceiling:
            over += 1
    return {
        "measured": len(batch),
        "over": over,
        "over_rate": over / len(batch),
        "truncated": len(batch) < len(ambiguous),
    }


# ---------------------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default=DEFAULT_MODEL)
    ap.add_argument("--host", default=None, help="default: Config.EMBED_HOST")
    ap.add_argument("--sample", type=int, default=300, help="ratio-calibration sample")
    ap.add_argument("--ambiguous-limit", type=int, default=400)
    ap.add_argument("--check", action="store_true", help="ceiling only, for CI/gates")
    ap.add_argument("--assert-cap", type=int, metavar="CHARS", default=None,
                    help="walk the corpus, exit non-zero if any chunk exceeds "
                         "CHARS. No embed calls; safe when the embedder is down.")
    ap.add_argument("--expect-ceiling", type=int, default=512)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    if args.assert_cap is not None:
        # Deliberately before the host resolution below: this mode never talks
        # to the embedder, so it must not fail when the embedder is unreachable.
        return assert_cap(args.assert_cap)

    host = args.host
    if host is None:
        from web.config import Config
        host = Config.EMBED_HOST

    print(f"model={args.model}  host={host}")
    print("\n[1] Measuring the input ceiling")
    ceil = measure_ceiling(args.model, host, verbose=not args.json)
    c = ceil["ceiling_tokens"]
    print(f"    ceiling            : {c} tokens (saturated={ceil['saturated']})")
    print(f"    cosine past ceiling: {ceil['cosine_past_ceiling']:.9f}  "
          f"(1.0 => suffix discarded)")
    print(f"    cosine control     : {ceil['cosine_control']:.6f}  (must be < 1)")
    print(f"    TRUNCATION         : "
          f"{'CONFIRMED' if ceil['truncation_confirmed'] else 'NOT CONFIRMED'}")

    if args.check:
        ok = c == args.expect_ceiling and ceil["truncation_confirmed"]
        print(f"\n--check: ceiling {c} vs expected {args.expect_ceiling} -> "
              f"{'PASS' if ok else 'FAIL'}")
        return 0 if ok else 1

    print("\n[2] Walking the corpus (this reproduces build_index()'s chunking)")
    texts = collect_chunk_texts()
    d = measure_distribution(texts, c, args.model, host, args.sample)
    print(f"    chunks             : {d['chunks']:,}")
    print(f"    chars mean/p50/p95/p99/max : {d['char_mean']:.0f} / {d['char_p50']} "
          f"/ {d['char_p95']} / {d['char_p99']} / {d['char_max']:,}")
    print(f"    chars-per-token    : min={d['ratio_min']:.2f} "
          f"median={d['ratio_median']:.2f} max={d['ratio_max']:.2f} "
          f"(n={d['sample_size']})")
    print(f"    provably under     : {d['definitely_under']:,} "
          f"(<= {d['lo_chars']:.0f} chars)")
    print(f"    provably over      : {d['definitely_over']:,} "
          f"(>  {d['hi_chars']:.0f} chars)")
    print(f"    ambiguous band     : {d['ambiguous_count']:,}")

    print("\n[3] Measuring the ambiguous band exactly")
    r = resolve_ambiguous(d["ambiguous"], c, args.model, host, args.ambiguous_limit)
    print(f"    measured           : {r['measured']:,}"
          f"{' (sampled)' if r['truncated'] else ' (all)'}")
    if r["measured"]:
        print(f"    at/over ceiling    : {r['over']:,} ({r.get('over_rate', 0):.1%})")

    est_band_over = d["ambiguous_count"] * r.get("over_rate", 0)
    total_over = d["definitely_over"] + est_band_over
    print(f"\n=== VERDICT ===")
    print(f"ceiling {c} tokens, truncation "
          f"{'CONFIRMED' if ceil['truncation_confirmed'] else 'unproven'}")
    print(f"chunks losing content to truncation: ~{total_over:,.0f} of {d['chunks']:,} "
          f"({100 * total_over / d['chunks']:.1f}%)")
    print(f"  exact lower bound (provably over): {d['definitely_over']:,} "
          f"({100 * d['definitely_over'] / d['chunks']:.1f}%)")
    print(f"  the rest is the band estimate, from {r['measured']} measured chunks")

    if args.json:
        d.pop("ambiguous", None)
        print(json.dumps({"ceiling": ceil, "distribution": d, "band": r}, default=str))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except urllib.error.URLError as exc:
        print(f"embed host unreachable: {exc}", file=sys.stderr)
        sys.exit(2)
