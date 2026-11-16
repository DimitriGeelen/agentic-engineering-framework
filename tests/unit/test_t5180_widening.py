"""T-5180 — operator-granted widening (T-5171 GO): a MEASURED act-in-the-world criterion in a
widening's scope closes on a reviewer green, and every tick cites the widening and the ruling.
One test (or parametrised group) per Agent criterion of T-5180. tmp_path fixtures only."""
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "lib"))
sys.path.insert(0, str(Path(__file__).resolve().parent))

import human_ac_ticks as hat  # noqa: E402
from lib import delegation_widening as dw  # noqa: E402
from lib import verdict_ledger as vl  # noqa: E402
from lib.delegation import classify, human_criteria  # noqa: E402
from lib.reviewer import judge_cli  # noqa: E402

# Reuse the T-3579 fixtures: a real producer commit, a signed review dispatch, a committed row.
from test_t3579_verdict_ledger import (  # noqa: E402,F401  (fixtures + autouse)
    TASK, WORLD, TIER0, _rec, _task, _lines, _humans, _text, _worker_attributed_reviewer,
    hermetic_review_env, root,
)

MEASURED = ("  **Measured:** `curl -s https://mirror.example/releases/latest`\n"
            "  ```\n  v1.9.0\n  ```\n")
WORLD_M = WORLD + MEASURED
# act-in-the-world, but not irreversible / consumer-facing: IW-7 rung 1, so one seat closes it
NOTIFY = ("- [ ] [REVIEW] Send a notification to the ops channel and confirm it arrives\n"
          "  **Steps:**\n  1. Send it\n  **Expected:** it arrives\n  **If not:** check the hub\n")
NOTIFY_M = NOTIFY + MEASURED
SOVEREIGN = ("- [ ] [REVIEW] Publish the scores with fw bvp confirm on the release\n"
             "  **Steps:**\n  1. Run it\n  **Expected:** confirmed\n  **If not:** ask\n" + MEASURED)
MARKED = ("- [ ] [REVIEW] [OPERATOR] Publish the release to the public mirror\n"
          "  **Steps:**\n  1. Publish\n  **Expected:** consumers upgrade\n  **If not:** roll back\n"
          + MEASURED)
TIER0_M = TIER0.replace("force push", "force push and publish the release") + MEASURED
PAT = r"Publish|force push|notification"
FAR = "2099-01-01"


def _widen(root, tasks=(TASK,), pattern=PAT, arc="", today="2026-11-16", expires="2027-01-01"):
    return hat.widen_delegation(root, "act-in-the-world", "R-3800", "Yes, you may close the task "
                                "yourself.", pattern, arc, list(tasks), expires, "operator",
                                today=today)


def _crit(root, ac=1):
    return next(c for c in human_criteria(_text(root)) if c.index == ac)


def _main(root, monkeypatch, *argv, agent=False):
    monkeypatch.setenv("PROJECT_ROOT", str(root))
    if agent:
        monkeypatch.setenv("CLAUDECODE", "1")
    else:
        monkeypatch.delenv("CLAUDECODE", raising=False)
        monkeypatch.delenv("AI_AGENT", raising=False)
    return hat.main(list(argv))


# ── AC 1: the widen verb ─────────────────────────────────────────────────────

def test_widen_writes_a_widening_row(root):
    row = _widen(root)
    rows = _lines(root, Path(hat.DELEGATIONS))
    assert rows == [row]
    assert row["kind"] == "widening" and row["id"].startswith("SD-") and len(row["id"]) == 11
    assert row["class"] == "act-in-the-world" and row["ruling"] == "R-3800"
    assert row["text"] == "Yes, you may close the task yourself."
    assert row["pattern"] == PAT and row["tasks"] == [TASK] and row["expires"] == "2027-01-01"


def test_widen_refused_under_agent_control_without_i_am_human(root, monkeypatch):
    args = ("delegation", "widen", "--class", "act-in-the-world", "--ruling", "R-1", "--text",
            "verbatim", "--pattern", "Publish", "--tasks", TASK, "--expires", "2027-01-01")
    assert _main(root, monkeypatch, *args, agent=True) == 2
    assert not (root / hat.DELEGATIONS).exists()
    today = hat.datetime.now(hat.timezone.utc).strftime("%Y-%m-%d")
    good = list(args)
    good[good.index("--expires") + 1] = today
    assert _main(root, monkeypatch, *good, "--i-am-human", agent=True) == 0
    assert _lines(root, Path(hat.DELEGATIONS))[0]["by"] == "agent-override"


@pytest.mark.parametrize("cls", ["tier0-or-bypass", "sovereignty-field", "operator-marked",
                                 "taste", ""])
def test_widen_refuses_any_class_but_act_in_the_world(root, cls):
    with pytest.raises(ValueError, match="cannot be widened"):
        hat.widen_delegation(root, cls, "R", "t", "Publish", "", [TASK], "2027-01-01", "op",
                             today="2026-11-16")
    assert not (root / hat.DELEGATIONS).exists()


@pytest.mark.parametrize("pattern", ["", ".*", "^", "x?", "(?:)"])
def test_widen_refuses_a_match_everything_pattern(root, pattern):
    with pytest.raises(ValueError, match="matches every criterion"):
        _widen(root, pattern=pattern)


def test_widen_scope_and_expiry_rules_match_grant(root):
    with pytest.raises(ValueError, match="scope"):
        _widen(root, tasks=())
    with pytest.raises(ValueError, match="days ahead"):
        _widen(root, expires="2030-01-01")
    with pytest.raises(ValueError, match="ruling"):
        hat.widen_delegation(root, "act-in-the-world", " ", "t", "Publish", "", [TASK],
                             "2027-01-01", "op", today="2026-11-16")


def test_list_shows_and_revoke_stops_it(root, monkeypatch, capsys):
    _task(root, WORLD_M)
    row = _widen(root, expires=FAR, today="2098-06-01")
    assert dw.active_widening(root, TASK, _text(root), _crit(root))[0]["id"] == row["id"]
    assert _main(root, monkeypatch, "delegation", "list") == 0
    out = capsys.readouterr().out
    assert row["id"] in out and "widening active" in out and "ruling=R-3800" in out
    assert _main(root, monkeypatch, "delegation", "revoke", row["id"], "--reason", "done") == 0
    w, why = dw.active_widening(root, TASK, _text(root), _crit(root))
    assert w is None and "revoked" in why
    _main(root, monkeypatch, "delegation", "list")
    assert "widening revoked" in capsys.readouterr().out


def test_a_widening_is_not_a_standing_grant(root):
    row = _widen(root)
    assert row["id"] not in hat.delegation_grants(root)


# ── AC 2: no widening recorded → unchanged ───────────────────────────────────

def test_no_widening_is_inert_everywhere(root):
    f = _task(root, WORLD_M)
    c = _crit(root)
    assert dw.active_widening(root, TASK, _text(root), c) == (None, "")
    cl = classify(c)
    expected = (f"AC#1 is {cl.cls} ({cl.delegation_class}): only the operator may answer it, so "
                f"no reviewer verdict can satisfy or escalate it — {cl.reason}")
    with pytest.raises(vl.VerdictRefused) as e:
        _rec(root)
    assert str(e.value) == expected
    data = {"path": f, "text": f.read_text(), "frontmatter": {"id": TASK}}
    judged, operator = judge_cli._partition(data, root, TASK)
    assert judged == [] and operator[0]["reason"] == cl.reason and "widened" not in operator[0]
    assert not any("widened" in ln for ln in vl.audit(root)[1])


# ── AC 3: in scope + Measured → green records and applies; otherwise refused ──

def test_widened_measured_criterion_records_and_applies(root):
    f = _task(root, NOTIFY_M)
    w = _widen(root, expires=FAR, today="2098-06-01")
    rec = _rec(root)
    assert rec["widened_by"] == w["id"] and rec["ruling"] == "R-3800"
    res = vl.apply(TASK, root)
    assert [t["verdict_id"] for t in res["ticked"]] == [rec["id"]]
    assert res["ticked"][0]["widened_by"] == w["id"]
    assert _humans(f)[0].ticked
    assert f"widened by {w['id']} (ruling R-3800)" in f.read_text()
    assert vl.apply(TASK, root)["ticked"] == []   # idempotent, no recite churn
    assert vl.apply(TASK, root)["recited"] == []


@pytest.mark.parametrize("case,why", [
    ("no-measured", "no Measured block"),
    ("empty-output", "no Measured block"),
    ("unclosed", "no Measured block"),
    ("out-of-scope", "outside"),
    ("expired", "expired"),
    ("revoked", "revoked"),
    ("pattern", "does not match"),
])
def test_widening_refuses_with_the_missing_part(root, case, why):
    body = {"no-measured": WORLD,
            "empty-output": WORLD + "  **Measured:** `curl x`\n  ```\n\n  ```\n",
            "unclosed": WORLD + "  **Measured:** `curl x`\n  ```\n  v1\n"}.get(case, WORLD_M)
    _task(root, body)
    if case == "out-of-scope":
        _widen(root, tasks=("T-1",), expires=FAR, today="2098-06-01")
    elif case == "expired":
        hat._append(root, hat.DELEGATIONS, {"ts": "2026-01-01T00:00:00Z", "kind": "widening",
                                            "id": "SD-0000dead", "class": "act-in-the-world",
                                            "ruling": "R-1", "text": "t", "pattern": PAT,
                                            "arc": None, "tasks": [TASK], "expires": "2026-02-01",
                                            "by": "op"})
    elif case == "pattern":
        _widen(root, pattern="Rotate the keys", expires=FAR, today="2098-06-01")
    else:
        w = _widen(root, expires=FAR, today="2098-06-01")
        if case == "revoked":
            hat._append(root, hat.DELEGATIONS, {"ts": "2026-11-16T00:00:00Z", "kind": "revoke",
                                                "id": w["id"], "by": "op", "reason": ""})
    with pytest.raises(vl.VerdictRefused, match="only the operator") as e:
        _rec(root)
    assert why in str(e.value) and "[widening:" in str(e.value)
    assert _lines(root, vl.REFUSALS)[-1]["class"] == "not-reviewer-judged"


def test_arc_scope_covers_a_task_on_that_arc(root):
    f = _task(root, WORLD_M)
    f.write_text(f.read_text().replace("horizon: now", "horizon: now\narc_id: arc-077"))
    _widen(root, tasks=(), arc="arc-077", expires=FAR, today="2098-06-01")
    assert dw.active_widening(root, TASK, _text(root), _crit(root))[0] is not None


def test_revoking_after_apply_withdraws_the_tick(root):
    f = _task(root, NOTIFY_M)
    w = _widen(root, expires=FAR, today="2098-06-01")
    _rec(root)
    vl.apply(TASK, root)
    assert _humans(f)[0].ticked
    hat._append(root, hat.DELEGATIONS, {"ts": "2026-11-16T00:00:00Z", "kind": "revoke",
                                        "id": w["id"], "by": "op", "reason": ""})
    res = vl.apply(TASK, root)
    assert res["withdrawn"] and not _humans(f)[0].ticked


# ── AC 4: tier0 / sovereignty / operator-marked are never widened ─────────────

@pytest.mark.parametrize("crit,cls", [(TIER0_M, "tier0-or-bypass"),
                                      (SOVEREIGN, "sovereignty-field"),
                                      (MARKED, "operator-marked")])
def test_risk_classes_ahead_of_act_in_the_world_are_never_widened(root, crit, cls):
    _task(root, crit)
    _widen(root, pattern=PAT, expires=FAR, today="2098-06-01")
    c = _crit(root)
    assert classify(c).cls == cls
    w, why = dw.active_widening(root, TASK, _text(root), c)
    assert w is None and "never widened" in why
    with pytest.raises(vl.VerdictRefused, match="only the operator"):
        _rec(root)
    f = next((root / ".tasks" / "active").glob(f"{TASK}-*.md"))
    data = {"path": f, "text": f.read_text(), "frontmatter": {"id": TASK}}
    judged, operator = judge_cli._partition(data, root, TASK)
    assert judged == [] and len(operator) == 1


# ── AC 5: cite, provenance, audit WARN ───────────────────────────────────────

def test_tick_is_provenanced_and_audit_warns_once_per_widened_tick(root):
    f = _task(root, NOTIFY_M)
    w = _widen(root, expires=FAR, today="2098-06-01")
    old = f.read_text()
    rec = _rec(root)
    vl.apply(TASK, root)
    new = f.read_text()
    backing = hat.VerdictBacking(root, TASK)
    ticks = hat.unprovenanced_ticks(old, new, backing)
    assert len(ticks) == 1 and ticks[0][2] == rec["id"]
    assert backing.consume(rec["id"])
    vl.apply(TASK, root)
    warns = [ln for ln in vl.audit(root)[1] if ln.startswith("WARN widened:")]
    assert len(warns) == 1
    assert TASK in warns[0] and "AC#1" in warns[0] and w["id"] in warns[0] and "R-3800" in warns[0]
    assert "Send a notification" in warns[0]


def test_fw_audit_emits_one_warn_per_widened_line():
    script = (f'warn(){{ echo "W:$1"; }}; FRAMEWORK_ROOT="{ROOT}"; '
              f'_VL_AUDIT_OUT=$(printf "WARN widened: T-1 AC#1 V-a: x\\nWARN step-down: y\\n'
              f'WARN widened: T-2 AC#3 V-b: z\\n"); '
              f'eval "$(sed -n "/^_audit_review_widened()/,/^}}/p" "{ROOT}/agents/audit/audit.sh")"; '
              f'_audit_review_widened')
    out = subprocess.run(["bash", "-c", script], capture_output=True, text=True).stdout
    lines = [ln for ln in out.splitlines() if ln.startswith("W:")]
    assert len(lines) == 2 and "T-1 AC#1" in lines[0] and "T-2 AC#3" in lines[1]


# ── AC 6: judge dispatches widened criteria, with the Measured block in the brief ──

def test_judge_dispatches_widened_and_briefs_the_measured_block(root):
    f = _task(root, WORLD_M + WORLD.replace("Publish the release", "Deploy the hub"))
    w = _widen(root, pattern="Publish", expires=FAR, today="2098-06-01")
    data = {"path": f, "text": f.read_text(), "frontmatter": {"id": TASK}}
    judged, operator = judge_cli._partition(data, root, TASK)
    assert [c["ac_index"] for c in judged] == [1]
    assert judged[0]["widened"] == {"id": w["id"], "ruling": "R-3800"}
    assert [c["ac_index"] for c in operator] == [2]   # unwidened act-in-the-world stays out
    brief = judge_cli._build_brief(TASK, judged)
    assert "**Measured:**" in brief and "v1.9.0" in brief
    assert "proves the act happened" in brief and w["id"] in brief


def test_measured_block_parser():
    ok = ["- [ ] x", "  **Measured:** `ls /srv`", "", "  ~~~", "  a", "  ~~~"]
    assert dw.measured_block(ok) == ("ls /srv", "  a")
    assert dw.measured_block(["**Measured:**", "```", "a", "```"]) is None   # no command
    assert dw.measured_block(["**Measured:** ls", "text", "```", "a", "```"]) is None
