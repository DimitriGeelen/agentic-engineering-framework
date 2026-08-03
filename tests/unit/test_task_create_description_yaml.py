"""T-2778: `fw task create` must emit parseable frontmatter for multi-line descriptions.

`description: >` is a folded scalar, so every line of the value has to be indented.
create-task.sh indented only the first, which ended the scalar at the first newline and
handed the remaining paragraphs to YAML as frontmatter. That failed two ways, and the
loud one was the lucky one:

  * a paragraph containing "word: word" parsed as a junk top-level key and SILENTLY
    truncated `description` to its first line — no error, and `fw audit`'s
    unparseable-YAML check sees a perfectly valid document;
  * a paragraph with no colon raised ScannerError and was caught.

The corpus held 5 instances: 1 loud, 4 silent. A census written against the loud
predicate alone reported 1 — which is why `test_multiline_description_is_not_silently_truncated`
below asserts round-trip content and not merely "it parses".

These tests drive the real script against a scratch TASKS_DIR rather than re-implementing
its substitution, so they stay honest if the emission moves.
"""

import re
import subprocess
from pathlib import Path

import pytest
import yaml

REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "agents" / "task-create" / "create-task.sh"

# Three paragraphs, deliberately covering both failure shapes: the second contains a
# colon (the silent-truncation trigger), the third does not (the ScannerError trigger).
DESCRIPTION = (
    "First paragraph about the defect.\n"
    "\n"
    "Second paragraph: this colon is what trips the scanner.\n"
    "\n"
    "Third paragraph with no colon."
)
PARAGRAPH_MARKERS = ("First paragraph", "Second paragraph", "Third paragraph")


def _sandbox(tmp_path: Path, with_templates: bool) -> Path:
    tasks = tmp_path / "tasks"
    (tasks / "active").mkdir(parents=True)
    (tasks / "completed").mkdir(parents=True)
    if with_templates:
        # Copy the real templates — a hand-written stub would not have the same
        # 'description: >' context the substitution matches against.
        import shutil

        shutil.copytree(REPO / ".tasks" / "templates", tasks / "templates")
    else:
        (tasks / "templates").mkdir()
    return tasks


def _create(tasks: Path, name: str, wf_type: str, *extra: str) -> Path:
    env = {
        "PATH": "/usr/bin:/bin:/usr/local/bin",
        "HOME": str(tasks.parent),
        "TASKS_DIR": str(tasks),
        "PROJECT_ROOT": str(tasks.parent),
    }
    proc = subprocess.run(
        [
            "bash", str(SCRIPT),
            "--name", name,
            "--description", DESCRIPTION,
            "--type", wf_type,
            "--owner", "agent",
            *extra,
        ],
        cwd=str(REPO), env=env, capture_output=True, text=True, timeout=120,
    )
    created = sorted((tasks / "active").glob("T-*.md"))
    assert created, (
        f"create-task.sh produced no task file (rc={proc.returncode})\n"
        f"stdout: {proc.stdout[-2000:]}\nstderr: {proc.stderr[-2000:]}"
    )
    return created[-1]


def _frontmatter(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    assert m, f"no frontmatter block in {path}"
    return yaml.safe_load(m.group(1))


def _assert_intact(path: Path) -> None:
    fm = _frontmatter(path)
    assert isinstance(fm, dict) and fm, f"frontmatter did not parse to a mapping: {path}"

    junk = [k for k in fm if " " in str(k)]
    assert not junk, (
        f"orphaned description paragraph(s) parsed as frontmatter keys: {junk}. "
        "The folded scalar ended early — description content leaked into the mapping."
    )

    description = str(fm.get("description") or "")
    missing = [p for p in PARAGRAPH_MARKERS if p not in description]
    assert not missing, (
        f"description lost paragraph(s) {missing}; got {description!r}. "
        "Parsing successfully is not sufficient — the value must survive round-trip."
    )


@pytest.mark.parametrize(
    "wf_type,extra",
    [
        ("build", ()),
        # The inception path is gated by the T-2204 recommendation check; --i-am-human is
        # its documented script/test escape and keeps us on the real emission path.
        ("inception", ("--i-am-human",)),
    ],
)
def test_multiline_description_is_not_silently_truncated(tmp_path, wf_type, extra):
    tasks = _sandbox(tmp_path, with_templates=True)
    _assert_intact(_create(tasks, f"Multiline {wf_type}", wf_type, *extra))


def test_fallback_inline_template_also_indents_every_line(tmp_path):
    """The heredoc fallback fires only when default.md is absent, so it is invisible to
    the two tests above — and it carried an identical copy of the defect."""
    tasks = _sandbox(tmp_path, with_templates=False)
    _assert_intact(_create(tasks, "Fallback path", "build"))


def test_single_line_description_still_round_trips(tmp_path):
    """Guard against a fix that only handles the multi-line case."""
    tasks = _sandbox(tmp_path, with_templates=True)
    env = {
        "PATH": "/usr/bin:/bin:/usr/local/bin",
        "HOME": str(tmp_path),
        "TASKS_DIR": str(tasks),
        "PROJECT_ROOT": str(tmp_path),
    }
    subprocess.run(
        ["bash", str(SCRIPT), "--name", "Single line", "--description",
         "One plain sentence with no newline.", "--type", "build", "--owner", "agent"],
        cwd=str(REPO), env=env, capture_output=True, text=True, timeout=120,
    )
    created = sorted((tasks / "active").glob("T-*.md"))
    assert created
    fm = _frontmatter(created[-1])
    assert "One plain sentence with no newline." in str(fm.get("description") or "")


def test_corpus_frontmatter_is_intact():
    """Standing census over the real corpus, asserted on BOTH failure shapes.

    Written against the loud predicate alone this returned 1 while 4 silent instances
    sat in the same corpus — the check and the defect have to share a predicate.
    """
    tasks_dir = REPO / ".tasks"
    files = sorted(tasks_dir.glob("active/T-*.md")) + sorted(tasks_dir.glob("completed/T-*.md"))
    if not files:
        pytest.skip("no task corpus in this checkout")

    unparseable, truncated = [], []
    for path in files:
        text = path.read_text(encoding="utf-8", errors="replace")
        m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
        if not m:
            unparseable.append((path.name, "no frontmatter"))
            continue
        try:
            fm = yaml.safe_load(m.group(1))
        except yaml.YAMLError as exc:
            unparseable.append((path.name, type(exc).__name__))
            continue
        if not isinstance(fm, dict) or not fm:
            unparseable.append((path.name, "not a mapping"))
            continue
        junk = [k for k in fm if " " in str(k)]
        if junk:
            truncated.append((path.name, junk))

    assert not unparseable, f"unparseable task frontmatter ({len(files)} scanned): {unparseable}"
    assert not truncated, f"description leaked into frontmatter keys ({len(files)} scanned): {truncated}"
