"""T-2556 AC3 (absent-marker half): frozen-v1 pin for the compile→stage→reconcile
pipeline on a diagram with NO kind= marker.

The kind= vocabulary proposal (rail offset 125, disposition 127) is additive:
absent/unknown kind must keep today's behavior byte-identical. This test pins
"today" mechanically, using 832's byte-pinned pair-draft #3 fixture (which
carries aef:workflowMeta WITHOUT a kind attribute — the exact absent-marker
case). When the consumption legs land post-ratification (compile stamps kind:
into the manifest, promote refuses kind=documentation), every assertion here
MUST stay green — any drift on unmarked diagrams is a frozen-v1 violation.

Deliberately built harness-first (T-2579 / T-2590 pattern): valid today,
valid regardless of the ratification outcome.
"""

import hashlib
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tools"))

import bpmn_to_tasks  # noqa: E402
import bpmn_promote  # noqa: E402

FIXTURE = REPO_ROOT / "tests" / "fixtures" / "832" / "pair-draft-3.bpmn"
SHA_PIN = FIXTURE.with_suffix(".sha256")

# Golden: sha256 of the manifest.yaml emitted by write_proposals() for the
# byte-pinned fixture staged under the relative diagram path below. The staged
# output is fully deterministic (no timestamps), so this is a byte-exact pin.
DIAGRAM_RELPATH = "tests/fixtures/832/pair-draft-3.bpmn"
MANIFEST_GOLDEN = "bbb2e46e6dcb75edbff7c170e4d0603cf25ecc109c2e93bb7abe3627832c095f"
EXPECTED_UIDS = ["n_1a2b3c4d", "n_2b3c4d5e", "n_5e6f7081", "n_6f708192"]


@pytest.fixture(scope="module")
def fixture_bytes():
    if not FIXTURE.is_file():
        pytest.skip("832 fixture not present (see tests/fixtures/832/README.md)")
    data = FIXTURE.read_bytes()
    pinned = SHA_PIN.read_text().split()[0]
    assert hashlib.sha256(data).hexdigest() == pinned, (
        "fixture bytes drifted from the cross-agent sha256 pin"
    )
    return data


def test_premise_fixture_has_no_kind_marker(fixture_bytes):
    """Guard the premise: the fixture carries workflowMeta WITHOUT kind=.
    If 832 ever re-delivers a marked fixture under this name, the pin test
    below no longer covers the absent path and must move to a new fixture."""
    text = fixture_bytes.decode("utf-8")
    assert "workflowMeta" in text
    assert "kind=" not in text


def test_absent_marker_stage_output_byte_identical(fixture_bytes, tmp_path):
    """Compile + stage the unmarked fixture; manifest bytes must match golden."""
    skeletons, _warnings = bpmn_to_tasks.parse_bpmn(str(FIXTURE))
    assert sorted(s["uid"] for s in skeletons) == EXPECTED_UIDS
    out_dir = bpmn_to_tasks.write_proposals(
        skeletons, DIAGRAM_RELPATH, stage_dir=str(tmp_path)
    )
    manifest = Path(out_dir, "manifest.yaml").read_bytes()
    assert hashlib.sha256(manifest).hexdigest() == MANIFEST_GOLDEN, (
        "staged manifest drifted for a NO-kind-marker diagram — frozen-v1 "
        "violation: the kind= legs must be byte-identical on unmarked input"
    )
    # kind: must never appear in the manifest for an unmarked diagram.
    assert b"kind:" not in manifest


def test_absent_marker_reconcile_all_promotable(fixture_bytes, tmp_path):
    """Promote's reconcile view: every proposal from an unmarked diagram is a
    plain NEW create against an empty task set — no refusal, no flag. The
    future kind=documentation refusal leg must not change this path."""
    skeletons, _ = bpmn_to_tasks.parse_bpmn(str(FIXTURE))
    bpmn_to_tasks.write_proposals(skeletons, DIAGRAM_RELPATH, stage_dir=str(tmp_path))
    manifests = bpmn_promote.load_manifests(str(tmp_path))
    assert len(manifests) == 1
    assert sorted(manifests[0]["proposals"]) == EXPECTED_UIDS
    actions = bpmn_promote.reconcile(manifests, existing={}, only_uid=None)
    assert [a["action"] for a in actions] == [bpmn_promote.NEW] * len(EXPECTED_UIDS)
