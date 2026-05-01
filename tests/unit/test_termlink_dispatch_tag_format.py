"""T-1654 — Framework dispatch primitive emits canonical `task:` tag prefix.

Pins the tag format produced by `agents/termlink/termlink.sh` against the
canonical-prefix list in `tests/fixtures/termlink-list-schema.json` (T-1649).

Before T-1654, the framework's own dispatch produced `task=NUM` (equals)
while T-1649's audit detected `task=` as a non-canonical prefix. The
framework was producing the drift its own audit caught — for 20 live
sessions on the dev hub at the moment of fix.

This test asserts the colon form is hard-coded at the producer site, so
any future refactor that reverts to `task=` fails CI.
"""

import json
import re
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
TERMLINK_SH = REPO_ROOT / "agents" / "termlink" / "termlink.sh"
SCHEMA_PATH = REPO_ROOT / "tests" / "fixtures" / "termlink-list-schema.json"


def _load_canonical_prefixes() -> set[str]:
    with SCHEMA_PATH.open() as f:
        return set(json.load(f)["tag_canonical_prefixes"])


def test_termlink_sh_present():
    assert TERMLINK_SH.is_file(), f"{TERMLINK_SH} missing"


def test_canonical_prefixes_contains_task_colon():
    """Sanity: the canonical-prefix list expects `task:` (colon)."""
    prefixes = _load_canonical_prefixes()
    assert "task:" in prefixes, (
        f"Schema does not list task: as canonical. Got {prefixes}. "
        "If renamed, refresh the assertion below in test_dispatch_uses_canonical_task_prefix."
    )


def test_dispatch_uses_canonical_task_prefix():
    """`agents/termlink/termlink.sh` MUST emit `task:$task` (colon), not `task=$task`."""
    source = TERMLINK_SH.read_text()
    # Find every place that constructs a tag from the $task variable.
    canonical_hits = re.findall(r'"task:\$task"', source)
    drift_hits = re.findall(r'"task=\$task"', source)

    assert canonical_hits, (
        f"No canonical 'task:$task' tag construction found in {TERMLINK_SH.name}. "
        "Did the spawn-tag emission move? Update this test to match."
    )
    assert not drift_hits, (
        f"Non-canonical 'task=$task' (equals) found in {TERMLINK_SH.name} — "
        "the framework would re-introduce the very drift its own audit detects (T-1649). "
        "Use 'task:$task' (colon) per tests/fixtures/termlink-list-schema.json."
    )


def test_no_other_task_equals_drift_in_termlink_sh():
    """Fail if any unquoted/quoted reference to a `task=` *tag value* sneaks back in.

    Excludes: shell variable assignments like `task=""`, `task="$2"`, env-var
    settings, comments. The drift form is specifically the *--tags* argument.
    """
    source = TERMLINK_SH.read_text()
    # Look for --tags … task= or "task=NUM" / "task=$something"
    for line_num, line in enumerate(source.splitlines(), start=1):
        if line.lstrip().startswith("#"):
            continue
        # Match the --tags ... "task=..." anti-pattern (with quotes around tag value).
        if re.search(r'--tags\s+["\']?task=', line):
            pytest.fail(
                f"{TERMLINK_SH.name}:{line_num} re-introduces non-canonical "
                f"`task=` tag form: {line.strip()!r}"
            )
