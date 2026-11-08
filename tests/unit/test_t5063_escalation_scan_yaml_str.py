"""T-5063 — escalation-scan-v0 must write YAML that parses, whatever a title holds.

Origin: T-4056's title holds a raw `\\"` (the v0 scanner reads frontmatter as text,
so YAML escapes are not decoded). The old writer swapped `"` for `'` and left the
backslash, producing `\\'` — not a YAML escape — and LATEST.yaml stopped parsing,
which turned escalation_scan_v05.bats A2/A3 red and blocked pre-push (2026-11-08).
"""

from __future__ import annotations

import importlib.util
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).resolve().parent.parent.parent
_spec = importlib.util.spec_from_file_location(
    "escalation_scan_v0", ROOT / "tools" / "escalation-scan-v0.py"
)
scan = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(scan)

TITLES = [
    # the origin: raw text as the line-based frontmatter reader returns it
    'fw doctor misparses interpreter-prefixed hook commands (python3 \\"$CLAUDE_PROJEC',
    "a title with \\' a backslash-quote",
    'plain "double" and \'single\' quotes',
    "trailing backslash \\",
    "tab\there and colon: here # not a comment",
    "non-ASCII: Bölt — ✓",
    "",
]


@pytest.mark.parametrize("title", TITLES)
def test_yaml_str_round_trips(title: str) -> None:
    doc = f"name: {scan.yaml_str(title)}\n"
    assert yaml.safe_load(doc) == {"name": title}


def test_old_swap_was_broken_for_the_origin_title() -> None:
    """Control: the pre-fix escaping fails on the origin title, so the test above bites."""
    old = TITLES[0].replace('"', "'")
    with pytest.raises(yaml.YAMLError):
        yaml.safe_load(f'name: "{old}"\n')
