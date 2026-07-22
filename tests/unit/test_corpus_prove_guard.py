"""T-2609: prove pre-flight loss guard — refuse BEFORE any destructive call.

`fw corpus prove` deletes every store version before regenerating; the snapshot
lives only in memory (and git). T-2605 only ever ran it on maps already
round-trip-proven. This pins the guard that makes prove safe on arbitrary maps:
a spec whose regeneration is not canonically identical to the proof target is
refused (exit 2) with zero HTTP mutations issued.
"""

import json
from pathlib import Path
from types import SimpleNamespace

import pytest
import yaml

import sys

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tools"))

import corpus_spec  # noqa: E402

MAP_ID = "aef-task-lifecycle"
_SRC_DIR = REPO_ROOT / ".context/designer/projects" / MAP_ID
_SRC_V = json.loads((_SRC_DIR / "meta.json").read_text())["latest"]
SOURCE_XML = (_SRC_DIR / f"v{_SRC_V}.bpmn").read_text()


@pytest.fixture()
def harness(monkeypatch, tmp_path):
    store = tmp_path / "projects"
    d = store / MAP_ID
    d.mkdir(parents=True)
    (d / "meta.json").write_text(json.dumps({
        "id": MAP_ID, "uuid": "44444444-4444-4444-8444-444444444444",
        "latest": 1, "versions": [{"v": 1}],
    }))
    # dispatch-loop must exist in the store index so the legacy targetWorkflow
    # ref in the source map resolves at generate time
    d2 = store / "aef-dispatch-loop"
    d2.mkdir()
    (d2 / "meta.json").write_text(json.dumps({
        "id": "aef-dispatch-loop",
        "uuid": "e32a518c-01de-4243-aafc-691cc99caf0d", "latest": 1,
    }))
    monkeypatch.setattr(corpus_spec, "STORE", store)

    mutations = []
    meta_path = d / "meta.json"

    def fake_post(url, body):
        # minimal /api/delete + /api/save server behavior against the tmp meta
        mutations.append(url)
        meta = json.loads(meta_path.read_text())
        if url.endswith("/api/delete"):
            meta["versions"] = [v for v in meta.get("versions", [])
                                if v["v"] != body["v"]]
        else:  # /api/save
            meta.setdefault("uuid", "should-not-mint")
            meta["versions"] = meta.get("versions", []) + [{"v": 1}]
            meta["latest"] = 1
        meta_path.write_text(json.dumps(meta))
        return {"ok": True, "v": 1}

    monkeypatch.setattr(corpus_spec, "_http_get", lambda url: SOURCE_XML)
    monkeypatch.setattr(corpus_spec, "_http_post", fake_post)
    return store, mutations


def _args(spec_path=None):
    return SimpleNamespace(map_id=MAP_ID, url="http://test.invalid", spec=spec_path,
                           from_ref=None, note=None, json=False)


def test_guard_refuses_lossy_spec_before_any_mutation(harness, tmp_path, capsys):
    _, mutations = harness
    spec = corpus_spec.parse_map(SOURCE_XML)
    spec["title"] = "MUTATED — no longer what the store serves"
    p = tmp_path / "mutated.yaml"
    p.write_text(yaml.safe_dump(spec, sort_keys=False))

    rc = corpus_spec.cmd_prove(_args(str(p)))
    assert rc == 2
    assert mutations == [], "guard must fire before any /api/delete or /api/save"
    assert "REFUSED" in capsys.readouterr().err


def test_faithful_spec_passes_guard_and_proceeds(harness):
    _, mutations = harness
    rc = corpus_spec.cmd_prove(_args())  # default: derive in-memory from snapshot
    assert rc == 0
    # guard passed → the destructive sequence ran: 1 version delete + 1 save
    assert len(mutations) == 2
