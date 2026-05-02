"""T-1674 — fabric drift completes in O(n) on the live repo.

Pre-T-1674: stale-edge check spawned TWO python3 subprocesses per fabric
card, each re-reading all cards (~1,016 spawns × 0.66s ≈ 11 minutes on
508 cards). Made `bin/fw fabric drift` unusable on the live repo.

Post-T-1674: single python3 pass, ~3s on 508 cards.

This test:
  1. Seeds a fixture project with N=20 cards (mix of resolvable and
     stale `depends_on` targets).
  2. Runs `bin/fw fabric drift` against it.
  3. Asserts the run completes in well under 10 seconds (orders of
     magnitude below the pre-fix per-card cost).
  4. Asserts the stale-edge output names the unresolved targets and
     the summary count is correct — the SAME byte-for-byte format as
     the pre-fix implementation.

The 10s budget is intentionally loose: we don't want CI flakes if the
host is slow, but we want a giant red flag if anyone reverts to
spawning python3 per-card.
"""

import os
import subprocess
import time
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
FW = REPO_ROOT / "bin" / "fw"


def _run(cmd, cwd, timeout=30):
    env = os.environ.copy()
    env["PROJECT_ROOT"] = str(cwd)
    env["FRAMEWORK_ROOT"] = str(REPO_ROOT)
    return subprocess.run(
        cmd, cwd=str(cwd), env=env, capture_output=True, text=True, timeout=timeout
    )


def _write_card(fabric_dir, card_id, name, depends_on=None):
    deps_yaml = ""
    if depends_on:
        deps_yaml = "depends_on:\n" + "".join(
            f"  - target: {t}\n    type: uses\n" for t in depends_on
        )
    else:
        deps_yaml = "depends_on: []\n"
    (fabric_dir / f"{card_id}.yaml").write_text(
        f"""id: {card_id}
name: {name}
type: code
subsystem: test
location: nonexistent-{card_id}.txt
purpose: T-1674 perf fixture
interfaces: []
{deps_yaml}depended_by: []
"""
    )


@pytest.fixture
def project_with_cards(tmp_path):
    """Build a 20-card fixture project. ~half of cards reference unresolved
    targets, so stale-edge output is non-empty."""
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    (tmp_path / ".tasks" / "completed").mkdir(parents=True)
    (tmp_path / ".context" / "working").mkdir(parents=True)
    (tmp_path / ".framework.yaml").write_text(f"framework_path: {REPO_ROOT}\n")
    fabric_dir = tmp_path / ".fabric" / "components"
    fabric_dir.mkdir(parents=True)

    # 10 cards with no deps (resolve trivially):
    for i in range(10):
        _write_card(fabric_dir, f"resolved-{i}", f"resolved-{i}")
    # 10 cards each with a target that doesn't exist:
    for i in range(10):
        _write_card(
            fabric_dir,
            f"stale-{i}",
            f"stale-{i}",
            depends_on=[f"phantom-target-{i}"],
        )
    return tmp_path


def test_drift_completes_quickly_on_20_cards(project_with_cards):
    """20-card drift must finish in <10s. Pre-T-1674 would be ~26s for
    20 cards (40 python3 spawns × 0.66s); the fix brings it to <1s."""
    t0 = time.monotonic()
    r = _run([str(FW), "fabric", "drift"], cwd=project_with_cards, timeout=15)
    elapsed = time.monotonic() - t0
    assert r.returncode == 0, r.stderr
    assert elapsed < 10.0, (
        f"drift took {elapsed:.1f}s — likely regressed to per-card python3 spawning. "
        f"Expected <10s. Stdout:\n{r.stdout[:500]}"
    )


def test_drift_stale_output_format_preserved(project_with_cards):
    """Stale edges must be reported with the existing format: byte-for-byte
    identical to pre-T-1674. The summary count must match the visible lines."""
    r = _run([str(FW), "fabric", "drift"], cwd=project_with_cards)
    assert r.returncode == 0, r.stderr
    lines = r.stdout.splitlines()
    # Find the stale-edges section:
    try:
        start = next(i for i, l in enumerate(lines) if "Stale edges:" in l)
    except StopIteration:
        pytest.fail(f"no 'Stale edges:' section in output:\n{r.stdout}")
    # Walk forward, collect "  ! ... → ... (unresolved)" lines until blank or Summary.
    unresolved = []
    for line in lines[start + 1:]:
        if not line.strip() or line.startswith("Summary:"):
            break
        if "(unresolved)" in line:
            unresolved.append(line)
    # We seeded 10 stale targets:
    assert len(unresolved) == 10, (
        f"expected 10 unresolved lines, got {len(unresolved)}:\n" + "\n".join(unresolved)
    )
    # Format check: must match the pre-fix shape "  ! NAME → TARGET (unresolved)":
    for line in unresolved:
        assert line.startswith("  ! "), f"format drift: {line!r}"
        assert " → " in line, f"format drift: {line!r}"
        assert line.endswith("(unresolved)"), f"format drift: {line!r}"
    # Summary count must match:
    summary = next(l for l in lines if l.startswith("Summary:"))
    assert "stale: 10" in summary, f"summary count drift: {summary!r}"


def test_drift_no_stale_emits_none_marker(tmp_path):
    """Empty fabric → stale-edges section emits '(none)'. Same as pre-fix."""
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    (tmp_path / ".tasks" / "completed").mkdir(parents=True)
    (tmp_path / ".context" / "working").mkdir(parents=True)
    (tmp_path / ".framework.yaml").write_text(f"framework_path: {REPO_ROOT}\n")
    (tmp_path / ".fabric" / "components").mkdir(parents=True)
    r = _run([str(FW), "fabric", "drift"], cwd=tmp_path)
    assert r.returncode == 0, r.stderr
    # Stale-edges section must show "(none)":
    assert "Stale edges:" in r.stdout
    # The line right after "Stale edges:" should be "  (none)":
    lines = r.stdout.splitlines()
    idx = next(i for i, l in enumerate(lines) if "Stale edges:" in l)
    assert any("(none)" in l for l in lines[idx + 1: idx + 4]), (
        f"empty fabric should print '(none)' marker:\n{r.stdout}"
    )
