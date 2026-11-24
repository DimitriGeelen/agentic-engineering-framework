"""T-5392: pure parts of the node1 nightly run (agents/audit/node1_nightly.py).

Hermetic: no network, no termlink, no pool-client — every external call goes through a
fake runner, time through a fake clock.
"""
import base64
import importlib.util
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("node1_nightly", ROOT / "agents/audit/node1_nightly.py")
assert spec and spec.loader
nn = importlib.util.module_from_spec(spec)
sys.modules["node1_nightly"] = nn
spec.loader.exec_module(nn)

NOW = 1_800_000_000.0


def feed(state="healthy", age=10, stale=180, reasons=(), now=NOW):
    return {"generated_at": nn.iso(now - age), "stale_after_s": stale,
            "health": {"state": state, "reasons": list(reasons)}}


# ── exclusions and selection ────────────────────────────────────────────────────────

def test_load_exclusions_strips_comments_blanks_and_duplicates(tmp_path):
    f = tmp_path / "x.txt"
    f.write_text("# head\n\ntests/unit/a.bats  # why\ntests/unit/b.py\ntests/unit/a.bats\n")
    assert nn.load_exclusions(f) == ["tests/unit/a.bats", "tests/unit/b.py"]


def test_select_drops_excluded_and_counts_them():
    files = ["tests/unit/a.bats", "tests/unit/b.bats", "tests/unit/c.py"]
    send, hits = nn.select(files, ["tests/unit/b.bats", "tests/unit/zz.bats"])
    assert send == ["tests/unit/a.bats", "tests/unit/c.py"]
    assert hits == ["tests/unit/b.bats"]


def test_select_only_limit_and_include_excluded():
    files = ["tests/unit/a.bats", "tests/unit/b.bats", "tests/unit/c.py"]
    send, hits = nn.select(files, ["tests/unit/b.bats"], only=["tests/unit/b.bats", "tests/unit/c.py"])
    assert send == ["tests/unit/c.py"] and hits == ["tests/unit/b.bats"]
    send, _ = nn.select(files, ["tests/unit/b.bats"], only=["tests/unit/b.bats"], include_excluded=True)
    assert send == ["tests/unit/b.bats"]
    send, _ = nn.select(files, [], limit=2)
    assert send == ["tests/unit/a.bats", "tests/unit/b.bats"]


def test_discover_matches_unit_suite_rules(tmp_path):
    d = tmp_path / "tests/unit"
    d.mkdir(parents=True)
    for n, body in {"a.bats": "", "test_x.py": "", "y_test.py": "", "t1_z.py": "def test_q():\n    pass\n",
                    "helper.py": "X = 1\n", "conftest.py": "def test_no(): pass\n",
                    "_private.py": "def test_no(): pass\n", "notes.txt": ""}.items():
        (d / n).write_text(body)
    assert nn.discover(d, tmp_path) == ["tests/unit/a.bats", "tests/unit/t1_z.py",
                                        "tests/unit/test_x.py", "tests/unit/y_test.py"]


def test_committed_exclusion_file_is_well_formed():
    items = nn.load_exclusions(nn.DEFAULT_EXCLUDE)
    assert items, "exclusion list is empty"
    for p in items:
        assert p.startswith("tests/unit/") and (p.endswith(".bats") or p.endswith(".py")), p


# ── feed health ─────────────────────────────────────────────────────────────────────

def test_feed_health_healthy():
    assert nn.feed_health(feed(), NOW) == (True, "healthy")


def test_feed_health_degraded_names_state_and_reasons():
    ok, why = nn.feed_health(feed("degraded", reasons=["canary failing"]), NOW)
    assert not ok and "health.state=degraded" in why and "canary failing" in why


def test_feed_health_stale_or_missing_is_unhealthy():
    ok, why = nn.feed_health(feed(age=500, stale=180), NOW)
    assert not ok and "stale" in why
    assert nn.feed_health(None, NOW)[0] is False
    assert nn.feed_health({"health": {"state": "healthy"}}, NOW)[0] is False


class Clock:
    def __init__(self):
        self.t = NOW

    def now(self):
        return self.t

    def sleep(self, s):
        self.t += s


class FakeRun:
    """Answers termlink pool:feed reads with a fresh feed doc per call; the health states
    come from a list (the last one repeats)."""

    def __init__(self, states, clock):
        self.states, self.clock, self.calls = list(states), clock, []

    def __call__(self, cmd, input=None, timeout=120):
        self.calls.append(list(cmd))
        state = self.states.pop(0) if len(self.states) > 1 else self.states[0]
        doc = feed(state, now=self.clock.t)
        line = json.dumps({"offset": 1, "payload_b64": base64.b64encode(json.dumps(doc).encode()).decode()})
        return subprocess.CompletedProcess(cmd, 0, line + "\n", "")


def make_run(tmp_path, states, clock):
    run = FakeRun(states, clock)
    return nn.Node1Run(tmp_path, run=run, sleep=clock.sleep, now=clock.now, log=lambda _m: None), run


def test_hold_never_sends_and_gives_up_with_reason(tmp_path, monkeypatch):
    monkeypatch.setenv("NODE1_HOLD_POLL_S", "300")
    monkeypatch.setenv("NODE1_HOLD_MAX_S", "900")
    clock = Clock()
    nr, run = make_run(tmp_path, ["degraded"], clock)
    holds = []
    why = nr.wait_healthy(holds, deadline=NOW + 10_000)
    assert why and "health.state=degraded" in why
    assert holds and holds[0]["reason"].startswith("health.state=degraded") and "gave_up" in holds[0]
    assert all(c[1:3] == ["channel", "subscribe"] for c in run.calls), "only feed reads while held"
    assert clock.t - NOW >= 900


def test_hold_resumes_when_feed_turns_healthy(tmp_path, monkeypatch):
    monkeypatch.setenv("NODE1_HOLD_POLL_S", "300")
    monkeypatch.setenv("NODE1_HOLD_MAX_S", "10800")
    clock = Clock()
    nr, _ = make_run(tmp_path, ["degraded", "degraded", "healthy"], clock)
    holds = []
    assert nr.wait_healthy(holds, deadline=NOW + 100_000) is None
    assert holds[0].get("until") and "gave_up" not in holds[0]


def test_submit_loop_holds_on_unhealthy_feed_and_marks_rest_not_sent(tmp_path, monkeypatch):
    monkeypatch.setenv("NODE1_HOLD_MAX_S", "600")
    monkeypatch.setenv("NODE1_HOLD_POLL_S", "300")
    clock = Clock()
    nr, run = make_run(tmp_path, ["degraded"], clock)
    _outcomes, not_sent, gave_up = nn.submit_and_collect(
        nr, ["tests/unit/a.bats", "tests/unit/b.py"], "202611240000", "f" * 64,
        tmp_path / "jobs", tmp_path / "res", [], NOW + 100_000)
    assert gave_up and set(not_sent) == {"tests/unit/a.bats", "tests/unit/b.py"}
    assert not any("submit-cmd" in c for c in run.calls)


# ── grading and report ──────────────────────────────────────────────────────────────

def test_grade():
    assert nn.grade(0, "ok 1 x\naef-run-unit: exit 0\n") == ("passed", "")
    st, d = nn.grade(1, "ok 1 x\nnot ok 2 y\naef-run-unit: exit 1\n")
    assert st == "failed" and "1 not ok" in d
    st, d = nn.grade(1, "FAILED tests/unit/t.py::test_a - x\n1 failed\naef-run-unit: exit 1\n")
    assert st == "failed" and "1 FAILED" in d
    assert nn.grade(0, "aef-run-unit: exit 124\n")[0] == "timeout"
    assert nn.grade(0, "not ok 1 hidden red\naef-run-unit: exit 0\n")[0] == "failed"


def test_report_counts_and_new_marking():
    to_send = ["tests/unit/a.bats", "tests/unit/b.bats", "tests/unit/c.py", "tests/unit/d.py",
               "tests/unit/e.bats", "tests/unit/f.bats"]
    outcomes = {"tests/unit/a.bats": {"status": "passed"},
                "tests/unit/b.bats": {"status": "failed", "detail": "exit 1, 1 not ok"},
                "tests/unit/c.py": {"status": "timeout", "detail": "cap"},
                "tests/unit/d.py": {"status": "failed", "detail": "exit 1"},
                "tests/unit/e.bats": {"status": "not-collected", "detail": "no unit.log"}}
    r = nn.build_report(run_id="r", commit="c", bundle_sha="s", discovered=10,
                        excluded=["tests/unit/d.py", "tests/unit/x.bats"],
                        exclusions=["tests/unit/d.py", "tests/unit/x.bats"], to_send=to_send,
                        outcomes=outcomes, not_sent={"tests/unit/f.bats": "held"}, holds=[],
                        started="s", finished="f", gave_up=None)
    c = r["counts"]
    assert (c["discovered"], c["excluded"], c["submitted"], c["passed"], c["failed"], c["timeout"],
            c["not_collected"], c["not_sent"], c["new_failures"]) == (10, 2, 5, 1, 2, 1, 1, 1, 2)
    new = {f["file"]: f["new"] for f in r["failures"]}
    assert new == {"tests/unit/b.bats": True, "tests/unit/c.py": True, "tests/unit/d.py": False}
    assert r["not_collected"][0]["reason"] == "no unit.log"


def test_job_name_is_stable_and_bounded():
    assert nn.job_name("202611240300", "tests/unit/t3051_exec_bit_gates.bats") == \
        "aef-n1-202611240300-t3051-exec-bit-gates-bats"
    assert len(nn.job_name("2026", "tests/unit/" + "x" * 300 + ".py")) == 100


class FakePool(FakeRun):
    """Feed reads healthy; pool-client submit-cmd/status/wait simulated on disk. A job's
    result arrives two polls after submission; never more than max_open in flight."""

    def __init__(self, clock, state_dir, fail=()):
        super().__init__(["healthy"], clock)
        self.state_dir, self.fail = state_dir, set(fail)
        self.inflight, self.peak, self.submitted = {}, 0, []

    def __call__(self, cmd, input=None, timeout=120):
        if cmd[1:3] == ["channel", "subscribe"]:
            return super().__call__(cmd, input, timeout)
        args = cmd[cmd.index("--window") + 2:]
        res = self.state_dir / "results"
        res.mkdir(parents=True, exist_ok=True)
        if args[0] == "submit-cmd":
            name = args[args.index("--name") + 1]
            target = (Path(args[1]) / "target.txt").read_text().strip()
            self.inflight[name] = [2, target]
            self.submitted.append(name)
            self.peak = max(self.peak, len(self.inflight))
        elif args[0] == "status":
            for name in list(self.inflight):
                self.inflight[name][0] -= 1
                if self.inflight[name][0] <= 0:
                    (res / f"{name}.json").write_text("{}")
                    self.inflight[name].append("done")
        elif args[0] == "wait":
            name, out = args[1], Path(args[args.index("--dir") + 1])
            target = self.inflight.pop(name)[1]
            d = out / name
            d.mkdir(parents=True, exist_ok=True)
            bad = target in self.fail
            (d / "exit_code").write_text("1\n" if bad else "0\n")
            (d / "unit.log").write_text(("not ok 1 x\n" if bad else "ok 1 x\n")
                                        + f"aef-run-unit: exit {1 if bad else 0}\n")
            (d / "pool-result.json").write_text('{"outcome": "done"}')
        return subprocess.CompletedProcess(cmd, 0, "", "")


def test_submit_loop_caps_open_jobs_and_collects_everything(tmp_path, monkeypatch):
    monkeypatch.setenv("NODE1_MAX_OPEN", "3")
    clock = Clock()
    files = [f"tests/unit/f{i}.bats" for i in range(8)] + ["tests/unit/test_p.py"]
    pool = FakePool(clock, tmp_path / ".context/scratch/node1-pool-state", fail={"tests/unit/f3.bats"})
    nr = nn.Node1Run(tmp_path, run=pool, sleep=clock.sleep, now=clock.now, log=lambda _m: None)
    outcomes, not_sent, gave_up = nn.submit_and_collect(nr, files, "r1", "a" * 64, tmp_path / "jobs",
                                                        tmp_path / "res", [], NOW + 100_000)
    assert gave_up is None and not_sent == {}
    assert pool.peak <= 3 and len(pool.submitted) == len(files)
    assert {f: o["status"] for f, o in outcomes.items()} == {
        **{f: "passed" for f in files if f != "tests/unit/f3.bats"}, "tests/unit/f3.bats": "failed"}
    assert (tmp_path / "jobs" / nn.job_name("r1", "tests/unit/test_p.py") / "target.txt").read_text() == \
        "tests/unit/test_p.py\n"
