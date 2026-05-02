"""T-1673 — fabric drift orphan check honours absolute location paths.

Origin: T-1652 introduced cross-repo fabric cards (e.g.
cross-repo-termlink-bypass.yaml) whose ``location`` field is an absolute
path like ``/opt/termlink/crates/termlink-hub/src/bypass.rs``. The orphan
check in ``agents/fabric/lib/drift.sh`` previously did
``[ ! -f "$PROJECT_ROOT/$loc" ]`` unconditionally, producing the literal
joined string ``/opt/999-Agentic-Engineering-Framework//opt/termlink/...``,
which never resolves → all 6 cross-repo cards reported as orphaned.

This test runs the real ``bin/fw fabric drift`` against a fixture
PROJECT_ROOT seeded with one absolute-path card and one project-relative
card, confirms the absolute-path card is NOT flagged, and confirms the
relative-path card IS flagged when its referent is missing.
"""

import os
import shutil
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
FW = REPO_ROOT / "bin" / "fw"


def _run(cmd, cwd, env_extra=None):
    env = os.environ.copy()
    env["PROJECT_ROOT"] = str(cwd)
    env["FRAMEWORK_ROOT"] = str(REPO_ROOT)
    if env_extra:
        env.update(env_extra)
    return subprocess.run(
        cmd, cwd=str(cwd), env=env, capture_output=True, text=True, timeout=120
    )


@pytest.fixture
def project(tmp_path):
    """Minimal PROJECT_ROOT skeleton with a small .fabric/components/ dir."""
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    (tmp_path / ".tasks" / "completed").mkdir(parents=True)
    (tmp_path / ".context" / "working").mkdir(parents=True)
    (tmp_path / ".framework.yaml").write_text(
        f"framework_path: {REPO_ROOT}\n"
    )
    fabric_dir = tmp_path / ".fabric" / "components"
    fabric_dir.mkdir(parents=True)
    return tmp_path


def _write_card(fabric_dir: Path, *, card_id: str, name: str, location: str):
    """Write a minimal fabric card YAML with the given location field."""
    (fabric_dir / f"{card_id}.yaml").write_text(
        f"""id: {card_id}
name: {name}
type: code
subsystem: test
location: {location}
purpose: test fixture
interfaces: []
depends_on: []
depended_by: []
"""
    )


def test_absolute_path_card_not_orphaned_when_file_exists(project, tmp_path):
    """An absolute-path card pointing at an existing file → NOT orphaned."""
    fabric_dir = project / ".fabric" / "components"
    # Absolute path to a real file outside PROJECT_ROOT.
    real_target = tmp_path / "outside-project.txt"
    real_target.write_text("real file")
    _write_card(
        fabric_dir,
        card_id="absolute-card-real",
        name="absolute-card-real",
        location=str(real_target),
    )

    r = _run([str(FW), "fabric", "drift"], cwd=project)
    assert r.returncode == 0, r.stderr
    # Card must NOT appear in orphaned section:
    assert "absolute-card-real" not in r.stdout or "(file missing)" not in r.stdout, (
        f"absolute-path card with existing file flagged as orphan:\n{r.stdout}"
    )
    # More precise: the orphan line specifically:
    for line in r.stdout.splitlines():
        if "absolute-card-real" in line and "(file missing)" in line:
            pytest.fail(
                f"absolute-path card pointing at existing file falsely orphaned:\n{line}"
            )


def test_absolute_path_card_orphaned_when_file_missing(project):
    """An absolute-path card whose referent is missing → IS orphaned."""
    fabric_dir = project / ".fabric" / "components"
    # Absolute path that does NOT exist.
    _write_card(
        fabric_dir,
        card_id="absolute-card-missing",
        name="absolute-card-missing",
        location="/nonexistent/path/totally-not-here.rs",
    )

    r = _run([str(FW), "fabric", "drift"], cwd=project)
    assert r.returncode == 0, r.stderr
    # Card MUST appear in orphaned section:
    assert "absolute-card-missing" in r.stdout, (
        f"absolute-path card with missing file not detected:\n{r.stdout}"
    )
    assert "(file missing)" in r.stdout


def test_relative_path_card_still_works(project):
    """Project-relative locations continue to resolve against PROJECT_ROOT."""
    fabric_dir = project / ".fabric" / "components"
    # Relative path that exists inside PROJECT_ROOT:
    real_inside = project / "real-inside.txt"
    real_inside.write_text("inside project")
    _write_card(
        fabric_dir,
        card_id="relative-card-real",
        name="relative-card-real",
        location="real-inside.txt",
    )
    # Relative path that does NOT exist:
    _write_card(
        fabric_dir,
        card_id="relative-card-missing",
        name="relative-card-missing",
        location="not-here.txt",
    )

    r = _run([str(FW), "fabric", "drift"], cwd=project)
    assert r.returncode == 0, r.stderr
    # Existing relative path → not orphaned:
    for line in r.stdout.splitlines():
        if "relative-card-real" in line and "(file missing)" in line:
            pytest.fail(
                f"relative-path card pointing at existing file falsely orphaned:\n{line}"
            )
    # Missing relative path → IS orphaned:
    assert "relative-card-missing" in r.stdout
    assert "(file missing)" in r.stdout
