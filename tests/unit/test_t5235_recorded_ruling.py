"""T-5235 — a recorded operator ruling makes an act-in-the-world or operator-marked criterion
reviewer-judgeable (operator ruling 2026-11-18, question 6, option A). One test group per Agent
criterion of T-5235. tmp_path roots only: this repo's real ledgers are never written."""
import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "lib"))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib import delegation_widening as dw  # noqa: E402
from lib import recorded_ruling as rr  # noqa: E402
from lib import shell_write_scan as sws  # noqa: E402
from lib import verdict_ledger as vl  # noqa: E402
from lib.delegation import OPERATOR_ONLY, REVIEWER_JUDGES, classify, human_criteria  # noqa: E402
from lib.reviewer import judge_cli  # noqa: E402

from test_t3579_verdict_ledger import (  # noqa: E402,F401  (fixtures + autouse)
    TASK, WORLD, TIER0, _rec, _task, _lines, _humans, _text, _worker_attributed_reviewer,
    hermetic_review_env, root,
)

HOOK = ROOT / "agents" / "context" / "check-human-ac-tick.py"
NOTIFY = ("- [ ] [REVIEW] Send a notification to the ops channel and confirm it arrives\n"
          "  **Steps:**\n  1. Send it\n  **Expected:** it arrives\n  **If not:** check the hub\n")
MARKED = ("- [ ] [REVIEW] [OPERATOR] Decide whether the nightly job may run unattended\n"
          "  **Steps:**\n  1. Decide\n  **Expected:** a ruling\n  **If not:** ask\n")
SOVEREIGN = ("- [ ] [REVIEW] Publish the scores with fw bvp confirm on the release\n"
             "  **Steps:**\n  1. Run it\n  **Expected:** confirmed\n  **If not:** ask\n")
# 832 T-676 AC1: a ruling question whose body merely lists once-refused commands
T676 = ("- [ ] [REVIEW] Should P-002 exempt read-only Bash when focus is absent, captured, or "
        "work-completed? GO / NO-GO / DEFER\n"
        "  **Steps:**\n  1. Read the commands the gate once refused: `git status`, `git log`, "
        "`git push`\n  2. Rule\n"
        "  **Expected:** a recorded ruling\n  **If not:** DEFER\n")


@pytest.fixture()
def operator(monkeypatch):
    monkeypatch.delenv("CLAUDECODE", raising=False)
    monkeypatch.delenv("AI_AGENT", raising=False)


def _crit(root, ac=1):
    return next(c for c in human_criteria(_text(root)) if c.index == ac)


def _record(root, ac=1, ruling="a", ref="operator, 2026-11-18"):
    return rr.record(root, TASK, ac, ruling, ref)


def _judged(root):
    f = next((root / ".tasks" / "active").glob(f"{TASK}-*.md"))
    data = {"path": f, "text": f.read_text(), "frontmatter": {"id": TASK}}
    return judge_cli._partition(data, root, TASK)


# ── AC 1: the verb, the ledger, the guards ───────────────────────────────────

def test_record_writes_an_append_only_digest_bound_row(root, operator):
    _task(root, NOTIFY + WORLD)
    r1 = _record(root)
    r2 = _record(root, ac=2, ruling="publish it")
    rows = _lines(root, rr.RULINGS)
    assert rows == [r1, r2]
    assert r1["id"].startswith("RL-") and r1["task"] == TASK and r1["ac"] == 1
    assert r1["ac_digest"] == vl.criterion_digest(_crit(root))
    assert r1["ruling"] == "a" and r1["ref"] and r1["by"] != "agent-override"


@pytest.mark.parametrize("env", [{"CLAUDECODE": "1"}, {"AI_AGENT": "codex"}])
def test_record_refused_under_agent_control_even_with_i_am_human(root, monkeypatch, env):
    _task(root, NOTIFY)
    monkeypatch.setenv("PROJECT_ROOT", str(root))
    for k, v in env.items():
        monkeypatch.setenv(k, v)
    args = ["record", TASK, "--ac", "1", "--ruling", "a", "--ref", "x"]
    assert rr.main(args) == 2
    assert rr.main(args + ["--i-am-human"]) == 2
    assert not (root / rr.RULINGS).exists()
    assert rr.main(args + ["--dry-run"]) == 0          # a dry run writes nothing
    assert not (root / rr.RULINGS).exists()


def test_record_refuses_tier0_sovereignty_and_non_operator_criteria(root, operator):
    _task(root, TIER0 + SOVEREIGN + "- [ ] [REVIEW] The summary reads clearly\n")
    for ac in (1, 2):
        with pytest.raises(rr.Refused, match="stays with the operator"):
            _record(root, ac=ac)
    with pytest.raises(rr.Refused, match="nothing to lift"):
        _record(root, ac=3)
    with pytest.raises(rr.Refused, match="no Human criterion 9"):
        _record(root, ac=9)
    assert not (root / rr.RULINGS).exists()


@pytest.mark.parametrize("cmd", [
    "bin/fw reviewer ruling record T-1 --ac 1 --ruling a --ref x",
    "bin/fw reviewer ruling record T-1 --ac 1 --ruling a --ref x --i-am-human",
    "env -u CLAUDECODE bin/fw reviewer ruling record T-1 --ac 1 --ruling a --ref x",
    "python3 lib/recorded_ruling.py record T-1 --ac 1 --ruling a --ref x",
    "python3 -m lib.recorded_ruling record T-1 --ac 1 --ruling a --ref x",
    "echo '{}' >> .context/reviews/recorded-rulings.jsonl",
    "sed -i 's/a/b/' .context/reviews/recorded-rulings.jsonl",
    "cp /tmp/x .context/reviews/recorded-rulings.jsonl",
])
def test_bash_text_gate_refuses_agent_writes_to_the_ledger(cmd):
    assert sws.scan(cmd, cwd=str(ROOT), project_root=str(ROOT)), cmd


@pytest.mark.parametrize("cmd", [
    "bin/fw reviewer ruling record --help",
    "bin/fw reviewer ruling record T-1 --ac 1 --ruling a --ref x --dry-run",
    "bin/fw reviewer ruling list",
    "cat .context/reviews/recorded-rulings.jsonl",
])
def test_bash_text_gate_passes_reads_help_and_dry_run(cmd):
    assert not sws.scan(cmd, cwd=str(ROOT), project_root=str(ROOT)), cmd


@pytest.mark.parametrize("tool", ["Write", "Edit"])
def test_write_edit_guard_refuses_the_ledger(tool):
    env = {k: v for k, v in os.environ.items()
           if k not in ("CLAUDECODE", "AI_AGENT", "FW_ALLOW_HUMAN_AC_TICK")}
    env["CLAUDECODE"] = "1"
    path = "/tmp/proj/.context/reviews/recorded-rulings.jsonl"
    ti = {"file_path": path, "content": "{}\n"} if tool == "Write" else \
        {"file_path": path, "old_string": "a", "new_string": "b"}
    p = subprocess.run([sys.executable, str(HOOK)], input=json.dumps(
        {"tool_name": tool, "tool_input": ti}), capture_output=True, text=True, env=env)
    assert p.returncode == 2 and "recorded-rulings.jsonl" in p.stderr


# ── AC 2: classification through the one decision point ─────────────────────

@pytest.mark.parametrize("body,cls", [(NOTIFY, "act-in-the-world"), (MARKED, "operator-marked")])
def test_valid_ruling_lifts_act_and_marked_to_reviewer_judged(root, operator, body, cls):
    _task(root, body)
    c = _crit(root)
    assert classify(c).cls == cls and classify(c).delegation_class == OPERATOR_ONLY
    assert dw.active_widening(root, TASK, _text(root), c) == (None, "")
    row = _record(root)
    w, why = dw.active_widening(root, TASK, _text(root), c)
    assert why == "" and w["id"] == row["id"] and w["kind"] == "ruling"
    assert dw.widened_note(w) == f"ruling recorded ({row['id']})"
    judged, operator_only = _judged(root)
    assert [j["ac_index"] for j in judged] == [1] and operator_only == []


def test_ruling_voided_by_an_edit_to_the_criterion(root, operator):
    f = _task(root, NOTIFY)
    _record(root)
    f.write_text(f.read_text().replace("confirm it arrives", "confirm it arrives twice"))
    w, why = dw.active_widening(root, TASK, _text(root), _crit(root))
    assert w is None and "edited since" in why
    judged, operator_only = _judged(root)
    assert judged == [] and len(operator_only) == 1


def test_a_hand_written_agent_override_or_malformed_ledger_never_applies(root, operator):
    _task(root, NOTIFY)
    row = _record(root)
    p = root / rr.RULINGS
    p.write_text(json.dumps({**row, "id": "RL-0000beef", "by": "agent-override"}) + "\n")
    w, why = dw.active_widening(root, TASK, _text(root), _crit(root))
    assert w is None and "agent control" in why
    p.write_text(json.dumps(row) + "\nnot json\n")
    w, why = dw.active_widening(root, TASK, _text(root), _crit(root))
    assert w is None and "not JSON" in why
    p.write_text(json.dumps(row) + "\n" + json.dumps(row) + "\n")
    assert dw.active_widening(root, TASK, _text(root), _crit(root))[0] is None


def test_ledger_is_append_only_against_its_committed_version(root, operator):
    _task(root, NOTIFY)
    row = _record(root)
    subprocess.run(["git", "-c", "core.hooksPath=/dev/null", "add", "-A"], cwd=root, check=True)
    subprocess.run(["git", "-c", "core.hooksPath=/dev/null", "-c", "user.name=o", "-c",
                    "user.email=o@x", "commit", "-qm", "x"], cwd=root, check=True)
    assert dw.active_widening(root, TASK, _text(root), _crit(root))[0]["id"] == row["id"]
    (root / rr.RULINGS).write_text(json.dumps({**row, "ruling": "b"}) + "\n")
    w, why = dw.active_widening(root, TASK, _text(root), _crit(root))
    assert w is None and "append-only" in why


@pytest.mark.parametrize("body,cls", [(TIER0, "tier0-or-bypass"), (SOVEREIGN, "sovereignty-field")])
def test_tier0_and_sovereignty_stay_operator_only_even_with_a_ruling(root, operator, body, cls):
    _task(root, body)
    c = _crit(root)
    assert classify(c).cls == cls
    # the verb refuses; a hand-appended row (operator provenance, right digest) still never lifts
    (root / ".context" / "reviews").mkdir(parents=True, exist_ok=True)
    (root / rr.RULINGS).write_text(json.dumps(
        {"ts": "2026-11-18T00:00:00Z", "id": "RL-0000aaaa", "task": TASK, "ac": 1,
         "ac_digest": vl.criterion_digest(c), "ruling": "yes", "ref": "op", "by": "op"}) + "\n")
    w, why = dw.active_widening(root, TASK, _text(root), c)
    assert w is None and "stays with the operator" in why
    judged, operator_only = _judged(root)
    assert judged == [] and len(operator_only) == 1
    with pytest.raises(vl.VerdictRefused, match="only the operator"):
        _rec(root)


def test_delegate_report_names_the_ruling(root, operator, monkeypatch):
    _task(root, NOTIFY)
    row = _record(root)
    monkeypatch.setenv("PROJECT_ROOT", str(root))
    from lib import delegation_cli  # noqa: PLC0415
    from lib.delegation import classify as cl  # noqa: PLC0415
    c = _crit(root)
    rows = [(c, cl(c))]
    wid = delegation_cli._widenings(TASK, _text(root), rows)
    entry = delegation_cli._refused_entry(c, rows[0][1], wid.get(1))
    assert entry["delegation_class"] == REVIEWER_JUDGES
    assert entry["ruling_recorded"] == row["id"] and "ruling recorded (RL-" in entry["reason"]


# ── AC 3: the verdict ledger and the brief ───────────────────────────────────

def test_green_records_and_applies_only_while_the_ruling_is_valid(root, operator):
    f = _task(root, NOTIFY)
    with pytest.raises(vl.VerdictRefused, match="only the operator"):
        _rec(root)
    row = _record(root)
    rec = _rec(root)
    assert rec["widened_by"] == row["id"]
    res = vl.apply(TASK, root)
    assert [t["verdict_id"] for t in res["ticked"]] == [rec["id"]]
    assert _humans(f)[0].ticked and f"ruling recorded ({row['id']})" in f.read_text()
    again = vl.apply(TASK, root)
    assert again["ticked"] == [] and again["recited"] == [] and again["withdrawn"] == []
    # void the ruling: the hand-appended override row is not enough, so corrupt the ledger
    (root / rr.RULINGS).write_text((root / rr.RULINGS).read_text() + "torn\n")
    res = vl.apply(TASK, root)
    assert res["withdrawn"] and not _humans(f)[0].ticked


def test_brief_carries_the_ruling_and_the_check_instruction(root, operator):
    _task(root, NOTIFY)
    row = _record(root, ruling="Yes: option a, exempt read-only Bash", ref="832 b826295ef")
    judged, _ = _judged(root)
    assert judged[0]["widened"]["kind"] == "ruling"
    brief = judge_cli._build_brief(TASK, judged)
    assert row["id"] in brief and "Yes: option a, exempt read-only Bash" in brief
    assert "832 b826295ef" in brief
    assert "You do NOT make this ruling" in brief and "Check that the box records it" in brief
    assert "**Measured:**" not in brief


# ── AC 4: 832's case ─────────────────────────────────────────────────────────

def test_832_t676_operator_only_before_reviewer_judged_after(root, operator):
    _task(root, T676)
    c = _crit(root)
    cl = classify(c)
    assert cl.cls == "act-in-the-world" and cl.delegation_class == OPERATOR_ONLY
    assert "git push" in cl.reason
    judged, operator_only = _judged(root)
    assert judged == [] and len(operator_only) == 1
    row = _record(root, ruling="a", ref="832 operator, commit b826295ef")
    judged, operator_only = _judged(root)
    assert [j["ac_index"] for j in judged] == [1] and operator_only == []
    assert judged[0]["widened"]["id"] == row["id"]
    assert classify(c).delegation_class == OPERATOR_ONLY   # the classifier itself is unchanged
