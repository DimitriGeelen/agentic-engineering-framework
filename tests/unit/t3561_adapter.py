"""Tests for T-3561 adapter — Stop hook and UserPromptSubmit hook integration.

Unit tests of the lib/sidecar/adapter.py functions (ready flag, pending peek).
The hook wiring, HANDED_OVER and sender states are proven in
test_sidecar_receiver_t3693.py and tests/integration/t3693_sidecar_e2e_test.py.
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
    """Adapter setter only. The real Stop hook wiring is tested in
    test_sidecar_receiver_t3693.py::test_stop_hook_sets_ready_via_fw_hook."""
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
    """Adapter clear only. Clear-FIRST ordering in the real prompt hook is tested in
    test_sidecar_receiver_t3693.py::test_prompt_hook_clears_ready_before_reading_messages."""
    # Set ready flag (simulating Stop hook)
    adapter.set_ready_for_input(True)
    assert adapter.is_ready_for_input()

    # UserPromptSubmit hook runs and clears it
    adapter.clear_ready_for_input()

    # Ready flag should now be false
    assert not adapter.is_ready_for_input()


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


def test_missing_or_unreadable_flag_reads_not_ready(temp_project):
    """Readiness fails toward NOT ready (T-3397:109): a message waits rather
    than being typed into a busy agent."""
    flag = adapter._ready_flag_path()
    if flag.exists():
        flag.unlink()
    assert not adapter.is_ready_for_input()
    flag.write_text("garbage without a ready line\n")
    assert not adapter.is_ready_for_input()
    flag.write_text("ready: maybe\n")
    assert not adapter.is_ready_for_input()
