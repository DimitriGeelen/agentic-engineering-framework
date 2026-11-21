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


def names_page(text: str) -> bool:
    """True when `text` names an app route (`/classic`, `/cicd/builds`) or a URL with a path.
    Filesystem roots and /api/ endpoints are not pages; neither is a token with a file suffix."""
    if re.search(r"https?://[\w.<>-]+(?::\d+)?/[a-z]", text, re.IGNORECASE):
        return True
    return any(m.group(1).lower() not in _NOT_A_PAGE for m in _PAGE_ROUTE_RE.finditer(text))


def needs_screenshots(c: dict) -> bool:
    """T-5352/T-5353: the ONE test for "this criterion is judged on screenshots of pages": a
    render criterion (`render`), or any criterion that names a page whatever its class (`page`).
    `c` is a criterion dict carrying those two flags (the judge's planned criterion)."""
    return bool(c.get("render") or c.get("page"))


def needs_view(render: bool, title: str, body: str) -> bool:
    """`needs_screenshots` for a criterion given its render flag and its text — the form the
    ledger has to hand. The page flag is derived exactly as the judge derives it
    (`judge_cli._partition`: render, or `names_page` over title and body)."""
    return needs_screenshots({"render": render,
                              "page": bool(render) or names_page(f"{title}\n{body}")})
