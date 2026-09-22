#!/usr/bin/env python3
"""Derive a component card's `purpose` and `subsystem` from the source file itself.

T-3430. `fw fabric register` used to write two placeholders — `purpose: "TODO:
describe what this component does"` and `subsystem: unknown` — and nothing ever
filled them: 792 of 1314 cards on this repo carried the TODO, 564 the unknown.
This module is the deriver those two surfaces were missing.

The governing rule is REFUSE, NEVER GUESS. A purpose sentence is only ever
copied out of something the file (or its originating task) actually says, and
the provenance is recorded on the card as `purpose_source:` so every sentence is
traceable back to its origin. When a file describes itself nowhere, the card
keeps its TODO and the run prints the refusal — a plausible near-miss written
into `purpose` is indistinguishable from a real description once it is on the
card, and would poison every index that reads the fabric.

Derivation order for `purpose` (first hit wins):
  1. the file's own header — Python module docstring, `#` comment block under a
     shebang, Markdown first paragraph, `/* */` or `//` banner, `<!-- -->` or
     Jinja `{# #}` comment;
  2. the `created_by:` task — its frontmatter title, else its
     `docs/reports/T-XXXX-*.md` artefact heading;
  3. nothing — return None, and let the caller print the refusal.

`subsystem` derives from the path against the `paths:` patterns declared per
subsystem in `.fabric/subsystems.yaml` (longest matching pattern wins), so the
vocabulary and the routing rules are one operator-editable file. No match
returns None, which the caller renders as `unknown` and prints.
"""

import ast
import fnmatch
import glob
import os
import re
import sys

import yaml

# The exact string register.sh writes. Anything equal to it — or any purpose
# containing a bare TODO/FIXME marker — is a placeholder we may overwrite.
# Anything else is a human sentence and is never touched.
PLACEHOLDER_PURPOSE = "TODO: describe what this component does"
PLACEHOLDER_SUBSYSTEM = "unknown"

# Longest a derived purpose may be. Card purposes are read in list views and
# search snippets; a full module docstring pasted in is noise, not description.
MAX_PURPOSE = 240

# Lines that appear at the top of a file but say nothing about what it does.
_NOISE_RE = re.compile(
    r"^(shellcheck\b|pylint\b|flake8\b|noqa\b|type:\s*ignore|mypy:|vim:|emacs:"
    r"|-\*-|coding[:=]|SPDX-|Copyright\b|\(c\)\s|Licen[cs]ed?\b|All rights reserved"
    r"|!/|#!/)",
    re.IGNORECASE,
)

# A line made only of separator punctuation (── === --- ### ***) carries no text.
_SEPARATOR_RE = re.compile(r"^[\s\-=#*_~/\\|+.·—–─━╌<>]*$")

_SENTENCE_END_RE = re.compile(r"(?<=[.!?])\s")

_TASK_ID_RE = re.compile(r"\bT-\d+\b")


# ---------------------------------------------------------------------------
# Text hygiene
# ---------------------------------------------------------------------------

def _clean_lines(lines, limit=None):
    """Drop separator-only and tooling-directive lines; strip each survivor.

    `limit` caps how many surviving lines are kept — a 12-line banner joined
    verbatim produces a run-on that says less than its first two lines do.
    """
    out = []
    for raw in lines:
        line = raw.strip()
        if not line:
            if out:
                break  # a blank line ends the first paragraph
            continue   # …but leading blanks are just layout ("""\nText…)
        if _SEPARATOR_RE.match(line):
            continue
        if _NOISE_RE.match(line):
            continue
        # A line with no whitespace at all is a filename or a marker, not a
        # description — `# lib/render_surface.sh` above the real sentence is
        # the common shape here.
        if " " not in line:
            continue
        out.append(line)
        if limit is not None and len(out) >= limit:
            break
    return out


def _finalize(text):
    """Collapse to one line, trim to MAX_PURPOSE, reject if it says nothing.

    Returns the cleaned string, or None when the candidate is too thin to be a
    description (a bare filename, a single word, a leftover TODO marker).
    """
    if not text:
        return None
    text = re.sub(r"\s+", " ", text).strip().strip("-–—:;,")
    if not text:
        return None
    # A leftover marker is not a description — refusing beats propagating it.
    if re.match(r"^(TODO|FIXME|XXX|WIP)\b", text, re.IGNORECASE):
        return None
    if len(text) < 12 or " " not in text:
        return None
    if len(text) > MAX_PURPOSE:
        # Prefer a sentence boundary inside the budget; fall back to a word one.
        head = text[:MAX_PURPOSE]
        parts = _SENTENCE_END_RE.split(head)
        if len(parts) > 1:
            text = " ".join(parts[:-1]).strip()
        else:
            text = head.rsplit(" ", 1)[0].rstrip(" ,;:-") + "…"
    return text


# ---------------------------------------------------------------------------
# Per-language header extraction
# ---------------------------------------------------------------------------

def _from_python(src):
    """Module docstring via ast; header comment block if there is none."""
    try:
        doc = ast.get_docstring(ast.parse(src))
    except (SyntaxError, ValueError):
        doc = None
    if doc:
        text = _finalize(" ".join(_clean_lines(doc.splitlines())))
        if text:
            return text, "docstring"
    text = _from_hash_header(src)
    if text:
        return text, "header-comment"
    return None


def _from_hash_header(src):
    """First `#` comment block at the top of the file (after any shebang)."""
    body = []
    started = False
    for raw in src.splitlines():
        line = raw.strip()
        if not started:
            if line.startswith("#!"):
                continue
            if not line:
                continue  # allow blank lines before the block begins
            if not line.startswith("#"):
                return None  # code before any comment — no header block
            started = True
        elif not line.startswith("#"):
            break
        body.append(line.lstrip("#").strip())
    return _finalize(" ".join(_clean_lines(body, limit=4)))


def _from_markdown(src):
    """First real paragraph, else the H1 text. YAML frontmatter is skipped."""
    lines = src.splitlines()
    i = 0
    if lines and lines[0].strip() == "---":
        for j in range(1, len(lines)):
            if lines[j].strip() == "---":
                i = j + 1
                break
    heading = None
    para = []
    while i < len(lines):
        line = lines[i].strip()
        i += 1
        if not line:
            if para:
                break
            continue
        if line.startswith("<!--"):
            while i < len(lines) and "-->" not in lines[i]:
                i += 1
            i += 1
            continue
        if line.startswith("#"):
            if heading is None:
                heading = line.lstrip("#").strip()
            continue
        if _SEPARATOR_RE.match(line):
            continue
        para.append(line)
    text = _finalize(" ".join(para))
    if text:
        return text
    return _finalize(heading)


def _from_block_comment(src):
    """Leading `/* … */` banner, or a run of `//` lines, or `<!-- … -->`/`{# … #}`."""
    stripped = src.lstrip()
    for opener, closer in (("/*", "*/"), ("<!--", "-->"), ("{#", "#}")):
        if stripped.startswith(opener):
            end = stripped.find(closer, len(opener))
            if end == -1:
                continue
            inner = stripped[len(opener):end]
            body = [ln.strip().lstrip("*").strip() for ln in inner.splitlines()]
            text = _finalize(" ".join(_clean_lines(body, limit=4)))
            if text:
                return text
    body = []
    for raw in src.splitlines():
        line = raw.strip()
        if not line and not body:
            continue
        if not line.startswith("//"):
            break
        body.append(line.lstrip("/").strip())
    return _finalize(" ".join(_clean_lines(body, limit=4)))


_EXT_READERS = {
    ".py": _from_python,
    ".sh": lambda s: (lambda t: (t, "header-comment") if t else None)(_from_hash_header(s)),
    ".bash": lambda s: (lambda t: (t, "header-comment") if t else None)(_from_hash_header(s)),
    ".yaml": lambda s: (lambda t: (t, "header-comment") if t else None)(_from_hash_header(s)),
    ".yml": lambda s: (lambda t: (t, "header-comment") if t else None)(_from_hash_header(s)),
    ".toml": lambda s: (lambda t: (t, "header-comment") if t else None)(_from_hash_header(s)),
    ".cfg": lambda s: (lambda t: (t, "header-comment") if t else None)(_from_hash_header(s)),
    ".ini": lambda s: (lambda t: (t, "header-comment") if t else None)(_from_hash_header(s)),
    ".md": lambda s: (lambda t: (t, "markdown") if t else None)(_from_markdown(s)),
    ".js": lambda s: (lambda t: (t, "header-comment") if t else None)(_from_block_comment(s)),
    ".ts": lambda s: (lambda t: (t, "header-comment") if t else None)(_from_block_comment(s)),
    ".jsx": lambda s: (lambda t: (t, "header-comment") if t else None)(_from_block_comment(s)),
    ".tsx": lambda s: (lambda t: (t, "header-comment") if t else None)(_from_block_comment(s)),
    ".css": lambda s: (lambda t: (t, "header-comment") if t else None)(_from_block_comment(s)),
    ".scss": lambda s: (lambda t: (t, "header-comment") if t else None)(_from_block_comment(s)),
    ".html": lambda s: (lambda t: (t, "header-comment") if t else None)(_from_block_comment(s)),
}


def derive_purpose_from_header(abs_path):
    """Tier 1: what the file says about itself. Returns (text, source) or None."""
    ext = os.path.splitext(abs_path)[1].lower()
    reader = _EXT_READERS.get(ext)
    if reader is None:
        # Unknown extension: a `#` block is the most common convention, and a
        # file with no leading comment simply returns None (a refusal).
        reader = _EXT_READERS[".sh"]
    try:
        with open(abs_path, errors="replace") as f:
            # 1 MB, not 64 KB: a truncated read makes ast.parse raise
            # SyntaxError on any Python file larger than the cap, so every
            # long module silently lost its docstring and was reported as
            # "describes itself nowhere" (enrich.py, 60 KB, was one).
            src = f.read(1024 * 1024)
    except OSError:
        return None
    if not src.strip():
        return None
    return reader(src)


# ---------------------------------------------------------------------------
# Tier 2: the originating task
# ---------------------------------------------------------------------------

def _task_file(task_id, project_root):
    for sub in ("active", "completed"):
        hits = sorted(glob.glob(os.path.join(
            project_root, ".tasks", sub, f"{task_id}-*.md")))
        hits += sorted(glob.glob(os.path.join(
            project_root, ".tasks", sub, f"{task_id}.md")))
        if hits:
            return hits[0]
    return None


def derive_purpose_from_task(created_by, project_root):
    """Tier 2: the created_by task's title, else its report's H1."""
    if not created_by:
        return None
    m = _TASK_ID_RE.search(str(created_by))
    if not m:
        return None
    task_id = m.group(0)

    path = _task_file(task_id, project_root)
    if path:
        try:
            with open(path, errors="replace") as f:
                raw = f.read()
        except OSError:
            raw = ""
        if raw.startswith("---"):
            end = raw.find("\n---", 3)
            if end != -1:
                try:
                    fm = yaml.safe_load(raw[3:end]) or {}
                except yaml.YAMLError:
                    fm = {}
                text = _finalize(str(fm.get("name") or ""))
                if text:
                    return text, "task-title"

    reports = sorted(glob.glob(os.path.join(
        project_root, "docs", "reports", f"{task_id}-*.md")))
    if reports:
        try:
            with open(reports[0], errors="replace") as f:
                text = _from_markdown(f.read())
        except OSError:
            text = None
        if text:
            return text, "task-report"
    return None


def derive_purpose(path, created_by=None, project_root=None):
    """Derive a purpose sentence for `path`. Returns (text, source) or None.

    None is a REFUSAL, not an error: the file describes itself nowhere and the
    caller must leave the placeholder in place and say so out loud.
    """
    project_root = project_root or _project_root()
    abs_path = path if os.path.isabs(path) else os.path.join(project_root, path)

    hit = derive_purpose_from_header(abs_path)
    if hit:
        return hit
    return derive_purpose_from_task(created_by, project_root)


# ---------------------------------------------------------------------------
# Subsystem routing
# ---------------------------------------------------------------------------

def _project_root():
    root = os.environ.get("PROJECT_ROOT")
    if root:
        return root
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.normpath(os.path.join(here, "..", "..", ".."))


def load_subsystem_rules(project_root=None):
    """Read `paths:` patterns out of .fabric/subsystems.yaml.

    Returns [(pattern, subsystem_id)] sorted longest-pattern-first, so the most
    specific declaration wins regardless of the order the operator wrote them in.
    """
    project_root = project_root or _project_root()
    path = os.path.join(project_root, ".fabric", "subsystems.yaml")
    try:
        with open(path) as f:
            data = yaml.safe_load(f) or {}
    except (OSError, yaml.YAMLError):
        return []
    rules = []
    for entry in data.get("subsystems", []) or []:
        sid = entry.get("id")
        if not sid:
            continue
        for pattern in entry.get("paths", []) or []:
            rules.append((str(pattern), sid))
    rules.sort(key=lambda r: (-len(r[0]), r[0]))
    return rules


def derive_subsystem(path, project_root=None, rules=None):
    """Route a path to a subsystem id. Returns the id, or None when no rule matches."""
    project_root = project_root or _project_root()
    rel = path
    if os.path.isabs(rel):
        try:
            rel = os.path.relpath(rel, project_root)
        except ValueError:
            pass
    rel = rel.replace(os.sep, "/")
    # NOT lstrip("./") — that strips CHARACTERS, so ".fabric/x" would become
    # "fabric/x" and no ".fabric/*" rule could ever match it.
    while rel.startswith("./"):
        rel = rel[2:]
    if rules is None:
        rules = load_subsystem_rules(project_root)
    for pattern, sid in rules:
        if fnmatch.fnmatch(rel, pattern):
            return sid
    return None


# ---------------------------------------------------------------------------
# Card-level helpers (shared by enrich --describe and drift)
# ---------------------------------------------------------------------------

def is_placeholder_purpose(value):
    """True when `purpose` is the template TODO (or empty) and may be filled."""
    if value is None:
        return True
    text = str(value).strip().strip('"').strip()
    if not text:
        return True
    return bool(re.search(r"\b(TODO|FIXME)\b", text))


def is_placeholder_subsystem(value):
    return not value or str(value).strip() in ("", PLACEHOLDER_SUBSYSTEM, "null", "None")


def card_edge_count(card):
    total = 0
    for key in ("depends_on", "depended_by"):
        edges = card.get(key) or []
        if isinstance(edges, list):
            total += len([e for e in edges if e])
    return total


def describe_card(card, project_root=None, rules=None):
    """Compute the describe-time updates for one card.

    Fills placeholders ONLY — a purpose a human wrote is never overwritten, and
    a subsystem already routed is never re-routed. Returns
    ``(updates, refusal)`` where `updates` is a dict of field → new value (empty
    when there is nothing to do) and `refusal` is a one-line explanation when the
    purpose could not be derived, else None.
    """
    project_root = project_root or _project_root()
    loc = card.get("location") or card.get("id") or ""
    updates = {}
    refusal = None

    if loc and not re.match(r"^[a-zA-Z]+://", str(loc)):
        if is_placeholder_purpose(card.get("purpose")):
            hit = derive_purpose(loc, card.get("created_by"), project_root)
            if hit:
                updates["purpose"], updates["purpose_source"] = hit
            else:
                refusal = f"{loc}: describes itself nowhere — write a header comment"
        if is_placeholder_subsystem(card.get("subsystem")):
            sid = derive_subsystem(loc, project_root, rules)
            if sid:
                updates["subsystem"] = sid

    return updates, refusal


# ---------------------------------------------------------------------------
# CLI — `--emit-shell <path>` is how register.sh (bash) reads the deriver
# ---------------------------------------------------------------------------

def _emit_shell(rel_path, created_by, project_root):
    """Print base64-encoded assignments for `eval` in bash.

    base64 because a purpose sentence contains quotes, backticks and `$` often
    enough that any shell-quoting scheme would eventually mangle one.
    """
    import base64

    def b64(value):
        return base64.b64encode(str(value).encode()).decode()

    hit = derive_purpose(rel_path, created_by, project_root)
    if hit:
        print(f"FW_PURPOSE_B64={b64(hit[0])}")
        print(f"FW_PURPOSE_SOURCE={hit[1]}")
    else:
        print("FW_PURPOSE_B64=")
        print("FW_PURPOSE_SOURCE=")
    print(f"FW_SUBSYSTEM={derive_subsystem(rel_path, project_root) or ''}")
    return 0


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    project_root = _project_root()
    created_by = ""
    if "--created-by" in argv:
        i = argv.index("--created-by")
        created_by = argv[i + 1] if i + 1 < len(argv) else ""
        del argv[i:i + 2]
    if argv and argv[0] == "--emit-shell":
        if len(argv) < 2:
            print("usage: describe.py --emit-shell <path> [--created-by T-XXX]",
                  file=sys.stderr)
            return 2
        return _emit_shell(argv[1], created_by, project_root)
    if len(argv) == 1:
        hit = derive_purpose(argv[0], created_by, project_root)
        sub = derive_subsystem(argv[0], project_root)
        if hit:
            print(f"purpose:        {hit[0]}")
            print(f"purpose_source: {hit[1]}")
        else:
            print(f"{argv[0]}: describes itself nowhere — write a header comment")
        print(f"subsystem:      {sub or PLACEHOLDER_SUBSYSTEM}")
        return 0
    print("usage: describe.py <path> | describe.py --emit-shell <path> "
          "[--created-by T-XXX]", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
