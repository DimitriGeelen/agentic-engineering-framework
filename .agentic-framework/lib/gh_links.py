"""Link task ids in text we post to GitHub (T-4903).

Operator 2026-10-29, from user feedback: a bare "T-4870" in a release note or an issue
comment is confusing; a reader cannot click it or find it. Every T-NNNN we post becomes a
link to that task's file in the public repository, at an IMMUTABLE ref (a release tag or a
commit already on GitHub): a task file moves from .tasks/active/ to .tasks/completed/ when
it closes, so a link to a branch path would break.

    link_task_ids(text, root, ref, repo)   -> text with ids linked
    github_ref(root)                       -> a commit known to be on the GitHub remote, or ""

Ids are left alone inside fenced code blocks, inline code spans, existing markdown links and
bare URLs, and when no task file exists at `ref` (an unresolvable id stays plain text rather
than becoming a dead link).
"""

from __future__ import annotations

import re
import subprocess
import sys

_ID_RE = re.compile(r"(?<![\w/#-])(T-\d{1,6})(?![\w-])")
# Spans that must not be touched: fenced blocks, inline code, markdown links/images, URLs.
_PROTECTED_RE = re.compile(
    r"```.*?```"                         # fenced code
    r"|`[^`\n]*`"                        # inline code
    r"|!?\[[^\]\n]*\]\([^)\n]*\)"        # [text](url) and ![alt](url)
    r"|<https?://[^>\s]+>"               # <url>
    r"|https?://[^\s)\]>]+",             # bare url
    re.DOTALL,
)


def _git(root: str, *args: str) -> str:
    try:
        p = subprocess.run(["git", "-C", root, *args], capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.SubprocessError):
        return ""
    return p.stdout if p.returncode == 0 else ""


def task_paths(root: str, ref: str) -> dict:
    """{task id: path of its file at ref}, from .tasks/active and .tasks/completed."""
    out: dict = {}
    listing = _git(root, "ls-tree", "-r", "--name-only", ref, "--", ".tasks/active", ".tasks/completed")
    for path in listing.splitlines():
        m = re.match(r"\.tasks/(?:active|completed)/(T-\d+)-", path)
        if m and path.endswith(".md"):
            # completed/ wins over a stale active/ copy at the same ref
            if m.group(1) not in out or "/completed/" in path:
                out[m.group(1)] = path
    return out


def github_ref(root: str) -> str:
    """The commit of bleeding-edge on the GitHub remote as last fetched or pushed (a commit
    GitHub has), else ""."""
    remotes = _git(root, "remote", "-v")
    for line in remotes.splitlines():
        parts = line.split()
        if len(parts) >= 2 and "github.com" in parts[1]:
            sha = _git(root, "rev-parse", "--verify", "-q", f"refs/remotes/{parts[0]}/bleeding-edge").strip()
            if sha:
                return sha
    return ""


def link_task_ids(text: str, root: str, ref: str, repo: str, paths: dict | None = None) -> str:
    """Return `text` with every bare task id linked to its file at `ref` on GitHub."""
    if not text or not ref or not repo:
        return text
    paths = task_paths(root, ref) if paths is None else paths
    if not paths:
        return text

    def link(m: re.Match) -> str:
        tid = m.group(1)
        path = paths.get(tid)
        if not path:
            return tid
        return f"[{tid}](https://github.com/{repo}/blob/{ref}/{path})"

    out, pos = [], 0
    for prot in _PROTECTED_RE.finditer(text):
        out.append(_ID_RE.sub(link, text[pos:prot.start()]))
        out.append(prot.group(0))
        pos = prot.end()
    out.append(_ID_RE.sub(link, text[pos:]))
    return "".join(out)


def main(argv: list) -> int:
    """CLI for shell callers: gh_links.py <root> <ref> <repo> < text > linked text."""
    if len(argv) != 4:
        print("usage: gh_links.py <root> <ref> <repo>  (text on stdin)", file=sys.stderr)
        return 2
    sys.stdout.write(link_task_ids(sys.stdin.read(), argv[1], argv[2], argv[3]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
