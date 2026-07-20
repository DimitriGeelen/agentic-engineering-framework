"""T-2577 (T-2571 S4): save-time ghost documentation-task minting.

The operator's "in parallel create a task to document the workflow" leg:
first sighting of a ghost at /api/save mints a task through the gated writer
(FW_TASK_ORIGIN=designer-ghost). Idempotent per uuid via ghost["task"];
non-fatal by contract (a failed mint never breaks the save).
"""

import json

import pytest

import web.blueprints.designer_api as designer_api
from web.designer_registry import load_registry, mint_ghost_tasks, save_registry

from tests.web.test_designer_registry_ghosts import bpmn_with_links

GHOST_UUID = "55555555-5555-4555-8555-555555555555"


@pytest.fixture()
def client(monkeypatch, tmp_path):
    store = tmp_path / "projects"
    monkeypatch.setattr(designer_api, "_STORE", store)
    from web.app import app

    app.config["TESTING"] = True
    return app.test_client(), store


def _seed_ghost_registry(store):
    store.mkdir(parents=True, exist_ok=True)
    save_registry(store, {
        "ghosts": [{
            "uuid": GHOST_UUID,
            "name": "future-flow",
            "referenced_by": [{"id": "referrer", "node": "n1", "nodeName": "go"}],
            "task": None,
            "first_seen": 1,
        }],
        "claims": [],
    })


class Recorder:
    def __init__(self, rc=0, out="ID: T-9001\nFile: /tmp/t.md\n"):
        self.calls = []
        self.rc, self.out = rc, out

    def __call__(self, args):
        self.calls.append(args)
        return self.rc, self.out


def test_mint_on_first_sighting_sets_task_and_persists(tmp_path):
    store = tmp_path / "projects"
    _seed_ghost_registry(store)
    r = Recorder()
    minted = mint_ghost_tasks(store, runner=r)
    assert minted == [{"uuid": GHOST_UUID, "task": "T-9001"}]
    assert len(r.calls) == 1
    args = r.calls[0]
    # gate-shape contract: human-owned, captured (no --start), never focus-stealing
    assert args[args.index("--owner") + 1] == "human"
    assert args[args.index("--horizon") + 1] == "later"
    assert "--start" not in args
    # body names the ghost and its referrers
    desc = args[args.index("--description") + 1]
    assert GHOST_UUID in desc and "referrer:n1" in desc
    assert "future-flow" in args[args.index("--name") + 1]
    # persisted: the registry now carries the T-ID
    assert load_registry(store)["ghosts"][0]["task"] == "T-9001"


def test_mint_is_idempotent_per_uuid(tmp_path):
    store = tmp_path / "projects"
    _seed_ghost_registry(store)
    mint_ghost_tasks(store, runner=Recorder())
    r2 = Recorder()
    assert mint_ghost_tasks(store, runner=r2) == []
    assert r2.calls == []  # already minted — never called again


def test_failed_mint_leaves_task_null(tmp_path):
    store = tmp_path / "projects"
    _seed_ghost_registry(store)
    assert mint_ghost_tasks(store, runner=Recorder(rc=1, out="BLOCKED")) == []
    assert load_registry(store)["ghosts"][0]["task"] is None


def test_unparseable_create_output_leaves_task_null(tmp_path):
    store = tmp_path / "projects"
    _seed_ghost_registry(store)
    assert mint_ghost_tasks(store, runner=Recorder(out="something weird")) == []
    assert load_registry(store)["ghosts"][0]["task"] is None


def test_save_triggers_minting(client, monkeypatch):
    c, store = client
    seen = []
    monkeypatch.setattr(designer_api, "mint_ghost_tasks", lambda s: seen.append(s))
    r = c.post("/api/save", json={
        "id": "referrer",
        "bpmn": bpmn_with_links(
            ("n1", "go", f'<aef:link workflowRef="{GHOST_UUID}" name="future-flow"/>')
        ),
    })
    assert r.status_code == 200
    assert seen == [store]


def test_mint_failure_is_nonfatal_to_save(client, monkeypatch):
    c, store = client

    def boom(s):
        raise RuntimeError("gate exploded")

    monkeypatch.setattr(designer_api, "mint_ghost_tasks", boom)
    r = c.post("/api/save", json={
        "id": "referrer",
        "bpmn": bpmn_with_links(
            ("n1", "go", f'<aef:link workflowRef="{GHOST_UUID}" name="future-flow"/>')
        ),
    })
    assert r.status_code == 200  # save survives
    # ghost persisted with task:null — audit sweep's job from here
    g = load_registry(store)["ghosts"][0]
    assert g["uuid"] == GHOST_UUID and g["task"] is None
