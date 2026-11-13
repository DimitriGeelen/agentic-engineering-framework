"""T-5119 (055 T-645) — a review seat refused by its provider is named as a provider refusal,
and a harness seat under the /tmp root is found at all (it used to read "no completion")."""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_HERE))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib.reviewer import judge_cli  # noqa: E402
from _review_runtime import hermetic_review_env  # noqa: E402,F401  (autouse)
import t3852_unavailable_seat_test as ut  # noqa: E402
from t3852_unavailable_seat_test import wdirs  # noqa: E402,F401

# The shape opencode prints when z.ai refuses the account (055, 2026-11-13): HTTP 429, code 1113,
# the provider body nested as an escaped JSON string.
ZAI_BALANCE = [{"type": "error", "timestamp": 1, "sessionID": "ses_x",
                "error": {"name": "APIError",
                          "data": {"message": "Insufficient balance or no resource package. Please recharge.",
                                   "statusCode": 429,
                                   "responseBody": json.dumps({"error": {
                                       "code": "1113",
                                       "message": "Insufficient balance or no resource package. Please recharge."}})}}}]


def test_balance_refusal_is_named_with_the_provider_code(wdirs):
    ut._dead_seat(wdirs, "judge-r-1", exit_code=1, stream=ZAI_BALANCE)
    assert judge_cli._unavailable_reason("judge-r-1") == \
        "provider refused: balance or quota (code 1113) (exit 1)"


def test_balance_refusal_without_a_code(wdirs):
    ev = [{"type": "error", "message": "You exceeded your current quota, please check your plan."}]
    ut._dead_seat(wdirs, "judge-r-2", exit_code=1, stream=ev)
    assert judge_cli._unavailable_reason("judge-r-2") == "provider refused: balance or quota (exit 1)"


def test_authentication_refusal(wdirs):
    ev = [{"type": "error", "error": {"type": "authentication_error", "message": "invalid x-api-key"}}]
    ut._dead_seat(wdirs, "judge-r-3", exit_code=1, stream=ev)
    assert judge_cli._unavailable_reason("judge-r-3") == "provider refused: authentication (exit 1)"


def test_a_code_elsewhere_in_the_stream_is_not_taken(wdirs):
    ev = [{"type": "step", "code": 200},
          {"type": "error", "message": "Insufficient balance"}]
    ut._dead_seat(wdirs, "judge-r-4", exit_code=1, stream=ev)
    assert judge_cli._unavailable_reason("judge-r-4") == "provider refused: balance or quota (exit 1)"


def test_control_a_plain_429_is_still_a_rate_limit(wdirs):
    ut._dead_seat(wdirs, "judge-r-5", exit_code=1, stream=[{"type": "error", "message": "HTTP 429"}])
    assert judge_cli._unavailable_reason("judge-r-5") == "rate limit (exit 1)"


def test_control_a_review_that_mentions_billing_is_not_a_refusal(wdirs):
    w = wdirs / "judge-r-6"
    w.mkdir(parents=True)
    (w / "exit_code").write_text("1\n")
    (w / "result.md").write_text("The billing page returns 401 Unauthorized for guests.\n")
    assert judge_cli._unavailable_reason("judge-r-6") == "exit 1"


def test_a_harness_seat_in_the_tmp_root_is_found(tmp_path, monkeypatch):
    """No pinned FW_DISPATCH_DIR: roots are <project>/.context/dispatch then the /tmp root. A
    codex/opencode/antigravity seat lives in the second (T-4675 exception)."""
    proj, legacy = tmp_path / "proj", tmp_path / "legacy"
    (proj / ".context" / "dispatch").mkdir(parents=True)
    monkeypatch.delenv("FW_DISPATCH_DIR", raising=False)
    monkeypatch.setenv("PROJECT_ROOT", str(proj))
    monkeypatch.setenv("FW_DISPATCH_LEGACY_DIR", str(legacy))
    ut._dead_seat(legacy, "judge-r-7", exit_code=1, stream=ZAI_BALANCE)
    assert judge_cli._unavailable_reason("judge-r-7") == \
        "provider refused: balance or quota (code 1113) (exit 1)"


def test_control_a_seat_in_neither_root_is_still_no_completion(tmp_path, monkeypatch):
    monkeypatch.delenv("FW_DISPATCH_DIR", raising=False)
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path / "proj"))
    monkeypatch.setenv("FW_DISPATCH_LEGACY_DIR", str(tmp_path / "legacy"))
    assert judge_cli._unavailable_reason("judge-nowhere") == "no completion"
