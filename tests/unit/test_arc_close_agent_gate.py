"""T-1671 — Default-to-OPEN agent gate on `fw arc close`.

Pins the §ACD/G-062 closure-decision gate added in lib/arc.sh after
the 4th-instance auto-close incident on 2026-05-02 (orchestrator-rethink
arc, this session). Mirrors the lib/inception.sh T-1259/T-1260 pattern:
agents must not invoke the terminal-decision verb directly; closure
belongs to the human via Watchtower.

Five canonical scenarios pinned (mirror T-1259/T-1260 inception-decide):
  1. CLAUDECODE=1 + no override                         → REFUSED (rc != 0)
  2. CLAUDECODE=1 + --i-am-human (override for rare human-in-agent case) → ACCEPTED
  3. CLAUDECODE=1 + --from-watchtower (Flask exemption) → ACCEPTED
  4. CLAUDECODE unset + --i-am-human (script/test)      → ACCEPTED
  5. CLAUDECODE unset + nothing (human CLI)             → ACCEPTED

Note on --i-am-human: T-1259's existing inception-decide gate uses
--i-am-human as a deliberate override flag for the rare case where a
human types into an agent session (e.g. paired-programming with the
shell prompt visible). T-1671 follows the same convention rather than
making the gate stricter — consistency with precedent reduces surprise.
"""

import os
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
FW = REPO_ROOT / "bin" / "fw"

VALID_HM = (
    "user runs fw work-on and observes a routing decision "
    "land on the chosen specialist"
)


def _run(cmd, cwd, claudecode=None):
    """Run cmd with explicit CLAUDECODE control.

    claudecode=None  → unset (mimics human running the binary directly)
    claudecode="1"   → set (mimics agent invocation inside Claude Code)
    """
    env = os.environ.copy()
    env["PROJECT_ROOT"] = str(cwd)
    env["FRAMEWORK_ROOT"] = str(REPO_ROOT)
    if claudecode is None:
        env.pop("CLAUDECODE", None)
    else:
        env["CLAUDECODE"] = claudecode
    return subprocess.run(cmd, cwd=str(cwd), env=env, capture_output=True, text=True)


@pytest.fixture
def project(tmp_path):
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    (tmp_path / ".tasks" / "completed").mkdir(parents=True)
    (tmp_path / ".context" / "working").mkdir(parents=True)
    (tmp_path / ".framework.yaml").write_text(f"framework_path: {REPO_ROOT}\n")
    return tmp_path


def _seed_arc_and_demo(project, arc_id="alpha"):
    """Create an arc + a valid demo file. Returns the demo path."""
    # T-1852: close requires `in-progress`; --start past the state-machine
    # check so the CLAUDECODE / demo gate is what's exercised. (Fixed: T-1995.)
    _run(
        [str(FW), "arc", "create", arc_id, "--name", "A",
         "--headline-mechanic", VALID_HM, "--start"],
        cwd=project,
        claudecode=None,  # human creating
    )
    demo = project / "demo.md"
    demo.write_text(
        f"# Arc demo for {arc_id}\n\n"
        f"User observed the routing decision land on the chosen specialist "
        f"for arc {arc_id}, validated end-to-end with a captured stream-json "
        f"transcript and a screenshot of the orchestrator surface page. "
        f"Reproducible via the steps in this artefact.\n"
    )
    return demo


# ─── Refusal paths ──────────────────────────────────────────────────────────

def test_close_refused_when_claudecode_set_no_override(project):
    demo = _seed_arc_and_demo(project)
    r = _run(
        [str(FW), "arc", "close", "alpha", "--demo", str(demo),
         "--decision", "shipped"],
        cwd=project,
        claudecode="1",
    )
    assert r.returncode != 0
    # Refusal message names §ACD/G-062 + redirects:
    assert "G-062" in r.stderr
    assert "fw task review" in r.stderr
    # Arc must NOT have closed:
    arc_text = (project / ".context" / "arcs" / "alpha.yaml").read_text()
    assert "status: in-progress" in arc_text
    assert "status: closed" not in arc_text


# ─── Acceptance paths ───────────────────────────────────────────────────────

def test_close_accepted_when_claudecode_set_with_i_am_human(project):
    """T-1259-precedent override: human-in-agent-session may pass --i-am-human."""
    demo = _seed_arc_and_demo(project)
    r = _run(
        [str(FW), "arc", "close", "alpha", "--demo", str(demo),
         "--decision", "shipped via human override", "--i-am-human"],
        cwd=project,
        claudecode="1",
    )
    assert r.returncode == 0, r.stderr
    arc_text = (project / ".context" / "arcs" / "alpha.yaml").read_text()
    assert "status: closed" in arc_text


def test_close_accepted_when_claudecode_set_with_from_watchtower(project):
    """Flask backend exemption — Watchtower invokes arc close on the human's behalf."""
    demo = _seed_arc_and_demo(project)
    r = _run(
        [str(FW), "arc", "close", "alpha", "--demo", str(demo),
         "--decision", "shipped via watchtower", "--from-watchtower"],
        cwd=project,
        claudecode="1",
    )
    assert r.returncode == 0, r.stderr
    arc_text = (project / ".context" / "arcs" / "alpha.yaml").read_text()
    assert "status: closed" in arc_text
    assert "shipped via watchtower" in arc_text


def test_close_accepted_when_claudecode_unset_with_i_am_human(project):
    """Script/test invocation: CLAUDECODE not set + explicit --i-am-human."""
    demo = _seed_arc_and_demo(project)
    r = _run(
        [str(FW), "arc", "close", "alpha", "--demo", str(demo),
         "--decision", "shipped via test", "--i-am-human"],
        cwd=project,
        claudecode=None,
    )
    assert r.returncode == 0, r.stderr
    arc_text = (project / ".context" / "arcs" / "alpha.yaml").read_text()
    assert "status: closed" in arc_text


def test_close_accepted_when_claudecode_unset_no_override(project):
    """Human CLI invocation: no CLAUDECODE, no flags. Pre-T-1671 behaviour."""
    demo = _seed_arc_and_demo(project)
    r = _run(
        [str(FW), "arc", "close", "alpha", "--demo", str(demo),
         "--decision", "shipped via human cli"],
        cwd=project,
        claudecode=None,
    )
    assert r.returncode == 0, r.stderr
    arc_text = (project / ".context" / "arcs" / "alpha.yaml").read_text()
    assert "status: closed" in arc_text
    assert "shipped via human cli" in arc_text


# ─── T-1668 demo gate still enforced (regression check) ─────────────────────

def test_t1668_demo_gate_still_fires_under_human_invocation(project):
    """Even with --i-am-human, --demo absence is rejected (T-1668 layer is below T-1671)."""
    _run(
        [str(FW), "arc", "create", "alpha", "--name", "A",
         "--headline-mechanic", VALID_HM, "--start"],  # T-1852: start before close (T-1995)
        cwd=project,
        claudecode=None,
    )
    r = _run(
        [str(FW), "arc", "close", "alpha", "--decision", "no demo", "--i-am-human"],
        cwd=project,
        claudecode=None,
    )
    assert r.returncode == 2
    assert "--demo is required" in r.stderr


def test_refusal_message_includes_anchor_redirect(project):
    """Refusal must point at fw task review on the arc anchor task."""
    # Create arc with explicit anchor:
    _run(
        [str(FW), "arc", "create", "alpha", "--name", "A",
         "--anchor", "T-9999",
         "--headline-mechanic", VALID_HM, "--start"],  # T-1852: start before close (T-1995)
        cwd=project,
        claudecode=None,
    )
    demo = project / "demo.md"
    demo.write_text(
        "# Demo for arc alpha — references T-9999 anchor for traceability.\n\n"
        "User-observable headline mechanic firing across the orchestrator surface "
        "with reproducible captured-transcript evidence attached for review.\n"
    )
    r = _run(
        [str(FW), "arc", "close", "alpha", "--demo", str(demo),
         "--decision", "shipped"],
        cwd=project,
        claudecode="1",
    )
    assert r.returncode != 0
    # Anchor should be named in the refusal:
    assert "T-9999" in r.stderr
