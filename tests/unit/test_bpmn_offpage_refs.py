"""T-2576 (T-2571 S3): compile-time off-page connector ref WARNs.

Contract v0 (rail offsets 107-111): <aef:link workflowRef="<uuid>"> is the
stable cross-workflow identity; legacy targetWorkflow="<slug>" resolves by name
only. Pass 5 resolves refs against the designer store and WARNs per defect —
silent on cleanly resolved refs (T-2570 taxonomy discipline), one aggregate
note when no store is available.
"""
import json
import os
import sys

import pytest

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO_ROOT, "tools"))

import bpmn_to_tasks  # noqa: E402

AEF = "http://anchorpoint.framework/aef/extensions"
GHOST_UUID = "11111111-1111-4111-8111-111111111111"


def _bpmn(link_attrs: str) -> str:
    """One-lane diagram: a userTask plus an intermediateThrowEvent carrying the link."""
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL" '
        f'xmlns:aef="{AEF}" id="D_t2576">'
        '<bpmn:process id="P1">'
        '<bpmn:userTask id="t1" name="do work">'
        '<bpmn:extensionElements><aef:uid value="agt_1_work"/></bpmn:extensionElements>'
        "</bpmn:userTask>"
        '<bpmn:intermediateThrowEvent id="n1" name="escalate">'
        f"<bpmn:extensionElements><aef:link {link_attrs}/></bpmn:extensionElements>"
        "</bpmn:intermediateThrowEvent>"
        "</bpmn:process></bpmn:definitions>"
    )


@pytest.fixture()
def store(tmp_path, monkeypatch):
    s = tmp_path / "projects"
    s.mkdir()
    monkeypatch.setenv("FW_DESIGNER_STORE", str(s))
    return s


def _project(store, slug, uuid=None):
    d = store / slug
    d.mkdir()
    meta = {"id": slug, "title": slug}
    if uuid:
        meta["uuid"] = uuid
    (d / "meta.json").write_text(json.dumps(meta))


def _compile(tmp_path, link_attrs):
    p = tmp_path / "d.bpmn"
    p.write_text(_bpmn(link_attrs))
    return bpmn_to_tasks.parse_bpmn(str(p))


def _pass5(warnings):
    return [w for w in warnings if "T-2576" in w]


def test_dangling_workflowref_warns_both_ends(store, tmp_path):
    _, warnings = _compile(
        tmp_path, f'workflowRef="{GHOST_UUID}" name="escalation handling"'
    )
    w5 = _pass5(warnings)
    assert len(w5) == 1
    w = w5[0]
    assert "'n1'" in w and "'escalate'" in w  # referrer end
    assert "'escalation handling'" in w and GHOST_UUID in w  # target end
    assert f"fw bpmn claim {GHOST_UUID}" in w  # resolution path


def test_resolved_workflowref_is_silent(store, tmp_path):
    _project(store, "escalation", uuid=GHOST_UUID)
    _, warnings = _compile(
        tmp_path, f'workflowRef="{GHOST_UUID}" name="escalation handling"'
    )
    assert _pass5(warnings) == []


def test_legacy_slug_resolving_gets_migrate_advisory(store, tmp_path):
    _project(store, "escalation", uuid=GHOST_UUID)
    _, warnings = _compile(tmp_path, 'targetWorkflow="escalation"')
    w5 = _pass5(warnings)
    assert len(w5) == 1
    w = w5[0]
    assert "legacy targetWorkflow slug" in w
    assert f'workflowRef="{GHOST_UUID}"' in w  # the uuid to adopt


def test_legacy_slug_resolving_uuidless_target_advises_mint(store, tmp_path):
    _project(store, "escalation")  # pre-backfill project, no uuid yet
    _, warnings = _compile(tmp_path, 'targetWorkflow="escalation"')
    w5 = _pass5(warnings)
    assert len(w5) == 1
    assert "no uuid yet" in w5[0]


def test_legacy_slug_dangling_warns(store, tmp_path):
    _, warnings = _compile(tmp_path, 'targetWorkflow="missing-flow"')
    w5 = _pass5(warnings)
    assert len(w5) == 1
    assert "'missing-flow'" in w5[0] and "no live workflow matches" in w5[0]


def test_no_store_emits_one_aggregate_note(tmp_path, monkeypatch):
    monkeypatch.setenv("FW_DESIGNER_STORE", str(tmp_path / "nonexistent"))
    monkeypatch.chdir(tmp_path)  # no cwd-relative store either
    skeletons, warnings = _compile(
        tmp_path, f'workflowRef="{GHOST_UUID}" name="x"'
    )
    w5 = _pass5(warnings)
    assert len(w5) == 1
    assert "no designer store found" in w5[0]
    # skeleton emission unaffected
    assert [s["uid"] for s in skeletons] == ["agt_1_work"]


def test_no_links_no_pass5_output(store, tmp_path):
    p = tmp_path / "d.bpmn"
    p.write_text(_bpmn("").replace("<aef:link />", ""))
    _, warnings = bpmn_to_tasks.parse_bpmn(str(p))
    assert _pass5(warnings) == []


def test_warn_only_skeletons_unchanged(store, tmp_path):
    skeletons, _ = _compile(
        tmp_path, f'workflowRef="{GHOST_UUID}" name="escalation handling"'
    )
    assert [s["uid"] for s in skeletons] == ["agt_1_work"]
