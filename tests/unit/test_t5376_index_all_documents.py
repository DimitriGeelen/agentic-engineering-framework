"""T-5376: every git-tracked project document is indexable by default, wherever
it lives; exclusion is the exception (built-in list + INDEX_EXCLUDE_DIRS).

Hermetic: each test builds its own project under tmp_path. All three retrieval
paths are exercised — the embedding collector (web.search_utils.collect_files),
keyword `fw search`, and the freshness check (vector_index_health._source_drift).
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
WORD = "zqxallword5376"

if shutil.which("git") is None:  # pragma: no cover - git is a framework prerequisite
    pytest.fail("git is required for T-5376 tests")


def _load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


SCOPE = _load("fw_authored_scope", ROOT / "lib" / "authored_scope.py")
VIH = _load("t5376_vector_index_health", ROOT / "lib" / "vector_index_health.py")

INCLUDED = ["design/x.md", "README.md", "notes/y.rst"]
EXCLUDED = [".agentic-framework/z.md", "docs/generated/g.md", "scratch.md"]


def _git(p: Path, *args):
    subprocess.run(["git", "-C", str(p), *args], check=True, capture_output=True,
                   env=dict(os.environ, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@t",
                            GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@t"))


def _write(p: Path, rel: str, text: str = f"The {WORD} document.\n") -> None:
    f = p / rel
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(text)


def _project(tmp_path: Path, git: bool = True, framework_yaml: str = "project_name: t5376\n") -> Path:
    p = tmp_path / "proj"
    p.mkdir()
    (p / ".framework.yaml").write_text(framework_yaml)
    for rel in INCLUDED + EXCLUDED[:2] + ["ci/pipeline.yaml"]:
        _write(p, rel)
    if git:
        _git(p, "init", "-q")
        _git(p, "config", "gc.auto", "0")
        _git(p, "add", "-A")
        _git(p, "commit", "-q", "-m", "init")
    _write(p, "scratch.md")  # untracked
    return p


def _rels(p: Path, files) -> set:
    return {str(Path(f).relative_to(p)) for f in files}


def _env(project: Path, **extra) -> dict:
    env = {k: v for k, v in os.environ.items()
           if not k.startswith("FW_") and k not in ("CLAUDE_PROJECT_DIR", "PROJECT_ROOT")}
    env.update(PROJECT_ROOT=str(project), NO_COLOR="1", **extra)
    return env


def _collect(project: Path, **extra) -> set:
    code = ("import json; from web.search_utils import collect_files; "
            "print(json.dumps(sorted(str(f) for f in collect_files())))")
    r = subprocess.run([sys.executable, "-c", code], cwd=project,
                       env=_env(project, PYTHONPATH=str(ROOT), FW_INDEX_HANDOVERS="0", **extra),
                       capture_output=True, text=True, timeout=120)
    assert r.returncode == 0, r.stderr
    return _rels(project, json.loads(r.stdout))


def _fw_search(project: Path, **extra) -> str:
    r = subprocess.run([str(ROOT / "bin" / "fw"), "search", WORD], cwd=project,
                       env=_env(project, **extra), capture_output=True, text=True, timeout=120)
    assert r.returncode == 0, r.stdout + r.stderr
    return r.stdout


@pytest.fixture(autouse=True)
def _clean_env(monkeypatch):
    for k in ("FW_INDEX_EXCLUDE_DIRS", "FW_INDEX_EXTRA_DIRS"):
        monkeypatch.delenv(k, raising=False)


# ── the rule ──────────────────────────────────────────────────────────────────

def test_git_project_includes_documents_anywhere_and_excludes_the_list(tmp_path):
    p = _project(tmp_path)
    got = _rels(p, SCOPE.indexable_files(p))
    for rel in INCLUDED:
        assert rel in got, (rel, got)
    for rel in EXCLUDED:
        assert rel not in got, (rel, got)
    assert "ci/pipeline.yaml" not in got  # YAML outside framework-state dirs is config


def test_collect_files_uses_the_rule(tmp_path):
    p = _project(tmp_path)
    got = _collect(p)
    assert set(INCLUDED) <= got
    assert not (set(EXCLUDED) & got)


def test_exclude_key_removes_a_dir_from_all_three_paths(tmp_path, monkeypatch):
    p = _project(tmp_path, framework_yaml="project_name: t5376\nINDEX_EXCLUDE_DIRS: design\n")
    assert "design/x.md" not in _rels(p, SCOPE.indexable_files(p))
    assert "design/x.md" not in _collect(p)
    assert "design/x.md" not in _fw_search(p)
    assert VIH._source_drift(p, {}) == 2  # README.md, notes/y.rst
    monkeypatch.setenv("FW_INDEX_EXCLUDE_DIRS", "notes, /abs:../up")  # env wins over yaml
    got = _rels(p, SCOPE.indexable_files(p))
    assert "notes/y.rst" not in got and "design/x.md" in got
    assert SCOPE.exclude_dirs(p) == (("notes",),)


def test_extra_dirs_cannot_readmit_an_excluded_dir(tmp_path, monkeypatch):
    p = _project(tmp_path)
    monkeypatch.setenv("FW_INDEX_EXTRA_DIRS", ".agentic-framework:untracked")
    _write(p, "untracked/u.md")
    got = _rels(p, SCOPE.indexable_files(p))
    assert ".agentic-framework/z.md" not in got
    assert "untracked/u.md" in got  # INDEX_EXTRA_DIRS still adds untracked content


def test_non_git_project_falls_back_to_authored_dirs(tmp_path):
    p = _project(tmp_path, git=False)
    _write(p, "docs/design/d.md")
    got = _rels(p, SCOPE.indexable_files(p))
    assert "docs/design/d.md" in got and "README.md" in got and "scratch.md" in got
    assert "design/x.md" not in got and "notes/y.rst" not in got


# ── keyword search and freshness ──────────────────────────────────────────────

def test_keyword_search_finds_documents_anywhere(tmp_path):
    p = _project(tmp_path)
    out = _fw_search(p)
    assert "design/x.md" in out and "notes/y.rst" in out, out
    assert ".agentic-framework" not in out and "docs/generated" not in out, out


def _state(p: Path, rels) -> dict:
    return {r: (hashlib.sha256((p / r).read_text().encode()).hexdigest(),) for r in rels}


def test_freshness_counts_new_and_deleted_documents_anywhere(tmp_path):
    p = _project(tmp_path)
    assert VIH._source_drift(p, {}) == 3
    assert VIH._source_drift(p, _state(p, INCLUDED)) == 0
    state = _state(p, INCLUDED)
    (p / "design" / "x.md").unlink()
    assert VIH._source_drift(p, state) == 1
