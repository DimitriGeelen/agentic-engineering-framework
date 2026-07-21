"""T-2579: off-page seam lifecycle composition test (T-2571 S1-S6 end-to-end).

Walks the whole contract-v0 loop against the real modules — compiler Pass-5,
designer_api save/list, designer_registry sync/mint/claim, /designer/ghosts —
in one hermetic temp store. Each slice has isolated tests; THIS test pins that
they compose: the same uuid threads compile-WARN → ghost → minted doc task →
visibility → claim → silence. It is the AEF-side harness 832's pair-draft #3
exemplar (resolved + ghost + legacy legs) drops into when it lands.
"""

import json
import os
import sys

import pytest

import web.blueprints.designer_api as designer_api
from web.designer_registry import claim_ghost, load_registry, mint_ghost_tasks

from tests.web.test_designer_registry_ghosts import PLAIN, bpmn_with_links

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO_ROOT, "tools"))

import bpmn_to_tasks  # noqa: E402

GHOST_UUID = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"

REFERRER_BPMN = bpmn_with_links(
    ("n1", "escalate", f'<aef:link workflowRef="{GHOST_UUID}" name="escalation handling"/>'),
    ("n2", "archive", '<aef:link targetWorkflow="mail-archive"/>'),
)


@pytest.fixture()
def env(monkeypatch, tmp_path):
    store = tmp_path / "projects"
    store.mkdir(parents=True)
    monkeypatch.setattr(designer_api, "_STORE", store)
    monkeypatch.setenv("FW_DESIGNER_STORE", str(store))
    from web.app import app

    app.config["TESTING"] = True
    return app.test_client(), store, tmp_path


def _compile_warns(tmp_path, bpmn):
    p = tmp_path / "d.bpmn"
    p.write_text(bpmn)
    _, warnings = bpmn_to_tasks.parse_bpmn(str(p))
    return [w for w in warnings if "T-2576" in w]


def _mint_runner(args):
    return 0, "ID: T-9001\nFile: /tmp/t.md\n"


def test_full_lifecycle(env):
    c, store, tmp_path = env

    # ── Phase 1: pre-save compile — both refs dangle, WARNs name both ends ──
    w5 = _compile_warns(tmp_path, REFERRER_BPMN)
    assert len(w5) == 2
    dangle = next(w for w in w5 if GHOST_UUID in w)
    assert "'n1'" in dangle and "'escalate'" in dangle
    assert "'escalation handling'" in dangle
    assert f"fw bpmn claim {GHOST_UUID}" in dangle
    legacy = next(w for w in w5 if "mail-archive" in w)
    assert "no live workflow matches" in legacy

    # ── Phase 2: save the referrer — ghost captured, doc task minted ──
    r = c.post("/api/save", json={"id": "referrer", "bpmn": REFERRER_BPMN})
    assert r.status_code == 200
    mint_ghost_tasks(store, runner=_mint_runner)
    reg = load_registry(store)
    by_uuid = {g["uuid"]: g for g in reg["ghosts"]}
    ghost = by_uuid[GHOST_UUID]
    assert ghost["referenced_by"] == [
        {"id": "referrer", "node": "n1", "nodeName": "escalate"}
    ]
    assert ghost["task"] == "T-9001"
    # legacy name-only ref got a store-minted ghost too
    assert any(g["name"] == "mail-archive" for g in reg["ghosts"])

    # ── Phase 3: /api/list partitions ghosts out of maps[] ──
    body = c.get("/api/list").get_json()
    assert [m["id"] for m in body["maps"]] == ["referrer"]
    assert GHOST_UUID in {g["uuid"] for g in body["ghosts"]}

    # ── Phase 4: /designer/ghosts renders the card + task chip + reverse count ──
    html = c.get("/designer/ghosts").get_data(as_text=True)
    assert "escalation handling" in html and "ghost — needs mapping" in html
    assert "/tasks/T-9001" in html
    assert f"fw bpmn claim {GHOST_UUID}" in html
    assert "2 unmapped references" in html  # referrer carries both dangling refs

    # ── Phase 5: create targets; claim binds the uuid; legacy leg goes advisory ──
    assert c.post("/api/save", json={"id": "escalation", "bpmn": PLAIN}).status_code == 200
    assert c.post("/api/save", json={"id": "mail-archive", "bpmn": PLAIN}).status_code == 200
    meta_p = store / "escalation" / "meta.json"
    m = json.loads(meta_p.read_text())
    del m["uuid"]  # forward-reference flow: project created AFTER the ref, claims the pinned uuid
    meta_p.write_text(json.dumps(m))
    result = claim_ghost(store, GHOST_UUID, "escalation")
    assert result["resolved_referrers"] == 1
    assert json.loads(meta_p.read_text())["uuid"] == GHOST_UUID

    # ── Phase 6: post-claim compile — uuid ref SILENT, legacy now migrate advisory ──
    w5 = _compile_warns(tmp_path, REFERRER_BPMN)
    assert not any(GHOST_UUID in w for w in w5)  # resolved refs are silent (T-2570)
    legacy = [w for w in w5 if "mail-archive" in w]
    assert len(legacy) == 1 and "legacy targetWorkflow slug" in legacy[0]

    # ── Phase 7: registry converged — claim audited; legacy ghost gone on re-save ──
    assert c.post("/api/save", json={"id": "referrer", "bpmn": REFERRER_BPMN}).status_code == 200
    reg = load_registry(store)
    assert reg["ghosts"] == []
    assert [(cl["uuid"], cl["project"]) for cl in reg["claims"]] == [
        (GHOST_UUID, "escalation")
    ]
