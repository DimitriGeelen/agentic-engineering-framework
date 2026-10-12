"""T-4113 / G-114 — the revert detector compares the decision VALUE at HEAD, not presence.

Before the fix any decision block at HEAD counted as "still there", so a Watchtower GO
rolled back to an earlier DEFER passed the audit. The newest decision commit (Watchtower
or CLI) is the one HEAD must still show. All fixtures are temp repos.
"""
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
DETECTOR = REPO_ROOT / "lib" / "watchtower_decision_revert.py"
TASK_ID = "T-9300"
TASK_PATH = f".tasks/completed/{TASK_ID}-decide-me.md"


def _git(repo, *args):
    r = subprocess.run(["git", *args], cwd=repo, capture_output=True, text=True, timeout=30)
    assert r.returncode == 0, f"git {' '.join(args)}: {r.stderr or r.stdout}"
    return r.stdout


def _task(decision):
    body = f"\n## Decision\n\n**Decision**: {decision}\n\n**Rationale**: test\n" if decision else "\n## Decision\n"
    return f"---\nid: {TASK_ID}\nstatus: work-completed\nworkflow_type: inception\n---\n# {TASK_ID}\n{body}"


def _commit(repo, decision, subject):
    """Write the task file with `decision` (None = no decision block) and commit it.

    other.txt follows the subject so every commit has content, even the unrelated ones.
    """
    (repo / TASK_PATH).write_text(_task(decision))
    (repo / "other.txt").write_text(subject + "\n")
    _git(repo, "add", "-A")
    _git(repo, "commit", "-qm", subject)


def _detect(repo):
    return subprocess.run([sys.executable, "-I", str(DETECTOR), "--repo", str(repo)],
                          capture_output=True, text=True, timeout=60)


def _repo(tmp_path):
    (tmp_path / ".tasks" / "completed").mkdir(parents=True)
    _git(tmp_path, "init", "-q")
    _git(tmp_path, "config", "user.email", "t@t")
    _git(tmp_path, "config", "user.name", "t")
    _git(tmp_path, "config", "commit.gpgsign", "false")
    (tmp_path / "other.txt").write_text("0\n")
    _commit(tmp_path, None, f"{TASK_ID}: seed")
    return tmp_path


WATCHTOWER_GO = f"{TASK_ID}: inception decision GO — decide chain finished (via Watchtower)"


def test_go_reverted_to_defer_at_head_is_detected(tmp_path):
    repo = _repo(tmp_path)
    _commit(repo, "GO", WATCHTOWER_GO)
    _commit(repo, "DEFER", "T-1: unrelated index write-back")  # stale index rewrites the old blob
    r = _detect(repo)
    assert r.returncode == 2, r.stdout + r.stderr
    assert f"REVERTED {TASK_ID}" in r.stdout, r.stdout
    assert "DEFER" in r.stdout and "GO" in r.stdout, r.stdout


def test_later_legitimate_no_go_decision_supersedes_go(tmp_path):
    repo = _repo(tmp_path)
    _commit(repo, "GO", WATCHTOWER_GO)
    _commit(repo, "NO-GO", f"{TASK_ID}: inception decision NO-GO — reconsidered")  # CLI, not Watchtower
    _commit(repo, "NO-GO", "T-1: unrelated change")
    r = _detect(repo)
    assert r.returncode == 0, r.stdout + r.stderr
    assert f"REVERTED {TASK_ID}" not in r.stdout, r.stdout


def test_go_still_at_head_is_not_flagged(tmp_path):
    repo = _repo(tmp_path)
    _commit(repo, "GO", WATCHTOWER_GO)
    _commit(repo, "GO", "T-1: unrelated change")
    r = _detect(repo)
    assert r.returncode == 0, r.stdout + r.stderr
    assert f"REVERTED {TASK_ID}" not in r.stdout, r.stdout


def test_stale_revert_to_go_after_a_later_no_go_is_detected(tmp_path):
    repo = _repo(tmp_path)
    _commit(repo, "GO", WATCHTOWER_GO)
    _commit(repo, "NO-GO", f"{TASK_ID}: inception decision NO-GO — reconsidered")
    _commit(repo, "GO", "T-1: stale index writes the Watchtower blob back")
    r = _detect(repo)
    assert r.returncode == 2, r.stdout + r.stderr
    assert f"REVERTED {TASK_ID}" in r.stdout, r.stdout


def test_decision_block_removed_at_head_is_still_detected(tmp_path):
    repo = _repo(tmp_path)
    _commit(repo, "GO", WATCHTOWER_GO)
    _commit(repo, None, "T-1: stale index drops the decision block")
    r = _detect(repo)
    assert r.returncode == 2, r.stdout + r.stderr
    assert f"REVERTED {TASK_ID}" in r.stdout and "no decision block at HEAD" in r.stdout, r.stdout
