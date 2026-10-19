"""T-4370: fw audit WARN for issue-ledger lag (G-119 detection).

A task with github_issue: implies a lifecycle stage on that issue (started-work -> in-progress,
work-completed -> fixed-on-bleeding-edge, a commit contained in a v* tag -> released). The check
lists every issue whose ledger lacks that stage. Pinned here against a committed fixture tree
(tests/unit/fixtures/t4370_issues_lag/) copied into a temp git repo that carries a v* tag.

Fixture cases (issue -> expected result):
  901  started-work, ledger only received+classified  -> finding, expected in-progress
  902  started-work, ledger has in-progress           -> satisfied
  903  work-completed, commit AFTER the tag           -> finding, expected fixed-on-bleeding-edge
  904  internal-author row (T-4342)                   -> exempt
  905  work-completed, commit IN the tag, ledger fixed -> finding, expected released
  906  in the tag, ledger has released                -> satisfied
  907  in the tag, ledger has closed-released         -> satisfied
  908  started-work, ledger has only a reply row      -> finding, last 'none'
  909  ledger row, no task                            -> ignored
  T-9009 has no github_issue                         -> ignored; ledger has a torn line -> skipped
"""

import json
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "lib"))
import issues_lag  # noqa: E402

FIXTURE = REPO_ROOT / "tests" / "unit" / "fixtures" / "t4370_issues_lag"
GIT_ID = ["-c", "user.name=t4370", "-c", "user.email=t4370@example.invalid"]
EXPECTED = {
    (901, "T-9001", "in-progress", "received+classified"),
    (903, "T-9003", "fixed-on-bleeding-edge", "in-progress"),
    (905, "T-9005", "released", "fixed-on-bleeding-edge"),
    (908, "T-9008", "in-progress", "none"),
}


def _git(repo: Path, *args: str) -> str:
    p = subprocess.run(["git", "-C", str(repo), *GIT_ID, *args], capture_output=True, text=True)
    assert p.returncode == 0, p.stderr
    return p.stdout


def _build_repo(dest: Path) -> Path:
    """Fixture tree -> temp git repo: pre-tag commits, a v9.9.9 tag, then post-tag commits."""
    shutil.copytree(FIXTURE / "tasks", dest / ".tasks")
    (dest / ".context" / "issues").mkdir(parents=True)
    shutil.copy(FIXTURE / "ledger" / "intake.jsonl", dest / ".context" / "issues" / "intake.jsonl")
    _git(dest, "init", "-q")
    _git(dest, "add", "-A")
    _git(dest, "commit", "-q", "-m", "fixture tree")
    for tid in ("T-9005", "T-9006", "T-9007", "T-9009"):  # shipped before the tag
        _git(dest, "commit", "-q", "--allow-empty", "-m", f"{tid}: shipped before v9.9.9")
    _git(dest, "tag", "v9.9.9")
    for tid in ("T-9001", "T-9002", "T-9003", "T-9004", "T-9008"):  # after the tag
        _git(dest, "commit", "-q", "--allow-empty", "-m", f"{tid}: after v9.9.9")
    return dest


@pytest.fixture
def repo(tmp_path):
    return _build_repo(tmp_path / "proj")


def _findings(root: Path) -> set:
    return {(f["issue"], f["task"], f["expected"], f["last"]) for f in issues_lag.check_lag(root)}


def test_fixture_yields_exactly_the_expected_lag(repo):
    assert _findings(repo) == EXPECTED


def test_internal_author_issue_is_exempt(repo):
    assert all(f["issue"] != 904 for f in issues_lag.check_lag(repo))


def test_released_expectation_needs_a_tag_containing_the_commit(repo):
    # T-9003 is work-completed with its only commit after the tag: fixed, not released.
    f = {x["task"]: x for x in issues_lag.check_lag(repo)}
    assert f["T-9003"]["expected"] == "fixed-on-bleeding-edge"


def test_without_git_no_release_is_claimed(tmp_path):
    root = tmp_path / "plain"
    shutil.copytree(FIXTURE / "tasks", root / ".tasks")
    (root / ".context" / "issues").mkdir(parents=True)
    shutil.copy(FIXTURE / "ledger" / "intake.jsonl", root / ".context" / "issues" / "intake.jsonl")
    found = {(f["issue"], f["expected"]) for f in issues_lag.check_lag(root)}
    assert (905, "released") not in found  # no tag: the 905 ledger row satisfies fixed, no release claimed
    assert (901, "in-progress") in found


def test_check_is_read_only(repo):
    ledger = repo / ".context" / "issues" / "intake.jsonl"
    before = (ledger.read_bytes(), _git(repo, "rev-parse", "HEAD"))
    issues_lag.check_lag(repo)
    assert (ledger.read_bytes(), _git(repo, "rev-parse", "HEAD")) == before


def test_findings_carry_mitigation_text(repo):
    by_issue = {f["issue"]: f for f in issues_lag.check_lag(repo)}
    assert by_issue[901]["mitigation"] == "bin/fw issues lifecycle T-9001 --event started"
    assert by_issue[903]["mitigation"] == "bin/fw issues lifecycle T-9003 --event closed"
    assert by_issue[905]["mitigation"] == "bin/fw issues release vX --range ..."


def test_cli_lists_lag_with_exit_1_and_clean_repo_exit_0(repo, tmp_path):
    cli = [sys.executable, str(REPO_ROOT / "lib" / "issues_lag.py"), "audit", "--root", str(repo)]
    p = subprocess.run(cli, capture_output=True, text=True)
    assert p.returncode == 1
    assert "LAG #901 T-9001 expected in-progress, ledger has received+classified" in p.stdout
    assert "LAG #908 T-9008 expected in-progress, ledger has none" in p.stdout

    clean = tmp_path / "clean"
    (clean / ".tasks" / "active").mkdir(parents=True)
    (clean / ".tasks" / "completed").mkdir(parents=True)
    p = subprocess.run([sys.executable, str(REPO_ROOT / "lib" / "issues_lag.py"), "audit",
                        "--root", str(clean)], capture_output=True, text=True)
    assert p.returncode == 0 and p.stdout == ""


def test_audit_sh_wires_the_check_into_the_structure_section():
    audit = (REPO_ROOT / "agents" / "audit" / "audit.sh").read_text()
    assert "lib/issues_lag.py" in audit
    assert audit.index("lib/issues_lag.py") < audit.index("# end structure")


def test_ledger_fixture_has_a_torn_line_that_is_skipped():
    lines = (FIXTURE / "ledger" / "intake.jsonl").read_text().splitlines()
    bad = [ln for ln in lines if ln.strip() and not _parses(ln)]
    assert bad, "fixture must keep a torn line so the reader's tolerance stays pinned"
    assert issues_lag._read_ledger(FIXTURE / "ledger" / "intake.jsonl")  # others still read


def _parses(line: str) -> bool:
    try:
        json.loads(line)
        return True
    except ValueError:
        return False
