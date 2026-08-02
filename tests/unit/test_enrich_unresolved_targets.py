"""T-2736 — enrich must not drop unresolvable and ignorable edges through one
silent branch.

Pre-fix, `resolve_edges` discarded any target that did not resolve to a card:

    target_id = loc_to_id.get(loc)
    if not target_id:
        continue

No counter, no verbose line, no effect on the summary. Enrichment could only
ever draw edges inside the already-registered set, and a run that discarded
everything reported identically to one that discarded nothing.

Measured on this repo before the fix, by wrapping the shipped `resolve_edges`
rather than reimplementing the dispatch: 2419 raw edges detected, 2124 kept,
**295 discarded** across 117 distinct targets, every one of which existed on
disk. The split is what makes the silence expensive:

    148 edge instances -> directories      (detector noise, correctly dropped)
    147 edge instances -> real uncarded files (genuine coverage loss)

One mute branch was doing both jobs, so no reader could distinguish a healthy
run from a lossy one.

These tests call the shipped functions directly. A test that re-typed the
classification would only ever check the shapes its author already had in mind
(L-533), and would drift from the producer the moment the producer changed.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "agents" / "fabric" / "lib"))

import enrich  # noqa: E402


@pytest.fixture
def tree(tmp_path):
    """A target of each class: carded file, uncarded file, directory, absent."""
    (tmp_path / "lib").mkdir()
    (tmp_path / "lib" / "carded.sh").write_text("#!/bin/bash\n")
    (tmp_path / "lib" / "uncarded.sh").write_text("#!/bin/bash\n")
    return tmp_path


def test_classify_directory_is_ignorable(tree):
    # Derived from the target being a directory — not from an allowlist of
    # known-noisy names. An allowlist can only cover the noise already seen.
    assert enrich.classify_unresolved("lib", str(tree)) == "ignorable"


def test_classify_existing_file_is_actionable(tree):
    # A real file with no card is what `fw fabric register` exists for.
    assert enrich.classify_unresolved("lib/uncarded.sh", str(tree)) == "actionable"


def test_classify_missing_path_is_absent(tree):
    assert enrich.classify_unresolved("lib/nope.sh", str(tree)) == "absent"


def test_the_three_classes_are_distinct(tree):
    # Discrimination control. If two classes collapsed to the same string the
    # tests above would all still pass while the reporting became useless.
    verdicts = {
        enrich.classify_unresolved("lib", str(tree)),
        enrich.classify_unresolved("lib/uncarded.sh", str(tree)),
        enrich.classify_unresolved("lib/nope.sh", str(tree)),
    }
    assert len(verdicts) == 3


def test_resolve_edges_collects_the_breakdown(tree):
    """The shipped resolve_edges, called directly."""
    loc_to_id = {"lib/carded.sh": "lib-carded"}
    raw = [
        ("lib/carded.sh", "sources"),    # resolves
        ("lib/uncarded.sh", "sources"),  # actionable
        ("lib", "sources"),              # ignorable
        ("lib/nope.sh", "sources"),      # absent
    ]
    unresolved = {}
    edges = enrich.resolve_edges(raw, loc_to_id, "some-source",
                                 unresolved=unresolved,
                                 project_root=str(tree))

    assert edges == [{"target": "lib-carded", "type": "sources"}]
    assert sum(unresolved.get("actionable", {}).values()) == 1
    assert sum(unresolved.get("ignorable", {}).values()) == 1
    assert sum(unresolved.get("absent", {}).values()) == 1
    assert "lib/uncarded.sh" in unresolved["actionable"]


def test_resolve_edges_signature_is_backward_compatible(tree):
    """Omitting `unresolved` must behave exactly as before.

    compute_reverse_edges and any external caller still use the 3-arg form;
    a mandatory parameter would have broken them silently.
    """
    loc_to_id = {"lib/carded.sh": "lib-carded"}
    raw = [("lib/carded.sh", "sources"), ("lib/nope.sh", "sources")]
    edges = enrich.resolve_edges(raw, loc_to_id, "some-source")
    assert edges == [{"target": "lib-carded", "type": "sources"}]


def test_discards_are_counted_not_swallowed(tree):
    """The property that failed before: a lossy run must not be indistinguishable
    from a clean one."""
    loc_to_id = {"lib/carded.sh": "lib-carded"}
    clean = {}
    enrich.resolve_edges([("lib/carded.sh", "sources")], loc_to_id, "src",
                         unresolved=clean, project_root=str(tree))
    lossy = {}
    enrich.resolve_edges([("lib/uncarded.sh", "sources")] * 5, loc_to_id, "src",
                         unresolved=lossy, project_root=str(tree))

    clean_total = sum(sum(v.values()) for v in clean.values())
    lossy_total = sum(sum(v.values()) for v in lossy.values())
    assert clean_total == 0
    assert lossy_total == 5
    # the whole point — the two runs are now distinguishable
    assert clean_total != lossy_total


def test_summary_reports_actionable_even_at_zero():
    """An absence has to be representable (L-525).

    If the Actionable line were printed only when non-zero, a clean run and a
    broken counter would produce identical output.
    """
    src = (REPO_ROOT / "agents" / "fabric" / "lib" / "enrich.py").read_text()
    # the print is unconditional — not nested under `if n_actionable`
    assert 'print(f"Actionable:' in src
    idx = src.index('print(f"Actionable:')
    preceding = src[max(0, idx - 400):idx]
    assert "if n_actionable" not in preceding


def test_classification_is_not_an_allowlist():
    """Source-derived guard (L-533).

    classify_unresolved must decide from the filesystem, not from a literal set
    of known-noisy path names. A hard-coded tuple/set/list of paths here would
    mean the next unseen shape is misfiled in silence.
    """
    src = (REPO_ROOT / "agents" / "fabric" / "lib" / "enrich.py").read_text()
    start = src.index("def classify_unresolved(")
    body = src[start:src.index("def resolve_edges(", start)]
    assert "os.path.isdir" in body
    assert "os.path.isfile" in body
    for smell in ('.tasks"', '"tools"', '"lib"', "in (", "in ["):
        assert smell not in body, f"allowlist smell in classify_unresolved: {smell}"
