"""T-3502 — arc membership must read frontmatter to its terminator, not to a byte count.

Slice S1 of T-3501. The defect was reported by cashweb-integration-agent
(agent-chat-arc @1247) and measured here: `_HEAD_READ_BYTES = 1024` left 56
membership markers beyond the cut, undercounting **17 of 29 arcs** by 59 members,
and — because truncation landed mid-token — it also *fabricated* an arc id.

Every fixture here is constructed (T-3326: no live corpus counts pinned). The
fixtures are deliberately LONG, which is the whole point: 832-Workflow-designer's
root-cause note on the sibling arc defect was

    "a fence whose fixtures all come from today's template cannot see yesterday's
     records"

and this defect's dual is that every fixture anyone writes by hand is SHORT, so a
short-fixture suite passes against the broken reader. The boundary cases are
therefore asserted by construction, with the offset computed rather than guessed.
"""

import sys
import warnings
from pathlib import Path

import pytest

FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FRAMEWORK_ROOT / "lib"))
import arc_membership as A  # noqa: E402

OLD_BUDGET = 1024


def _task(dirpath, tid, *, arc_id=None, tags="[]", pad_to=0, body="", extra=""):
    """Write a task file whose `arc_id:` lands at >= `pad_to` bytes.

    Padding uses YAML comment lines, exactly like the real template's
    arc_id/demo_target/BVP comment block — which is what pushed real fields past
    byte 1024 in the live corpus.
    """
    head = f"---\nid: {tid}\nname: \"a task\"\nstatus: started-work\ntags: {tags}\n{extra}"
    pad = ""
    if pad_to:
        while len(head) + len(pad) < pad_to:
            pad += "# padding comment line, as in the real task template\n"
    tail = f"arc_id: {arc_id}\n" if arc_id else ""
    text = head + pad + tail + "---\n" + body
    p = dirpath / f"{tid}-x.md"
    p.write_text(text, encoding="utf-8")
    return p, text


@pytest.fixture()
def repo(tmp_path):
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    (tmp_path / ".tasks" / "completed").mkdir(parents=True)
    return tmp_path


def active(repo):
    return repo / ".tasks" / "active"


# ── the core defect ─────────────────────────────────────────────────────────

def test_an_arc_id_past_the_old_budget_is_now_counted(repo):
    """The case every hand-written short fixture misses."""
    p, text = _task(active(repo), "T-100", arc_id="my-arc", pad_to=1200)
    assert text.index("arc_id: my-arc") > OLD_BUDGET, "fixture is not past the old cut"

    by_id, _ = A.scan_tasks_by_arc_membership(repo)
    assert by_id.get("my-arc") == ["T-100"], (
        f"arc_id at byte {text.index('arc_id: my-arc')} was not seen: {by_id}")


def test_a_legacy_arc_tag_past_the_old_budget_is_now_counted(repo):
    """7 of the 56 live markers were tag-form, so the tag path needs its own leg."""
    head_pad = "# pad\n" * 200  # pushes the tags: line past 1024
    (active(repo) / "T-101-x.md").write_text(
        "---\nid: T-101\n" + head_pad + "tags: [arc:legacy-arc]\n---\nbody\n",
        encoding="utf-8")
    _, by_tag = A.scan_tasks_by_arc_membership(repo)
    assert by_tag.get("arc:legacy-arc") == ["T-101"]


def test_a_value_straddling_the_boundary_is_read_WHOLE_not_truncated(repo):
    """The phantom-arc regression.

    Live instance: T-1655's `arc_id: orchestrator-rethink` had byte 1024 fall
    inside the value, so the reader saw `orchestrator-reth` — dropping the task
    from its real arc AND inventing an arc with one member. A value that is merely
    *late* is a miss; a value cut MID-TOKEN is a fabrication, which is worse,
    because the phantom looks like real data.
    """
    name = "orchestrator-rethink"
    # Place the value so the old 1024-byte cut lands inside it.
    prefix = "---\nid: T-102\nname: \"a task\"\ntags: []\n"
    pad = ""
    while len(prefix) + len(pad) + len("arc_id: ") + 4 < OLD_BUDGET:
        pad += "# pad\n"
    text = prefix + pad + f"arc_id: {name}\n---\nbody\n"
    cut = text[:OLD_BUDGET]
    assert "arc_id: " in cut and name not in cut, (
        "fixture does not straddle the boundary; adjust the padding")

    (active(repo) / "T-102-x.md").write_text(text, encoding="utf-8")
    by_id, _ = A.scan_tasks_by_arc_membership(repo)

    assert by_id.get(name) == ["T-102"], f"full value not read: {by_id}"
    phantoms = [k for k in by_id if k != name and name.startswith(k)]
    assert phantoms == [], f"truncated prefix survives as a phantom arc: {phantoms}"


# ── THE CONTROL LEG ─────────────────────────────────────────────────────────

def test_a_short_frontmatter_task_is_unchanged(repo):
    """Without this, "fixed the truncation" is indistinguishable from "changed how
    membership is computed". A task well inside the old budget must behave exactly
    as before."""
    _task(active(repo), "T-200", arc_id="small-arc", tags="[arc:also-tagged]")
    by_id, by_tag = A.scan_tasks_by_arc_membership(repo)
    assert by_id == {"small-arc": ["T-200"]}
    assert by_tag == {"arc:also-tagged": ["T-200"]}


def test_a_task_with_no_arc_membership_stays_absent(repo):
    """Reading MORE must not invent membership where there is none."""
    _task(active(repo), "T-201", pad_to=1500)
    by_id, by_tag = A.scan_tasks_by_arc_membership(repo)
    assert by_id == {} and by_tag == {}


# ── the terminator is respected: the BODY is not membership ─────────────────

def test_body_content_is_NOT_scanned_for_membership(repo):
    """A genuine improvement from reading to the terminator rather than N bytes.

    `arc_id:` is matched at line-start, so a body line beginning `arc_id:` — a
    code block, a quoted example, a report pasted into a task — was eligible to
    match whenever frontmatter was short enough to leave budget for the body. It
    now cannot, because the read stops at the closing `---`.

    This is not hypothetical carelessness: computing arc counts with a whole-file
    regex during T-3501 produced phantom arcs named `foo`, `alpha` and `slug` from
    exactly this leakage.
    """
    (active(repo) / "T-300-x.md").write_text(
        "---\nid: T-300\ntags: []\n---\n"
        "Example from another task:\n"
        "arc_id: not-a-real-arc\n"
        "tags: [arc:also-not-real]\n",
        encoding="utf-8")
    by_id, by_tag = A.scan_tasks_by_arc_membership(repo)
    assert by_id == {}, f"body prose leaked into membership: {by_id}"
    assert by_tag == {}, f"body prose leaked into tag membership: {by_tag}"


# ── the cap: bounded, but never silently ────────────────────────────────────

def test_the_cap_still_exists(repo):
    """A runaway or binary file must not be slurped unbounded."""
    assert A._MAX_FRONTMATTER_BYTES >= 16384
    assert A._MAX_FRONTMATTER_BYTES <= 1024 * 1024


def test_hitting_the_cap_is_reported_and_not_read_as_absent(repo):
    """The rule this whole slice exists to install: a bounded read of an unbounded
    field must REPORT that it was bounded. The old failure mode was not the cut —
    it was that the cut was invisible."""
    huge = "---\nid: T-400\n" + ("# " + "x" * 200 + "\n") * 400 + "arc_id: late\n---\n"
    assert len(huge) > A._MAX_FRONTMATTER_BYTES
    p = active(repo) / "T-400-x.md"
    p.write_text(huge, encoding="utf-8")

    text, complete = A.read_frontmatter(p)
    assert complete is False, "cap was hit but the read claims to be complete"

    with warnings.catch_warnings(record=True) as caught:
        warnings.simplefilter("always")
        A.scan_tasks_by_arc_membership(repo)
    assert any("UNDETERMINED" in str(c.message) for c in caught), (
        "a truncated read passed silently — the exact failure this slice removes")


def test_a_normal_terminator_and_eof_both_count_as_complete(repo):
    """`complete` must mean "nothing was cut short", not "a terminator was seen".
    A malformed file read fully to EOF has had everything read."""
    p1, _ = _task(active(repo), "T-500", arc_id="a")
    assert A.read_frontmatter(p1)[1] is True

    p2 = active(repo) / "T-501-x.md"
    p2.write_text("---\nid: T-501\narc_id: b\n", encoding="utf-8")  # no closing ---
    text, complete = A.read_frontmatter(p2)
    assert complete is True
    assert "arc_id: b" in text


def test_a_file_without_leading_delimiter_is_not_cut_at_an_arbitrary_offset(repo):
    p = active(repo) / "T-600-x.md"
    p.write_text("id: T-600\n" + "# pad\n" * 300 + "arc_id: no-delim\n", encoding="utf-8")
    by_id, _ = A.scan_tasks_by_arc_membership(repo)
    assert by_id.get("no-delim") == ["T-600"]


# ── the path-valued variant shares the fix ─────────────────────────────────

def test_scan_by_arc_id_paths_also_sees_late_fields(repo):
    """Used by audit's stale-arc check, which needs paths. It called the same
    truncating reader, so it carried the same undercount."""
    _task(active(repo), "T-700", arc_id="audited-arc", pad_to=1300)
    by_arc = A.scan_tasks_by_arc_id(repo)
    assert list(by_arc) == ["audited-arc"]
    assert by_arc["audited-arc"][0].endswith("T-700-x.md")


def test_the_stale_budget_constant_is_gone(repo):
    """The old name must not survive as a live knob, and the justification comment
    that cited "~700 bytes / 1841 files" must not survive as a false basis."""
    assert not hasattr(A, "_HEAD_READ_BYTES"), "the fixed read budget is back"
    src = (FRAMEWORK_ROOT / "lib" / "arc_membership.py").read_text(encoding="utf-8")
    assert "largest frontmatter observed is ~700 bytes" not in src
