"""T-5391: a task tagged `outside-contributor` links the PR workflow map.

Hermetic: a temp project, the real create-task.sh / update-task.sh, and a fixed
WATCHTOWER_URL (the override every _watchtower_url caller honours), so no live
Watchtower or network is consulted.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

FW = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW / "lib"))
import workflow_map_link as wml  # noqa: E402

BASE = "http://wt.test:4321"
MAP = "aef-github-pr-intake"


@pytest.fixture
def proj(tmp_path):
    for d in (".tasks/active", ".tasks/completed", ".tasks/templates", ".context/working"):
        (tmp_path / d).mkdir(parents=True)
    (tmp_path / ".framework.yaml").write_text(f"framework_root: {FW}\n")
    tpl = FW / ".tasks/templates/zzz-default.md"
    if tpl.exists():
        shutil.copy(tpl, tmp_path / ".tasks/templates/")
    subprocess.run(["git", "init", "-q"], cwd=tmp_path, check=True)
    return tmp_path


def _env(proj):
    env = {k: v for k, v in os.environ.items() if k not in ("CLAUDECODE", "AI_AGENT")}
    env.update(FRAMEWORK_ROOT=str(FW), PROJECT_ROOT=str(proj), TASKS_DIR=str(proj / ".tasks"),
               CONTEXT_DIR=str(proj / ".context"), NO_COLOR="1", WATCHTOWER_URL=BASE)
    return env


def _create(proj, name, tags=None):
    args = [str(FW / "agents/task-create/create-task.sh"), "--name", name, "--type", "build",
            "--description", "t5391 probe", "--owner", "agent"]
    if tags:
        args += ["--tags", tags]
    r = subprocess.run(args, cwd=proj, env=_env(proj), capture_output=True, text=True)
    assert r.returncode == 0, r.stdout + r.stderr
    files = list((proj / ".tasks/active").glob("T-*.md"))
    slug = name.lower().replace(" ", "-")
    return next(f for f in files if slug in f.name)


def _add_tag(proj, path, tag):
    tid = path.name.split("-")[0] + "-" + path.name.split("-")[1]
    r = subprocess.run([str(FW / "agents/task-create/update-task.sh"), tid, "--add-tag", tag],
                       cwd=proj, env=_env(proj), capture_output=True, text=True)
    assert r.returncode == 0, r.stdout + r.stderr


def _count_line(text):
    return sum(1 for ln in text.splitlines() if ln.startswith("**Workflow:**") and MAP in ln)


def _assert_linked(text):
    fm = text.split("\n---\n", 1)[0]
    assert fm.count(f"\nworkflow_map: {MAP}\n") == 1
    assert _count_line(text) == 1
    ctx = text.split("## Context", 1)[1].split("\n## ", 1)[0]
    assert f"**Workflow:** outside-PR process map {MAP} — {BASE}/designer/app?load=" in ctx
    # the four Context labels are intact
    for label in ("Background / trigger", "Problem / hypothesis", "Goal", "Expected outcome"):
        if label in Path(FW / ".tasks/templates/default.md").read_text():
            assert label in ctx


def test_create_with_tag_writes_field_and_line(proj):
    f = _create(proj, "Tagged probe", tags="github,outside-contributor")
    _assert_linked(f.read_text())


def test_add_tag_later_links_once(proj):
    f = _create(proj, "Later probe", tags="github")
    assert "workflow_map:" not in f.read_text()
    _add_tag(proj, f, "outside-contributor")
    _assert_linked(f.read_text())
    _add_tag(proj, f, "outside-contributor")  # second run adds nothing
    _assert_linked(f.read_text())


def test_untagged_task_unchanged(proj):
    f = _create(proj, "Plain probe", tags="github")
    text = f.read_text()
    assert "workflow_map:" not in text and "**Workflow:**" not in text
    before = f.read_bytes()
    assert wml.needs(text) is False
    assert wml.apply(text, BASE) == (text, [])
    assert subprocess.run([sys.executable, str(FW / "lib/workflow_map_link.py"), "apply", str(f), BASE]
                          ).returncode == 0
    assert f.read_bytes() == before


def test_apply_is_idempotent(proj):
    f = _create(proj, "Idem probe", tags="outside-contributor")
    first = f.read_bytes()
    r = subprocess.run([sys.executable, str(FW / "lib/workflow_map_link.py"), "apply", str(f), BASE],
                       capture_output=True, text=True)
    assert r.returncode == 0 and r.stdout == ""
    assert f.read_bytes() == first
    assert wml.needs(first.decode()) is False


def test_map_id_single_source():
    assert wml.TAG_MAPS == {"outside-contributor": MAP}
    hits = [p for p in ("lib/workflow-map-link.sh", "agents/task-create/create-task.sh",
                        "agents/task-create/update-task.sh", "agents/task-create/create-batch.sh")
            if MAP in (FW / p).read_text()]
    assert hits == []
