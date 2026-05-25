#!/usr/bin/env python3
"""T-2050 — validate Watchtower review links against app.url_map at `fw task review`.

T-2030 GO follow-on (candidate C). Agents have pasted review links to routes that
don't exist (`/appearance` 404 vs the real `/settings/appearance`), so the human
clicks a dead link at review time. This module extracts the internal Watchtower
URLs an agent wrote in a task's `## Recommendation` section and `### Human` AC
Steps, and WARNs on any path that doesn't resolve against the app's route table.

It is ADVISORY: `main()` always returns 0 so it can never block `fw task review`.

Resolution strategy (per the T-2030 decision):
  - parameterless paths → matched against `discover_get_routes()` (T-2042 reuse)
  - parameterised paths (e.g. /review/T-XXX) → HTTP-probed; 404 → WARN
  - server/Flask unavailable → non-blocking advisory ("verify manually" — the
    curl-before-paste backstop)

OUT of scope (deliberately not checked): external (non-base_url) URLs, screenshot
existence, prose quality.

Pinned by tests/unit/test_review_link_validator.py.
"""
from __future__ import annotations

import os
import re
import sys
from urllib.parse import urlparse

# A URL ends at whitespace or a markdown/code delimiter. This deliberately stops
# before ), ], ", ', <, > and backtick so `[label](url)`, "url" and `url` all
# yield the bare URL (the rendering contract, T-1575, accepts all three forms).
_URL_RE = re.compile(r'https?://[^\s)\]"\'<>`]+')


def extract_section(body: str, heading: str) -> str:
    """Return the body of a `## <heading>` section, up to the next `## ` or EOF."""
    m = re.search(
        rf"^##\s+{re.escape(heading)}\s*$(.*?)(?=^##\s|\Z)",
        body,
        re.MULTILINE | re.DOTALL,
    )
    return m.group(1) if m else ""


def extract_human_steps(body: str) -> str:
    """Return the `### Human` subsection of `## Acceptance Criteria` (Steps live here)."""
    ac = extract_section(body, "Acceptance Criteria")
    m = re.search(
        r"^###\s+Human\s*$(.*?)(?=^###\s|^##\s|\Z)",
        ac,
        re.MULTILINE | re.DOTALL,
    )
    return m.group(1) if m else ""


def extract_internal_paths(body: str, base_url: str) -> list[str]:
    """Sorted unique internal paths from Recommendation + Human Steps.

    Internal = same host:port as base_url. External URLs are ignored (out of scope).
    Query strings and fragments are dropped — only the path is validated.
    """
    base = urlparse(base_url)
    text = extract_section(body, "Recommendation") + "\n" + extract_human_steps(body)
    paths: set[str] = set()
    for raw in _URL_RE.findall(text):
        raw = raw.rstrip(".,;:")  # trailing prose punctuation
        p = urlparse(raw)
        if p.scheme not in ("http", "https"):
            continue
        if (p.hostname, p.port) != (base.hostname, base.port):
            continue  # external URL — out of scope
        if p.path and p.path != "/":
            paths.add(p.path)
    return sorted(paths)


def load_known_routes():
    """Reuse T-2042 `discover_get_routes()`. Returns a set, or None if unavailable.

    ux-review.py imports only stdlib at module level (playwright is lazy), and has
    an `if __name__ == "__main__"` guard, so importlib-loading it is side-effect
    free. discover_get_routes() does `from web.app import app` internally, so a
    missing Flask app degrades to None (probe-only mode), never an exception here.
    """
    import contextlib
    import importlib.util
    import io

    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    spec_path = os.path.join(root, "agents", "ux-review", "ux-review.py")
    try:
        spec = importlib.util.spec_from_file_location("_uxreview_t2050", spec_path)
        mod = importlib.util.module_from_spec(spec)
        # Importing ux-review.py pulls in web.app, which prints an FW_SECRET_KEY
        # advisory on import. Suppress import-time chatter so it doesn't leak into
        # the clean `fw task review` output this validator is meant to improve.
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            spec.loader.exec_module(mod)  # type: ignore[union-attr]
            routes = mod.discover_get_routes()
        return set(routes)
    except Exception:
        return None


def http_status(url: str, timeout: float = 3.0):
    """Return the HTTP status code for a GET, or None if the host is unreachable."""
    import urllib.error
    import urllib.request

    try:
        req = urllib.request.Request(url, method="GET")
        with urllib.request.urlopen(req, timeout=timeout) as resp:  # noqa: S310
            return resp.status
    except urllib.error.HTTPError as exc:
        return exc.code
    except Exception:
        return None


def classify_path(path, base_url, known_routes, probe_fn):
    """Return (level, message) where level is 'ok' | 'warn' | 'advisory'."""
    if known_routes is not None and path in known_routes:
        return ("ok", f"{path} → resolves (registered route)")
    # Parameterised (e.g. /review/<id>) or genuinely unknown — probe it.
    code = probe_fn(base_url.rstrip("/") + path)
    if code is None:
        return ("advisory", f"{path} → could not probe (server unreachable) — verify manually")
    if code == 404:
        return ("warn", f"{path} → 404 (no such route — check the path)")
    if code >= 400:
        return ("warn", f"{path} → HTTP {code}")
    return ("ok", f"{path} → HTTP {code}")


def validate(task_file, base_url, known_routes=None, probe_fn=None):
    """Return a list of (level, message) for every internal path in the task body."""
    if known_routes is None:
        known_routes = load_known_routes()
    if probe_fn is None:
        probe_fn = http_status
    with open(task_file, encoding="utf-8") as fh:
        body = fh.read()
    return [
        classify_path(path, base_url, known_routes, probe_fn)
        for path in extract_internal_paths(body, base_url)
    ]


def main(argv=None) -> int:
    argv = argv if argv is not None else sys.argv[1:]
    if len(argv) < 2:
        return 0
    task_file, base_url = argv[0], argv[1]
    try:
        results = validate(task_file, base_url)
    except Exception:
        return 0  # advisory tool — never break `fw task review`

    warns = [msg for level, msg in results if level == "warn"]
    advisories = [msg for level, msg in results if level == "advisory"]

    if warns:
        print("  ⚠ Review-link check (T-2050) — unresolvable path(s) in this task:", file=sys.stderr)
        for msg in warns:
            print(f"      {msg}", file=sys.stderr)
        print("      Fix the path(s) above before the human opens the link.", file=sys.stderr)
    for msg in advisories:
        print(f"  · Review-link check (T-2050): {msg}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
