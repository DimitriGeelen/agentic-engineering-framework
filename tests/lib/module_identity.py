"""Restore replaced module objects after a test (T-4616).

`sys.modules.pop("web.shared")` (or `del`) followed by a reimport builds a NEW
module object. Everything that bound the old one at import time keeps it: the
blueprints' `from web.shared import _auto_link_files`, a test file's module-level
`import web.search as search_mod`. Every later test that monkeypatches "the"
module then patches a copy the code under test does not read, so it passes alone
and fails after the replacer — the order dependence behind the T-4616 flakes
(test_t4044 x4 after test_secret_key, test_t4043 after test_fabric_loader,
test_t4458 x2 after test_t4223_gaps_perf).

`importlib.reload` keeps identity and is handled by the conftests' value restores;
this handles the identity loss, for every test, without editing the replacers.
"""

from __future__ import annotations

import sys


def _owned(name: str, prefixes: tuple[str, ...]) -> bool:
    return any(name == p or name.startswith(p + ".") for p in prefixes)


def _set_parent_attr(name: str, mod) -> None:
    parent_name, _, child = name.rpartition(".")
    parent = sys.modules.get(parent_name) if parent_name else None
    if parent is None:
        return
    if mod is None:
        if getattr(parent, child, None) is not None:
            try:
                delattr(parent, child)
            except AttributeError:
                pass
    else:
        setattr(parent, child, mod)


def snapshot(prefixes: tuple[str, ...]) -> dict:
    return {n: m for n, m in list(sys.modules.items()) if m is not None and _owned(n, prefixes)}


def restore(before: dict, prefixes: tuple[str, ...]) -> None:
    """Put back every module object in `before` that the test removed or replaced.

    When any was, modules first imported during the test belong to the discarded
    generation (they bound the replacement objects), so they are dropped too and
    re-import against the restored originals on next use. A test that only adds
    modules leaves sys.modules untouched.
    """
    now = snapshot(prefixes)
    replaced = [n for n, m in before.items() if sys.modules.get(n) is not m]
    if not replaced:
        return
    for name in sorted(n for n in now if n not in before):
        sys.modules.pop(name, None)
        _set_parent_attr(name, None)
    # Parents before children, so a restored child lands on its original parent.
    for name in sorted(before, key=lambda n: n.count(".")):
        sys.modules[name] = before[name]
    for name in sorted(before, key=lambda n: n.count(".")):
        _set_parent_attr(name, before[name])
