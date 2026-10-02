"""T-3657 — acknowledged refusals: a committed ledger row that does not verify because of a FIXED
framework defect can be acknowledged. Audit grades it WARN (never PASS); the row never counts."""
import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_t3579_verdict_ledger import (  # noqa: E402,F401
    TASK, TASTE, _commit_ledger, _git, _lines, _rec, _task, _ticked, _worker_attributed_reviewer, root,
)
from lib import verdict_ledger as vl  # noqa: E402

FIX = "T-9200"


def _fixing_task(root, tid=FIX, sub="completed"):
    d = root / ".tasks" / sub
    d.mkdir(parents=True, exist_ok=True)
    (d / f"{tid}-fix.md").write_text(f"---\nid: {tid}\nstatus: work-completed\n---\n")


def _refused_green(root):
    """A green row committed by someone other than its worker: refused (introduced-by-*)."""
    _task(root, TASTE)
    rec = _rec(root, commit=False)
    _commit_ledger(root, author="Builder Bot")
    return rec["id"]


def _commit_acks(root):
    """Commit the ack file with an explicit identity: the nightly runner (cron) has no GIT_* env
    and no user.name, so a bare `git commit` exits 128 there (T-3718)."""
    _git(root, "add", str(vl.ACKS))
    _git(root, "commit", "-q", "-m", f"{FIX}: acknowledge refusal",
         env={"GIT_AUTHOR_NAME": "Operator", "GIT_AUTHOR_EMAIL": "op@x.y",
              "GIT_COMMITTER_NAME": "Operator", "GIT_COMMITTER_EMAIL": "op@x.y"})


def test_unacknowledged_refused_row_fails_audit(root):
    rid = _refused_green(root)
    code, out = vl.audit(root)
    assert code == 2 and any(ln.startswith(f"FAIL {rid}") and "introduced by" in ln for ln in out)


def test_acknowledged_refused_row_is_warn_never_pass_and_never_counts(root):
    rid = _refused_green(root)
    _fixing_task(root)
    before = (root / vl.VERDICTS).read_text()
    rec = vl.acknowledge(rid, fixed_by=FIX, reason="producer-email defect", root=root)
    assert rec["class"].startswith("introduced-by") and rec["fixed_by"] == FIX
    assert (root / vl.VERDICTS).read_text() == before            # the ledger is untouched
    assert vl.audit(root)[0] == 2                                 # uncommitted ack: not honoured
    _commit_acks(root)
    code, out = vl.audit(root)
    assert code == vl.AUDIT_WARN != 0
    assert any(ln.startswith(f"WARN acknowledged: {rid}") and f"superseded by {FIX}" in ln for ln in out)
    assert not any(ln.startswith("FAIL") for ln in out)
    assert vl.load_ledger(root).faults == []                      # append-only history still holds
    assert vl.apply(TASK, root)["ticked"] == [] and not _ticked(root)   # the row never counts


def test_one_acknowledged_plus_one_unacknowledged_still_fails(root):
    rid = _refused_green(root)
    _fixing_task(root)
    vl.acknowledge(rid, fixed_by=FIX, reason="r", root=root)
    _commit_acks(root)
    _rec(root, commit=False)
    _commit_ledger(root, author="Builder Bot")                   # a second, unacknowledged refusal
    code, out = vl.audit(root)
    assert code == 2
    assert sum(ln.startswith("WARN acknowledged") for ln in out) == 1
    assert sum(ln.startswith("FAIL V-") for ln in out) == 1


def test_refuses_nonexistent_row(root):
    _refused_green(root)
    _fixing_task(root)
    with pytest.raises(vl.VerdictRefused, match="no row"):
        vl.acknowledge("V-nope", fixed_by=FIX, reason="r", root=root)


def test_refuses_a_row_that_verifies(root):
    _task(root, TASTE)
    rid = _rec(root)["id"]
    _fixing_task(root)
    with pytest.raises(vl.VerdictRefused, match="verifies"):
        vl.acknowledge(rid, fixed_by=FIX, reason="r", root=root)
    assert not (root / vl.ACKS).exists()


@pytest.mark.parametrize("fixed_by", ["T-9999", "T-9201", "", "not-a-task"])
def test_refuses_missing_nonexistent_or_unfinished_fixing_task(root, fixed_by):
    rid = _refused_green(root)
    _fixing_task(root, "T-9201", sub="active")                   # exists but is not completed
    with pytest.raises(vl.VerdictRefused):
        vl.acknowledge(rid, fixed_by=fixed_by, reason="r", root=root)
    assert not (root / vl.ACKS).exists()


def test_refuses_missing_reason_and_duplicates(root):
    rid = _refused_green(root)
    _fixing_task(root)
    with pytest.raises(vl.VerdictRefused, match="reason"):
        vl.acknowledge(rid, fixed_by=FIX, reason=" ", root=root)
    vl.acknowledge(rid, fixed_by=FIX, reason="r", root=root)
    with pytest.raises(vl.VerdictRefused, match="already"):
        vl.acknowledge(rid, fixed_by=FIX, reason="r", root=root)


def test_cli_requires_fixed_by_and_refuses_bad_input(root, capsys):
    rid = _refused_green(root)
    with pytest.raises(SystemExit):
        vl._cli(["acknowledge", rid, "--reason", "r"])           # --fixed-by missing
    assert vl._cli(["acknowledge", "V-nope", "--fixed-by", FIX, "--reason", "r"]) == 1
    assert vl._cli(["acknowledge", rid, "--fixed-by", "T-9999", "--reason", "r"]) == 1
    _fixing_task(root)
    assert vl._cli(["acknowledge", rid, "--fixed-by", FIX, "--reason", "r"]) == 0
    assert json.loads(capsys.readouterr().out.splitlines()[-1])["row_id"] == rid


def test_tampered_ack_file_fails_and_honours_nothing(root):
    rid = _refused_green(root)
    _fixing_task(root)
    vl.acknowledge(rid, fixed_by=FIX, reason="r", root=root)
    _commit_acks(root)
    p = root / vl.ACKS
    row = json.loads(p.read_text())
    row["reason"] = "rewritten"
    p.write_text(json.dumps(row) + "\n")
    code, out = vl.audit(root)
    assert code == 2 and any(ln.startswith("FAIL acknowledgement integrity") for ln in out)
    assert any(ln.startswith(f"FAIL {rid}") for ln in out)


def test_hand_written_ack_for_a_different_class_or_unfinished_fix_is_not_honoured(root):
    rid = _refused_green(root)
    row = _lines(root, vl.VERDICTS)[-1]
    p = root / vl.ACKS
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps({"kind": vl.ACK_KIND, "row_id": rid, "class": "reviewer-is-producer",
                             "row_sha256": vl._row_sha(row), "fixed_by": FIX}) + "\n")
    _commit_acks(root)
    code, out = vl.audit(root)
    assert code == 2 and any("acknowledgement not honoured" in ln for ln in out)
