"""T-5087 (GitHub #107): existing-project onboarding seeds T-002..T-006 had no ## Updates, and
task_updates.py appended the first status entry at end of file, inside ## Verification, where
P-011 then refused the close. Every seed now has the section, and the writer creates it."""
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "lib"))
import task_updates  # noqa: E402

SEEDS = sorted((ROOT / "lib" / "seeds" / "tasks").glob("*/T-*.md"))
ENTRY = "### 2026-11-12 — status-update [task-update-agent]\n- **Change:** status: captured → started-work"


@pytest.mark.parametrize("seed", SEEDS, ids=lambda p: f"{p.parent.name}/{p.name}")
def test_every_seed_has_updates(seed):
    assert "\n## Updates\n" in seed.read_text()


def test_seeds_found():
    assert len(SEEDS) >= 7


def test_missing_section_is_created_after_verification():
    text = "# T-9\n\n## Verification\n\ntest -f x\nfw audit\n"
    out = task_updates.insert_entry(text, ENTRY)
    verification = out.split("## Verification\n", 1)[1].split("\n## ", 1)[0]
    assert verification.strip().splitlines() == ["test -f x", "fw audit"]
    assert out.endswith("## Updates\n\n" + ENTRY + "\n")
    # a second entry goes into the section it just made, not after it
    out2 = task_updates.insert_entry(out, "### later\n- x")
    assert out2.count("## Updates") == 1 and out2.endswith(ENTRY + "\n\n### later\n- x\n")


def test_missing_section_without_trailing_newline():
    out = task_updates.insert_entry("# T-9\n\n## Verification\n\ntrue", ENTRY)
    assert "true\n\n## Updates\n\n" + ENTRY + "\n" in out


def test_existing_section_unchanged():
    text = "# T-9\n\n## Updates\n\n### a\n- one\n\n## Reviewer Verdict\n\nok\n"
    out = task_updates.insert_entry(text, ENTRY)
    assert out == "# T-9\n\n## Updates\n\n### a\n- one\n\n" + ENTRY + "\n\n## Reviewer Verdict\n\nok\n"
