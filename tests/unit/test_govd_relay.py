"""T-2431 — pin the governance relay / proxy brain (arc-013, design §4b/§4c).

Covers the network-free core: SSE tool_use extraction, the coherent-denial turn
(round-trips to a text turn with no tool_use), the sovereign policy (governance-path
+ dangerous-Bash invariants), and the mediator (allow → passthrough, deny →
substitution + audit). The live E2E (claude -p through the relay) was proven in the
T-2429 spikes; this slice productionizes and unit-pins the mechanism.
"""
import json
import sys
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_ROOT))

from lib import govd_relay as R          # noqa: E402
from lib.govd_holder import AppendOnlyAudit  # noqa: E402


def _tool_use_sse(name, input_json, model="claude-opus-4-8"):
    def ev(t, d):
        return f"event: {t}\ndata: {json.dumps(d)}\n\n"
    return "".join([
        ev("message_start", {"type": "message_start",
            "message": {"model": model, "usage": {"input_tokens": 10, "output_tokens": 1}}}),
        ev("content_block_start", {"type": "content_block_start", "index": 0,
            "content_block": {"type": "tool_use", "id": "toolu_1", "name": name, "input": {}}}),
        ev("content_block_delta", {"type": "content_block_delta", "index": 0,
            "delta": {"type": "input_json_delta", "partial_json": input_json}}),
        ev("content_block_stop", {"type": "content_block_stop", "index": 0}),
        ev("message_delta", {"type": "message_delta",
            "delta": {"stop_reason": "tool_use"}, "usage": {"output_tokens": 5}}),
        ev("message_stop", {"type": "message_stop"}),
    ])


def _text_sse(text, model="claude-opus-4-8"):
    def ev(t, d):
        return f"event: {t}\ndata: {json.dumps(d)}\n\n"
    return "".join([
        ev("message_start", {"type": "message_start",
            "message": {"model": model, "usage": {"input_tokens": 8, "output_tokens": 1}}}),
        ev("content_block_start", {"type": "content_block_start", "index": 0,
            "content_block": {"type": "text", "text": ""}}),
        ev("content_block_delta", {"type": "content_block_delta", "index": 0,
            "delta": {"type": "text_delta", "text": text}}),
        ev("content_block_stop", {"type": "content_block_stop", "index": 0}),
        ev("message_delta", {"type": "message_delta", "delta": {"stop_reason": "end_turn"},
            "usage": {"output_tokens": 4}}),
        ev("message_stop", {"type": "message_stop"}),
    ])


POLICY = R.Policy(
    governance_paths=[".claude/settings.json", "policy/authority-envelope.yaml"],
    deny_command_patterns=["rm -rf /", "git push --no-verify"],
    deny_tools=["DangerousTool"],
)


# ── SSE parsing ─────────────────────────────────────────────────────────────
def test_parse_tool_uses_extracts_name_and_input():
    sse = _tool_use_sse("Bash", '{"command": "echo hi"}')
    tools = R.parse_tool_uses(sse)
    assert len(tools) == 1
    assert tools[0]["name"] == "Bash"
    assert json.loads(tools[0]["input"]) == {"command": "echo hi"}


def test_parse_tool_uses_none_for_text_turn():
    assert R.parse_tool_uses(_text_sse("hello")) == []


def test_parse_usage():
    u = R.parse_usage(_tool_use_sse("Bash", "{}"))
    assert u["input_tokens"] == 10 and u["output_tokens"] == 5


# ── coherent denial ─────────────────────────────────────────────────────────
def test_synth_deny_turn_is_a_text_turn_with_no_tool_use():
    out = R.synth_deny_turn("claude-opus-4-8", ["Bash"], "test reason").decode()
    assert R.parse_tool_uses(out) == []                  # no owed tool_result
    stops = [ev for ev in R._iter_data_events(out) if ev.get("type") == "message_delta"]
    assert stops and stops[0]["delta"]["stop_reason"] == "end_turn"
    assert "[GOVERNANCE]" in out and "Bash" in out


# ── Policy ──────────────────────────────────────────────────────────────────
def test_policy_denies_governance_path_edit():
    v, why = POLICY.decide("Edit", {"file_path": "/repo/.claude/settings.json"})
    assert v == "deny" and "governance" in why


def test_policy_allows_benign_edit():
    v, _ = POLICY.decide("Edit", {"file_path": "/repo/src/app.py"})
    assert v == "allow"


def test_policy_denies_dangerous_bash():
    v, why = POLICY.decide("Bash", {"command": "sudo rm -rf / --no-preserve-root"})
    assert v == "deny" and "pattern" in why


def test_policy_allows_benign_bash():
    v, _ = POLICY.decide("Bash", {"command": "echo hello"})
    assert v == "allow"


def test_policy_deny_tools():
    assert POLICY.decide("DangerousTool", {})[0] == "deny"


def test_policy_accepts_string_input_from_wire():
    # the relay passes input as the concatenated partial_json string
    v, _ = POLICY.decide("Bash", '{"command": "git push --no-verify"}')
    assert v == "deny"


# ── Mediator ────────────────────────────────────────────────────────────────
def test_mediate_allows_benign_passthrough():
    sse = _tool_use_sse("Bash", '{"command": "echo ok"}')
    out, decisions = R.Mediator(POLICY).mediate(sse, "claude-opus-4-8")
    assert out == sse                                    # untouched
    assert decisions == [{"name": "Bash", "verdict": "allow", "reason": "within policy"}]


def test_mediate_denies_and_substitutes(tmp_path):
    audit = AppendOnlyAudit(tmp_path / "a.jsonl")
    sse = _tool_use_sse("Edit", '{"file_path": ".claude/settings.json"}')
    out, decisions = R.Mediator(POLICY, audit).mediate(sse, "claude-opus-4-8")
    assert out != sse
    assert R.parse_tool_uses(out) == []                  # tool_use dropped
    assert "[GOVERNANCE]" in out
    assert decisions[0]["verdict"] == "deny"
    # audited
    lines = Path(audit.path).read_text().splitlines()
    assert any(json.loads(l)["event"] == "tool_intent" for l in lines)


def test_mediate_text_turn_passthrough():
    sse = _text_sse("just talking")
    out, decisions = R.Mediator(POLICY).mediate(sse, "claude-opus-4-8")
    assert out == sse and decisions == []


# ── Policy.load ─────────────────────────────────────────────────────────────
def test_policy_load_from_yaml(tmp_path):
    import yaml
    p = tmp_path / "pol.yaml"
    p.write_text(yaml.safe_dump({
        "invariants": {"governance_paths": [".git/hooks"], "deny_command_patterns": ["mkfs"]},
        "deny_tools": ["X"]}))
    pol = R.Policy.load(p)
    assert pol.decide("Bash", {"command": "mkfs.ext4 /dev/sda"})[0] == "deny"
    assert pol.decide("X", {})[0] == "deny"
    assert pol.decide("Bash", {"command": "ls"})[0] == "allow"
