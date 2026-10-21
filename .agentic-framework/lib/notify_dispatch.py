#!/usr/bin/env python3
"""Run the skills-manager alert dispatcher the way it can actually run (T-3866).

The dispatcher (`<root>/skills/alerts/alert_dispatcher.py`) is a module inside a
package: it opens with `from .alert_config import ...`, so `python3 <file>`
dies with "attempted relative import with no known parent package". On some
hosts it also has no `__main__` block, so `python3 -m` imports it and exits 0
without sending anything. The one interface every version has is the library
function `dispatch_alert(trigger, title, message, context)`, so that is what
this helper calls, with the package root on sys.path.

    notify_dispatch.py check DISPATCHER
        Dry import. Exit 0 when the module imports and has dispatch_alert;
        exit 1 with the reason on stderr otherwise. Sends nothing.
    notify_dispatch.py send DISPATCHER --trigger T --title X --message M
        Dispatch. Exit 0 when dispatched (or deduplicated by the dispatcher);
        exit 1 with the reason on stderr otherwise.

NTFY_URL in the environment is passed through untouched; the dispatcher reads it.
"""
import argparse
import importlib
import sys
import traceback
from pathlib import Path


def module_for(path):
    """(package_root, dotted module name) for a .py file inside a package.

    Walks up while the parent directory is a package (has __init__.py); the
    first directory that is not is the root that goes on sys.path."""
    p = Path(path).resolve()
    if p.suffix != ".py" or not p.is_file():
        raise ImportError(f"no dispatcher file at {path}")
    parts = [p.stem]
    d = p.parent
    while (d / "__init__.py").is_file():
        parts.insert(0, d.name)
        d = d.parent
    return str(d), ".".join(parts)


def load(path):
    root, name = module_for(path)
    if root not in sys.path:
        sys.path.insert(0, root)
    mod = importlib.import_module(name)
    fn = getattr(mod, "dispatch_alert", None)
    if not callable(fn):
        raise ImportError(f"{name} has no dispatch_alert()")
    return name, fn


def main(argv=None):
    ap = argparse.ArgumentParser(prog="notify_dispatch.py")
    sub = ap.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("check")
    c.add_argument("dispatcher")
    s = sub.add_parser("send")
    s.add_argument("dispatcher")
    s.add_argument("--trigger", default="manual")
    s.add_argument("--title", required=True)
    s.add_argument("--message", default="")
    a = ap.parse_args(argv)

    try:
        name, dispatch_alert = load(a.dispatcher)
    except Exception as e:  # ImportError, SyntaxError, anything the import raises
        print(f"notify: dispatcher not importable ({a.dispatcher}): "
              f"{type(e).__name__}: {e}", file=sys.stderr)
        return 1
    if a.cmd == "check":
        print(f"importable as {name}")
        return 0

    message = a.message or a.title
    # The dispatcher deduplicates on (trigger, context) for 24 h; with an empty
    # context every `manual` push after the first would be dropped as a duplicate.
    context = {"title": a.title, "message": message}
    try:
        alert = dispatch_alert(a.trigger, a.title, message, context)
    except Exception:
        print("notify: dispatch_alert raised:", file=sys.stderr)
        traceback.print_exc()
        return 1
    if alert is None:
        print("notify: deduplicated by the dispatcher (same alert within its window)",
              file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
