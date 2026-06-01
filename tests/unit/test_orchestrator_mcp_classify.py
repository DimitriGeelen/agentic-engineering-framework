"""T-2154 (T-1761 build): pin classify_by_convention behaviour.

The classifier lives inside agents/audit/orchestrator-mcp-scan.sh as an
inline Python function. To test it without dragging in the whole probe
machinery (baseline read, tools.rs grep, etc.), we extract the function
source into a temp module via the actual scan-script bytes — keeping the
test honest about what shipped, not against a duplicated copy.

Convention canonical-form source: docs/reports/T-1761-auto-classify-heuristic.md
§Re-evaluation + the baseline header annotations across 7 batches
(T-1755, T-1755 f/u, T-1760, T-1867, T-2073, T-2073 f/u, T-2150).

If the classifier moves out of the shell-embedded Python block into its own
module, update the EXTRACT block here — the assertions should stay valid.
"""
from __future__ import annotations

import re
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
SCAN_SCRIPT = REPO_ROOT / "agents" / "audit" / "orchestrator-mcp-scan.sh"


@pytest.fixture(scope="module")
def classify_by_convention():
    """Extract classify_by_convention + its dependent constants from the
    scan script's embedded Python block, exec into a namespace, return the
    function reference."""
    src = SCAN_SCRIPT.read_text()
    # Pull the Python block (between python3 - <<'PYEOF' and PYEOF).
    m = re.search(r"python3 - <<'PYEOF'\n(.*?)\nPYEOF\n", src, re.DOTALL)
    assert m, "Could not locate PYEOF block in scan script"
    py_block = m.group(1)
    # The block uses os.environ at module level; isolate ONLY the classifier
    # plus its two constant sets. Slice from the CONVENTION_NAMESPACES line
    # to the end of classify_by_convention's return — terminate at the next
    # comment boundary (the tag-format-lint comment marker T-1649).
    slice_m = re.search(
        r"(CONVENTION_NAMESPACES = .*?return 'readonly_exempt'\n)",
        py_block,
        re.DOTALL,
    )
    assert slice_m, "Could not locate classifier slice in PYEOF block"
    ns: dict = {"frozenset": frozenset}
    exec(slice_m.group(1), ns)
    return ns["classify_by_convention"]


# (a) action-verb suffix in termlink_agent_* → mutator
def test_agent_post_is_mutator(classify_by_convention):
    assert classify_by_convention("termlink_agent_post") == "mutators_ungated"


# (b) read-shape suffix in termlink_agent_* → readonly
def test_agent_status_is_readonly(classify_by_convention):
    assert classify_by_convention("termlink_agent_status") == "readonly_exempt"


# (c) action-verb suffix in termlink_channel_* → mutator
def test_channel_broadcast_is_mutator(classify_by_convention):
    assert classify_by_convention("termlink_channel_broadcast") == "mutators_ungated"


# (d) read-shape suffix in termlink_channel_* → readonly
def test_channel_recent_is_readonly(classify_by_convention):
    assert classify_by_convention("termlink_channel_recent") == "readonly_exempt"


# (e) out-of-namespace → unknown (bounded blast radius)
def test_orchestrator_namespace_unknown(classify_by_convention):
    assert classify_by_convention("termlink_orchestrator_foo") == "unknown"


def test_fleet_namespace_unknown(classify_by_convention):
    # T-2073 batch DID classify fleet_reauth manually — but T-1761 chose
    # the bounded shape (agent + channel only). Fleet stays unknown.
    assert classify_by_convention("termlink_fleet_reauth") == "unknown"


# (f) multi-word verb (poll_start/end/vote) → mutator
def test_agent_poll_start_is_mutator(classify_by_convention):
    assert classify_by_convention("termlink_agent_poll_start") == "mutators_ungated"


def test_agent_poll_end_is_mutator(classify_by_convention):
    assert classify_by_convention("termlink_agent_poll_end") == "mutators_ungated"


def test_agent_poll_vote_is_mutator(classify_by_convention):
    assert classify_by_convention("termlink_agent_poll_vote") == "mutators_ungated"


# (g) typing_emit multi-word verb → mutator
def test_agent_typing_emit_is_mutator(classify_by_convention):
    assert classify_by_convention("termlink_agent_typing_emit") == "mutators_ungated"


# Extra sanity: tools currently in the baseline classify the same way they
# were manually classified — proves the convention reproduces the existing
# state (zero-misclassification claim).
def test_existing_baseline_known_mutator_agent_send(classify_by_convention):
    # termlink_agent_send is in mutators_ungated per the 7-batch history.
    assert classify_by_convention("termlink_agent_send") == "mutators_ungated"


def test_existing_baseline_known_readonly_agent_threads(classify_by_convention):
    # termlink_agent_threads is in readonly_exempt — "threads" is a list-shape
    # noun, not a verb.
    assert classify_by_convention("termlink_agent_threads") == "readonly_exempt"


# Edge: empty suffix → unknown (don't silently mis-classify the namespace prefix itself)
def test_empty_suffix_is_unknown(classify_by_convention):
    assert classify_by_convention("termlink_agent_") == "unknown"
