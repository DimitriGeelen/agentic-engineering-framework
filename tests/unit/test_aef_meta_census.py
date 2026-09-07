"""T-2871 — pin for the aef:meta key-dependency exposure.

T-2870 measured (by hand, once) that our corpus is 91% built on `aef:meta`
keys the standard (aef-bpmn-mapping-v1 Part I §2, pinned T-2869) explicitly
reserves the right to change without a version bump. That measurement lived
only in a report. This file makes it re-runnable and adds the piece the
report didn't have: a guard that actually goes red if a key our own tooling
depends on disappears from the corpus.

NOT in scope (T-2871 description, verbatim): asking 832 to freeze more keys.
Their §2 note is deliberate and correct. The gap this closes is that we built
on the unfrozen half of the schema without ever recording that we had.

Three things, in order:
  1. test_census_method_* — the measurement METHOD, pinned two ways (T-3326
     re-anchor). Exact counts run against a committed inline fixture corpus
     (hermetic — red only if the parser/classifier breaks); the live corpus
     gets structural invariants (categories sum, >0 carriers, the T-2870
     exposure property non_frozen > frozen) that survive corpus growth by
     construction. This file USED to pin exact live counts (56 carriers /
     102 state, later re-eyeballed to 74/138) — that anchored the test to
     mutable corpus state and it rotted with every designer session, blocking
     closes for reasons unrelated to the code under test (OBS-377).
  2. test_depended_on_keys_* — DEPENDED_ON_KEYS is the actual guard: a small,
     evidence-based set (state, workflowType) with live corpus occurrences,
     as opposed to the ~13 keys that merely appear. Robust to corpus growth
     (asserts >0, not an exact count) — this is what fires on a rename
     regardless of how many new diagrams get added around it.
  3. test_anti_vacuity_* — OBS-193: a mutant that dies at parse time is
     indistinguishable from the property going red. Each mutation is checked
     well-formed FIRST, against a REAL corpus fixture, feeding the REAL
     consumer function (not a reimplementation) — so the demonstration is of
     the actual exposure, not of a model of it.
"""

import sys
import xml.etree.ElementTree as ET
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tools"))

import aef_meta_census as census_mod  # noqa: E402
import bpmn_to_tasks  # noqa: E402
import corpus_conformance  # noqa: E402
import corpus_spec  # noqa: E402


# ── 1. the measurement METHOD, pinned (T-3326 re-anchor) ─────────────────────
# Exact counts belong to a COMMITTED fixture corpus, not the live one: the live
# corpus is mutable state (designer sessions grow it), so exact live counts
# measure the drift, not the code (OBS-377 / T-3326 — sibling of T-1828/T-3105).
# The fixture is inline rather than on-disk under tests/fixtures/ because
# corpus_files() scans tests/fixtures/**/*.bpmn — an on-disk fixture would
# perturb the very live census this module measures.

_FIXTURE_NS1 = "http://anchorpoint.framework/aef/extensions"
_FIXTURE_NS2 = "urn:aef:workflow-designer"

# Two aef namespace URIs on purpose: pins the local-name (namespace-agnostic)
# matching that the tool's docstring records as a real undercount bug
# (498/649 vs the true 501/652 under exact-URI findall).
_FIXTURE_FILES = {
    ".context/designer/projects/sample-a/v1.bpmn": f"""<?xml version="1.0"?>
<bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL"
                  xmlns:aef="{_FIXTURE_NS1}">
  <bpmn:process id="p1">
    <bpmn:task id="t1">
      <bpmn:extensionElements>
        <aef:meta state="captured" workflowType="build" note="n"/>
      </bpmn:extensionElements>
    </bpmn:task>
    <bpmn:task id="t2">
      <bpmn:extensionElements>
        <aef:meta horizon="now" tier="1"/>
      </bpmn:extensionElements>
    </bpmn:task>
  </bpmn:process>
</bpmn:definitions>
""",
    # namespaced attribute (aef:state) — attrib key arrives as {uri}state;
    # pins the _local() handling on the attribute axis too
    ".context/designer/projects/sample-b/v1.bpmn": f"""<?xml version="1.0"?>
<bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL"
                  xmlns:aef="{_FIXTURE_NS2}">
  <bpmn:process id="p2">
    <bpmn:task id="t3">
      <bpmn:extensionElements>
        <aef:meta aef:state="done" agentType="coder"/>
      </bpmn:extensionElements>
    </bpmn:task>
  </bpmn:process>
</bpmn:definitions>
""",
    # a diagram with NO aef:meta — pins diagrams_with_meta < files
    ".context/designer/projects/sample-c/v1.bpmn": """<?xml version="1.0"?>
<bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL">
  <bpmn:process id="p3"><bpmn:task id="t4"/></bpmn:process>
</bpmn:definitions>
""",
}


def _write_fixture_corpus(root: Path) -> Path:
    for rel, text in _FIXTURE_FILES.items():
        p = root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)
    return root


def test_census_method_exact_counts_on_fixture_corpus(tmp_path):
    """Exact-count pin of the measurement method against a committed fixture.
    Red only when census() itself breaks (parser misses a namespace, category
    sums drift, a key is dropped) — never when the live corpus grows."""
    c = census_mod.census(_write_fixture_corpus(tmp_path))
    assert c["files"] == 3
    assert c["diagrams_with_meta"] == 2
    assert c["elements"] == 3
    assert c["attributes"] == 7
    assert c["frozen_attributes"] == 4  # workflowType, horizon, tier, agentType
    assert c["non_frozen_attributes"] == 3  # state x2, note x1
    assert c["key_counts"] == {
        "state": 2,
        "workflowType": 1,
        "note": 1,
        "horizon": 1,
        "tier": 1,
        "agentType": 1,
    }


def test_census_live_corpus_invariants():
    """Structural invariants on the LIVE corpus — properties that survive
    corpus growth by construction but still fail if the measurement breaks
    (parser returns nothing, categories stop summing)."""
    c = census_mod.census(REPO_ROOT)
    assert c["files"] > 0, "corpus glob found no .bpmn files — method broke"
    assert c["elements"] > 0, "parser found zero <aef:meta> elements"
    assert 0 < c["diagrams_with_meta"] <= c["files"]
    assert c["attributes"] == sum(c["key_counts"].values())
    assert c["frozen_attributes"] + c["non_frozen_attributes"] == c["attributes"]
    assert c["frozen_attributes"] == sum(
        v for k, v in c["key_counts"].items() if k in census_mod.FROZEN_KEYS
    )
    # The T-2870 finding itself, as a property: the corpus is built
    # overwhelmingly on the NON-frozen side (was 92%, then 94%). Pinned as an
    # inequality, not a percentage — deepening exposure keeps it green,
    # a broken classifier (both zero) goes red.
    assert c["non_frozen_attributes"] > c["frozen_attributes"]


def test_state_is_the_load_bearing_exposure():
    """T-2871's own framing: of the 91% non-frozen surface, `state=` is the one
    that matters, because the aef-task-lifecycle state-carrier design (T-2624)
    rests on it and the T-2621 conformance rail audits transition parity
    THROUGH those carriers — a rename there leaves the rail SKIP-green
    (carrier_count == 0) while the map has silently stopped meaning anything.
    Every other non-frozen key (note, terminalKind, ...) is either display-only
    or has no live consumer at all."""
    c = census_mod.census(REPO_ROOT)
    # >0, not an exact count (T-3326): the live count is mutable corpus state
    # (102 in August, 138 by September); the exposure claim only needs "live".
    assert c["key_counts"].get("state", 0) > 0
    assert "state" not in census_mod.FROZEN_KEYS
    assert "state" in census_mod.DEPENDED_ON_KEYS
    assert census_mod.DEPENDED_ON_KEYS["state"]["frozen"] is False
    assert "T-2621" in census_mod.DEPENDED_ON_KEYS["state"]["why"]
    assert "T-2624" in census_mod.DEPENDED_ON_KEYS["state"]["why"]


# ── 2. depended-on keys, classified, and present ─────────────────────────────

def test_depended_on_keys_classification():
    """Enumerates keys the corpus actually DEPENDS ON — i.e. code reads them
    and branches — not every key that merely appears (note=393 appears and is
    read nowhere but a display-only print in corpus_explain.py; it is not in
    this set)."""
    assert set(census_mod.DEPENDED_ON_KEYS) == {"state", "workflowType"}
    for key, info in census_mod.DEPENDED_ON_KEYS.items():
        # frozen classification must match FROZEN_KEYS, not be asserted
        # independently — the two lists are allowed to disagree in principle
        # (a key can be depended-on AND frozen, e.g. workflowType) but the
        # entry's own "frozen" flag must be derived, not hand-typed drift.
        assert info["frozen"] == (key in census_mod.FROZEN_KEYS)
        assert info["consumers"], f"{key} has no consumers listed"

    assert census_mod.DEPENDED_ON_KEYS["state"]["frozen"] is False
    assert census_mod.DEPENDED_ON_KEYS["workflowType"]["frozen"] is True


def test_depended_on_keys_present_in_corpus():
    """The exposure guard proper: each depended-on key currently has a
    non-zero count in the live corpus. Deliberately >0, not an exact count —
    robust to corpus growth (new diagrams), so this only fires on the actual
    failure shape: the old key stops appearing, the new one is unrecognised,
    and today nothing notices (T-2871 description)."""
    c = census_mod.census(REPO_ROOT)
    for key in census_mod.DEPENDED_ON_KEYS:
        assert c["key_counts"].get(key, 0) > 0, (
            f"depended-on key {key!r} has zero live occurrences in the corpus "
            "— this is exactly the silent-rename shape T-2871 exists to catch"
        )


# ── 3. anti-vacuity — the guard demonstrably goes red on a rename ───────────
# OBS-193 (T-2870): a mutant that dies at parse time is indistinguishable from
# the property going red. Each test below asserts well-formedness of the
# mutant BEFORE feeding it to the real consumer.

def _latest_bpmn_text(map_dir: Path) -> str:
    import json

    meta = json.loads((map_dir / "meta.json").read_text())
    return (map_dir / f"v{meta['latest']}.bpmn").read_text()


def test_anti_vacuity_state_rename_zeroes_the_carrier_guard():
    """Real fixture (aef-task-lifecycle, the map T-2624 built), real consumer
    (corpus_conformance.carrier_count — the function the T-2621 rail runs)."""
    fixture = REPO_ROOT / ".context/designer/projects/aef-task-lifecycle"
    original = _latest_bpmn_text(fixture)

    before = corpus_conformance.carrier_count(corpus_spec.parse_map(original))
    assert before > 0, "sanity: fixture must carry state= before mutating"

    mutant = original.replace('state="', 'staleState="')
    assert mutant != original, "mutation did not change anything — test is vacuous"
    ET.fromstring(mutant)  # OBS-193 guard: mutant must still be well-formed XML

    after = corpus_conformance.carrier_count(corpus_spec.parse_map(mutant))
    assert after == 0, (
        f"expected the rename to silently zero the carrier count (that IS the "
        f"exposure — the T-2621 rail would report SKIP, not FAIL), got {after}"
    )


def test_anti_vacuity_workflow_type_rename_kills_inception_marker():
    """Real fixture (T-2534's own positive fixture for this exact signal), real
    consumer (bpmn_to_tasks._is_inception_subprocess)."""
    fixture = REPO_ROOT / "tests/fixtures/bpmn/inception-gonogo-sample.bpmn"
    original = fixture.read_text()
    assert 'workflowType="inception"' in original

    def _subprocess_node(xml_text: str) -> ET.Element:
        root = ET.fromstring(xml_text)
        for el in root.iter():
            if bpmn_to_tasks._local(el.tag) == "subProcess":
                return el
        raise AssertionError("fixture has no subProcess node")

    before = bpmn_to_tasks._is_inception_subprocess(_subprocess_node(original))
    assert before is True, "sanity: fixture must be recognised as inception before mutating"

    mutant = original.replace('workflowType="inception"', 'workflowTyp3="inception"')
    assert mutant != original, "mutation did not change anything — test is vacuous"
    ET.fromstring(mutant)  # OBS-193 guard: mutant must still be well-formed XML

    after = bpmn_to_tasks._is_inception_subprocess(_subprocess_node(mutant))
    assert after is False, (
        "expected the rename to silently drop the inception marker (the "
        "subProcess would compile as an ordinary composite instead of an "
        "inception task, with no error), got True"
    )
