"""T-4660: act on submitter replies — classifier, `replies`, `confirm-close`, sync auto-close.
gh is stubbed in-process; the real GitHub API is never called."""
import json
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "lib"))
import issues  # noqa: E402

# The real excerpts from .context/issues/intake.jsonl (2026-10-22), verbatim.
REAL = {
    86: ("Confirmed fixed (checked on 1.8.13, which carries T-4040).\n\nIn a throwaway container, a fresh "
         "`fw init --provider claude` seeds T-002 with `target_blast_radius: 3` and `voi_score: 0.5`. Fed an "
         "Edit on that file, `check-inception-schema.py` exits 0; with `voi_score` removed it exits 2, so the "
         "gate still bites. I did not run a full agent session on the fresh project. Thank you.\n", "confirmed"),
    87: ("Confirmed fixed. I tested it on a copy of a vendored consumer pinned at v1.8.13, so with upstream one "
         "release ahead, which is the case that used to fail.\n\nA plain `.agentic-framework/bin/fw upgrade` run "
         "from the project printed \"Bare-from-consumer detected\" and upgraded to v1.8.14 with exit 0.\n",
         "confirmed"),
    90: ("Confirmed fixed on 1.8.13. A project document under `docs/reports/` opened through `/file/` now shows "
         "its `# title` once (one `<h1>`), and the \"View in Fabric\" link is gone for a file without a "
         "component card. Thank you.\n", "confirmed"),
    93: ("Looks fixed on 1.8.13, checked on the rendered page only. On `/inception/T-002` of a freshly "
         "initialised project, the unticked Human criterion is rendered as a checkbox in a form posting to "
         "`/api/task/T-002/toggle-ac`, and the page header links to the task page. I have not clicked it in a "
         "browser, as there is no unticked inception criterion in the project where I work. Thank you.\n",
         "confirmed"),
    94: ("Confirmed fixed on 1.8.13. On the inception page of a task made from the stock template, the "
         "Verification card now shows the section verbatim in a `<pre>` block, `#` comment lines included, "
         "instead of turning them into headings. Thank you.\n", "confirmed"),
    92: ("Thank you for building this so quickly.\n\nIn our setup the \"Awaiting review\" column stays empty on "
         "purpose: a task only enters it with a verdict from the independent AI reviewer, and we chose not to "
         "enable one. So I cannot confirm the column from real use.\n", "other"),
}


@pytest.mark.parametrize("n", sorted(REAL))
def test_real_excerpts(n):
    text, want = REAL[n]
    assert issues.classify_reply(text, "MikeEchoVoid", "MikeEchoVoid") == want


@pytest.mark.parametrize("text,want", [
    ("Verified fixed on main.", "confirmed"),
    ("Fixed for me, thanks.", "confirmed"),
    ("Works now after the upgrade.", "confirmed"),
    ("Confirmed fixed, but it is not fixed for the second case.", "not-fixed"),
    ("Confirmed fixed. However the doctor output is odd.", "other"),
    ("Confirmed fixed, except on Windows.", "other"),
    ("Not fixed on 1.8.13, the error is the same.", "not-fixed"),
    ("Still broken for me.", "not-fixed"),
    ("This is a regression.", "not-fixed"),
    ("Thanks, will test later.", "other"),
    ("", "other"),
    ("Looks fixed, but I will reopen if it comes back.", "not-fixed"),
])
def test_classifier_table(text, want):
    assert issues.classify_reply(text, "a", "a") == want


def test_non_author_is_other():
    assert issues.classify_reply("Confirmed fixed.", "bystander", "reporter") == "other"


def test_quote_and_caveats():
    assert issues._quote(REAL[93][0]) == "Looks fixed on 1.8.13, checked on the rendered page only."
    assert any("not clicked" in c for c in issues._caveats(REAL[93][0]))
    assert issues._quote("Confirmed <!-- aef-intake:stage=x --> fixed. More") == "Confirmed  fixed."


# ── ledger + stubbed gh ─────────────────────────────────────────────────────

class Gh:
    def __init__(self):
        self.calls, self.state, self.author = [], "OPEN", "reporter"
        self.comments = [],
        self.comments = [{"id": "R1", "author": {"login": "reporter"}, "url": "https://github.com/o/r/issues/5#issuecomment-9",
                          "body": "Confirmed fixed on 1.8.13. Thank you."}]
        self.fail = set()
        self.posted = []

    def __call__(self, args, stdin=None):
        self.calls.append(args)

        class P:
            returncode, stdout, stderr = 0, "", ""
        p = P()
        if args[:2] == ["issue", "view"]:
            p.stdout = json.dumps({"state": self.state, "author": {"login": self.author},
                                   "comments": self.comments})
        elif args[:2] == ["issue", "comment"]:
            if "comment" in self.fail:
                p.returncode, p.stderr = 1, "503"
            else:
                self.posted.append(stdin)
                p.stdout = "https://github.com/o/r/issues/5#issuecomment-77\n"
        elif args[:2] == ["issue", "close"]:
            if "close" in self.fail:
                p.returncode, p.stderr = 1, "nope"
        return p


@pytest.fixture
def env(tmp_path, monkeypatch):
    monkeypatch.setenv("FW_ISSUES_DIR", str(tmp_path))
    gh = Gh()
    monkeypatch.setattr(issues, "_gh", gh)
    monkeypatch.setattr(issues, "_maintainer_login", lambda: "maint")
    return gh, tmp_path / "intake.jsonl"


def seed(ledger, *rows):
    ledger.write_text("".join(json.dumps(r) + "\n" for r in rows))


def reply_row(n=5, rid="R1", author="reporter", excerpt="Confirmed fixed on 1.8.13. Thank you."):
    return {"issue": n, "stage": "reply", "reply_id": rid, "author": author,
            "created": "2026-10-22T15:00:00Z", "excerpt": excerpt, "answered": False}


FIXED = {"issue": 5, "stage": "fixed-on-bleeding-edge", "tasks": ["T-4040"], "commit": "20289bf2d"}
RELEASED = {"issue": 5, "stage": "released", "tasks": ["T-4040"], "version": "v1.8.11"}


def rows(ledger):
    return [json.loads(x) for x in ledger.read_text().splitlines() if x.strip()]


def test_replies_lists_undecided_and_hides_settled(env, capsys):
    gh, ledger = env
    seed(ledger, FIXED, reply_row(), reply_row(6, "R2", excerpt="Thank you for building this."))
    items = issues._undecided_replies()
    assert [(i["issue"], i["class"], i["stage"]) for i in items] == [
        (5, "confirmed", "fixed-on-bleeding-edge"), (6, "other", "")]
    issues._append_row(ledger, {"issue": 5, "stage": "closed", "reply_id": "R1"})
    assert [i["issue"] for i in issues._undecided_replies()] == [6]
    assert [i["issue"] for i in issues._undecided_replies(include_all=True)] == [5, 6]
    assert issues.main(["replies", "--json"]) == 0
    assert json.loads(capsys.readouterr().out)[0]["issue"] == 6


@pytest.mark.parametrize("setup,msg", [
    (lambda gh, led: None, "no reply"),                                   # rid not in ledger (below)
    (lambda gh, led: seed(led, reply_row()), "no fixed-on-bleeding-edge"),
    (lambda gh, led: (seed(led, FIXED, reply_row()), setattr(gh, "state", "CLOSED")), "not open"),
    (lambda gh, led: (seed(led, FIXED, reply_row(author="bystander"))), "not the issue author"),
    (lambda gh, led: (seed(led, FIXED, reply_row(excerpt="Still broken.")), setattr(gh, "comments", [])),
     "does not classify"),
])
def test_confirm_close_refusals(env, setup, msg):
    gh, ledger = env
    setup(gh, ledger)
    with pytest.raises(issues.IssuesError, match=msg):
        issues.confirm_close(5, "R1" if msg != "no reply" else "NOPE")
    assert gh.posted == [] and ["issue", "close"] not in [c[:2] for c in gh.calls]


def test_confirm_close_posts_one_comment_closes_and_is_idempotent(env):
    gh, ledger = env
    seed(ledger, FIXED, RELEASED, reply_row())
    assert issues.confirm_close(5, "R1") == "closed"
    assert len(gh.posted) == 1
    body = gh.posted[0]
    assert body.startswith("<!-- aef-intake:stage=closed -->")
    assert "> Confirmed fixed on 1.8.13." in body and "issuecomment-9" in body
    assert "T-4040" in body and "v1.8.11" in body and "20289bf2d" in body
    assert issues.FOOTER in body
    assert [c for c in gh.calls if c[:2] == ["issue", "close"]][0][-2:] == ["--reason", "completed"]
    last = rows(ledger)[-1]
    assert last["stage"] == "closed" and last["reply_id"] == "R1" and last["by"] == "confirm-close"
    n_calls = len(gh.calls)
    assert issues.confirm_close(5, "R1") == "already"
    assert len(gh.calls) == n_calls and len(gh.posted) == 1


def test_partial_check_is_named_in_the_comment(env):
    gh, ledger = env
    seed(ledger, FIXED, reply_row(excerpt=REAL[93][0]))
    gh.comments = []
    issues.confirm_close(5, "R1")
    assert "checked on the rendered page only" in gh.posted[0] and "not clicked" in gh.posted[0]


def test_dry_run_posts_nothing(env, capsys):
    gh, ledger = env
    seed(ledger, FIXED, reply_row())
    assert issues.confirm_close(5, "R1", dry_run=True) == "would-close"
    assert gh.posted == [] and "Thank you" in capsys.readouterr().out
    assert len(rows(ledger)) == 2


def test_failed_close_retries_close_only(env):
    gh, ledger = env
    seed(ledger, FIXED, reply_row())
    gh.fail.add("close")
    with pytest.raises(issues.IssuesError):
        issues.confirm_close(5, "R1")
    assert [r["stage"] for r in rows(ledger)][-1] == "closed-note"
    gh.fail.clear()
    assert issues.confirm_close(5, "R1") == "closed"
    assert len(gh.posted) == 1


# ── sync leg ────────────────────────────────────────────────────────────────

def test_settle_auto_closes_confirmed_and_marks_the_rest(env):
    gh, ledger = env
    seed(ledger, FIXED, reply_row(), reply_row(6, "R2", excerpt="Not fixed on 1.8.13."),
         reply_row(7, "R3", excerpt="Nice feature, thanks."))
    lines = issues._settle_replies({5, 6, 7}, dry_run=False)
    assert any("CONFIRMED #5" in x for x in lines)
    assert len(gh.posted) == 1  # nothing posted for the not-fixed or other replies
    nd = {r["issue"]: r["class"] for r in rows(ledger) if r["stage"] == "needs-decision"}
    assert nd == {6: "not-fixed", 7: "other"}
    issues._settle_replies({5, 6, 7}, dry_run=False)  # second run: no duplicate rows
    assert len([r for r in rows(ledger) if r["stage"] == "needs-decision"]) == 2
    assert len(gh.posted) == 1


def test_settle_gh_failure_leaves_ledger_alone(env):
    gh, ledger = env
    seed(ledger, FIXED, reply_row())
    gh.fail.add("comment")
    before = ledger.read_text()
    lines = issues._settle_replies({5}, dry_run=False)
    assert any("WARN #5" in x for x in lines) and ledger.read_text() == before


def test_settle_confirmed_without_fixed_stage_needs_decision(env):
    gh, ledger = env
    seed(ledger, reply_row())
    issues._settle_replies({5}, dry_run=False)
    assert gh.posted == []
    assert [r["class"] for r in rows(ledger) if r["stage"] == "needs-decision"] == ["confirmed"]


def test_settle_marks_replies_on_closed_issues(env):
    gh, ledger = env
    seed(ledger, reply_row())
    issues._settle_replies(set(), dry_run=False)
    assert issues._undecided_replies() == []
