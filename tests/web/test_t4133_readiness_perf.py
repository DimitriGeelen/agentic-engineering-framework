"""T-4133: /tasks cold time. Git reads are memoised per repo state (HEAD + refs) and a readiness
entry that never consulted the verdict ledger is not invalidated by commits elsewhere."""

import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, ".")
sys.path.insert(0, "lib")

from web import shared  # noqa: E402
import verdict_ledger as vl  # noqa: E402

FW_ROOT = Path(__file__).resolve().parents[2]
GIT = ["git", "-c", "user.name=t", "-c", "user.email=t@t"]

DETERMINISTIC = """- [ ] [RUBBER-STAMP] Run it
  **Steps:**
  1. Run `ls /tmp`
  **Expected:** output contains `tmp`
  **If not:** fix it
"""
TASTE = """- [ ] [REVIEW] Tone reads clearly
  **Steps:**
  1. Read it
  **Expected:** reads clearly, tone is right
  **If not:** note paragraphs
"""


def _task(tid, agent, human):
    return f"""---
id: {tid}
name: "fixture {tid}"
status: started-work
workflow_type: build
owner: agent
---

# {tid}

## Acceptance Criteria

### Agent
{agent}
### Human
{human}
## Verification
true
"""


def _commit(repo, msg):
    subprocess.run(GIT + ["-C", str(repo), "commit", "-q", "--allow-empty", "-m", msg], check=True)


@pytest.fixture
def proj(tmp_path, monkeypatch):
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    subprocess.run(["git", "init", "-q", str(tmp_path)], check=True)
    _commit(tmp_path, "init")
    monkeypatch.setattr(shared, "PROJECT_ROOT", tmp_path)
    shared._READINESS_CACHE.clear()
    shared._LEDGER_CACHE.clear()
    vl._GIT_MEMO.clear()
    return tmp_path


@pytest.fixture
def count_git(monkeypatch):
    calls = []
    real = subprocess.run

    def run(cmd, *a, **k):
        if cmd[:1] == ["git"]:
            calls.append(cmd[1:])
        return real(cmd, *a, **k)

    monkeypatch.setattr(vl.subprocess, "run", run)
    return calls


def test_repeated_git_read_is_one_subprocess(proj, count_git):
    for _ in range(5):
        assert vl._git_out(proj, "log", "--format=%H", "HEAD")[0] == 0
    assert len(count_git) == 1


def test_new_commit_invalidates_memo(proj, count_git):
    _, before = vl._git_out(proj, "log", "--format=%H", "HEAD")
    _commit(proj, "second")
    _, after = vl._git_out(proj, "log", "--format=%H", "HEAD")
    assert after != before and len(after.split()) == 2
    assert len([c for c in count_git if c[:1] == ["log"]]) == 2


def test_moved_ref_invalidates_memo(proj):
    subprocess.run(GIT + ["-C", str(proj), "branch", "side"], check=True)
    _, a = vl._git_out(proj, "rev-parse", "side")
    _commit(proj, "second")
    subprocess.run(GIT + ["-C", str(proj), "branch", "-f", "side", "HEAD"], check=True)
    _, b = vl._git_out(proj, "rev-parse", "side")
    assert a != b


def test_worktree_dependent_commands_are_never_memoised(proj, count_git):
    vl._git_out(proj, "status", "--porcelain")
    vl._git_out(proj, "status", "--porcelain")
    (proj / "new.txt").write_text("x")
    _, out = vl._git_out(proj, "status", "--porcelain")
    assert "new.txt" in out
    assert len(count_git) == 3


def test_failures_are_not_memoised(proj, count_git):
    assert vl._git_out(proj, "rev-parse", "-q", "--verify", "nope")[0] != 0
    assert vl._git_out(proj, "rev-parse", "-q", "--verify", "nope")[0] != 0
    assert len(count_git) == 2


def _readiness(proj, tid, text):
    p = proj / ".tasks" / "active" / f"{tid}-fixture.md"
    if not p.exists() or p.read_text() != text:
        p.write_text(text)
    return shared.review_readiness(tid, "started-work", text, p)


def test_ledger_free_entry_survives_unrelated_commit(proj, monkeypatch):
    text = _task("T-9101", "- [ ] open\n", DETERMINISTIC)
    first = _readiness(proj, "T-9101", text)
    assert first[0] == "waiting-on-agent"
    _commit(proj, "elsewhere")
    monkeypatch.setattr(shared, "_compute_readiness",
                        lambda *a, **k: pytest.fail("recomputed after an unrelated commit"))
    assert _readiness(proj, "T-9101", text) == first


def test_ledger_dependent_entry_recomputes_after_commit(proj):
    text = _task("T-9102", "- [x] done\n", TASTE)
    _readiness(proj, "T-9102", text)
    _commit(proj, "elsewhere")
    calls = []
    real = shared._compute_readiness

    def spy(*a, **k):
        calls.append(1)
        return real(*a, **k)

    shared._compute_readiness = spy
    try:
        assert _readiness(proj, "T-9102", text)[0] == "waiting-on-agent"
    finally:
        shared._compute_readiness = real
    assert calls == [1]


def test_edit_to_task_file_invalidates_its_entry(proj):
    p = proj / ".tasks" / "active" / "T-9103-fixture.md"
    assert _readiness(proj, "T-9103", _task("T-9103", "- [ ] open\n", DETERMINISTIC))[0] == "waiting-on-agent"
    text = _task("T-9103", "- [x] done\n", DETERMINISTIC)
    p.write_text(text)
    os.utime(p, ns=(p.stat().st_atime_ns, p.stat().st_mtime_ns + 10_000_000))
    subprocess.run(GIT + ["-C", str(proj), "add", "-A"], check=True)
    _commit(proj, "task file touched")
    assert shared.review_readiness("T-9103", "started-work", text, p)[0] == "ready"


def test_equivalence_memo_off_vs_on_over_this_repos_active_tasks(monkeypatch):
    """Same results with the memo and the narrowed cache as with neither."""
    monkeypatch.setattr(shared, "PROJECT_ROOT", FW_ROOT)
    files = sorted((FW_ROOT / ".tasks" / "active").glob("T-*.md"))[:150]

    def sweep():
        shared._READINESS_CACHE.clear()
        shared._LEDGER_CACHE.clear()
        return {f.name: shared.task_review_state(f) for f in files}

    on = sweep()
    monkeypatch.setattr(vl, "_GIT_MEMO_CMDS", frozenset())
    off = sweep()
    assert json.dumps(on, sort_keys=True, default=list) == json.dumps(off, sort_keys=True, default=list)


# ── round 2: batched walks ───────────────────────────────────────────────────────────────────

def _history_repo(tmp_path, n=12):
    """n tasks, each with several committed versions and commits that mention it."""
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    (tmp_path / ".tasks" / "completed").mkdir()
    (tmp_path / "src").mkdir()
    subprocess.run(["git", "init", "-q", str(tmp_path)], check=True)
    for v in range(3):
        for i in range(n):
            tid = f"T-{9300 + i}"
            f = tmp_path / ".tasks" / "active" / f"{tid}-slug.md"
            f.write_text(f"---\nid: {tid}\nname: x\nblast_radius: {v}\n---\nbody {v}\n")
            (tmp_path / "src" / f"{tid}.py").write_text(f"v{v}\n")
            subprocess.run(GIT + ["-C", str(tmp_path), "add", "-A"], check=True)
            subprocess.run(GIT + ["-C", str(tmp_path), "commit", "-q", "-m", f"{tid}: step {v}\n\nmentions T-{9300 + (i + 1) % n}"],
                           check=True)
    done = tmp_path / ".tasks" / "completed" / "T-9300-slug.md"
    (tmp_path / ".tasks" / "active" / "T-9300-slug.md").rename(done)
    subprocess.run(GIT + ["-C", str(tmp_path), "add", "-A"], check=True)
    subprocess.run(GIT + ["-C", str(tmp_path), "commit", "-q", "-m", "T-9300: close"], check=True)
    return tmp_path


def _clear_all():
    for d in (vl._GIT_MEMO, vl._HISTORY_FM, vl._GIT_COMPONENTS, vl._TASK_FILE_INDEX, vl._ALL_COMMITS):
        d.clear()


def _answers(repo, n=12):
    out = {}
    for i in range(n):
        tid = f"T-{9300 + i}"
        out[tid] = (
            [(s, dict(fm)) for s, fm in vl._task_history_fms(repo, tid)],
            vl._git_components(repo, tid),
            sorted(vl.producers_checked(repo, tid)[0]),
            vl.producers_checked(repo, tid)[1],
        )
    return out


def test_batched_walks_equal_per_task_walks(tmp_path, monkeypatch):
    repo = _history_repo(tmp_path)
    _clear_all()
    batched = _answers(repo)
    assert any(v[0] for v in batched.values()), "fixture must produce task versions"
    assert any(v[2] for v in batched.values()), "fixture must produce producers"
    _clear_all()
    monkeypatch.setattr(vl, "_task_file_index", lambda *a: None)
    monkeypatch.setattr(vl, "_all_commit_index", lambda *a: None)
    assert json.dumps(batched, sort_keys=True, default=list) == \
        json.dumps(_answers(repo), sort_keys=True, default=list)


def test_batched_walk_is_constant_in_the_number_of_tasks(tmp_path, count_git):
    repo = _history_repo(tmp_path)
    _clear_all()
    _answers(repo)
    walks = [c for c in count_git if c[:1] == ["log"]]
    # one .tasks history walk + one --all walk (+ HEAD resolution), never one per task
    assert len(walks) <= 2, walks


def test_batched_index_is_not_served_for_another_head(tmp_path):
    repo = _history_repo(tmp_path)
    _clear_all()
    before = vl._task_history_fms(repo, "T-9301")
    prod_before = vl.producers_checked(repo, "T-9301")
    (repo / ".tasks" / "active" / "T-9301-slug.md").write_text("---\nid: T-9301\nblast_radius: 9\n---\nnew\n")
    subprocess.run(GIT + ["-C", str(repo), "add", "-A"], check=True)
    env = {**os.environ, "GIT_AUTHOR_NAME": "other", "GIT_AUTHOR_EMAIL": "o@o",
           "GIT_COMMITTER_NAME": "other", "GIT_COMMITTER_EMAIL": "o@o"}
    subprocess.run(["git", "-C", str(repo), "commit", "-q", "-m", "T-9301: new version"],
                   check=True, env=env)
    after = vl._task_history_fms(repo, "T-9301")
    assert len(after) == len(before) + 1
    got = vl.producers_checked(repo, "T-9301")[0]
    assert any("o@o" in x or "other" in x for x in got), got
    assert not any("other" in x for x in prod_before[0])


def test_state_token_follows_loose_ref_creation_and_removal(proj):
    t0 = vl._git_state_token(proj)
    subprocess.run(GIT + ["-C", str(proj), "branch", "a/b/c"], check=True)
    t1 = vl._git_state_token(proj)
    subprocess.run(GIT + ["-C", str(proj), "branch", "-D", "a/b/c"], check=True)
    t2 = vl._git_state_token(proj)
    assert len({t0, t1, t2}) == 3
