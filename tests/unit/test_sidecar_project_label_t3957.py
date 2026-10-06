"""T-3957 (010, pickup 321): the sidecar's project id honours RAIL_PROJECT_LABEL.

010 sets a project label; the rail used it, the sidecar ignored it and addressed the project
by its directory name — one project, two names on one hub. The sidecar now resolves the label
exactly as lib/rail-identity.sh rail_project_label does (same sources, same normalisation).
"""
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "lib"))

from sidecar import circuit  # noqa: E402


@pytest.fixture()
def proj(tmp_path, monkeypatch):
    p = tmp_path / "Some_Project Dir"
    p.mkdir()
    monkeypatch.setenv("PROJECT_ROOT", str(p))
    monkeypatch.delenv("FW_RAIL_PROJECT_LABEL", raising=False)
    return p


def _shell_label(proj: Path, env_label: str = "") -> str:
    """rail_project_label from lib/rail-identity.sh, with fw_config absent (env path)."""
    cmd = f'source "{ROOT}/lib/rail-identity.sh"; rail_project_label'
    env = {"PATH": "/usr/bin:/bin", "PROJECT_ROOT": str(proj)}
    if env_label:
        env["FW_RAIL_PROJECT_LABEL"] = env_label
    return subprocess.run(["bash", "-c", cmd], capture_output=True, text=True, env=env).stdout


def test_control_no_label_keeps_the_basename_unchanged(proj):
    assert circuit.project_id() == "Some_Project Dir"


def test_env_label_wins_and_matches_the_rail(proj, monkeypatch):
    monkeypatch.setenv("FW_RAIL_PROJECT_LABEL", "010-TermLink_Main")
    assert circuit.project_id() == "010-termlink-main"
    assert circuit.project_id() == _shell_label(proj, "010-TermLink_Main")


@pytest.mark.parametrize("key", ["RAIL_PROJECT_LABEL", "rail_project_label"])
def test_file_label_upper_and_lower_key(proj, key):
    (proj / ".framework.yaml").write_text(f"project_name: x\n{key}: \"010-termlink\"\n")
    assert circuit.project_id() == "010-termlink"


def test_normalisation_parity_with_rail_on_odd_input(proj, monkeypatch):
    odd = "My Proj_ä!42.x"
    monkeypatch.setenv("FW_RAIL_PROJECT_LABEL", odd)
    assert circuit.project_id() == _shell_label(proj, odd)


def test_vendored_dir_refusal_still_holds(tmp_path, monkeypatch):
    v = tmp_path / ".agentic-framework"
    v.mkdir()
    monkeypatch.setenv("PROJECT_ROOT", str(v))
    monkeypatch.delenv("FW_RAIL_PROJECT_LABEL", raising=False)
    with pytest.raises(circuit.CircuitError):
        circuit.project_id()
