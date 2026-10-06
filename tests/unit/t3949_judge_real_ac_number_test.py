"""T-3949 (832 7616ce48): a self-recording reviewer records the REAL Human AC number.

`fw reviewer judge T-310 --criterion 3` listed the only criterion as "Criterion 1 (Human AC#3)"
and told the worker `--ac <N>`; the worker used 1, so its verdict landed on AC#1. A green would
have ticked the wrong Human criterion. Two legs: the brief maps every criterion to its real AC
number, and `verdict record` refuses an AC the dispatch's brief did not name.
"""
import sys
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_HERE))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib import verdict_ledger as vl  # noqa: E402
from lib.reviewer import judge_cli  # noqa: E402
import _review_runtime as rt  # noqa: E402
from t3580_judge_cli_test import TASTE, TID, _mk_task, _produce, repo  # noqa: E402,F401
from t3580_round2_test import _crit  # noqa: E402

ONLY_AC3 = "### Criterion 1 (Human AC#3)\n\nThe summary paragraph reads clearly\n"


@pytest.fixture()
def prod(repo):
    _mk_task(repo, TASTE * 3)
    _produce(repo)
    return repo


def _rec(root, did, ac):
    rep = root / f".context/reviews/evidence/{TID}/AC{ac}-{did}.md"
    rep.parent.mkdir(parents=True, exist_ok=True)
    rep.write_text("checked\n")
    return vl.record(TID, ac, "amber", reviewer=f"reviewer-{did}:claude", guidance="needs work",
                     rung="rung-1-same-vendor-independent", dispatch_id=did,
                     digest=vl.criterion_digest(_crit(root, ac)),
                     evidence=[str(rep.relative_to(root))], root=root)


def test_brief_maps_each_criterion_to_its_real_ac_number():
    crit = [{"index": 1, "ac_index": 3, "text": "x", "body": "x"}]
    brief = judge_cli._build_brief(TID, crit)
    assert "### Criterion 1 (Human AC#3)" in brief
    assert "- Criterion 1 → `--ac 3`" in brief
    assert "NOT the criterion's position" in brief


def test_record_refuses_an_ac_the_brief_did_not_name(prod):
    rt.dispatch(prod, "rv-1", TID, issuer_session="S-x", issuer_identity="dispatcher",
                worker_kind="claude", brief=ONLY_AC3)
    with pytest.raises(vl.VerdictRefused, match="criterion-not-in-dispatch|briefed on Human AC#3"):
        _rec(prod, "rv-1", 1)


def test_control_record_accepts_the_ac_the_brief_named(prod):
    rt.dispatch(prod, "rv-1", TID, issuer_session="S-x", issuer_identity="dispatcher",
                worker_kind="claude", brief=ONLY_AC3)
    assert _rec(prod, "rv-1", 3)["ac"] == 3
