"""The one place the Playwright suite decides what it is talking to (T-2784).

Before this module, `conftest.py` derived the address from `FW_TEST_PORT` while 81 of the
150 test files each defined their own `TEST_URL = "http://localhost:3099"`. While those two
agree nothing goes wrong, which is why 81 files accumulated the literal one at a time
without anyone noticing.

When they disagree, conftest starts, identity-checks and age-bounds a server on
`FW_TEST_PORT` — and the tests send their requests somewhere else. The guarantees T-2782
added then apply to a server the suite is not addressing, and if anything happens to hold
the hard-coded port (every consumer project runs the same Flask app; CLAUDE.md §Watchtower
Port records 371 verification lines that passed against another project's Watchtower on
:3000) the suite asserts confidently against it.

Deliberately standalone rather than importing from `conftest`: pytest imports conftest under
its own module name, so a test doing `from tests.playwright.conftest import TEST_URL` gets a
*second* copy of that module. Harmless for a constant, but it makes conftest the thing
everyone imports, which is the opposite of the direction dependencies should run. conftest
imports from here instead.
"""
import os

TEST_PORT = int(os.environ.get("FW_TEST_PORT", "3099"))
TEST_URL = f"http://localhost:{TEST_PORT}"


def url(path=""):
    """Absolute URL for `path` on the server under test."""
    return f"{TEST_URL}{path}"
