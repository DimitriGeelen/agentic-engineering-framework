"""T-4394: a readiness entry that consulted the verdict ledger is keyed on the git inputs the
validator reads (commits mentioning the task, its task file, task-independent committed inputs,
rewritten/dropped history), not on .git/logs/HEAD - so an unrelated commit keeps it, and every
relevant commit still drops it (stale data on /approvals would be worse than slow)."""

import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, ".")
sys.path.insert(0, "lib")

from web import shared  # noqa: E402
import verdict_ledger as vl  # noqa: E402

GIT = ["git", "-c", "user.name=t", "-c", "user.email=t@t"]
TID = "T-9102"

TASTE = """- [ ] [REVIEW] Tone reads clearly
  **Steps:**
  1. Read it
  **Expected:** reads clearly, tone is right
  **If not:** note paragraphs
"""

TEXT = f"""---
id: {TID}
name: "fixture {TID}"
status: started-work
workflow_type: build
owner: agent
---

# {TID}

## Acceptance Criteria

### Agent
- [x] done

### Human
{TASTE}
## Verification
true
"""


def _git(repo, *args, **kw):
    return subprocess.run(GIT + ["-C", str(repo), *args], check=True, capture_output=True,
                          text=True, **kw).stdout.strip()


def _commit_file(repo, rel, content, msg):
    f = repo / rel
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(content)
    _git(repo, "add", "--", rel)
    _git(repo, "commit", "-q", "-m", msg)


@pytest.fixture
def proj(tmp_path, monkeypatch):
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    subprocess.run(["git", "init", "-q", str(tmp_path)], check=True)
    (tmp_path / ".tasks" / "active" / f"{TID}-fixture.md").write_text(TEXT)
    _git(tmp_path, "add", "-A")
    _git(tmp_path, "commit", "-q", "-m", f"{TID}: create")
    monkeypatch.setattr(shared, "PROJECT_ROOT", tmp_path)
    shared._READINESS_CACHE.clear()
    shared._LEDGER_CACHE.clear()
    getattr(shared, "_GIT_GEN", {}).clear()
    vl._GIT_MEMO.clear()
    return tmp_path


@pytest.fixture
def computes(monkeypatch):
    calls = []
    real = shared._compute_readiness

    def spy(*a, **k):
        calls.append(a[0])
        return real(*a, **k)

    monkeypatch.setattr(shared, "_compute_readiness", spy)
    return calls


def _ready(proj):
    p = proj / ".tasks" / "active" / f"{TID}-fixture.md"
    return shared.review_readiness(TID, "started-work", TEXT, p)


def _primed(proj, computes):
    first = _ready(proj)
    assert first[0] == "waiting-on-agent"
    assert computes == [TID]
    computes.clear()
    return first


def test_ledger_entry_survives_unrelated_commit(proj, computes):
    first = _primed(proj, computes)
    _commit_file(proj, "src/other.py", "x = 1\n", "T-1: unrelated work")
    _commit_file(proj, ".tasks/active/T-1-other.md", "---\nid: T-1\n---\n", "T-1: its task file")
    assert _ready(proj) == first
    assert computes == [], "recomputed after a commit that cannot change this task's verdict"


@pytest.mark.parametrize("msg", [f"{TID}: mentions it", f"fix\n\nsee {TID} body", "T-91021: longer id"])
def test_mention_invalidates(proj, computes, msg):
    _primed(proj, computes)
    _commit_file(proj, "src/other.py", msg, msg)
    _ready(proj)
    assert computes == [TID]


@pytest.mark.parametrize("rel", [".context/reviews/verdicts.jsonl", ".context/costs/reviews.jsonl",
                                 "policy/review-backends.yaml", ".fabric/components/x.yaml",
                                 ".framework.yaml", f".tasks/completed/{TID}-old.md"])
def test_relevant_path_invalidates(proj, computes, rel):
    _primed(proj, computes)
    _commit_file(proj, rel, "x\n", "chore: no id here")
    _ready(proj)
    assert computes == [TID]


def test_rewind_invalidates(proj, computes):
    _commit_file(proj, "src/a.py", "a\n", f"{TID}: producer commit")
    _primed(proj, computes)
    branch = _git(proj, "symbolic-ref", "--short", "HEAD")
    _git(proj, "update-ref", f"refs/heads/{branch}", "HEAD~1")
    _ready(proj)
    assert computes == [TID]


def test_new_branch_with_mention_invalidates(proj, computes):
    _primed(proj, computes)
    tree = _git(proj, "rev-parse", "HEAD^{tree}")
    sha = _git(proj, "commit-tree", tree, "-p", "HEAD", "-m", f"{TID}: on a side branch")
    _git(proj, "update-ref", "refs/heads/side", sha)
    _ready(proj)
    assert computes == [TID]


def test_head_fast_forward_onto_known_commit_invalidates(proj, computes):
    """The commit was seen when `side` moved, but the history read AT HEAD changes now."""
    tree = _git(proj, "rev-parse", "HEAD^{tree}")
    sha = _git(proj, "commit-tree", tree, "-p", "HEAD", "-m", f"{TID}: on a side branch")
    _git(proj, "update-ref", "refs/heads/side", sha)
    _primed(proj, computes)
    branch = _git(proj, "symbolic-ref", "--short", "HEAD")
    _git(proj, "update-ref", f"refs/heads/{branch}", sha)
    _ready(proj)
    assert computes == [TID]


def test_new_branch_without_new_commits_keeps_entry(proj, computes):
    first = _primed(proj, computes)
    _git(proj, "branch", "side")
    assert _ready(proj) == first
    assert computes == []


def test_uncommitted_ledger_write_still_invalidates(proj, computes):
    _primed(proj, computes)
    d = proj / ".context" / "reviews"
    d.mkdir(parents=True)
    (d / "verdicts.jsonl").write_text("{}\n")
    _ready(proj)
    assert computes == [TID]
