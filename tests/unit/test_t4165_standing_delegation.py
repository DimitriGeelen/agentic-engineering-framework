"""T-4165 — standing operator delegation as a Human-tick provenance kind (inception T-4158).

The operator records a grant once (pattern, scope, condition, expiry); `human_ac_ticks.py
audit` then accepts an agent tick that cites the grant and a green verdict on the named
condition criterion of the same task — and refuses every leg that does not hold.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "lib"))
sys.path.insert(0, str(ROOT))
import human_ac_ticks as hat  # noqa: E402
import verdict_ledger as vl  # noqa: E402

TASK = "T-9001"
PATH = f".tasks/active/{TASK}-delegation-fixture.md"
REVIEW = "[REVIEW] Independent review: step 3 output meets its role card"
APPROVE = "[REVIEW] Step 3 output approved"


def task_text(approve_box=" ", cite="", arc="arc-x", approve_body="output approved by the operator",
              review_box=" "):
    cite_line = f"  **Delegated tick:** {cite}\n" if cite else ""
    return (f"---\nid: {TASK}\nname: fixture\narc_id: {arc}\n---\n\n"
            f"## Acceptance Criteria\n\n### Agent\n- [x] done\n\n### Human\n"
            f"- [{review_box}] {REVIEW}\n  **Steps:** 1. read the step output\n"
            f"  **Expected:** it meets the role card\n  **If not:** send it back\n"
            f"- [{approve_box}] {APPROVE}\n  **Steps:** 1. look at the output\n"
            f"  **Expected:** {approve_body}\n  **If not:** reject it\n{cite_line}"
            f"\n## Verification\n")


def git(root, *args):
    return subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True,
                          check=True).stdout


def commit(root, text, msg, date=None):
    (root / PATH).write_text(text)
    env = dict(os.environ)
    if date:
        env["GIT_COMMITTER_DATE"] = env["GIT_AUTHOR_DATE"] = date
    subprocess.run(["git", "-C", str(root), "add", "-A"], check=True)
    subprocess.run(["git", "-C", str(root), "commit", "-qm", msg], check=True, env=env)


@pytest.fixture
def repo(tmp_path):
    root = tmp_path
    git(root, "init", "-q")
    git(root, "config", "user.email", "op@example.com")
    git(root, "config", "user.name", "op")
    (root / ".tasks/active").mkdir(parents=True)
    commit(root, task_text(), f"{TASK}: fixture")
    return root


def review_digest(text):
    crit = next(c for c in vl.human_criteria(text) if "Independent review" in c.title)
    return vl.criterion_digest(crit)


def add_verdict(root, vid="V-1", outcome="green", digest=None):
    p = root / ".context/reviews/verdicts.jsonl"
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open("a") as f:
        f.write(json.dumps({"id": vid, "task": TASK, "outcome": outcome,
                            "ac_digest": digest or review_digest(task_text())}) + "\n")


def grant(root, **kw):
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    args = dict(pattern=r"Step \d+ output approved", condition=r"Independent review",
                arc="arc-x", tasks=[], by="op",
                expires=(datetime.now(timezone.utc) + timedelta(days=30)).strftime("%Y-%m-%d"))
    args.update(kw)
    return hat.grant_delegation(root, today=today, **args)


def tick(root, gid, vid="V-1", **kw):
    commit(root, task_text(approve_box="x", cite=f"{gid} verdict {vid}", **kw), f"{TASK}: tick")


def audit(root):
    return hat.audit(root)


# ── accept path ──────────────────────────────────────────────────────────────

def test_delegated_tick_with_green_condition_verdict_passes(repo):
    add_verdict(repo)
    g = grant(repo)
    tick(repo, g["id"])
    rc, lines = audit(repo)
    assert rc == 0, lines


def test_same_tick_without_a_cite_still_fails(repo):
    add_verdict(repo)
    grant(repo)
    commit(repo, task_text(approve_box="x"), f"{TASK}: tick, no cite")
    rc, lines = audit(repo)
    assert rc == 2 and "Step 3 output approved" in "\n".join(lines)


def test_task_list_scope_passes(repo):
    add_verdict(repo)
    g = grant(repo, arc="", tasks=[TASK])
    tick(repo, g["id"], arc="other")
    assert audit(repo)[0] == 0


def test_annotation_is_not_part_of_the_criterion_key():
    plain = hat.boxes(hat._human_section(task_text(approve_box="x")))
    cited = hat.boxes(hat._human_section(task_text(approve_box="x", cite="SD-0000abcd verdict V-1")))
    assert [k for k, _, _ in plain] == [k for k, _, _ in cited]


# ── refusal legs ─────────────────────────────────────────────────────────────

def _refused(repo, reason):
    rc, lines = audit(repo)
    out = "\n".join(lines)
    assert rc == 2, out
    assert "delegation refused" in out and reason in out, out


def test_unknown_grant_refused(repo):
    add_verdict(repo)
    tick(repo, "SD-deadbeef")
    _refused(repo, "no such grant")


def test_revoked_grant_refused(repo):
    add_verdict(repo)
    g = grant(repo)
    with (repo / hat.DELEGATIONS).open("a") as f:
        f.write(json.dumps({"ts": "2000-01-01T00:00:00Z", "kind": "revoke", "id": g["id"]}) + "\n")
    tick(repo, g["id"])
    _refused(repo, "grant revoked")


def test_tick_committed_before_the_grant_refused(repo):
    add_verdict(repo)
    g = grant(repo)
    commit(repo, task_text(approve_box="x", cite=f"{g['id']} verdict V-1"), f"{TASK}: tick",
        date="2026-10-05T00:00:00Z")
    _refused(repo, "tick predates the grant")


def test_expired_grant_refused(repo):
    add_verdict(repo)
    g = grant(repo)
    commit(repo, task_text(approve_box="x", cite=f"{g['id']} verdict V-1"), f"{TASK}: tick",
           date=(datetime.now(timezone.utc) + timedelta(days=60)).strftime("%Y-%m-%dT%H:%M:%SZ"))
    _refused(repo, "grant expired")


def test_out_of_scope_task_refused(repo):
    add_verdict(repo)
    g = grant(repo, arc="arc-y")
    tick(repo, g["id"])
    _refused(repo, "outside the grant's scope")


def test_pattern_miss_refused(repo):
    add_verdict(repo)
    g = grant(repo, pattern=r"Deployment signed off")
    tick(repo, g["id"])
    _refused(repo, "does not match the grant pattern")


def test_non_green_verdict_refused(repo):
    add_verdict(repo, outcome="amber")
    g = grant(repo)
    tick(repo, g["id"])
    _refused(repo, "is not a green verdict")


def test_verdict_on_the_ticked_criterion_itself_refused(repo):
    crit = next(c for c in vl.human_criteria(task_text()) if "approved" in c.title)
    add_verdict(repo, digest=vl.criterion_digest(crit))
    g = grant(repo, condition=r"Step 3")
    tick(repo, g["id"])
    _refused(repo, "not bound to a different criterion")


def test_condition_pattern_miss_refused(repo):
    add_verdict(repo)
    g = grant(repo, condition=r"Security review")
    tick(repo, g["id"])
    _refused(repo, "not bound to a different criterion")


def test_act_in_the_world_criterion_never_delegable(repo):
    add_verdict(repo)
    g = grant(repo)
    tick(repo, g["id"], approve_body="the step output is published to the customer")
    _refused(repo, "act-in-the-world is never delegable")


def test_one_cite_licenses_one_tick(repo):
    add_verdict(repo)
    g = grant(repo)
    tick(repo, g["id"])
    commit(repo, task_text(cite=f"{g['id']} verdict V-1"), f"{TASK}: untick")
    tick(repo, g["id"])
    _refused(repo, "already licensed a tick")


# ── grant validation and who may grant ───────────────────────────────────────

@pytest.mark.parametrize("kw,msg", [
    (dict(pattern=""), "matches every criterion"),
    (dict(pattern=".*"), "matches every criterion"),
    (dict(condition="("), "does not compile"),
    (dict(arc="", tasks=[]), "scope needs"),
    (dict(tasks=["nope"]), "scope needs"),
    (dict(expires="2099-01-01"), "days ahead"),
    (dict(expires="yesterday"), "not YYYY-MM-DD"),
])
def test_grant_validation(repo, kw, msg):
    with pytest.raises(ValueError, match=msg):
        grant(repo, **kw)


def _cli(repo, *args, agent=True):
    env = {k: v for k, v in os.environ.items() if k not in ("CLAUDECODE", "AI_AGENT")}
    if agent:
        env["CLAUDECODE"] = "1"
    env["PROJECT_ROOT"] = str(repo)
    return subprocess.run([sys.executable, str(ROOT / "lib/human_ac_ticks.py"), *args],
                          capture_output=True, text=True, env=env)


def test_grant_refused_under_agent_control(repo):
    exp = (datetime.now(timezone.utc) + timedelta(days=30)).strftime("%Y-%m-%d")
    r = _cli(repo, "delegation", "grant", "--pattern", "Step", "--condition", "review",
             "--arc", "arc-x", "--expires", exp)
    assert r.returncode == 2 and "REFUSED" in r.stderr
    assert not (repo / hat.DELEGATIONS).exists()
    r = _cli(repo, "delegation", "grant", "--pattern", "Step", "--condition", "review",
             "--arc", "arc-x", "--expires", exp, agent=False)
    assert r.returncode == 0, r.stderr
    gid = r.stdout.split()[1]
    assert _cli(repo, "delegation", "revoke", gid).returncode == 2
    assert _cli(repo, "delegation", "revoke", gid, agent=False).returncode == 0
    assert "revoked" in _cli(repo, "delegation", "list").stdout


def test_text_gate_refuses_grant_and_ledger_writes():
    import shell_write_scan as sws
    assert sws.scan("python3 lib/human_ac_ticks.py delegation grant --pattern a --condition b "
                    "--arc x --expires 2027-01-01", ".", ".")
    assert sws.scan("python3 lib/human_ac_ticks.py delegation revoke SD-1", ".", ".")
    assert sws.scan("echo x >> .context/reviews/standing-delegations.jsonl", ".", ".")
    assert not sws.scan("python3 lib/human_ac_ticks.py delegation list", ".", ".")
