"""T-3581 round 4 — remaining OpenAI/Z.ai findings. Every refusal has a control."""
import json
import re
import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_t3579_verdict_ledger import (  # noqa: E402,F401
    TASK, TASTE, _commit_ledger, _worker_attributed_reviewer, _dg, _dispatch, _edit, _lines, _produce, _rec, _task,
    _text, _ticked, root,
)
from test_t3581_ledger_integrity import _rewrite  # noqa: E402
from lib import verdict_ledger as vl  # noqa: E402
from lib.delegation import human_criteria  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]


def _apply_cli(root):
    return subprocess.run([sys.executable, str(ROOT / "lib/verdict_ledger.py"), "apply", TASK],
                          cwd=root, capture_output=True, text=True,
                          env={"PATH": "/usr/bin:/bin", "PROJECT_ROOT": str(root)})


def _ticked_task(root):
    _task(root, TASTE)
    _rec(root)
    assert [t["ac"] for t in vl.apply(TASK, root)["ticked"]] == [1]


# ── 1: non-green rows get the full validation ────────────────────────────────

def test_control_committed_red_with_guidance_audits_clean(root):
    _task(root, TASTE)
    _rec(root, "red")
    assert vl.audit(root)[0] == 0


def test_uncommitted_red_fails_audit(root):
    _task(root, TASTE)
    _rec(root, "red", commit=False)
    code, out = vl.audit(root)
    assert code == 2 and any("uncommitted" in ln for ln in out)


def test_red_without_guidance_fails_audit(root):
    _task(root, TASTE)
    _rec(root, "red", commit=False)
    _rewrite(root, lambda rows: [dict(r, guidance="") for r in rows])
    _commit_ledger(root)
    code, out = vl.audit(root)
    assert code == 2 and any("guidance" in ln or "tampered" in ln for ln in out)


# ── 2: durable provenance for reviewer-derived ticks ─────────────────────────

def test_control_annotation_intact_revalidates_quietly(root):
    _ticked_task(root)
    res = vl.apply(TASK, root)
    assert res["refused"] == [] and _ticked(root) and vl.audit(root)[0] == 0


@pytest.mark.parametrize("edit", [
    lambda t: re.sub(r"(?m)^\s*\*\*Reviewer verdict:\*\*.*\n", "", t),
    lambda t: t.replace("**Reviewer verdict:** green", "**Reviewer verdict:** GREEN!"),
    lambda t: re.sub(r"green (V-[\w-]+)", "green V-19990101-deadbeef", t),
])
def test_stripped_or_altered_annotation_refuses_close_and_fails_audit(root, edit):
    _ticked_task(root)
    f = next((root / ".tasks" / "active").glob(f"{TASK}-*.md"))
    f.write_text(edit(f.read_text()))
    _rec(root, "red", dispatch_id=_dispatch(root, "rv-7"))     # a later RED
    res = vl.apply(TASK, root)
    assert res["refused"] and _ticked(root)                     # nothing quietly kept or changed
    assert _apply_cli(root).returncode == 1
    code, out = vl.audit(root)
    assert code == 2 and any("annotation mismatch" in ln for ln in out)


def test_release_is_an_operator_action_and_makes_the_tick_manual(root, monkeypatch):
    _ticked_task(root)
    cli = [sys.executable, str(ROOT / "lib/verdict_ledger.py"), "release", TASK, "--ac", "1",
           "--reason", "operator reviewed"]
    env = {"PATH": "/usr/bin:/bin", "PROJECT_ROOT": str(root), "CLAUDECODE": "1"}
    assert subprocess.run(cli, cwd=root, env=env, capture_output=True).returncode == 1
    assert subprocess.run(cli + ["--i-am-human"], cwd=root, env=env,
                          capture_output=True).returncode == 0
    _rec(root, "red", dispatch_id=_dispatch(root, "rv-8"))
    res = vl.apply(TASK, root)
    assert res["refused"] == [] and res["withdrawn"] == [] and _ticked(root)   # now manual
    assert vl.audit(root)[0] == 0


def test_control_hand_ticked_criterion_is_untouched(root):
    _task(root, TASTE)
    _edit(root, "- [ ] [REVIEW]", "- [x] [REVIEW]")
    assert vl.apply(TASK, root)["refused"] == [] and _ticked(root)


# ── 3: short dispatch ids get the worker-identity check ──────────────────────

def test_short_dispatch_id_worker_identity_is_checked(root):
    _task(root, TASTE)
    _produce(root, author="dispatch+rv-1", trailer="")
    assert vl._dispatch_is_producer("rv-1", vl.producers(root, TASK))


def test_control_unrelated_short_dispatch_id_is_not_a_producer(root):
    _task(root, TASTE)
    _produce(root, author="Builder Bot")
    assert vl._dispatch_is_producer("rv-1", vl.producers(root, TASK)) == ""


# ── 4: deleting an uncommitted RED does not reopen an earlier GREEN ──────────

def test_deleting_uncommitted_red_does_not_resurrect_the_green(root):
    _ticked_task(root)
    _rec(root, "red", commit=False, dispatch_id=_dispatch(root, "rv-9"))
    p = root / vl.VERDICTS
    p.write_text("".join(p.read_text().splitlines(True)[:-1]))     # drop the uncommitted RED
    res = vl.apply(TASK, root)
    assert res["withdrawn"] and not _ticked(root)
    code, out = vl.audit(root)
    assert code == 2 and any("deleted verdict" in ln for ln in out)


def test_control_committed_red_withdraws_without_a_deleted_fault(root):
    _ticked_task(root)
    _rec(root, "red", dispatch_id=_dispatch(root, "rv-9"))
    assert vl.load_ledger(root).missing == []


# ── 5: registration ──────────────────────────────────────────────────────────

def test_second_registration_of_the_same_id_is_refused(root):
    _dispatch(root, "rv-1")
    with pytest.raises(ValueError, match="already registered"):
        vl.register_dispatch("rv-1", TASK, "review", root=root)


def test_control_distinct_ids_register(root):
    _dispatch(root, "rv-1")
    _dispatch(root, "rv-2")


def test_review_dispatch_names_carry_a_random_suffix():
    src = (ROOT / "agents/termlink/termlink.sh").read_text()
    assert 'task_type" = "review" ] && name="${name}-$(od' in src


# ── 6: evidence is content-hashed ────────────────────────────────────────────

def test_control_unchanged_evidence_verifies(root):
    _ticked_task(root)
    assert _lines(root, vl.VERDICTS)[0]["evidence_sha256"]["evidence.md"]
    assert vl.audit(root)[0] == 0


def test_evidence_changed_after_recording_withdraws_and_fails_audit(root):
    _ticked_task(root)
    (root / "evidence.md").write_text("swapped content\n")
    res = vl.apply(TASK, root)
    assert res["withdrawn"] and "evidence" in res["withdrawn"][0]["why"]
    code, out = vl.audit(root)
    assert code == 2 and any("evidence hash" in ln for ln in out)


def test_green_row_without_hashes_is_refused(root):
    _task(root, TASTE)
    _rec(root, commit=False)
    _rewrite(root, lambda rows: [{k: v for k, v in r.items() if k != "evidence_sha256"} for r in rows])
    _commit_ledger(root)
    assert vl.apply(TASK, root)["ticked"] == []
    assert vl.audit(root)[0] == 2
