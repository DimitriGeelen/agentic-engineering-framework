"""Provider adapters for terminal session management (T-967)."""

from web.terminal.adapters.local_shell import LocalShellAdapter
from web.terminal.adapters.claude_code import ClaudeCodeAdapter

__all__ = ["LocalShellAdapter", "ClaudeCodeAdapter"]
