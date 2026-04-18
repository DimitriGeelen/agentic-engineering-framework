"""Regression tests for Flask secret_key persistence (T-1302/T-1306).

Verifies the three-source resolver: env > file > generate+persist.
"""

import os
import sys
import tempfile
from pathlib import Path

import pytest

FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]
if str(FRAMEWORK_ROOT) not in sys.path:
    sys.path.insert(0, str(FRAMEWORK_ROOT))


def _fresh_project(tmp_path: Path) -> Path:
    """Create a minimal project layout (.context/working/) in a tmp dir."""
    (tmp_path / ".context" / "working").mkdir(parents=True, exist_ok=True)
    return tmp_path


def test_generated_key_stable_across_invocations(tmp_path, monkeypatch):
    """The regression: two create_app() calls must yield the same secret_key."""
    monkeypatch.delenv("FW_SECRET_KEY", raising=False)
    monkeypatch.setenv("PROJECT_ROOT", str(_fresh_project(tmp_path)))
    # Reset cached Config and reload web.app so PROJECT_ROOT is re-read.
    for mod in ("web.app", "web.config", "web.shared"):
        sys.modules.pop(mod, None)
    from web.app import create_app  # noqa: E402
    a = create_app()
    b = create_app()
    assert a.secret_key == b.secret_key
    assert len(a.secret_key) == 64  # 32 bytes hex


def test_persisted_file_has_secure_permissions(tmp_path, monkeypatch):
    monkeypatch.delenv("FW_SECRET_KEY", raising=False)
    monkeypatch.setenv("PROJECT_ROOT", str(_fresh_project(tmp_path)))
    for mod in ("web.app", "web.config", "web.shared"):
        sys.modules.pop(mod, None)
    from web.app import create_app  # noqa: E402
    create_app()
    key_file = tmp_path / ".context" / "working" / ".fw-secret-key"
    assert key_file.is_file()
    mode = os.stat(key_file).st_mode & 0o777
    assert mode == 0o600, f"expected 0o600, got {oct(mode)}"


def test_env_var_wins_over_file(tmp_path, monkeypatch):
    monkeypatch.setenv("FW_SECRET_KEY", "from-env-wins")
    monkeypatch.setenv("PROJECT_ROOT", str(_fresh_project(tmp_path)))
    # Pre-seed a file with a different value to prove env wins.
    key_file = tmp_path / ".context" / "working" / ".fw-secret-key"
    key_file.write_text("from-file-should-lose")
    for mod in ("web.app", "web.config", "web.shared"):
        sys.modules.pop(mod, None)
    from web.app import create_app  # noqa: E402
    app = create_app()
    assert app.secret_key == "from-env-wins"


def test_file_wins_over_generation(tmp_path, monkeypatch):
    monkeypatch.delenv("FW_SECRET_KEY", raising=False)
    monkeypatch.setenv("PROJECT_ROOT", str(_fresh_project(tmp_path)))
    # Pre-seed a file; app must load it, not regenerate.
    key_file = tmp_path / ".context" / "working" / ".fw-secret-key"
    key_file.write_text("preseeded-stable-key")
    for mod in ("web.app", "web.config", "web.shared"):
        sys.modules.pop(mod, None)
    from web.app import create_app  # noqa: E402
    app = create_app()
    assert app.secret_key == "preseeded-stable-key"
