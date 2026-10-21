#!/usr/bin/env python3
"""T-4519 — a committed verdict row whose worker was later killed has a sanctioned exit.

Origin: 832 (their T-1245). SIGTERM reached two claude review workers AFTER each had committed its
green row; the runtime signed exit 143 and `audit` FAILed both rows forever (append-only, and
`acknowledge` needs a completed fixing task in the consumer's own tree), blocking every push.

Leg 1: a runtime-attested `worker-failed` row is VOID — graded WARN (exit 3, never PASS), never
counts — provided every other check on it passes; a later valid verdict supersedes it.
Leg 2: a committed row whose dispatch is still running (started, not completed, inside its signed
`complete_by` window) is PROVISIONAL — WARN, never counts — until the runtime signs its exit.
"""
import sys
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_HERE))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib import verdict_ledger as vl  # noqa: E402
import _review_runtime as rt  # noqa: E402
from _review_runtime import hermetic_review_env  # noqa: E402,F401  (T-4205: autouse)
from t3580_judge_cli_test import TASTE, TID, _mk_task, _produce, repo  # noqa: E402,F401
from t3580_round2_test import _commit_as  # noqa: E402
from t3580_round3_test import _closed, _dispatch, _record, _why  # noqa: E402


@pytest.fixture()
def prod(repo):
    _mk_task(repo, TASTE)
    (repo / "notes.md").write_text("notes v1\n")
    _produce(repo)
    return repo


def _killed_green(root, did="rv-1", exit_code=143, committer=None):
    """832's shape: the worker records and commits its green, THEN is killed; run.sh signs."""
    _dispatch(root, did)
    rec = _record(root, did)
    _commit_as(root, committer or f"reviewer-{did}")
    rt.finish(root, did, exit_code=exit_code)
    return rec["id"]


def test_killed_worker_green_is_void_warn_not_fail(prod):
    rid = _killed_green(prod)
    before = (prod / vl.VERDICTS).read_text()
    code, out = vl.audit(prod)
    assert code == vl.AUDIT_WARN != 0, out
    assert any(ln.startswith(f"WARN void: {rid}") and "worker failed" in ln and "143" in ln
               for ln in out), out
    assert not any(ln.startswith("FAIL") for ln in out), out
    assert "worker-failed" in _closed(prod)                       # it still never counts
    assert (prod / vl.VERDICTS).read_text() == before            # nothing rewritten
    assert vl.load_ledger(prod).faults == []                      # append-only history holds


def test_control_exit_zero_counts_and_audits_clean(prod):
    _killed_green(prod, exit_code=0)
    assert [t["ac"] for t in vl.apply(TID, prod)["ticked"]] == [1]
    assert vl.audit(prod)[0] == 0


def test_worker_failed_row_with_another_fault_still_fails(prod):
    """VOID is only for a row that is otherwise fully attested: committed by someone other than its
    worker, the other fault wins and audit FAILs."""
    rid = _killed_green(prod, committer="Builder Bot")
    code, out = vl.audit(prod)
    assert code == 2 and any(ln.startswith(f"FAIL {rid}") for ln in out), out
    assert not any(ln.startswith("WARN void") for ln in out)


def test_later_valid_verdict_supersedes_the_void_row(prod):
    rid = _killed_green(prod, "rv-1")
    _dispatch(prod, "rv-2")
    _record(prod, "rv-2")
    _commit_as(prod, "reviewer-rv-2")
    rt.finish(prod, "rv-2", exit_code=0)
    assert [t["ac"] for t in vl.apply(TID, prod)["ticked"]] == [1]
    code, out = vl.audit(prod)
    assert code == vl.AUDIT_WARN and any(ln.startswith(f"WARN void: {rid}") for ln in out), out


def test_in_flight_committed_row_is_provisional_until_the_runtime_signs(prod, monkeypatch):
    _dispatch(prod, "rv-1")
    rt.take_secret(prod, "rv-1")                                  # run.sh's signed start
    rid = _record(prod, "rv-1")["id"]
    _commit_as(prod, "reviewer-rv-1")                             # worker committed, still running
    code, out = vl.audit(prod)
    assert code == vl.AUDIT_WARN and any(ln.startswith(f"WARN provisional: {rid}") for ln in out), out
    assert "no-completion" in _why(prod)                          # never counts while provisional
    drec, _ = vl.dispatch_record(prod, "rv-1")
    assert drec is not None
    monkeypatch.setattr(vl, "_clock", lambda: int(drec["complete_by"]) + 1)
    code, out = vl.audit(prod)                                    # window closed, never signed
    assert code == 2 and any(ln.startswith(f"FAIL {rid}") and "no completion" in ln for ln in out), out


def test_never_started_dispatch_row_is_not_provisional(prod):
    """No signed start = run.sh never ran: a committed row in its name is not in flight."""
    _dispatch(prod, "rv-1")
    rid = _record(prod, "rv-1")["id"]
    _commit_as(prod, "reviewer-rv-1")
    code, out = vl.audit(prod)
    assert code == 2 and any(ln.startswith(f"FAIL {rid}") for ln in out), out


def test_audit_sh_names_the_new_warn_classes():
    src = (_HERE / "agents" / "audit" / "audit.sh").read_text()
    assert "WARN \\(acknowledged\\|void\\|provisional\\)" in src
