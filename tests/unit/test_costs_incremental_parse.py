"""T-2035: pin the costs per-file memo + incremental append parser.

`_parse_session_cached` must produce byte-identical token totals to a
from-scratch `_parse_session`, whether the file was parsed cold, grew
(incremental fold from the last offset), or shrank (truncation/rotation →
full re-parse). It must also never count a partial, still-being-written
trailing record until its newline arrives. These guards let the cockpit
load fast (historical 1.5GB parsed once) without ever skewing the numbers.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from web.blueprints import costs

_NUMERIC = (
    "turns",
    "input_tokens",
    "cache_read",
    "cache_create",
    "output_tokens",
    "total",
)


def _rec(ts, model="claude-opus-4-7", inp=10, cr=5, cc=3, out=7):
    return json.dumps(
        {
            "timestamp": ts,
            "message": {
                "model": model,
                "usage": {
                    "input_tokens": inp,
                    "cache_read_input_tokens": cr,
                    "cache_creation_input_tokens": cc,
                    "output_tokens": out,
                },
            },
        }
    )


def _write(path, records, trailing_newline=True):
    text = "\n".join(records)
    if records and trailing_newline:
        text += "\n"
    path.write_text(text)


def _assert_same(a, b):
    for k in _NUMERIC:
        assert a[k] == b[k], f"{k}: {a[k]} != {b[k]}"
    assert a["first_ts"] == b["first_ts"]
    assert a["last_ts"] == b["last_ts"]
    assert a["model"] == b["model"]


def setup_function(_):
    # module-level memo is process-global; isolate each test
    costs._parse_memo.clear()


def test_cold_cached_equals_full(tmp_path):
    p = tmp_path / "S-cold.jsonl"
    _write(p, [_rec(f"2026-05-25T00:0{i}:00Z") for i in range(4)])
    _assert_same(costs._parse_session_cached(str(p)), costs._parse_session(str(p)))


def test_unchanged_file_returns_same_object(tmp_path):
    p = tmp_path / "S-static.jsonl"
    _write(p, [_rec("2026-05-25T00:00:00Z")])
    first = costs._parse_session_cached(str(p))
    second = costs._parse_session_cached(str(p))
    # identity: the cache short-circuit returned the memoized object, no re-read
    assert first is second


def test_incremental_growth_equals_full(tmp_path):
    p = tmp_path / "S-grow.jsonl"
    _write(p, [_rec(f"2026-05-25T00:0{i}:00Z") for i in range(3)])
    costs._parse_session_cached(str(p))  # cold → records offset

    # append more records (size grows → incremental fold)
    with p.open("a") as f:
        for i in range(3, 7):
            f.write(_rec(f"2026-05-25T00:0{i}:00Z") + "\n")

    incremental = costs._parse_session_cached(str(p))
    full = costs._parse_session(str(p))
    _assert_same(incremental, full)
    assert incremental["turns"] == 7


def test_truncation_triggers_full_reparse(tmp_path):
    p = tmp_path / "S-trunc.jsonl"
    _write(p, [_rec(f"2026-05-25T00:0{i}:00Z") for i in range(6)])
    big = costs._parse_session_cached(str(p))
    assert big["turns"] == 6

    # rotate/truncate to fewer records (size shrinks → full re-parse, not stale)
    _write(p, [_rec("2026-05-25T01:00:00Z")])
    small = costs._parse_session_cached(str(p))
    assert small["turns"] == 1
    _assert_same(small, costs._parse_session(str(p)))


def test_partial_trailing_line_not_counted_until_complete(tmp_path):
    p = tmp_path / "S-partial.jsonl"
    # two complete records + a third with NO trailing newline (mid-write)
    _write(p, [_rec("2026-05-25T00:00:00Z"), _rec("2026-05-25T00:01:00Z")], trailing_newline=True)
    with p.open("a") as f:
        f.write(_rec("2026-05-25T00:02:00Z"))  # no "\n"

    partial = costs._parse_session_cached(str(p))
    assert partial["turns"] == 2, "the unterminated record must not be counted yet"

    # complete the record with its newline → now it folds in
    with p.open("a") as f:
        f.write("\n")
    completed = costs._parse_session_cached(str(p))
    assert completed["turns"] == 3
    _assert_same(completed, costs._parse_session(str(p)))
