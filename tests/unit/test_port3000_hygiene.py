"""Unit tests for tools/port3000_hygiene.py (T-2894).

Covers the classifier (carrier vs. citation) and the baseline ratchet:
new carriers fail, removed carriers never fail, stale entries are reported
(not silently dropped), and the 832-class lifecycle-move regression (a task
file's basename survives `active/` -> `completed/` unchanged) does not
register as new.
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from tools.port3000_hygiene import (  # noqa: E402
    CARRIER,
    CITATION,
    build_baseline_dict,
    compare,
    find_claude_watchtower_section,
    load_baseline,
    save_baseline,
    scan_file,
    scan_repo,
)


def _hits_by_category(hits):
    carriers = [h for h in hits if h.category == CARRIER]
    citations = [h for h in hits if h.category == CITATION]
    return carriers, citations


# --------------------------------------------------------------------- AC1/(a)


def test_classifier_separates_carrier_from_citation_with_exact_counts(tmp_path):
    """L-591: assert the actual classified COUNTS on a known fixture, not
    just that the tool exits 0 / doesn't crash. The citation fixture is the
    repo's own real CLAUDE.md §Watchtower Port section text (read live, not
    paraphrased), so the test is anchored to real citation text."""
    claude_md = ROOT / "CLAUDE.md"
    real_lines = claude_md.read_text(encoding="utf-8").splitlines()
    section_lines = find_claude_watchtower_section(real_lines)
    assert section_lines, "fixture precondition: CLAUDE.md must have a §Watchtower Port section"
    start, end = min(section_lines), max(section_lines)
    section_text = "\n".join(real_lines[start - 1 : end])
    section_hit_count = sum(
        1 for ln in real_lines[start - 1 : end] if "localhost:3000" in ln or "127.0.0.1:3000" in ln
    )
    assert section_hit_count == 3, (
        "fixture precondition drifted from CLAUDE.md's real section content "
        f"(expected 3 hit lines — heading + 2 body — found {section_hit_count})"
    )

    fixture_claude_md = (
        section_text
        + "\n\n"
        + "## Next Section\n"
        + "\n"
        + "Outside the section now: curl http://localhost:3000/outside-the-doc\n"
    )
    (tmp_path / "CLAUDE.md").write_text(fixture_claude_md, encoding="utf-8")

    (tmp_path / "carrier1.sh").write_text(
        "#!/bin/bash\n"
        "curl -sf http://localhost:3000/tasks/T-1\n"
        "curl -sf http://127.0.0.1:3000/tasks/T-2\n",
        encoding="utf-8",
    )
    (tmp_path / "sanctioned.sh").write_text(
        "#!/bin/bash\n"
        'WT_URL=$(bin/fw watchtower url 2>/dev/null || echo "http://localhost:3000")\n',
        encoding="utf-8",
    )
    (tmp_path / "commented.py").write_text(
        "# anti-pattern reminder: don't hardcode http://localhost:3000\n"
        "x = 1\n",
        encoding="utf-8",
    )

    hits = scan_repo(tmp_path)
    carriers, citations = _hits_by_category(hits)

    # carriers: 1 (CLAUDE.md line outside its own section) + 2 (carrier1.sh) = 3
    assert len(carriers) == 3, [
        (h.path, h.line, h.text) for h in carriers
    ]
    # citations: 3 (real CLAUDE.md section lines) + 1 (sanctioned.sh) + 1 (commented.py) = 5
    assert len(citations) == 5, [
        (h.path, h.line, h.reason) for h in citations
    ]

    assert any(h.path == "carrier1.sh" for h in carriers)
    assert any("outside-the-doc" in h.text for h in carriers if h.path == "CLAUDE.md")

    reasons = {h.reason for h in citations}
    assert "claude_md_watchtower_port_section" in reasons
    assert "sanctioned_fallback_same_line" in reasons
    assert "code_comment" in reasons


def test_claude_md_section_boundary_is_exclusive_of_next_heading(tmp_path):
    fixture = (
        "## Watchtower Port (read this FIRST, before any `curl localhost:3000`)\n"
        "\n"
        "Inside: curl http://localhost:3000/inside\n"
        "\n"
        "## Task System\n"
        "\n"
        "Outside: curl http://localhost:3000/outside\n"
    )
    (tmp_path / "CLAUDE.md").write_text(fixture, encoding="utf-8")
    hits = scan_file(tmp_path / "CLAUDE.md", tmp_path)
    by_text = {h.text: h.category for h in hits}
    assert by_text["Inside: curl http://localhost:3000/inside"] == CITATION
    assert by_text["Outside: curl http://localhost:3000/outside"] == CARRIER


# --------------------------------------------------------------------- AC3/(b)(c)(d)


def test_ratchet_passes_on_unchanged_population(tmp_path):
    scan_dir = tmp_path / "repo"
    scan_dir.mkdir()
    (scan_dir / "foo.sh").write_text("curl -sf http://localhost:3000/x\n", encoding="utf-8")

    hits = scan_repo(scan_dir)
    baseline = build_baseline_dict(hits)

    result = compare(scan_repo(scan_dir), baseline)
    assert result.ok
    assert result.new == []
    assert result.stale == []
    assert result.unchanged_count == 1


def test_ratchet_fails_on_one_new_carrier(tmp_path):
    scan_dir = tmp_path / "repo"
    scan_dir.mkdir()
    (scan_dir / "foo.sh").write_text("curl -sf http://localhost:3000/x\n", encoding="utf-8")
    baseline = build_baseline_dict(scan_repo(scan_dir))

    # A genuinely new carrier appears.
    (scan_dir / "bar.sh").write_text("curl -sf http://localhost:3000/y\n", encoding="utf-8")

    result = compare(scan_repo(scan_dir), baseline)
    assert not result.ok
    assert len(result.new) == 1
    assert result.new[0]["path"] == "bar.sh"
    assert result.new[0]["line"] == 1


def test_ratchet_does_not_fail_when_a_carrier_is_removed(tmp_path):
    scan_dir = tmp_path / "repo"
    scan_dir.mkdir()
    foo = scan_dir / "foo.sh"
    foo.write_text(
        "curl -sf http://localhost:3000/x\ncurl -sf http://localhost:3000/y\n",
        encoding="utf-8",
    )
    baseline = build_baseline_dict(scan_repo(scan_dir))

    # Remove one of the two carriers.
    foo.write_text("curl -sf http://localhost:3000/x\n", encoding="utf-8")

    result = compare(scan_repo(scan_dir), baseline)
    assert result.ok, result.new
    assert result.new == []
    assert len(result.stale) == 1


# --------------------------------------------------------------------- AC4/(e)


def test_lifecycle_move_active_to_completed_is_not_a_new_carrier(tmp_path):
    """The exact 832-class regression: `fw task update --status work-completed`
    moves `.tasks/active/T-XXX-*.md` -> `.tasks/completed/T-XXX-*.md`. Same
    basename, same carrier content — a relpath-keyed baseline would (and did,
    for 832) make this look like a brand new carrier."""
    repo = tmp_path / "repo"
    active = repo / ".tasks" / "active"
    completed = repo / ".tasks" / "completed"
    active.mkdir(parents=True)
    completed.mkdir(parents=True)

    task_content = (
        "## Verification\n\n"
        "curl -sf http://localhost:3000/tasks/T-9001\n"
    )
    task_file = active / "T-9001-example.md"
    task_file.write_text(task_content, encoding="utf-8")

    baseline = build_baseline_dict(scan_repo(repo))
    assert baseline["entries"].get("T-9001-example.md"), "fixture precondition"

    # Simulate the work-completed move: same basename, same content, new dir.
    task_file.unlink()
    (completed / "T-9001-example.md").write_text(task_content, encoding="utf-8")

    result = compare(scan_repo(repo), baseline)
    assert result.ok
    assert result.new == [], result.new
    assert result.stale == [], result.stale
    assert result.unchanged_count == 1


# --------------------------------------------------------------------- AC5/(f)


def test_stale_baseline_entry_is_reported_distinctly(tmp_path):
    scan_dir = tmp_path / "repo"
    scan_dir.mkdir()
    foo = scan_dir / "foo.sh"
    foo.write_text("curl -sf http://localhost:3000/x\n", encoding="utf-8")
    baseline = build_baseline_dict(scan_repo(scan_dir))

    # Carrier fully removed from the file.
    foo.write_text("echo cleaned\n", encoding="utf-8")

    result = compare(scan_repo(scan_dir), baseline)
    assert result.ok
    assert result.new == []
    assert len(result.stale) == 1
    assert result.stale[0]["basename"] == "foo.sh"
    assert result.stale[0]["line"] == 1
    # Distinct from "new" and "unchanged" — must not be silently dropped.
    assert result.unchanged_count == 0


# --------------------------------------------------------------------- extra: collision + persistence


def test_basename_collision_across_directories_is_reported_not_merged(tmp_path):
    repo = tmp_path / "repo"
    d1 = repo / "a"
    d2 = repo / "b"
    d1.mkdir(parents=True)
    d2.mkdir(parents=True)
    (d1 / "same.md").write_text("curl http://localhost:3000/one\n", encoding="utf-8")
    (d2 / "same.md").write_text("curl http://localhost:3000/two\n", encoding="utf-8")

    hits = scan_repo(repo)
    carriers = [h for h in hits if h.category == CARRIER]
    assert len(carriers) == 2

    baseline = build_baseline_dict(hits)
    assert len(baseline["entries"]["same.md"]) == 2

    result = compare(scan_repo(repo), baseline)
    assert result.ok
    assert result.unchanged_count == 2
    assert len(result.collisions) == 1
    assert result.collisions[0]["basename"] == "same.md"
    assert len(result.collisions[0]["paths"]) == 2


def test_baseline_round_trips_through_disk(tmp_path):
    scan_dir = tmp_path / "repo"
    scan_dir.mkdir()
    (scan_dir / "foo.sh").write_text("curl -sf http://localhost:3000/x\n", encoding="utf-8")
    baseline = build_baseline_dict(scan_repo(scan_dir))

    baseline_path = tmp_path / "baseline.json"
    save_baseline(baseline_path, baseline)
    reloaded = load_baseline(baseline_path)

    result = compare(scan_repo(scan_dir), reloaded)
    assert result.ok
    assert result.unchanged_count == 1


def test_load_baseline_missing_file_returns_empty_structure(tmp_path):
    baseline = load_baseline(tmp_path / "does-not-exist.json")
    assert baseline == {"version": 1, "entries": {}}
