"""T-5227: the inception lifecycle map with instances.

Covers each Agent criterion against fixture inceptions in tmp roots:
  1. the map aef-inception-lifecycle exists, validates (corpus validator + 832's pinned
     validator: no errors) and carries exactly the Goal's state nodes;
  2. waiting_on / revisit_at: filing defaults (+7 days), invalid values refused, refused on
     non-inceptions — create-task.sh, fw inception start, the Write/Edit hook, the wait verb;
  3. /api/instances?template=aef-inception-lifecycle places a fixture in every node, gives
     NO-POSITION for an unplaceable one and validates against runtime-projection v2 (the
     T-5193 schema checks, reused);
  4. the daily routing: agent -> handover, peer -> reminder item, operator -> fw operator
     pending + the approvals page with no decide link; plus the audit section;
  5. fw inception lifecycle --json: per-node counts, median days in step, overdue counts.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

import lib.inception_lifecycle as il  # noqa: E402
import web.blueprints.designer as designer  # noqa: E402
import web.blueprints.designer_api as designer_api  # noqa: E402
from tests.unit import test_t5193_runtime_projection_v2 as v2  # noqa: E402

MAP_DIR = ROOT / ".context/designer/projects" / il.MAP_ID
TODAY = datetime.now(timezone.utc).date()  # fixtures are relative, so routing reads live dates


def _d(days):
    return (TODAY + timedelta(days=days)).isoformat()


CREATED = _d(-17) + "T00:00:00Z"
GOAL_NODES = {"il_wait_agent", "il_wait_peer", "il_wait_operator", "il_ready",
              "il_awaiting_decision", "il_go_building", "il_decided", "il_closed"}


# ── fixtures ───────────────────────────────────────────────────────────────────────────


def _inception(d, tid, *, status="started-work", rec="EXPLORING", decision="", waiting=None,
               revisit=None, questions="", extra_fm="", history="", created=None):
    created = created or CREATED
    fm = [f"id: {tid}", f"name: \"Question {tid}\"", f"status: {status}",
          "workflow_type: inception", "owner: agent", "horizon: now",
          "related_tasks: []", f"created: {created}", f"last_update: {created}"]
    if waiting is not None:
        fm.append(f"waiting_on: {waiting}")
    if revisit is not None:
        fm.append(f"revisit_at: {revisit}")
    if extra_fm:
        fm.append(extra_fm)
    body = f"# {tid}\n\n## Open Questions\n\n{questions}\n" if questions else f"# {tid}\n\n"
    body += f"## Recommendation\n\n**Recommendation:** {rec}\n\n**Rationale:** because\n\n"
    body += "## Decision\n\n" + (f"**Decision**: {decision}\n\n" if decision else "")
    body += f"## Updates\n\n### {created} — task-created [task-create-agent]\n- **Action:** Created\n{history}"
    p = d / f"{tid}-q.md"
    p.write_text("---\n" + "\n".join(fm) + "\n---\n" + body)
    return p


def _build(d, tid, related):
    (d / f"{tid}-b.md").write_text(
        f"---\nid: {tid}\nname: build slice\nstatus: started-work\nworkflow_type: build\n"
        f"owner: agent\nhorizon: now\nrelated_tasks: [{related}]\n---\n# {tid}\n")


DISPOSED = ("- **IW-1: does it work?**\n  disposition: answered\n  rationale: measured\n")
OPEN_Q = "- **IW-1: does it work?**\n"


def _populate(root):
    a, c = root / ".tasks/active", root / ".tasks/completed"
    _inception(a, "T-101", waiting="agent", revisit=_d(-8), questions=OPEN_Q)
    _inception(a, "T-102", waiting="peer", revisit=_d(-1), questions=OPEN_Q)
    _inception(a, "T-103", waiting="operator", revisit=_d(0), questions=OPEN_Q)
    _inception(a, "T-104", questions=DISPOSED, revisit=_d(12))                    # ready
    _inception(a, "T-105", rec="GO")                                               # awaiting
    _inception(a, "T-106", rec="GO", decision="GO")                                # GO, active
    _inception(a, "T-107", rec="DEFER", decision="DEFER", status="captured")       # decided
    _inception(c, "T-108", status="work-completed", rec="GO", decision="GO")       # GO, builds open
    _build(a, "T-120", "T-108")
    _inception(c, "T-109", status="work-completed", rec="NO-GO", decision="NO-GO")  # closed
    _inception(a, "T-110", waiting="banana", questions=OPEN_Q)                     # NO-POSITION
    _inception(a, "T-111", waiting="agent", revisit=_d(13), questions=OPEN_Q)  # not due
    _inception(a, "T-112", questions=OPEN_Q)  # no fields: waiting_on agent, revisit created + 7
    (a / "T-199-bad.md").write_text("no frontmatter\n")


@pytest.fixture()
def root(tmp_path):
    for d in (".tasks/active", ".tasks/completed", ".context/working"):
        (tmp_path / d).mkdir(parents=True)
    _populate(tmp_path)
    return tmp_path


# ── 1. the map ─────────────────────────────────────────────────────────────────────────


def _spec():
    import importlib.util

    spec = importlib.util.spec_from_file_location("corpus_spec", ROOT / "tools/corpus_spec.py")
    cs = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(cs)
    latest = json.loads((MAP_DIR / "meta.json").read_text())["latest"]
    return cs.parse_map((MAP_DIR / f"v{latest}.bpmn").read_text()), latest


def test_map_node_set_matches_goal_and_table():
    spec, _ = _spec()
    carriers = {n["uid"] for n in spec["nodes"] if (n.get("meta") or {}).get("state")}
    assert carriers == GOAL_NODES
    assert set(il.NODES.values()) == GOAL_NODES == set(il.NODE_ORDER)
    assert all(f.get("uid") for f in spec["flows"])
    # the three waiting steps sit in three different lanes (agent / peer / operator)
    lane = {n["uid"]: n.get("lane") for n in spec["nodes"]}
    assert len({lane["il_wait_agent"], lane["il_wait_peer"], lane["il_wait_operator"]}) == 3


def test_map_validates():
    r = subprocess.run([str(ROOT / "bin/fw"), "corpus", "validate", il.MAP_ID],
                       cwd=ROOT, capture_output=True, text=True, timeout=120)
    assert r.returncode == 0, r.stdout + r.stderr
    mod, why = designer_api._load_validator()
    if mod is None:
        pytest.skip(f"832 validator unavailable: {why}")
    _, latest = _spec()
    findings = mod.run_xml((MAP_DIR / f"v{latest}.bpmn").read_text())
    assert not [f for f in findings if f.severity == "ERROR"], [f.message for f in findings]


# ── 2. fields ──────────────────────────────────────────────────────────────────────────


@pytest.mark.parametrize("wf,wait,rev,ok", [
    ("inception", "agent", "2026-11-25", True),
    ("inception", "peer", None, True),
    ("inception", "operator", None, True),
    ("inception", "banana", None, False),
    ("inception", None, "2026-13-01", False),
    ("inception", None, "next week", False),
    ("build", "agent", None, False),
    ("build", None, "2026-11-25", False),
    ("build", None, None, True),
])
def test_validate_fields(wf, wait, rev, ok):
    assert (il.validate_fields(wf, wait, rev) == []) is ok


def _project(tmp_path):
    for d in (".tasks/active", ".tasks/completed", ".tasks/templates", ".context/working",
              ".context/locks"):
        (tmp_path / d).mkdir(parents=True, exist_ok=True)
    for t in (ROOT / ".tasks/templates").glob("*.md"):
        (tmp_path / ".tasks/templates" / t.name).write_text(t.read_text())
    subprocess.run(["git", "init", "-q"], cwd=tmp_path, check=True)
    env = {k: v for k, v in os.environ.items()
           if k not in ("CLAUDECODE", "AI_AGENT", "FW_ALLOW_EMPTY_RECOMMENDATION")}
    env.update(TASKS_DIR=str(tmp_path / ".tasks"), PROJECT_ROOT=str(tmp_path),
               CONTEXT_DIR=str(tmp_path / ".context"), FRAMEWORK_ROOT=str(ROOT))
    return env


def _create(tmp_path, env, *args):
    return subprocess.run(["bash", str(ROOT / "agents/task-create/create-task.sh"), *args],
                          cwd=tmp_path, env=env, capture_output=True, text=True, timeout=120)


def _fm(path):
    head = path.read_text().split("\n---\n", 1)[0]
    return dict(re.findall(r"^(waiting_on|revisit_at|created):[ \t]*(.*)$", head, re.M))


def test_filing_defaults_and_refusals(tmp_path):
    env = _project(tmp_path)
    r = _create(tmp_path, env, "--name", "Q default", "--description", "d", "--type", "inception",
                "--owner", "agent")
    assert r.returncode == 0, r.stderr
    (f,) = (tmp_path / ".tasks/active").glob("T-*.md")
    fm = _fm(f)
    filed = date.fromisoformat(fm["created"].strip("'\"")[:10])
    assert fm["waiting_on"] == "agent"
    assert date.fromisoformat(fm["revisit_at"]) == filed.fromordinal(filed.toordinal() + 7)
    f.unlink()

    r = _create(tmp_path, env, "--name", "Q peer", "--description", "d", "--type", "inception",
                "--owner", "agent", "--waiting-on", "peer", "--revisit-at", "2026-12-24")
    assert r.returncode == 0, r.stderr
    (f,) = (tmp_path / ".tasks/active").glob("T-*.md")
    assert _fm(f) | {"created": ""} == {"waiting_on": "peer", "revisit_at": "2026-12-24", "created": ""}
    f.unlink()

    for args in (["--type", "inception", "--waiting-on", "banana"],
                 ["--type", "inception", "--revisit-at", "2026-13-01"],
                 ["--type", "build", "--waiting-on", "agent"],
                 ["--type", "build", "--revisit-at", "2026-12-01"]):
        r = _create(tmp_path, env, "--name", "X", "--description", "d", "--owner", "agent", *args)
        assert r.returncode != 0, args
        assert not list((tmp_path / ".tasks/active").glob("T-*.md")), args

    # a build task carries neither field
    r = _create(tmp_path, env, "--name", "B", "--description", "d", "--type", "build", "--owner", "agent")
    assert r.returncode == 0, r.stderr
    (f,) = (tmp_path / ".tasks/active").glob("T-*.md")
    assert "waiting_on" not in _fm(f) and "revisit_at" not in _fm(f)


def test_inception_start_forwards_fields(tmp_path):
    env = _project(tmp_path)
    r = subprocess.run(
        ["bash", "-c", 'AGENTS_DIR="$FRAMEWORK_ROOT/agents"; source "$FRAMEWORK_ROOT/lib/colors.sh" 2>/dev/null; '
         'source "$FRAMEWORK_ROOT/lib/inception.sh"; '
         'do_inception_start "Q via start" --i-am-human --rationale r --waiting-on operator'],
        cwd=tmp_path, env=env, capture_output=True, text=True, timeout=120)
    files = list((tmp_path / ".tasks/active").glob("T-*.md"))
    assert files, r.stdout + r.stderr
    assert _fm(files[0])["waiting_on"] == "operator"


def _hook(tmp_path, file_path, old, new):
    p = Path(file_path)
    p.write_text(old)
    payload = {"tool_name": "Edit", "cwd": str(tmp_path),
               "tool_input": {"file_path": str(p), "old_string": old, "new_string": new}}
    env = {**os.environ, "PROJECT_ROOT": str(tmp_path), "CLAUDECODE": "1"}
    env.pop("FW_ALLOW_INCEPTION_SCHEMA_DRIFT", None)
    return subprocess.run([sys.executable, str(ROOT / "agents/context/check-inception-schema.py")],
                          input=json.dumps(payload), env=env, capture_output=True, text=True,
                          timeout=60)


INC = ("---\nid: T-1\nname: q\nstatus: captured\nworkflow_type: inception\n"
       "target_blast_radius: 3\nvoi_score: 0.5\nWAIT---\n# T-1\n")
BLD = "---\nid: T-2\nname: b\nstatus: captured\nworkflow_type: build\nWAIT---\n# T-2\n"


@pytest.mark.parametrize("tmpl,new_fields,rc", [
    (INC, "waiting_on: peer\nrevisit_at: 2026-12-01\n", 0),
    (INC, "waiting_on: operator\n", 0),
    (INC, "waiting_on: banana\n", 2),
    (INC, "revisit_at: 01-12-2026\n", 2),
    (BLD, "waiting_on: agent\n", 2),
    (BLD, "revisit_at: 2026-12-01\n", 2),
])
def test_write_edit_hook(tmp_path, tmpl, new_fields, rc):
    d = tmp_path / ".tasks/active"
    d.mkdir(parents=True)
    r = _hook(tmp_path, d / "T-1-x.md", tmpl.replace("WAIT", ""), tmpl.replace("WAIT", new_fields))
    assert r.returncode == rc, r.stderr


def test_hook_leaves_unrelated_edits_alone(tmp_path):
    """A legacy file holding a bad value is not held on an edit that does not touch it."""
    d = tmp_path / ".tasks/active"
    d.mkdir(parents=True)
    old = INC.replace("WAIT", "waiting_on: banana\n")
    r = _hook(tmp_path, d / "T-1-x.md", old, old.replace("# T-1", "# T-1 edited"))
    assert r.returncode == 0, r.stderr


def test_wait_verb_sets_fields_and_entered_at(root):
    f = root / ".tasks/active/T-112-q.md"
    when = il.set_wait(f, "peer", None, now=il.datetime(2026, 11, 18, 9, tzinfo=il.timezone.utc))
    assert when == "2026-11-25"
    text = f.read_text()
    assert "waiting_on: peer" in text and "revisit_at: 2026-11-25" in text
    assert "- **Change:** waiting_on: agent → peer" in text
    row = {r["task"]: r for r in il.instances(root, TODAY)[0]}["T-112"]
    assert row["node"] == "il_wait_peer" and row["entered_at"] == "2026-11-18T09:00:00Z"
    assert row["entered_source"] == "step_entered_at"
    with pytest.raises(ValueError):
        il.set_wait(f, "banana")
    with pytest.raises(ValueError):
        il.set_wait(root / ".tasks/active/T-120-b.md", "agent")


# ── 3. /api/instances ──────────────────────────────────────────────────────────────────


@pytest.fixture()
def client(monkeypatch, root):
    store = root / ".context/designer/projects"
    store.mkdir(parents=True)
    d = store / il.MAP_ID
    d.mkdir()
    for f in ("meta.json", "v1.bpmn"):
        (d / f).write_text((MAP_DIR / f).read_text())
    monkeypatch.setattr(designer_api, "_STORE", store)
    monkeypatch.setattr(designer_api, "PROJECT_ROOT", root)
    monkeypatch.setattr(designer, "PROJECT_ROOT", root)
    from web.app import app

    app.config["TESTING"] = True
    return app.test_client()


EXPECTED = {"T-101": "il_wait_agent", "T-102": "il_wait_peer", "T-103": "il_wait_operator",
            "T-104": "il_ready", "T-105": "il_awaiting_decision", "T-106": "il_go_building",
            "T-107": "il_decided", "T-108": "il_go_building", "T-110": None,
            "T-111": "il_wait_agent", "T-112": "il_wait_agent"}


def test_instances_place_every_node_and_validate(client):
    j = v2._check(client.get(f"/api/instances?template={il.MAP_ID}"), "GET /api/instances")
    got = {i["task"]: (i["state"], i["node"]) for i in j["instances"]}
    assert {t: n for t, (_, n) in got.items()} == EXPECTED
    assert got["T-110"] == ("NO-POSITION", None)
    assert all(s == "NODE" for t, (s, _) in got.items() if t != "T-110")
    assert set(EXPECTED.values()) - {None} == GOAL_NODES - {"il_closed"}
    assert "T-109" not in got and "T-120" not in got  # closed / non-inception never served
    assert j["unplaced"] == [{"task": "T-199-bad.md", "reason": "no frontmatter"}]
    assert j["runtime_projection_version"] == 2 and j["refusals"] == []
    assert all(i["traversed"] == [] and i["unmapped"] == [] for i in j["instances"])


def test_instances_stale_when_map_lacks_the_node(client, root):
    p = root / ".context/designer/projects" / il.MAP_ID / "v1.bpmn"
    p.write_text(p.read_text().replace('value="il_wait_peer"', 'value="il_wait_peer_gone"'))
    j = v2._check(client.get(f"/api/instances?template={il.MAP_ID}"), "GET /api/instances")
    assert {i["task"]: i["state"] for i in j["instances"]}["T-102"] == "STALE"


def test_overlay_badges_validate_and_overdue_is_alert(client):
    j = v2._check(client.get(f"/api/overlay?id={il.MAP_ID}"), "GET /api/overlay")
    sev = {n["uid"]: n["severity"] for n in j["nodes"]}
    assert sev["il_wait_agent"] == sev["il_wait_peer"] == sev["il_wait_operator"] == "alert"
    assert sev["il_ready"] != "alert" and "il_closed" not in sev


def test_schema_control_inception_node_must_be_in_enum(client):
    body = json.loads(client.get(f"/api/instances?template={il.MAP_ID}").get_data(as_text=True))
    v = v2._validator("GET /api/instances", 200)
    assert not list(v.iter_errors(body))
    body["instances"][0]["node"] = "il_closed"  # never served: not in the enum
    assert list(v.iter_errors(body))


def test_live_repo_inception_instances_validate():
    from web.app import app

    j = v2._check(app.test_client().get(f"/api/instances?template={il.MAP_ID}"), "GET /api/instances")
    assert all(i["node"] in GOAL_NODES or i["state"] == "NO-POSITION" for i in j["instances"])


# ── 4. routing ─────────────────────────────────────────────────────────────────────────


def test_overdue_by_owner(root):
    by = il.overdue_by_owner(root, TODAY)
    assert [r["task"] for r in by["agent"]] == ["T-112", "T-101"]  # by revisit date; T-112: created + 7
    assert [r["task"] for r in by["peer"]] == ["T-102"]
    assert [r["task"] for r in by["operator"]] == ["T-103"]


def test_handover_lists_agent_and_peer(root):
    md = il.handover_md(root, TODAY)
    agent, peer = md.split("## Overdue Inceptions — Remind the Peer")
    assert "Next Actions for the Agent" in agent and "T-101" in agent and "T-112" in agent
    assert "T-102" in peer and "fw sidecar send" in peer
    assert "T-103" not in md.replace("1 overdue inception question(s)", "")
    assert "fw operator pending" in md
    assert il.handover_md(root, TODAY - timedelta(days=30)) == ""


def test_handover_script_includes_the_section():
    text = (ROOT / "agents/handover/handover.sh").read_text()
    assert "inception_lifecycle.py" in text and "--handover" in text


def test_operator_pending_lists_question_without_decide_link(root):
    env = {**os.environ, "PROJECT_ROOT": str(root), "FRAMEWORK_ROOT": str(ROOT)}
    r = subprocess.run([sys.executable, str(ROOT / "lib/operator_pending.py"), "pending", "--json"],
                       env=env, capture_output=True, text=True, timeout=120)
    data = json.loads(r.stdout)
    assert [x["id"] for x in data["inception_questions"]] == ["T-103"]
    assert "/inception/" not in data["inception_questions"][0]["path"]
    # EXPLORING inceptions are not in the decision list (decide refuses them)
    assert {i["id"] for i in data["inceptions"]} == {"T-105"}
    r = subprocess.run([sys.executable, str(ROOT / "lib/operator_pending.py"), "pending"],
                       env=env, capture_output=True, text=True, timeout=120)
    assert "Questions waiting for you" in r.stdout
    line = next(ln for ln in r.stdout.splitlines() if "T-103" in ln)
    assert "/inception/" not in line and "decide" not in line
    assert "T-101" not in r.stdout and "T-102" not in r.stdout


def test_approvals_page_shows_questions_without_decide_link(monkeypatch, root):
    from web.blueprints import approvals
    from web.app import app

    monkeypatch.setattr(approvals, "PROJECT_ROOT", root)
    assert [q["task_id"] for q in approvals._load_inception_questions()] == ["T-103"]
    app.config["TESTING"] = True
    html = app.test_client().get("/approvals/content").get_data(as_text=True)
    sec = html.split('id="section-inception-questions"', 1)[1].split("</ul>", 1)[0]
    assert "Questions waiting for you" in sec and 'href="/tasks/T-103"' in sec
    assert "T-101" not in sec and "T-102" not in sec
    assert "/inception/" not in sec and "decide" not in sec.lower()


def test_audit_section_routes_by_owner():
    text = (ROOT / "agents/audit/audit.sh").read_text()
    sec = text.split("C-006c (T-5227)", 1)[1].split('fi # end oe-research', 1)[0]
    for owner in ("agent", "peer", "operator"):
        assert owner in sec
    assert "--overdue" in sec


def test_revisit_scan_skips_routed_inceptions(root):
    env = {**os.environ, "PROJECT_ROOT": str(root)}
    subprocess.run(["bash", str(ROOT / "agents/context/revisit-due-scan.sh")], env=env,
                   capture_output=True, text=True, timeout=60)
    due = root / ".context/working/.revisits-due.txt"
    text = due.read_text() if due.exists() else ""
    assert "T-101" not in text and "T-102" not in text


# ── 5. measurement ─────────────────────────────────────────────────────────────────────


def test_lifecycle_json(root):
    r = subprocess.run([sys.executable, str(ROOT / "lib/inception_lifecycle.py"), "--json",
                        "--root", str(root), "--today", TODAY.isoformat()],
                       capture_output=True, text=True, timeout=120)
    s = json.loads(r.stdout)
    by = {n["node"]: n for n in s["nodes"]}
    assert [n["node"] for n in s["nodes"]] == list(il.NODE_ORDER)
    assert {k: v["count"] for k, v in by.items()} == {
        "il_wait_agent": 3, "il_wait_peer": 1, "il_wait_operator": 1, "il_ready": 1,
        "il_awaiting_decision": 1, "il_go_building": 2, "il_decided": 1, "il_closed": 1}
    assert {k: v["overdue"] for k, v in by.items() if v["overdue"]} == {
        "il_wait_agent": 2, "il_wait_peer": 1, "il_wait_operator": 1}
    # created 17 days ago, no step event: 17 days in step for each fixture
    assert by["il_wait_agent"]["median_days_in_step"] == 17.0
    assert s["no_position"] == [{"task": "T-110", "reason": "waiting_on 'banana' is not agent, peer or operator"}]
    assert s["overdue"] == 4


def test_entered_at_from_history(root):
    a = root / ".tasks/active"
    _inception(a, "T-130", rec="GO", history=(
        f"\n### {_d(-8)}T08:00:00Z — status-update [task-update-agent]\n"
        "- **Change:** status: captured → started-work\n"))
    row = {r["task"]: r for r in il.instances(root, TODAY)[0]}["T-130"]
    assert row["entered_at"] == f"{_d(-8)}T08:00:00Z" and row["entered_source"] == "history"
    assert row["days_in_step"] == 7.7


def test_fw_inception_lifecycle_cli(root):
    env = {**os.environ, "PROJECT_ROOT": str(root)}
    r = subprocess.run([str(ROOT / "bin/fw"), "inception", "lifecycle", "--json"], cwd=root,
                       env=env, capture_output=True, text=True, timeout=120)
    assert r.returncode == 0, r.stderr
    assert {n["node"] for n in json.loads(r.stdout)["nodes"]} == GOAL_NODES
    r = subprocess.run([str(ROOT / "bin/fw"), "inception", "lifecycle"], cwd=root, env=env,
                       capture_output=True, text=True, timeout=120)
    assert "median days" in r.stdout and "waiting on a peer" in r.stdout
