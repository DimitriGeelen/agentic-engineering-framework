"""`report_divergence` must agree with the enricher about what the edges are.

The report answers the question drift's other sections do not ask: does a card's
declared `depends_on` still match what its source actually imports? Section 3
walks the edges a card DECLARES and checks the targets resolve; nothing walked
the converse, so a card naming one edge out of ten is clean by every other
check — each one only audits what the map already says.

The load-bearing property is not the count. It is that the count comes from the
*enricher's own* detector. Two detectors would be free to disagree, and a drift
report that disagrees with the enricher is worse than no report: it sends
readers to add edges the enricher then declines to write. So the central test
here is an equivalence, not a fixture — on a real corpus, the set of cards
flagged divergent must equal the set `compute_forward_edges` would add a forward
edge to. A fixture can only ever check the shapes its author had in mind
(L-533); the equivalence checks the property that actually matters, and keeps
checking it after someone adds a seventh detector.

These tests call the shipped functions directly for the same reason.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "agents" / "fabric" / "lib"))

import enrich  # noqa: E402


def write_card(components, slug, location, deps):
    """deps: list of (target, type) tuples.

    `id` is the location, as it is throughout a real corpus — edge targets are
    card *ids*, so a fixture that gave them different values would be testing a
    shape the enricher never produces.
    """
    lines = [
        f"id: {location}",
        f"name: {slug}",
        f"location: {location}",
        "subsystem: framework-core",
        'purpose: "A sentence that says what this does."',
    ]
    if deps:
        lines.append("depends_on:")
        for target, edge_type in deps:
            lines.append(f"  - target: {target}")
            lines.append(f"    type: {edge_type}")
    else:
        lines.append("depends_on: []")
    lines.append("depended_by: []")
    (components / f"{slug}.yaml").write_text("\n".join(lines) + "\n")


@pytest.fixture
def project(tmp_path):
    """A two-file project: consumer.sh sources helper.sh. Both carded."""
    components = tmp_path / ".fabric" / "components"
    components.mkdir(parents=True)
    lib = tmp_path / "lib"
    lib.mkdir()
    (lib / "helper.sh").write_text("#!/bin/bash\nhelper() { :; }\n")
    (lib / "consumer.sh").write_text(
        '#!/bin/bash\nsource "$LIB_DIR/helper.sh"\n'
    )
    write_card(components, "lib-helper", "lib/helper.sh", [])
    return tmp_path, components


def index(tmp_path, components):
    cards, loc_to_id, _lc, _il, _ic = enrich.build_index(str(components))
    return cards, loc_to_id


# --- the dangerous direction: source imports what the card does not declare ---

def test_undeclared_import_is_divergent(project):
    tmp_path, components = project
    write_card(components, "lib-consumer", "lib/consumer.sh", [])
    cards, loc_to_id = index(tmp_path, components)
    rep = enrich.report_divergence(cards, loc_to_id, str(tmp_path))
    assert rep["divergent"] == [("lib/consumer.sh", ["lib/helper.sh"])], rep


def test_control_a_declared_import_is_not_divergent(project):
    """The negative control. A card that declares what its source imports must
    NOT be flagged — otherwise the section is a constant, not a detector."""
    tmp_path, components = project
    write_card(components, "lib-consumer", "lib/consumer.sh",
               [("lib/helper.sh", "sources")])
    cards, loc_to_id = index(tmp_path, components)
    rep = enrich.report_divergence(cards, loc_to_id, str(tmp_path))
    assert rep["divergent"] == [], rep


def test_declared_edge_the_detectors_cannot_see_is_extra_not_divergent(project):
    """`extra` is the low-severity direction and must stay out of the headline
    count: a hand-authored edge the detectors cannot find is usually legitimate."""
    tmp_path, components = project
    write_card(components, "lib-consumer", "lib/consumer.sh",
               [("lib/helper.sh", "sources"), ("lib/helper.sh", "calls")])
    cards, loc_to_id = index(tmp_path, components)
    rep = enrich.report_divergence(cards, loc_to_id, str(tmp_path))
    assert rep["divergent"] == [], rep
    assert rep["extra"] == 0, "same target, so nothing is missing from detection"


def test_a_write_type_edge_is_never_extra(project):
    """`writes` of a runtime artifact is not something detection could find, so
    its absence from the detected set is not a finding about the card."""
    tmp_path, components = project
    write_card(components, "lib-consumer", "lib/consumer.sh",
               [("lib/helper.sh", "sources"), ("data/ledger.log", "writes")])
    cards, loc_to_id = index(tmp_path, components)
    rep = enrich.report_divergence(cards, loc_to_id, str(tmp_path))
    assert rep["extra"] == 0, rep


def test_missing_source_is_not_divergent(project):
    """An orphaned card is section 2's business. Claiming it here would double-
    report the same file under two classes."""
    tmp_path, components = project
    write_card(components, "lib-gone", "lib/gone.sh", [])
    cards, loc_to_id = index(tmp_path, components)
    rep = enrich.report_divergence(cards, loc_to_id, str(tmp_path))
    assert [loc for loc, _m in rep["divergent"]] == [], rep


def test_unresolved_uses_the_existing_triage(project):
    """The breakdown reuses classify_unresolved's vocabulary rather than
    inventing a second one, so this report and the enrichment summary cannot
    tell different stories about the same corpus."""
    tmp_path, components = project
    (tmp_path / "lib" / "uncarded.sh").write_text("#!/bin/bash\n:\n")
    (tmp_path / "lib" / "consumer.sh").write_text(
        '#!/bin/bash\nsource "$LIB_DIR/helper.sh"\nsource "$LIB_DIR/uncarded.sh"\n'
    )
    write_card(components, "lib-consumer", "lib/consumer.sh",
               [("lib/helper.sh", "sources")])
    cards, loc_to_id = index(tmp_path, components)
    rep = enrich.report_divergence(cards, loc_to_id, str(tmp_path))
    assert rep["divergent"] == [], "the uncarded import is not a card-level gap"
    assert set(rep["unresolved"]) <= {"actionable", "ignorable", "absent"}
    assert "lib/uncarded.sh" in rep["unresolved"].get("actionable", {}), rep


# --- the property that matters: one detector, shared with the write path ---

def test_divergence_equals_what_the_enricher_would_add_on_the_real_corpus():
    """Equivalence against this repo's own corpus.

    If these two ever disagree, drift is telling readers about edges the
    enricher would not write (or staying silent on ones it would) — the exact
    failure that delegating to detect_raw_edges() is meant to make
    unrepresentable. Measured at 28 == 28 when this landed.
    """
    components = REPO_ROOT / ".fabric" / "components"
    if not components.is_dir():
        pytest.skip("no corpus in this checkout")
    cards, loc_to_id, _lc, _il, _ic = enrich.build_index(str(components))
    forward = enrich.compute_forward_edges(cards, loc_to_id, str(REPO_ROOT))
    rep = enrich.report_divergence(cards, loc_to_id, str(REPO_ROOT))

    divergent_locs = [loc for loc, _m in rep["divergent"]]
    forward_locs = sorted(cards[p].get("location", "") for p in forward)
    assert sorted(divergent_locs) == forward_locs, (
        "divergence and the enricher disagree about which cards are behind "
        "their source — they must share one detector"
    )


def test_a_detector_added_to_the_dispatch_reaches_both_paths(monkeypatch, project):
    """Structural: patch detect_raw_edges and BOTH paths must change.

    A second detector inside the divergence report would leave this test green
    while the two silently drifted apart, so the assertion is on the shared
    call, not on a count.
    """
    tmp_path, components = project
    write_card(components, "lib-consumer", "lib/consumer.sh", [])
    cards, loc_to_id = index(tmp_path, components)

    seen = []
    real = enrich.detect_raw_edges

    def spy(location, content, root):
        seen.append(location)
        return real(location, content, root)

    monkeypatch.setattr(enrich, "detect_raw_edges", spy)
    enrich.report_divergence(cards, loc_to_id, str(tmp_path))
    assert "lib/consumer.sh" in seen, "report_divergence must use the shared dispatch"

    seen.clear()
    enrich.compute_forward_edges(cards, loc_to_id, str(tmp_path))
    assert "lib/consumer.sh" in seen, "compute_forward_edges must use the same one"


# --- read-only, structurally ---

def test_report_divergence_writes_nothing(project):
    """--describe is ON by default and writes cards. The flag must return before
    it, so read-only is a property of the control flow rather than a promise."""
    tmp_path, components = project
    write_card(components, "lib-consumer", "lib/consumer.sh", [])
    before = {p: p.read_bytes() for p in sorted(components.glob("*.yaml"))}

    enrich_py = REPO_ROOT / "agents" / "fabric" / "lib" / "enrich.py"
    proc = subprocess.run(
        [sys.executable, str(enrich_py), "--report-divergence"],
        cwd=str(tmp_path), capture_output=True, text=True,
        env={"PROJECT_ROOT": str(tmp_path), "PATH": "/usr/bin:/bin",
             "HOME": str(tmp_path)},
    )
    assert proc.returncode == 0, proc.stderr
    assert "##DIVERGENT_CARDS=1##" in proc.stdout, proc.stdout
    after = {p: p.read_bytes() for p in sorted(components.glob("*.yaml"))}
    assert before == after, "a read-only mode modified a card"


def test_every_sentinel_prints_even_at_zero(project):
    """An absence has to be representable, or a clean corpus and a broken reader
    look identical (L-525). drift.sh's UNKNOWN branch depends on this."""
    tmp_path, components = project
    write_card(components, "lib-consumer", "lib/consumer.sh",
               [("lib/helper.sh", "sources")])
    enrich_py = REPO_ROOT / "agents" / "fabric" / "lib" / "enrich.py"
    proc = subprocess.run(
        [sys.executable, str(enrich_py), "--report-divergence"],
        cwd=str(tmp_path), capture_output=True, text=True,
        env={"PROJECT_ROOT": str(tmp_path), "PATH": "/usr/bin:/bin",
             "HOME": str(tmp_path)},
    )
    assert proc.returncode == 0, proc.stderr
    for key in ("DIVERGENT_CARDS", "DIVERGENT_EDGES", "DIVERGENT_EXTRA",
                "DIVERGENT_UNRESOLVED", "DIVERGENT_UNRESOLVED_ACTIONABLE",
                "DIVERGENT_UNRESOLVED_IGNORABLE", "DIVERGENT_UNRESOLVED_ABSENT"):
        assert f"##{key}=" in proc.stdout, f"{key} missing from a clean run"
    assert "##DIVERGENT_CARDS=0##" in proc.stdout, proc.stdout
