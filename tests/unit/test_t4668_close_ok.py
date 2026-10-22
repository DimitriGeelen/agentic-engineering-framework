"""T-4668: close-ok replies — the submitter OKs closing. gh is stubbed (T-4660's stub); the real
GitHub API is never called."""
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "lib"))
sys.path.insert(0, str(ROOT / "tests" / "unit"))
import issues  # noqa: E402
from test_t4660_issue_replies import Gh, seed, reply_row, rows, FIXED, RELEASED  # noqa: E402,F401

# Issue #92's last reply (IC_kwDORdtOLc8AAAABekVrTg, 2026-10-22), verbatim from GitHub. The ledger in
# .context/issues/intake.jsonl holds only its first 500 characters, which stop before the OK.
R92 = (
    "Thank you for building this so quickly.\n\n"
    "In our setup the \"Awaiting review\" column stays empty on purpose: a task only enters it with a "
    "verdict from the independent AI reviewer, and we chose not to enable one (reviews of our "
    "deliverables stay human-only). So I cannot confirm the column from real use.\n\n"
    "What we actually needed, as in the original request, is to see the tasks where the agent is done "
    "and the human has to act. Today we get that from `owner: human` and the `/tasks?owner=human` view, "
    "which works for us. If the column could also take tasks whose Agent criteria are all ticked and "
    "whose owner is human, without a reviewer verdict, it would cover projects like ours too.\n\n"
    "Fine to close from our side."
)


@pytest.mark.parametrize("text,want", [
    (R92, "close-ok"),
    ("Thanks for the change. Fine to close.", "close-ok"),
    ("Thanks. OK to close from my side.", "close-ok"),
    ("I have not tried it yet, but you can close this.", "close-ok"),
    ("Feel free to close it.", "close-ok"),
    ("Happy for this to be closed.", "close-ok"),
    # confirmed keeps priority
    ("Confirmed fixed on 1.8.13. Fine to close.", "confirmed"),
    # counter-signals
    ("Still broken for me, but fine to close if you want.", "not-fixed"),
    ("Not fixed yet. You can close it later.", "not-fixed"),
    ("Thanks. Please keep this open until I test it.", "other"),
    ("Thanks. Don't close yet, fine to close next week.", "other"),
    ("It is not fine to close.", "other"),
    ("Is it fine to close?", "other"),
    ("Thanks, will test later.", "other"),
])
def test_classifier_table(text, want):
    assert issues.classify_reply(text, "a", "a") == want


def test_non_author_ok_is_other():
    assert issues.classify_reply("Fine to close.", "bystander", "reporter") == "other"


def test_suggestion_heuristic():
    assert issues.has_suggestion(R92)
    assert issues.has_suggestion("Fine to close. I suggest a flag for it.")
    assert issues.has_suggestion("Fine to close. A dark mode would be nice.")
    assert not issues.has_suggestion("Thanks, it works for us. Fine to close.")
    assert not issues.has_suggestion("I could not test the CLI. Fine to close.")


def test_excerpt_keeps_the_tail():
    assert "Fine to close from our side." in issues._excerpt(R92)
    assert issues.classify_reply(issues._excerpt(R92), "a", "a") == "close-ok"
    assert issues.classify_reply(R92[:500], "a", "a") == "other"   # the old head-only cut
    assert issues._excerpt("short") == "short"


@pytest.fixture
def env(tmp_path, monkeypatch):
    monkeypatch.setenv("FW_ISSUES_DIR", str(tmp_path))
    gh = Gh()
    monkeypatch.setattr(issues, "_gh", gh)
    monkeypatch.setattr(issues, "_maintainer_login", lambda: "maint")
    return gh, tmp_path / "intake.jsonl"


def _live(gh, body):
    gh.comments = [{"id": "R1", "author": {"login": "reporter"},
                    "url": "https://github.com/o/r/issues/5#issuecomment-9", "body": body}]


def test_confirm_close_close_ok_with_note(env):
    gh, ledger = env
    seed(ledger, FIXED, RELEASED, reply_row(excerpt=R92[:500]))
    _live(gh, R92)
    assert issues.confirm_close(5, "R1", note="Your suggestion is tracked as T-4663.") == "closed"
    body = gh.posted[0]
    assert "Closed with your OK" in body and "confirmed fixed" not in body
    assert "Thank you" in body
    assert "> Fine to close from our side." in body
    assert "cannot confirm the column" in body          # caveat kept on record
    assert "T-4040" in body and "v1.8.11" in body and "20289bf2d" in body
    assert "Your suggestion is tracked as T-4663." in body
    assert issues.FOOTER in body
    last = rows(ledger)[-1]
    assert last["stage"] == "closed" and last["class"] == "close-ok"
    assert [c for c in gh.calls if c[:2] == ["issue", "close"]][0][-2:] == ["--reason", "completed"]


def test_confirm_close_note_on_confirmed(env):
    gh, ledger = env
    seed(ledger, FIXED, reply_row())
    issues.confirm_close(5, "R1", note="Follow-up: T-9999.")
    assert "confirmed fixed" in gh.posted[0] and "Follow-up: T-9999." in gh.posted[0]


def test_confirm_close_close_ok_needs_fixed_stage(env):
    gh, ledger = env
    seed(ledger, reply_row(excerpt="Fine to close."))
    _live(gh, "Fine to close.")
    with pytest.raises(issues.IssuesError, match="no fixed-on-bleeding-edge"):
        issues.confirm_close(5, "R1")
    assert gh.posted == []


def test_cli_note_flag(env, capsys):
    gh, ledger = env
    seed(ledger, FIXED, reply_row(excerpt="Fine to close."))
    _live(gh, "Fine to close.")
    assert issues.main(["confirm-close", "5", "--reply-id", "R1", "--note", "Tracked as T-1.",
                        "--dry-run"]) == 0
    out = capsys.readouterr().out
    assert "Closed with your OK" in out and "Tracked as T-1." in out and gh.posted == []


# ── sync leg ────────────────────────────────────────────────────────────────

def test_settle_auto_closes_plain_close_ok(env):
    gh, ledger = env
    seed(ledger, FIXED, reply_row(excerpt="Thanks, that works for us. Fine to close."))
    _live(gh, "Thanks, that works for us. Fine to close.")
    lines = issues._settle_replies({5}, dry_run=False)
    assert any("CLOSE-OK #5" in x for x in lines)
    assert len(gh.posted) == 1 and "Closed with your OK" in gh.posted[0]


def test_settle_holds_close_ok_with_a_suggestion(env):
    gh, ledger = env
    seed(ledger, FIXED, reply_row(excerpt=issues._excerpt(R92)))
    _live(gh, R92)
    lines = issues._settle_replies({5}, dry_run=False)
    assert gh.posted == [] and ["issue", "close"] not in [c[:2] for c in gh.calls]
    nd = [r for r in rows(ledger) if r["stage"] == "needs-decision"]
    assert len(nd) == 1 and nd[0]["class"] == "close-ok" and "suggestion" in nd[0]["reason"]
    assert any("DECIDE #5" in x for x in lines)
    # the agent then files the follow-up and closes by hand with a note
    assert issues.confirm_close(5, "R1", note="Your suggestion is tracked as T-4663.") == "closed"


def test_settle_close_ok_without_fixed_stage_needs_decision(env):
    gh, ledger = env
    seed(ledger, reply_row(excerpt="Fine to close."))
    issues._settle_replies({5}, dry_run=False)
    assert gh.posted == []
    assert [r["class"] for r in rows(ledger) if r["stage"] == "needs-decision"] == ["close-ok"]
