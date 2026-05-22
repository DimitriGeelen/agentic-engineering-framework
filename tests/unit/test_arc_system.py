"""T-1661 — Arc system MVP regression tests.

Pins lib/arc.sh + bin/fw arc behaviour against T-1653 Phase 1 deliverables
(D1..D9). Each test runs the real `bin/fw arc` binary against an isolated
PROJECT_ROOT (tmp_path) so we don't pollute the live registry.
"""

import os
import re
import shutil
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
FW = REPO_ROOT / "bin" / "fw"
ARC_SH = REPO_ROOT / "lib" / "arc.sh"


def _run(cmd, cwd, env_extra=None, check=False):
    env = os.environ.copy()
    env["PROJECT_ROOT"] = str(cwd)
    env["FRAMEWORK_ROOT"] = str(REPO_ROOT)
    # T-1671: clear CLAUDECODE so arc-close tests run as human invocation
    # (CLAUDECODE-aware tests live in test_arc_close_agent_gate.py with
    # explicit env_extra={"CLAUDECODE": "1"} where needed).
    env.pop("CLAUDECODE", None)
    if env_extra:
        env.update(env_extra)
    return subprocess.run(
        cmd, cwd=str(cwd), env=env, capture_output=True, text=True, check=check
    )


@pytest.fixture
def project(tmp_path):
    """Minimal PROJECT_ROOT skeleton: dirs + one task file."""
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    (tmp_path / ".tasks" / "completed").mkdir(parents=True)
    (tmp_path / ".context" / "working").mkdir(parents=True)
    # Minimal `.framework.yaml` so the path-resolution accepts cwd as a project.
    (tmp_path / ".framework.yaml").write_text("framework_path: " + str(REPO_ROOT) + "\n")

    # Seed one task that will be tagged.
    task = tmp_path / ".tasks" / "active" / "T-9001-seed.md"
    task.write_text(
        """---
id: T-9001
name: "seed task for arc tag"
status: started-work
workflow_type: build
horizon: now
tags: [seed]
---

# T-9001
"""
    )
    return tmp_path


def test_arc_sh_present():
    assert ARC_SH.is_file(), f"{ARC_SH} missing"


def test_arc_help_lists_all_verbs(project):
    """D1 — `bin/fw arc help` lists 7 verbs."""
    r = _run([str(FW), "arc", "help"], cwd=project)
    assert r.returncode == 0, r.stderr
    out = r.stdout
    for verb in ("create", "focus", "list", "show", "tag", "close", "migrate"):
        assert verb in out, f"verb {verb} not in arc help"


def test_arc_create_writes_yaml_with_required_fields(project):
    """D2 — `arc create` writes a YAML with id/name/status/anchor/created.

    T-1816: name/description/headline_mechanic are now yaml-safe-quoted, so we
    parse the YAML and check structural fields rather than substring-matching
    the raw text.
    """
    import yaml

    r = _run(
        [str(FW), "arc", "create", "test-arc", "--name", "Test arc", "--anchor", "T-1641",
         "--headline-mechanic", "user runs fw work-on and sees the test arc complete"],
        cwd=project,
    )
    assert r.returncode == 0, r.stderr + r.stdout
    arc_file = project / ".context" / "arcs" / "test-arc.yaml"
    assert arc_file.is_file(), "arc YAML not written"
    data = yaml.safe_load(arc_file.read_text())
    # T-1969 dual-form: canonical immutable id (arc-001 in a fresh project) +
    # human-given slug. T-1852: plain create yields `draft` (use --start for
    # in-progress). T-1851: constituent_tasks deprecated — source of truth is
    # the task's `arc:<slug>` tag, not a duplicated list in the arc YAML.
    # (Fixed: T-1995.)
    assert data["id"] == "arc-001"
    assert data["slug"] == "test-arc"
    assert data["name"] == "Test arc"
    assert data["status"] == "draft"
    assert data["anchor_task"] == "T-1641"
    assert "created" in data


def test_arc_create_yaml_safe_with_colons_in_name(project):
    """T-1816: arc YAML must parse cleanly when name/description contain colons.

    Origin: dispatch-safety.yaml shipped with `name: Dispatch safety: Worker
    uncertainty handling` — the unquoted colon caused yaml.safe_load to fail,
    which 404'd Watchtower /arcs/dispatch-safety AND silently excluded the
    arc from the /arcs list page.
    """
    import yaml

    r = _run(
        [str(FW), "arc", "create", "ds-test",
         "--name", "Foo: a colon test",
         "--description", "Desc: with colon # and hash -> and arrow",
         "--headline-mechanic", "user observes that arc yaml with colons in name and description parses cleanly via yaml.safe_load"],
        cwd=project,
    )
    assert r.returncode == 0, r.stderr + r.stdout
    arc_file = project / ".context" / "arcs" / "ds-test.yaml"
    data = yaml.safe_load(arc_file.read_text())
    assert data["name"] == "Foo: a colon test"
    assert data["description"] == "Desc: with colon # and hash -> and arrow"


def test_arc_create_rejects_invalid_id(project):
    """Slug must be lowercase + slug-safe."""
    r = _run([str(FW), "arc", "create", "Bad_ID", "--name", "X"], cwd=project)
    assert r.returncode != 0
    assert "lowercase slug" in (r.stderr + r.stdout).lower()


def test_arc_focus_writes_arc_focus_yaml(project):
    """D3 — `arc focus` sets current_arc."""
    _run([str(FW), "arc", "create", "alpha", "--name", "A",
         "--headline-mechanic", "user runs fw work-on and sees the demo arc complete"], cwd=project, check=True)
    r = _run([str(FW), "arc", "focus", "alpha"], cwd=project)
    assert r.returncode == 0, r.stderr
    focus = (project / ".context" / "working" / "arc-focus.yaml").read_text()
    assert "current_arc: alpha" in focus

    # Verify list marks it focused (* in the indicator column).
    # T-1969: `arc list` shows the canonical id (arc-001), not the slug. (T-1995.)
    r2 = _run([str(FW), "arc", "list"], cwd=project)
    assert "arc-001" in r2.stdout
    assert "*" in r2.stdout  # focus marker

    # Clear focus
    r3 = _run([str(FW), "arc", "focus", "--clear"], cwd=project)
    assert r3.returncode == 0
    cleared = (project / ".context" / "working" / "arc-focus.yaml").read_text()
    assert "current_arc: null" in cleared


def test_arc_tag_adds_to_task_and_constituents(project):
    """D4 — tag T-9001 with arc:alpha; tag lands on the task and the arc
    surfaces it. T-1851: source of truth is the task's `arc:<slug>` tag (not a
    constituent_tasks list); `arc show` computes membership from the tag scan.
    (Fixed: T-1995.)"""
    _run([str(FW), "arc", "create", "alpha", "--name", "A",
         "--headline-mechanic", "user runs fw work-on and sees the demo arc complete"], cwd=project, check=True)
    r = _run([str(FW), "arc", "tag", "alpha", "T-9001"], cwd=project)
    assert r.returncode == 0, r.stderr + r.stdout
    task_text = (project / ".tasks" / "active" / "T-9001-seed.md").read_text()
    assert "arc:alpha" in task_text, f"tag not added to task:\n{task_text}"
    # Membership is computed from the tag, surfaced by `arc show`.
    show = _run([str(FW), "arc", "show", "alpha"], cwd=project)
    assert "T-9001" in show.stdout, f"tagged task not surfaced by arc show:\n{show.stdout}"


def test_arc_tag_idempotent(project):
    """Re-tagging the same task does not duplicate the entry."""
    _run([str(FW), "arc", "create", "alpha", "--name", "A",
         "--headline-mechanic", "user runs fw work-on and sees the demo arc complete"], cwd=project, check=True)
    _run([str(FW), "arc", "tag", "alpha", "T-9001"], cwd=project, check=True)
    _run([str(FW), "arc", "tag", "alpha", "T-9001"], cwd=project, check=True)
    # T-1851: tag lives on the task; re-tagging must not duplicate it. (T-1995.)
    task_text = (project / ".tasks" / "active" / "T-9001-seed.md").read_text()
    assert task_text.count("arc:alpha") == 1, f"duplicate tag:\n{task_text}"


def test_arc_close_marks_status_and_clears_focus(project):
    """D7-bonus — close ends the arc + drops focus if it was focused."""
    _run([str(FW), "arc", "create", "alpha", "--name", "A",
         "--headline-mechanic", "user runs fw work-on and sees the demo arc complete"], cwd=project, check=True)
    _run([str(FW), "arc", "focus", "alpha"], cwd=project, check=True)
    # T-1852: close requires `in-progress`; plain create yields `draft`, so
    # transition via `arc start` first. (Fixed: T-1995.)
    _run([str(FW), "arc", "start", "alpha"], cwd=project, check=True)
    # T-1668 §ACD Layer B: close requires --demo. Use the bypass for this
    # test (it's testing close mechanics, not §ACD enforcement).
    r = _run([str(FW), "arc", "close", "alpha", "--decision", "shipped",
              "--demo", "none",
              "--justification", "test-fixture exercising close mechanics, no runtime mechanic"],
             cwd=project)
    assert r.returncode == 0, r.stderr
    arc_text = (project / ".context" / "arcs" / "alpha.yaml").read_text()
    assert "status: closed" in arc_text
    assert "shipped" in arc_text  # decision now quoted
    focus = (project / ".context" / "working" / "arc-focus.yaml").read_text()
    assert "current_arc: null" in focus, "focus not cleared on close"


def test_arc_show_renders_metadata_and_tasks(project):
    """D5 — show emits id/name/status + tagged task lines."""
    _run([str(FW), "arc", "create", "alpha", "--name", "A",
         "--headline-mechanic", "user runs fw work-on and sees the demo arc complete"], cwd=project, check=True)
    _run([str(FW), "arc", "tag", "alpha", "T-9001"], cwd=project, check=True)
    r = _run([str(FW), "arc", "show", "alpha"], cwd=project)
    assert r.returncode == 0
    out = r.stdout
    # T-1969 dual-form: `id:` is the canonical immutable arc-NNN (arc-001 in a
    # fresh project), the human-given handle moves to `slug:`. (Fixed: T-1995.)
    assert "id: arc-001" in out
    assert "slug: alpha" in out
    assert "T-9001" in out
    assert "Tasks tagged arc:alpha" in out


def test_handover_injects_current_arc_section(project):
    """D6 — handover.sh emits ## Current Arc when arc-focus.yaml is set.

    We don't need to run the whole handover agent — the injection block is a
    self-contained `$(...)` subshell. We grep handover.sh to assert the block
    exists, then prove the block produces output for a focused project.
    """
    text = (REPO_ROOT / "agents" / "handover" / "handover.sh").read_text()
    # Assertion 1: the injection point exists in the script.
    assert "ARC_FOCUS_FILE" in text, "handover.sh has no ARC_FOCUS_FILE injection"
    assert "## Current Arc" in text, "handover.sh has no ## Current Arc emit"

    # Assertion 2: when focus.yaml has current_arc:, the inline block emits the section.
    _run([str(FW), "arc", "create", "alpha", "--name", "A",
         "--headline-mechanic", "user runs fw work-on and sees the demo arc complete"], cwd=project, check=True)
    _run([str(FW), "arc", "focus", "alpha"], cwd=project, check=True)
    inline = '''
ARC_FOCUS_FILE="$PROJECT_ROOT/.context/working/arc-focus.yaml"
cur_arc=$(grep -E '^current_arc:' "$ARC_FOCUS_FILE" 2>/dev/null | head -1 | awk -F': ' '{print $2}' | tr -d ' "')
arc_yaml="$PROJECT_ROOT/.context/arcs/${cur_arc}.yaml"
arc_name=$(awk -F': ' '/^name:/ {sub(/^name: /,""); print; exit}' "$arc_yaml")
echo "## Current Arc"
echo "**${cur_arc}** — ${arc_name}"
'''
    r = subprocess.run(
        ["bash", "-c", inline],
        env={**os.environ, "PROJECT_ROOT": str(project)},
        capture_output=True, text=True,
    )
    assert "## Current Arc" in r.stdout
    assert "**alpha**" in r.stdout
    assert "A" in r.stdout
