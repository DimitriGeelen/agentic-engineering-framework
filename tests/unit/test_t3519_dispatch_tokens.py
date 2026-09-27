"""T-3519: a dispatch worker's token usage comes from modelUsage, not from summing turns.

The central test here is `test_per_turn_summation_disagrees_with_modelUsage`. It does
not check that the helper is correct — it checks that the WRONG method gives a
different answer, on a fixture shaped like a real stream. Without it, someone
"simplifying" the helper into a loop over `usage` objects would see a plausible
number and a green suite.

Measured on the real pf0927-r1 stream (265 assistant turns) before this was written:

    method                     output        cache read
    sum over turns                935      50,146,589
    modelUsage (result line)   62,051      25,187,338

Neither wrong number looks wrong on its own, which is the whole problem.

Second theme: UNAVAILABLE is not 0. A worker still running has no measurement, and
reporting 0 tokens would read as "this run was free" — the same defect T-3068
removed from blast_radius, where absence scored as the cheapest value.
"""

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "lib"))
import dispatch_tokens as dt  # noqa: E402


def write_stream(path: Path, turns, result_obj):
    """Build a stream: N assistant events with per-turn usage, then one result line."""
    lines = []
    for t in turns:
        lines.append(json.dumps({"type": "assistant", "message": {"usage": t}}))
    if result_obj is not None:
        lines.append(json.dumps(result_obj))
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


@pytest.fixture()
def stream(tmp_path):
    """A stream whose per-turn sum and modelUsage deliberately disagree, as real ones do."""
    p = tmp_path / "result.jsonl"
    # Every turn re-reports the same 100_000-token cached prefix — that is what makes
    # summation double-count — and reports only partial output.
    turns = [{"input_tokens": 1, "output_tokens": 3,
              "cache_creation_input_tokens": 10,
              "cache_read_input_tokens": 100_000} for _ in range(5)]
    result = {
        "type": "result", "subtype": "success", "is_error": False,
        "usage": {"input_tokens": 1, "output_tokens": 3,
                  "cache_creation_input_tokens": 10,
                  "cache_read_input_tokens": 100_000},
        "modelUsage": {
            "claude-sonnet-5": {"inputTokens": 20, "outputTokens": 900,
                                "cacheReadInputTokens": 100_000,
                                "cacheCreationInputTokens": 50},
        },
    }
    write_stream(p, turns, result)
    return p


# ── the measurement, and the wrong one ──────────────────────────────────────


def test_rollup_comes_from_modelUsage(stream):
    roll = dt.tokens_for_stream(stream)
    assert roll["available"] is True
    assert roll["source"] == "modelUsage"
    assert roll["totals"]["output"] == 900          # modelUsage, not 5×3=15
    assert roll["totals"]["cache_read"] == 100_000  # once, not 5×100_000


def test_per_turn_summation_disagrees_with_modelUsage(stream):
    """THE guard. If these ever agree, the fixture stopped representing a real stream
    and this suite has stopped protecting anything."""
    rows = [json.loads(l) for l in stream.read_text(encoding="utf-8").splitlines() if l.strip()]
    summed_out = sum((r.get("message") or {}).get("usage", {}).get("output_tokens", 0)
                     for r in rows if r.get("type") == "assistant")
    summed_cr = sum((r.get("message") or {}).get("usage", {}).get("cache_read_input_tokens", 0)
                    for r in rows if r.get("type") == "assistant")
    roll = dt.tokens_for_stream(stream)
    assert summed_out != roll["totals"]["output"]
    assert summed_cr != roll["totals"]["cache_read"]
    # And specifically: summation inflates cache-read and deflates output.
    assert summed_cr > roll["totals"]["cache_read"]
    assert summed_out < roll["totals"]["output"]


def test_new_tokens_excludes_cache_read(stream):
    t = dt.tokens_for_stream(stream)["totals"]
    assert t["new_tokens"] == t["input"] + t["cache_creation"] + t["output"]
    assert t["cache_read"] not in (t["new_tokens"],)


def test_multiple_models_are_summed(tmp_path):
    p = tmp_path / "result.jsonl"
    write_stream(p, [], {
        "type": "result", "subtype": "success", "is_error": False,
        "modelUsage": {
            "model-a": {"inputTokens": 5, "outputTokens": 100,
                        "cacheReadInputTokens": 1_000, "cacheCreationInputTokens": 7},
            "model-b": {"inputTokens": 2, "outputTokens": 50,
                        "cacheReadInputTokens": 500, "cacheCreationInputTokens": 3},
        },
    })
    t = dt.tokens_for_stream(p)["totals"]
    assert t["output"] == 150
    assert t["cache_read"] == 1_500
    assert t["input"] == 7
    assert t["cache_creation"] == 10


# ── unavailable is never zero ───────────────────────────────────────────────


def test_missing_file_is_unavailable_not_zero(tmp_path):
    roll = dt.tokens_for_stream(tmp_path / "nope.jsonl")
    assert roll["available"] is False
    assert "totals" not in roll          # no zeroed rollup to misread


def test_running_worker_is_unavailable_not_zero(tmp_path):
    p = tmp_path / "result.jsonl"
    write_stream(p, [{"output_tokens": 3}], None)   # turns, but no result line yet
    roll = dt.tokens_for_stream(p)
    assert roll["available"] is False
    assert "still running" in roll["reason"]
    assert "totals" not in roll


def test_result_line_without_modelUsage_is_unavailable(tmp_path):
    p = tmp_path / "result.jsonl"
    write_stream(p, [], {"type": "result", "subtype": "success", "is_error": False})
    roll = dt.tokens_for_stream(p)
    assert roll["available"] is False
    assert "modelUsage" in roll["reason"]


def test_truncated_json_does_not_crash(tmp_path):
    p = tmp_path / "result.jsonl"
    p.write_text('{"type":"assistant"}\n{"type":"result","modelUsage":{"m":{"outputTo\n',
                 encoding="utf-8")
    roll = dt.tokens_for_stream(p)          # must not raise
    assert roll["available"] is False


def test_a_later_line_after_the_result_does_not_hide_it(tmp_path):
    # A watchdog kill can append to the stream after the result line, so the helper
    # must not assume the result is the FINAL line.
    p = tmp_path / "result.jsonl"
    p.write_text(
        json.dumps({"type": "result", "subtype": "success", "is_error": False,
                    "modelUsage": {"m": {"outputTokens": 42, "inputTokens": 1,
                                         "cacheReadInputTokens": 9,
                                         "cacheCreationInputTokens": 0}}}) + "\n"
        + json.dumps({"type": "system", "subtype": "killed"}) + "\n",
        encoding="utf-8")
    roll = dt.tokens_for_stream(p)
    assert roll["available"] is True
    assert roll["totals"]["output"] == 42


# ── no dollars, per the operator's instruction ───────────────────────────────


def test_rendering_prints_tokens_and_no_dollar_figure(stream):
    out = dt.format_rollup(dt.tokens_for_stream(stream), "w1")
    assert "tokens" in out
    assert "$" not in out
    assert "cost_usd" not in out


def test_unavailable_rendering_says_so_rather_than_printing_a_number(tmp_path):
    out = dt.format_rollup(dt.tokens_for_stream(tmp_path / "nope.jsonl"), "w1")
    assert "UNAVAILABLE" in out
    assert "$" not in out


# ── the real captured rounds ────────────────────────────────────────────────


@pytest.mark.parametrize("worker", ["pf0927-r1", "pf0927-r2"])
def test_real_captured_round_rolls_up(worker):
    """Anchored on PROPERTIES, not on today's counts — a literal figure here would be
    a mutable-corpus anchor (T-3326), and these streams live in /tmp."""
    p = dt.dispatch_dir() / worker / "result.jsonl"
    if not p.is_file():
        pytest.skip(f"{worker} stream not present on this host")
    roll = dt.tokens_for_stream(p)
    assert roll["available"] is True
    t = roll["totals"]
    assert t["output"] > 0
    assert t["cache_read"] > t["output"]       # cache-read dominates, always
    assert t["new_tokens"] == t["input"] + t["cache_creation"] + t["output"]
