"""T-3694: design-conformance register — audit/doctor predicate, stale keystones,
close-gate self-deferral, and the /approvals line.

Every test builds a throwaway project root (tmp_path) and runs the REAL predicate in
lib/design_register.py against it — nothing under test is mocked. The T-3691 case is
reproduced from a committed copy of T-3691's own task file as it closed
(tests/fixtures/t3694/T-3691-as-closed.md), so the fixture is the actual text that got
through, not a paraphrase of it.
"""
from __future__ import annotations

import shutil
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "lib"))
import design_register as dr  # noqa: E402

MOD = REPO / "lib" / "design_register.py"
T3691_FIXTURE = REPO / "tests" / "fixtures" / "t3694" / "T-3691-as-closed.md"
NOW = datetime(2026, 10, 10, 12, 0, tzinfo=timezone.utc)


# ---------------------------------------------------------------- fixture helpers

def task(root: Path, tid: str, *, loc="active", status="started-work", name="fixture task",
         arc_id="", created="2026-10-01T00:00:00Z", body="") -> Path:
    d = root / ".tasks" / loc
    d.mkdir(parents=True, exist_ok=True)
    p = d / f"{tid}-fixture.md"
    p.write_text(
        f"---\nid: {tid}\nname: \"{name}\"\ndescription: fixture\nstatus: {status}\n"
        f"workflow_type: build\nowner: agent\nhorizon: now\narc_id: {arc_id}\n"
        f"created: {created}\nlast_update: {created}\n---\n\n# {tid}\n\n{body}\n"
    )
    return p


def register_doc(root: Path, rows: list[dict], rel="docs/architecture/x-design.md") -> Path:
    p = root / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    lines = ["# Design", "", "## Register", "", "```yaml", "register:"]
    for r in rows:
        lines.append(f"  - id: {r['id']}")
        lines.append(f"    text: \"{r.get('text', 'req')}\"")
        lines.append(f"    owner_task: {r.get('owner', 'null')}")
        lines.append(f"    status: {r.get('status', 'unbuilt')}")
    lines += ["```", ""]
    p.write_text("\n".join(lines))
    return p


def arc(root: Path, filename: str, arc_id: str, slug: str, **extra) -> Path:
    d = root / ".context" / "arcs"
    d.mkdir(parents=True, exist_ok=True)
    p = d / f"{filename}.yaml"
    body = f"id: {arc_id}\nslug: {slug}\nname: fixture arc\nstatus: in-progress\n"
    for k, v in extra.items():
        if isinstance(v, list):
            body += f"{k}:\n" + "".join(f"  - {x}\n" for x in v)
        else:
            body += f"{k}: {v}\n"
    p.write_text(body)
    return p


def cli(root: Path, *args) -> subprocess.CompletedProcess:
    return subprocess.run([sys.executable, str(MOD), *args, "--root", str(root)],
                          capture_output=True, text=True)


# ---------------------------------------------------------------- item 3: violations

def test_violations_control_clean(tmp_path):
    task(tmp_path, "T-0001", loc="completed", status="work-completed")
    task(tmp_path, "T-0002")
    register_doc(tmp_path, [{"id": "R1", "owner": "T-0001", "status": "built"},
                            {"id": "R2", "owner": "T-0002", "status": "unbuilt"}])
    r = cli(tmp_path, "violations")
    assert r.returncode == 0, r.stdout
    assert r.stdout.strip() == ""


@pytest.mark.parametrize("row,expect", [
    ({"id": "R2", "owner": "null"}, "R2: no owner_task"),
    ({"id": "R2", "owner": "T-0404"}, "R2: owner_task T-0404 does not exist"),
    ({"id": "R2", "owner": "T-0001", "status": "partial"},
     "R2: owner T-0001 is completed but row status is 'partial'"),
])
def test_violations_treatment_fails(tmp_path, row, expect):
    task(tmp_path, "T-0001", loc="completed", status="work-completed")
    register_doc(tmp_path, [{"id": "R1", "owner": "T-0001", "status": "built"}, row])
    r = cli(tmp_path, "violations")
    assert r.returncode == 1
    assert expect in r.stdout
    assert "R1" not in r.stdout  # the valid row is not reported


def test_violations_see_unlinked_and_arc_linked_docs(tmp_path):
    """A register under docs/ is checked even when no arc links it (the sidecar
    case), and an arc's register_docs outside docs/ is checked too."""
    register_doc(tmp_path, [{"id": "R1", "owner": "T-0404"}])
    register_doc(tmp_path, [{"id": "Q1", "owner": "T-0405"}], rel="design/elsewhere.md")
    arc(tmp_path, "some-arc", "arc-077", "some-arc", register_docs=["design/elsewhere.md"])
    r = cli(tmp_path, "violations")
    assert r.returncode == 1
    assert "R1: owner_task T-0404" in r.stdout
    assert "Q1: owner_task T-0405" in r.stdout


def test_violations_sidecar_shape_before_and_after_repoint(tmp_path):
    """The live sidecar shape: T-3561 completed while owning an unbuilt row FAILs;
    re-pointing the row at the active S1-finish task makes it pass."""
    task(tmp_path, "T-3561", loc="completed", status="work-completed")
    task(tmp_path, "T-3693")
    register_doc(tmp_path, [{"id": "R6", "owner": "T-3561", "status": "partial"}])
    assert cli(tmp_path, "violations").returncode == 1
    register_doc(tmp_path, [{"id": "R6", "owner": "T-3693", "status": "partial"}])
    assert cli(tmp_path, "violations").returncode == 0


def test_live_register_has_no_owner_on_unrelated_t3692():
    """No sidecar register row may point at T-3692 (an unrelated bug)."""
    rows = dr.parse_register(REPO / "docs/architecture/sidecar-target-architecture.md")
    assert rows, "sidecar register not found"
    assert all(str(r.get("owner_task")) != "T-3692" for r in rows)


# ---------------------------------------------------------------- item 5: stale keystones

def test_stale_keystone_owner_of_unbuilt_row(tmp_path):
    task(tmp_path, "T-0010", status="captured", created="2026-10-01T00:00:00Z")   # 9.5 days
    task(tmp_path, "T-0011", status="captured", created="2026-10-08T00:00:00Z")   # 2.5 days
    task(tmp_path, "T-0012", status="started-work", created="2026-09-01T00:00:00Z")
    register_doc(tmp_path, [{"id": "R1", "owner": "T-0010"}, {"id": "R2", "owner": "T-0011"},
                            {"id": "R3", "owner": "T-0012"}])
    rows = dr.stale_keystones(tmp_path, days=3, now=NOW)
    assert [r["task_id"] for r in rows] == ["T-0010"]
    assert rows[0]["days_captured"] == 9
    assert "owns unbuilt register row R1" in rows[0]["reasons"]


def test_stale_keystone_built_row_does_not_count(tmp_path):
    task(tmp_path, "T-0010", status="captured", created="2026-09-01T00:00:00Z")
    register_doc(tmp_path, [{"id": "R1", "owner": "T-0010", "status": "built"}])
    assert dr.stale_keystones(tmp_path, days=3, now=NOW) == []


def test_stale_keystone_by_arc_field_and_by_name(tmp_path):
    arc(tmp_path, "my-arc", "arc-088", "my-arc", keystone_task="T-0020")
    task(tmp_path, "T-0020", status="captured", created="2026-09-30T00:00:00Z")
    task(tmp_path, "T-0021", status="captured", arc_id="arc-088",
         name="arc-088 S1: first vertical slice", created="2026-09-30T00:00:00Z")
    task(tmp_path, "T-0022", status="captured", arc_id="arc-088",
         name="arc-088 S4: a later slice", created="2026-09-30T00:00:00Z")
    rows = {r["task_id"]: r for r in dr.stale_keystones(tmp_path, days=3, now=NOW)}
    assert set(rows) == {"T-0020", "T-0021"}
    assert rows["T-0020"]["arc"] == "my-arc"
    assert any("keystone_task" in x for x in rows["T-0020"]["reasons"])


def test_stale_keystone_uses_last_demotion_not_created(tmp_path):
    """A task created long ago but demoted back to captured yesterday is not stale."""
    body = ("## Updates\n\n### 2026-09-01T00:00:00Z — status-update [x]\n"
            "- **Change:** status: captured → started-work\n\n"
            "### 2026-10-09T12:00:00Z — status-update [x]\n"
            "- **Change:** status: started-work → captured\n")
    task(tmp_path, "T-0030", status="captured", created="2026-08-01T00:00:00Z", body=body)
    register_doc(tmp_path, [{"id": "R1", "owner": "T-0030"}])
    assert dr.stale_keystones(tmp_path, days=3, now=NOW) == []


def test_stale_keystone_cli_exit_codes(tmp_path):
    register_doc(tmp_path, [{"id": "R1", "owner": "T-0010"}])
    task(tmp_path, "T-0010", status="captured", created="2020-01-01T00:00:00Z")
    r = cli(tmp_path, "stale-keystones")
    assert r.returncode == 1 and "T-0010: captured" in r.stdout
    task(tmp_path, "T-0010", status="started-work", created="2020-01-01T00:00:00Z")
    assert cli(tmp_path, "stale-keystones").returncode == 0


# ---------------------------------------------------------------- close gate: self-deferral

def _t3691(root: Path) -> Path:
    d = root / ".tasks" / "active"
    d.mkdir(parents=True, exist_ok=True)
    dst = d / "T-3691-design-conformance-gate.md"
    shutil.copy(T3691_FIXTURE, dst)
    return dst


def test_self_deferral_reproduces_t3691(tmp_path):
    """T-3691 as it closed: T-3692 existed but was an unrelated bug, T-3693 did
    not exist yet. Both must be refused."""
    f = _t3691(tmp_path)
    task(tmp_path, "T-3692", status="captured",
         name="Dispatched workers cannot read the project's sidecar inbox")
    r = cli(tmp_path, "self-deferral", str(f))
    assert r.returncode == 1
    assert "T-3693 does not exist" in r.stdout
    assert "T-3692 never mentions T-3691" in r.stdout


def test_self_deferral_t3691_control_with_real_owners(tmp_path):
    """Same text; both targets exist, are active, and name T-3691 → passes."""
    f = _t3691(tmp_path)
    task(tmp_path, "T-3692", status="captured", body="Finishes T-3691 item 3.")
    task(tmp_path, "T-3693", status="captured", body="Finishes T-3691 item 5.")
    # T-3691's AC text names T-3396/T-3397/T-3561/T-3684..T-3690 without deferring to
    # them; none of those exist here, so a pass also proves they are not misread.
    r = cli(tmp_path, "self-deferral", str(f))
    assert r.returncode == 0, r.stdout


def test_self_deferral_completed_target_refused(tmp_path):
    f = task(tmp_path, "T-0100", body="## Recommendation\n\nRemaining work deferred to T-0101.\n")
    task(tmp_path, "T-0101", loc="completed", status="work-completed", body="picks up T-0100")
    r = cli(tmp_path, "self-deferral", str(f))
    assert r.returncode == 1 and "T-0101 is not active" in r.stdout


def test_self_deferral_ignores_context_and_fenced_code(tmp_path):
    """A Context line describing another task's deferral is a finding, not a
    deferral by this task (T-3694's own description is exactly that); a fenced
    command block is not prose."""
    body = ("## Context\n\nT-0200 deferred its items to T-0404.\n\n"
            "## Recommendation\n\nGO.\n\n```\nfw x  # deferred to T-0405\n```\n")
    f = task(tmp_path, "T-0100", body=body)
    assert cli(tmp_path, "self-deferral", str(f)).returncode == 0


@pytest.mark.parametrize("prose", [
    "Remaining work deferred to `T-0404`.",                  # inline code
    "Remaining work is deferred to\nT-0404 for later.",     # wrapped line
    "Remaining work deferred to [T-0404](/tasks/T-0404).",   # markdown link
    "Remaining work deferred to **T-0404**.",                # emphasis
])
def test_self_deferral_formatting_does_not_hide_target(tmp_path, prose):
    """T-3694 review finding: backticks and line wraps used to hide the target."""
    f = task(tmp_path, "T-0100", body=f"## Recommendation\n\n{prose}\n")
    r = cli(tmp_path, "self-deferral", str(f))
    assert r.returncode == 1 and "T-0404 does not exist" in r.stdout


def test_self_deferral_ignores_h1_title_naming_parent(tmp_path):
    """T-3793: T-3791 was titled 'T-3790 follow-up: …' and refused because T-3790
    was completed. The title names the parent, not a deferral; the same sentence in
    the task's own result is still a deferral."""
    task(tmp_path, "T-0101", loc="completed", status="work-completed")
    p = tmp_path / ".tasks" / "active" / "T-0100-fixture.md"
    task(tmp_path, "T-0100")
    p.write_text(p.read_text().replace("# T-0100\n", "# T-0100: T-0101 follow-up: close its gaps\n"))
    assert cli(tmp_path, "self-deferral", str(p)).returncode == 0
    p.write_text(p.read_text() + "\n## Recommendation\n\nT-0101 follow-up remains.\n")
    r = cli(tmp_path, "self-deferral", str(p))
    assert r.returncode == 1 and "T-0101 is not active" in r.stdout


def test_self_deferral_list_items_stay_separate(tmp_path):
    """Joining wrapped lines must not glue a list item onto the next one."""
    body = "## Evolution\n\n- Scope was deferred to later in this task.\n- T-0404 is cited as evidence.\n"
    f = task(tmp_path, "T-0100", body=body)
    assert cli(tmp_path, "self-deferral", str(f)).returncode == 0


# ---------------------------------------------------------------- close gate: register

def test_close_check_resolves_arc_by_id_not_filename(tmp_path):
    """arc-011 lives in parallel-execution-aef.yaml; the T-3691 gate looked only
    for arc-011.yaml / 011.yaml and so never fired for it."""
    register_doc(tmp_path, [{"id": "R7", "owner": "null"}], rel="docs/architecture/side.md")
    arc(tmp_path, "parallel-thing", "arc-011", "parallel-thing",
        register_docs=["docs/architecture/side.md"])
    f = task(tmp_path, "T-0300", arc_id="arc-011", body="## Scope\n\nR7 deferred.\n")
    r = cli(tmp_path, "close-check", str(f))
    assert r.returncode == 1 and "R7: deferred here but has no owner_task" in r.stdout


def test_close_check_refuses_owner_closing_on_unbuilt_row(tmp_path):
    register_doc(tmp_path, [{"id": "R6", "owner": "T-0400", "status": "partial"}])
    f = task(tmp_path, "T-0400")
    r = cli(tmp_path, "close-check", str(f))
    assert r.returncode == 1 and "R6: owned by T-0400 and still 'partial'" in r.stdout
    register_doc(tmp_path, [{"id": "R6", "owner": "T-0400", "status": "built"}])
    assert cli(tmp_path, "close-check", str(f)).returncode == 0


# ---------------------------------------------------------------- /approvals line

@pytest.fixture()
def client():
    sys.path.insert(0, str(REPO))
    from web.app import app
    app.config["TESTING"] = True
    return app.test_client()


def _stale_root(root: Path, created: str) -> None:
    arc(root, "fx-arc", "arc-099", "fx-arc")
    task(root, "T-0500", status="captured", arc_id="arc-099",
         name="fx-arc S1: keystone fixture", created=created)
    register_doc(root, [{"id": "R1", "owner": "T-0500"}])


def test_approvals_renders_stale_keystone(client, tmp_path, monkeypatch):
    """Real loader + real predicate + real template, against a fixture root."""
    import web.blueprints.approvals as ap
    _stale_root(tmp_path, (datetime.now(timezone.utc) - timedelta(days=5)).strftime("%Y-%m-%dT%H:%M:%SZ"))
    monkeypatch.setattr(ap, "PROJECT_ROOT", tmp_path)
    html = client.get("/approvals/content").get_data(as_text=True)
    assert 'id="section-stale-keystones"' in html
    assert 'href="/tasks/T-0500"' in html
    assert "captured 5 days" in html
    assert 'href="/arcs/fx-arc"' in html
    assert "owns unbuilt register row R1" in html


def test_approvals_no_section_when_fresh(client, tmp_path, monkeypatch):
    import web.blueprints.approvals as ap
    _stale_root(tmp_path, (datetime.now(timezone.utc) - timedelta(days=1)).strftime("%Y-%m-%dT%H:%M:%SZ"))
    monkeypatch.setattr(ap, "PROJECT_ROOT", tmp_path)
    html = client.get("/approvals/content").get_data(as_text=True)
    assert "section-stale-keystones" not in html
