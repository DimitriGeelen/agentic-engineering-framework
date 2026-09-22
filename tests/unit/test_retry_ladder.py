"""T-3434 — the universal message retry ladder (D-600).

Pure module, so these tests need no fixtures, no clock and no tmp_path.
They pin every rung boundary, the two-class verb split, exhaustion, and the
deliberate NotImplementedError on `urgent`.
"""

from datetime import datetime, timedelta, timezone

import pytest

from lib import retry_ladder as rl


def test_ladder_is_the_schedule_d600_ruled():
    assert rl.LADDER == [(2, 60), (2, 300), (2, 900), (2, 3600),
                         (2, 14400), (2, 86400), (2, 604800), (2, 2592000)]
    assert rl.MAX_ATTEMPTS == 16


@pytest.mark.parametrize("attempts,rung", [
    (0, 0), (1, 0),      # 2 x 1min
    (2, 1), (3, 1),      # 2 x 5min
    (4, 2), (5, 2),      # 2 x 15min
    (6, 3), (7, 3),      # 2 x 1h
    (8, 4), (9, 4),      # 2 x 4h
    (10, 5), (11, 5),    # 2 x 1d
    (12, 6), (13, 6),    # 2 x 1w
    (14, 7), (15, 7),    # 2 x 1mo
])
def test_every_rung_boundary(attempts, rung):
    assert rl.rung_for(attempts) == rung


def test_exhaustion_is_one_attempt_past_the_last_rung():
    assert rl.rung_for(15) == 7
    assert rl.rung_for(16) is None
    assert rl.rung_for(99) is None


def test_next_attempt_adds_that_rungs_delay_to_last_at():
    base = datetime(2026, 9, 22, 12, 0, 0, tzinfo=timezone.utc)
    for attempts, rung, seconds in [(1, 0, 60), (3, 1, 300), (5, 2, 900),
                                    (7, 3, 3600), (9, 4, 14400), (11, 5, 86400),
                                    (13, 6, 604800), (15, 7, 2592000)]:
        got_rung, due = rl.next_attempt(attempts, base.isoformat())
        assert got_rung == rung
        assert datetime.fromisoformat(due) == base + timedelta(seconds=seconds)


def test_next_attempt_returns_none_when_exhausted():
    assert rl.next_attempt(16, "2026-09-22T12:00:00+00:00") is None


def test_next_attempt_reads_a_naive_timestamp_as_utc():
    rung, due = rl.next_attempt(1, "2026-09-22T12:00:00")
    assert rung == 0
    assert datetime.fromisoformat(due) == datetime(
        2026, 9, 22, 12, 1, tzinfo=timezone.utc)


def test_whole_ladder_spans_about_seventy_six_days():
    span = sum(count * seconds for count, seconds in rl.LADDER)
    assert span == 6_604_920
    assert timedelta(days=76) < timedelta(seconds=span) < timedelta(days=77)


def test_is_due_compares_against_injected_now():
    assert rl.is_due("2026-09-22T12:00:00+00:00", "2026-09-22T12:00:01+00:00")
    assert rl.is_due("2026-09-22T12:00:00+00:00", "2026-09-22T12:00:00+00:00")
    assert not rl.is_due("2026-09-22T12:00:00+00:00", "2026-09-22T11:59:59+00:00")
    assert rl.is_due(None, "2026-09-22T11:59:59+00:00"), "no due time = due now"


@pytest.mark.parametrize("rung,verb", [
    (0, rl.REPOST), (1, rl.REPOST),
    (2, rl.NUDGE), (3, rl.NUDGE), (4, rl.NUDGE),
    (5, rl.OPERATOR), (6, rl.OPERATOR), (7, rl.OPERATOR),
    (None, rl.DEADLETTER), (8, rl.DEADLETTER), (-1, rl.DEADLETTER),
])
def test_verb_for_posted_is_the_escalation_ladder(rung, verb):
    assert rl.verb_for(rung) == verb


@pytest.mark.parametrize("rung", range(8))
def test_unposted_reposts_on_every_rung(rung):
    # A message that never reached the hub has nothing to escalate about:
    # the recipient holds nothing, so re-post stays the verb (D-600).
    assert rl.verb_for(rung, posted=False) == rl.REPOST


def test_unposted_still_deadletters_when_exhausted():
    assert rl.verb_for(None, posted=False) == rl.DEADLETTER


def test_nudge_starts_at_the_15_minute_rung():
    assert rl.LADDER[rl.NUDGE_RUNG][1] == 900
    assert rl.verb_for(rl.NUDGE_RUNG - 1) == rl.REPOST
    assert rl.verb_for(rl.NUDGE_RUNG) == rl.NUDGE


def test_operator_surface_starts_at_the_1_day_rung():
    assert rl.LADDER[rl.OPERATOR_RUNG][1] == 86400
    assert rl.verb_for(rl.OPERATOR_RUNG - 1) == rl.NUDGE
    assert rl.verb_for(rl.OPERATOR_RUNG) == rl.OPERATOR


def test_urgent_is_out_of_scope_and_says_where_the_design_lives():
    for call in (lambda: rl.next_attempt(1, "2026-09-22T12:00:00+00:00", urgent=True),
                 lambda: rl.rung_for(1, urgent=True),
                 lambda: rl.verb_for(0, urgent=True)):
        with pytest.raises(NotImplementedError) as exc:
            call()
        assert "separate conversation" in str(exc.value)
        assert "T-3434-retry-ladder.md" in str(exc.value)


def test_urgent_false_is_the_normal_path():
    assert rl.next_attempt(1, "2026-09-22T12:00:00+00:00", urgent=False) is not None


def test_negative_attempts_is_a_programming_error():
    with pytest.raises(ValueError):
        rl.rung_for(-1)


def test_describe_names_every_rung_and_exhaustion():
    text = rl.describe()
    assert text.count("rung ") == 8
    assert "exhausted after attempt 16" in text
