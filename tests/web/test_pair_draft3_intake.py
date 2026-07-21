"""T-2590: pair-draft-3 intake drop-point — sha-pinned 832 fixture test.

832's pair-draft #3 (their T-219) is a shared byte-fixture exercising the
T-2571 contract-v0 three legs: RESOLVED (live uuid), GHOST (unresolved uuid),
LEGACY (slug-only targetWorkflow). This file is the canonical drop-point:
intake = drop two files + run pytest, no hand-driving.

Drop procedure:
  1. Save 832's fixture bytes verbatim to  tests/fixtures/832/pair-draft-3.bpmn
  2. Save their announced sha256 (hex, one line) to
     tests/fixtures/832/pair-draft-3.sha256
  3. Run:  python3 -m pytest tests/web/test_pair_draft3_intake.py -q

Until the bytes land, the fixture test skips cleanly; the synthetic three-leg
test below keeps the taxonomy assertions green so the intake logic itself is
proven before delivery.
"""

import hashlib
import json
import os
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

import pytest

from tests.web.test_designer_registry_ghosts import bpmn_with_links

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tools"))

import bpmn_to_tasks  # noqa: E402

FIXTURE = REPO_ROOT / "tests" / "fixtures" / "832" / "pair-draft-3.bpmn"
SHA_PIN = FIXTURE.with_suffix(".sha256")

# Live corpus uuid recommended to 832 for the RESOLVED leg (DM offset 118).
LIVE_UUID = "1f9b5f0c-0be4-4cfe-9158-d9e6f0c1d4c7"  # aef-task-lifecycle
GHOST_UUID = "22222222-2222-4222-8222-222222222222"


def _t2576(warnings):
    return [w for w in warnings if "T-2576" in w]


def test_synthetic_three_legs(monkeypatch, tmp_path):
    """Taxonomy proof independent of 832's delivery: RESOLVED silent (T-2570),
    GHOST → claim WARN, LEGACY slug → migrate-advisory WARN."""
    store = tmp_path / "projects"
    proj = store / "aef-task-lifecycle"
    proj.mkdir(parents=True)
    (proj / "meta.json").write_text(
        json.dumps({"id": "aef-task-lifecycle", "uuid": LIVE_UUID})
    )
    monkeypatch.setenv("FW_DESIGNER_STORE", str(store))

    bpmn = bpmn_with_links(
        ("n1", "resolved", f'<aef:link workflowRef="{LIVE_UUID}" name="task lifecycle"/>'),
        ("n2", "ghost", f'<aef:link workflowRef="{GHOST_UUID}" name="future flow"/>'),
        ("n3", "legacy", '<aef:link targetWorkflow="aef-task-lifecycle"/>'),
    )
    p = tmp_path / "three-leg.bpmn"
    p.write_text(bpmn)
    _, warnings = bpmn_to_tasks.parse_bpmn(str(p))
    link_warns = _t2576(warnings)

    # RESOLVED: exactly the other two legs warn; the resolved node stays silent.
    assert len(link_warns) == 2, link_warns
    assert not any("'n1'" in w for w in link_warns)
    # GHOST: pending-ghost WARN carries the copy-pasteable claim command.
    assert any(f"fw bpmn claim {GHOST_UUID}" in w and "'n2'" in w for w in link_warns)
    # LEGACY: migrate advisory names the stable uuid to migrate to.
    assert any(
        "'n3'" in w and "legacy" in w and f'workflowRef="{LIVE_UUID}"' in w
        for w in link_warns
    )


def test_pair_draft3_fixture_intake(monkeypatch):
    """832's actual bytes: sha-verify, compile against the LIVE store, assert
    every link classifies per contract v0. Skips until delivery."""
    if not FIXTURE.exists():
        pytest.skip(
            "832 pair-draft-3 not yet delivered — drop bytes at "
            f"{FIXTURE.relative_to(REPO_ROOT)} (+ .sha256 sibling) and rerun"
        )

    # (a) integrity: bytes match 832's announced pin
    assert SHA_PIN.exists(), "fixture present but sha256 pin sibling is missing"
    pinned = SHA_PIN.read_text().split()[0].strip().lower()
    actual = hashlib.sha256(FIXTURE.read_bytes()).hexdigest()
    assert actual == pinned, f"sha mismatch: fixture {actual} != pinned {pinned}"

    # (b) compile against the live designer store — resolution must be decidable
    live_store = REPO_ROOT / ".context" / "designer" / "projects"
    monkeypatch.setenv("FW_DESIGNER_STORE", str(live_store))
    _, warnings = bpmn_to_tasks.parse_bpmn(str(FIXTURE))
    assert not any("no designer store found" in w for w in warnings), warnings

    live_uuids = set()
    for d in live_store.iterdir() if live_store.is_dir() else []:
        mp = d / "meta.json"
        if mp.is_file():
            u = json.loads(mp.read_text()).get("uuid")
            if u:
                live_uuids.add(u)

    # (c) taxonomy: classify each aef:link in the fixture and hold it to contract v0
    root = ET.parse(FIXTURE).getroot()
    links = [el for el in root.iter() if el.tag.rsplit("}", 1)[-1] == "link"]
    assert links, "fixture contains no aef:link refs — not a pair-draft"
    link_warns = _t2576(warnings)
    legs = {"resolved": 0, "ghost": 0, "legacy": 0}
    for link in links:
        wref = link.get("workflowRef")
        target = link.get("targetWorkflow") or ""
        display = link.get("name") or target
        if wref and wref in live_uuids:
            legs["resolved"] += 1  # T-2570: resolved refs are silent
            assert not any(f"workflowRef {wref}" in w for w in link_warns), (
                f"resolved uuid {wref} wrongly WARNed"
            )
        elif wref:
            legs["ghost"] += 1
            assert any(f"fw bpmn claim {wref}" in w for w in link_warns), (
                f"ghost uuid {wref} missing claim WARN"
            )
        else:
            legs["legacy"] += 1  # either migrate-advisory or no-live-match form
            assert any(
                (target and repr(target) in w) or (display and repr(display) in w)
                for w in link_warns
            ), f"legacy ref {display!r} missing legacy WARN"
    assert all(legs.values()), f"pair-draft #3 should exercise all three legs: {legs}"
