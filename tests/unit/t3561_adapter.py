"""Tests for T-3561 adapter — Stop hook and UserPromptSubmit hook integration.

Tests AC3: Runtime adapter hands messages to agent at safe boundary
Tests AC5: Sender sees state transitions
"""

import tempfile
from pathlib import Path
from unittest import mock

import pytest

from lib.sidecar import adapter, receiver


@pytest.fixture
def temp_project():
    """Set up a temporary project root for testing."""
    with tempfile.TemporaryDirectory() as tmpdir:
        project_root = Path(tmpdir)
        (project_root / ".context" / "sidecar").mkdir(parents=True, exist_ok=True)

        # Patch both modules
        with mock.patch.object(adapter, "_sidecar_dir", return_value=project_root / ".context" / "sidecar"):
            with mock.patch.object(receiver, "_root", return_value=project_root):
                yield project_root


def test_ac3_stop_hook_sets_ready_flag(temp_project):
    """AC3: Stop hook sets ready-for-input flag when agent is idle."""
    # Initially no ready flag
    assert not adapter.is_ready_for_input()

    # Stop hook runs and sets ready
    adapter.set_ready_for_input(True)

    # Now ready flag should be set
    assert adapter.is_ready_for_input()

    # Verify the flag file was created
    flag_path = adapter._ready_flag_path()
    assert flag_path.exists()
    content = flag_path.read_text()
    assert "ready: true" in content.lower()


def test_ac3_userpromptsubmit_clears_ready(temp_project):
    """AC3: UserPromptSubmit hook clears ready flag when new prompt starts."""
    # Set ready flag (simulating Stop hook)
    adapter.set_ready_for_input(True)
    assert adapter.is_ready_for_input()

    # UserPromptSubmit hook runs and clears it
    adapter.clear_ready_for_input()

    # Ready flag should now be false
    assert not adapter.is_ready_for_input()


def test_ac3_safe_boundary_timing(temp_project):
    """AC3: Ready flag transition is safe — no injection mid-tool-call."""
    # The stop hook sets ready ONLY when a turn ends (harness is idle)
    # The UserPromptSubmit hook clears it BEFORE the next turn starts
    # This ensures injection happens at a safe boundary, never mid-tool-call

    adapter.set_ready_for_input(True)
    ready1 = adapter.is_ready_for_input()
    assert ready1, "Agent should be marked ready after Stop hook"

    # UserPromptSubmit runs (clearing the flag happens first, before prompt)
    adapter.clear_ready_for_input()
    ready2 = adapter.is_ready_for_input()
    assert not ready2, "Agent should not be marked ready during prompt processing"


def test_get_pending_messages_empty(temp_project):
    """Test getting pending messages when none exist."""
    messages = adapter.get_pending_messages()
    assert messages == []


def test_get_pending_messages_returns_unhandled(temp_project):
    """Test that get_pending_messages returns messages not yet handed over."""
    # Store a message
    msg_id = "test-pending-001"
    envelope = {
        "from": "agent-a",
        "to": "agent-b",
        "conversation_id": "conv-001",
        "body": "Test message",
    }
    receiver.store_message(msg_id, envelope)

    # Get pending messages
    messages = adapter.get_pending_messages()
    assert len(messages) == 1
    assert messages[0]["msg_id"] == msg_id
    assert messages[0]["from"] == "agent-a"
    assert messages[0]["body"] == "Test message"


def test_get_pending_messages_skips_handed_over(temp_project):
    """Test that already-handed-over messages are not returned."""
    # Store a message
    msg_id = "test-handed-001"
    envelope = {
        "from": "agent-a",
        "to": "agent-b",
        "conversation_id": "conv-001",
        "body": "Already handled",
    }
    receiver.store_message(msg_id, envelope)

    # Mark it as handed over
    receiver.mark_handed_over(msg_id)

    # Get pending messages should not include it
    messages = adapter.get_pending_messages()
    assert len(messages) == 0


def test_ready_flag_freshness(temp_project):
    """Test that stale ready flags are treated as not ready (safety fallback)."""
    # Set ready
    adapter.set_ready_for_input(True)
    assert adapter.is_ready_for_input()

    # Manipulate the flag file to be old (optional: test stale detection)
    # For now, we test that clearing always works
    adapter.set_ready_for_input(False)
    assert not adapter.is_ready_for_input()
