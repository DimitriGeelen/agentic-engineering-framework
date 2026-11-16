"""T-5172 (0909 consult d1993c2c): a project declares extra folders Watchtower links and serves.

The folder list is fixed at import (the linker's regex is built from it), so each test reloads
web.shared with the setting in place, and restores the default afterwards.
"""
import importlib
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))


@pytest.fixture()
def shared_with(monkeypatch, tmp_path_factory):
    import web.shared as shared

    def load(value=None, yaml_value=None, tmp=None):
        # Never read the real repo's .framework.yaml: a project of its own each time.
        tmp = tmp or tmp_path_factory.mktemp("proj")
        (tmp / ".framework.yaml").write_text(
            f"VIEWABLE_DIRS: {yaml_value}\n" if yaml_value is not None else "{}\n")
        monkeypatch.setenv("PROJECT_ROOT", str(tmp))
        monkeypatch.delenv("FW_VIEWABLE_DIRS", raising=False)
        if value is not None:
            monkeypatch.setenv("FW_VIEWABLE_DIRS", value)
        return importlib.reload(shared)
    yield load
    monkeypatch.delenv("FW_VIEWABLE_DIRS", raising=False)
    monkeypatch.undo()
    importlib.reload(shared)


def test_default_declares_nothing(shared_with):
    s = shared_with()
    assert s._declared_viewable_dirs() == ()
    assert not s.is_viewable_path("scripts/x.sh")


def test_env_adds_a_folder_for_route_and_linker(shared_with):
    s = shared_with("scripts, tools/ops")
    assert "scripts/" in s.VIEWABLE_DIR_PREFIXES and "tools/ops/" in s.VIEWABLE_DIR_PREFIXES
    assert s.is_viewable_path("scripts/grub-btrfs-install.sh")
    assert not s.is_viewable_path("scripts/blob.bin")          # extensions still limited
    assert s._ARTEFACT_PATH_RE.search("see scripts/grub-btrfs-install.sh for it")


def test_framework_yaml_is_read(shared_with, tmp_path):
    s = shared_with(yaml_value="scripts", tmp=tmp_path)
    assert s._declared_viewable_dirs(tmp_path) == ("scripts/",)


@pytest.mark.parametrize("bad", ["..", "../etc", "scripts/../..", "/etc", ".git", ".git/hooks",
                                 ".context/secrets", ".context", ".", "./", "/"])
def test_unsafe_entries_are_ignored(shared_with, bad):
    s = shared_with(bad)
    assert s._declared_viewable_dirs() == ()


def test_dot_slash_and_duplicates_normalised(shared_with):
    s = shared_with("./scripts scripts/ scripts")
    assert s._declared_viewable_dirs() == ("scripts/",)


def test_secrets_never_served_even_under_a_declared_parent(shared_with):
    s = shared_with(".context")   # refused: it would contain .context/secrets
    assert not s.is_viewable_path(".context/secrets/key.json")
