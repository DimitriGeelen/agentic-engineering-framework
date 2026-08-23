#!/usr/bin/env python3
"""Fabric enrichment engine — auto-detect dependency edges from source analysis.

Reads component cards, analyzes their source files for import/source/render
patterns, resolves matches to component IDs, and writes both forward (depends_on)
and reverse (depended_by) edges back to cards.

Usage:
    python3 enrich.py [--dry-run] [--subsystem X] [--verbose] [CARD_PATH ...]
"""

import argparse
import glob
import os
import re
import sys
from collections import defaultdict
from datetime import date

import yaml


# ---------------------------------------------------------------------------
# YAML helpers
# ---------------------------------------------------------------------------

def load_card(path):
    with open(path) as f:
        return yaml.safe_load(f)


def save_card(path, data):
    """Write card YAML preserving readable formatting.

    Atomic write (T-2457 / OBS-080): serialize to a temp file in the SAME
    directory, then os.replace() — an atomic rename on POSIX. A non-atomic
    ``open(path, "w")`` truncates the card first and streams the new content,
    so a concurrent reader (e.g. ``fw fabric drift`` doing
    ``grep "^location:" *.yaml`` to build its registered set) can observe the
    card after truncation but before ``location:`` is written → the card's
    source path drops out of the registered set → spurious "unregistered"
    drift FP that clears on re-run once the write completes. os.replace keeps
    readers seeing either the complete old card or the complete new one.
    """
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False,
                  allow_unicode=True, width=120)
    os.replace(tmp, path)


# ---------------------------------------------------------------------------
# Index builder
# ---------------------------------------------------------------------------

def build_index(components_dir):
    """Build lookup indexes from all component cards."""
    cards = {}       # card_path -> card_data
    loc_to_id = {}   # relative_location -> component_id
    loc_to_card = {} # relative_location -> card_path
    id_to_loc = {}   # component_id -> relative_location
    id_to_card = {}  # component_id -> card_path

    for card_path in sorted(glob.glob(os.path.join(components_dir, "*.yaml"))):
        data = load_card(card_path)
        if not data:
            continue
        cards[card_path] = data
        loc = data.get("location", "")
        cid = data.get("id", "")
        if loc:
            loc_to_id[loc] = cid
            loc_to_card[loc] = card_path
        if cid:
            id_to_loc[cid] = loc
            id_to_card[cid] = card_path

    return cards, loc_to_id, loc_to_card, id_to_loc, id_to_card


# ---------------------------------------------------------------------------
# Reverse edge type mapping
# ---------------------------------------------------------------------------

REVERSE_EDGE_TYPE = {
    "calls": "called_by",
    "renders": "rendered_by",
    "reads": "read_by",
    "extends": "extended_by",
    "includes": "included_by",
    "registers": "registered_by",
}


# ---------------------------------------------------------------------------
# Pattern detectors — each returns list of (target_location, edge_type)
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Bash source-argument resolution (T-3122)
# ---------------------------------------------------------------------------

# Characters that may appear in a literal (unexpanded) path fragment.
_PATH_CHARS = set(
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._+-/@"
)

# A `source` / `.` command, at a shell command position (start of line, or after
# a separator / block keyword). The argument itself is scanned by hand below,
# because it may contain quotes, `&&` and nested `$( )` that no regex should try
# to balance.
_SOURCE_CMD_RE = re.compile(
    r'(?:^|[;&|(){}]|\bthen\b|\bdo\b|\belse\b)[ \t]*(?:source|\.)[ \t]+',
    re.MULTILINE,
)


def _read_shell_word(text, i):
    """Return the single shell word starting at ``text[i]``.

    Tracks quote state and `$( )` nesting so that an argument like
    ``"$(cd "$(dirname "$0")/.." && pwd)/lib/config.sh"`` is read whole instead
    of being cut at the embedded `&&`.
    """
    quote = None
    stack = []
    out = []
    while i < len(text):
        ch = text[i]
        if ch == '\n':
            break
        if ch == '\\' and i + 1 < len(text):
            out.append(ch)
            out.append(text[i + 1])
            i += 2
            continue
        if ch == '$' and text.startswith('$(', i):
            stack.append(quote)
            quote = None
            out.append('$(')
            i += 2
            continue
        if ch == ')' and stack:
            quote = stack.pop()
            out.append(ch)
            i += 1
            continue
        if quote is None and ch in '"\'':
            quote = ch
        elif quote == ch:
            quote = None
        elif quote is None and not stack and (ch.isspace() or ch in ';&|<>#'):
            break
        out.append(ch)
        i += 1
    return ''.join(out)


def _iter_source_args(content):
    """Yield the raw argument of every `source`/`.` command in ``content``."""
    for m in _SOURCE_CMD_RE.finditer(content):
        arg = _read_shell_word(content, m.end())
        if arg:
            yield arg


def _trailing_literal_path(arg):
    """Extract the trailing literal path from a source argument, or None.

    ``"$FRAMEWORK_ROOT/lib/config.sh"``, ``"$fw_root/lib/config.sh"``,
    ``"${ANYTHING}/lib/config.sh"``, ``"$(dirname "$0")/lib/config.sh"``,
    ``./lib/config.sh`` and ``lib/config.sh`` all yield ``lib/config.sh``.
    Whatever precedes the literal tail is irrelevant — the variable's *name* is
    never consulted.
    """
    a = arg.strip()
    bare = a.lstrip('"\'')
    # Not project sources: absolute system paths and home-relative paths.
    if not bare or bare[0] in '~/' or bare.startswith('$HOME'):
        return None

    # Blank out every expansion so only literal text survives the scan below.
    s = a.replace('"', '').replace("'", '')
    s = s.replace('$(', '\x00(')
    s = re.sub(r'\$\{[^}]*\}', '\x00', s)
    s = re.sub(r'\$[A-Za-z_][A-Za-z0-9_]*', '\x00', s)
    s = re.sub(r'\$[0-9@*#?!$-]', '\x00', s)

    i = len(s)
    while i > 0 and s[i - 1] in _PATH_CHARS:
        i -= 1
    path = s[i:].lstrip('/')
    while path.startswith('./'):
        path = path[2:]
    if not path or path.endswith('/') or path in ('.', '..'):
        return None
    return path


def _resolve_source_path(rel, source_dir, framework_root):
    """Resolve a literal source path against the source dir, then the root.

    Order (first hit wins, existence-guarded at every step):
      a) <source_dir>/<rel>
      b) <source_dir>/lib/<rel>     — preserves the old `$LIB_DIR` behaviour
      c) <project_root>/<rel>       — the `$FRAMEWORK_ROOT/...` idiom
    """
    for cand in (os.path.join(source_dir, rel),
                 os.path.join(source_dir, 'lib', rel),
                 rel):
        cand = os.path.normpath(cand)
        if os.path.isabs(cand) or cand.startswith('..'):
            continue
        if os.path.isfile(os.path.join(framework_root, cand)):
            return cand
    return None


# ---------------------------------------------------------------------------
# Bash invocation resolution (T-3123)
# ---------------------------------------------------------------------------
#
# Shell composes two ways. `source X` / `. X` splices X's TEXT into the caller
# — that is the T-3122 path above. The other way is INVOCATION: the caller runs
# X as a subprocess (`./x.sh`, `bash x.sh`, `exec "$D/x.sh"`). That edge was not
# modelled at all, so a script whose only dependency is what it executes got a
# card with zero edges.
#
# Everything below keys on SHELL grammar only — command position, POSIX
# builtins, shell interpreter names. No directory name, no variable name and no
# package prefix from this or any other tree appears here. That restraint is the
# point: T-3121 hardcoded `web|lib|agents|tools`, T-3122 hardcoded four $VAR
# names, and both broke the moment a file was written in a different idiom.

# A command position: start of line, or immediately after a separator /
# grouping character. Same construction as _SOURCE_CMD_RE, minus the fixed
# command name — here it is the word AT the position that gets read.
_CMD_POS_RE = re.compile(r'(?:^|[;&|(){}`])[ \t]*', re.MULTILINE)

# Words that stand in FRONT of the real command and hand off to it. POSIX
# builtins and coreutils wrappers, plus bats' `run`. Compared by basename, so
# `/usr/bin/env` matches `env`.
_CMD_PREFIX_WORDS = frozenset({
    'exec', 'command', 'builtin', 'env', 'nohup', 'nice', 'sudo', 'time',
    'if', 'elif', 'while', 'until', 'then', 'do', 'else', '!', 'run',
})

# Shell interpreters. After one of these, the script is the first non-option
# argument rather than the command word itself.
_SHELL_INTERPRETERS = frozenset({'sh', 'bash', 'zsh', 'ksh', 'dash', 'ash'})

_ENV_ASSIGN_RE = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*=')


def _mask_comment_lines(content):
    """Blank out whole-line `#` comments, preserving line structure.

    Usage banners and commented-out calls are prose, not composition; without
    this a `# bash tools/x.sh` example line becomes a dependency edge.
    """
    return re.sub(r'^[ \t]*#.*$', '', content, flags=re.MULTILINE)


_HEREDOC_START_RE = re.compile(r'<<-?\s*(["\']?)([A-Za-z_][A-Za-z0-9_]*)\1')


def _mask_inert_regions(content):
    """Blank the INSIDE of quoted strings, trailing comments and heredoc bodies.

    Used only to locate command positions. A `;` inside an echo message and a
    `(` inside an embedded `python3 - <<PY` body are text, not shell
    separators — but the command-position regex cannot tell, so it opened a
    bogus command at every one of them. That is where every false edge in this
    repo's corpus came from: `add_issue "... see .context/inbox.yaml"` and
    `print(f"  History: .context/bvp-weight-history.yaml")` both resolve to real
    files and both are prose.

    The result has the SAME length as ``content``, so a match offset found in it
    indexes the original unchanged. Callers read the word itself from the
    original, which is why masking a quoted argument is harmless: `exec
    "$D/x.sh"` is found at the position of `exec`, then read raw.

    Quote state is scoped to a LINE (heredocs excepted). Real shell is not a
    language a 60-line lexer can track — an `awk` program, a regex class or an
    apostrophe in a trailing comment will eventually desync it. Resetting per
    line bounds the damage of any desync to that one line instead of blanking
    the rest of a 5000-line file, which is exactly what an unscoped version did
    here: it silently cost 90% of the real edges and looked like a clean run.
    """
    out = list(content)
    heredoc = None          # (delimiter, allow_leading_tabs)
    pos = 0
    n = len(content)
    while pos < n:
        eol = content.find('\n', pos)
        if eol == -1:
            eol = n
        line = content[pos:eol]

        if heredoc is not None:
            delim, strip_tabs = heredoc
            if (line.lstrip('\t') if strip_tabs else line).strip() == delim:
                heredoc = None
            else:
                for k in range(pos, eol):
                    out[k] = ' '
            pos = eol + 1
            continue

        quote = None        # None | "'" | '"' | '`'
        stack = []          # quote states saved across $( ) nesting
        i = pos
        while i < eol:
            ch = content[i]

            if ch == '\\' and quote != "'" and i + 1 < eol:
                out[i + 1] = ' '
                i += 2
                continue

            if quote != "'" and content.startswith('$(', i):
                stack.append(quote)
                quote = None
                i += 2
                continue

            if quote is None and stack and ch == ')':
                quote = stack.pop()
                i += 1
                continue

            if quote is None:
                if ch == '#' and (i == pos or content[i - 1] in ' \t;&|('):
                    for k in range(i, eol):
                        out[k] = ' '
                    break
                if ch in '"\'`':
                    quote = ch
                    i += 1
                    continue
                if content.startswith('<<', i) and not content.startswith('<<<', i):
                    m = _HEREDOC_START_RE.match(content, i)
                    if m:
                        heredoc = (m.group(2), content.startswith('<<-', i))
                        i = m.end()
                        continue
            elif ch == quote:
                quote = None
                i += 1
                continue
            else:
                out[i] = ' '

            i += 1

        pos = eol + 1

    return ''.join(out)


def _is_executable(rel, framework_root):
    """Whether the resolved path can actually be RUN as a command.

    The shell's own rule, used as the shell uses it: a bare command word only
    invokes a file that carries the execute bit. A README, a YAML config or a
    settings.json mentioned in passing cannot be a subprocess, so it cannot be
    an invocation edge. Not applied behind an interpreter — `bash x.sh` runs a
    file whether or not it is chmod +x.
    """
    return os.access(os.path.join(framework_root, rel), os.X_OK)


def _trim_word_tail(word):
    """Drop closer punctuation that a word scan carries along.

    `_read_shell_word` stops at separators but not at an unmatched closer, so
    `$(bash a/b.sh)` hands back `a/b.sh)`. The trailing literal-path scan reads
    backwards from the end, so one stray `)` erases the whole path.
    """
    return word.rstrip(')}`;,')


def _skip_blanks(text, i):
    """Advance past spaces, tabs and backslash-newline continuations."""
    while i < len(text):
        if text[i] in ' \t':
            i += 1
        elif text.startswith('\\\n', i):
            i += 2
        else:
            break
    return i


def _iter_shell_invocations(content):
    """Yield the argument of every script INVOCATION in ``content``.

    Yields ``(word, via_interpreter)`` where ``word`` is the raw shell word
    naming the script and ``via_interpreter`` records whether it was reached
    through `bash`/`sh`/... (in which case it need not look like a path) or as
    the command word itself (in which case it must).

    Recognised, with any number of prefix words in front:
        ./a/b.sh          bash a/b.sh        sh b.sh        bash -e b.sh
        exec "$D/b.sh"    "$D/b.sh" a1 a2    $(dirname "$0")/b.sh
        command bash b.sh    VAR=1 exec ./b.sh    /usr/bin/env bash b.sh

    Deliberately NOT recognised: `bash -c "..."` (the argument is an inline
    command string, not a file), and any command word without a `/` — a bare
    name is a PATH lookup, not a script in this tree, so `grep x.sh` and
    `[ -f x.sh ]` never become edges.
    """
    scan = _mask_inert_regions(content)
    for m in _CMD_POS_RE.finditer(scan):
        # A line reached by backslash-continuation carries ARGUMENTS of the
        # command above it, not a new command. Without this, every entry of a
        # `for f in \` list and every wrapped `warn "..." \ "$D/x.sh"` argument
        # reads as an invocation — 11 of this repo's first 24 new edges were
        # exactly that, and every one pointed at a real executable file.
        p = m.start()
        if p > 0 and scan[p - 1] == '\n' and p >= 2 and scan[p - 2] == '\\':
            continue
        i = _skip_blanks(content, m.end())
        via_interpreter = False
        # Bounded: a real invocation reaches its script within a few words.
        for _ in range(8):
            word = _read_shell_word(content, i)
            if not word:
                break
            nxt = _skip_blanks(content, i + len(word))
            bare = word.strip('"\'')

            if via_interpreter:
                if bare.startswith('-'):
                    # `-c` (alone or bundled, e.g. `-ec`) means the next word is
                    # a command STRING. Abandon this command entirely.
                    if 'c' in bare.lstrip('-').split('=', 1)[0]:
                        break
                    i = nxt
                    continue
                # `bash -euo pipefail x.sh` — `pipefail` is the argument of an
                # option, not the script. A script argument is a path or carries
                # a suffix; a bare suffixless word is not one, so keep scanning.
                if '/' in bare or '.' in bare.rsplit('/', 1)[-1]:
                    yield _trim_word_tail(word), True
                    break
                i = nxt
                continue

            if _ENV_ASSIGN_RE.match(bare):
                i = nxt
                continue

            name = bare.rsplit('/', 1)[-1]
            if name in _CMD_PREFIX_WORDS:
                i = nxt
                continue
            if name in _SHELL_INTERPRETERS:
                via_interpreter = True
                i = nxt
                continue

            # The command word itself. Only a path can name a script in-tree.
            if '/' in bare:
                yield _trim_word_tail(word), False
            break


def detect_bash_sources(content, source_location, framework_root):
    """Detect bash source/dot-source, exec, and variable-path patterns.

    `source X` / `. X` is resolved by extracting the TRAILING LITERAL PATH from
    the argument and resolving that against the filesystem (T-3122). The prior
    implementation matched on the *variable name* — it recognised only
    `$LIB_DIR`, `$SCRIPT_DIR`, `$AGENTS_DIR` and `$FW_LIB_DIR`, so 127 of this
    repo's 194 source statements (65%) emitted no edge at all, including the 88
    written with the framework's own `$FRAMEWORK_ROOT/...` idiom. Same class as
    the hardcoded `web|lib|agents|tools` prefix list fixed in T-3121: resolve
    the path, don't trust a name list.
    """
    edges = []
    seen = set()
    source_dir = os.path.dirname(source_location)

    def add(target, relation="calls"):
        """Record an edge, guarding self-edges and duplicate targets."""
        if target and target != source_location and target not in seen:
            seen.add(target)
            edges.append((target, relation))

    # Pattern: source <arg> / . <arg> — any argument shape.
    for arg in _iter_source_args(content):
        rel = _trailing_literal_path(arg)
        if rel:
            add(_resolve_source_path(rel, source_dir, framework_root))

    # Pattern: INVOCATION — the caller runs the target as a subprocess rather
    # than splicing its text (T-3123). Resolved through exactly the same
    # trailing-literal-path machinery as `source`, so `bash "$ANY_VAR/x.sh"`
    # lands on the same target as `source "$ANY_VAR/x.sh"`. Shares `add()`, so
    # a script both sourced and invoked yields one edge, not two.
    for word, via_interpreter in _iter_shell_invocations(_mask_comment_lines(content)):
        rel = _trailing_literal_path(word)
        if not rel:
            continue
        target = _resolve_source_path(rel, source_dir, framework_root)
        if target and (via_interpreter or _is_executable(target, framework_root)):
            add(target)

    # Pattern: exec "$AGENTS_DIR/agent/script.sh" "$@"
    for m in re.finditer(r'exec\s+"?\$AGENTS_DIR/([^"$\s]+)"?', content):
        target = os.path.normpath(os.path.join("agents", m.group(1)))
        if os.path.exists(os.path.join(framework_root, target)):
            add(target)

    # Pattern: source/exec "$FW_LIB_DIR/file.sh"
    for m in re.finditer(
        r'(?:source|exec|\.)\s+"?\$FW_LIB_DIR/([^"$\s]+)"?', content
    ):
        target = os.path.normpath(os.path.join("lib", m.group(1)))
        if os.path.exists(os.path.join(framework_root, target)):
            add(target)

    # Pattern: exec python3 "$AGENTS_DIR/path"
    for m in re.finditer(r'exec\s+python3\s+"?\$AGENTS_DIR/([^"$\s]+)"?', content):
        target = os.path.normpath(os.path.join("agents", m.group(1)))
        if os.path.exists(os.path.join(framework_root, target)):
            add(target)

    # Pattern: exec python3 -m web.module
    for m in re.finditer(r'exec\s+python3\s+-m\s+(web\.\w+)', content):
        mod = m.group(1).replace(".", "/") + ".py"
        if os.path.exists(os.path.join(framework_root, mod)):
            add(mod)

    # Pattern: "$FRAMEWORK_ROOT/path.sh" or "$PROJECT_ROOT/path.sh" (called as command)
    for m in re.finditer(
        r'"?\$(?:FRAMEWORK_ROOT|PROJECT_ROOT)/([^"$\s]+\.sh)"?', content
    ):
        target = os.path.normpath(m.group(1))
        if os.path.exists(os.path.join(framework_root, target)):
            add(target)

    # Pattern: "$FRAMEWORK_ROOT/agents/X/Y.sh" via variable like GIT_AGENT=
    for m in re.finditer(
        r'(?:FRAMEWORK_ROOT|PROJECT_ROOT)["/]+?(agents/[^"$\s]+\.sh)', content
    ):
        target = os.path.normpath(m.group(1))
        if os.path.exists(os.path.join(framework_root, target)):
            add(target)

    # Pattern: "$FRAMEWORK_ROOT/metrics.sh" or standalone script paths
    for m in re.finditer(
        r'"?\$(?:FRAMEWORK_ROOT|PROJECT_ROOT)/([^"$\s]+\.(?:sh|py))"?', content
    ):
        target = os.path.normpath(m.group(1))
        if os.path.exists(os.path.join(framework_root, target)):
            add(target)

    # Pattern: "$FRAMEWORK_ROOT/bin/fw" / "$PROJECT_ROOT/bin/fw" — suffixless
    # invocation (T-2511). The FRAMEWORK_ROOT/*.sh pattern above requires a
    # .sh/.py suffix, so an actual `"$FRAMEWORK_ROOT/bin/fw" orchestrator …` call
    # (single-host-parallel-demo.sh) was missed. This is a real invocation path,
    # not prose — distinct from the bare `bin/fw` grep-pattern false-positive class.
    if re.search(r'"\$(?:FRAMEWORK_ROOT|PROJECT_ROOT)/bin/fw"', content) \
       and source_location != "bin/fw" and os.path.exists(os.path.join(framework_root, "bin/fw")):
        add("bin/fw")

    # Pattern: exec python3 "$(dirname "$0")/sibling.py"  (T-2511)
    # The fw hook dispatcher loads a thin .sh that exec's its own-dir .py sibling
    # (check-inception-schema.sh -> check-inception-schema.py etc.). Resolve
    # relative to the SOURCE file's directory.
    for m in re.finditer(r'\$\(\s*dirname\s+"?\$0"?\s*\)/([^"$\s]+\.(?:sh|py))', content):
        target = os.path.normpath(os.path.join(source_dir, m.group(1)))
        if os.path.exists(os.path.join(framework_root, target)) and target != source_location:
            add(target)

    return edges


def detect_fw_hook_dispatch(content, source_location, framework_root):
    """Detect `fw hook <name>` dispatcher calls → agents/context/<name>.sh (T-2511).

    `.claude/settings.json` (and some scripts) wire PreToolUse/PostToolUse hooks
    via `bin/fw hook check-inception-schema`, NOT a direct path to the .sh file —
    so the literal-path detectors never saw the dependency. The fw dispatcher
    convention is `fw hook <name>` -> agents/context/<name>.sh. Existence-guarded.
    """
    edges = []
    for m in re.finditer(r'fw\s+hook\s+([\w-]+)', content):
        target = os.path.join("agents", "context", m.group(1) + ".sh")
        if os.path.exists(os.path.join(framework_root, target)) and target != source_location:
            edges.append((target, "calls"))
    return edges


def detect_bats_deps(content, source_location, framework_root):
    """Detect dependencies in .bats test files (T-1754).

    Reuses bash patterns + adds bats-specific ones. Tests typically point at
    one or more system-under-test scripts via FRAMEWORK_ROOT/REPO_ROOT/AUDIT
    variables, `bash "$REPO_ROOT/path"` invocations, or literal paths.
    """
    # Start with the standard bash patterns — bats files are bash-shaped.
    edges = list(detect_bash_sources(content, source_location, framework_root))

    # Pattern: bash "$REPO_ROOT/path" or run bash "$FRAMEWORK_ROOT/path"
    for m in re.finditer(
        r'bash\s+"?\$(?:REPO_ROOT|FRAMEWORK_ROOT|PROJECT_ROOT)/([^"$\s]+)"?', content
    ):
        target = os.path.normpath(m.group(1))
        if os.path.exists(os.path.join(framework_root, target)):
            if target != source_location:
                edges.append((target, "tests"))

    # Pattern: VAR="$FRAMEWORK_ROOT/path/to/script.sh" assignments — capture the
    # script being tested even when not invoked via the bash patterns above.
    for m in re.finditer(
        r'\b\w+\s*=\s*"\$(?:REPO_ROOT|FRAMEWORK_ROOT|PROJECT_ROOT)/([^"$\s]+\.(?:sh|py))"',
        content,
    ):
        target = os.path.normpath(m.group(1))
        if os.path.exists(os.path.join(framework_root, target)):
            if target != source_location:
                edges.append((target, "tests"))

    # Pattern: literal framework-root-relative paths in arguments / quotes / heredocs
    # Constrains to known top-level dirs to avoid over-matching tmp paths or yaml fragments.
    for m in re.finditer(
        r'(?:["\'\s/]|^)((?:bin|lib|agents|tools|web|prompts)/[\w./-]+\.(?:sh|py))',
        content,
    ):
        target = m.group(1)
        if os.path.exists(os.path.join(framework_root, target)):
            if target != source_location:
                edges.append((target, "tests"))

    # Pattern: bare `bin/fw <subcommand>` references — every test that exercises
    # fw routing depends on bin/fw, even when the path isn't quoted explicitly.
    if re.search(r'\bbin/fw\b', content) and "bin/fw" != source_location:
        edges.append(("bin/fw", "tests"))

    # A .bats file that runs a script TESTS it. The generic bash detectors above
    # label the same reference `calls` (T-3123 sees `run bash "$R/x.sh"` as an
    # invocation, which it is), so without this a test file would carry two
    # edges to one subject under two relations — and the reverse pass would
    # write both `called_by` and `tested_by` onto the subject's card. The more
    # specific relation wins.
    tested = {t for t, etype in edges if etype == "tests"}
    edges = [(t, etype) for t, etype in edges
             if not (etype == "calls" and t in tested)]

    # De-duplicate while preserving order (multiple patterns may emit the same edge)
    seen = set()
    deduped = []
    for target, etype in edges:
        key = (target, etype)
        if key not in seen:
            seen.add(key)
            deduped.append((target, etype))
    return deduped


def detect_python_imports(content, source_location, framework_root):
    """Detect Python from/import and render_page patterns."""
    edges = []

    # Pattern: from {web,lib,agents,tools}.X import Y (T-1758 extends to lib/agents/tools)
    for m in re.finditer(r'from\s+((?:web|lib|agents|tools)(?:\.\w+)+)\s+import', content):
        mod_path = m.group(1).replace(".", "/")
        target = mod_path + ".py"
        if os.path.exists(os.path.join(framework_root, target)):
            if target != source_location:
                edges.append((target, "calls"))
            continue
        target = os.path.join(mod_path, "__init__.py")
        if os.path.exists(os.path.join(framework_root, target)):
            if target != source_location:
                edges.append((target, "calls"))

    # Pattern: from {web,lib,agents,tools} import NAME  (bare — no dot after prefix)
    # T-2511: the dotted pattern above misses `from lib import govd_policy` (the
    # module is a name imported FROM the package, e.g. test_govd_policy.py). Resolve
    # to prefix/NAME.py. Existence-guarded, additive.
    for m in re.finditer(r'from\s+(web|lib|agents|tools)\s+import\s+(\w+)', content):
        target = os.path.join(m.group(1), m.group(2) + ".py")
        if os.path.exists(os.path.join(framework_root, target)) and target != source_location:
            edges.append((target, "calls"))

    # Pattern: sys.path.insert(..., ".../lib") then bare `import NAME` → lib/NAME.py
    # T-2511: unit tests (test_resolver_run, test_ollama_loop, test_pi_worker) prepend
    # lib/ to sys.path and `import resolver`/`ollama_loop`/`pi_worker`. Only fire when
    # the file manipulates sys.path into lib/ AND lib/NAME.py exists — double-guarded.
    if re.search(r'sys\.path\.insert\([^)]*["\']lib["\']', content) or \
       re.search(r'sys\.path\.insert\([^)]*/\s*["\']lib["\']', content):
        for m in re.finditer(r'^import\s+(\w+)\s*(?:#.*)?$', content, re.MULTILINE):
            target = os.path.join("lib", m.group(1) + ".py")
            if os.path.exists(os.path.join(framework_root, target)) and target != source_location:
                edges.append((target, "calls"))

    # Pattern: render_page("template.html", ...)
    for m in re.finditer(r'render_page\(\s*["\']([^"\']+)["\']', content):
        template = m.group(1)
        target = os.path.join("web/templates", template)
        if os.path.exists(os.path.join(framework_root, target)):
            edges.append((target, "renders"))

    # Pattern: yaml.safe_load(open(path)) with literal path
    for m in re.finditer(
        r'yaml\.safe_load\(.*?open\([^)]*["\']([^"\']+)["\']', content
    ):
        path = m.group(1)
        if os.path.exists(os.path.join(framework_root, path)):
            edges.append((path, "reads"))

    return edges


def detect_python_path_refs(content, source_location, framework_root):
    """Detect path references in .py files (T-1758).

    Covers patterns the import-based detector misses — common in tests/tools that
    reference framework artefacts as paths rather than importing them:

      - Pathlib slash-chains: REPO_ROOT / "bin" / "fw"
      - Literal framework paths: "agents/handover/handover.sh"
      - Bare bin/fw references in subprocess args

    Mirrors detect_bats_deps shape (T-1754) — same dedup contract, same
    self-reference and unknown-target exclusion.
    """
    edges = []

    # Pattern: REPO_ROOT / "seg1" / "seg2" / "seg3"
    #          FRAMEWORK_ROOT / "lib" / "arc.sh"
    # Capture the full chain so we can reconstruct the relative path.
    chain_re = re.compile(
        r'(?:REPO_ROOT|FRAMEWORK_ROOT|PROJECT_ROOT)((?:\s*/\s*"[^"]+")+)'
    )
    seg_re = re.compile(r'"([^"]+)"')
    for m in chain_re.finditer(content):
        segments = seg_re.findall(m.group(1))
        if not segments:
            continue
        target = os.path.normpath("/".join(segments))
        if os.path.exists(os.path.join(framework_root, target)):
            if target != source_location:
                edges.append((target, "calls"))

    # Pattern: literal framework paths embedded in any string
    # (matches the detect_bats_deps literal-path branch).
    # T-2511: added backtick + paren to the prefix class — orchestrator-graph.py
    # references `agents/dispatch/yield-point.sh` inside a Markdown-style backtick
    # docstring, which the original ["\'\s/] prefix excluded.
    for m in re.finditer(
        r'(?:["\'\s/`(]|^)((?:bin|lib|agents|tools|web|prompts)/[\w./-]+\.(?:sh|py))',
        content,
    ):
        target = os.path.normpath(m.group(1))
        if os.path.exists(os.path.join(framework_root, target)):
            if target != source_location:
                edges.append((target, "calls"))

    # Pattern: os.path.join(<var>, "seg", ..., "file.py")  and
    #          <base> / "seg" / ... / "file.{py,sh}" slash-chains with ANY base
    # T-2511: tests build the module-under-test path via os.path.join or pathlib
    # slash-chains whose base is a local var (ROOT, repo, Path(...).parents[N]) —
    # the T-1758 chain_re only matched REPO_ROOT/FRAMEWORK_ROOT/PROJECT_ROOT bases.
    for m in re.finditer(r'os\.path\.join\(\s*\w+\s*,\s*((?:"[^"]+"\s*,\s*)*"[^"]+")\s*\)', content):
        segs = re.findall(r'"([^"]+)"', m.group(1))
        target = os.path.normpath("/".join(segs))
        if os.path.exists(os.path.join(framework_root, target)) and target != source_location:
            edges.append((target, "calls"))
    for m in re.finditer(r'(?:parents\[\d+\]|\b\w+)((?:\s*/\s*"[^"]+")+)', content):
        segs = re.findall(r'"([^"]+)"', m.group(1))
        if not segs:
            continue
        target = os.path.normpath("/".join(segs))
        if os.path.exists(os.path.join(framework_root, target)) and target != source_location \
           and target.split("/")[0] in ("bin", "lib", "agents", "tools", "web", "prompts", "tests"):
            edges.append((target, "calls"))

    # Pattern: bare bin/fw reference (subprocess args, etc.)
    if re.search(r'\bbin/fw\b', content) and "bin/fw" != source_location:
        if os.path.exists(os.path.join(framework_root, "bin/fw")):
            edges.append(("bin/fw", "calls"))

    # Dedupe by (target, etype)
    seen = set()
    deduped = []
    for target, etype in edges:
        if (target, etype) not in seen:
            seen.add((target, etype))
            deduped.append((target, etype))
    return deduped


def detect_blueprint_registration(content, source_location, framework_root):
    """Detect Flask blueprint registration in __init__.py or app.py."""
    edges = []

    # Pattern: from web.blueprints.X import bp
    for m in re.finditer(r'from\s+web\.blueprints\.(\w+)\s+import', content):
        mod_name = m.group(1)
        target = f"web/blueprints/{mod_name}.py"
        if os.path.exists(os.path.join(framework_root, target)):
            if target != source_location:
                edges.append((target, "registers"))

    return edges


def detect_template_deps(content, source_location, framework_root):
    """Detect Jinja2 template dependencies."""
    edges = []
    tmpl_dir = "web/templates"

    # Pattern: {% extends "base.html" %}
    for m in re.finditer(r'\{%[-\s]*extends\s+["\']([^"\']+)["\']', content):
        target = os.path.join(tmpl_dir, m.group(1))
        if os.path.exists(os.path.join(framework_root, target)):
            edges.append((target, "extends"))

    # Pattern: {% include "_fragment.html" %}
    for m in re.finditer(r'\{%[-\s]*include\s+["\']([^"\']+)["\']', content):
        target = os.path.join(tmpl_dir, m.group(1))
        if os.path.exists(os.path.join(framework_root, target)):
            edges.append((target, "includes"))

    return edges


def detect_generic_python_imports(content, source_location, project_root):
    """
    Detect standard Python imports: `from X import Y` and `import X`.

    Handles dotted module paths (`from pkg.mod import Y`, `import pkg.mod`),
    resolving each to either `pkg/mod.py` or `pkg/mod/__init__.py` relative to
    the source file's directory, then its parent. Flat imports resolve exactly
    as before (T-3121 — the `\\w` pattern excluded `.`, so 114 dotted imports in
    this repo emitted no edge at all).

    This is a prototype for consumer project support (L-CONSUMER-001).
    """
    edges = []
    seen = set()

    # Get directory containing source file
    source_dir = os.path.dirname(source_location)

    # Skip standard library and common third-party modules
    SKIP_MODULES = {
        'typing', 'os', 'sys', 'datetime', 'argparse', 'subprocess',
        'yaml', 're', 'json', 'pathlib', 'collections', 'functools',
        'itertools', 'logging', 'time', 'random', 'math', 'copy',
        'enum', 'dataclasses', 'abc', 'urllib', 'http', 'email',
        'sqlite3', 'csv', 'xml', 'html', 'unittest', 'pytest',
        'flask', 'jinja2', 'werkzeug', 'requests', 'numpy', 'pandas'
    }

    def resolve(module_name):
        """Resolve a (possibly dotted) module name to a project-relative path."""
        # Relative imports (`from . import x`) carry no resolvable root segment
        if module_name.startswith('.') or module_name.endswith('.'):
            return None

        parts = module_name.split('.')
        if not all(parts):
            return None

        # SKIP_MODULES is consulted on the ROOT segment: `yaml.parser` is still
        # third-party even though `yaml` alone is what the set lists.
        if parts[0] in SKIP_MODULES:
            return None

        subpath = os.path.join(*parts)

        candidates = []
        # Strategy 1: Same directory as source
        candidates.append(os.path.join(source_dir, subpath + '.py'))
        # Strategy 2: Package init file
        candidates.append(os.path.join(source_dir, subpath, '__init__.py'))
        # Strategy 3: Check parent directory (for shared modules)
        parent_dir = os.path.dirname(source_dir)
        if parent_dir:
            candidates.append(os.path.join(parent_dir, subpath + '.py'))
            candidates.append(os.path.join(parent_dir, subpath, '__init__.py'))

        # Strategy 4: project-root-relative (T-3121). A dotted import is normally
        # rooted at the project, not at the importing file's directory —
        # `web/blueprints/tasks.py` doing `from web.shared import x` means
        # `<root>/web/shared.py`, which strategies 1-3 cannot reach from
        # `web/blueprints/`. Without this the generic detector returns zero edges
        # for ANY nested source file, which is why detect_python_imports carries a
        # hardcoded `web|lib|agents|tools` prefix list: that list is this strategy,
        # written out for one project's top-level packages. Last so local
        # resolution still wins, and existence-guarded like the rest.
        candidates.append(subpath + '.py')
        candidates.append(os.path.join(subpath, '__init__.py'))

        for target in candidates:
            if os.path.exists(os.path.join(project_root, target)):
                return target
        return None

    def add(module_name):
        target = resolve(module_name)
        # Never a self-edge, never a duplicate target from one file
        if target and target != source_location and target not in seen:
            seen.add(target)
            edges.append((target, "uses"))

    # Pattern: from module.path import something
    for m in re.finditer(r'^[ \t]*from\s+([\w.]+)\s+import\b', content, re.MULTILINE):
        add(m.group(1))

    # Pattern: import a.b, c as d
    for m in re.finditer(r'^[ \t]*import\s+([^\n#;]+)', content, re.MULTILINE):
        for chunk in m.group(1).split(','):
            name = chunk.strip().split(' as ')[0].strip()
            if name and re.fullmatch(r'[\w.]+', name):
                add(name)

    return edges


RUST_SKIP_CRATES = {
    # Language built-ins and intra-crate aliases
    "std", "core", "alloc", "crate", "self", "super",
    # Async runtime + futures
    "tokio", "tokio_util", "tokio_stream", "futures", "futures_util",
    "async_trait",
    # Serde + encoding
    "serde", "serde_json", "serde_yaml", "serde_with", "bincode",
    "base64", "hex", "byteorder",
    # Errors + logging
    "anyhow", "thiserror", "tracing", "tracing_subscriber", "log",
    "env_logger",
    # Crypto / hashing / rand
    "sha2", "sha1", "md5", "blake3",
    "ed25519", "ed25519_dalek", "x25519_dalek", "rsa", "ring",
    "rand", "rand_core", "rand_chacha", "getrandom",
    # Data structures + time
    "chrono", "time", "uuid", "once_cell", "lazy_static",
    "parking_lot", "dashmap", "smallvec", "indexmap", "ahash",
    # CLI + HTTP + RPC
    "clap", "structopt",
    "reqwest", "hyper", "axum", "warp", "tower", "http", "url",
    "jsonrpsee", "jsonrpc_core",
    # Storage
    "rusqlite", "r2d2", "sled",
    # Testing / utilities
    "tempfile", "assert_cmd", "predicates", "insta", "mockall",
    "pretty_assertions",
    # Misc third-party seen in this workspace
    "libc", "nix", "bytes", "regex", "dirs", "home",
    "toml", "toml_edit", "shellwords",
}


def detect_rust_deps(content, source_location, project_root):
    """Detect Rust `mod` declarations and cross-crate `use` statements.

    Two edge patterns, both mapped to edge type "calls" (same convention as
    bash source and python imports):

    1. `mod <name>;` — resolves to a sibling file `<dir>/<name>.rs` or a
       subdir module `<dir>/<name>/mod.rs`. This captures intra-crate
       structural composition (lib.rs → submodule files).

    2. `use <crate>::...;` / `pub use <crate>::...;` — when `<crate>` maps
       to a workspace crate via the `crate_name → kebab-case → crates/<kebab>/src/lib.rs`
       convention, emit an edge to that crate's lib.rs. Third-party and std
       crates in `RUST_SKIP_CRATES` are ignored.

    Intra-crate `use crate::foo::Bar` is deliberately NOT detected here —
    the owning `lib.rs` / `mod.rs` already has `mod foo;` which captures
    the sibling edge, so adding a second edge would be noise.
    """
    edges = []
    source_dir = os.path.dirname(source_location)

    # Pattern: mod foo;  (optionally with pub or pub(crate)/pub(super))
    # Skip `mod foo { ... }` inline modules — only resolve file/dir modules.
    # Skip `#[cfg(test)] mod tests { ... }` via the `;` anchor; inline blocks
    # end in `{` not `;`.
    for m in re.finditer(
        r'^\s*(?:pub(?:\([^)]+\))?\s+)?mod\s+([A-Za-z_][A-Za-z0-9_]*)\s*;',
        content,
        re.MULTILINE,
    ):
        mod_name = m.group(1)
        # Try sibling file first: <source_dir>/<mod>.rs
        sibling = os.path.normpath(os.path.join(source_dir, f"{mod_name}.rs"))
        if os.path.exists(os.path.join(project_root, sibling)):
            if sibling != source_location:
                edges.append((sibling, "calls"))
            continue
        # Fall back to subdir module: <source_dir>/<mod>/mod.rs
        subdir = os.path.normpath(os.path.join(source_dir, mod_name, "mod.rs"))
        if os.path.exists(os.path.join(project_root, subdir)):
            if subdir != source_location:
                edges.append((subdir, "calls"))

    # Pattern: use <crate>::...;  or  pub use <crate>::...;
    # Grab the leading path segment; the resolver decides if it's a crate.
    # Also handles `use <crate>;` (no `::`) and `use <crate> as Alias;`.
    seen_crates = set()
    for m in re.finditer(
        r'^\s*(?:pub(?:\([^)]+\))?\s+)?use\s+([A-Za-z_][A-Za-z0-9_]*)\b',
        content,
        re.MULTILINE,
    ):
        crate_name = m.group(1)
        if crate_name in RUST_SKIP_CRATES:
            continue
        if crate_name in seen_crates:
            continue
        seen_crates.add(crate_name)
        # Rust `_` → Cargo `-` (underscore ↔ hyphen convention)
        kebab = crate_name.replace("_", "-")
        target = os.path.normpath(f"crates/{kebab}/src/lib.rs")
        if os.path.exists(os.path.join(project_root, target)):
            if target != source_location:
                edges.append((target, "calls"))

    return edges


def detect_ts_js_imports(content, source_location, project_root):
    """Detect TypeScript/JavaScript import/require patterns.

    Handles: import X from './path', import {X} from './path',
             export {X} from './path', require('./path'),
             dynamic import('./path').

    Resolves relative paths (./ and ../) against source directory.
    Skips bare package imports (no ./ prefix) as they're node_modules.
    T-552: Origin — OpenClaw eval showed 0 edges on TS project.
    """
    edges = []
    source_dir = os.path.dirname(source_location)

    import_paths = set()

    # ES module: import X from 'path' / import {X} from 'path' / export {X} from 'path'
    for m in re.finditer(
        r'''(?:import|export)\s+.*?\s+from\s+['"]([^'"]+)['"]''', content
    ):
        import_paths.add(m.group(1))

    # Side-effect import: import 'path'
    for m in re.finditer(r'''import\s+['"]([^'"]+)['"]''', content):
        import_paths.add(m.group(1))

    # CommonJS: require('path')
    for m in re.finditer(r'''require\s*\(\s*['"]([^'"]+)['"]\s*\)''', content):
        import_paths.add(m.group(1))

    # Dynamic import: import('path')
    for m in re.finditer(r'''import\s*\(\s*['"]([^'"]+)['"]\s*\)''', content):
        import_paths.add(m.group(1))

    for imp in import_paths:
        # Skip bare package imports (node_modules)
        if not imp.startswith('.'):
            continue

        resolved = os.path.normpath(os.path.join(source_dir, imp))

        # Try exact path, then common extensions and index files
        extensions = ['', '.ts', '.tsx', '.js', '.jsx',
                      '/index.ts', '/index.tsx', '/index.js', '/index.jsx']
        for ext in extensions:
            candidate = resolved + ext
            if os.path.exists(os.path.join(project_root, candidate)):
                if candidate != source_location:
                    edges.append((candidate, "uses"))
                break

    return edges


# ---------------------------------------------------------------------------
# Edge resolver
# ---------------------------------------------------------------------------

def classify_unresolved(loc, project_root):
    """Why did this target not resolve to a card? (T-2736)

    Returns "ignorable" | "actionable" | "absent".

    The distinction is derived from the target itself, never from an allowlist
    of known-noisy paths (L-533) — a directory is ignorable *because it is a
    directory*, not because someone remembered to list it. An allowlist can
    only ever cover the noise its author had already seen.
    """
    path = os.path.join(project_root, loc) if project_root else loc
    if os.path.isdir(path):
        return "ignorable"      # a dependency on a directory is not a component
    if os.path.isfile(path):
        return "actionable"     # a real file with no card — `fw fabric register`
    return "absent"             # referenced but not on disk


def resolve_edges(raw_edges, loc_to_id, source_id, unresolved=None,
                  project_root=None):
    """Convert (location, type) pairs to edge dicts. Deduplicates.

    T-2736: unresolvable targets were dropped by a bare `continue` with no
    counter, no verbose line and no effect on the summary — so enrichment could
    only ever draw edges inside the already-registered set, and a run that
    discarded everything reported identically to one that discarded nothing.

    Measured before the fix: 2419 raw edges detected, 2124 kept, 295 discarded
    across 117 distinct targets, every one of which existed on disk. The split
    is what makes the silence expensive — 148 of those edge instances pointed at
    directories (genuine detector noise, correctly dropped) and 147 at real
    uncarded files (genuine coverage loss). One mute branch was doing both jobs,
    so no reader could tell a healthy run from a lossy one.

    Passing `unresolved` (a dict) collects the breakdown for the caller to
    report. Omitting it preserves the previous signature exactly.
    """
    seen = set()
    resolved = []

    for loc, edge_type in raw_edges:
        loc = os.path.normpath(loc)
        target_id = loc_to_id.get(loc)
        if not target_id:
            if unresolved is not None:
                kind = classify_unresolved(loc, project_root)
                unresolved.setdefault(kind, {})
                unresolved[kind][loc] = unresolved[kind].get(loc, 0) + 1
            continue
        if target_id == source_id:
            continue
        key = (target_id, edge_type)
        if key in seen:
            continue
        seen.add(key)
        resolved.append({"target": target_id, "type": edge_type})

    return resolved


# ---------------------------------------------------------------------------
# Forward pass — detect depends_on for each card
# ---------------------------------------------------------------------------

def compute_forward_edges(cards, loc_to_id, framework_root, unresolved=None):
    """Analyze all cards and return new forward edges per card_path.

    Returns: dict of card_path -> list of edge dicts to ADD to depends_on

    T-2736: pass `unresolved` (a dict) to collect the breakdown of targets that
    did not resolve to a card, so the summary can report what was dropped.
    """
    forward = {}  # card_path -> [edge_dicts]

    for card_path, card_data in sorted(cards.items()):
        location = card_data.get("location", "")
        card_id = card_data.get("id", "")

        if not location:
            continue

        source_path = os.path.join(framework_root, location)
        if not os.path.exists(source_path):
            continue

        try:
            with open(source_path, "r", errors="replace") as f:
                # T-2511: was 100_000 — bin/fw (349 KB, the central dispatcher that
                # exec's nearly every lib/agent script) had all its dispatch routing
                # past byte 100K truncated away, hiding 65+ real edges and leaving
                # lib/pause.sh, lib/worktree.sh, orchestrator-graph.py edgeless. 2 MB
                # covers every realistic source file (largest is ~350 KB) with headroom.
                content = f.read(2_000_000)
        except (OSError, UnicodeDecodeError):
            continue

        # Determine file type — check extension, fall back to shebang
        raw_edges = []
        is_bash = location.endswith(".sh")
        is_bats = location.endswith(".bats")
        is_python = location.endswith(".py")
        is_html = location.endswith(".html")
        is_ts_js = any(location.endswith(ext) for ext in ('.ts', '.tsx', '.js', '.jsx'))
        is_rust = location.endswith(".rs")
        if not (is_bash or is_bats or is_python or is_html or is_ts_js or is_rust):
            first_line = content.split("\n", 1)[0] if content else ""
            if "bash" in first_line or "sh" in first_line:
                is_bash = True
            elif "python" in first_line:
                is_python = True

        if is_bats:
            raw_edges.extend(detect_bats_deps(content, location, framework_root))
        elif is_bash:
            raw_edges.extend(detect_bash_sources(content, location, framework_root))
        elif is_python:
            raw_edges.extend(detect_python_imports(content, location, framework_root))
            raw_edges.extend(detect_python_path_refs(content, location, framework_root))  # T-1758
            raw_edges.extend(detect_blueprint_registration(content, location, framework_root))
            raw_edges.extend(detect_generic_python_imports(content, location, framework_root))  # L-CONSUMER-001 prototype
        elif is_html:
            raw_edges.extend(detect_template_deps(content, location, framework_root))
        elif is_ts_js:
            raw_edges.extend(detect_ts_js_imports(content, location, framework_root))
        elif is_rust:
            raw_edges.extend(detect_rust_deps(content, location, framework_root))

        # T-2511: fw-hook dispatcher edges (`fw hook <name>` → agents/context/<name>.sh)
        # run on EVERY card regardless of type — the primary source is
        # .claude/settings.json (a .json file that no type-detector above scans).
        raw_edges.extend(detect_fw_hook_dispatch(content, location, framework_root))

        if not raw_edges:
            continue

        new_edges = resolve_edges(raw_edges, loc_to_id, card_id,
                                  unresolved=unresolved,
                                  project_root=framework_root)
        if not new_edges:
            continue

        # Filter out edges already present
        existing = card_data.get("depends_on", []) or []
        existing_keys = set()
        if isinstance(existing, list):
            for e in existing:
                if isinstance(e, dict):
                    existing_keys.add((e.get("target", ""), e.get("type", "")))

        to_add = []
        for edge in new_edges:
            key = (edge["target"], edge["type"])
            if key not in existing_keys:
                to_add.append(edge)

        if to_add:
            forward[card_path] = to_add

    return forward


# ---------------------------------------------------------------------------
# Reverse pass — compute depended_by from forward edges
# ---------------------------------------------------------------------------

def compute_reverse_edges(forward_edges, cards, id_to_card):
    """From forward edges, compute reverse depended_by edges per card_path.

    Returns: dict of card_path -> list of edge dicts to ADD to depended_by
    """
    reverse = defaultdict(list)  # card_path -> [edge_dicts]

    for source_path, edges in forward_edges.items():
        source_data = cards[source_path]
        source_id = source_data.get("id", "")

        for edge in edges:
            target_id = edge["target"]
            edge_type = edge["type"]
            rev_type = REVERSE_EDGE_TYPE.get(edge_type, f"{edge_type}_by")
            target_card_path = id_to_card.get(target_id)
            if not target_card_path:
                continue
            reverse[target_card_path].append({
                "target": source_id,
                "type": rev_type,
            })

    # Also compute reverse edges from EXISTING depends_on that were already
    # in the cards (so targets of pre-existing edges also get depended_by)
    for card_path, card_data in cards.items():
        source_id = card_data.get("id", "")
        existing_deps = card_data.get("depends_on", []) or []
        if not isinstance(existing_deps, list):
            continue
        for edge in existing_deps:
            if not isinstance(edge, dict):
                continue
            target_id = edge.get("target", "")
            edge_type = edge.get("type", "")
            rev_type = REVERSE_EDGE_TYPE.get(edge_type, f"{edge_type}_by")
            target_card_path = id_to_card.get(target_id)
            if not target_card_path:
                continue
            reverse[target_card_path].append({
                "target": source_id,
                "type": rev_type,
            })

    # Deduplicate and filter already-present reverse edges
    filtered = {}
    for card_path, rev_edges in reverse.items():
        card_data = cards.get(card_path)
        if not card_data:
            continue

        existing_depby = card_data.get("depended_by", []) or []
        existing_keys = set()
        if isinstance(existing_depby, list):
            for e in existing_depby:
                if isinstance(e, dict):
                    existing_keys.add((e.get("target", ""), e.get("type", "")))

        seen = set()
        to_add = []
        for edge in rev_edges:
            key = (edge["target"], edge["type"])
            if key not in existing_keys and key not in seen:
                to_add.append(edge)
                seen.add(key)

        if to_add:
            filtered[card_path] = to_add

    return filtered


# ---------------------------------------------------------------------------
# Write pass — apply edges to cards
# ---------------------------------------------------------------------------

def apply_edges(cards, forward, reverse, dry_run, verbose):
    """Write forward and reverse edges to cards. Returns stats."""
    today = str(date.today())
    cards_touched = set()
    total_fwd = 0
    total_rev = 0
    subsystem_stats = defaultdict(int)

    # Apply forward edges (depends_on)
    for card_path, edges in sorted(forward.items()):
        card_data = cards[card_path]
        name = card_data.get("name", "?")
        subsystem = card_data.get("subsystem", "unknown")

        if verbose:
            for e in edges:
                print(f"  {name}: depends_on +{e['type']:10s} -> {e['target']}")

        if not dry_run:
            existing = card_data.get("depends_on", []) or []
            if not isinstance(existing, list):
                existing = []
            card_data["depends_on"] = existing + edges
            card_data["last_enriched"] = today

        cards_touched.add(card_path)
        total_fwd += len(edges)
        subsystem_stats[subsystem] += len(edges)

    # Apply reverse edges (depended_by)
    for card_path, edges in sorted(reverse.items()):
        card_data = cards[card_path]
        name = card_data.get("name", "?")
        subsystem = card_data.get("subsystem", "unknown")

        if verbose:
            for e in edges:
                print(f"  {name}: depended_by +{e['type']:10s} <- {e['target']}")

        if not dry_run:
            existing = card_data.get("depended_by", []) or []
            if not isinstance(existing, list):
                existing = []
            card_data["depended_by"] = existing + edges
            card_data["last_enriched"] = today

        cards_touched.add(card_path)
        total_rev += len(edges)
        subsystem_stats[subsystem] += len(edges)

    # Save all touched cards
    if not dry_run:
        for card_path in cards_touched:
            save_card(card_path, cards[card_path])

    return len(cards_touched), total_fwd, total_rev, dict(subsystem_stats)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Enrich fabric component cards with dependency edges"
    )
    parser.add_argument("--dry-run", action="store_true",
                        help="Report changes without writing")
    parser.add_argument("--subsystem",
                        help="Only enrich cards in this subsystem")
    parser.add_argument("--verbose", "-v", action="store_true",
                        help="Show each detected edge")
    parser.add_argument("cards", nargs="*",
                        help="Specific card paths to enrich (default: all)")
    args = parser.parse_args()

    # Find project root (use PROJECT_ROOT env var if available, for embedded frameworks)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.environ.get("PROJECT_ROOT") or os.path.normpath(os.path.join(script_dir, "..", "..", ".."))
    components_dir = os.path.join(project_root, ".fabric", "components")

    if not os.path.isdir(components_dir):
        print(f"ERROR: Components directory not found: {components_dir}",
              file=sys.stderr)
        sys.exit(1)

    # Build index
    cards, loc_to_id, loc_to_card, id_to_loc, id_to_card = build_index(
        components_dir
    )

    # Filter to target cards if specified
    if args.cards:
        targets = {}
        for p in args.cards:
            p = os.path.abspath(p)
            if p in cards:
                targets[p] = cards[p]
            else:
                print(f"WARN: Card not found: {p}", file=sys.stderr)
    elif args.subsystem:
        targets = {p: d for p, d in cards.items()
                   if d.get("subsystem") == args.subsystem}
        if not targets:
            print(f"No cards for subsystem: {args.subsystem}", file=sys.stderr)
            sys.exit(1)
    else:
        targets = cards

    mode = "DRY RUN" if args.dry_run else "ENRICHING"
    print(f"\n=== Fabric Enrichment ({mode}) ===")
    print(f"Processing {len(targets)} cards...\n")

    # Phase 1: Compute forward edges (depends_on)
    unresolved = {}
    forward = compute_forward_edges(targets, loc_to_id, project_root,
                                    unresolved=unresolved)

    # Phase 2: Compute reverse edges (depended_by) — uses ALL cards as targets
    reverse = compute_reverse_edges(forward, cards, id_to_card)

    # If subsystem filter, also limit reverse edges to target subsystem's cards
    # But actually we want reverse edges on ANY card that is a target — even
    # outside the subsystem. So we use all cards for reverse computation.

    # Phase 3: Apply
    n_cards, n_fwd, n_rev, sub_stats = apply_edges(
        cards, forward, reverse, args.dry_run, args.verbose
    )

    # Summary
    print(f"\n=== Summary ===")
    print(f"Cards processed:   {len(targets)}")
    print(f"Cards enriched:    {n_cards}")
    print(f"Forward edges:     {n_fwd}  (depends_on)")
    print(f"Reverse edges:     {n_rev}  (depended_by)")
    print(f"Total edges added: {n_fwd + n_rev}")

    # T-2736: report what did NOT resolve. Before this, unresolvable targets
    # were dropped by a bare `continue` — so a run that discarded 295 edges
    # printed the same summary as one that discarded none, and the operator
    # had no way to tell "nothing to add" from "everything thrown away".
    #
    # ACTIONABLE is printed even at zero. An absence has to be representable,
    # or a clean run and a broken counter look identical (L-525).
    n_actionable = sum(unresolved.get("actionable", {}).values())
    n_ignorable = sum(unresolved.get("ignorable", {}).values())
    n_absent = sum(unresolved.get("absent", {}).values())
    d_actionable = len(unresolved.get("actionable", {}))

    print(f"\n=== Unresolved edge targets ===")
    print(f"Actionable:        {n_actionable}  ({d_actionable} real file(s) "
          f"with no card — run: fw fabric register <path>)")
    print(f"Ignorable:         {n_ignorable}  (directories — not components)")
    if n_absent:
        print(f"Absent:            {n_absent}  (referenced but not on disk)")

    if args.verbose and d_actionable:
        print(f"\nUncarded files referenced as dependencies:")
        for loc, count in sorted(unresolved["actionable"].items(),
                                 key=lambda x: -x[1]):
            print(f"  x{count:<4d} {loc}")

    if sub_stats:
        print(f"\nEdges by subsystem:")
        for sub, count in sorted(sub_stats.items(), key=lambda x: -x[1]):
            print(f"  {sub:30s}  +{count}")

    if args.dry_run:
        print(f"\n(Dry run — no files were modified)")

    return 0


if __name__ == "__main__":
    sys.exit(main())
