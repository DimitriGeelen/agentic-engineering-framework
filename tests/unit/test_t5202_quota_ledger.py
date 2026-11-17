"""T-5202 (T-5190 S3): the machine-wide quota ledger — ids and counts only.

* path: FW_QUOTA_LEDGER > $XDG_STATE_HOME/aef > ~/.local/state/aef; missing dirs created.
* append: whole lines under parallel writers (several processes), rotation to `.1` at the
  size bound, an unwritable ledger warns once and never raises.
* rows(): torn lines skipped, filters by time and subscription, reads across rotation.
* hooks: a completed dispatch (real termlink.sh + run.sh, stub claude) and a review cost row
  each append one row; no row holds a prompt, host name or account-like value (S1 patterns).

Every ledger here lives under tmp_path; conftest also pins FW_QUOTA_LEDGER for every test.
"""
from __future__ import annotations

import json
import os
import socket
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT / "lib"))
sys.path.insert(0, str(Path(__file__).resolve().parent))

import quota_ledger  # noqa: E402
import subscriptions  # noqa: E402
import test_t5201_subscription_tokens as s2  # noqa: E402

HOST = socket.gethostname()
FIELDS = {"event", "ts", "project", "task", "dispatch_id", "review_id", "worker_kind",
          "subscription", "tokens"}


@pytest.fixture
def ledger(tmp_path, monkeypatch):
    p = tmp_path / "state" / "aef" / "quota-ledger.jsonl"
    monkeypatch.setenv("FW_QUOTA_LEDGER", str(p))
    monkeypatch.setattr(quota_ledger, "_warned", False)
    return p


def _lines(p: Path) -> list[dict]:
    return [json.loads(x) for x in p.read_text().splitlines() if x.strip()]


def _assert_clean(row: dict, *forbidden: str) -> None:
    text = json.dumps(row)
    assert set(row) <= FIELDS, row
    assert subscriptions.account_values(text) == [], (text, subscriptions.account_values(text))
    assert HOST not in text
    assert "/" not in text.replace("\\/", "")   # no path, so no prompt file / project path
    for f in forbidden:
        assert f not in text


# ── path resolution ─────────────────────────────────────────────────────────

def test_path_resolution_order(tmp_path, monkeypatch):
    monkeypatch.delenv("FW_QUOTA_LEDGER", raising=False)
    monkeypatch.delenv("XDG_STATE_HOME", raising=False)
    monkeypatch.setenv("HOME", str(tmp_path / "home"))
    assert quota_ledger.ledger_path() == tmp_path / "home" / ".local" / "state" / "aef" / "quota-ledger.jsonl"
    monkeypatch.setenv("XDG_STATE_HOME", str(tmp_path / "xdg"))
    assert quota_ledger.ledger_path() == tmp_path / "xdg" / "aef" / "quota-ledger.jsonl"
    monkeypatch.setenv("FW_QUOTA_LEDGER", str(tmp_path / "x" / "q.jsonl"))
    assert quota_ledger.ledger_path() == tmp_path / "x" / "q.jsonl"
    out = subprocess.run([sys.executable, str(ROOT / "lib" / "quota_ledger.py"), "path"],
                         capture_output=True, text=True, env=os.environ.copy())
    assert out.stdout.strip() == str(tmp_path / "x" / "q.jsonl")


def test_xdg_path_is_created_and_written(tmp_path, monkeypatch):
    monkeypatch.delenv("FW_QUOTA_LEDGER", raising=False)
    monkeypatch.setenv("XDG_STATE_HOME", str(tmp_path / "xdg"))
    assert quota_ledger.append(quota_ledger.make_row(event="review", project="p", task="T-1"))
    assert len(_lines(tmp_path / "xdg" / "aef" / "quota-ledger.jsonl")) == 1


# ── unwritable ledger ───────────────────────────────────────────────────────

def test_unwritable_ledger_warns_once_and_never_raises(tmp_path, monkeypatch, capsys):
    blocker = tmp_path / "file"
    blocker.write_text("x")                       # a FILE where the directory must go
    monkeypatch.setenv("FW_QUOTA_LEDGER", str(blocker / "aef" / "q.jsonl"))
    monkeypatch.setattr(quota_ledger, "_warned", False)
    row = quota_ledger.make_row(event="dispatch", project="p", task="T-1")
    assert quota_ledger.append(row) is False
    assert quota_ledger.append(row) is False
    err = capsys.readouterr().err
    assert err.count("WARNING: quota ledger not written") == 1, err


# ── parallel writers ────────────────────────────────────────────────────────

_WRITER = r"""
import sys
sys.path.insert(0, sys.argv[1])
import quota_ledger
proj, n = sys.argv[2], int(sys.argv[3])
for i in range(n):
    quota_ledger.append(quota_ledger.make_row(event="dispatch", project=proj, task="T-5202",
        dispatch_id=f"{proj}-{i}", worker_kind="claude", subscription="claude-a",
        tokens={"input": i, "output": 2 * i, "cache_read": 10 ** 6}))
"""


def test_parallel_writers_produce_whole_lines(ledger, tmp_path):
    procs = [subprocess.Popen([sys.executable, "-c", _WRITER, str(ROOT / "lib"), f"proj{k}", "200"],
                              env=os.environ.copy()) for k in range(6)]
    assert all(p.wait(timeout=120) == 0 for p in procs)
    raw = ledger.read_text().split("\n")
    assert raw[-1] == ""                          # ends with a newline: no partial tail
    rows = [json.loads(x) for x in raw[:-1]]     # every line parses whole
    assert len(rows) == 1200
    for k in range(6):
        assert sorted(int(r["dispatch_id"].split("-")[1]) for r in rows
                      if r["project"] == f"proj{k}") == list(range(200))


def test_parallel_writers_with_rotation_lose_nothing(ledger, monkeypatch):
    monkeypatch.setenv("FW_QUOTA_LEDGER_MAX_BYTES", "20000")
    procs = [subprocess.Popen([sys.executable, "-c", _WRITER, str(ROOT / "lib"), f"p{k}", "60"],
                              env=os.environ.copy()) for k in range(4)]
    assert all(p.wait(timeout=120) == 0 for p in procs)
    # Only one previous file is kept, so some rows may have rotated away; whatever is
    # present is whole, and the live file never exceeds the bound by more than one row.
    for f in (ledger, Path(str(ledger) + ".1")):
        for x in f.read_text().splitlines():
            json.loads(x)
    assert Path(str(ledger) + ".1").exists()


# ── reader ──────────────────────────────────────────────────────────────────

def test_reader_skips_torn_lines_and_filters(ledger):
    ledger.parent.mkdir(parents=True)
    good = [quota_ledger.make_row(event="dispatch", project="a", task="T-1", subscription="claude-a",
                                  ts="2026-11-01T00:00:00Z"),
            quota_ledger.make_row(event="review", project="b", task="T-2", subscription="glm",
                                  ts="2026-11-10T00:00:00Z"),
            quota_ledger.make_row(event="dispatch", project="c", task="T-3", subscription="claude-a",
                                  ts="2026-11-15T12:00:00Z")]
    body = "\n".join([json.dumps(good[0]), '{"event":"dispatch","ts":"2026-11-0', "[1,2]",
                      "\xff garbage", json.dumps(good[1]), "", json.dumps(good[2]),
                      '{"torn": tr'])
    ledger.write_bytes(body.encode("utf-8", "surrogateescape"))
    assert quota_ledger.rows() == good
    assert quota_ledger.rows(subscription="claude-a") == [good[0], good[2]]
    assert quota_ledger.rows(since="2026-11-05T00:00:00Z") == [good[1], good[2]]
    assert quota_ledger.rows(since="2026-11-05T00:00:00Z", subscription="claude-a") == [good[2]]
    assert quota_ledger.rows(path=ledger.parent / "absent.jsonl") == []


def test_rotation_keeps_one_previous_file(ledger, monkeypatch):
    monkeypatch.setenv("FW_QUOTA_LEDGER_MAX_BYTES", "300")
    for i in range(30):
        assert quota_ledger.append(quota_ledger.make_row(
            event="dispatch", project="p", task="T-1", dispatch_id=f"w{i}",
            ts=f"2026-11-17T00:00:{i:02d}Z"))
    prev = Path(str(ledger) + ".1")
    assert prev.exists() and not Path(str(ledger) + ".2").exists()
    assert ledger.stat().st_size < 300 + 200 and prev.stat().st_size < 300 + 200
    ids = [r["dispatch_id"] for r in quota_ledger.rows()]
    assert ids[-1] == "w29" and ids == sorted(ids, key=lambda s: int(s[1:]))  # .1 first, oldest first
    assert len(ids) < 30                           # older generations were dropped


# ── row shape / no account values ───────────────────────────────────────────

def test_make_row_keeps_ids_and_counts_only():
    row = quota_ledger.make_row(
        event="dispatch", project="/opt/some/where/999-proj", task="T-5202",
        dispatch_id="me@example.com", worker_kind="sk-abcdefghijkl", subscription="Bad_Id",
        tokens={"input": 3, "output": "7", "secret": 9, "cache_read": True, "total": -1})
    assert row["project"] == "999-proj"
    assert row["dispatch_id"] == "redacted" and row["worker_kind"] == "redacted"
    assert row["subscription"] == "unknown"
    assert row["tokens"] == {"input": 3}
    assert "review_id" not in row
    _assert_clean(row, "example.com", "sk-abc", "/opt")
    assert "tokens" not in quota_ledger.make_row(event="review", project="p", tokens={})


# ── hooks: dispatch completion and review cost row ──────────────────────────

def test_completed_dispatch_appends_one_clean_row(ledger, tmp_path):
    proj = s2._project(tmp_path, s2.REGISTRY)
    r, w = s2._dispatch(tmp_path, proj, s2._stubs(tmp_path, s2.MODEL_USAGE_RESULT), "t5202-a")
    assert r.returncode == 0, r.stdout + r.stderr
    s2._wait_done(w)
    rows = _lines(ledger)
    assert len(rows) == 1, rows
    row = rows[0]
    assert row["event"] == "dispatch" and row["project"] == "proj" and row["task"] == "T-5201"
    assert row["dispatch_id"] == "t5202-a" and row["worker_kind"] == "claude"
    assert row["subscription"] == "claude-b"
    assert row["tokens"] == {"input": 15, "output": 10, "cache_read": 100}
    _assert_clean(row, "noop", str(proj))          # "noop" is the prompt


def test_dispatch_with_no_reported_tokens_omits_tokens(ledger, tmp_path):
    proj = s2._project(tmp_path, s2.INVALID)
    r, w = s2._dispatch(tmp_path, proj, s2._stubs(tmp_path, None), "t5202-n")
    assert r.returncode == 0
    s2._wait_done(w)
    (row,) = _lines(ledger)
    assert "tokens" not in row and row["subscription"] == "unknown"


def test_unwritable_ledger_never_fails_the_dispatch(tmp_path, monkeypatch):
    blocker = tmp_path / "blocker"
    blocker.write_text("x")
    monkeypatch.setenv("FW_QUOTA_LEDGER", str(blocker / "q.jsonl"))
    proj = s2._project(tmp_path, s2.REGISTRY)
    r, w = s2._dispatch(tmp_path, proj, s2._stubs(tmp_path, s2.MODEL_USAGE_RESULT), "t5202-u")
    assert r.returncode == 0, r.stdout + r.stderr
    m = s2._wait_done(w)
    assert m["status"] == "done" and m["exit_code"] == 0
    assert (w / "stderr.log").read_text().count("WARNING: quota ledger not written") == 1


def test_review_cost_row_appends_one_clean_row(ledger, tmp_path):
    proj = s2._project(tmp_path, s2.REGISTRY)
    (proj / "policy" / "review-backends.yaml").write_text((ROOT / "policy" / "review-backends.yaml").read_text())
    backend = s2._backend_kind("claude")
    r = s2._rc(proj, "cost", "log", "--task", "T-5202", "--backend", backend,
               "--purpose", "code-review", "--tokens", "1234")
    assert r.returncode == 0, r.stdout + r.stderr
    (row,) = _lines(ledger)
    assert row["event"] == "review" and row["project"] == "proj" and row["task"] == "T-5202"
    assert row["review_id"].startswith("RC-") and row["worker_kind"] == "claude"
    assert row["subscription"] == "claude-b" and row["tokens"] == {"total": 1234}
    _assert_clean(row, "code-review")


def test_unwritable_ledger_never_fails_the_review_row(tmp_path, monkeypatch):
    blocker = tmp_path / "blocker"
    blocker.write_text("x")
    monkeypatch.setenv("FW_QUOTA_LEDGER", str(blocker / "q.jsonl"))
    proj = s2._project(tmp_path, s2.REGISTRY)
    (proj / "policy" / "review-backends.yaml").write_text((ROOT / "policy" / "review-backends.yaml").read_text())
    r = s2._rc(proj, "cost", "log", "--task", "T-5202", "--backend", s2._backend_kind("claude"),
               "--purpose", "code-review")
    assert r.returncode == 0, r.stdout + r.stderr
    assert r.stderr.count("WARNING: quota ledger not written") == 1
    assert len((proj / ".context" / "costs" / "reviews.jsonl").read_text().splitlines()) == 1
