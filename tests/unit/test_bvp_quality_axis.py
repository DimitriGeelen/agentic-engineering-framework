"""T-3497 — the QUALITY axis (slice 4 of T-3484).

Two properties under test, and both exist because this task's own premise was
wrong before any code was written:

1. **Count events by `kind:`, not by substring.** The design doc claimed 1,970
   operator-correction entries in `feedback-stream.yaml`, from a grep for
   `auto_tick|override|untick` across the whole file. Counted by kind the corpus
   holds 125 `override_applied` and 12 `auto_tick` — the grep was matching
   payload prose. A signal counted the wrong way is not a smaller signal, it is
   a different one.

2. **An unreadable source is not a clean record.** `available: False` must be
   distinguishable from a task that genuinely has zero corrections, for the same
   reason S1 refuses to render unmeasured cost as 0.

No live corpus counts are pinned (T-3326) — every stream here is a fixture.
"""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from lib import bvp_outcomes as bo  # noqa: E402


def _event(kind, task_id, extra=""):
    return f"---\nkind: {kind}\ntimestamp: '2026-01-01T00:00:00Z'\ntask_id: {task_id}\n{extra}"


@pytest.fixture()
def repo(tmp_path):
    (tmp_path / ".context" / "working").mkdir(parents=True)
    (tmp_path / ".tasks" / "completed").mkdir(parents=True)
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    return tmp_path


def _stream(repo, text):
    (repo / ".context" / "working" / "feedback-stream.yaml").write_text(text, encoding="utf-8")


def _task(repo, where, tid, *, created, name="a task", related="[]", tags="[]"):
    (repo / ".tasks" / where / f"{tid}-x.md").write_text(
        f"---\nid: {tid}\nname: \"{name}\"\ncreated: {created}\n"
        f"related_tasks: {related}\ntags: {tags}\n---\n", encoding="utf-8")


# ── counting by kind, not by substring ──────────────────────────────────────

def test_counts_override_applied_by_kind(repo):
    _stream(repo, _event("override_applied", "T-1") + _event("override_applied", "T-1")
            + _event("scan_emitted", "T-1"))
    q = bo.quality_for_task("T-1", root=repo)
    assert q["operator_corrections"] == 2
    assert q["auto_ticks"] == 0


def test_a_mention_in_payload_prose_is_NOT_a_correction(repo):
    """The exact error this task's premise made.

    A `scan_emitted` event whose payload happens to contain the word
    'override_applied' must not be counted. Substring counting inflated the
    design doc's claim by more than an order of magnitude.
    """
    _stream(repo, _event("scan_emitted", "T-2",
                         "payload:\n  note: 'override_applied appears here as text'\n"))
    q = bo.quality_for_task("T-2", root=repo)
    assert q["operator_corrections"] == 0, (
        "payload prose was counted as an event — the substring bug is back")


def test_events_for_other_tasks_are_not_absorbed(repo):
    _stream(repo, _event("override_applied", "T-3") + _event("override_applied", "T-4"))
    assert bo.quality_for_task("T-3", root=repo)["operator_corrections"] == 1


def test_auto_ticks_are_counted_separately_from_corrections(repo):
    """They are different claims: one is the machine acting, one is a human
    saying the machine was wrong. Summing them would lose the direction."""
    _stream(repo, _event("auto_tick", "T-5") + _event("override_applied", "T-5"))
    q = bo.quality_for_task("T-5", root=repo)
    assert (q["auto_ticks"], q["operator_corrections"]) == (1, 1)


# ── unreadable is not zero ──────────────────────────────────────────────────

def test_a_missing_stream_is_unavailable_not_a_clean_record(repo):
    q = bo.quality_for_task("T-6", root=repo)
    assert q["available"] is False
    assert "reason" in q


def test_a_present_stream_with_no_events_for_this_task_is_a_REAL_zero(repo):
    """The control leg: available:True with zeros must be distinguishable from
    available:False. Otherwise 'no corrections' and 'no data' collapse."""
    _stream(repo, _event("override_applied", "T-OTHER"))
    q = bo.quality_for_task("T-7", root=repo)
    assert q["available"] is True
    assert q["operator_corrections"] == 0


# ── follow-on defects: the at-or-after rule ─────────────────────────────────

def test_a_later_bug_task_naming_it_counts(repo):
    _task(repo, "completed", "T-10", created="2026-01-01T00:00:00Z")
    _task(repo, "completed", "T-11", created="2026-02-01T00:00:00Z",
          name="fix the thing T-10 broke", related="[T-10]")
    _stream(repo, "")
    assert bo.quality_for_task("T-10", root=repo)["follow_on_defects"] == 1


def test_an_EARLIER_task_naming_it_does_not_count(repo):
    """A task filed before this one cannot be a defect this one caused, however
    much it mentions it. Same discipline as S1's cost join."""
    _task(repo, "completed", "T-20", created="2026-06-01T00:00:00Z")
    _task(repo, "completed", "T-19", created="2026-01-01T00:00:00Z",
          name="an earlier fix mentioning T-20", related="[T-20]")
    _stream(repo, "")
    assert bo.quality_for_task("T-20", root=repo)["follow_on_defects"] == 0


def test_a_later_NON_bug_task_naming_it_does_not_count(repo):
    """Follow-on work is not the same as a follow-on defect. A build slice that
    continues the work is healthy; counting it as a defect would penalise
    exactly the propagation the GO-scope check wants to see."""
    _task(repo, "completed", "T-30", created="2026-01-01T00:00:00Z")
    _task(repo, "completed", "T-31", created="2026-02-01T00:00:00Z",
          name="add the next slice on top of T-30", related="[T-30]")
    _stream(repo, "")
    assert bo.quality_for_task("T-30", root=repo)["follow_on_defects"] == 0


def test_an_unknown_subject_yields_zero_rather_than_raising(repo):
    _stream(repo, "")
    assert bo.quality_for_task("T-NOPE", root=repo)["follow_on_defects"] == 0


# ── wiring into the ledger ──────────────────────────────────────────────────

def test_record_realised_derives_quality_when_not_passed(repo):
    _stream(repo, _event("override_applied", "T-40"))
    _task(repo, "completed", "T-40", created="2026-01-01T00:00:00Z")
    row = bo.record_realised("T-40", ts="t", root=repo)
    assert row["quality"]["operator_corrections"] == 1
    assert row["quality"]["available"] is True


def test_an_explicit_quality_argument_still_wins(repo):
    """A caller with better information must not be overridden by the deriver."""
    _stream(repo, _event("override_applied", "T-41"))
    row = bo.record_realised("T-41", ts="t", quality={"hand": "written"}, root=repo)
    assert row["quality"] == {"hand": "written"}
