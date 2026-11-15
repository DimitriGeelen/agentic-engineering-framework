"""Pick an arc by STATE from the corpus under test, never by name (T-5160).

Seven Playwright files used to name one arc as "the in-progress arc with many
tasks". That arc closed, and 21 tests went red without any page being wrong
(the T-3326 anti-pattern: a test anchored to mutable corpus state).

`pick_arc(...)` reads `.context/arcs/*.yaml` and `.tasks/` of the repo the
Watchtower under test serves, returns the first arc (sorted by file name) that
is in the asked-for state, and calls `pytest.skip` with the missing state named
when the corpus holds none. It reads the files itself and imports nothing from
`web/` or `lib/`, so a page that miscounts cannot agree with it by construction.
"""
import os
import re
from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path

import pytest
import yaml

_FRONTMATTER_CAP = 64 * 1024
_ARC_ID_RE = re.compile(r"^arc_id:\s*(.+?)\s*$", re.MULTILINE)
_ID_RE = re.compile(r"^id:\s*(T-\d+)\s*$", re.MULTILINE)
_TAGS_RE = re.compile(r"^tags:\s*(.+?)\s*$", re.MULTILINE)
_TAG_ARC_RE = re.compile(r"arc:([A-Za-z0-9\-_]+)")
_REC_SECTION_RE = re.compile(r"^## Recommendation\s*$(.*?)(?=^## |\Z)", re.MULTILINE | re.DOTALL)
_REC_VERDICT_RE = re.compile(
    r"^[ \t]*[-*]?[ \t]*\*\*Recommendation:\*\*[ \t]*\*{0,2}([A-Z][A-Z-]*)", re.MULTILINE
)
# Only these answer "is the arc done?"; GO / NO-GO / DEFER are about starting it.
CLOSE_VERDICTS = ("CLOSE", "KEEP-OPEN")


def project_root() -> Path:
    """Same resolution as conftest's `watchtower_server` fixture."""
    return Path(os.environ.get("PROJECT_ROOT") or Path(__file__).resolve().parents[2])


@dataclass
class Arc:
    slug: str
    numeric_id: str
    status: str
    anchor_task: str = ""
    close_task: str = ""
    headline_mechanic: str = ""
    # Task ids filed under the slug form (`arc_id: <slug>` or tag `arc:<slug>`):
    # what `/tasks?arc=<slug>` lists.
    slug_members: frozenset = field(default_factory=frozenset)
    # Slug form, `arc_id: arc-NNN` form and the arc file's own `constituent_tasks:`.
    members: frozenset = field(default_factory=frozenset)
    # Task carrying a CLOSE / KEEP-OPEN recommendation (close_task first, then
    # anchor_task), and that verdict. Both "" when there is none.
    close_rec_task: str = ""
    close_rec_verdict: str = ""


def _unquote(raw: str) -> str:
    v = (raw or "").strip()
    if v[:1] in ('"', "'"):
        end = v.find(v[0], 1)
        v = v[1:end] if end != -1 else v[1:]
    else:
        v = re.sub(r"(^|\s+)#.*$", "", v).strip()
    return "" if v in ("null", "~") else v


def _frontmatter(path: Path) -> str:
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            head = fh.read(_FRONTMATTER_CAP)
    except OSError:
        return ""
    if not head.startswith("---"):
        return ""
    end = head.find("\n---", 3)
    return head[:end] if end != -1 else head


def _membership(root: Path) -> dict:
    """{arc key (slug or arc-NNN, lower case): {task ids}} from task frontmatter."""
    out: dict = {}
    for sub in ("active", "completed"):
        for path in (root / ".tasks" / sub).glob("T-*.md"):
            fm = _frontmatter(path)
            m = _ID_RE.search(fm)
            if not m:
                continue
            tid = m.group(1)
            keys = set()
            a = _ARC_ID_RE.search(fm)
            if a and _unquote(a.group(1)):
                keys.add(_unquote(a.group(1)).lower())
            t = _TAGS_RE.search(fm)
            if t:
                keys.update(k.lower() for k in _TAG_ARC_RE.findall(t.group(1)))
            for k in keys:
                out.setdefault(k, set()).add(tid)
    return out


def _close_recommendation(root: Path, task_ids) -> tuple:
    for tid in task_ids:
        if not tid:
            continue
        for sub in ("active", "completed"):
            files = sorted((root / ".tasks" / sub).glob(f"{tid}-*.md"))
            if not files:
                continue
            try:
                body = files[0].read_text(encoding="utf-8", errors="replace")
            except OSError:
                break
            sec = _REC_SECTION_RE.search(body)
            v = _REC_VERDICT_RE.search(sec.group(1)) if sec else None
            if v and v.group(1) in CLOSE_VERDICTS:
                return tid, v.group(1)
            break
    return "", ""


@lru_cache(maxsize=None)
def _load(root_str: str) -> tuple:
    root = Path(root_str)
    by_key = _membership(root)
    arcs = []
    for path in sorted((root / ".context" / "arcs").glob("*.yaml")):
        try:
            data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        except (OSError, yaml.YAMLError):
            continue
        if not isinstance(data, dict):
            continue

        def _s(key):
            v = str(data.get(key) or "").strip()
            return "" if v in ("null", "~", "None") else v

        slug = _s("slug") or path.stem
        numeric = _s("id")
        slug_members = set(by_key.get(slug.lower(), ()))
        members = set(slug_members)
        if numeric:
            members |= by_key.get(numeric.lower(), set())
        legacy = data.get("constituent_tasks")
        if isinstance(legacy, list):
            members |= {str(t).strip() for t in legacy if str(t).strip()}
        rec_task, rec_verdict = _close_recommendation(root, (_s("close_task"), _s("anchor_task")))
        arcs.append(Arc(
            slug=slug, numeric_id=numeric, status=_s("status"),
            anchor_task=_s("anchor_task"), close_task=_s("close_task"),
            headline_mechanic=_s("headline_mechanic"),
            slug_members=frozenset(slug_members), members=frozenset(members),
            close_rec_task=rec_task, close_rec_verdict=rec_verdict,
        ))
    return tuple(arcs)


def all_arcs() -> tuple:
    return _load(str(project_root()))


def pick_arc(status="in-progress", *, min_members=0, min_slug_members=0,
             headline_mechanic=False, close_recommendation=False,
             numeric_id=False, most_members=False) -> Arc:
    """First arc in the corpus under test that is in the asked-for state.

    status               `status:` of the arc file ("in-progress", "closed", ...).
    min_members          at least this many member tasks, in any membership form.
    min_slug_members     at least this many filed under the slug form (the ones
                         `/tasks?arc=<slug>` lists).
    headline_mechanic    the arc has a non-empty `headline_mechanic:`.
    close_recommendation its close-out or anchor task holds a CLOSE / KEEP-OPEN
                         recommendation (what the close and review pages show).
    numeric_id           the arc has an `id: arc-NNN`.
    most_members         of the matches, the one with the most members instead
                         of the first by file name.

    Skips the calling test, naming the missing state, when no arc matches.
    """
    wanted = [f"status {status}"]
    if min_members:
        wanted.append(f"at least {min_members} member task(s)")
    if min_slug_members:
        wanted.append(f"at least {min_slug_members} task(s) filed under its slug")
    if headline_mechanic:
        wanted.append("a headline_mechanic")
    if close_recommendation:
        wanted.append("a CLOSE/KEEP-OPEN recommendation in its close-out or anchor task")
    if numeric_id:
        wanted.append("an arc-NNN id")

    matches = [
        a for a in all_arcs()
        if a.status == status
        and len(a.members) >= min_members
        and len(a.slug_members) >= min_slug_members
        and (not headline_mechanic or a.headline_mechanic)
        and (not close_recommendation or a.close_rec_task)
        and (not numeric_id or a.numeric_id)
    ]
    if not matches:
        pytest.skip(f"no arc in this corpus with {', '.join(wanted)}")
    if most_members:
        return max(matches, key=lambda a: len(a.members))
    return matches[0]
