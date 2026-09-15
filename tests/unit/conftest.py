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
