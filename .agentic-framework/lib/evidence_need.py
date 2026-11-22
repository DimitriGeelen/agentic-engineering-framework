"""T-5353: the ONE decision point for "this criterion's evidence needs a proven view of
screenshots of pages".

Three consumers ask it and must agree:
  * the judge (`lib/reviewer/judge_cli.py`): which criteria get pages captured, the Visual
    Verification shots gathered and the brief's image section (T-5352);
  * the ledger (`lib/verdict_ledger.py` `_run_fault`): which greens need a review run that
    recorded the required pages, each captured and cited;
  * the vote checker (`lib/vote_checker.py` `checkable`, via the ledger): which votes in a
    non-panel run are not checkable when every cited image is proven only "attached at launch"
    (T-5327 ATTACHED_ONLY).

Before T-5353 the judge asked "render, or names a page" while the ledger and the vote checker
asked "render" only, so a page-naming non-render criterion (a designer re-pin naming /designer)
got screenshots but closed on attached-only proof. This module holds the test; the judge and
the ledger import it and never copy it. It imports nothing from either (no cycle: judge_cli
imports verdict_ledger).
"""
from __future__ import annotations

import re

# T-4978 (ring20): a criterion that describes what an app page shows ("[REVIEW] /classic SSL
# Certificates widget shows 4 tiles ...") classifies taste or unclassified when its task does not
# touch AEF's own web/ layout, so `render` stays False. `page` asks: does the criterion name a
# route of the app?
_PAGE_ROUTE_RE = re.compile(r"(?<![\w/.:~-])/([a-z][\w-]*)(?:/[\w-]+)*(?![\w/.-])", re.IGNORECASE)
_NOT_A_PAGE = {"tmp", "opt", "etc", "usr", "var", "root", "home", "dev", "proc", "bin", "srv", "mnt",
               "api"}


# T-5367: a URL names a page only on THIS project's Watchtower. A GitHub PR link or a docs URL
# cited as a reference is not a page to capture: counting it made the judge try to screenshot
# GitHub and the ledger refuse every green ("no required page was recorded"). `<watchtower>` is
# the placeholder criteria use for the project's own host.
LOCAL_HOSTS = {"localhost", "127.0.0.1", "<watchtower>"}
_URL_RE = re.compile(r"https?://((?:<watchtower>|[\w.-]+))(?::(\d+))?(/[^\s?#`<>()\[\]'\"]*)?",
                     re.IGNORECASE)


def own_origin(root) -> tuple[str, str | None]:
    """(netloc, port) of this project's Watchtower: `.context/working/watchtower.url`, the port
    falling back to the PORT config (default 3000). `root=None` gives ("", None): only the local
    hosts count, on any port. Callers resolve it once and pass it to `names_page`/`is_own_url`."""
    if root is None:
        return "", None
    from pathlib import Path
    from urllib.parse import urlsplit
    f = Path(root) / ".context/working/watchtower.url"
    try:
        own = urlsplit(f.read_text().strip()) if f.exists() else urlsplit("")
        port = str(own.port) if own.port else None
    except (OSError, ValueError):
        own, port = urlsplit(""), None
    if port is None:
        from lib import review_policy
        port = review_policy.config_value(Path(root), "PORT", "3000")
    return own.netloc.lower(), port


def is_own_url(host: str, port: str, origin: tuple[str, str | None]) -> bool:
    """True when host[:port] is the project's Watchtower (`origin` from `own_origin`), or a local
    host on its port (any port when the origin is unknown)."""
    own_netloc, own_port = origin
    host, port = host.lower(), port or ""
    netloc = f"{host}:{port}" if port else host
    if own_netloc and netloc == own_netloc:
        return True
    return host in LOCAL_HOSTS and (own_port is None or port == own_port)


def names_page(text: str, origin: tuple[str, str | None] | None = None) -> bool:
    """True when `text` names an app route (`/classic`, `/cicd/builds`) or a URL with a path on
    this project's Watchtower (`origin`, from `own_origin(root)`; None = local hosts only).
    Outside URLs, filesystem roots and /api/ endpoints are not pages; neither is a token with a
    file suffix."""
    origin = origin or ("", None)
    for m in _URL_RE.finditer(text):
        if re.match(r"/[a-z]", m.group(3) or "", re.IGNORECASE) and \
                is_own_url(m.group(1), m.group(2) or "", origin):
            return True
    # URLs are not bare routes: blank them so an outside URL's path is never read as one.
    bare = _URL_RE.sub(" ", text)
    return any(m.group(1).lower() not in _NOT_A_PAGE for m in _PAGE_ROUTE_RE.finditer(bare))


def needs_screenshots(c: dict) -> bool:
    """T-5352/T-5353: the ONE test for "this criterion is judged on screenshots of pages": a
    render criterion (`render`), or any criterion that names a page whatever its class (`page`).
    `c` is a criterion dict carrying those two flags (the judge's planned criterion)."""
    return bool(c.get("render") or c.get("page"))


def needs_view(render: bool, title: str, body: str,
               origin: tuple[str, str | None] | None = None) -> bool:
    """`needs_screenshots` for a criterion given its render flag and its text — the form the
    ledger has to hand. The page flag is derived exactly as the judge derives it
    (`judge_cli._partition`: render, or `names_page` over title and body, against the project's
    Watchtower `origin`)."""
    return needs_screenshots({"render": render,
                              "page": bool(render) or names_page(f"{title}\n{body}", origin)})
