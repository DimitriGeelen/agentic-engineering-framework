"""T-5196: persistent memo for `_git_out` calls fixed by full 40-hex object ids.

Only `show <40-hex>:<path>` and `ls-tree [-r] [--name-only] <40-hex> -- <paths>` may be served from
it; refs, HEAD, short ids and ranges never are. A damaged or unreadable memo falls back to git."""
import os
import sqlite3
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "lib"))
sys.path.insert(0, str(ROOT))
import verdict_ledger as vl  # noqa: E402

H = "0123456789abcdef0123456789abcdef01234567"


def _reset():
    for d in vl._IMM_DB.values():
        if d:
            d["conn"].close()
    vl._IMM_DB.clear()
    vl._IMM_MEM.clear()
    vl._IMM_CTX.clear()
    vl._GIT_MEMO.clear()
    vl._REF_DIRS.clear()


def _git(root, *a):
    return subprocess.run(["git", *a], cwd=str(root), capture_output=True, text=True, check=True).stdout.strip()


def _commit(root, name, text, msg):
    (root / name).write_text(text)
    _git(root, "add", name)
    _git(root, "commit", "-q", "-m", msg)
    return _git(root, "rev-parse", "HEAD")


@pytest.fixture
def repo(tmp_path, monkeypatch):
    for k in list(os.environ):
        if k.startswith("GIT_") and k not in vl._IMM_ENV_OK:
            monkeypatch.delenv(k)
    _git(tmp_path, "init", "-q")
    _git(tmp_path, "config", "user.name", "t")
    _git(tmp_path, "config", "user.email", "t@t")
    (tmp_path / ".context" / "working").mkdir(parents=True)
    (tmp_path / ".gitignore").write_text(".context/working/*.db*\n")
    _git(tmp_path, "add", ".gitignore")
    _reset()
    yield tmp_path
    _reset()


@pytest.fixture
def git_calls(monkeypatch):
    calls = []
    real = subprocess.run

    def run(argv, *a, **kw):
        if argv and argv[0] == "git":
            calls.append(tuple(argv[1:]))
        return real(argv, *a, **kw)
    monkeypatch.setattr(vl.subprocess, "run", run)
    return calls


def _rows(root):
    db = root / vl.IMM_MEMO_FILE
    if not db.exists():
        return []
    c = sqlite3.connect(str(db))
    try:
        return [r[0] for r in c.execute("SELECT args FROM memo")]
    finally:
        c.close()


def _restart():
    """A new process: every in-memory layer gone, the file on disk kept."""
    _reset()


# --- classification -------------------------------------------------------------------------

@pytest.mark.parametrize("args", [
    ("show", f"{H}:a.txt"),
    ("show", f"{H}:.context/reviews/verdicts.jsonl"),
    ("ls-tree", "-r", "--name-only", H, "--", ".tasks/active", ".tasks/completed"),
    ("ls-tree", "-r", H, "--", ".fabric/components/"),
    ("ls-tree", "--name-only", H, "--", "x"),
])
def test_immutable_shapes(args):
    assert vl._immutable_args(args)


@pytest.mark.parametrize("args", [
    ("show", "HEAD:a.txt"),                       # a ref
    ("show", "master:a.txt"),
    ("show", "refs/heads/master:a.txt"),
    ("show", f"{H[:12]}:a.txt"),                  # short id
    ("show", f"{H.upper()}:a.txt"),               # not the canonical spelling
    ("show", f"{H}^:a.txt"),                      # a parent walk
    ("show", f"{H}~1:a.txt"),
    ("show", f"{H}..HEAD"),                       # a range ending in a ref
    ("show", f"{H}"),                             # a whole commit (decorations, config)
    ("show", f"{H}:"),                            # empty path
    ("show", f"{H}:./a.txt"),                     # cwd-relative
    ("show", f"{H}:../a.txt"),
    ("show", "--format=%H", f"{H}:a.txt"),        # extra options
    ("ls-tree", "-r", "HEAD", "--", "x"),
    ("ls-tree", "-r", H[:10], "--", "x"),
    ("ls-tree", "-r", H, "x"),                    # no `--`
    ("ls-tree", "-r", "--abbrev", H, "--", "x"),  # unlisted flag
    ("ls-tree", "-r", H, "--", ":(glob)x"),       # pathspec magic
    ("log", "--format=%H", H),
    ("log", f"{H}..HEAD"),
    ("cat-file", "-e", f"{H}^{{commit}}"),        # existence can change (prune)
    ("merge-base", "--is-ancestor", H, H),
    ("rev-parse", "-q", "--verify", H),
    ("status", "--porcelain"),
])
def test_not_immutable_shapes(args):
    assert not vl._immutable_args(args)


# --- behaviour ------------------------------------------------------------------------------

def test_ref_call_never_served_from_memo(repo):
    c1 = _commit(repo, "a.txt", "one\n", "c1")
    assert vl._git_out(repo, "show", "HEAD:a.txt") == (0, "one\n")
    assert vl._git_out(repo, "show", f"{c1}:a.txt") == (0, "one\n")
    _commit(repo, "a.txt", "two\n", "c2")
    assert vl._git_out(repo, "show", "HEAD:a.txt") == (0, "two\n")   # not the memoised "one"
    assert vl._git_out(repo, "show", f"{c1}:a.txt") == (0, "one\n")
    assert _rows(repo) == [f"show\0{c1}:a.txt"]                       # only the object-id call


def test_persists_across_restart_without_running_git(repo, git_calls):
    c1 = _commit(repo, "a.txt", "one\n", "c1")
    args = ("ls-tree", "-r", "--name-only", c1, "--", "a.txt")
    assert vl._git_out(repo, "show", f"{c1}:a.txt") == (0, "one\n")
    assert vl._git_out(repo, *args) == (0, "a.txt\n")
    _restart()
    git_calls.clear()
    assert vl._git_out(repo, "show", f"{c1}:a.txt") == (0, "one\n")
    assert vl._git_out(repo, *args) == (0, "a.txt\n")
    assert not [c for c in git_calls if c[0] in ("show", "ls-tree")]


def test_new_commit_keeps_immutable_entries(repo, git_calls):
    c1 = _commit(repo, "a.txt", "one\n", "c1")
    vl._git_out(repo, "show", f"{c1}:a.txt")
    _commit(repo, "b.txt", "x\n", "c2")       # moves HEAD: the ref memo is dropped, this is not
    git_calls.clear()
    assert vl._git_out(repo, "show", f"{c1}:a.txt") == (0, "one\n")
    assert not [c for c in git_calls if c[0] == "show"]


def test_nonzero_exit_never_kept(repo, git_calls):
    c1 = _commit(repo, "a.txt", "one\n", "c1")
    rc, _ = vl._git_out(repo, "show", f"{c1}:missing.txt")
    assert rc != 0
    assert _rows(repo) == []
    git_calls.clear()
    assert vl._git_out(repo, "show", f"{c1}:missing.txt")[0] != 0
    assert ("show", f"{c1}:missing.txt") in git_calls


def test_damaged_row_falls_back_to_git(repo, git_calls):
    c1 = _commit(repo, "a.txt", "one\n", "c1")
    vl._git_out(repo, "show", f"{c1}:a.txt")
    _restart()
    c = sqlite3.connect(str(repo / vl.IMM_MEMO_FILE))
    c.execute("UPDATE memo SET out='forged\n'")
    c.commit()
    c.close()
    git_calls.clear()
    assert vl._git_out(repo, "show", f"{c1}:a.txt") == (0, "one\n")
    assert ("show", f"{c1}:a.txt") in git_calls


def test_corrupt_file_falls_back_and_is_rebuilt(repo, git_calls):
    c1 = _commit(repo, "a.txt", "one\n", "c1")
    vl._git_out(repo, "show", f"{c1}:a.txt")
    _restart()
    for suf in ("-wal", "-shm"):
        p = Path(str(repo / vl.IMM_MEMO_FILE) + suf)
        if p.exists():
            p.unlink()
    (repo / vl.IMM_MEMO_FILE).write_bytes(b"this is not a sqlite database" * 100)
    git_calls.clear()
    assert vl._git_out(repo, "show", f"{c1}:a.txt") == (0, "one\n")
    assert ("show", f"{c1}:a.txt") in git_calls
    assert _rows(repo) == [f"show\0{c1}:a.txt"]           # started again, usable


def test_partial_file_falls_back(repo, git_calls):
    c1 = _commit(repo, "a.txt", "one\n" * 5000, "c1")
    vl._git_out(repo, "show", f"{c1}:a.txt")
    _restart()
    db = repo / vl.IMM_MEMO_FILE
    c = sqlite3.connect(str(db))
    c.execute("PRAGMA wal_checkpoint(TRUNCATE)")
    c.close()
    data = db.read_bytes()
    db.write_bytes(data[: len(data) // 2])                # truncated mid-file
    git_calls.clear()
    assert vl._git_out(repo, "show", f"{c1}:a.txt") == (0, "one\n" * 5000)


def test_replace_ref_changes_the_answer(repo):
    c1 = _commit(repo, "a.txt", "one\n", "c1")
    c2 = _commit(repo, "a.txt", "two\n", "c2")
    assert vl._git_out(repo, "show", f"{c1}:a.txt") == (0, "one\n")
    _git(repo, "replace", c1, c2)
    assert vl._git_out(repo, "show", f"{c1}:a.txt") == (0, "two\n")
    _restart()
    assert vl._git_out(repo, "show", f"{c1}:a.txt") == (0, "two\n")
    _git(repo, "replace", "-d", c1)
    assert vl._git_out(repo, "show", f"{c1}:a.txt") == (0, "one\n")


def test_unlisted_git_env_disables_memo(repo, monkeypatch, git_calls):
    c1 = _commit(repo, "a.txt", "one\n", "c1")
    monkeypatch.setenv("GIT_NO_REPLACE_OBJECTS", "1")
    vl._git_out(repo, "show", f"{c1}:a.txt")
    vl._git_out(repo, "show", f"{c1}:a.txt")
    assert _rows(repo) == []


def test_not_gitignored_means_no_file(repo):
    (repo / ".gitignore").write_text("")
    c1 = _commit(repo, "a.txt", "one\n", "c1")
    assert vl._git_out(repo, "show", f"{c1}:a.txt") == (0, "one\n")
    assert not (repo / vl.IMM_MEMO_FILE).exists()


def test_size_bound_evicts_least_recently_used(repo, monkeypatch):
    monkeypatch.setattr(vl, "IMM_MEMO_MAX_ROWS", 10)
    monkeypatch.setattr(vl, "IMM_MEMO_EVICT_EVERY", 1)
    monkeypatch.setattr(vl, "IMM_MEMO_TOUCH_S", -1)      # every hit refreshes last use
    shas = [_commit(repo, "a.txt", f"v{i}\n", f"c{i}") for i in range(25)]
    t = [1000]
    monkeypatch.setattr(vl.time, "time", lambda: t[0])
    keep = f"show\0{shas[0]}:a.txt"
    for s in shas:
        t[0] += 1
        vl._git_out(repo, "show", f"{s}:a.txt")
        vl._IMM_MEM.clear()
        t[0] += 1
        vl._git_out(repo, "show", f"{shas[0]}:a.txt")    # keep the first one in use
        vl._IMM_MEM.clear()
    rows = _rows(repo)
    assert len(rows) <= 10
    assert keep in rows
    assert f"show\0{shas[1]}:a.txt" not in rows


def test_byte_bound(repo, monkeypatch):
    monkeypatch.setattr(vl, "IMM_MEMO_MAX_BYTES", 4000)
    monkeypatch.setattr(vl, "IMM_MEMO_EVICT_EVERY", 1)
    shas = [_commit(repo, "a.txt", f"{i}" * 1000 + "\n", f"c{i}") for i in range(10)]
    for s in shas:
        vl._git_out(repo, "show", f"{s}:a.txt")
    c = sqlite3.connect(str(repo / vl.IMM_MEMO_FILE))
    total = c.execute("SELECT SUM(size) FROM memo").fetchone()[0]
    c.close()
    assert total <= 4000 + 1002                           # bound plus the row just written


def test_format_version_mismatch_starts_again(repo, monkeypatch, git_calls):
    c1 = _commit(repo, "a.txt", "one\n", "c1")
    vl._git_out(repo, "show", f"{c1}:a.txt")
    _restart()
    monkeypatch.setattr(vl, "IMM_MEMO_VERSION", vl.IMM_MEMO_VERSION + 1)
    git_calls.clear()
    assert vl._git_out(repo, "show", f"{c1}:a.txt") == (0, "one\n")
    assert ("show", f"{c1}:a.txt") in git_calls
