"""T-1668 — §ACD enforcement gates: --headline-mechanic at create + --demo at close.

Pins the structural enforcement of §Arc Completion Discipline (G-062). Each
test runs the real `bin/fw arc` binary against an isolated PROJECT_ROOT.

Layers under test:
  Layer A — fw arc create REFUSES without --headline-mechanic, REFUSES on
            substrate-only phrasing, ACCEPTS user-observable phrasing.
  Layer B — fw arc close REFUSES without --demo, REFUSES on too-small files
            and unrelated-task-id files, ACCEPTS valid path/url, ACCEPTS
            --demo none with sufficient justification.
"""

import os
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
FW = REPO_ROOT / "bin" / "fw"

VALID_HM = "user runs fw work-on and observes a routing decision land on the chosen specialist"


def _run(cmd, cwd, env_extra=None):
    env = os.environ.copy()
    env["PROJECT_ROOT"] = str(cwd)
    env["FRAMEWORK_ROOT"] = str(REPO_ROOT)
    # T-1671: clear CLAUDECODE so pre-existing tests of T-1668 gates run as
    # "human invocation" (CLAUDECODE-aware tests use _run with --i-am-human
    # OR explicit env_extra={"CLAUDECODE": "1"} — never inherit from this
    # session's parent env).
    env.pop("CLAUDECODE", None)
    if env_extra:
        env.update(env_extra)
    return subprocess.run(cmd, cwd=str(cwd), env=env, capture_output=True, text=True)


@pytest.fixture
def project(tmp_path):
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    (tmp_path / ".tasks" / "completed").mkdir(parents=True)
    (tmp_path / ".context" / "working").mkdir(parents=True)
    (tmp_path / ".framework.yaml").write_text(f"framework_path: {REPO_ROOT}\n")
    return tmp_path


# ─── Layer A: --headline-mechanic at create ─────────────────────────────────

def test_create_refuses_without_headline_mechanic(project):
    r = _run([str(FW), "arc", "create", "alpha", "--name", "A"], cwd=project)
    assert r.returncode == 2
    assert "--headline-mechanic is required" in r.stderr
    assert "G-062" in r.stderr
    assert not (project / ".context" / "arcs" / "alpha.yaml").exists()


def test_create_refuses_substrate_only_phrasing(project):
    r = _run(
        [str(FW), "arc", "create", "alpha", "--name", "A",
         "--headline-mechanic", "framework metadata capture for events"],
        cwd=project,
    )
    assert r.returncode == 2
    assert "observable action" in r.stderr or "substrate" in r.stderr


def test_create_refuses_too_short_mechanic(project):
    r = _run(
        [str(FW), "arc", "create", "alpha", "--name", "A",
         "--headline-mechanic", "user runs"],
        cwd=project,
    )
    assert r.returncode == 2
    assert "30-500 chars" in r.stderr


def test_create_refuses_pure_substrate_with_substrate_keywords(project):
    """Substrate keywords + no user reference → refuse."""
    r = _run(
        [str(FW), "arc", "create", "alpha", "--name", "A",
         "--headline-mechanic",
         "the framework populates metadata capture infrastructure for governance hook events"],
        cwd=project,
    )
    assert r.returncode == 2


def test_create_accepts_valid_user_observable_mechanic(project):
    r = _run(
        [str(FW), "arc", "create", "alpha", "--name", "A",
         "--headline-mechanic", VALID_HM],
        cwd=project,
    )
    assert r.returncode == 0, r.stderr
    arc_text = (project / ".context" / "arcs" / "alpha.yaml").read_text()
    assert "headline_mechanic:" in arc_text
    assert "routing decision" in arc_text
    assert "demo_evidence: null" in arc_text


# ─── Layer B: --demo at close ───────────────────────────────────────────────

def _create_arc(project, arc_id="alpha"):
    # T-1852: close requires `in-progress`; plain create yields `draft`. These
    # are close-gate tests, so --start past the state-machine check lets the
    # demo / §ACD gate be what's exercised. (Fixed: T-1995.)
    _run(
        [str(FW), "arc", "create", arc_id, "--name", "A",
         "--headline-mechanic", VALID_HM, "--start"],
        cwd=project,
    )


def test_close_refuses_without_demo(project):
    _create_arc(project)
    r = _run([str(FW), "arc", "close", "alpha", "--decision", "ok"], cwd=project)
    assert r.returncode == 2
    assert "--demo is required" in r.stderr
    assert "G-062" in r.stderr
    # Headline mechanic should be printed to remind agent what was promised.
    assert "headline_mechanic" in r.stderr


def test_close_refuses_tiny_demo_file(project):
    _create_arc(project)
    tiny = project / "tiny.md"
    tiny.write_text("alpha\n")
    r = _run(
        [str(FW), "arc", "close", "alpha", "--demo", str(tiny), "--decision", "ok"],
        cwd=project,
    )
    assert r.returncode == 1
    assert "too small" in r.stderr


def test_close_refuses_demo_extension_not_allowlisted(project):
    _create_arc(project)
    weird = project / "demo.exe"
    weird.write_text("alpha\n" + ("x" * 300))
    r = _run(
        [str(FW), "arc", "close", "alpha", "--demo", str(weird), "--decision", "ok"],
        cwd=project,
    )
    assert r.returncode == 1
    assert "extension not in evidence allowlist" in r.stderr


def test_close_refuses_demo_referencing_unrelated_task(project):
    _create_arc(project)
    # File referencing only an unrelated task id, not arc id, not constituent.
    bad = project / "bad-demo.md"
    bad.write_text("# Demo\n" + "T-9999 unrelated task evidence " * 12)
    r = _run(
        [str(FW), "arc", "close", "alpha", "--demo", str(bad), "--decision", "ok"],
        cwd=project,
    )
    assert r.returncode == 1
    assert "none belong to arc" in r.stderr or "does not reference arc id" in r.stderr


def test_close_accepts_valid_demo_file_referencing_arc_id(project):
    _create_arc(project)
    good = project / "good-demo.md"
    good.write_text(
        "# Demo evidence for arc alpha\n\n"
        "Captured 2026-05-02. The user ran `fw work-on test --type build` and "
        "the framework dispatched to the routing path. The orchestrator picked "
        "haiku for arc alpha. This is the headline mechanic firing end-to-end "
        "on a fresh substrate, with the routing decision visible on /orchestrator "
        "and reproducible via the captured stream-json transcript attached.\n"
    )
    r = _run(
        [str(FW), "arc", "close", "alpha", "--demo", str(good), "--decision", "success"],
        cwd=project,
    )
    assert r.returncode == 0, r.stderr
    arc_text = (project / ".context" / "arcs" / "alpha.yaml").read_text()
    assert "status: closed" in arc_text
    assert "demo_evidence:" in arc_text
    assert str(good) in arc_text or "good-demo.md" in arc_text


def test_close_demo_none_requires_justification(project):
    _create_arc(project)
    r = _run(
        [str(FW), "arc", "close", "alpha", "--demo", "none", "--decision", "ok"],
        cwd=project,
    )
    assert r.returncode == 2
    assert "--justification" in r.stderr


def test_close_demo_none_with_justification_logs_bypass_and_proceeds(project):
    _create_arc(project)
    r = _run(
        [str(FW), "arc", "close", "alpha",
         "--demo", "none",
         "--justification", "documentation arc with no runtime mechanic to demonstrate",
         "--decision", "doc-arc"],
        cwd=project,
    )
    assert r.returncode == 0, r.stderr
    arc_text = (project / ".context" / "arcs" / "alpha.yaml").read_text()
    assert "status: closed" in arc_text
    bypass_log = project / ".context" / "audits" / "arc-bypass.jsonl"
    assert bypass_log.is_file(), "bypass should be logged to arc-bypass.jsonl"
    log_text = bypass_log.read_text()
    assert "alpha" in log_text
    assert "documentation arc" in log_text


def test_close_yaml_carries_demo_evidence_field(project):
    """demo_evidence field is added when not present (back-compat for old arcs)."""
    _create_arc(project)
    good = project / "demo.md"
    good.write_text(
        "Demo for arc alpha\n" + ("alpha lorem ipsum dolor sit amet " * 10)
    )
    _run([str(FW), "arc", "close", "alpha",
          "--demo", str(good), "--decision", "ok"], cwd=project)
    arc_text = (project / ".context" / "arcs" / "alpha.yaml").read_text()
    assert "demo_evidence:" in arc_text
    assert "demo.md" in arc_text
