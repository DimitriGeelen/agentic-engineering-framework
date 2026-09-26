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

T-3487: scenario 1's refusal is now opt-in behind FW_REQUIRE_ARC_CLOSE_APPROVAL=1
(lib/arc.sh — sovereignty waiver, operator directive 2026-09-26). The two tests
that pin the refusal (test_close_refused_when_claudecode_set_no_override,
test_refusal_message_includes_anchor_redirect) only run when that switch is set,
and set it themselves for the subprocess under test — so they exercise the real
refusal path rather than being permanently skipped or silently green against a
default that no longer refuses anything.
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

REQUIRE_APPROVAL_ENV = "FW_REQUIRE_ARC_CLOSE_APPROVAL"

# T-3508: the `_require_approval_switch` skipif marker that lived here is REMOVED,
# not merely unused. It skipped the two refusal tests unless
# FW_REQUIRE_ARC_CLOSE_APPROVAL=1 was in the environment, so in every normal run
# they reported as passes while executing nothing (T-3217: a skipped test reads as
# ok). Its reason string also asserted "the refusal on `fw arc close` is opt-in",
# which is no longer true — leaving it would be the same stale-contradiction shape
# T-3504 removed from `fw arc help`.
#
# The variable is kept above because the WAIVER still exists; only its default
# moved from opt-in to opt-out.


def _run(cmd, cwd, claudecode=None, extra_env=None):
    """Run cmd with explicit CLAUDECODE control.

    claudecode=None  → unset (mimics human running the binary directly)
    claudecode="1"   → set (mimics agent invocation inside Claude Code)
    extra_env        → optional dict merged into the subprocess environment
                        (e.g. FW_REQUIRE_ARC_CLOSE_APPROVAL=1, T-3487)
    """
    env = os.environ.copy()
    env["PROJECT_ROOT"] = str(cwd)
    env["FRAMEWORK_ROOT"] = str(REPO_ROOT)
    if claudecode is None:
        env.pop("CLAUDECODE", None)
    else:
        env["CLAUDECODE"] = claudecode
    if extra_env:
        env.update(extra_env)
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
    # T-3508: runs by DEFAULT again. T-3487 had made this opt-in behind
    # FW_REQUIRE_ARC_CLOSE_APPROVAL=1, applied here as pytest.mark.skipif — so the
    # two tests guarding the gate were SKIPPED in every normal run, and a skipped
    # test reports as a pass (T-3217). No env var is set below on purpose: the
    # refusal must hold with nothing configured, which is the whole point.
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
    """Refusal must point at fw task review on the arc anchor task.

    T-3508: runs by default again — see the note on
    test_close_refused_when_claudecode_set_no_override.
    """
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


# ─── T-3508: the DEFAULT is the thing under guard ───────────────────────────


def test_the_refusal_is_the_DEFAULT_not_an_opt_in(project):
    """THE LEG THAT PROTECTS THE GATE.

    Every other refusal test here can be satisfied by a gate that only fires when
    an env var is set — which is exactly the state T-3487 shipped and T-3506 merged
    while the authorising question was still parked (OBS-547). This test fails if
    the default is ever flipped back to opt-in, because it passes NOTHING: no env
    var, no identity flag.

    Asserted on the shipped source as well as on behaviour, because the behaviour
    assertion alone would also pass if the whole block were deleted.
    """
    demo = _seed_arc_and_demo(project)
    r = _run(
        [str(FW), "arc", "close", "alpha", "--demo", str(demo),
         "--decision", "shipped"],
        cwd=project,
        claudecode="1",
    )
    assert r.returncode != 0, (
        "fw arc close did NOT refuse with nothing configured — the identity gate "
        "is opt-in again")
    assert "G-062" in r.stderr

    src = (REPO_ROOT / "lib" / "arc.sh").read_text(encoding="utf-8")
    assert f'"${{{REQUIRE_APPROVAL_ENV}:-1}}" != "0"' in src, (
        "the switch is no longer default-on; an opt-in default means the gate is "
        "off for every caller who sets nothing")
    assert f'"${{{REQUIRE_APPROVAL_ENV}:-}}" = "1"' not in src, (
        "the opt-in form is back")


def test_the_waiver_still_works_when_explicitly_set_to_zero(project):
    """The escape hatch must be proven present, not assumed.

    T-3508 keeps T-3487's variable and mechanism and moves only the default, so the
    operator can still waive the identity check — and can re-enable the waiver as
    the default with a one-line change if they rule the wider authorisation correct.
    """
    demo = _seed_arc_and_demo(project)
    r = _run(
        [str(FW), "arc", "close", "alpha", "--demo", str(demo),
         "--decision", "shipped"],
        cwd=project,
        claudecode="1",
        extra_env={REQUIRE_APPROVAL_ENV: "0"},
    )
    assert r.returncode == 0, (
        f"waiver did not take effect: rc={r.returncode} stderr={r.stderr[:400]}")
    arc_text = (project / ".context" / "arcs" / "alpha.yaml").read_text()
    assert "status: closed" in arc_text


def test_waiving_the_identity_check_does_NOT_waive_the_demo_requirement(project):
    """Identity and evidence are independent gates, and only identity is waivable.

    Without this, 'the waiver works' could mean 'the waiver lets an agent close an
    arc with no evidence at all', which is a materially different and much worse
    permission than the one T-3487 asked for.
    """
    _run(
        [str(FW), "arc", "create", "alpha", "--name", "A",
         "--headline-mechanic", VALID_HM, "--start"],
        cwd=project,
        claudecode=None,
    )
    r = _run(
        [str(FW), "arc", "close", "alpha", "--decision", "shipped"],
        cwd=project,
        claudecode="1",
        extra_env={REQUIRE_APPROVAL_ENV: "0"},
    )
    assert r.returncode != 0
    assert "--demo is required" in r.stderr
