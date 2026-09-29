"""Importable access to `lib/bvp.sh`'s python body. T-3552.

WHY THIS EXISTS
---------------
`lib/bvp.sh` is a polyglot: a shell wrapper whose real content is a python
program in a `<<'PYEOF'` heredoc, executed as `python3 - "$@"`. That is fine for
a CLI and useless for anything that needs to *ask it a question* — the value and
cost model, the median split, and the quadrant assignment all live in there with
no import surface.

So every consumer that needed a quadrant had two options: shell out and parse a
table, or re-derive the classification. Both are wrong in the same way. This repo
has already paid for the second one — arc membership reached five readers and
three disagreeing verdicts (OBS-546, T-3516) — and the fix each time is the same:
one implementation, imported.

Three unit tests already extract this body by hand (`test_bvp_cli_arcs_rollup.py`,
`test_bvp_cli_rank_proposed.py` and their siblings), each with its own copy of the
marker strings and its own scratch file. This module is that idiom, written once,
where production code can use it too.

WHAT IT IS NOT
--------------
Not a refactor of `bvp.sh`. Extracting the python into a real module would be the
better end state and is a much larger change — it is the CLI's entire
implementation, and `fw bvp` is a surface the operator uses daily. This gives
importers what they need without moving the thing they depend on.

The heredoc markers are asserted, not assumed: if `bvp.sh` is ever restructured,
this raises with a message naming the cause rather than silently exporting an
empty module. A loader that degrades to "no functions found" would hand every
caller a quadrant of None, which is precisely the unmeasured-absence class this
codebase keeps removing.
"""

from __future__ import annotations

import importlib.util
import os
import sys
import threading
from pathlib import Path

_START = "python3 - \"$@\" <<'PYEOF'"
_END = "\nPYEOF"

_lock = threading.Lock()
_cached: tuple[int, object] | None = None  # (mtime_ns, module)


def _extract(src: str) -> str:
    try:
        i = src.index(_START) + len(_START)
        j = src.index(_END, i)
    except ValueError as e:  # pragma: no cover - structural, not data-dependent
        raise RuntimeError(
            "lib/bvp_py: could not find the python body in lib/bvp.sh "
            f"(markers {_START!r} … {_END!r}). bvp.sh was restructured; update "
            "this loader rather than letting callers see an empty module."
        ) from e
    body = src[i:j]
    # The CLI's entry point. Running it on import would execute `fw bvp` with
    # whatever argv the importing process happens to have.
    return body.replace("sys.exit(main(sys.argv))", "pass  # entry point stripped for import")


def load(framework_root: Path | str | None = None):
    """Return `lib/bvp.sh`'s python body as an imported module.

    Cached on bvp.sh's mtime, so an edit during a long-running Flask process is
    picked up without a restart — same invalidation contract as the blueprint
    body caches.
    """
    global _cached
    root = Path(framework_root) if framework_root else Path(__file__).resolve().parent.parent
    bvp = root / "lib" / "bvp.sh"
    mtime = bvp.stat().st_mtime_ns

    with _lock:
        if _cached is not None and _cached[0] == mtime:
            return _cached[1]

        # The body reads these at module scope and exits the process if absent.
        os.environ.setdefault("PROJECT_ROOT", str(root))
        os.environ.setdefault("FRAMEWORK_ROOT", str(root))

        body = _extract(bvp.read_text())

        name = "_bvp_body"
        spec = importlib.util.spec_from_loader(name, loader=None)
        if spec is None:  # pragma: no cover
            raise RuntimeError("lib/bvp_py: could not create a module spec")
        mod = importlib.util.module_from_spec(spec)
        mod.__file__ = str(bvp)
        sys.modules[name] = mod
        exec(compile(body, str(bvp), "exec"), mod.__dict__)  # noqa: S102

        # Assert the surface callers actually import. Without this the failure
        # mode is a missing attribute at the first real call, far from the cause.
        for fn in ("compute_bvp", "compute_cost", "quadrant", "value_axis_degenerate"):
            if not callable(getattr(mod, fn, None)):
                raise RuntimeError(
                    f"lib/bvp_py: lib/bvp.sh's python body has no callable {fn!r}. "
                    "The contract this loader exports has changed."
                )

        _cached = (mtime, mod)
        return mod
