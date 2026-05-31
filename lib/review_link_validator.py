#!/usr/bin/env python3
"""Validate Watchtower review/inception handoff links at the moment of handoff.

T-2050 (initial advisory shape, T-2030 GO 2026-05-25) — extract internal URLs an
agent wrote in `## Recommendation` and `### Human` Steps, WARN on any path that
doesn't resolve against `app.url_map`.

T-2139 (V1 keystone, T-2138 GO 2026-05-31) — extend to detect the *absence-of-URL*
homework anti-pattern ('URL from bin/fw watchtower url', bare-path bullets in
Steps without an http:// prefix), add --enforce mode that returns non-zero on
findings, and emit class-aware block messages that name the review-vs-inception
distinction. Default mode remains advisory (T-2050 contract preserved).

Two failure classes detected:
  - wrong-URL (T-2050)     — URL present but path doesn't resolve to a route
  - absence-of-URL (T-2139) — Steps tell the human to construct a URL themselves

The latter regex-matches Steps content; finding any of:
    - "URL from `bin/fw watchtower url`"
    - "base from `bin/fw watchtower url`"
    - "(Watchtower URL from"
    - Bare-path bulleted lines inside `### Human` Steps without a preceding scheme
…flags `block` level in enforce mode.

Resolution strategy (T-2030):
  - parameterless paths → matched against `discover_get_routes()` (T-2042 reuse)
  - parameterised paths (e.g. /review/T-XXX) → HTTP-probed; 404 → WARN
  - server/Flask unavailable → non-blocking advisory

OUT of scope: external URLs, screenshot existence, prose quality, chat-message
slips (different surface; tracked separately).

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

# T-2139: homework anti-pattern detectors. Each tuple is (regex, label) — the
# label feeds the block message ("found <label> in your Human AC Steps").
_HOMEWORK_PATTERNS = [
    (re.compile(r'URL\s+from\s+`?bin/fw\s+watchtower\s+url`?', re.IGNORECASE),
     "`URL from bin/fw watchtower url`"),
    (re.compile(r'base\s+from\s+`?bin/fw\s+watchtower\s+url`?', re.IGNORECASE),
     "`base from bin/fw watchtower url`"),
    (re.compile(r'\(Watchtower\s+URL\s+from', re.IGNORECASE),
     "`(Watchtower URL from …)`"),
    (re.compile(r'\(?\s*base\s+from\s+`?fw\s+watchtower\s+url`?', re.IGNORECASE),
     "`base from fw watchtower url`"),
]

# Bare-path-bullet detector: a bulleted line whose content is just a /path
# (optionally backticked), with no http:// or https:// scheme earlier on the
# same line. Matches " - `/foo`", " - /foo", " * /foo", "- `/foo/bar`" etc.
# Anchored to start-of-line in MULTILINE mode.
_BARE_PATH_BULLET_RE = re.compile(
    r'^\s{0,8}[-*]\s+`?/[A-Za-z0-9_\-./?=&]+`?\s*$',
    re.MULTILINE,
)

# Frontmatter workflow_type extraction — simple line match, no YAML parser needed.
_WORKFLOW_TYPE_RE = re.compile(r'^workflow_type:\s*([A-Za-z0-9_-]+)\s*$', re.MULTILINE)


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

    Fenced ```code blocks``` are stripped before scanning — URLs inside a fence
    are documentation/examples (e.g. synthetic /inception/T-9999 in an inlined
    block-message rendering), not live links the human should be clicking.
    """
    base = urlparse(base_url)
    rec = _strip_fenced_code(extract_section(body, "Recommendation"))
    steps = _strip_fenced_code(extract_human_steps(body))
    text = rec + "\n" + steps
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


def detect_workflow_type(body: str) -> str:
    """Return the task's `workflow_type:` frontmatter value, or 'build' if absent."""
    m = _WORKFLOW_TYPE_RE.search(body)
    return m.group(1) if m else "build"


def _strip_fenced_code(text: str) -> str:
    """Remove ```...``` fenced code blocks from text.

    T-2139 self-trap fix: when an AC quotes the homework pattern verbatim
    inside a fenced code block (to document the anti-pattern, e.g. an
    inlined example block-message), that's documentation, not instruction.
    The detector should not fire on it. Plain `inline` backticks are
    intentionally NOT stripped — single-token quoting still counts as
    instructional content surrounding it.
    """
    return re.sub(r"```.*?```", "", text, flags=re.DOTALL)


def detect_homework_patterns(body: str):
    """Return a list of (level, message) for absence-of-URL homework anti-patterns
    found in the `### Human` Steps subsection.

    Each finding is level='block' — these patterns are always bugs at handoff
    time. `main()` emits them at advisory severity by default; `--enforce` mode
    propagates them to a non-zero exit code.

    Fenced ```code blocks``` are stripped before scanning: they exist to
    document examples (block-message renderings, anti-pattern catalogues),
    not to instruct the reviewer.
    """
    steps_raw = extract_human_steps(body)
    findings: list[tuple[str, str]] = []
    if not steps_raw:
        return findings
    steps = _strip_fenced_code(steps_raw)
    for regex, label in _HOMEWORK_PATTERNS:
        if regex.search(steps):
            findings.append(("block", f"homework pattern in Steps: {label}"))
    # Bare-path bullets that aren't preceded on the same line by http(s)://
    for m in _BARE_PATH_BULLET_RE.finditer(steps):
        line = m.group(0)
        if "http://" in line or "https://" in line:
            continue  # has a scheme on this line — fine
        findings.append((
            "block",
            f"bare-path bullet in Steps (no http:// prefix): {line.strip()}",
        ))
    return findings


def class_aware_handoff_hint(workflow_type: str, task_id: str) -> str:
    """Return the class-correct URL pattern + hint string for the block message."""
    if workflow_type == "inception":
        return (
            f"This task is an inception. Inception handoffs go to "
            f"/inception/{task_id}, NOT /review/{task_id}."
        )
    return (
        f"This is a {workflow_type} task with unticked Human ACs (partial-complete). "
        f"Review handoffs go to /review/{task_id}."
    )


def _task_id_from_path(path: str) -> str:
    """Extract T-NNNN from a task filename like '.tasks/active/T-2139-foo.md'."""
    m = re.search(r'(T-\d+)', os.path.basename(path))
    return m.group(1) if m else "T-XXXX"


def main(argv=None) -> int:
    argv = argv if argv is not None else sys.argv[1:]
    if len(argv) < 2:
        return 0
    enforce = "--enforce" in argv
    pos = [a for a in argv if not a.startswith("--")]
    if len(pos) < 2:
        return 0
    task_file, base_url = pos[0], pos[1]

    # T-2139: bypass mechanism — env var skips the entire check + logs Tier-2.
    if enforce and os.environ.get("FW_ALLOW_REVIEW_LINK_HOMEWORK") == "1":
        print(
            "  · Review-link check (T-2139): BYPASSED via FW_ALLOW_REVIEW_LINK_HOMEWORK=1",
            file=sys.stderr,
        )
        _log_tier2_bypass(task_file, "FW_ALLOW_REVIEW_LINK_HOMEWORK=1")
        return 0

    try:
        path_results = validate(task_file, base_url)
        with open(task_file, encoding="utf-8") as fh:
            body = fh.read()
        homework_results = detect_homework_patterns(body)
        workflow_type = detect_workflow_type(body)
        task_id = _task_id_from_path(task_file)
    except Exception:
        return 0  # advisory tool — never break `fw task review` on validator bugs

    warns = [msg for level, msg in path_results if level == "warn"]
    advisories = [msg for level, msg in path_results if level == "advisory"]
    blocks = [msg for level, msg in homework_results if level == "block"]

    if warns:
        print(
            "  ⚠ Review-link check (T-2050) — unresolvable path(s) in this task:",
            file=sys.stderr,
        )
        for msg in warns:
            print(f"      {msg}", file=sys.stderr)
        print(
            "      Fix the path(s) above before the human opens the link.",
            file=sys.stderr,
        )

    if blocks:
        severity_label = "BLOCK" if enforce else "⚠ advisory"
        print(
            f"  ✗ Review-link check (T-2139) — {severity_label} — review-handoff homework in this task:",
            file=sys.stderr,
        )
        for msg in blocks:
            print(f"      {msg}", file=sys.stderr)
        # Class-aware teaching line
        print(
            f"      {class_aware_handoff_hint(workflow_type, task_id)}",
            file=sys.stderr,
        )
        example_route = "inception" if workflow_type == "inception" else "review"
        print(
            f"      Replace homework with concrete absolute URLs (e.g. {base_url.rstrip('/')}/{example_route}/{task_id}).",
            file=sys.stderr,
        )
        if enforce:
            print(
                "      Bypass: FW_ALLOW_REVIEW_LINK_HOMEWORK=1 <command>  (logged Tier-2)",
                file=sys.stderr,
            )
            print(
                "      Or:     bin/fw task review T-XXX --skip-review-link-check \"rationale\"",
                file=sys.stderr,
            )

    for msg in advisories:
        print(f"  · Review-link check (T-2050): {msg}", file=sys.stderr)

    if enforce and blocks:
        return 2  # block exit code (parallel to other PreToolUse hooks)
    return 0


def _log_tier2_bypass(task_file: str, mechanism: str) -> None:
    """Append a Tier-2 bypass entry to .context/working/.gate-bypass-log.yaml.

    Honors PROJECT_ROOT (consumer projects) before falling back to the framework's
    own root — same resolution order other gate-bypass logs use.
    """
    import datetime

    root = os.environ.get("PROJECT_ROOT") or os.path.dirname(
        os.path.dirname(os.path.abspath(__file__))
    )
    log_path = os.path.join(root, ".context", "working", ".gate-bypass-log.yaml")
    try:
        ts = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        task_id = _task_id_from_path(task_file)
        entry = (
            f"- ts: '{ts}'\n"
            f"  gate: review-link-homework\n"
            f"  task: {task_id}\n"
            f"  mechanism: {mechanism}\n"
            f"  rationale: {os.environ.get('FW_BYPASS_RATIONALE', 'unspecified')}\n"
        )
        os.makedirs(os.path.dirname(log_path), exist_ok=True)
        with open(log_path, "a", encoding="utf-8") as fh:
            fh.write(entry)
    except Exception:
        pass  # best-effort logging


if __name__ == "__main__":
    sys.exit(main())
