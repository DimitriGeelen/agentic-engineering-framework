#!/usr/bin/env python3
"""Optional components a project may leave out on purpose (T-4355, T-5080).

The only list. Read by `fw doctor` (bin/fw runs this file to print the names) and
by `fw config components` (lib/config_components.py imports it). ABSENT_COMPONENTS
names entries from it. Kept as a .py file so `fw vendor` ships it to consumers
(vendoring copies .sh and .py under lib/, not data files).
"""

# (name, command that shows it is installed, description)
COMPONENTS = (
    ("termlink", "termlink", "Cross-terminal sessions and workers (fw termlink, dispatch)"),
    ("node", "node", "Node.js, runs the TypeScript hooks (Python fallback without it)"),
    ("bats", "bats", "Shell test runner (framework repo tests)"),
    ("shellcheck", "shellcheck", "Shell script linter"),
    ("pi", "pi", "Pi coding agent (workflows with worker_kind: pi)"),
    ("ollama", "ollama", "Local model server (ollama-loop workflows)"),
    ("litellm", "litellm", "LiteLLM proxy (workflows that set ANTHROPIC_BASE_URL)"),
    ("playwright", "playwright", "Playwright browser tests (pip package and MCP server; UI regression tests)"),
)

NAMES = tuple(c[0] for c in COMPONENTS)

if __name__ == "__main__":
    print(" ".join(NAMES))
