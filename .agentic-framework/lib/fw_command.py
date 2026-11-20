#!/usr/bin/env python3
"""The one builder for every fw command the framework PRINTS (T-5303, T-5302 GO).

Rule (operator GO 2026-11-20, docs/reports/T-5302-command-naming-vendored.md):

    cd <absolute project root> && <fw path> <args>

where <fw path> is ``bin/fw`` in the framework repo (FRAMEWORK.md and bin/fw at
the root) and ``.agentic-framework/bin/fw`` in a vendored project. Never bare
``fw`` (the PATH ``fw`` is not the T-2793 router on every host, nor on every
PATH a worker or hook runs with); never ``bin/watchtower.sh`` (Watchtower is
``<fw path> watchtower ...``).

This is the Python twin of ``_fw_cmd`` / ``_emit_user_command`` in
lib/paths.sh, and Watchtower's ``fw_cmd`` template global calls it. The three
must print identical text: tests/unit/test_t5303_fw_command_builder.py pins it.

Quoting (decided in T-5303): ``args`` is ONE pre-formed string, written the way
the reader should type it (callers already embed their own quotes, e.g.
``inception decide T-1 go --rationale 'why'``). Both builders concatenate it
unchanged; neither re-quotes it. Shell ``printf %q`` and ``shlex.quote`` do not
produce the same text for the same word, so quoting argv in the builder would
break parity. Only the project ROOT is quoted, with ``shlex.quote`` rules, which
lib/paths.sh reproduces exactly (``_fw_quote_word``); for an ordinary path that
is the path itself. ``user_command`` also accepts a list, joined with
``shlex.join``: a Python-only convenience with no shell twin.

Running fw (not printing) is a different question and is unchanged: Watchtower
runs FRAMEWORK_ROOT/bin/fw by absolute path (T-3952).
"""
from __future__ import annotations

import os
import shlex
from pathlib import Path
from typing import Sequence, Union

FRAMEWORK_FW = "bin/fw"
VENDORED_FW = ".agentic-framework/bin/fw"


def _root(project_root: Union[str, os.PathLike, None]) -> str:
    if project_root is None:
        project_root = os.environ.get("PROJECT_ROOT") or os.getcwd()
    # abspath, not resolve: the shell twin prints $PROJECT_ROOT as it is.
    return os.path.abspath(os.fspath(project_root))


def is_framework_repo(project_root: Union[str, os.PathLike, None] = None) -> bool:
    root = Path(_root(project_root))
    return (root / "FRAMEWORK.md").is_file() and (root / "bin" / "fw").is_file()


def fw_path(project_root: Union[str, os.PathLike, None] = None) -> str:
    """Project-relative fw path to print: ``bin/fw`` or ``.agentic-framework/bin/fw``."""
    return FRAMEWORK_FW if is_framework_repo(project_root) else VENDORED_FW


def user_command(args: Union[str, Sequence[str]] = "",
                 project_root: Union[str, os.PathLike, None] = None) -> str:
    """``cd <absolute root> && <fw path> <args>`` — copy-pasteable from any directory."""
    if not isinstance(args, str):
        args = shlex.join(list(args))
    root = _root(project_root)
    cmd = f"cd {shlex.quote(root)} && {fw_path(root)}"
    return f"{cmd} {args}" if args else cmd


if __name__ == "__main__":  # `python3 lib/fw_command.py [ROOT] ARGS` — debugging aid
    import sys
    if len(sys.argv) >= 3:
        print(user_command(sys.argv[2], sys.argv[1]))
    else:
        print(user_command(sys.argv[1] if len(sys.argv) > 1 else ""))
