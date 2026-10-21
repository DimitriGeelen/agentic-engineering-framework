"""T-4526: a process that built a search index removes it when it exits.

Origin: every exited Watchtower / test process left its last
fw-search-index-<pid>-* generation in /tmp until another process happened to
build an index in the same parent dir — about 1 GB of them on the shared host.
"""
from __future__ import annotations

import subprocess
import sys
import textwrap
from pathlib import Path

import pytest

pytest.importorskip("tantivy")

ROOT = Path(__file__).resolve().parent.parent.parent

CHILD = textwrap.dedent("""
    import sys
    from pathlib import Path
    sys.path.insert(0, sys.argv[1])
    import web.search as s
    parent, corpus = Path(sys.argv[2]), Path(sys.argv[3])
    files = sorted(corpus.glob("*.md"))
    s.INDEX_PARENT = parent
    s.PROJECT_ROOT = corpus
    s.collect_files = lambda: list(files)
    s.build_index()
    s.build_index()   # second generation: the first is now a retired dir
    assert s.search("release")["total_hits"] > 0
    print(len(list(parent.iterdir())))
""")


def _corpus(tmp_path: Path) -> tuple[Path, Path]:
    corpus = tmp_path / "proj"
    corpus.mkdir()
    for i in range(5):
        (corpus / f"doc{i}.md").write_text(f"# Doc {i}\n\nrelease note {i}\n")
    parent = tmp_path / "idx"
    parent.mkdir()
    return parent, corpus


def test_index_dirs_removed_on_normal_exit(tmp_path):
    parent, corpus = _corpus(tmp_path)
    r = subprocess.run([sys.executable, "-c", CHILD, str(ROOT), str(parent), str(corpus)],
                       capture_output=True, text=True, timeout=120)
    assert r.returncode == 0, r.stderr
    assert int(r.stdout.strip().splitlines()[-1]) >= 1   # dirs existed while it ran
    assert list(parent.iterdir()) == []


def test_exit_cleanup_leaves_other_processes_dirs(tmp_path):
    parent, corpus = _corpus(tmp_path)
    other = parent / "fw-search-index-1-keepme"
    other.mkdir()
    r = subprocess.run([sys.executable, "-c", CHILD, str(ROOT), str(parent), str(corpus)],
                       capture_output=True, text=True, timeout=120)
    assert r.returncode == 0, r.stderr
    assert [p.name for p in parent.iterdir()] == ["fw-search-index-1-keepme"]
