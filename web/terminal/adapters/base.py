"""SessionAdapter protocol — provider-neutral interface for terminal sessions (T-967).

Each provider (local shell, Claude Code, Ollama, etc.) implements this protocol.
Design: docs/reports/T-962-v7-orchestrator-design.md §4.2 L2.
"""

from typing import Optional, Protocol, runtime_checkable


@runtime_checkable
class SessionAdapter(Protocol):
    """Provider-specific session management.

    Implementations translate provider-neutral operations (spawn, inject, kill)
    into provider-specific invocations (pty.fork, claude -p, ollama run, etc.).
    """

    name: str  # Provider identifier: "local", "claude", "ollama", etc.

    def spawn(self, config: dict) -> dict:
        """Start a session.

        Args:
            config: Provider-specific configuration. Common keys:
                - shell: Shell binary path (local adapter)
                - cwd: Working directory
                - prompt: Initial prompt (agent adapters)
                - env: Additional environment variables
                - model: Model identifier (agent adapters)

        Returns:
            dict with at least: {"pid": int, "fd": int}
            May include additional provider-specific fields.
        """
        ...

    def capabilities(self) -> dict:
        """Declare what this provider supports.

        Returns:
            dict matching Capabilities schema: mode, file_edit, tool_use,
            streaming, context_window, persistent_thread.
        """
        ...

    def inject(self, handle: dict, data: bytes) -> None:
        """Send input to the session (PTY write or API message).

        Args:
            handle: The dict returned by spawn().
            data: Raw bytes to send.
        """
        ...

    def read(self, handle: dict, max_bytes: int = 65536) -> Optional[bytes]:
        """Read available output from the session.

        Args:
            handle: The dict returned by spawn().
            max_bytes: Maximum bytes to read.

        Returns:
            bytes if data available, None if session closed, b"" if nothing ready.
        """
        ...

    def resize(self, handle: dict, rows: int, cols: int) -> None:
        """Resize the PTY to the given dimensions.

        Args:
            handle: The dict returned by spawn().
            rows: New row count.
            cols: New column count.
        """
        ...

    def kill(self, handle: dict) -> None:
        """Terminate the session and clean up resources.

        Args:
            handle: The dict returned by spawn().
        """
        ...

    def get_cost(self, handle: dict) -> Optional[dict]:
        """Get current token usage.

        Returns:
            dict with token counts (input_tokens, output_tokens, etc.)
            or None for providers without token costs (local shells).
        """
        ...

    def is_alive(self, handle: dict) -> bool:
        """Check if the session process is still running.

        Args:
            handle: The dict returned by spawn().

        Returns:
            True if the session is still active.
        """
        ...
