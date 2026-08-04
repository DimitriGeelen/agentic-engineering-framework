"""Playwright tests must take their target from one place (T-2784).

81 of 150 `tests/playwright/test_*.py` files had drifted into defining their own
module-level `TEST_URL = "http://localhost:3099"`, and none of them read `FW_TEST_PORT`.
They did depend on the `page` fixture, so a server was always started — this was never the
missing-dependency bug T-2782 fixed. It is the other half of the same class:

    conftest.py  starts / adopts / identity-checks / age-bounds a server on FW_TEST_PORT
    the tests    send their requests to a literal 3099

While those agree, everything works, which is why 81 files accumulated without anyone
noticing. When they disagree, T-2782's identity check and staleness bound are guarding a
server the tests are not talking to — and if anything else holds 3099 (every consumer
project runs the same Flask app, and CLAUDE.md §Watchtower Port records 371 verification
lines that passed against another project's Watchtower on :3000) the suite asserts
confidently against it.

This guard is the part that keeps it fixed. The 81 files drifted one at a time, each one a
reasonable local choice; nothing was watching the aggregate. That is the actual defect.
"""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PW_DIR = os.path.join(ROOT, "tests", "playwright")

# A bare host:port literal. Matches "http://localhost:3099", "127.0.0.1:5000" and friends.
# Deliberately not anchored to 3099 — the defect is hard-coding *an* address, not that
# particular one, and a guard that only knows today's number teaches people to pick a
# different one.
_LITERAL = re.compile(r"(?:localhost|127\.0\.0\.1)\s*:\s*\d{2,5}")

# target.py builds the address from FW_TEST_PORT and is the single source this guard exists
# to funnel everything through; conftest.py imports from it and manages the server.
_ALLOWED = {"conftest.py", "target.py"}


def _offenders():
    found = {}
    for name in sorted(os.listdir(PW_DIR)):
        if not name.endswith(".py") or name in _ALLOWED:
            continue
        path = os.path.join(PW_DIR, name)
        with open(path, encoding="utf-8") as fh:
            hits = [
                (i, line.strip())
                for i, line in enumerate(fh, 1)
                if _LITERAL.search(line) and not line.lstrip().startswith("#")
            ]
        if hits:
            found[name] = hits
    return found


def test_no_playwright_test_hardcodes_its_own_target():
    offenders = _offenders()
    assert not offenders, (
        "these Playwright test files build their own target address instead of taking it "
        "from conftest:\n"
        + "\n".join(
            f"  {name}:{hits[0][0]}: {hits[0][1]}"
            + (f"   (+{len(hits) - 1} more)" if len(hits) > 1 else "")
            for name, hits in offenders.items()
        )
        + "\n\nUse `from tests.playwright.target import TEST_URL` (or take the `base_url` "
        "fixture). A literal address means conftest can start, identity-check and "
        "age-bound a server on FW_TEST_PORT while the test talks to a different one — the "
        "wrong-object failure T-2782/T-2784 exist to close."
    )


def test_the_guard_can_see_a_violation(tmp_path, monkeypatch):
    """Mutation check (L-530): a guard that has never been red proves only that it runs."""
    (tmp_path / "test_fake_offender.py").write_text('TEST_URL = "http://localhost:3099"\n')
    (tmp_path / "test_clean.py").write_text("from tests.playwright.conftest import TEST_URL\n")
    monkeypatch.setitem(globals(), "PW_DIR", str(tmp_path))

    offenders = _offenders()
    assert "test_fake_offender.py" in offenders, (
        "the guard did not flag a file containing a bare localhost:3099 literal"
    )
    assert "test_clean.py" not in offenders, (
        "the guard flagged a file that takes its target from conftest — it would fire on "
        "the fix as well as the defect, which makes it useless as a gate"
    )


def test_target_module_is_the_single_source():
    """The allow-list is only sound while target.py actually derives from FW_TEST_PORT.

    Funnelling 81 files through one module buys nothing if that module hard-codes the port
    itself — it would just relocate the literal and make the guard green about it.
    """
    with open(os.path.join(PW_DIR, "target.py"), encoding="utf-8") as fh:
        src = fh.read()
    assert "FW_TEST_PORT" in src, (
        "target.py no longer reads FW_TEST_PORT, so funnelling every test through it no "
        "longer makes the suite follow the configured port"
    )


def test_conftest_takes_its_target_from_the_same_source():
    """The server that gets started and the address that gets requested must agree.

    This is the whole point: if conftest resolved the port independently, the two could
    drift apart again and every guarantee T-2782 added would attach to the wrong server.
    """
    with open(os.path.join(PW_DIR, "conftest.py"), encoding="utf-8") as fh:
        src = fh.read()
    assert "from tests.playwright.target import" in src, (
        "conftest resolves its own address instead of importing from target.py — the "
        "address under test and the address under guard can diverge again"
    )
