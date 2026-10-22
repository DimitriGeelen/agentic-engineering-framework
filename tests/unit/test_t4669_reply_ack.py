"""T-4669: `fw issues reply-ack` settles one submitter reply that needs no action — a ledger row, nothing
posted to GitHub. gh is stubbed (T-4660's stub); the real GitHub API is never called."""
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "lib"))
sys.path.insert(0, str(ROOT / "tests" / "unit"))
import issues  # noqa: E402
from test_t4660_issue_replies import Gh, seed, reply_row, rows, FIXED  # noqa: E402,F401

REASON = "May 2026 thank-you/outreach comments, no fix verdict, no action needed"


@pytest.fixture
def env(tmp_path, monkeypatch):
    monkeypatch.setenv("FW_ISSUES_DIR", str(tmp_path))
    gh = Gh()
    monkeypatch.setattr(issues, "_gh", gh)
    monkeypatch.setattr(issues, "_maintainer_login", lambda: "maint")
    return gh, tmp_path / "intake.jsonl"


def _two_replies(ledger):
    seed(ledger, reply_row(14, "A", excerpt="Thank you for this thorough analysis."),
         reply_row(14, "B", excerpt="One more thought: I'd love to work together."))


def test_ack_writes_one_row_and_calls_no_gh(env, capsys):
    gh, ledger = env
    _two_replies(ledger)
    assert issues.main(["reply-ack", "14", "--reply-id", "A", "--reason", REASON]) == 0
    assert "nothing posted" in capsys.readouterr().out
    last = rows(ledger)[-1]
    assert {k: last[k] for k in ("issue", "stage", "reply_id", "reason")} == {
        "issue": 14, "stage": "reply-acked", "reply_id": "A", "reason": REASON}
    assert last["by"] in ("agent", "operator") and last["ts"]
    assert gh.calls == []


def test_ack_settles_only_that_reply(env):
    _, ledger = env
    _two_replies(ledger)
    assert [i["reply_id"] for i in issues._undecided_replies()] == ["A", "B"]
    issues.reply_ack(14, "A", REASON)
    assert [i["reply_id"] for i in issues._undecided_replies()] == ["B"]
    assert [i["reply_id"] for i in issues._undecided_replies(include_all=True)] == ["A", "B"]
    issues.reply_ack(14, "B", REASON)
    assert issues._undecided_replies() == []


def test_ack_drops_out_of_the_sync_decision_leg(env):
    gh, ledger = env
    _two_replies(ledger)
    issues.reply_ack(14, "A", REASON)
    issues.reply_ack(14, "B", REASON)
    assert issues._settle_replies({14}, dry_run=False) == []
    assert not [r for r in rows(ledger) if r["stage"] == "needs-decision"]
    assert gh.calls == []


def test_unknown_reply_and_empty_reason_are_refused(env):
    _, ledger = env
    _two_replies(ledger)
    before = ledger.read_text()
    assert issues.main(["reply-ack", "14", "--reply-id", "NOPE", "--reason", REASON]) == 2
    assert issues.main(["reply-ack", "15", "--reply-id", "A", "--reason", REASON]) == 2   # wrong issue
    assert issues.main(["reply-ack", "14", "--reply-id", "A", "--reason", "   "]) == 2
    assert ledger.read_text() == before


def test_second_ack_is_a_no_op(env):
    _, ledger = env
    _two_replies(ledger)
    assert issues.reply_ack(14, "A", REASON) == "acked"
    assert issues.reply_ack(14, "A", REASON) == "already"
    assert len([r for r in rows(ledger) if r["stage"] == "reply-acked"]) == 1


def test_dry_run_writes_nothing(env, capsys):
    _, ledger = env
    _two_replies(ledger)
    before = ledger.read_text()
    assert issues.main(["reply-ack", "14", "--reply-id", "A", "--reason", REASON, "--dry-run"]) == 0
    assert '"stage": "reply-acked"' in capsys.readouterr().out
    assert ledger.read_text() == before
