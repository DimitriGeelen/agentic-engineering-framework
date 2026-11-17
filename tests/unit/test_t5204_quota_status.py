"""T-5204 (T-5190 S5): `fw quota status` — free / tight / at limit until, per subscription.

Every rule in the task's Goal, the exit codes 0/1/2, --json parity with the text, the ledger
left byte-identical, and S1's account-value check over the output. Every ledger is a tmp file
(conftest pins FW_QUOTA_LEDGER too); the real ledger is never read or written.
"""
from __future__ import annotations

import datetime as dt
import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT / "lib"))

import quota_status as qs  # noqa: E402
import subscriptions  # noqa: E402

NOW = dt.datetime(2026, 11, 17, 12, 0, tzinfo=dt.timezone.utc)
REG = {"subscriptions": [{"id": "claude-a", "harness": "claude", "description": "A"},
                         {"id": "glm", "harness": "glm", "description": "G"}],
       "assignments": []}


def ts(hours_ago: float) -> str:
    return (NOW - dt.timedelta(hours=hours_ago)).strftime("%Y-%m-%dT%H:%M:%SZ")


def disp(h, sub="claude-a", total=None, did="d-x", **tok):
    r = {"event": "dispatch", "ts": ts(h), "subscription": sub, "dispatch_id": did,
         "project": "proj-secret-name", "task": "T-1"}
    if total is not None:
        r["tokens"] = {"total": total}
    elif tok:
        r["tokens"] = tok
    return r


def limit(h, kind="5h", sub="claude-a", reset_at=None, did="d-lim", reset_text=None):
    r = {"event": "limit", "ts": ts(h), "subscription": sub, "kind": kind, "dispatch_id": did,
         "project": "proj-secret-name", "task": "T-1", "source": "dispatch"}
    if reset_at is not None:
        r["reset_at"] = ts(reset_at)
    else:
        r["reset"] = "unknown"
        if reset_text:
            r["reset_text"] = reset_text
    return r


def one(rows, sid="claude-a", need=None):
    return next(r for r in qs.status(rows, REG, NOW, need) if r["id"] == sid)


# ── rules ────────────────────────────────────────────────────────────────────

def test_future_reset_is_at_limit_until():
    r = one([limit(1, reset_at=-2)])
    assert r["state"] == "at-limit" and r["until"] == ts(-2)
    assert r["last_limit"] == {"kind": "5h", "ts": ts(1), "reset_at": ts(-2)}


def test_unknown_reset_holds_without_a_later_dispatch():
    r = one([limit(1, kind="rate")])
    assert r["state"] == "at-limit" and r["until"] == "unknown"


def test_the_dispatch_that_raised_the_limit_does_not_clear_it():
    # run.sh appends the dispatch row just after the limit row's ts (ended) — same dispatch id.
    r = one([limit(1, kind="rate", did="d-1"), disp(0.99, did="d-1", total=10)])
    assert r["state"] == "at-limit"


def test_unknown_reset_cleared_by_a_later_dispatch_is_tight_inside_its_window():
    r = one([limit(2, kind="rate"), disp(1, did="d-2", total=10)])
    assert r["state"] == "tight" and r["until"] is None
    assert "has reset" in r["reason"]


@pytest.mark.parametrize("kind,inside,outside", [
    ("5h", 4.9, 5.1), ("rate", 4.9, 5.1), ("weekly", 167, 169),
    ("balance", 23, 25), ("monthly", 23, 25), ("3h", 23, 25)])
def test_unknown_reset_expires_after_its_window(kind, inside, outside):
    assert one([limit(inside, kind=kind)])["state"] == "at-limit"
    assert one([limit(outside, kind=kind)])["state"] == "free"


def test_reset_passed_inside_window_is_tight_and_after_window_free():
    assert one([limit(3, reset_at=1)])["state"] == "tight"          # 5h window open
    assert one([limit(6, reset_at=1)])["state"] == "free"           # window closed


def test_only_the_latest_limit_decides_at_limit():
    # an older active-looking event is superseded by a newer one that has reset
    r = one([limit(4, kind="weekly", reset_at=-10), limit(2, kind="5h", reset_at=1)])
    assert r["state"] == "tight" and r["last_limit"]["kind"] == "5h"


def test_need_against_capacity_estimate():
    rows = [disp(30, total=600_000, did="a"), disp(27, total=400_000, did="b"),   # 5 h before limit
            disp(40, total=9_999_999, did="c"),                                    # outside it
            limit(26, reset_at=21),                                                # 5h, long reset
            disp(2, total=500_000, did="e")]                                       # current window
    r = one(rows, need=None)
    assert r["capacity_estimate"] == 1_000_000 and r["window_tokens"] == 500_000
    assert r["state"] == "free"
    assert one(rows, need=300_000)["state"] == "free"        # 800k = 80% of 1M: not exceeded
    t = one(rows, need=300_001)
    assert t["state"] == "tight" and "capacity estimate 1000000" in t["reason"]


def test_capacity_uses_the_most_recent_5h_limit_and_parts_when_no_total():
    rows = [disp(60, input=100, output=50, cache_read=10, did="a"), limit(58, reset_at=55),
            disp(30, total=7, did="b"), limit(29, reset_at=24),
            limit(28, kind="rate", reset_at=27)]
    assert one(rows)["capacity_estimate"] == 7
    assert qs.row_tokens({"tokens": {"input": 100, "output": 50, "cache_read": 10}}) == 160


def test_free_with_capacity_unknown():
    r = one([disp(1, total=123)], need=10**9)
    assert r["state"] == "free" and r["capacity_estimate"] is None
    assert "capacity unknown" in r["reason"]
    assert one([], sid="glm")["state"] == "free"


def test_unassigned_and_unknown_and_unregistered_ids():
    rows = [disp(1, sub="unassigned", total=5), limit(1, sub="unknown", reset_at=-1),
            disp(24 * 8, sub="gone", total=1)]   # older than 7 days: not listed
    res = {r["id"]: r for r in qs.status(rows, REG, NOW)}
    assert list(res) == ["claude-a", "glm", "unassigned", "unknown"]
    assert res["unassigned"]["registered"] is False and res["unassigned"]["state"] == "free"
    assert res["unknown"]["state"] == "at-limit"
    assert res["claude-a"]["registered"] is True
    # rows of one subscription never leak into another
    assert res["claude-a"]["window_tokens"] == 0


def test_subscription_filter():
    res = qs.status([limit(1, reset_at=-1)], REG, NOW, subscription="glm")
    assert [r["id"] for r in res] == ["glm"] and res[0]["state"] == "free"


def test_exit_codes():
    f = {"state": "free"}; t = {"state": "tight"}; a = {"state": "at-limit"}
    assert qs.exit_code([f, f]) == 0 and qs.exit_code([f, t]) == 1 and qs.exit_code([t, a, f]) == 2
    assert qs.exit_code([]) == 0


# ── CLI ──────────────────────────────────────────────────────────────────────

@pytest.fixture
def cli(tmp_path):
    led = tmp_path / "q" / "quota-ledger.jsonl"
    led.parent.mkdir()
    proj = tmp_path / "proj"
    (proj / "policy").mkdir(parents=True)
    import yaml
    (proj / "policy" / "subscriptions.yaml").write_text(yaml.safe_dump(REG))

    def run(rows, *args):
        led.write_text("".join(json.dumps(r) + "\n" for r in rows))
        env = {**os.environ, "FW_QUOTA_LEDGER": str(led), "PROJECT_ROOT": str(proj)}
        p = subprocess.run([sys.executable, str(ROOT / "lib" / "quota_status.py"), "--now", NOW.isoformat(), *args],
                           capture_output=True, text=True, env=env, cwd=str(proj), timeout=60)
        return p, led
    return run


SCENARIOS = {
    0: [disp(1, total=10)],
    1: [limit(3, reset_at=1)],
    2: [limit(1, kind="5h", sub="glm", reset_text="2026-11-16 14:12:01"), limit(3, reset_at=1)],
}


@pytest.mark.parametrize("code", [0, 1, 2])
def test_cli_exit_codes_text_json_parity_and_no_write(cli, code):
    rows = SCENARIOS[code]
    p, led = cli(rows)
    before = led.read_bytes()
    assert p.returncode == code, p.stderr
    lines = p.stdout.strip().splitlines()
    assert [l.split(":")[0] for l in lines] == ["claude-a", "glm"]
    pj, _ = cli(rows, "--json")
    assert pj.returncode == code
    data = json.loads(pj.stdout)["subscriptions"]
    # parity: every json record renders to exactly the text line
    assert [qs.line(r) for r in data] == lines
    for r, l in zip(data, lines):
        head = "at limit" if r["state"] == "at-limit" else r["state"]
        assert head in l and f"{r['window_tokens']:,}" in l
    assert led.read_bytes() == before
    assert sorted(p.name for p in led.parent.iterdir()) == ["quota-ledger.jsonl"]   # no lock, no rotation


def test_cli_output_holds_no_account_values_and_no_row_strings(cli):
    rows = SCENARIOS[2] + [disp(1, total=5, sub="unassigned"),
                           {"event": "dispatch", "ts": ts(1), "subscription": "claude-a",
                            "project": "someone@example.com", "task": "sk-abcdefghijkl",
                            "dispatch_id": "a" * 40, "tokens": {"total": 9}}]
    for args in ((), ("--json",), ("--need", "1000")):
        p, _ = cli(rows, *args)
        assert subscriptions.account_values(p.stdout) == []
        for leak in ("proj-secret-name", "T-1", "d-lim", "example.com", "sk-"):
            assert leak not in p.stdout
    assert "message says 2026-11-16 14:12:01, zone not given" in cli(rows)[0].stdout


def test_cli_need_and_subscription_flags(cli):
    rows = [disp(30, total=1000, did="a"), limit(26, reset_at=21), disp(1, total=500, did="b")]
    assert cli(rows, "--need", "200", "--subscription", "claude-a")[0].returncode == 0
    p, _ = cli(rows, "--need", "301", "--subscription", "claude-a")
    assert p.returncode == 1 and p.stdout.startswith("claude-a: tight")
    assert len(p.stdout.strip().splitlines()) == 1
    bad, _ = cli(rows, "--subscription", "nope")
    assert bad.returncode == 3 and "unknown subscription id" in bad.stderr
    neg, _ = cli(rows, "--need", "-1")
    assert neg.returncode == 3


def test_fw_quota_status_is_routed(tmp_path):
    # through bin/fw in the framework repo itself, against an empty tmp ledger
    env = {k: v for k, v in os.environ.items() if k not in ("PROJECT_ROOT", "AI_AGENT")}
    env["FW_QUOTA_LEDGER"] = str(tmp_path / "quota-ledger.jsonl")
    sid = subscriptions.load(ROOT / "policy" / "subscriptions.yaml")["subscriptions"]
    args = ["--subscription", sid[0]["id"]] if sid else []
    r = subprocess.run([str(ROOT / "bin" / "fw"), "quota", "status", *args], capture_output=True,
                       text=True, env=env, cwd=str(ROOT), timeout=60)
    assert r.returncode == 0, r.stderr
    assert (r.stdout.startswith(sid[0]["id"] + ": free") if sid else "No subscriptions" in r.stdout)
    assert not (tmp_path / "quota-ledger.jsonl").exists()
