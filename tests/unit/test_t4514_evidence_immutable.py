"""T-4514 — a later judge run must leave an earlier run's committed evidence intact.

2026-10-20, T-4475: run 1's worker cited `config@1024.png`, copied into the shared evidence
directory under the bare name and committed. Run 2's worker put its own copy under the same name,
then renamed it to a `-<dispatch>` name, so run 1's committed file was deleted from the shared checkout.
The ledger audit failed ("evidence path does not exist") and blocked every push.
`_commit_rows` is the one commit path for every verdict row; it now restores committed evidence
from HEAD before it commits, so a move is a copy.
"""
import subprocess
import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_HERE))

from lib import verdict_ledger as vl  # noqa: E402

RUN1 = b"\x89PNG run-1 bytes"


def _git(root, *a):
    return subprocess.run(["git", *a], cwd=root, capture_output=True, text=True, check=True).stdout


def _repo(tmp_path):
    root = tmp_path / "proj"
    root.mkdir()
    _git(root, "init", "-q")
    _git(root, "config", "user.email", "t@t")
    _git(root, "config", "user.name", "t")
    (root / ".gitignore").write_text("*.png\n")
    _git(root, "add", ".gitignore")
    _git(root, "commit", "-qm", "init")
    return root


def _first_run(root):
    """Run 1: cites the bare-named copy and commits it with its row."""
    d = root / vl.REPORT_DIR / "T-1"
    d.mkdir(parents=True)
    (d / "config@1024.png").write_bytes(RUN1)
    (d / "AC1-run1.md").write_text("run 1 report\n")
    (root / vl.VERDICTS).write_text('{"id": "V-1"}\n')
    rels = [str((d / n).relative_to(root)) for n in ("config@1024.png", "AC1-run1.md")]
    sha, err = vl._commit_rows(root, vl._ledger_paths(root, rels), "run1", "T-1: reviewer verdict")
    assert err == "" and sha
    return d


def test_second_run_moving_the_first_runs_evidence_leaves_it_intact(tmp_path):
    root = _repo(tmp_path)
    d = _first_run(root)
    # Run 2, the T-4475 sequence: copy under the bare name (overwriting), then rename to its own.
    (d / "config@1024.png").write_bytes(b"\x89PNG run-2 bytes")
    (d / "config@1024.png").rename(d / "config@1024-run2.png")
    (d / "AC1-run2.md").write_text("run 2 report\n")
    with (root / vl.VERDICTS).open("a") as fh:
        fh.write('{"id": "V-2"}\n')
    rels = [str((d / n).relative_to(root)) for n in ("config@1024-run2.png", "AC1-run2.md")]
    sha, err = vl._commit_rows(root, vl._ledger_paths(root, rels), "run2", "T-1: reviewer verdict")
    assert err == "" and sha
    # Run 1's cited evidence: on disk, byte-identical, and still committed at HEAD.
    assert (d / "config@1024.png").read_bytes() == RUN1
    rel1 = str((d / "config@1024.png").relative_to(root))
    assert _git(root, "status", "--porcelain", "--", rel1) == ""
    assert rel1 in _git(root, "ls-tree", "-r", "--name-only", "HEAD").split()
    # Run 2's own copy is committed alongside its row.
    files = set(_git(root, "show", "--name-only", "--format=", "HEAD").split())
    assert str((d / "config@1024-run2.png").relative_to(root)) in files
    assert rel1 not in files


def test_a_modified_committed_report_is_restored(tmp_path):
    root = _repo(tmp_path)
    d = _first_run(root)
    (d / "AC1-run1.md").write_text("rewritten by someone else\n")
    with (root / vl.VERDICTS).open("a") as fh:
        fh.write('{"id": "V-2"}\n')
    sha, err = vl._commit_rows(root, vl._ledger_paths(root, []), "run2", "T-1: reviewer verdict")
    assert err == "" and sha
    assert (d / "AC1-run1.md").read_text() == "run 1 report\n"


def test_control_uncommitted_evidence_of_another_worker_is_left_alone(tmp_path):
    """Only files committed at HEAD are restored; a worker's in-flight new file is not touched."""
    root = _repo(tmp_path)
    d = _first_run(root)
    (d / "AC1-inflight.md").write_text("another worker, not yet committed\n")
    with (root / vl.VERDICTS).open("a") as fh:
        fh.write('{"id": "V-2"}\n')
    sha, err = vl._commit_rows(root, vl._ledger_paths(root, []), "run2", "T-1: reviewer verdict")
    assert err == "" and sha
    assert (d / "AC1-inflight.md").read_text() == "another worker, not yet committed\n"
