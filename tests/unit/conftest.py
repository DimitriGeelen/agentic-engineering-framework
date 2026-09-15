"""Suite-level test isolation for tests/unit (T-3363).

## What this exists to stop

A test that passes alone and fails in the full suite. L-421 (T-1995 / T-1996 /
T-1997) names the two module-state causes:

1. **A reloaded module global is left dangling.** A test does
   `monkeypatch.setenv("PROJECT_ROOT", tmp)` then `importlib.reload(web.shared)`.
   `monkeypatch` restores the *environment variable* at teardown; it knows nothing
   about the module global the reload recomputed from it. `web.shared.PROJECT_ROOT`
   keeps pointing at a tmp dir that pytest then deletes. Every later test whose code
   path touches PROJECT_ROOT — a template lookup, an `(PROJECT_ROOT/p).exists()`
   guard — silently takes the wrong branch.

2. **`del sys.modules[mod]` + reimport replaces the module object**, orphaning other
   tests' import-time `from mod import fn` bindings.

`tests/unit/test_decide_commit.py:55-59` is a live instance of (1), and there are
15 reload-based files in this directory.

## Why the fix is here and not in the 15 polluters

T-1995 diagnosed this correctly and fixed it with a per-test autouse re-pin fixture
— placed in **two** files (`test_render_page_guard.py`,
`test_render_artefact_paths.py`). Both are immune. The six files that were never
given the fixture stayed broken for months: 16 failing tests, invisible because the
nightly unit suite was starving its own pytest leg (T-3359) and reporting
`failed_count: 0`.

That is the lesson this file encodes. A per-file fixture's coverage is exactly the
set of files someone had already watched fail; it protects no test written
afterwards. Polluter-side repair (L-421's other option: prefer `importlib.reload`
over `del sys.modules`) is O(15) today and reopens the moment a 16th reload lands.

One autouse fixture in one conftest is O(1), covers every test in this directory
including the ones not yet written, and needs no edit to any polluter.

See `docs/reports/T-3362-pytest-triage.md` for the measurement.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

# The real repository root: tests/unit/conftest.py -> tests/unit -> tests -> repo.
_REPO = Path(__file__).resolve().parents[2]

# Module globals that a reload recomputes from the environment and that nothing
# else restores. Keyed by attribute name so this stays a list of *names*, not a
# list of modules — any already-imported module carrying one gets restored.
_FRAGILE_ATTRS = ("PROJECT_ROOT",)


def _fragile_modules():
    """Already-imported modules carrying a fragile attribute.

    Iterates a snapshot of `sys.modules`: a test may import more while running, and
    mutating-during-iteration would raise. Restricted to the packages this repo owns
    so a third-party module that happens to define PROJECT_ROOT is left alone.
    """
    for name, mod in list(sys.modules.items()):
        if mod is None:
            continue
        if not (name == "web" or name.startswith(("web.", "agents.", "lib."))):
            continue
        for attr in _FRAGILE_ATTRS:
            if hasattr(mod, attr):
                yield mod, attr


@pytest.fixture(autouse=True)
def _restore_fragile_module_globals():
    """Snapshot fragile module globals, restore them after the test.

    Restores rather than merely re-pins to `_REPO`: a test that legitimately points
    PROJECT_ROOT somewhere for its own duration gets its value back untouched, and
    only the *leak* is undone.

    The post-test pass re-scans `sys.modules` instead of reusing the pre-test list,
    because the pollution we care about most — `importlib.reload` — can introduce the
    attribute on a module that did not carry it when the test started.
    """
    saved = {id(mod): (mod, attr, getattr(mod, attr)) for mod, attr in _fragile_modules()}

    yield

    for mod, attr in _fragile_modules():
        key = id(mod)
        if key in saved:
            _, _, original = saved[key]
            if getattr(mod, attr, None) != original:
                setattr(mod, attr, original)
        else:
            # Module appeared (or gained the attribute) during the test. There is no
            # "before" to restore, so pin the repo root — a dangling tmp path here is
            # exactly the T-1995 failure.
            setattr(mod, attr, _REPO)


# ---------------------------------------------------------------------------
# T-3367: rebound class identity — a third cause, neither of L-421's two.
#
# `importlib.reload(m)` re-executes m in place. `sys.modules[m]` keeps its
# identity — which is why every module-level guard, including the one above,
# misses this — but every `class X:` statement in m builds a NEW class object.
# Any module that did `from m import X` at import time still holds the old one.
#
# It takes three participants, which is why single-file bisection never found it
# and why it outlived T-1995 / T-1997 / T-3362:
#
#   1. an early MODULE-LEVEL importer pins the old class
#      (tests/unit/test_chunk_cap.py:28  `from web import embeddings as E`,
#       and web/embeddings.py:29 `from web.config import Config`)
#   2. a reloader builds a new one
#      (tests/unit/test_csrf_cookie_scoping.py:45  `importlib.reload(web.config)`)
#   3. a victim whose own import is LAZY straddles the two: its in-function
#      `from web.config import Config` resolves to the new class, while the code
#      under test still reads the old one, so monkeypatching is silently inert
#      (tests/unit/test_embed_health.py:148,198 -> 6 failures;
#       tests/unit/test_incremental_reindex.py:528 -> 4)
#
# Measured minimal reproducer, with both controls:
#   chunk_cap + csrf + embed_health -> identical=False, 6 failed
#   drop chunk_cap                  -> identical=True,  29 passed
#   drop csrf                       -> identical=True,  35 passed
#
# Restoring the ORIGINAL class re-aligns every import-time consumer at once,
# because they all bound that same original. Fixing it consumer-by-consumer is
# whack-a-mole and reopens on the next `from web.config import ...`.
#
# Test-side on purpose: `from web.config import Config` in web/embeddings.py is
# ordinary Python, not a defect. The defect is a test reloading a module that
# other modules bound from.
# ---------------------------------------------------------------------------

# module name -> attributes whose *identity* a reload destroys.
_FRAGILE_BINDINGS = {"web.config": ("Config",)}

# Captured once, the first time each attribute is seen, so the restore target is
# the object every import-time consumer bound — not whatever a prior test left.
_ORIGINAL_BINDINGS: dict = {}


@pytest.fixture(autouse=True)
def _restore_rebound_class_identity():
    """Restore class objects that `importlib.reload` rebuilt underneath importers."""
    for mod_name, attrs in _FRAGILE_BINDINGS.items():
        mod = sys.modules.get(mod_name)
        if mod is None:
            continue
        for attr in attrs:
            key = (mod_name, attr)
            if key not in _ORIGINAL_BINDINGS and hasattr(mod, attr):
                _ORIGINAL_BINDINGS[key] = getattr(mod, attr)

    yield

    for (mod_name, attr), original in _ORIGINAL_BINDINGS.items():
        mod = sys.modules.get(mod_name)
        # `is not` on purpose: this is an identity failure, not a value one. The
        # rebuilt class compares equal on every attribute and is still wrong.
        if mod is not None and getattr(mod, attr, None) is not original:
            setattr(mod, attr, original)
