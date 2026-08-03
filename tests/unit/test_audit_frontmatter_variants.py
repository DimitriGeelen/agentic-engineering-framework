"""T-2779: the audit's task-frontmatter check must see BOTH halves of the T-2069 class.

A `description: >` folded scalar that ends early hands its orphaned paragraphs to YAML as
frontmatter, and what happens next depends on punctuation the author never thought about:

  * paragraph contains "word: word"  -> parses as a junk top-level key. The document is
    valid YAML, so a parse-error check assigns rc=0 and says nothing, while `description`
    has silently been truncated to its first line.
  * paragraph contains no colon      -> ScannerError, rc=3, warned about.

The check was written against the second shape only. T-2778 censused the corpus on both and
found 4 silent instances against 1 loud — so the detector was reporting roughly a fifth of
its own class, and the historical note at audit.sh:640 ("1 corpus victim") was recording the
predicate's reach rather than the defect's.

Each test drives the real `audit.sh` against a scratch PROJECT_ROOT. Asserting on the emitted
warning rather than on a re-implemented classifier is the point: the classifier is what
changed, so a test that re-implements it would agree with itself.
"""

import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
AUDIT = REPO / "agents" / "audit" / "audit.sh"

LOUD = """\
---
id: T-9002
name: "Unparseable"
description: >
  First paragraph.

Third paragraph with no colon at all.

status: started-work
workflow_type: build
owner: agent
horizon: now
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
---

# T-9002: Unparseable
"""

SILENT = """\
---
id: T-9001
name: "Silently truncated"
description: >
  First paragraph.

Second paragraph: this became a key.

status: started-work
workflow_type: build
owner: agent
horizon: now
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
---

# T-9001: Silently truncated
"""

CLEAN = """\
---
id: T-9003
name: "Well formed"
description: >
  First paragraph.

  Second paragraph: correctly indented, so it stays part of the value.

status: started-work
workflow_type: build
owner: agent
horizon: now
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
---

# T-9003: Well formed
"""

SILENT_WARN = "description content parsed as frontmatter keys"
LOUD_WARN = "have unparseable YAML"


def _run_audit(tmp_path: Path, fixtures: dict[str, str]) -> str:
    root = tmp_path / "root"
    (root / ".tasks" / "active").mkdir(parents=True)
    (root / ".tasks" / "completed").mkdir(parents=True)
    # audit.sh imports web.shared.parse_frontmatter from PROJECT_ROOT and skips the whole
    # check silently when the import fails — without this symlink the tests would pass by
    # never running the code under test.
    (root / "web").symlink_to(REPO / "web")
    for name, body in fixtures.items():
        (root / ".tasks" / "active" / name).write_text(body, encoding="utf-8")

    proc = subprocess.run(
        ["bash", str(AUDIT), "--section", "structure"],
        cwd=str(REPO),
        env={
            "PATH": "/usr/bin:/bin:/usr/local/bin",
            "HOME": str(tmp_path),
            "PROJECT_ROOT": str(root),
        },
        capture_output=True, text=True, timeout=300,
    )
    out = proc.stdout + proc.stderr
    assert "STRUCTURE CHECKS" in out, f"audit did not run the structure section:\n{out[-3000:]}"
    return out


def test_silent_truncation_is_reported(tmp_path):
    out = _run_audit(tmp_path, {"T-9001-silent.md": SILENT})
    assert SILENT_WARN in out, (
        "audit did not flag a description paragraph that became a frontmatter key. "
        f"This file parses cleanly, so the unparseable check cannot catch it.\n{out[-3000:]}"
    )


def test_unparseable_is_still_reported(tmp_path):
    """The original check must survive the addition — regressions here would be silent."""
    out = _run_audit(tmp_path, {"T-9002-loud.md": LOUD})
    assert LOUD_WARN in out, f"audit stopped flagging unparseable frontmatter:\n{out[-3000:]}"


def test_the_two_variants_are_reported_as_distinct_classes(tmp_path):
    """They need different repairs, so one merged count would hide which one applies."""
    out = _run_audit(tmp_path, {"T-9001-silent.md": SILENT, "T-9002-loud.md": LOUD})
    assert SILENT_WARN in out and LOUD_WARN in out, out[-3000:]
    assert "1 task(s) have unparseable YAML" in out, (
        f"the silent file was counted as unparseable; the classes are merged:\n{out[-3000:]}"
    )
    assert "1 task(s) have description content parsed as frontmatter keys" in out, out[-3000:]


def test_correctly_indented_multi_paragraph_description_is_not_flagged(tmp_path):
    """The predicate must be whitespace-in-key, not 'has more than one paragraph'."""
    out = _run_audit(tmp_path, {"T-9003-clean.md": CLEAN})
    assert SILENT_WARN not in out, f"false positive on a well-formed description:\n{out[-3000:]}"
    assert LOUD_WARN not in out, out[-3000:]


@pytest.mark.parametrize("field", ["bvp_scores_proposed", "cost_estimate_proposed"])
def test_extensible_schema_fields_are_not_flagged(tmp_path, field):
    """Guard against re-implementing this as an unknown-key check.

    The frontmatter schema is deliberately open (audit treats unknown fields as silent
    additions, A2). An unknown-key predicate would pass this file today and start failing
    the day someone adds a field — the check would then be measuring the schema's age.
    """
    body = CLEAN.replace("# T-9003: Well formed", "# T-9003: Well formed").replace(
        "last_update: 2026-01-01T00:00:00Z",
        f"last_update: 2026-01-01T00:00:00Z\n{field}:\n  - ts: '2026-01-01T00:00:00Z'\n    estimator: x",
    )
    out = _run_audit(tmp_path, {"T-9003-clean.md": body})
    assert SILENT_WARN not in out, f"flagged the extensible field {field!r}:\n{out[-3000:]}"
