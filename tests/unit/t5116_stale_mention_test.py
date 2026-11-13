#!/usr/bin/env python3
"""T-5116 — a commit that only MENTIONS a task must not make its green verdict stale.

055 field report (their T-645, msgs 73f57250 / a56f7da3, 2026-11-13): a green verdict was
judged stale because a later commit for THEIR T-704 named T-645 in its message body.
`_stale_fault` grepped the whole message for the id; the component count in the same module
already counts only commits whose subject opens with the id (`task_commits.owns`).

Fixture repos only (the T-3580 round-3 harness); no real task is judged.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib import verdict_ledger as vl  # noqa: E402
from _review_runtime import hermetic_review_env  # noqa: E402,F401  (autouse)
from t3580_judge_cli_test import TID, repo  # noqa: E402,F401
from t3580_round3_test import _why, prod  # noqa: E402,F401
from t4779_stale_review_release_test import _reviewed, _task_commit  # noqa: E402

OTHER = "T-99999"


class TestMentionIsNotWork:
    def test_other_task_commit_mentioning_this_task_does_not_withdraw(self, prod):
        _reviewed(prod)
        _task_commit(prod, {"src/other.py": "y = 2\n"},
                     f"{OTHER}: unrelated change\n\nFollow-up to {TID}; see its review.")
        assert _why(prod) == ""
        assert [t["ac"] for t in vl.apply(TID, prod)["ticked"]] == [1]

    def test_mention_in_the_subject_but_not_as_owner_does_not_withdraw(self, prod):
        _reviewed(prod)
        _task_commit(prod, {"src/other.py": "y = 2\n"}, f"{OTHER}: same fix as {TID}")
        assert _why(prod) == ""


class TestOwnWorkStillWithdraws:
    def test_negative_control_own_subject_still_withdraws(self, prod):
        _reviewed(prod)
        _task_commit(prod, {"src/new.py": "x = 1\n"}, f"{TID}: add code")
        assert "stale-review" in _why(prod)

    def test_negative_control_id_list_subject_still_withdraws(self, prod):
        _reviewed(prod)
        _task_commit(prod, {"src/new.py": "x = 1\n"}, f"{OTHER}, {TID}: shared fix")
        assert "stale-review" in _why(prod)
