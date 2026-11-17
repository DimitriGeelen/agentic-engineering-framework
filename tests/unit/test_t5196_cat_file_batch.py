"""T-5196: `git show <40-hex>:<path>` served by one long-lived `git cat-file --batch` reader.

Every answer must be identical to the per-call `git show` it replaces (same (rc, stdout) as
subprocess.run(..., text=True)), including failures, and the reader must never leak a process.
"""
from __future__ import annotations

import os
import subprocess
import sys
import threading
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from lib import verdict_ledger as vl  # noqa: E402


def git(repo: Path, *args: str, **kw) -> str:
    return subprocess.run(["git", *args], cwd=repo, check=True, capture_output=True,
                          text=True, **kw).stdout


def old_show(repo: Path, spec: str):
    cp = subprocess.run(["git", "show", spec], cwd=repo, capture_output=True, text=True, timeout=60)
    return cp.returncode, cp.stdout


FILES = {
    "plain.txt": b"hello\nworld\n",
    "crlf.txt": b"a\r\nb\rc\n",
    "empty.txt": b"",
    "no-newline.txt": b"tail",
    "dir with space/f i l e.md": b"spaced\n",
    "déjà/日本.txt": "café ☃\n".encode(),
    "large.txt": (b"0123456789abcdef" * 4096 + b"\n") * 40,     # ~2.6 MB, far over a pipe buffer
    "bin.dat": bytes(range(256)) * 4,                              # not valid UTF-8
}


@pytest.fixture()
def repo(tmp_path: Path):
    r = tmp_path / "repo"
    r.mkdir()
    git(r, "init", "-q")
    git(r, "config", "user.email", "t@example.invalid")
    git(r, "config", "user.name", "t")
    for rel, data in FILES.items():
        p = r / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(data)
    (r / ".gitattributes").write_text("*.txt diff=up\n")
    git(r, "config", "diff.up.textconv", "tr a-z A-Z")
    git(r, "add", "-A")
    git(r, "commit", "-qm", "c1")
    yield r
    vl._catfile_shutdown()
    vl._GIT_MEMO.clear()


def head(repo: Path) -> str:
    return git(repo, "rev-parse", "HEAD").strip()


def served(repo: Path, spec: str):
    tok = vl._git_state_token(repo)
    assert tok is not None
    return vl._catfile_show(repo, spec, tok)


@pytest.mark.parametrize("rel", [k for k in FILES if k != "bin.dat"])
def test_text_blobs_identical_to_git_show(repo, rel):
    spec = f"{head(repo)}:{rel}"
    got = served(repo, spec)
    assert got is not None, "the reader must serve a text blob"
    assert got == old_show(repo, spec)
    vl._GIT_MEMO.clear()
    assert vl._git_out(repo, "show", spec) == old_show(repo, spec)


def test_textconv_not_applied_like_git_show(repo):
    spec = f"{head(repo)}:plain.txt"
    assert old_show(repo, spec)[1] == "hello\nworld\n"      # git show ignores the textconv driver
    assert served(repo, spec) == (0, "hello\nworld\n")


def test_binary_not_utf8_falls_back_and_matches(repo):
    spec = f"{head(repo)}:bin.dat"
    assert served(repo, spec) is None                         # decode fails -> per-call path
    with pytest.raises(UnicodeDecodeError):
        old_show(repo, spec)
    with pytest.raises(UnicodeDecodeError):
        vl._git_out(repo, "show", spec)


@pytest.mark.parametrize("rel", ["nope.txt", "dir with space"])
def test_missing_or_tree_takes_the_old_path(repo, rel):
    spec = f"{head(repo)}:{rel}"
    assert served(repo, spec) is None
    vl._GIT_MEMO.clear()
    assert vl._git_out(repo, "show", spec) == old_show(repo, spec)


def test_missing_commit_same_failure(repo):
    spec = "0" * 40 + ":plain.txt"
    assert served(repo, spec) is None
    rc, out = vl._git_out(repo, "show", spec)
    assert (rc, out) == old_show(repo, spec) and rc != 0
    assert repr(("show", spec)) not in repr(vl._GIT_MEMO)     # a failure is never memoised


def test_non_40hex_or_relative_specs_not_routed(repo, monkeypatch):
    calls = []
    monkeypatch.setattr(vl, "_catfile_show", lambda *a: calls.append(a))
    h = head(repo)
    for spec in ("HEAD:plain.txt", f"{h[:12]}:plain.txt", f"{h}:./plain.txt", f"{h}:../x"):
        vl._git_out(repo, "show", spec)
    assert calls == []
    vl._GIT_MEMO.clear()
    vl._git_out(repo, "show", f"{h}:plain.txt")
    assert len(calls) == 1


def test_replace_ref_honoured_like_git_show(repo):
    c1 = head(repo)
    (repo / "plain.txt").write_text("replaced\n")
    git(repo, "commit", "-qam", "c2")
    c2 = head(repo)
    spec = f"{c1}:plain.txt"
    assert served(repo, spec) == (0, "hello\nworld\n")        # reader started before the replace
    git(repo, "replace", c1, c2)
    assert old_show(repo, spec) == (0, "replaced\n")
    assert served(repo, spec) == old_show(repo, spec)        # restarted: refs/replace moved
    env = dict(os.environ, GIT_NO_REPLACE_OBJECTS="1")
    os.environ["GIT_NO_REPLACE_OBJECTS"] = "1"
    try:
        want = subprocess.run(["git", "show", spec], cwd=repo, capture_output=True,
                              text=True, env=env).stdout
        assert want == "hello\nworld\n"
        assert served(repo, spec) == (0, want)               # restarted: env changed
    finally:
        del os.environ["GIT_NO_REPLACE_OBJECTS"]


def test_one_reader_per_repo_and_concurrent_threads(repo):
    h = head(repo)
    specs = [f"{h}:{k}" for k in FILES if k != "bin.dat"]
    want = {s: old_show(repo, s) for s in specs}
    tok = vl._git_state_token(repo)
    errors = []

    def worker(i):
        for j in range(40):
            s = specs[(i + j) % len(specs)]
            got = vl._catfile_show(repo, s, tok)
            if got != want[s]:
                errors.append((s, got and got[1][:20]))

    ts = [threading.Thread(target=worker, args=(i,)) for i in range(8)]
    for t in ts:
        t.start()
    for t in ts:
        t.join()
    assert errors == []
    assert list(vl._CATFILE) == [str(repo)]


def test_reader_killed_mid_run_recovers(repo):
    spec = f"{head(repo)}:plain.txt"
    assert served(repo, spec) == old_show(repo, spec)
    rd = vl._CATFILE[str(repo)]
    rd.proc.kill()
    rd.proc.wait()
    assert vl._git_out(repo, "show", spec) == old_show(repo, spec)   # this call: fallback
    assert served(repo, spec) == old_show(repo, spec)                # next call: new reader
    assert vl._CATFILE[str(repo)] is not rd


def test_desync_closes_reader_and_falls_back(repo, monkeypatch):
    spec = f"{head(repo)}:plain.txt"
    served(repo, spec)
    rd = vl._CATFILE[str(repo)]
    rd.buf += b"garbage that is not a header\n"
    assert served(repo, spec) is None
    assert rd.proc is None and vl._CATFILE.get(str(repo)) is not rd
    assert served(repo, spec) == old_show(repo, spec)


def test_no_process_left_after_shutdown(repo):
    spec = f"{head(repo)}:plain.txt"
    served(repo, spec)
    p = vl._CATFILE[str(repo)].proc
    pid = p.pid
    vl._catfile_shutdown()
    assert p.returncode is not None                           # reaped, not a zombie
    assert not Path(f"/proc/{pid}").exists() or "git" not in Path(f"/proc/{pid}/cmdline").read_text(errors="replace")
    assert vl._CATFILE == {}


def test_interpreter_exit_leaves_no_reader(repo, tmp_path):
    code = (
        "import sys; sys.path.insert(0, %r)\n"
        "from lib import verdict_ledger as vl\n"
        "from pathlib import Path\n"
        "r = Path(%r)\n"
        "print(vl._git_out(r, 'show', %r)[1], end='')\n"
        "print('PID', vl._CATFILE[str(r)].proc.pid)\n"
    ) % (str(ROOT), str(repo), f"{head(repo)}:plain.txt")
    out = subprocess.run([sys.executable, "-c", code], capture_output=True, text=True,
                         timeout=60).stdout
    assert out.startswith("hello\nworld\n")
    pid = int(out.split("PID")[1])
    alive = Path(f"/proc/{pid}").exists() and "cat-file" in Path(f"/proc/{pid}/cmdline").read_text(errors="replace")
    assert not alive


def test_new_commit_restarts_reader(repo):
    spec = f"{head(repo)}:plain.txt"
    served(repo, spec)
    rd = vl._CATFILE[str(repo)]
    (repo / "plain.txt").write_text("v2\n")
    git(repo, "commit", "-qam", "c2")
    spec2 = f"{head(repo)}:plain.txt"
    assert served(repo, spec2) == (0, "v2\n")
    assert rd.proc is None and vl._CATFILE[str(repo)] is not rd


def test_an_interruption_after_the_write_never_shifts_later_answers(repo, monkeypatch):
    # T-5196 review #1: a BaseException raised inside request() after the write used to leave the
    # response unread, so the next request got the previous request's blob (off by one, forever).
    sha = head(repo)
    served(repo, f"{sha}:plain.txt")
    real_fill = vl._CatFileBatch._fill
    calls = {"n": 0}

    def interrupted_fill(self, deadline):
        calls["n"] += 1
        if calls["n"] == 1:
            raise KeyboardInterrupt
        return real_fill(self, deadline)

    monkeypatch.setattr(vl._CatFileBatch, "_fill", interrupted_fill)
    with pytest.raises(KeyboardInterrupt):
        served(repo, f"{sha}:empty.txt")
    monkeypatch.setattr(vl._CatFileBatch, "_fill", real_fill)
    spec = f"{sha}:crlf.txt"
    assert served(repo, spec) == old_show(repo, spec)


def test_a_path_containing_dotdot_is_not_routed(repo, monkeypatch):
    # T-5196 review #2: `git show <sha>:a..HEAD` can be a range; the reader must not answer it
    sha = head(repo)
    assert not vl._SHOW_SPEC.fullmatch(f"{sha}:a..HEAD")
    assert not vl._SHOW_SPEC.fullmatch(f"{sha}:dir/x..y")
    assert vl._SHOW_SPEC.fullmatch(f"{sha}:dir/x.y")


def test_a_global_config_change_restarts_the_reader(repo, tmp_path, monkeypatch):
    # T-5196 review #3: core.useReplaceRefs in the global config changes a blob's bytes
    home = tmp_path / "home"
    home.mkdir()
    monkeypatch.setenv("HOME", str(home))
    tok = vl._git_state_token(repo)
    k1 = vl._catfile_key(repo, tok)
    (home / ".gitconfig").write_text("[core]\n\tuseReplaceRefs = false\n")
    assert vl._catfile_key(repo, tok) != k1
