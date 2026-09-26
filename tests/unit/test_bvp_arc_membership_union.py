"""T-3503 — `fw bvp arcs` must union tag membership, and must never drop an arc.

Slice S3 of T-3501. Reported by cashweb-integration-agent (agent-chat-arc @1247):
*"BVP arc ranking blind spots: an arc with no canonical members was dropped rather
than reported as zero."* Two defects compounded in one function:

1. `_arc_member_tasks` matched `arc_id:` only, so a tag-only arc had no members.
2. `cmd_arcs` then did `if not scores: continue`, deleting the arc from the table.

Measured on the live corpus before the fix: **16 of 20 arcs listed**, and three of
the four missing were among the five arcs the audit flags as stale — the arcs most
needing attention were the ones the ranking could not see.

The second defect is the one worth a test suite on its own: `continue` collapsed
*no members found* and *members found but unscored* into the same invisible state,
so an arc absent from the ranking was indistinguishable from an arc that does not
exist. Reporting BOTH, distinguishably, is what these tests pin.

Fixtures only (T-3326) — no live corpus counts.
"""

from __future__ import annotations

import importlib.util
import os
import sys
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_ROOT))
os.environ.setdefault("PROJECT_ROOT", str(PROJECT_ROOT))
os.environ.setdefault("FRAMEWORK_ROOT", str(PROJECT_ROOT))


def _load_bvp_module():
    """Load lib/bvp.sh's embedded python body — the house pattern from
    tests/unit/test_bvp_cli_arcs_rollup.py."""
    src = (PROJECT_ROOT / "lib" / "bvp.sh").read_text()
    start_marker = "python3 - \"$@\" <<'PYEOF'"
    end_marker = "PYEOF"
    i = src.index(start_marker) + len(start_marker)
    j = src.index(end_marker, i)
    body = src[i:j].replace("sys.exit(main(sys.argv))", "# (stripped for import)")
    tmp = PROJECT_ROOT / "tests" / "unit" / "_bvp_union_imported.py"
    tmp.write_text(body)
    spec = importlib.util.spec_from_file_location("bvp_union_imported", tmp)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["bvp_union_imported"] = mod
    spec.loader.exec_module(mod)
    return mod


bvp = _load_bvp_module()

SCORES = "bvp_scores:\n  D1: 4\n  D2: 4\n  D3: 3\n  D4: 2\n"


def _task(root, tid, *, arc_id=None, tag=None, scored=True):
    body = f"---\nid: {tid}\nname: \"t\"\nstatus: work-completed\n"
    body += f"tags: [arc:{tag}]\n" if tag else "tags: []\n"
    if arc_id:
        body += f"arc_id: {arc_id}\n"
    if scored:
        body += SCORES
    body += "---\nbody\n"
    (root / ".tasks" / "active" / f"{tid}-x.md").write_text(body, encoding="utf-8")


@pytest.fixture()
def corpus(tmp_path, monkeypatch):
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    (tmp_path / ".tasks" / "completed").mkdir(parents=True)
    # cmd_arcs loads the driver policy from PROJECT_ROOT and sys.exit(2)s without
    # it. Copy the real one rather than stubbing weights, so the rollup arithmetic
    # under test is the arithmetic that ships.
    (tmp_path / "policy").mkdir(parents=True, exist_ok=True)
    (tmp_path / "policy" / "value-drivers.yaml").write_text(
        (PROJECT_ROOT / "policy" / "value-drivers.yaml").read_text(encoding="utf-8"),
        encoding="utf-8")
    monkeypatch.setattr(bvp, "PROJECT_ROOT", tmp_path)
    # Both caches are module-global and built once — they must be cleared between
    # fixtures or the first test's corpus leaks into every later one.
    monkeypatch.setattr(bvp, "_ARC_MEMBERSHIP_INDEX", None)
    monkeypatch.setattr(bvp, "_ARC_FM_INDEX", None)
    return tmp_path


# ── defect 1: membership must union the legacy tag form ────────────────────

def test_a_tag_only_member_is_found(corpus):
    """The reported defect. Before the fix this returned []."""
    _task(corpus, "T-1", tag="my-arc")
    members = bvp._arc_member_tasks("my-arc", "arc-099")
    assert [m["id"] for m in members] == ["T-1"]


def test_arc_id_slug_and_arc_nnn_forms_both_still_bind(corpus):
    """T-1849 dual-form must survive the change — this is the half that worked."""
    _task(corpus, "T-2", arc_id="my-arc")
    _task(corpus, "T-3", arc_id="arc-099")
    ids = {m["id"] for m in bvp._arc_member_tasks("my-arc", "arc-099")}
    assert ids == {"T-2", "T-3"}


def test_the_union_deduplicates_a_task_carrying_both_forms(corpus):
    """A task with arc_id AND the tag is one member, not two — otherwise it would
    be double-weighted in the mean that rolls up the arc's score."""
    _task(corpus, "T-4", arc_id="my-arc", tag="my-arc")
    assert len(bvp._arc_member_tasks("my-arc", "arc-099")) == 1


def test_an_unrelated_arc_gains_nothing(corpus):
    """CONTROL: reading MORE forms must not pull in foreign members."""
    _task(corpus, "T-5", arc_id="other-arc")
    _task(corpus, "T-6", tag="other-arc")
    assert bvp._arc_member_tasks("my-arc", "arc-099") == []


# ── defect 2: an unscorable arc is REPORTED, never dropped ─────────────────

def _rows(corpus, arcs, monkeypatch):
    """Run cmd_arcs over a fixture arc registry, capturing its rows."""
    (corpus / ".context" / "arcs").mkdir(parents=True, exist_ok=True)
    out = []
    for slug, aid in arcs:
        (corpus / ".context" / "arcs" / f"{slug}.yaml").write_text(
            f"id: {aid}\nslug: {slug}\nname: {slug}\nstatus: in-progress\n",
            encoding="utf-8")
    monkeypatch.setattr(bvp, "collect_arcs", lambda: [
        (corpus / ".context" / "arcs" / f"{slug}.yaml",
         {"id": aid, "slug": slug, "name": slug, "status": "in-progress"})
        for slug, aid in arcs])
    printed: list[str] = []
    monkeypatch.setattr("builtins.print", lambda *a, **k: printed.append(" ".join(str(x) for x in a)))
    bvp.cmd_arcs()
    return printed


def test_an_arc_with_no_members_is_listed_as_no_members(corpus, monkeypatch):
    """Before the fix this arc simply vanished from the table."""
    printed = _rows(corpus, [("empty-arc", "arc-100")], monkeypatch)
    joined = "\n".join(printed)
    assert "empty-arc" in joined, f"the arc was dropped from the table:\n{joined}"
    assert "no-members" in joined


def test_an_arc_whose_members_are_all_unscored_says_so(corpus, monkeypatch):
    """The other half of the collapsed state. An arc WITH members that cannot be
    scored is a different finding from an arc with no members, and the operator
    needs to tell them apart: one is a membership problem, the other a scoring one."""
    _task(corpus, "T-7", arc_id="unscored-arc", scored=False)
    printed = _rows(corpus, [("unscored-arc", "arc-101")], monkeypatch)
    joined = "\n".join(printed)
    assert "unscored-arc" in joined
    assert "members-unscored" in joined


def test_the_two_empty_states_are_distinguishable(corpus, monkeypatch):
    """Stated as its own assertion because collapsing them IS the original defect.
    A fix that reported both as one state would only have relabelled it."""
    _task(corpus, "T-8", arc_id="unscored-arc", scored=False)
    printed = _rows(corpus, [("empty-arc", "arc-100"), ("unscored-arc", "arc-101")],
                    monkeypatch)
    joined = "\n".join(printed)
    assert "no-members" in joined and "members-unscored" in joined


def test_an_unscorable_arc_renders_a_dash_not_a_zero(corpus, monkeypatch):
    """An arc we cannot score is not an arc worth nothing. Rendering 0.00 would be
    a fabricated verdict — the same rule as blast_radius unknown-not-zero."""
    printed = _rows(corpus, [("empty-arc", "arc-100")], monkeypatch)
    row = [p for p in printed if "empty-arc" in p and "SLUG" not in p][0]
    assert "0.00" not in row, f"unscorable arc claimed a score: {row}"
    assert "-" in row


# ── the control leg ────────────────────────────────────────────────────────

def test_a_scored_arc_still_ranks_normally(corpus, monkeypatch):
    """Without this, 'now shows more arcs' is indistinguishable from 'changed how
    arcs are scored'. The scored path must be untouched."""
    _task(corpus, "T-9", arc_id="good-arc")
    printed = _rows(corpus, [("good-arc", "arc-102")], monkeypatch)
    row = [p for p in printed if "good-arc" in p and "SLUG" not in p][0]
    assert "derived" in row
    assert "no-members" not in row and "members-unscored" not in row


def test_scored_arcs_sort_before_unscorable_ones(corpus, monkeypatch):
    """Unscorable rows must not displace real ones at the top of the ranking."""
    _task(corpus, "T-10", arc_id="good-arc")
    printed = _rows(corpus, [("empty-arc", "arc-100"), ("good-arc", "arc-102")],
                    monkeypatch)
    body = [p for p in printed if ("good-arc" in p or "empty-arc" in p) and "SLUG" not in p]
    assert "good-arc" in body[0]
    assert "empty-arc" in body[-1]


# ── degraded membership is announced, never silent ─────────────────────────

def test_a_failed_canonical_import_is_reported_not_swallowed(corpus, monkeypatch):
    """`fw bvp` must not crash if the helper is unavailable — but falling back to
    arc_id:-only silently would restore the exact defect being fixed here."""
    monkeypatch.setattr(bvp, "_ARC_MEMBERSHIP_INDEX", ({}, {}, "ImportError: boom"))
    assert bvp.arc_membership_degraded() == "ImportError: boom"

    _task(corpus, "T-11", arc_id="deg-arc")
    members = bvp._arc_member_tasks("deg-arc", "arc-103")
    assert [m["id"] for m in members] == ["T-11"], "degraded path lost arc_id members"

    printed = _rows(corpus, [("deg-arc", "arc-103")], monkeypatch)
    assert any("DEGRADED" in p for p in printed), (
        "membership degraded silently — the caller never said so")
