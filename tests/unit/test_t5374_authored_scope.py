"""T-5374: one definition of authored content drives keyword search, the
embedding index and the index freshness check, plus INDEX_EXTRA_DIRS.

Hermetic: every test builds its own project in tmp_path; nothing reads the
live corpus.
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WORD = "zqxreasonerword5374"


def _load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


SCOPE = _load("fw_authored_scope", ROOT / "lib" / "authored_scope.py")
VIH = _load("t5374_vector_index_health", ROOT / "lib" / "vector_index_health.py")


def _project(tmp_path: Path, framework_yaml: str = "project_name: t5374\n") -> Path:
    p = tmp_path / "proj"
    (p / ".tasks" / "active").mkdir(parents=True)
    (p / ".context" / "episodic").mkdir(parents=True)
    (p / "docs" / "design").mkdir(parents=True)
    (p / "docs" / "design" / "x.md").write_text(f"# Design\n\nThe {WORD} module.\n")
    (p / "docs" / "generated").mkdir(parents=True)
    (p / "docs" / "generated" / "g.md").write_text(f"generated {WORD}\n")
    (p / "notes").mkdir()
    (p / "notes" / "n.md").write_text(f"custom {WORD}\n")
    (p / ".framework.yaml").write_text(framework_yaml)
    return p


def _env(project: Path, **extra) -> dict:
    env = {k: v for k, v in os.environ.items()
           if not k.startswith("FW_") and k not in ("CLAUDE_PROJECT_DIR", "PROJECT_ROOT")}
    env.update(PROJECT_ROOT=str(project), NO_COLOR="1", **extra)
    return env


def _fw_search(project: Path, **extra) -> str:
    r = subprocess.run([str(ROOT / "bin" / "fw"), "search", WORD], cwd=project,
                       env=_env(project, **extra), capture_output=True, text=True, timeout=120)
    assert r.returncode == 0, r.stdout + r.stderr
    return r.stdout


def _collect(project: Path, **extra) -> list:
    code = ("import json; from web.search_utils import collect_files; "
            "print(json.dumps(sorted(str(f) for f in collect_files())))")
    r = subprocess.run([sys.executable, "-c", code], cwd=project,
                       env=_env(project, PYTHONPATH=str(ROOT), FW_INDEX_HANDOVERS="0", **extra),
                       capture_output=True, text=True, timeout=120)
    assert r.returncode == 0, r.stderr
    return [str(Path(f).relative_to(project)) for f in json.loads(r.stdout)]


# ── one definition ──────────────────────────────────────────────────────────

def test_search_utils_reexports_the_shared_definition():
    code = ("import sys; from web import search_utils as S; "
            "m = sys.modules['fw_authored_scope']; "
            "assert S.AUTHORED_DIRS is m.AUTHORED_DIRS and S.EXCLUDED_DIRS is m.EXCLUDED_DIRS; "
            "assert ('docs', 'design') in S.AUTHORED_DIRS; print('ok')")
    r = subprocess.run([sys.executable, "-c", code], cwd=ROOT,
                       env=dict(os.environ, PYTHONPATH=str(ROOT)),
                       capture_output=True, text=True, timeout=120)
    assert r.stdout.strip() == "ok", r.stderr


def test_freshness_scope_is_the_authored_set():
    assert VIH.DRIFT_DIRS == SCOPE.AUTHORED_DIRS
    assert ("docs", "design") in VIH.DRIFT_DIRS


# ── keyword fw search ─────────────────────────────────────────────────────────

def test_keyword_search_finds_design_doc_and_skips_generated(tmp_path):
    p = _project(tmp_path)
    out = _fw_search(p)
    assert "docs/design/x.md" in out, out
    assert "docs/generated" not in out, out
    assert "notes/n.md" not in out, out  # not authored until declared


def test_keyword_search_honours_extra_dirs(tmp_path):
    p = _project(tmp_path, "project_name: t5374\nINDEX_EXTRA_DIRS: notes\n")
    assert "notes/n.md" in _fw_search(p)


# ── freshness check ───────────────────────────────────────────────────────────

def _state_for(project: Path, rels) -> dict:
    return {r: (hashlib.sha256((project / r).read_text().encode()).hexdigest(),)
            for r in rels}


def test_unindexed_design_doc_counts_as_drift(tmp_path):
    p = _project(tmp_path)
    assert VIH._source_drift(p, {}) == 1  # docs/design/x.md; generated + notes out
    assert VIH._source_drift(p, _state_for(p, ["docs/design/x.md"])) == 0


def test_deleted_design_doc_still_served_counts_as_drift(tmp_path):
    p = _project(tmp_path)
    state = _state_for(p, ["docs/design/x.md"])
    (p / "docs" / "design" / "x.md").unlink()
    assert VIH._source_drift(p, state) == 1


def test_extra_dir_counts_in_freshness_check(tmp_path, monkeypatch):
    p = _project(tmp_path)
    monkeypatch.setenv("FW_INDEX_EXTRA_DIRS", "notes")
    assert VIH._source_drift(p, _state_for(p, ["docs/design/x.md"])) == 1
    assert VIH._source_drift(p, _state_for(p, ["docs/design/x.md", "notes/n.md"])) == 0


# ── embedding index ───────────────────────────────────────────────────────────

def test_index_collects_design_doc_and_extra_dir(tmp_path):
    p = _project(tmp_path)
    files = _collect(p)
    assert "docs/design/x.md" in files
    assert "notes/n.md" not in files
    assert not any(f.startswith("docs/generated") for f in files)
    assert "notes/n.md" in _collect(p, FW_INDEX_EXTRA_DIRS="notes")


# ── the config key ────────────────────────────────────────────────────────────

def test_extra_dirs_default_empty_and_sanitised(tmp_path, monkeypatch):
    p = _project(tmp_path)
    monkeypatch.delenv("FW_INDEX_EXTRA_DIRS", raising=False)
    assert SCOPE.extra_dirs(p) == ()
    assert SCOPE.authored_dirs(p) == SCOPE.AUTHORED_DIRS
    monkeypatch.setenv("FW_INDEX_EXTRA_DIRS",
                       "notes, /etc:../up:a/../b:.git:docs/generated/x:docs/design:./wiki/")
    assert SCOPE.extra_dirs(p) == (("notes",), ("wiki",))


def test_env_overrides_framework_yaml(tmp_path, monkeypatch):
    p = _project(tmp_path, "INDEX_EXTRA_DIRS: \"notes\"\n")
    monkeypatch.delenv("FW_INDEX_EXTRA_DIRS", raising=False)
    assert SCOPE.extra_dirs(p) == (("notes",),)
    monkeypatch.setenv("FW_INDEX_EXTRA_DIRS", "wiki")
    assert SCOPE.extra_dirs(p) == (("wiki",),)


def test_config_key_registered():
    assert '"INDEX_EXTRA_DIRS||' in (ROOT / "lib" / "config.sh").read_text()
    assert '("INDEX_EXTRA_DIRS", ""' in (ROOT / "web" / "blueprints" / "config.py").read_text()
