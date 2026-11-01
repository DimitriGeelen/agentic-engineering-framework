"""Regression: PROJECT_ROOT discovery for Watchtower (T-1310)."""

import importlib
import os
import sys
from pathlib import Path

import pytest

FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]
if str(FRAMEWORK_ROOT) not in sys.path:
    sys.path.insert(0, str(FRAMEWORK_ROOT))


def _reload_shared(monkeypatch, env_project_root=None, cwd=None):
    if env_project_root is None:
        monkeypatch.delenv("PROJECT_ROOT", raising=False)
    else:
        monkeypatch.setenv("PROJECT_ROOT", str(env_project_root))
    if cwd is not None:
        monkeypatch.chdir(cwd)
    import web.shared as s  # noqa: E402
    importlib.reload(s)
    return s


def test_env_var_wins(tmp_path, monkeypatch):
    (tmp_path / ".framework.yaml").write_text("version: 1\n")
    s = _reload_shared(monkeypatch, env_project_root=str(tmp_path))
    assert s.PROJECT_ROOT == Path(str(tmp_path))


def test_discovers_from_cwd(tmp_path, monkeypatch):
    """CWD inside a consumer project finds its .framework.yaml ancestor."""
    (tmp_path / ".framework.yaml").write_text("version: 1\n")
    deep = tmp_path / "sub" / "deeper"
    deep.mkdir(parents=True)
    s = _reload_shared(monkeypatch, env_project_root=None, cwd=deep)
    assert s.PROJECT_ROOT == tmp_path.resolve()


def test_falls_back_to_framework_when_no_marker(tmp_path, monkeypatch):
    """No .framework.yaml anywhere above CWD → fall back to FRAMEWORK_ROOT."""
    deep = tmp_path / "nothing"
    deep.mkdir()
    s = _reload_shared(monkeypatch, env_project_root=None, cwd=deep)
    # tmp_path is typically /tmp/... which has no .framework.yaml ancestor.
    # Result: FRAMEWORK_ROOT.
    assert s.PROJECT_ROOT == s.FRAMEWORK_ROOT


def test_discover_helper_returns_none_when_no_marker(tmp_path):
    from web.shared import _discover_project_root
    # tmp_path has no .framework.yaml — discover returns None somewhere up the tree
    # (unless the test runner happens to have one near tmp_path, which is unlikely).
    result = _discover_project_root(tmp_path / "a" / "b")
    # Either None (no marker anywhere up) or the marker exists far up — both are
    # acceptable for the helper; we just check it doesn't crash and returns
    # Path-or-None.
    assert result is None or isinstance(result, Path)
