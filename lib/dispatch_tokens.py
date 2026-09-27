#!/usr/bin/env python3
"""dispatch_tokens.py — token usage for a TermLink dispatch worker (T-3519).

Operator instruction 2026-09-27: report a worker's cost in TOKENS, not dollars, and
embed it rather than computing it by hand per round.

── WHY modelUsage AND NOT A SUM OVER TURNS ──────────────────────────────────────

`result.jsonl` is a stream: many `{"type":"assistant"}` events, then exactly one
`{"type":"result"}` line. Each assistant event carries a `usage` object, and the
obvious implementation — add them up — is wrong in both directions at once:

  * cache_read_input_tokens DOUBLE-COUNTS. Every turn re-reports the entire cached
    prefix it read, so summing across 265 turns adds the same prefix 265 times.
  * output_tokens UNDERCOUNTS. Per-event usage is partial for a streamed message.

Measured on the real pf0927-r1 stream, 265 assistant turns:

    method                     output        cache read
    sum over turns                935      50,146,589
    modelUsage (result line)   62,051      25,187,338

Both numbers in the first row are wrong, and neither is wrong in a way that looks
wrong — 935 output tokens for a 28-minute round reads as plausible until it is
compared with something. The authoritative rollup is `modelUsage` on the single
result line, keyed by model. `tests/unit/test_t3519_dispatch_tokens.py` pins the
disagreement so this cannot be "simplified" back into the summing version.

── UNKNOWN IS NOT ZERO ─────────────────────────────────────────────────────────

A worker still running, or one that died before emitting a result line, has NO
measurement. This module reports that as unavailable and never as 0. Zero tokens is
a legitimate-looking value that reads as "this run was free", which is the same
defect T-3068 removed from `blast_radius` — absence scored as the cheapest value.

── CACHE READ IS REPORTED SEPARATELY ───────────────────────────────────────────

Cache reads are the largest figure by an order of magnitude and the cheapest per
token. Folding them into one total misrepresents the run in whichever direction the
reader happens to assume, so `new_tokens` (input + cache_creation + output) and
`cache_read` stay distinct.
"""

from __future__ import annotations

import json
import os
from pathlib import Path

#: Keys as they appear in the result line's `modelUsage` entries. Note the case
#: difference from the per-turn `usage` objects (`inputTokens` here vs
#: `input_tokens` there) — reading the wrong spelling yields a silent 0.
_FIELDS = {
    "input": "inputTokens",
    "output": "outputTokens",
    "cache_read": "cacheReadInputTokens",
    "cache_creation": "cacheCreationInputTokens",
}


def dispatch_dir() -> Path:
    return Path(os.environ.get("FW_DISPATCH_DIR") or "/tmp/tl-dispatch")


def _result_line(stream_path: Path) -> dict | None:
    """Return the parsed `{"type":"result"}` line, or None if absent/unreadable.

    Scans for the LAST result line rather than assuming it is the final line of the
    file: a watchdog kill can append to the stream after it.
    """
    stream_path = Path(stream_path)
    if not stream_path.is_file():
        return None
    found = None
    try:
        with stream_path.open("r", encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if not line or '"result"' not in line:
                    continue
                try:
                    obj = json.loads(line)
                except ValueError:
                    continue          # a truncated final write is not a crash
                if isinstance(obj, dict) and obj.get("type") == "result":
                    found = obj
    except OSError:
        return None
    return found


def tokens_for_stream(stream_path) -> dict:
    """Token rollup for one worker stream.

    Returns {"available": False, "reason": str} when there is nothing to measure —
    never a zeroed rollup.
    """
    stream_path = Path(stream_path)
    res = _result_line(stream_path)
    if res is None:
        if not stream_path.is_file():
            return {"available": False,
                    "reason": "no result.jsonl (worker never started?)"}
        return {"available": False,
                "reason": "no result line yet (worker still running, or died before finishing)"}

    mu = res.get("modelUsage")
    if not isinstance(mu, dict) or not mu:
        return {"available": False,
                "reason": "result line carries no modelUsage (older worker build?)"}

    per_model: dict[str, dict[str, int]] = {}
    totals = {k: 0 for k in _FIELDS}
    for model, usage in mu.items():
        if not isinstance(usage, dict):
            continue
        row = {}
        for out_key, in_key in _FIELDS.items():
            v = usage.get(in_key, 0)
            row[out_key] = int(v) if isinstance(v, (int, float)) else 0
            totals[out_key] += row[out_key]
        per_model[str(model)] = row

    if not per_model:
        return {"available": False,
                "reason": "modelUsage present but held no usable entries"}

    totals["new_tokens"] = totals["input"] + totals["cache_creation"] + totals["output"]
    return {
        "available": True,
        "source": "modelUsage",
        "per_model": per_model,
        "totals": totals,
        "subtype": res.get("subtype"),
        "is_error": res.get("is_error"),
    }


def tokens_for_worker(name: str) -> dict:
    return tokens_for_stream(dispatch_dir() / name / "result.jsonl")


def format_rollup(roll: dict, name: str = "") -> str:
    """One-or-few-line human rendering. Deliberately prints no dollar figure."""
    label = f"{name}: " if name else ""
    if not roll.get("available"):
        return f"{label}tokens UNAVAILABLE — {roll.get('reason', 'unknown')}"
    t = roll["totals"]

    def f(n):
        return f"{n:,}"

    lines = [
        f"{label}tokens (source: {roll['source']})",
        f"  new tokens   {f(t['new_tokens'])}"
        f"   (input {f(t['input'])} + cache-create {f(t['cache_creation'])}"
        f" + output {f(t['output'])})",
        f"  cache read   {f(t['cache_read'])}"
        f"   (separate: largest figure, cheapest per token)",
    ]
    if len(roll["per_model"]) > 1:
        for model, row in sorted(roll["per_model"].items()):
            lines.append(
                f"    {model}: output {f(row['output'])},"
                f" cache-read {f(row['cache_read'])}")
    return "\n".join(lines)


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: dispatch_tokens.py <worker-name|--stream PATH> [--json]")
        return 2
    if argv[1] == "--stream":
        if len(argv) < 3:
            print("usage: dispatch_tokens.py --stream PATH [--json]")
            return 2
        name = argv[2]
        roll = tokens_for_stream(argv[2])
    else:
        name = argv[1]
        roll = tokens_for_worker(name)
    if "--json" in argv[2:]:
        print(json.dumps(roll, indent=2))
    else:
        print(format_rollup(roll, name))
    # Exit 0 even when unavailable: "cannot measure" is a valid, reported answer and
    # must not fail a caller that is only printing a rollup.
    return 0


if __name__ == "__main__":
    import sys
    raise SystemExit(main(sys.argv))
