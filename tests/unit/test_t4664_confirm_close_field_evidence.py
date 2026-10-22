"""T-4664: a submitter's confirmed fix is recorded as a WORKS row in the submitter field-evidence table,
which `fw issues release` merges with the release's own field report. gh is stubbed (T-4660's stub);
the real GitHub API is never called."""
import json
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "lib"))
sys.path.insert(0, str(ROOT / "tests" / "unit"))
import issues  # noqa: E402
from test_t4660_issue_replies import Gh, seed, reply_row, rows, FIXED, RELEASED  # noqa: E402,F401


@pytest.fixture
def env(tmp_path, monkeypatch):
    monkeypatch.setenv("FW_ISSUES_DIR", str(tmp_path))
    monkeypatch.delenv("FW_ISSUES_FIELD_REPORT", raising=False)
    gh = Gh()
    monkeypatch.setattr(issues, "_gh", gh)
    monkeypatch.setattr(issues, "_maintainer_login", lambda: "maint")
    return gh, tmp_path / "intake.jsonl", tmp_path / issues.SUBMITTER_REPORT


def _live(gh, body):
    gh.comments = [{"id": "R1", "author": {"login": "reporter"},
                    "url": "https://github.com/o/r/issues/5#issuecomment-9", "body": body}]


def _data_rows(report):
    return [x for x in report.read_text().splitlines() if x.startswith("| T-")]


def test_confirmed_close_records_a_works_row(env):
    gh, ledger, report = env
    seed(ledger, FIXED, RELEASED, reply_row())
    assert issues.confirm_close(5, "R1") == "closed"
    [row] = _data_rows(report)
    assert row.startswith("| T-4040 | **WORKS** — GitHub #5 (submitter) | 1.8.13 |")
    assert "https://github.com/o/r/issues/5#issuecomment-9" in row and "`R1`" in row
    v = issues._field_verdicts(report)
    assert v["T-4040"]["verdict"] == "works"
    assert any("GitHub #5 (submitter)" in e for e in v["T-4040"]["evidence"])


def test_version_not_stated(env):
    gh, ledger, report = env
    seed(ledger, FIXED, reply_row(excerpt="Confirmed fixed. Thank you."))
    _live(gh, "Confirmed fixed. Thank you.")
    issues.confirm_close(5, "R1")
    assert "| not stated |" in _data_rows(report)[0]


def test_close_ok_records_nothing(env):
    gh, ledger, report = env
    seed(ledger, FIXED, reply_row(excerpt="Thanks for the change. Fine to close."))
    _live(gh, "Thanks for the change. Fine to close.")
    assert issues.confirm_close(5, "R1") == "closed"
    assert not report.exists()


def test_dry_run_records_nothing(env):
    gh, ledger, report = env
    seed(ledger, FIXED, reply_row())
    assert issues.confirm_close(5, "R1", dry_run=True) == "would-close"
    assert not report.exists()


def test_record_is_idempotent_and_needs_tasks(env):
    _, _, report = env
    args = (5, "R1", ["T-1"], "Confirmed fixed on 1.8.13.", "https://x/5", "2026-10-22")
    assert issues.record_field_evidence(*args) == "recorded"
    assert issues.record_field_evidence(*args) == "already"
    assert len(_data_rows(report)) == 1
    assert issues.record_field_evidence(6, "R2", [], "Confirmed fixed.", "", "2026-10-22") == "no-tasks"


def test_sync_auto_close_records_the_row(env):
    gh, ledger, report = env
    seed(ledger, FIXED, reply_row())
    lines = issues._settle_replies({5}, dry_run=False)
    assert any("CONFIRMED #5" in x for x in lines)
    assert len(_data_rows(report)) == 1


def test_default_path_is_project_docs_reports(monkeypatch, tmp_path):
    monkeypatch.delenv("FW_ISSUES_DIR", raising=False)
    monkeypatch.delenv("FW_ISSUES_FIELD_REPORT", raising=False)
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    assert issues._submitter_report_path() == tmp_path / "docs" / "reports" / issues.SUBMITTER_REPORT


# ── backfill verb ───────────────────────────────────────────────────────────

def _closed(n, rid, tasks, cls=None):
    r = {"issue": n, "stage": "closed", "reply_id": rid, "by": "confirm-close", "tasks": tasks,
         "ts": "2026-10-22T20:36:28Z"}
    if cls:
        r["class"] = cls
    return r


def test_backfill_dry_run_then_real(env, capsys):
    gh, ledger, report = env
    seed(ledger,
         reply_row(5, "R1", excerpt="Confirmed fixed on 1.8.11 (e42aa41bf). Thank you."), _closed(5, "R1", ["T-1", "T-2"]),
         reply_row(6, "R2", excerpt="Fine to close."), _closed(6, "R2", ["T-3"], cls="close-ok"),
         reply_row(7, "R3", excerpt="Confirmed fixed."), _closed(7, "R3", ["T-4"]))
    assert issues.main(["field-evidence", "--dry-run"]) == 0
    assert not report.exists()
    assert "would-record" in capsys.readouterr().out
    assert issues.main(["field-evidence", "5", "6"]) == 0
    out = capsys.readouterr().out
    assert "recorded" in out and "skip-close-ok" in out
    [row] = _data_rows(report)
    assert row.startswith("| T-1, T-2 | **WORKS** — GitHub #5 (submitter) | 1.8.11 |")
    assert "| 2026-10-22 |" in row and "https://github.com/" in row
    assert issues.main(["field-evidence"]) == 0          # rerun: #5 already, #7 new
    assert "already" in capsys.readouterr().out
    assert len(_data_rows(report)) == 2
    assert gh.calls == []                                # ledger only, never GitHub


# ── release merges the table ────────────────────────────────────────────────

def test_release_merges_submitter_table(tmp_path):
    reports = tmp_path / "docs" / "reports"
    reports.mkdir(parents=True)
    issues.record_field_evidence(5, "R1", ["T-10", "T-11"], "Confirmed fixed on 1.8.13.", "https://x/5",
                                 "2026-10-22", path=reports / issues.SUBMITTER_REPORT)
    (reports / "field-test-v9.9.9-results.md").write_text(
        "# r\n\n| Fix | Project | Verdict |\n|---|---|---|\n| T-11 | p | **FAILS** |\n| T-12 | p | **WORKS** |\n")
    v = issues._release_field_verdicts(tmp_path, "v9.9.9")
    assert v["T-10"]["verdict"] == "works"
    assert any("GitHub #5 (submitter)" in e for e in v["T-10"]["evidence"])
    assert v["T-11"]["verdict"] == "fails"          # a FAILS in the release report still holds
    assert v["T-12"]["verdict"] == "works"
    assert issues._release_field_verdicts(tmp_path, "v0.0.1")["T-10"]["verdict"] == "works"  # no release report
