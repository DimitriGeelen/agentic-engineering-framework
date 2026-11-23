"""Run a framework module the way ``python3 -m lib.X`` would, from any CWD (T-5373).

``python3 -m`` puts the caller's CWD at sys.path[0], ahead of PYTHONPATH. In a
consumer that ships its own regular ``lib`` package, that ``lib`` then wins and
``lib.X`` is not found. This launcher puts the framework root first instead:

    python3 "$FRAMEWORK_ROOT/lib/run_module.py" lib.X [args...]

Only ``sys`` and ``os`` (both loaded before this file runs) are touched before
sys.path[0] is replaced, so a ``lib/*.py`` named like a stdlib module cannot
shadow anything here.
"""
import os
import sys

_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path[0] = _ROOT  # was this file's directory (lib/)

import runpy  # noqa: E402

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: run_module.py <module> [args...]", file=sys.stderr)
        sys.exit(2)
    _mod = sys.argv[1]
    sys.argv = sys.argv[1:]
    runpy.run_module(_mod, run_name="__main__", alter_sys=True)
