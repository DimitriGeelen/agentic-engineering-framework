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
  1. test_measurement_reproduces_T2870 — the exact table from the report,
     reproduced from tools/aef_meta_census.py rather than living only in
     docs/reports/T-2870-mapping-v1-rulings.md. Exact-count: expected to need
     updating if the corpus grows — that's a feature, not brittleness, since
     "the numbers moved" is itself the thing worth eyeballing on next touch.
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


# ── 1. measurement reproduces the T-2870 report ──────────────────────────────

def test_measurement_reproduces_T2870():
    c = census_mod.census(REPO_ROOT)
    assert c["files"] == 56
    assert c["diagrams_with_meta"] == 45
    assert c["elements"] == 501
    assert c["attributes"] == 652
    assert c["frozen_attributes"] == 53
    assert c["non_frozen_attributes"] == 599

    expected_key_counts = {
        "note": 393,
        "state": 102,
        "terminalKind": 74,
        "tier": 34,
        "triggeredBy": 18,
        "workflowType": 10,
        "agentType": 8,
        "decisionOwner": 6,
        "softFail": 2,
        "guard": 2,
        "horizon": 1,
        "gate": 1,
        "exitCode": 1,
    }
    assert c["key_counts"] == expected_key_counts


def test_state_is_the_load_bearing_exposure():
    """T-2871's own framing: of the 91% non-frozen surface, `state=` is the one
    that matters, because the aef-task-lifecycle state-carrier design (T-2624)
    rests on it and the T-2621 conformance rail audits transition parity
    THROUGH those carriers — a rename there leaves the rail SKIP-green
    (carrier_count == 0) while the map has silently stopped meaning anything.
    Every other non-frozen key (note, terminalKind, ...) is either display-only
    or has no live consumer at all."""
    c = census_mod.census(REPO_ROOT)
    assert c["key_counts"]["state"] == 102
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
