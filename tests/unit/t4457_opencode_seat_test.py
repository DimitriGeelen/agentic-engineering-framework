"""T-4457 — the opencode review seat: the launch pins the registered model and closes stdin, and
a seat that dies on a provider error names that error in its unavailable reason."""
from __future__ import annotations

import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_HERE))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib.reviewer import judge_cli  # noqa: E402
from _review_runtime import hermetic_review_env  # noqa: E402,F401  (autouse)
import t3852_unavailable_seat_test as ut  # noqa: E402
from t3852_unavailable_seat_test import wdirs  # noqa: E402,F401

PROVIDER = [{"type": "error", "timestamp": 1, "sessionID": "ses_x",
             "error": {"name": "UnknownError",
                       "data": {"message": "Unexpected server error. Check server logs for details.",
                                "ref": "err_87ccce84"}}}]


def test_the_opencode_launch_passes_the_registered_model_and_closes_stdin():
    body = (_HERE / "agents/termlink/termlink.sh").read_text()
    line = next(l for l in body.splitlines() if 'run ${MODEL:+-m "$MODEL"}' in l)
    assert '--agent plan --pure --format json "$PROMPT_TEXT" < /dev/null' in line, line


def test_the_registry_pins_a_model_for_the_opencode_kind():
    text = (_HERE / "policy/review-backends.yaml").read_text()
    block = text.split("id: opencode", 1)[1].split("- id:", 1)[0]
    assert "model: zai-coding-plan/" in block, block


def test_a_provider_error_is_named_in_the_unavailable_reason(wdirs):
    ut._dead_seat(wdirs, "judge-o-1", exit_code=1, stream=PROVIDER)
    why = judge_cli._unavailable_reason("judge-o-1")
    assert why == "exit 1: Unexpected server error. Check server logs for details.", why


def test_the_provider_error_is_capped(wdirs):
    ev = [{"type": "error", "error": {"data": {"message": "y" * 5000}}}]
    ut._dead_seat(wdirs, "judge-o-2", exit_code=1, stream=ev)
    assert len(judge_cli._unavailable_reason("judge-o-2")) <= 120


def test_control_a_bare_exit_with_no_error_event_is_unchanged(wdirs):
    ut._dead_seat(wdirs, "judge-o-3", exit_code=1, stream=[{"type": "text", "part": {"text": "hi"}}])
    assert judge_cli._unavailable_reason("judge-o-3") == "exit 1"
