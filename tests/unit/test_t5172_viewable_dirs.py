"""T-5172 (0909 consult d1993c2c): a project declares extra folders Watchtower links and serves.

The folder list is merged at import (the linker's regex is built from it). These tests never
reload web.shared in-process (that left other test files holding stale objects): the settings
reader is called directly, route and linker are checked with the list patched, and the
import-time merge is checked in a fresh interpreter.
"""
import os
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

import web.shared as shared  # noqa: E402


@pytest.fixture()
def project(tmp_path, monkeypatch):
    """An empty project of its own: never the real repo's .framework.yaml."""
    monkeypatch.delenv("FW_VIEWABLE_DIRS", raising=False)
    (tmp_path / ".framework.yaml").write_text("{}\n")
    return tmp_path


def _declared(project, monkeypatch, env=None, yaml_value=None):
    if yaml_value is not None:
        (project / ".framework.yaml").write_text(f"VIEWABLE_DIRS: {yaml_value}\n")
    if env is not None:
        monkeypatch.setenv("FW_VIEWABLE_DIRS", env)
    return shared._declared_viewable_dirs(project)


def test_default_declares_nothing(project, monkeypatch):
    assert _declared(project, monkeypatch) == ()


def test_env_and_yaml(project, monkeypatch):
    assert _declared(project, monkeypatch, yaml_value="scripts") == ("scripts/",)
    assert _declared(project, monkeypatch, env="scripts, tools/ops") == ("scripts/", "tools/ops/")


@pytest.mark.parametrize("bad", ["..", "../etc", "scripts/../..", "/etc", ".git", ".git/hooks",
                                 ".context/secrets", ".context", ".", "./", "/"])
def test_unsafe_entries_are_ignored(project, monkeypatch, bad):
    assert _declared(project, monkeypatch, env=bad) == ()


def test_dot_slash_and_duplicates_normalised(project, monkeypatch):
    assert _declared(project, monkeypatch, env="./scripts scripts/ scripts") == ("scripts/",)


def test_route_and_linker_with_a_declared_folder(monkeypatch):
    monkeypatch.setattr(shared, "VIEWABLE_DIR_PREFIXES", shared.VIEWABLE_DIR_PREFIXES + ("scripts/",))
    monkeypatch.setattr(shared, "_ARTEFACT_PATH_RE", shared._build_artefact_path_re())
    assert shared.is_viewable_path("scripts/grub-btrfs-install.sh")
    assert not shared.is_viewable_path("scripts/blob.bin")          # extensions still limited
    assert shared._ARTEFACT_PATH_RE.search("see scripts/grub-btrfs-install.sh for it")
    assert not shared.is_viewable_path(".context/secrets/key.json")


def test_import_merges_the_declared_folders(project):
    code = ("import web.shared as s; print('scripts/' in s.VIEWABLE_DIR_PREFIXES, "
            "s.is_viewable_path('scripts/x.sh'))")
    env = {**os.environ, "PROJECT_ROOT": str(project), "FW_VIEWABLE_DIRS": "scripts"}
    out = subprocess.run([sys.executable, "-c", code], cwd=str(ROOT), env=env,
                         capture_output=True, text=True, timeout=120)
    assert out.stdout.strip() == "True True", out.stderr[-500:]
    env.pop("FW_VIEWABLE_DIRS")
    out = subprocess.run([sys.executable, "-c", code], cwd=str(ROOT), env=env,
                         capture_output=True, text=True, timeout=120)
    assert out.stdout.strip() == "False False", out.stderr[-500:]
