"""T-3335 (arc-020 S8): live termlink wiring for the notice-sink seam.

Covers termlink_notice_sink — the D5-bound-3 'inform operator' delivery wired
to a termlink channel — against a fake invoke (no live hub). The antifragile
invariant is the point: the local ledger fires unconditionally, the termlink
post is additional and best-effort, and a termlink failure never suppresses
the operator notice.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from lib import aef_repo_source as rs  # noqa: E402
from lib.aef_repo_source import (  # noqa: E402
    DEFAULT_NOTICE_CHANNEL,
    OperatorNotice,
    termlink_notice_sink,
)


def _notice(project="/opt/missing"):
    return OperatorNotice(
        ts="2026-09-07T00:00:00Z",
        project=project,
        peers_tried=("peer-a", "peer-b"),
        attempts=(),
        message="no peer holds the repo",
    )


class _FakeInvoke:
    def __init__(self, fail=False):
        self.calls: list[list[str]] = []
        self.fail = fail

    def __call__(self, args, *, timeout=20.0):
        self.calls.append(list(args))
        if self.fail:
            raise RuntimeError("hub down")
        return {"ok": True, "code": 0, "data": {"delivered": {"offset": 0}},
                "stdout": "", "stderr": ""}


def setup_function(_):
    rs.OPERATOR_NOTICES.clear()


def test_posts_notice_to_channel():
    fake = _FakeInvoke()
    sink = termlink_notice_sink(invoke=fake)
    sink(_notice())
    verbs = [c[1] for c in fake.calls if len(c) > 1]
    assert "create" in verbs and "post" in verbs
    post = next(c for c in fake.calls if len(c) > 1 and c[1] == "post")
    assert post[2] == DEFAULT_NOTICE_CHANNEL
    assert "/opt/missing" in post[3]
    assert "peer-a" in post[3]


def test_composes_local_ledger_by_default():
    sink = termlink_notice_sink(invoke=_FakeInvoke())
    sink(_notice())
    assert len(rs.OPERATOR_NOTICES) == 1  # local delivery preserved


def test_termlink_failure_never_suppresses_the_notice():
    # hub down → sink must NOT raise, and the local ledger must still fire.
    sink = termlink_notice_sink(invoke=_FakeInvoke(fail=True))
    sink(_notice())  # must not raise
    assert len(rs.OPERATOR_NOTICES) == 1


def test_also_default_false_skips_ledger():
    sink = termlink_notice_sink(invoke=_FakeInvoke(), also_default=False)
    sink(_notice())
    assert len(rs.OPERATOR_NOTICES) == 0


def test_custom_channel_is_honored():
    fake = _FakeInvoke()
    termlink_notice_sink(channel="ops-alerts", invoke=fake)(_notice())
    post = next(c for c in fake.calls if len(c) > 1 and c[1] == "post")
    assert post[2] == "ops-alerts"


def test_sink_conforms_to_notice_sink_signature():
    # It is a plain Callable[[OperatorNotice], None] — usable directly as the
    # notice_sink= argument of source_repo / provision_with_sourcing.
    sink = termlink_notice_sink(invoke=_FakeInvoke())
    assert sink(_notice()) is None
