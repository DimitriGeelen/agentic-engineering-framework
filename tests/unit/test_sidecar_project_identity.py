"""T-3671: sidecar identity comes from the consumer project, not the vendored dir."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from lib.sidecar import circuit, outbox  # noqa: E402


@pytest.fixture
def vendored(tmp_path, monkeypatch):
    proj = tmp_path / "my-proj"
    fw = proj / ".agentic-framework"
    fw.mkdir(parents=True)
    (proj / ".framework.yaml").write_text("project_name: my-proj\n")
    monkeypatch.setenv("FRAMEWORK_ROOT", str(fw))
    monkeypatch.delenv("FW_SIDECAR_AGENT_ID", raising=False)
    return proj, fw


def test_project_root_env_wins(vendored, monkeypatch):
    proj, _ = vendored
    monkeypatch.setenv("PROJECT_ROOT", str(proj))
    assert circuit.project_id() == "my-proj"
    assert circuit.agent_name() == "my-proj"
    assert outbox._ledger_path().parent == proj / ".context" / "sidecar"


def test_walk_up_from_cwd(vendored, monkeypatch):
    proj, _ = vendored
    monkeypatch.delenv("PROJECT_ROOT", raising=False)
    sub = proj / "src" / "deep"
    sub.mkdir(parents=True)
    monkeypatch.chdir(sub)
    assert circuit.project_id() == "my-proj"


def test_state_not_inside_vendored_dir(vendored, monkeypatch):
    proj, fw = vendored
    monkeypatch.setenv("PROJECT_ROOT", str(proj))
    outbox._outbox_dir()
    assert not (fw / ".context").exists()


def test_refuses_vendored_dir_id(tmp_path, monkeypatch):
    bad = tmp_path / ".agentic-framework"
    bad.mkdir()
    monkeypatch.setenv("PROJECT_ROOT", str(bad))
    with pytest.raises(circuit.CircuitError, match="vendored framework dir"):
        circuit.project_id()


def test_refuses_empty_id(monkeypatch):
    monkeypatch.setenv("PROJECT_ROOT", "/")
    with pytest.raises(circuit.CircuitError):
        circuit.project_id()


def test_fallback_strips_vendored_dir(vendored, monkeypatch, tmp_path):
    _, fw = vendored
    monkeypatch.delenv("PROJECT_ROOT", raising=False)
    monkeypatch.chdir(tmp_path)
    monkeypatch.setattr(outbox, "_is_project_root", lambda d: False)
    assert outbox._root() == fw.parent
