"""T-5203 (T-5190 S4): limit-message recognisers -> `limit` events in the quota ledger.

* every wording in 1409's table (docs/reports/T-5190-subscription-quota-overview.md) gives its
  kind and reset handling; unrelated text and model text quoting the wordings give nothing;
* claude's reset parsed only with "(UTC)"; the date-less form is the next HH:MM UTC after the
  message time; GLM's zone-less time is "unknown" + reset_text; never a guessed zone;
* one event per kind per dispatch; end to end through real termlink.sh + run.sh with a stub
  claude that prints the limit message on stderr; no other output text stored.

Every ledger lives under tmp_path; conftest also pins FW_QUOTA_LEDGER for every test.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT / "lib"))
sys.path.insert(0, str(Path(__file__).resolve().parent))

import quota_ledger  # noqa: E402
import quota_limits as ql  # noqa: E402
import test_t5201_subscription_tokens as s2  # noqa: E402

AT = "2026-11-14T01:40:00Z"

# (wording, worker_kind, expected events) — the fixture strings are 1409's table, verbatim.
TABLE = [
    ("Insufficient balance or no resource package. Please recharge.", "opencode",
     [{"kind": "balance", "reset": "unknown"}]),
    ("You've hit your weekly limit · resets 5am (UTC)", "claude",
     [{"kind": "weekly", "reset_at": "2026-11-14T05:00:00Z"}]),
    ("Rate limit reached for requests", "opencode",
     [{"kind": "rate", "reset": "unknown"}]),
    ("Usage limit reached for 5 hour. Your limit will reset at 2026-11-16 14:12:01", "opencode",
     [{"kind": "5h", "reset": "unknown", "reset_text": "2026-11-16 14:12:01"}]),
    ("Usage limit reached for 5 hour. Your limit will reset at 2026-11-16 20:32:37", "claude",
     [{"kind": "5h", "reset": "unknown", "reset_text": "2026-11-16 20:32:37"}]),
    ("You've hit your weekly limit · resets Nov 21, 5am (UTC)", "claude",
     [{"kind": "weekly", "reset_at": "2026-11-21T05:00:00Z"}]),
    ("HTTP Error 429: Too Many Requests", "ollama-loop",
     [{"kind": "rate", "reset": "unknown"}]),
    ("You've hit your 5-hour limit · resets 3pm (UTC)", "claude",
     [{"kind": "5h", "reset_at": "2026-11-14T15:00:00Z"}]),
]


@pytest.mark.parametrize("text,kind,expected", TABLE)
def test_table_wording(text, kind, expected):
    assert ql.recognise(text, kind, AT) == expected


@pytest.mark.parametrize("text", [
    "", "all done, 3 files changed", "limit reached for the loop counter",
    "429 lines processed", "resets 5am (UTC)", "rate limit configuration updated",
    "HARNESS ERROR (codex): network unreachable",
])
def test_unrelated_text_gives_nothing(text):
    assert ql.recognise(text, "claude", AT) == []


def test_claude_wording_only_for_claude_workers():
    assert ql.recognise("You've hit your weekly limit · resets 5am (UTC)", "opencode", AT) == []


# ── reset rules ─────────────────────────────────────────────────────────────

def test_dateless_reset_is_next_time_strictly_after_message_time():
    msg = "You've hit your weekly limit · resets 5am (UTC)"
    assert ql.recognise(msg, "claude", "2026-11-14T01:37:00Z")[0]["reset_at"] == "2026-11-14T05:00:00Z"
    assert ql.recognise(msg, "claude", "2026-11-14T06:00:00Z")[0]["reset_at"] == "2026-11-15T05:00:00Z"
    assert ql.recognise(msg, "claude", "2026-11-14T05:00:00Z")[0]["reset_at"] == "2026-11-15T05:00:00Z"
    assert ql.recognise(msg, "claude", "2026-12-31T23:00:00Z")[0]["reset_at"] == "2027-01-01T05:00:00Z"


def test_dateless_reset_without_message_time_is_unknown():
    assert ql.recognise("You've hit your weekly limit · resets 5am (UTC)", "claude") == [
        {"kind": "weekly", "reset": "unknown", "reset_text": "5am (UTC)"}]


def test_dated_reset_year_rolls_over():
    ev = ql.recognise("You've hit your weekly limit · resets Jan 2, 5am (UTC)", "claude",
                      "2026-12-30T10:00:00Z")
    assert ev == [{"kind": "weekly", "reset_at": "2027-01-02T05:00:00Z"}]


@pytest.mark.parametrize("when", ["5am", "Nov 21, 5am", "5:30pm (Europe/Berlin)", "17:00 (CET)"])
def test_claude_reset_without_utc_is_never_guessed(when):
    (ev,) = ql.recognise(f"You've hit your weekly limit · resets {when}", "claude", AT)
    assert ev["reset"] == "unknown" and "reset_at" not in ev
    assert ev["reset_text"] == when


def test_claude_invalid_time_is_unknown():
    (ev,) = ql.recognise("You've hit your weekly limit · resets 13pm (UTC)", "claude", AT)
    assert ev["reset"] == "unknown" and "reset_at" not in ev


def test_glm_zoneless_time_is_unknown_not_utc_plus_8():
    (ev,) = ql.recognise("Usage limit reached for 5 hour. Your limit will reset at "
                         "2026-11-16 14:12:01", "opencode", AT)
    assert "reset_at" not in ev and ev["reset"] == "unknown"


def test_one_event_per_kind_last_wins():
    text = "\n".join(["You've hit your weekly limit · resets 5am (UTC)"] * 5 +
                     ["Rate limit reached for requests", "HTTP Error 429: Too Many Requests",
                      "You've hit your weekly limit · resets Nov 21, 5am (UTC)"])
    ev = ql.recognise(text, "claude", AT)
    assert sorted(e["kind"] for e in ev) == ["rate", "weekly"]
    assert [e for e in ev if e["kind"] == "weekly"][0]["reset_at"] == "2026-11-21T05:00:00Z"


def test_result_jsonl_model_text_is_not_a_limit(tmp_path):
    """A worker reading these wordings (this very file) is not at its limit."""
    (tmp_path / "result.jsonl").write_text("\n".join(json.dumps(x) for x in [
        {"type": "assistant", "message": {"content": [{"type": "text",
         "text": "The table says: You've hit your weekly limit · resets 5am (UTC)"}]}},
        {"type": "result", "subtype": "success", "is_error": False,
         "result": "Rate limit reached for requests is a GLM wording"},
    ]) + "\n")
    assert ql.recognise(ql.worker_text(tmp_path), "claude", AT) == []


def test_result_jsonl_error_events_count(tmp_path):
    (tmp_path / "result.jsonl").write_text("\n".join(json.dumps(x) for x in [
        {"type": "result", "is_error": True, "result": "You've hit your weekly limit · resets 5am (UTC)"},
        {"type": "error", "message": "Insufficient balance or no resource package. Please recharge."},
    ]) + "\nnot json\n")
    kinds = sorted(e["kind"] for e in ql.recognise(ql.worker_text(tmp_path), "claude", AT))
    assert kinds == ["balance", "weekly"]


def test_reads_only_the_last_megabyte(tmp_path):
    (tmp_path / "stderr.log").write_text("Rate limit reached for requests\n" + "x" * (ql.READ_TAIL_BYTES + 10)
                                         + "\nInsufficient balance or no resource package\n")
    kinds = [e["kind"] for e in ql.recognise(ql.worker_text(tmp_path), "opencode", AT)]
    assert kinds == ["balance"]


def test_append_failure_never_raises(tmp_path, monkeypatch):
    monkeypatch.setenv("FW_QUOTA_LEDGER", str(tmp_path))  # a directory: open() fails
    monkeypatch.setattr(quota_ledger, "_warned", False)
    (tmp_path / "w").mkdir()
    (tmp_path / "w" / "stderr.log").write_text("HTTP Error 429: Too Many Requests\n")
    (tmp_path / "meta.json").write_text(json.dumps({"name": "d1", "subscription": "glm-a"}))
    assert ql.append_for_dispatch(tmp_path / "meta.json", tmp_path / "w") == 0
    assert ql.main(["append", "--meta", str(tmp_path / "nope.json"), "--wdir", str(tmp_path)]) == 0
    assert ql.main(["bogus"]) == 0


# ── end to end: real termlink.sh + run.sh, stub claude printing a limit on stderr ──────

SECRET = "PROMPT-OUTPUT-MARKER-91x"


def _limit_stub(tmp: Path) -> Path:
    stub = s2._stubs(tmp, None)
    (stub / "claude").write_text(
        "#!/bin/bash\n"
        f"echo 'some normal output {SECRET}'\n"
        f"echo 'working on {SECRET}' >&2\n"
        "echo \"You've hit your weekly limit · resets Nov 21, 5am (UTC)\" >&2\n"
        "echo \"You've hit your weekly limit · resets Nov 21, 5am (UTC)\" >&2\n"
        "echo 'HTTP Error 429: Too Many Requests' >&2\n"
        "exit 1\n")
    return stub


@pytest.fixture
def ledger(tmp_path, monkeypatch):
    p = tmp_path / "state" / "aef" / "quota-ledger.jsonl"
    monkeypatch.setenv("FW_QUOTA_LEDGER", str(p))
    monkeypatch.setattr(quota_ledger, "_warned", False)
    return p


def _lines(p: Path) -> list[dict]:
    return [json.loads(x) for x in p.read_text().splitlines() if x.strip()]


def test_dispatch_with_limit_message_appends_one_event_per_kind(ledger, tmp_path):
    proj = s2._project(tmp_path, s2.REGISTRY)
    r, w = s2._dispatch(tmp_path, proj, _limit_stub(tmp_path), "t5203-a")
    assert r.returncode == 0, r.stdout + r.stderr
    m = s2._wait_done(w)
    assert m["status"] == "failed" and m["exit_code"] == 1     # the outcome is the worker's own
    rows = _lines(ledger)
    assert [x["event"] for x in rows].count("dispatch") == 1
    limits = sorted((x for x in rows if x["event"] == "limit"), key=lambda x: x["kind"])
    assert [x["kind"] for x in limits] == ["rate", "weekly"]
    weekly = limits[1]
    assert weekly["reset_at"].endswith("-11-21T05:00:00Z")
    assert weekly["subscription"] == "claude-b" and weekly["dispatch_id"] == "t5203-a"
    assert weekly["worker_kind"] == "claude" and weekly["source"] == "dispatch"
    assert weekly["ts"] == m["ended"]
    allowed = {"event", "ts", "project", "task", "dispatch_id", "worker_kind", "subscription",
               "kind", "reset_at", "reset", "reset_text", "source"}
    for x in limits:
        assert set(x) <= allowed, x
        text = json.dumps(x)
        assert SECRET not in text and "hit your" not in text and "Too Many" not in text
        assert str(proj) not in text and "noop" not in text


def test_dispatch_without_limit_message_appends_no_limit_event(ledger, tmp_path):
    proj = s2._project(tmp_path, s2.REGISTRY)
    r, w = s2._dispatch(tmp_path, proj, s2._stubs(tmp_path, s2.MODEL_USAGE_RESULT), "t5203-n")
    assert r.returncode == 0
    s2._wait_done(w)
    assert [x["event"] for x in _lines(ledger)] == ["dispatch"]


def test_no_output_text_other_than_reset_literal_is_stored(tmp_path):
    (tmp_path / "stderr.log").write_text(
        f"{SECRET} Usage limit reached for 5 hour. Your limit will reset at 2026-11-16 14:12:01 "
        f"{SECRET}\nYou've hit your weekly limit · resets 5am, {SECRET} (UTC)\n")
    meta = {"name": "d1", "project": "/x/proj", "task": "T-1", "subscription": "glm-a",
            "ended": AT}
    rows = ql.events_for_dispatch(meta, tmp_path, "claude")
    for row in rows:
        text = json.dumps(row)
        assert SECRET not in text and "/x/" not in text
        if "reset_text" in row:
            assert row["reset_text"] in ("2026-11-16 14:12:01", "5am")
    assert {r["kind"] for r in rows} == {"5h", "weekly"}
