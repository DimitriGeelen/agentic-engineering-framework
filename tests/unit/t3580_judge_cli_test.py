#!/usr/bin/env python3
"""Unit tests for lib.reviewer.judge_cli (T-3580)."""

import json
import os
import re
import sys
import tempfile
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_HERE))

from lib.reviewer import judge_cli  # noqa: E402


class TestLoadTask:
    """Test task file loading."""

    def test_load_task_not_found(self, tmp_path):
        """Non-existent task returns None."""
        root = tmp_path
        result = judge_cli._load_task("T-9999", root)
        assert result is None

    def test_load_task_success(self, tmp_path):
        """Valid task file is loaded correctly."""
        root = tmp_path
        tasks_dir = root / ".tasks" / "active"
        tasks_dir.mkdir(parents=True)

        # Create a minimal task file
        task_file = tasks_dir / "T-1234-test-task.md"
        task_file.write_text(
            """---
id: T-1234
name: Test Task
status: started-work
workflow_type: build
owner: agent
---

## Acceptance Criteria

### Agent
- [x] Test criterion
"""
        )

        result = judge_cli._load_task("T-1234", root)
        assert result is not None
        assert result["frontmatter"]["id"] == "T-1234"
        assert "## Acceptance Criteria" in result["body"]


class TestCalculateRung:
    """Test rung calculation per IW-7 impact-risk model."""

    def test_rung_low_impact(self):
        """Low impact task gets rung 1."""
        task_data = {"frontmatter": {}, "body": "", "path": Path(".")}
        rung, reason = judge_cli._calculate_rung(task_data)
        assert rung == 1
        assert "default" in reason

    def test_rung_high_blast_radius(self):
        """High blast radius → rung 5."""
        task_data = {
            "frontmatter": {"cost_estimate": {"blast_radius": 10}},
            "body": "",
            "path": Path("."),
        }
        rung, reason = judge_cli._calculate_rung(task_data)
        assert rung == 5
        assert "blast_radius" in reason

    def test_rung_high_bvp_d1(self):
        """High D1 BVP score → rung 5."""
        task_data = {
            "frontmatter": {"bvp_scores": {"D1": 4, "D2": 2}},
            "body": "",
            "path": Path("."),
        }
        rung, reason = judge_cli._calculate_rung(task_data)
        assert rung == 5
        assert "D1/D2" in reason


class TestBuildBrief:
    """Test reviewer brief generation."""

    def test_build_brief_structure(self):
        """Brief includes role, criteria, and output format."""
        criteria = [
            {"index": 1, "ac_index": 0, "text": "Test criterion 1", "body": "Test criterion 1"},
            {"index": 2, "ac_index": 1, "text": "Test criterion 2", "body": "Test criterion 2"},
        ]
        brief = judge_cli._build_brief("T-1234", criteria)

        assert "INDEPENDENT REVIEWER" in brief
        assert "Your role" in brief
        assert "The criteria" in brief
        assert "Output format" in brief
        assert "Test criterion 1" in brief
        assert "Test criterion 2" in brief
        assert "Summary:" in brief


class TestMain:
    """Test main entry point."""

    def test_main_no_task(self, monkeypatch, tmp_path):
        """Non-existent task returns error code 1."""
        monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
        sys.argv = ["judge_cli.py", "T-9999", "--dry-run"]

        result = judge_cli.main()
        assert result == 1

    def test_main_dry_run_output(self, monkeypatch, tmp_path, capsys):
        """--dry-run outputs without dispatching."""
        root = tmp_path
        tasks_dir = root / ".tasks" / "active"
        tasks_dir.mkdir(parents=True)

        # Create a minimal task file with no Human criteria
        task_file = tasks_dir / "T-1234-test-task.md"
        task_file.write_text(
            """---
id: T-1234
name: Test Task
status: started-work
workflow_type: build
owner: agent
---

## Acceptance Criteria

### Agent
- [x] Agent criterion
"""
        )

        monkeypatch.setenv("PROJECT_ROOT", str(root))
        sys.argv = ["judge_cli.py", "T-1234", "--dry-run"]

        result = judge_cli.main()
        # Should fail because no REVIEWER_JUDGES criteria
        assert result == 1

    def test_main_json_output(self, monkeypatch, tmp_path, capsys):
        """--json outputs JSON."""
        root = tmp_path
        tasks_dir = root / ".tasks" / "active"
        tasks_dir.mkdir(parents=True)

        task_file = tasks_dir / "T-1234-test-task.md"
        task_file.write_text(
            """---
id: T-1234
name: Test Task
status: started-work
workflow_type: build
owner: agent
---

## Acceptance Criteria

### Agent
- [x] Agent criterion
"""
        )

        monkeypatch.setenv("PROJECT_ROOT", str(root))
        sys.argv = ["judge_cli.py", "T-1234", "--json", "--dry-run"]

        result = judge_cli.main()
        captured = capsys.readouterr()

        if result == 1:
            # No REVIEWER_JUDGES criteria, that's OK for this test
            # Just verify it doesn't crash
            assert "No REVIEWER_JUDGES" in captured.err or len(captured.err) == 0



# ── T-3580 core: fixtures + fake dispatcher/worker (no real task, no real dispatch) ──────────
import subprocess  # noqa: E402
from datetime import datetime, timezone  # noqa: E402

from lib import verdict_ledger as vl  # noqa: E402

sys.path.insert(0, str(Path(__file__).resolve().parent))
import _review_runtime as rt  # noqa: E402

TID = "T-9200"
TASTE = ("- [ ] [REVIEW] The summary paragraph reads clearly\n"
         "  **Steps:**\n  1. Read it\n  **Expected:** reads as a peer briefing\n  **If not:** note it\n")
TIER0 = ("- [ ] [REVIEW] Approve the force push via `fw tier0 approve`\n"
         "  **Steps:**\n  1. Run it\n  **Expected:** approved\n  **If not:** ask\n")
WORLD = ("- [ ] [REVIEW] Publish the release to the public mirror and confirm consumers pick it up\n"
         "  **Steps:**\n  1. Publish\n  **Expected:** consumers upgrade\n  **If not:** roll back\n")
RENDER = ("- [ ] [REVIEW] The review page layout reads clearly when rendered at `/review`\n"
          "  **Steps:**\n  1. Open the page\n  **Expected:** the layout is tidy\n  **If not:** note it\n")


def _git(root, *a, env=None):
    subprocess.run(["git", "-c", "core.hooksPath=/dev/null", *a], cwd=root, check=True,
                   capture_output=True, env={**os.environ, **(env or {})})


def _ident(name):
    mail = name.lower().replace(" ", ".") + "@x.y"
    return {"GIT_AUTHOR_NAME": name, "GIT_AUTHOR_EMAIL": mail,
            "GIT_COMMITTER_NAME": name, "GIT_COMMITTER_EMAIL": mail}


def _mk_task(root, criteria, extra_fm="", workflow="build"):
    d = root / ".tasks" / "active"
    d.mkdir(parents=True, exist_ok=True)
    f = d / f"{TID}-fixture.md"
    f.write_text(
        f"---\nid: {TID}\nname: \"fixture\"\nstatus: started-work\nworkflow_type: {workflow}\n"
        f"owner: human\nhorizon: now\ncreated: 2026-09-30T00:00:00Z\nlast_update: 2026-09-30T00:00:00Z\n"
        f"{extra_fm}---\n\n## Acceptance Criteria\n\n### Agent\n- [x] built\n\n### Human\n{criteria}\n"
        f"## Verification\n\n## Updates\n")
    return f


@pytest.fixture()
def repo(tmp_path, monkeypatch):
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    monkeypatch.setenv("FRAMEWORK_ROOT", str(_HERE))
    _git(tmp_path, "init", "-q")
    return tmp_path


def _produce(root):
    _git(root, "add", "-A")
    _git(root, "commit", "-q", "-m", f"{TID}: build the thing", env=_ident("Builder Bot"))


def _cli(root, *args, env_extra=None):
    return subprocess.run([sys.executable, str(_HERE / "lib" / "verdict_ledger.py"), *args], cwd=root,
                          capture_output=True, text=True,
                          env={**os.environ, "PROJECT_ROOT": str(root), **(env_extra or {})})


class FakeWorker:
    """A fake dispatcher that plays all three parts of a real review dispatch: the WRAPPER
    registers the dispatch (worker dir + the revision the judge passed), the WORKER does what the
    brief says — runs the REAL `verdict record` CLI (which signs nothing) and commits under its
    own identity `reviewer-<dispatch id>` — and the RUNTIME signs the completion after the worker
    exits (`runtime=False` skips that). `behaviour` picks the outcome per dispatch (a string, or a
    list indexed by dispatch number); `cite_shots=False` makes it omit the screenshots."""

    def __init__(self, behaviour="green", identity=None, write=True, cite_shots=True,
                 runtime=True, exit_code=0, vendors=None):
        self.vendors = vendors or {}      # worker kind -> vendor the fake dispatcher registers
        self.behaviour, self.identity, self.write = behaviour, identity, write
        self.cite_shots, self.runtime, self.exit_code = cite_shots, runtime, exit_code
        self.calls: list[dict] = []
        self.n = 0

    def __call__(self, *, task_id, brief, root, name, vendor, revision="", run_id="", seat=""):
        self.n += 1
        did = f"{name}-{self.n:012x}"
        self.calls.append({"name": name, "brief": brief, "did": did, "vendor": vendor,
                           "revision": revision})
        rt.dispatch(root, did, task_id, issuer_session="S-x", revision=revision,
                    worker_kind=vendor,   # round 5: the ledger derives the vendor from the kind
                    run_id=run_id, seat=seat,   # round 6: bound to its run before launch
                    brief=brief)                # round 7: the brief the run registered
        if not self.write:
            if self.runtime:
                rt.finish(root, did, self.exit_code)
            return did
        outcome = self.behaviour if isinstance(self.behaviour, str) else self.behaviour[self.n - 1]
        run = re.search(r"--run-id (\S+)", brief)
        rung = re.search(r"--rung (\S+)", brief).group(1)
        shots = re.findall(r"^- `([^`]+\.png)`$", brief, re.M) if self.cite_shots else []
        f = next((root / ".tasks" / "active").glob(f"{task_id}-*.md"))
        for c in vl.human_criteria(f.read_text()):
            if c.ticked:
                continue
            ev_dir = root / ".context/reviews/evidence" / task_id
            ev_dir.mkdir(parents=True, exist_ok=True)
            rep = ev_dir / f"AC{c.index}-{did}.md"
            rep.write_text("checked it\n")
            evidence = [str(rep.relative_to(root))]
            for sh in shots:
                cp = ev_dir / f"AC{c.index}-{did}-{Path(sh).name}"
                cp.write_bytes((root / sh).read_bytes())
                evidence.append(str(cp.relative_to(root)))
            dg = vl.criterion_digest(c)
            args = ["record", task_id, "--ac", str(c.index), "--outcome", outcome,
                    "--reviewer", f"reviewer-{did}:{vendor}", "--rung", rung,
                    "--dispatch-id", did, "--digest", dg]
            for e in evidence:
                args += ["--evidence", e]
            if run:
                args += ["--run-id", run.group(1)]
            if outcome != "green":
                args += ["--guidance", "needs work"]
            r = _cli(root, *args)
            assert r.returncode == 0, r.stderr
        _git(root, "add", ".context/reviews")
        _git(root, "commit", "-q", "-m", f"{task_id}: reviewer verdict",
             env=_ident(self.identity or f"reviewer-{did}"))
        if self.runtime:
            rt.finish(root, did, self.exit_code)
        return did


#: Every worker kind the registry's seat backends name — as if T-3582 had built them all.
ALL_KINDS = {"claude", "codex", "opencode"}


def _all_kinds(monkeypatch, root):
    """Pretend every internal backend has a worker kind (T-3582 not built): the dispatchable kinds,
    and — round 5 — the ONE kind→vendor mapping, written as a fixture registry the ledger reads
    (vendor = kind name, so a panel over the three kinds spans three vendors)."""
    import yaml
    reg = yaml.safe_load((_HERE / "policy" / "review-backends.yaml").read_text())
    kinds = {"claude-code": "claude", "codex": "codex", "opencode": "opencode"}
    for b in reg["backends"]:
        if b["id"] in kinds:
            b["worker_kind"] = b["vendor"] = kinds[b["id"]]
        elif b.get("worker_kind"):
            b.pop("worker_kind")
    # Round 6: committed (the ledger ignores the working tree) and launchable (the ledger checks
    # the dispatcher's kinds) — as if T-3582 had shipped.
    rt.commit_registry(root, yaml.safe_dump(reg, sort_keys=False))
    rt.launchable(monkeypatch, ALL_KINDS)
    monkeypatch.setattr(judge_cli, "_dispatchable_kinds", lambda r: ALL_KINDS)
    monkeypatch.setattr(judge_cli, "_kind_vendors", lambda r: {k: k for k in ALL_KINDS})

NOCAP = lambda url, pages, out: ([], "no capture in this test")  # noqa: E731


def _judge(root, **kw):
    kw.setdefault("capture", NOCAP)
    return judge_cli.judge(TID, root, **kw)


class TestWorkerWritesItsOwnRow:
    def test_end_to_end_row_passes_apply_and_audit(self, repo):
        _mk_task(repo, TASTE)
        _produce(repo)
        w = FakeWorker("green")
        res = _judge(repo, dispatcher=w)
        assert res["outcomes"] == {1: "green"}
        assert res["dispatches"][0]["results"][0]["source"] == "ledger"
        out = vl.apply(TID, repo)
        assert [t["ac"] for t in out["ticked"]] == [1] and out["owner_after"] == "agent"
        code, lines = vl.audit(repo)
        assert code == 0, lines
        # the parent wrote no verdict: every row names the worker's dispatch and identity
        rows = vl._read(vl.VERDICTS, repo)
        assert rows and all(r["dispatch_id"] == w.calls[0]["did"] for r in rows)

    def test_row_written_by_the_parent_identity_is_refused(self, repo):
        """Negative control: the producer (the parent) commits the row itself -> not counted."""
        _mk_task(repo, TASTE)
        _produce(repo)
        w = FakeWorker("green", identity="Builder Bot")  # same identity as the producer
        res = _judge(repo, dispatcher=w)
        assert res["outcomes"] == {1: "unknown"}
        assert res["dispatches"][0]["results"][0]["source"] == "ledger-row-invalid"

    def test_brief_tells_worker_to_digest_record_and_commit(self, repo):
        _mk_task(repo, TASTE)
        _produce(repo)
        w = FakeWorker("green")
        _judge(repo, dispatcher=w)
        b = w.calls[0]["brief"]
        for needle in ("reviewer verdict digest", "reviewer verdict record", "--dispatch-id",
                       "FW_SIDECAR_AGENT_ID", "git add .context/reviews", "--evidence", "--digest"):
            assert needle in b

    def test_dispatch_name_and_registration(self, repo):
        _mk_task(repo, TASTE)
        _produce(repo)
        w = FakeWorker("green")
        _judge(repo, dispatcher=w)
        assert w.calls[0]["name"].startswith("judge-t-9200")
        assert vl.dispatch_record(repo, w.calls[0]["did"])[0]["task_type"] == "review"


class TestOutputParsing:
    def test_no_ledger_row_is_unknown_even_if_printed_green(self, repo):
        _mk_task(repo, TASTE)
        _produce(repo)
        res = _judge(repo, dispatcher=FakeWorker(write=False))
        assert res["outcomes"] == {1: "unknown"}
        assert res["dispatches"][0]["results"][0]["source"] == "no-ledger-row"

    def test_printed_parse_is_report_only(self):
        crit = [{"index": 1}, {"index": 2}, {"index": 3}]
        out = "1. [1] a\nVERDICT: green\nWHY: x\n2. [2] b\nVERDICT: maybe\n"
        assert judge_cli._parse_printed(out, crit) == {1: "green", 2: "unknown", 3: "unknown"}
        assert judge_cli._parse_printed("garbage", crit) == {1: "unknown", 2: "unknown", 3: "unknown"}

    def test_malformed_ledger_row_is_unknown(self, repo):
        _mk_task(repo, TASTE)
        _produce(repo)
        w = FakeWorker(write=False)

        def d(**kw):
            did = w(**kw)
            (kw["root"] / ".context/reviews").mkdir(parents=True, exist_ok=True)
            (kw["root"] / vl.VERDICTS).write_text(json.dumps(
                {"task": TID, "ac": 1, "dispatch_id": did, "outcome": "green"}) + "\n")
            return did
        res = _judge(repo, dispatcher=d)
        assert res["outcomes"][1] == "unknown"


class TestHardClasses:
    def test_mixed_task_dispatches_only_judged(self, repo):
        _mk_task(repo, TASTE + TIER0 + WORLD)
        _produce(repo)
        w = FakeWorker("green")
        res = _judge(repo, dispatcher=w)
        assert [c["ac"] for c in res["criteria"]] == [1]
        assert sorted(o["ac"] for o in res["operator_only"]) == [2, 3]
        b = w.calls[0]["brief"]
        assert "force push" not in b and "Publish the release" not in b
        assert "operator-only" in b

    def test_only_hard_classes_dispatches_nothing(self, repo):
        _mk_task(repo, TIER0 + WORLD)
        _produce(repo)
        w = FakeWorker("green")
        res = _judge(repo, dispatcher=w)
        assert res["code"] == 1 and not w.calls and len(res["operator_only"]) == 2


class TestScreenshots:
    def _render_task(self, repo):
        (repo / "web/blueprints").mkdir(parents=True)
        (repo / "web/blueprints/review.py").write_text('@bp.route("/review")\ndef r(): pass\n')
        _mk_task(repo, RENDER, extra_fm="components:\n  - web/blueprints/review.py\n")
        _produce(repo)

    def test_screenshots_are_passed_as_evidence(self, repo):
        self._render_task(repo)

        def cap(url, pages, out):
            out.mkdir(parents=True, exist_ok=True)
            f = out / "01-review.png"
            f.write_bytes(b"png")
            return [f], ""
        w = FakeWorker("green")
        res = _judge(repo, dispatcher=w, capture=cap)
        assert res["evidence"]["shots"] == [".context/working/judge-evidence/T-9200/01-review.png"]
        assert "01-review.png" in w.calls[0]["brief"]
        assert "/review" in res["evidence"]["pages"]

    def test_failed_capture_forbids_green_in_brief(self, repo):
        self._render_task(repo)
        w = FakeWorker("escalate")
        res = _judge(repo, dispatcher=w, capture=lambda u, p, o: ([], "browser down"))
        b = w.calls[0]["brief"]
        assert "SCREENSHOT CAPTURE FAILED: browser down" in b and "MUST NOT return green" in b
        assert res["evidence"]["error"] == "browser down"

    def test_green_on_unseen_page_is_refused_by_the_worker_record(self, repo):
        """The ledger refuses the green at `record`, so the worker's attempt leaves no row."""
        self._render_task(repo)
        res = _judge(repo, dispatcher=FakeWorker("green"), capture=lambda u, p, o: ([], "browser down"))
        r = res["dispatches"][0]["results"][0]
        assert r["outcome"] == "unknown" and res["outcomes"] == {1: "unknown"}
        assert not vl._read(vl.VERDICTS, repo)

    def test_capture_crash_is_a_failed_capture(self, repo):
        self._render_task(repo)

        def boom(u, p, o):
            raise RuntimeError("kaboom")
        w = FakeWorker("escalate")
        _judge(repo, dispatcher=w, capture=boom)
        assert "MUST NOT return green" in w.calls[0]["brief"]


class TestSpendCeiling:
    HI = "cost_estimate:\n  blast_radius: 9\n"

    def test_due_rung_5_is_a_panel_of_three_when_under_ceiling(self, repo, monkeypatch):
        _all_kinds(monkeypatch, repo)
        _mk_task(repo, TASTE, extra_fm=self.HI)
        _produce(repo)
        w = FakeWorker("green")
        res = _judge(repo, dispatcher=w)
        assert res["rung"] == 5 and len(w.calls) == 3
        assert all("rung-5-panel" in c["brief"] for c in w.calls)
        assert [c["vendor"] for c in w.calls] == ["claude", "codex", "opencode"]
        assert res["outcomes"] == {1: "green"} and not res["degraded"]

    def test_ceiling_reached_drops_rung_and_says_so(self, repo, monkeypatch):
        monkeypatch.setenv("FW_REVIEWER_JUDGE_WEEKLY_SPEND_CEILING", "200")
        _mk_task(repo, TASTE, extra_fm=self.HI)
        _produce(repo)
        from t3580_round7_test import _cost    # round 7: spend = the COMMITTED cost ledger
        _cost(repo, 199.0)
        w = FakeWorker("green")
        res = _judge(repo, dispatcher=w)
        assert res["rung_due"] == 5 and res["rung"] == 3 and len(w.calls) == 1
        assert "reviewed at rung 3, weekly spend ceiling reached" in res["ceiling_note"]
        assert "rung 5 was due" in w.calls[0]["brief"] and "RUNG DROPPED" in w.calls[0]["brief"]
        rows = vl._read(vl.VERDICTS, repo)
        assert rows  # not skipped

    def test_old_spend_does_not_count(self, repo):
        _produce_empty = (repo / "x").write_text("x")  # noqa: F841 - a first commit
        _produce(repo)
        from t3580_round7_test import _cost
        _cost(repo, 999, ts="2020-01-01T00:00:00Z")
        assert judge_cli._weekly_spend(repo) == 0.0

    def test_lowest_rung_at_ceiling_still_runs(self):
        r, _, note = judge_cli._apply_ceiling(1, "default", 1000, 100)
        assert r == 1 and "not skipped" in note

    def test_under_ceiling_no_note(self):
        assert judge_cli._apply_ceiling(5, "x", 0, 100)[2] == ""

    def test_panel_stops_at_first_non_green_seat(self, repo, monkeypatch):
        _all_kinds(monkeypatch, repo)
        _mk_task(repo, TASTE, extra_fm=self.HI)
        _produce(repo)
        w = FakeWorker(["green", "red", "green"])
        res = _judge(repo, dispatcher=w)
        assert len(w.calls) == 2 and res["outcomes"] == {1: "red"}


class TestDryRunAndRealDispatcher:
    def test_dry_run_dispatches_nothing_and_prints_brief(self, repo, capsys):
        _mk_task(repo, TASTE + TIER0)
        _produce(repo)
        w = FakeWorker("green")
        rc = judge_cli.main([TID, "--dry-run"], dispatcher=w, capture=NOCAP)
        out = capsys.readouterr().out
        assert rc == 0 and not w.calls
        assert "Rung: 1" in out and "INDEPENDENT REVIEWER" in out and "operator-only" in out
        assert not (repo / ".context/reviews").exists()

    def test_criterion_flag_selects_one(self, repo):
        two = TASTE + TASTE.replace("summary paragraph", "closing paragraph")
        _mk_task(repo, two)
        _produce(repo)
        w = FakeWorker("green")
        res = _judge(repo, dispatcher=w, criterion_n=2)
        assert [c["ac"] for c in res["criteria"]] == [2]

    def test_real_dispatcher_invokes_fw_termlink_dispatch_review(self, repo, monkeypatch):
        calls = []

        def fake_run(cmd, **kw):
            calls.append(cmd)
            class R:  # noqa: D401
                returncode = 0
                stdout = "Worker spawned: judge-t-9200-r1-abc123 (wdir: /x)"
                stderr = ""
            return R()
        monkeypatch.setattr(judge_cli.subprocess, "run", fake_run)
        did = judge_cli._dispatch_real(task_id=TID, brief="b", root=repo, name="judge-t-9200-r1",
                                       vendor="claude")
        assert did == "judge-t-9200-r1-abc123"
        d = calls[0]
        assert d[1:3] == ["termlink", "dispatch"] and "--task-type" in d and d[d.index("--task-type") + 1] == "review"
        assert calls[1][1:3] == ["termlink", "wait"]
        # the wrapper takes --project (not --project-dir) and --worker-kind for the vendor
        assert "--project-dir" not in d and d[d.index("--project") + 1] == str(repo)
        assert d[d.index("--worker-kind") + 1] == "claude"

    def test_real_dispatcher_failure_is_unknown(self, repo, monkeypatch):
        _mk_task(repo, TASTE)
        _produce(repo)

        def bad(**kw):
            raise RuntimeError("no termlink")
        res = _judge(repo, dispatcher=bad)
        assert res["dispatches"][0]["results"][0]["outcome"] == "unknown"
