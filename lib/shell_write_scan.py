#!/usr/bin/env python3
"""shell_write_scan — does a Bash command write a task file? (T-3695)

`check-human-ac-tick` used to run on Write|Edit only, so `sed -i`, `perl -pi`, `tee`,
`cp`, a redirect or `python3 -c` could turn `- [ ]` into `- [x]` under `### Human` with
no check at all. The Write/Edit leg can diff old against new content; a shell command's
result cannot be computed before it runs. So the Bash leg does not ask "does this tick a
box?" — it asks "does this command write a guarded file?", and a guarded file is never
written from the shell under agent control. The Edit tool stays the sanctioned route (and
is diffed by the Write/Edit leg).

GUARDED
-------
  * any path with a `.tasks` component (task files, templates, active/completed dirs)
  * the Human-tick provenance ledger (`human-ac-ticks.jsonl`, lib/human_ac_ticks.py)
  * the Watchtower tick endpoint (`/toggle-ac`) — a POST to it IS a tick

HOW (a text gate, deliberately)
-------------------------------
The command is tokenised bash-style (_tokens: quote-aware, so a `>` inside a quoted sed script is
not a redirect), split into simple commands on `; && || | & ( ) newline` and backticks,
and each segment is read as bash would: leading assignments and wrappers (`sudo`, `env`,
`timeout`, `xargs`, ...) are skipped, so the VERB is the word in command position — a verb
mentioned inside an argument never counts (T-3678 triage: anchor to command position).

Per segment the write targets are collected:
  redirections        > >> >| &> &>> <> >&FILE   (not `2>&1`)
  in-place editors    sed -i, perl -i, ruby -i, awk -i inplace
  copy family         cp mv install ln rsync (dest or -t DIR), dd of=, tee, sponge,
                      sort -o, patch, editors (ed ex vi vim nano ...)
  git                 checkout / restore / apply / am naming a guarded path
  find                -exec/-execdir/-ok inner command, -fprint*
  inline code         python -c, perl -e, ruby -e, node -e, sh/bash -c, eval, and an
                      interpreter reading code from stdin / a heredoc

A target is RESOLVED (cwd tracked through `cd`, globs expanded, realpath taken) and refused
when it is guarded. A target the text cannot resolve (`$VAR`, `$(...)`, a brace, a glob
with no match, operands fed by xargs / find) is refused when the command mentions a
guarded path anywhere. Inline code is opaque: it is refused when the command mentions a
guarded path anywhere. Fail direction: toward blocking.

WHAT THIS DOES NOT SEE (same scope boundary as Tier 0, T-2742)
---------------------------------------------------------------
A script file run by the command (`bash ./x.sh`, `python3 tool.py`, `make`) is not opened;
a path assembled at run time from pieces the text does not contain (`'.ta'+'sks'`,
printf, a path read from a file written by an earlier call) is not seen. Those writes are
caught after the fact, not before: `fw audit` (lib/human_ac_ticks.py) FAILs on a committed
`### Human` tick that carries no provenance.
"""
from __future__ import annotations

import glob
import os
import re
from dataclasses import dataclass, field
from typing import Callable, Optional

LEDGER_NAME = "human-ac-ticks.jsonl"

# A mention of a guarded path anywhere in the command (quotes/backslashes removed).
MENTION_RE = re.compile(
    r"\.tasks\b|tasks/(?:active|completed|templates)\b|/(?:active|completed)/T-\d"
    r"|\bT-\d+[-\w]*\.md\b|human-ac-ticks\.jsonl|toggle-ac",
    re.I,
)

SEPARATORS = {";", ";;", "&&", "||", "|", "|&", "&", "(", ")", "\n", "!", "{", "}"}
REDIRECT_WRITE = {">", ">>", ">|", "&>", "&>>", "<>", ">&", "&>|"}
WRAPPERS = {"sudo", "doas", "env", "command", "builtin", "exec", "nohup", "nice", "ionice",
            "time", "timeout", "stdbuf", "chronic", "unbuffer", "setsid", "flock", "chroot",
            "runuser", "su", "watch", "then", "do", "else", "elif", "if", "while", "until",
            "fakeroot", "strace", "ltrace"}
WRAPPER_ARGC = {"timeout": 1, "nice": 0, "flock": 1, "chroot": 1, "watch": 0}
INTERPRETERS = re.compile(
    r"^(python[0-9.]*|pypy[0-9.]*|perl[0-9.]*|ruby[0-9.]*|node(js)?|deno|bun|php[0-9.]*|lua[0-9.]*"
    r"|tclsh|bash|sh|zsh|dash|ksh|mksh|fish|busybox|osascript|R|Rscript|julia|awk|gawk|mawk|nawk"
    r"|jq|yq|sqlite3|ex|vim?|nvim|emacs|ed)$")
EDITORS = {"ed", "red", "ex", "vi", "vim", "nvim", "view", "nano", "pico", "emacs", "joe", "micro",
           "mcedit", "kak", "helix", "hx"}
COPY_FAMILY = {"cp", "mv", "install", "ln", "rsync", "scp", "gcp", "gmv"}
EXTRACTORS = {"tar", "bsdtar", "unzip", "cpio", "7z", "7za", "pax", "busybox"}
NETWORK_VERBS = {"curl", "wget", "http", "https", "xh", "httpie", "aria2c", "nc", "ncat", "socat",
                 "lynx", "w3m", "links", "elinks"}
UNRESOLVED = "\x00UNRESOLVED\x00"


@dataclass
class Hit:
    reason: str
    target: str = ""


@dataclass
class _Ctx:
    cwd: str | None
    mentions: bool
    hits: list = field(default_factory=list)
    # T-4149 boundary mode (scan_boundary): `guarded` replaces is_guarded_path, `cd_ok`
    # judges an absolute cd destination, and the extra verbs below are read.
    guarded: Optional[Callable[[str], bool]] = None
    boundary: bool = False
    cd_ok: Optional[Callable[[str], bool]] = None
    depth: int = 0
    # T-3768 read mode (scan_boundary_reads): every path-shaped WORD is judged.
    read_outside: Optional[Callable[[str], bool]] = None
    # T-4487 boundary mode: a git diff-family word that may expand to --output; judged
    # once the whole command is read (refused when the command names a guarded path).
    pending_output: str = ""


# T-4149: bash's `\cX` (control-X) consumes the character after `c` — a quote included —
# so `$'\c''` is ONE string; reading `\c` as a two-character escape ended it early.
_ANSI_C_RE = re.compile(r"\$'((?:[^'\\]|\\c.|\\.)*)'", re.S)


def _ansi_c_value(body: str) -> str:
    body = re.sub(r"\\c(.)", lambda m: chr(ord(m.group(1)) & 0x1F), body, flags=re.S)
    return body.encode("latin-1", "backslashreplace").decode("unicode_escape")


def _decode_ansi_c(text: str) -> str:
    """Decode bash $'...' quoting so `$'\\x2etasks'` is seen as `.tasks`."""
    def dec(m):
        try:
            return _ansi_c_value(m.group(1))
        except Exception:  # noqa: BLE001
            return m.group(1)
    return _ANSI_C_RE.sub(dec, text)


def normalised(command: str) -> str:
    t = _decode_ansi_c(command)
    return t.replace("'", "").replace('"', "").replace("\\", "")


def mentions_guarded(command: str) -> bool:
    return bool(MENTION_RE.search(normalised(command)))


OPERATORS = sorted([";;", "&&", "||", "|&", ">>", "&>>", "&>", ">&", ">|", "<>", "<<-", "<<<", "<<",
                    ";", "&", "|", "(", ")", "<", ">", "\n"], key=len, reverse=True)
_OPSET = set(OPERATORS)
_HEREDOC_RE = re.compile(r"<<-?\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1")


def _strip_heredoc_bodies(cmd: str) -> str:
    """Drop here-document BODIES (kept for the mention check, which reads the raw text).

    A body is data or interpreter code, not shell: tokenising it as shell made an
    apostrophe in a Python comment an "unbalanced quote"."""
    out, pending = [], []
    for line in cmd.split("\n"):
        if pending:
            if line.lstrip("\t") == pending[0]:
                pending.pop(0)
            continue
        out.append(line)
        pending = [m.group(2) for m in _HEREDOC_RE.finditer(line)]
    return "\n".join(out)


# ── T-4149: a lexer that finds what bash EXECUTES ────────────────────────────
# _strip_heredoc_bodies and _substitutions are line/regex scans: a `<<EOF` inside a
# comment or a quoted string fakes a heredoc and hides the real lines after it, and a
# `$(...)` inside single quotes or a QUOTED heredoc body is treated as executed. The
# boundary hook cannot afford either error (it has no "mentions" gate to absorb the
# false positives), so this walks the text with bash's quoting rules: single quotes,
# $'...', double quotes, backslashes, comments, heredocs (operator → body after the next
# newline, quoted delimiter = literal body), $(...), `...`, <(...)/>(...), ${...},
# $((...)) and ((...)). It returns the heredoc BODY spans (data, to be blanked) and the
# spans of every command-substitution body bash would run. Unterminated quoting or
# substitution raises ParseError — the caller fails closed.

class ParseError(Exception):
    pass


_WORD_BREAK = set(" \t\n;&|()<>")


def _lex_spans(s: str) -> tuple[list, list]:
    removed: list = []
    subs: list = []
    _lex(s, 0, None, removed, subs)
    return removed, subs


def _skip_squote(s, i):
    j = s.find("'", i)
    if j < 0:
        raise ParseError("unterminated single quote")
    return j + 1


def _skip_ansi(s, i):
    n = len(s)
    while i < n:
        if s[i] == "\\":
            i += 3 if s.startswith("\\c", i) else 2      # `\cX` takes X, even a quote
        elif s[i] == "'":
            return i + 1
        else:
            i += 1
    raise ParseError("unterminated $'...'")


def _sub(s, i, removed, subs):
    """i = first char of a $(...)/<(...) body. Returns the index after the closing `)`."""
    end = _lex(s, i, ")", removed, subs)
    subs.append((i, end))
    return end + 1


def _backtick(s, i, removed, subs):
    end = _lex(s, i, "`", removed, subs)
    subs.append((i, end))
    return end + 1


def _arith(s, i, removed, subs):
    """i = after `$((` / `((`. Returns the index after the closing `))`."""
    n, depth = len(s), 0
    while i < n:
        if s.startswith("$(", i) and not s.startswith("$((", i):
            i = _sub(s, i + 2, removed, subs)
            continue
        c = s[i]
        if c == "(":
            depth += 1
        elif c == ")":
            if depth == 0:
                if i + 1 < n and s[i + 1] == ")":
                    return i + 2
                raise ParseError("unbalanced arithmetic")
            depth -= 1
        i += 1
    raise ParseError("unterminated arithmetic")


def _param(s, i, removed, subs):
    """i = after `${`. Returns the index after the matching `}`."""
    n, depth = len(s), 1
    while i < n:
        c = s[i]
        if c == "\\":
            i += 2
        elif c == "'":
            i = _skip_squote(s, i + 1)
        elif c == '"':
            i = _dquote(s, i + 1, removed, subs)
        elif c == "`":
            i = _backtick(s, i + 1, removed, subs)
        elif s.startswith("$((", i):
            i = _arith(s, i + 3, removed, subs)
        elif s.startswith("$(", i):
            i = _sub(s, i + 2, removed, subs)
        elif s.startswith("${", i):
            depth += 1
            i += 2
        elif c == "}":
            depth -= 1
            i += 1
            if depth == 0:
                return i
        else:
            i += 1
    raise ParseError("unterminated ${...}")


def _dollar(s, i, removed, subs):
    """s[i] == '$' in a context where substitutions run. Returns the next index."""
    if s.startswith("$((", i):
        return _arith(s, i + 3, removed, subs)
    if s.startswith("$(", i):
        return _sub(s, i + 2, removed, subs)
    if s.startswith("${", i):
        return _param(s, i + 2, removed, subs)
    return i + 1


def _dquote(s, i, removed, subs):
    """i = after the opening `"`. Returns the index after the closing `"`."""
    n = len(s)
    while i < n:
        c = s[i]
        if c == "\\":
            i += 2
        elif c == '"':
            return i + 1
        elif c == "`":
            i = _backtick(s, i + 1, removed, subs)
        elif c == "$":
            i = _dollar(s, i, removed, subs)
        else:
            i += 1
    raise ParseError("unterminated double quote")


def _heredoc_op(s, i):
    """i = after `<<`. Returns (next index, (delimiter, strip_tabs, quoted))."""
    n = len(s)
    strip = i < n and s[i] == "-"
    if strip:
        i += 1
    while i < n and s[i] in " \t":
        i += 1
    word, quoted = [], False
    while i < n and s[i] not in _WORD_BREAK:
        c = s[i]
        if c == "'":
            j = _skip_squote(s, i + 1)
            word.append(s[i + 1:j - 1])
            quoted, i = True, j
        elif c == '"':
            j = s.find('"', i + 1)
            if j < 0:
                raise ParseError("unterminated heredoc delimiter")
            word.append(s[i + 1:j])
            quoted, i = True, j + 1
        elif c == "\\" and i + 1 < n:
            word.append(s[i + 1])
            quoted, i = True, i + 2
        else:
            word.append(c)
            i += 1
    if not word:
        raise ParseError("heredoc operator without a delimiter")
    return i, ("".join(word), strip, quoted)


def _heredoc_body(s, i, hd, removed, subs):
    """i = first char of the body. Blanks body + terminator line; returns the index after."""
    delim, strip, quoted = hd
    n, start, j = len(s), i, i
    while j <= n:
        e = s.find("\n", j)
        e = n if e < 0 else e
        line = s[j:e]
        if (line.lstrip("\t") if strip else line) == delim:
            body_end, after = j, min(e + 1, n)
            break
        if e >= n:
            body_end, after = n, n
            break
        j = e + 1
    else:
        body_end, after = n, n
    # blank the BODY only: the terminator line stays, so blanked text still lexes
    # (a stray delimiter word in command position writes nothing)
    removed.append((start, body_end))
    if not quoted:  # an unquoted body expands $(...), `...`, ${...}
        k = start
        while k < body_end:
            c = s[k]
            if c == "\\":
                k += 2
            elif c == "`":
                k = _backtick(s, k + 1, removed, subs)
            elif c == "$":
                k = _dollar(s, k, removed, subs)
            else:
                k += 1
    return after


def _lex(s, i, stop, removed, subs):
    """Walk shell text from i. stop: None (end of text), ')' or '`'. Returns the index of
    the stop character."""
    n, pending, paren = len(s), [], 0
    while i < n:
        c = s[i]
        if stop == "`" and c == "`":
            return i
        if c == "\\":
            i += 2
        elif c == "'":
            i = _skip_squote(s, i + 1)
        elif s.startswith("$'", i):
            i = _skip_ansi(s, i + 2)
        elif c == '"':
            i = _dquote(s, i + 1, removed, subs)
        elif c == "`":
            i = _backtick(s, i + 1, removed, subs)
        elif c == "$":
            i = _dollar(s, i, removed, subs)
        elif c in "<>" and i + 1 < n and s[i + 1] == "(":
            i = _sub(s, i + 2, removed, subs)          # process substitution
        elif c == "#" and (i == 0 or s[i - 1] in _WORD_BREAK):
            j = s.find("\n", i)
            i = n if j < 0 else j
        elif s.startswith("((", i) and (i == 0 or s[i - 1] in _WORD_BREAK):
            i = _arith(s, i + 2, removed, subs)        # arithmetic command: `<<` is a shift
        elif s.startswith("<<<", i):
            i += 3
        elif s.startswith("<<", i):
            i, hd = _heredoc_op(s, i + 2)
            pending.append(hd)
        elif c == "\n":
            i += 1
            for hd in pending:
                i = _heredoc_body(s, i, hd, removed, subs)
            pending = []
        elif stop == ")" and c == "(":
            paren += 1
            i += 1
        elif stop == ")" and c == ")":
            if paren == 0:
                return i
            paren -= 1
            i += 1
        else:
            i += 1
    if stop is not None:
        raise ParseError(f"unterminated {'$(' if stop == ')' else '`'}")
    return n


def _blank(s: str, spans) -> str:
    out = list(s)
    for a, b in spans:
        for k in range(a, min(b, len(out))):
            if out[k] != "\n":
                out[k] = " "
    return "".join(out)


def executed_texts(command: str) -> list[str]:
    """The command with heredoc bodies blanked, then every substitution body bash would
    run (bodies blanked inside them too). Raises ParseError when the text does not lex."""
    removed, subs = _lex_spans(command)
    out = [_blank(command, removed)]
    for a, b in subs:
        # blank only the heredoc bodies NESTED in this piece: a $(...) that sits in an
        # unquoted heredoc body lies inside that body's span and must stay readable
        inner = [(x - a, y - a) for x, y in removed if a <= x and y <= b]
        out.append(_blank(command[a:b], inner))
    return out


def _tokens(command: str, strip_heredocs: bool = True, masks: list | None = None) -> list[str] | None:
    """Bash-style words and operators. Operators are bare (`>`, `|`, ...); words are
    dequoted. A QUOTED word that spells an operator (`grep '>' f`, `grep -e'>' f`) is
    prefixed with NUL so it is never read as one (T-3695 review rounds 1-2 — shlex could
    not tokenise a quote attached to an option). None when a quote is unterminated.

    T-4149: strip_heredocs=False when the caller already blanked bodies with the lexer;
    `masks`, when given, receives one string per token: 'u' for each unquoted character,
    'q' for each quoted or escaped one (brace expansion only applies to unquoted text),
    'd' for a `$` that expands inside double quotes (T-4512)."""
    cmd = _strip_heredoc_bodies(command) if strip_heredocs else command
    cmd = _decode_ansi_c_quoted(cmd).replace("`", "\n")
    out: list[str] = []
    buf: list[str] = []
    mbuf: list[str] = []
    inword = False
    i, n = 0, len(cmd)

    def emit(tok, mask):
        out.append(tok)
        if masks is not None:
            masks.append(mask)

    def flush():
        nonlocal buf, mbuf, inword
        if inword:
            w = "".join(buf)
            m = "".join(mbuf)
            if w in _OPSET:
                emit("\x00" + w, "q" * (len(w) + 1))
            else:
                emit(w, m)
        buf, mbuf, inword = [], [], False

    while i < n:
        c = cmd[i]
        if c in " \t\r":
            flush()
            i += 1
        elif c == "#" and not inword:
            # a comment runs to end of line (`cat F # don't edit` — review round 3)
            j = cmd.find("\n", i)
            i = n if j < 0 else j
        elif c == "\\":
            if i + 1 < n and cmd[i + 1] == "\n":
                i += 2
                continue
            ch = cmd[i + 1] if i + 1 < n else ""
            buf.append(ch)
            mbuf.append("q" * len(ch))
            inword, i = True, i + 2
        elif c == "'":
            j = cmd.find("'", i + 1)
            if j < 0:
                return None
            buf.append(cmd[i + 1:j])
            mbuf.append("q" * (j - i - 1))
            inword, i = True, j + 1
        elif c == '"':
            # T-4512: pm marks a `$` that EXPANDS inside the quotes 'd' (one word, content
            # unknown); every other quoted character is 'q'.
            j, part, pm = i + 1, [], []
            while j < n and cmd[j] != '"':
                if cmd[j] == "\\" and j + 1 < n and cmd[j + 1] in '"\\$`\n':
                    part.append(cmd[j + 1])
                    pm.append("q")
                    j += 2
                elif cmd.startswith(("$(", "${"), j) and not cmd.startswith("$((", j):
                    # T-4149: a nested "$(cmd "x")" / "${v:-"x"}" is one unit — its inner
                    # quotes do not end this word (the body is read separately)
                    try:
                        e = (_sub(cmd, j + 2, [], []) if cmd[j + 1] == "("
                             else _param(cmd, j + 2, [], []))
                    except ParseError:
                        return None
                    part.append(cmd[j:e])
                    pm.append("d" + "q" * (e - j - 1))
                    j = e
                else:
                    part.append(cmd[j])
                    pm.append("d" if cmd[j] == "$" and j + 1 < n and _EXPANDS.match(cmd[j + 1]) else "q")
                    j += 1
            if j >= n:
                return None
            p = "".join(part)
            buf.append(p)
            mbuf.append("".join(pm))
            inword, i = True, j + 1
        else:
            op = next((o for o in OPERATORS if cmd.startswith(o, i)), None)
            if op:
                flush()
                emit(op, "u" * len(op))
                i += len(op)
            else:
                buf.append(c)
                mbuf.append("u")
                inword, i = True, i + 1
    flush()
    return out


# T-4367: git's diff-family verbs take --output[=FILE] (any unambiguous prefix of the
# long option), which WRITES FILE although the verb is a read.
GIT_OUTPUT_VERBS = frozenset({"diff", "log", "show", "diff-tree", "diff-index", "whatchanged"})
_GIT_OUTPUT_RE = re.compile(r"^--ou(?:t(?:p(?:u(?:t)?)?)?)?(?:=(.*))?$")


def git_output_risk(command: str) -> str | None:
    """Why `git <verb> args...` (global options already skipped) may write a file via
    --output, or None. T-4485: the read-only allowlist (agents/context/lib/safe-commands.sh)
    matched raw words, so quotes, a backslash, $var or ${p:-default} hid the option. This
    judges the words bash hands git: dequoted, ANSI-C decoded, brace-expanded. An expansion
    whose result the text does not fix ($, a backtick, an unquoted glob) fails closed."""
    if "`" in command:
        return "backtick substitution"
    masks: list[str] = []
    toks = _tokens(command, masks=masks)
    if toks is None:
        return "does not tokenise"
    words = [(t, m) for t, m in zip(toks, masks) if t not in _OPSET]
    if len(words) < 2 or words[0][0] != "git" or words[1][0] not in GIT_OUTPUT_VERBS:
        return None
    for w, m in words[2:]:
        if "$" in w:
            return "an argument is expanded by the shell ($)"
        for e, em in _brace_expand(w, m):
            if any(c in "*?[" and em[k] == "u" for k, c in enumerate(e)):
                return "an unquoted glob"
            u = "".join(c for k, c in enumerate(e) if em[k] == "u")
            if "{" in u and ("," in u or ".." in u):
                return "a brace expression not expanded from the text"
            if _GIT_OUTPUT_RE.match(e.lstrip("\x00")):
                return "--output writes a file"
    return None


_EXPANDS = re.compile(r"[A-Za-z_0-9{(@*#?$!-]")
# The framework's own documented idiom (CLAUDE.md §Watchtower Port): its output is a URL.
_WATCHTOWER_URL_SUB = re.compile(r"\$\((?:bin/fw|fw|\.agentic-framework/bin/fw) watchtower url\)")


def option_words(command: str) -> tuple[list[tuple[str, str]] | None, str | None]:
    """T-4512: the words bash hands the program, for an option check on ONE simple
    command. The read-only allowlist (agents/context/lib/safe-commands.sh) matched raw
    or quote-stripped words, so `find . -'exec'` and `curl -'o' F` hid the option.
    Words are dequoted, ANSI-C decoded and brace-expanded, each with a kind:
      'L'  literal: exactly this word reaches the program
      'E'  one word that BEGINS with a quoted expansion ("$X", "$(cmd)/x"): its
           content is unknown, so it may be an option
    A quoted expansion after a literal first character (`"Bearer $T"`) is 'L': whatever
    it expands to, the word cannot start with `-`. Returns (None, reason) for what the
    text cannot resolve: a backtick, an unquoted $ (may split into several words), an
    unquoted glob, a brace expression left unexpanded, an unterminated quote."""
    if "`" in command:
        return None, "backtick substitution"
    masks: list[str] = []
    toks = _tokens(command, masks=masks)
    if toks is None:
        return None, "does not tokenise"
    out: list[tuple[str, str]] = []
    for t, m in zip(toks, masks):
        if t in _OPSET:
            continue
        if t.startswith("\x00"):
            t, m = t[1:], m[1:]
        for e, em in _brace_expand(t, m):
            u = "".join(c for k, c in enumerate(e) if em[k] == "u")
            if "$" in u:
                return None, "an unquoted expansion ($) may split into several words"
            if any(c in "*?[" for c in u):
                return None, "an unquoted glob"
            if "{" in u and ("," in u or ".." in u):
                return None, "a brace expression not expanded from the text"
            kind = "L"
            if em[:1] == "d":
                kind = "E"
                mt = _WATCHTOWER_URL_SUB.match(e)
                if mt and "d" not in em[mt.end():]:
                    e, kind = "http://watchtower" + e[mt.end():], "L"
            out.append((e, kind))
    return out, None


def _decode_ansi_c_quoted(text: str) -> str:
    """Like _decode_ansi_c, but re-quote the decoded text so it stays ONE word."""
    def dec(m):
        try:
            s = _ansi_c_value(m.group(1))
        except Exception:  # noqa: BLE001
            s = m.group(1)
        return "'" + s.replace("'", "'\\''") + "'"
    return _ANSI_C_RE.sub(dec, text)


def _segments(tokens: list[str]) -> list[list[str]]:
    segs, cur = [], []
    for t in tokens:
        if t in SEPARATORS or (t and set(t) <= set(";&|()\n") and t not in REDIRECT_WRITE):
            if cur:
                segs.append(cur)
            cur = []
            continue
        cur.append(t)
    if cur:
        segs.append(cur)
    return segs


def is_guarded_path(path: str) -> bool:
    parts = path.replace("\\", "/").split("/")
    return ".tasks" in parts or os.path.basename(path) == LEDGER_NAME


def _provably_outside(path: str, root: str) -> bool:
    """T-4336: True only when `path` is absolute and lies outside `root` (a realpath).

    A relative path, or one under `root`, is NOT provably outside, so it stays guarded.
    """
    if not os.path.isabs(path):
        return False
    return not (path == root or path.startswith(root.rstrip("/") + "/"))


def _guarded_within(root: str) -> Callable[[str], bool]:
    """T-4336: the guard for a project at `root`. A `.tasks` path only counts when it is
    not provably outside the project. The ledger name stays guarded everywhere, as the
    Write/Edit leg already does, so the Bash leg is never more permissive than that one."""
    def guarded(path: str) -> bool:
        if os.path.basename(path) == LEDGER_NAME:
            return True
        parts = path.replace("\\", "/").split("/")
        return ".tasks" in parts and not _provably_outside(path, root)
    return guarded


def _resolve(target: str, ctx: _Ctx) -> tuple[bool, list[str]]:
    """(resolved?, absolute paths). Unresolvable → (False, [])."""
    if target == UNRESOLVED or not target:
        return False, []
    if target.startswith("\x00"):
        return True, []  # a quoted operator spelling (e.g. `\;`), not a path
    t = target
    if t.startswith("~"):
        t = os.path.expanduser(t)
    if re.search(r"[$`{}]", t) or t.startswith("~"):
        return False, []
    if not os.path.isabs(t):
        if ctx.cwd is None:
            return False, []
        t = os.path.join(ctx.cwd, t)
    if re.search(r"[*?\[]", t):
        matches = glob.glob(t)
        if ctx.boundary:
            # T-4149: the literal pattern is judged too (no match = bash keeps it literal)
            return True, [os.path.realpath(m) for m in matches] + matches + [os.path.normpath(t)]
        if not matches:
            return False, []
        return True, [os.path.realpath(m) for m in matches] + matches
    if ctx.boundary and os.path.normpath(t).startswith("/dev/"):
        # /dev/stderr, /dev/fd/N resolve through /proc to a pipe or pty: judge the name
        return True, [os.path.normpath(t)]
    return True, [os.path.realpath(t), os.path.normpath(t)]


def _check_target(target: str, ctx: _Ctx, reason: str) -> None:
    ok, paths = _resolve(target, ctx)
    if ok:
        if any((ctx.guarded or is_guarded_path)(p) for p in paths):
            ctx.hits.append(Hit(reason, target))
    elif ctx.mentions:
        ctx.hits.append(Hit(reason + " (target not resolvable from the text; command names a "
                            "guarded path)", target if target != UNRESOLVED else "<operands from stdin>"))


def _strip_redirects(seg: list[str], ctx: _Ctx) -> list[str]:
    argv, i = [], 0
    while i < len(seg):
        t = seg[i]
        if t in REDIRECT_WRITE:
            nxt = seg[i + 1] if i + 1 < len(seg) else ""
            if t == ">&" and (nxt.isdigit() or nxt == "-"):
                i += 2
                continue
            if nxt and nxt != "(":
                _check_target(nxt, ctx, f"redirect {t}")
            i += 2
            continue
        if t in ("<", "<<", "<<-", "<<<") or (t.startswith("<") and set(t) <= set("<>&-")):
            i += 2
            continue
        if re.fullmatch(r"\d+", t) and i + 1 < len(seg) and seg[i + 1] in REDIRECT_WRITE | {"<", "<<"}:
            i += 1
            continue
        argv.append(t)
        i += 1
    return argv


def _unwrap(argv: list[str]) -> tuple[list[str], bool]:
    """Skip assignments and wrappers. Returns (argv, fed_by_xargs)."""
    xargs = False
    while argv:
        a = argv[0]
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", a):
            argv = argv[1:]
            continue
        base = os.path.basename(a)
        if base in ("xargs", "parallel"):
            xargs = True
            argv = argv[1:]
            while argv and argv[0].startswith("-"):
                opt = argv[0]
                argv = argv[1:]
                if opt in ("-I", "-L", "-n", "-P", "-d", "-E", "-s", "-a") and argv:
                    argv = argv[1:]
            continue
        if base in WRAPPERS:
            argv = argv[1:]
            while argv and (argv[0].startswith("-") or re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", argv[0])):
                opt = argv[0]
                argv = argv[1:]
                if base in ("sudo", "env", "su", "runuser") and opt in ("-u", "-g", "-C", "-c") and argv:
                    if base in ("su", "runuser") and opt == "-c":
                        argv = ["sh", "-c"] + argv
                        break
                    argv = argv[1:]
            n = WRAPPER_ARGC.get(base, 0)
            if n and argv and not argv[0].startswith("-"):
                argv = argv[n:]
            continue
        break
    return argv, xargs


def _operands(args: list[str], takes_value: "set[str] | frozenset[str]" = frozenset()) -> list[str]:
    out, i, end = [], 0, False
    while i < len(args):
        a = args[i]
        if not end and a == "--":
            end = True
        elif not end and a.startswith("-") and a != "-":
            if a in takes_value:
                i += 1
        else:
            out.append(a)
        i += 1
    return out


_SED_ADDR = r"(?:\d+(?:~\d+)?|\$|/(?:[^/\\]|\\.)*/[IM]*|\\(.)(?:(?!\1).)*\1)"
SED_WRITE_RE = re.compile(
    rf"(?:^|[;{{}}\n])\s*(?:{_SED_ADDR}(?:\s*,\s*(?:{_SED_ADDR}|[+~]\d+))?)?\s*!?\s*[wWe](?:\s|$|;)"
    r"|/[gpiImMe0-9]*[we](?:\s|$|;|})")


def _is_long(name: str, full: str) -> bool:
    """`--name` is an abbreviation GNU getopt_long would accept for `--full`."""
    return bool(name) and full.startswith(name)


def _parse_sed(args: list[str]) -> tuple[bool, list[str], bool, list[str]]:
    """(in-place?, -e scripts, -f given?, operands) — GNU option clustering honoured.

    `-i[SUF]` swallows the rest of its cluster as a suffix; `-e`/`-f`/`-l` take the rest
    of the cluster or the next word (`-e's/a/b/'` attached — review round 1)."""
    inplace, scripts, script_file, ops = False, [], False, []
    i, end = 0, False
    while i < len(args):
        a = args[i]
        if end or a == "-" or not a.startswith("-"):
            ops.append(a)
        elif a == "--":
            end = True
        elif a.startswith("--"):
            name, eq, val = a[2:].partition("=")
            # GNU getopt_long accepts any unambiguous PREFIX (`--in-plac`, `--expr`) —
            # review round 2. Matched liberally: a prefix of several options counts as each.
            if _is_long(name, "in-place"):
                inplace = True
            if any(_is_long(name, o) for o in ("expression", "file", "line-length")):
                if not eq and i + 1 < len(args):
                    i += 1
                    val = args[i]
                if _is_long(name, "expression"):
                    scripts.append(val)
                if _is_long(name, "file"):
                    script_file = True
        else:
            k = 1
            while k < len(a):
                c = a[k]
                if c == "i":
                    inplace = True
                    break
                if c in "efl":
                    val = a[k + 1:]
                    if not val and i + 1 < len(args):
                        i += 1
                        val = args[i]
                    if c == "e":
                        scripts.append(val)
                    elif c == "f":
                        script_file = True
                    break
                k += 1
        i += 1
    return inplace, scripts, script_file, ops


def _perl_cluster(flag: str) -> tuple[bool, bool]:
    """(in-place?, inline code?) for one perl/ruby short-option cluster. An option that
    takes an argument ends the cluster: `-MFile::Find` is a module, not `-i` (T-4149)."""
    for c in flag[1:]:
        if c == "i":
            return True, False
        if c in "eE":
            return False, True
        if c in "MmIdDxClF0V":
            return False, False
    return False, False


def _inline(ctx: _Ctx, verb: str) -> None:
    if ctx.mentions:
        ctx.hits.append(Hit(f"{verb} runs inline code and the command names a guarded path"))


def _segment(seg: list[str], ctx: _Ctx) -> None:
    argv = _strip_redirects(seg, ctx)
    argv, xargs = _unwrap(argv)
    if not argv:
        return
    verb = os.path.basename(argv[0])
    args = argv[1:] + ([UNRESOLVED] if xargs else [])
    seg_text = " ".join(seg)
    if ctx.boundary and _boundary_segment(argv[0], verb, args, ctx):
        return

    if not ctx.boundary and verb in NETWORK_VERBS and "toggle-ac" in normalised(seg_text):
        ctx.hits.append(Hit("calls the Watchtower toggle-ac endpoint (that IS a tick)"))
        return
    ops = [a for a in args if not a.startswith("-")]
    if not ctx.boundary and \
            any(os.path.basename(a) in ("human_ac_ticks.py", "human_ac_ticks") for a in ops[:2]) and "ack" in ops:
        ctx.hits.append(Hit("records a Human-tick provenance row (the operator's act)"))
        return
    if verb in ("cd", "pushd"):
        dest = next((a for a in args if not a.startswith("-")), None)
        if dest is None or dest == UNRESOLVED or re.search(r"[$`{}*?\[~]", dest) or dest == "-":
            ctx.cwd = None
        elif ctx.cwd is not None or os.path.isabs(dest):
            ctx.cwd = os.path.normpath(os.path.join(ctx.cwd or "/", dest))
        return

    if verb in ("sed", "gsed"):
        inplace, scripts, script_file, ops = _parse_sed(args)
        if not scripts and not script_file and ops:
            scripts, ops = [ops[0]], ops[1:]
        if inplace:
            for t in ops:
                _check_target(t, ctx, "sed -i")
        # sed's own write/execute commands: `w FILE`, `s///w FILE`, `e`, `s///e`
        # (T-3695 review round 1). The file is named inside the script, so it is not
        # resolved here; refused when the command names a guarded path, like inline code.
        if script_file or any(SED_WRITE_RE.search(s) for s in scripts):
            _inline(ctx, "sed (w/e command or -f script)")
        return
    if verb.startswith(("perl", "ruby")):
        flags = [a for a in args if a.startswith("-") and not a.startswith("--")]
        inline = any(_perl_cluster(f)[1] for f in flags)
        if any(_perl_cluster(f)[0] for f in flags):
            ops = _operands(args, {"-e", "-E", "-I", "-M", "-m"})
            if not inline and ops:
                ops = ops[1:]
            for t in ops:
                _check_target(t, ctx, f"{verb} -i")
        if inline or not _operands(args, {"-e", "-E", "-I", "-M", "-m"}):
            _inline(ctx, verb)
        else:
            _script_form(verb, seg_text, ctx)
        return
    if verb in ("awk", "gawk", "mawk", "nawk"):
        if any((a == "-i" or (a.startswith("--") and _is_long(a[2:].partition("=")[0], "include")))
               and "inplace" in (a + " " + (args[k + 1] if k + 1 < len(args) else ""))
               or a.startswith("-iinplace") for k, a in enumerate(args)):
            ops = _operands(args, {"-i", "-f", "-v", "-F", "--include"})
            for t in ops[1:]:
                _check_target(t, ctx, f"{verb} -i inplace")
        prog = next(iter(_operands(args, {"-i", "-f", "-v", "-F", "--include"})), "")
        # awk writes only through print/printf redirection, a pipe to a command, system()
        # or close(); a bare comparison (`NF > 0`) is not one (review round 1).
        # string literals and parenthesised expressions (`print ($1 > 0)`) cannot redirect
        bare = re.sub(r'"(?:[^"\\]|\\.)*"', '""', prog)
        while re.search(r"\([^()]*\)", bare):
            bare = re.sub(r"\([^()]*\)", " 0", bare)
        if re.search(r"\bprintf?\b[^;{}]*(>|\|)|\bsystem\s*\(|\|\s*getline|\bclose\s*\(", prog) and \
                re.search(r"\bprintf?\b[^;{}]*(>|\|)|\bsystem\b|\|\s*getline|\bclose\b", bare):
            _inline(ctx, verb)
        return
    if verb in ("tee", "sponge"):
        for t in _operands(args):
            _check_target(t, ctx, verb)
        return
    if verb in ("sort", "gsort", "shuf", "uniq"):
        for k, a in enumerate(args):
            name, eq, val = a[2:].partition("=") if a.startswith("--") else ("", "", "")
            if (a == "-o" or (_is_long(name, "output") and not eq)) and k + 1 < len(args):
                _check_target(args[k + 1], ctx, f"{verb} -o")
            elif _is_long(name, "output") and eq:
                _check_target(val, ctx, f"{verb} -o")
            elif re.match(r"^-[a-zA-Z]*o.+", a) and verb != "uniq":
                _check_target(a[a.index("o") + 1:], ctx, f"{verb} -o")
        if verb == "uniq":
            ops = _operands(args, {"-f", "-s", "-w"})
            if len(ops) >= 2:
                _check_target(ops[1], ctx, "uniq OUTPUT")
        return
    if verb in ("rsync", "patch") and any(
            (a.startswith("--") and _is_long(a[2:].partition("=")[0], "dry-run") and len(a) > 4)
            or (verb == "rsync" and re.match(r"^-[a-zA-Z]*n", a)) for a in args):
        return  # --dry-run / rsync -n writes nothing (review round 3)
    if verb in COPY_FAMILY:
        tval = {"-t", "--target-directory", "-S", "--suffix", "-m", "--mode", "-o", "--owner",
                "-g", "--group", "-e", "--exclude", "--include", "-f", "--filter"}
        for k, a in enumerate(args):
            name, eq, val = a[2:].partition("=") if a.startswith("--") else ("", "", "")
            if (a == "-t" or (_is_long(name, "target-directory") and not eq)) and k + 1 < len(args):
                _check_target(args[k + 1], ctx, f"{verb} -t")
                return
            if a.startswith("-t") and len(a) > 2 and not a.startswith("--"):
                _check_target(a[2:], ctx, f"{verb} -t")
                return
            if _is_long(name, "target-directory") and eq:
                _check_target(val, ctx, f"{verb} -t")
                return
        ops = _operands(args, tval)
        if ops:
            _check_target(ops[-1], ctx, f"{verb} destination")
            if verb == "ln":
                for t in ops[:-1]:
                    _check_target(t, ctx, "ln source (a link to a guarded file)")
        return
    if verb == "dd":
        for a in args:
            if a.startswith("of="):
                _check_target(a[3:], ctx, "dd of=")
        return
    if verb == "view" and not any(a in ("-c", "-s", "-es", "-e", "--cmd", "-S") or a.startswith("+") for a in args):
        return  # read-only vim; only its command options can write
    if verb in EDITORS:
        for t in _operands(args, {"-c", "-S", "-u", "-i", "-s", "-e", "--cmd"}):
            _check_target(t, ctx, f"editor {verb}")
        if verb in ("ed", "red", "ex") or any(a in ("-c", "-s", "-es", "-e", "--cmd", "-S") or a.startswith("+") for a in args):
            _inline(ctx, verb)
        return
    if verb == "patch":
        ops = _operands(args, {"-i", "--input", "-o", "--output", "-p", "-d", "-D", "-B", "-z", "-r"})
        for k, a in enumerate(args):
            if a in ("-o", "--output", "-d") and k + 1 < len(args):
                _check_target(args[k + 1], ctx, f"patch {a}")
        if ops:
            _check_target(ops[0], ctx, "patch")
        else:
            _check_target(UNRESOLVED, ctx, "patch (file named inside the diff)")
        return
    if verb == "git":
        rest = args[:]
        while rest and rest[0].startswith("-"):
            opt = rest.pop(0)
            if opt in ("-C", "-c", "--git-dir", "--work-tree", "--namespace") and rest:
                rest.pop(0)
        sub = rest[0] if rest else ""
        # T-4367: --output[=FILE] (any unambiguous long-option prefix) writes FILE
        if sub in GIT_OUTPUT_VERBS:
            # T-4485: judge the words bash hands git. Braces are expanded (quoted ones
            # too: over-expanding only adds candidates); a $ or backtick means the word
            # is not known from the text; a glob is matched against the cwd.
            words = []
            for a in rest[1:]:
                if "$" in a or "`" in a:
                    _check_target(UNRESOLVED, ctx, f"git {sub} (an expanded argument may be --output)")
                    lit = re.split(r"[$`]", a, 1)[0]   # T-4487: may this word be --output[=…]?
                    if ctx.boundary and ("--output".startswith(lit) or
                                         ("=" in lit and _GIT_OUTPUT_RE.match(lit))):
                        ctx.pending_output = ctx.pending_output or f"git {sub} {a}"
                for e, _m in _brace_expand(a, "u" * len(a)):
                    if re.search(r"[*?\[]", e):
                        if ctx.cwd is None:
                            _check_target(UNRESOLVED, ctx, f"git {sub} (a glob may expand to --output)")
                        else:
                            words += [os.path.relpath(g, ctx.cwd) for g in glob.glob(os.path.join(ctx.cwd, e))]
                    words.append(e)
            rest = rest[:1] + words
            for k, a in enumerate(rest[1:], 1):
                m = _GIT_OUTPUT_RE.match(a)
                if m:
                    if m.group(1) is not None:
                        _check_target(m.group(1), ctx, f"git {sub} {a.split('=')[0]}")
                    elif k + 1 < len(rest):
                        _check_target(rest[k + 1], ctx, f"git {sub} {a}")
                    else:
                        _check_target(UNRESOLVED, ctx, f"git {sub} {a}")
        if sub in ("checkout", "restore", "apply", "am", "stash", "switch", "reset") and \
                not ctx.boundary and MENTION_RE.search(normalised(seg_text)):
            ctx.hits.append(Hit(f"git {sub} names a guarded path (writes it from another revision/patch)"))
        elif sub in ("apply", "am"):
            _check_target(UNRESOLVED, ctx, f"git {sub} (paths named inside the patch)")
        return
    if verb == "find":
        for k, a in enumerate(args):
            if a in ("-fprint", "-fprint0", "-fprintf", "-fls") and k + 1 < len(args):
                _check_target(args[k + 1], ctx, f"find {a}")
            if a in ("-exec", "-execdir", "-ok", "-okdir"):
                inner = []
                for b in args[k + 1:]:
                    if b.lstrip("\x00") in (";", "+", "\\;"):
                        break
                    inner.append(UNRESOLVED if "{}" in b else b)
                if inner:
                    _segment(inner, ctx)
        return
    if verb in EXTRACTORS:
        flags = "".join(x.lstrip("-") for x in args if x.startswith("-")) + (args[0] if args and verb in ("tar", "bsdtar") and not args[0].startswith("-") else "")
        extracting = ((verb == "unzip" and not re.search(r"[lvtZpz]", flags)) or verb == "busybox" or ("x" in flags if verb in ("tar", "bsdtar", "7z", "7za") else "i" in flags)
                      or any(x in ("--extract", "--get") or (verb in ("7z", "7za") and x in ("x", "e")) for x in args))
        if extracting and not ctx.boundary and MENTION_RE.search(normalised(seg_text)):
            ctx.hits.append(Hit(f"{verb} extracts into a guarded path"))
        return
    if verb in ("eval", "source", "."):
        _inline(ctx, verb)
        return
    if INTERPRETERS.match(verb):
        flags = [a for a in args if a.startswith("-")]
        code_flag = {"-c"} if re.match(r"^(python|pypy|bash|sh|zsh|dash|ksh|mksh|fish|busybox)", verb) else {"-e", "-E", "-r", "-p", "--eval", "--print"}
        inline = any(f in code_flag or (len(f) > 1 and f[1:].isalpha() and set(code_flag) & {"-" + c for c in f[1:]})
                     for f in flags)
        ops = [a for a in args if not a.startswith("-")]
        if inline or not ops or ops[0] == "-" or verb in ("jq", "yq", "sqlite3"):
            _inline(ctx, verb)
        else:
            _script_form(verb, seg_text, ctx)
        return


# ── T-4149 boundary mode: verbs the project-boundary hook reads beyond T-3695's set ──
# Every operand is written (created, removed, re-moded) by these; options that take a
# value are skipped so the value is not mistaken for a target.
_ALL_OPERANDS = {
    "touch": {"-d", "-t", "-r", "--date", "--reference"},
    "mkdir": {"-m", "--mode"},
    "mkfifo": {"-m", "--mode"},
    "truncate": {"-s", "--size", "-r", "--reference"},
    "rm": set(), "rmdir": set(), "unlink": set(),
    "shred": {"-n", "-s", "--iterations", "--size"},
}
_MODE_FIRST = {"chmod", "chown", "chgrp"}        # first operand is the mode/owner
_SHELLS = re.compile(r"^(bash|sh|dash|zsh|ksh|mksh|ash|busybox)$")
_COPY_TVAL = {"-t", "--target-directory", "-S", "--suffix", "-m", "--mode", "-o", "--owner",
              "-g", "--group", "-e", "--exclude", "--include", "-f", "--filter"}


def _boundary_segment(exe: str, verb: str, args: list[str], ctx: _Ctx) -> bool:
    """True when the segment is fully handled here; False to continue with _segment."""
    if verb in ("cd", "pushd"):
        dest = next((a for a in args if not a.startswith("-")), None)
        if dest is None:
            ctx.cwd = os.path.expanduser("~")       # bare cd goes HOME
            return True
        if dest.startswith("/") and ctx.cd_ok is not None and not re.search(r"[$`]", dest):
            norm = os.path.normpath(dest)
            if not ctx.cd_ok(norm):
                ctx.hits.append(Hit(f"cd to {norm}", dest))
        return False                                # cwd tracking stays in _segment
    if exe.startswith("/") and os.path.normpath(exe).endswith("/.agentic-framework/bin/fw"):
        root = os.path.normpath(exe)[: -len("/.agentic-framework/bin/fw")] or "/"
        if ctx.cd_ok is not None and not ctx.cd_ok(root):
            ctx.hits.append(Hit(f"fw of another project ({root})", exe))
        return True
    if verb in _ALL_OPERANDS:
        for t in _operands(args, _ALL_OPERANDS[verb]):
            _check_target(t, ctx, verb)
        return True
    if verb == "mknod":
        ops = _operands(args, {"-m", "--mode"})
        if ops:
            _check_target(ops[0], ctx, verb)
        return True
    if verb in _MODE_FIRST:
        ops = _operands(args, {"--reference"})
        ref = any(a.startswith("--reference") for a in args)
        for t in (ops if ref else ops[1:]):
            _check_target(t, ctx, verb)
        return True
    if verb == "mv":                                # a move removes every source
        for t in _operands(args, _COPY_TVAL):
            _check_target(t, ctx, "mv")
        return False                                # -t DIR / destination: copy family
    if verb == "install" and any(re.match(r"^-[a-zA-Z]*d", a) or a == "--directory" for a in args):
        for t in _operands(args, _COPY_TVAL):
            _check_target(t, ctx, "install -d")
        return True
    if verb == "ln":                                # a link SOURCE is not a write
        ops = _operands(args, _COPY_TVAL)
        tdir = [a for a in args if a.startswith(("-t", "--target-directory"))]
        if ops and not tdir:
            _check_target(ops[-1], ctx, "ln destination")
            return True
        return False
    if ctx.depth < 4 and (_SHELLS.match(verb) or verb == "eval"):
        script = None
        if verb == "eval":
            script = " ".join(args)
        else:
            k, has_c = 0, False
            while k < len(args):
                a = args[k]
                if a in ("-o", "+o", "-O", "+O"):
                    k += 2
                    continue
                if a == "--":
                    k += 1
                    break
                if a.startswith(("-", "+")) and not a.startswith("--") and len(a) > 1:
                    has_c = has_c or "c" in a[1:]
                    k += 1
                    continue
                if a.startswith("--"):
                    k += 1
                    continue
                break
            if has_c and k < len(args):
                script = args[k]
        if script is not None and script != UNRESOLVED:
            _scan_boundary_text(script, ctx)
        return False                                # still an interpreter for _segment
    return False


def _script_form(verb: str, seg_text: str, ctx: _Ctx) -> None:
    """`python3 tool.py ARGS`: the script is not opened (residual); its ARGUMENTS are seen."""
    if not ctx.boundary and MENTION_RE.search(normalised(seg_text)):
        ctx.hits.append(Hit(f"{verb} script is handed a guarded path (the script itself is not inspected)"))


# T-4499: argument values that are a message, not shell. `_tokens` turns every backtick
# into a command break and `_substitutions` reads `$(...)`/`` `...` `` even inside single
# quotes, so a peer message quoting `git log --output="$F"` was scanned as a git command.
# Only a SINGLE-quoted value is data: in double quotes bash runs the substitutions itself.
_DATA_ARGS = {("sidecar", "send"): {"--body"}}
_FW_VERB = re.compile(r"^(?:\S*/)?fw$")


def _top_words(s: str) -> list[list[tuple[int, int, str]]]:
    """Top-level words of `s` as (start, end, raw) grouped into simple commands, walked with
    the lexer's own quoting rules. Raises ParseError on a heredoc or unbalanced text."""
    segs, i, n, start = [[]], 0, len(s), None
    while i < n:
        c = s[i]
        if c in " \t\r" or c in ";&|()\n<>":
            if start is not None:
                segs[-1].append((start, i, s[start:i]))
                start = None
            if c in ";&|()\n":
                segs.append([])
            elif c in "<>":
                if s.startswith("<<", i) and not s.startswith("<<<", i):
                    raise ParseError("heredoc")
            i += 1
            continue
        if c == "#" and start is None:
            j = s.find("\n", i)
            i = n if j < 0 else j
            continue
        if start is None:
            start = i
        if c == "\\":
            i += 2
        elif c == "'":
            i = _skip_squote(s, i + 1)
        elif s.startswith("$'", i):
            i = _skip_ansi(s, i + 2)
        elif c == '"':
            i = _dquote(s, i + 1, [], [])
        elif c == "`":
            i = _backtick(s, i + 1, [], [])
        elif c == "$":
            i = _dollar(s, i, [], [])
        else:
            i += 1
    if start is not None:
        segs[-1].append((start, n, s[start:n]))
    return [seg for seg in segs if seg]


def _blank_data_args(command: str) -> str:
    """`command` with the interior of each single-quoted data argument (_DATA_ARGS) blanked."""
    try:
        segs = _top_words(command)
    except ParseError:
        return command
    spans = []
    for seg in segs:
        k = 0
        while k < len(seg) and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", seg[k][2]):
            k += 1
        raw = [w[2] for w in seg[k:]]
        if len(raw) < 3 or not _FW_VERB.match(raw[0]):
            continue
        opts = _DATA_ARGS.get((raw[1], raw[2]))
        if not opts:
            continue
        for j in range(k + 3, len(seg)):
            a, b, w = seg[j]
            name, eq, val = w.partition("=")
            if eq and name in opts:
                a, w = a + len(name) + 1, val
            elif not (w in opts and j + 1 < len(seg)):
                continue
            else:
                a, b, w = seg[j + 1]
            # exactly one single-quoted string, nothing attached
            if len(w) >= 2 and w[0] == "'" and w.find("'", 1) == len(w) - 1:
                spans.append((a + 1, b - 1))
    return _blank(command, spans)


def scan(command: str, cwd: str | None = None, project_root: str | None = None) -> list[Hit]:
    """Every reason `command` writes (or may write) a guarded path. Empty list = no write seen.

    `project_root` (T-4336): when given, a `.tasks` target provably outside it is not a
    guarded write. Without it every `.tasks` target is guarded, as before.
    """
    command = _blank_data_args(command)
    guarded = _guarded_within(os.path.realpath(project_root)) if project_root else None
    ctx = _Ctx(cwd=cwd, mentions=mentions_guarded(command), guarded=guarded)
    try:
        # the command itself, then every $(...) / `...` body found ANYWHERE in it — a
        # substitution inside double quotes still executes (review round 3); one inside
        # single quotes does not, but scanning it too only errs toward refusing
        for text in [command] + _substitutions(command):
            toks = _tokens(text)
            if toks is None:
                if ctx.mentions:
                    ctx.hits.append(Hit("command does not tokenise (unbalanced quote) and names a guarded path"))
                continue
            for seg in _segments(toks):
                _segment(seg, ctx)
        # T-4149: plus the lexer's reading (a `<<EOF` in a comment or quote no longer
        # hides the lines after it). Only ever adds refusals to the reading above.
        if ctx.mentions:
            try:
                texts = executed_texts(command)
            except ParseError:
                texts = []
            for text in texts:
                toks = _tokens(text, strip_heredocs=False)
                for seg in _segments(toks or []):
                    _segment(seg, ctx)
    except Exception as e:  # noqa: BLE001 — a scanner bug must not open the gate
        if ctx.mentions:
            ctx.hits.append(Hit(f"scanner error ({type(e).__name__}) on a command naming a guarded path"))
    return ctx.hits


_BRACE_SEQ = re.compile(r"^(-?\d+|[A-Za-z])\.\.(-?\d+|[A-Za-z])(?:\.\.(-?\d+))?$")
_BRACE_CAP = 256


def _brace_expand(word: str, mask: str) -> list[tuple[str, str]]:
    """Bash brace expansion over the UNQUOTED braces of one word. Returns (word, mask)
    pairs; past _BRACE_CAP results the word is returned unexpanded (and unresolvable)."""
    n = len(word)
    for i in range(n):
        if word[i] != "{" or mask[i] != "u" or (i and word[i - 1] == "$" and mask[i - 1] == "u"):
            continue
        depth, commas, j = 0, [], i
        while j < n:
            if mask[j] == "u":
                if word[j] == "{":
                    depth += 1
                elif word[j] == "}":
                    depth -= 1
                    if depth == 0:
                        break
                elif word[j] == "," and depth == 1:
                    commas.append(j)
            j += 1
        if j >= n:
            return [(word, mask)]
        pre, pm, post, qm = word[:i], mask[:i], word[j + 1:], mask[j + 1:]
        alts: list[tuple[str, str]] = []
        if commas:
            cuts = [i] + commas + [j]
            alts = [(word[a + 1:b], mask[a + 1:b]) for a, b in zip(cuts, cuts[1:])]
        else:
            m = _BRACE_SEQ.match(word[i + 1:j]) if "q" not in mask[i + 1:j] else None
            if not m:
                continue
            a, b, step = m.group(1), m.group(2), abs(int(m.group(3) or 1)) or 1
            if a.lstrip("-").isdigit() and b.lstrip("-").isdigit():
                lo, hi = int(a), int(b)
                if abs(hi - lo) // step > _BRACE_CAP:
                    return [(word, mask)]
                rng = range(lo, hi + 1, step) if lo <= hi else range(lo, hi - 1, -step)
                alts = [(str(v), "u" * len(str(v))) for v in rng]
            elif a.isalpha() and b.isalpha():
                lo, hi = ord(a), ord(b)
                rng = range(lo, hi + 1, step) if lo <= hi else range(lo, hi - 1, -step)
                alts = [(chr(v), "u") for v in rng]
            else:
                continue
        out: list[tuple[str, str]] = []
        for w, wm in alts:
            for e, em in _brace_expand(pre + w + post, pm + wm + qm):
                out.append((e, em))
                if len(out) > _BRACE_CAP:
                    return [(word, mask)]
        return out
    return [(word, mask)]


def _scan_boundary_text(text: str, ctx: _Ctx) -> None:
    """Lex `text`, then read every executed piece of it. A lex failure is a refusal."""
    ctx.depth += 1
    cwd0, cwd_after_top = ctx.cwd, ctx.cwd
    try:
        try:
            pieces = executed_texts(text)
        except ParseError as e:
            ctx.hits.append(Hit(f"command does not parse as shell ({e}); refused rather than guessed"))
            return
        for k, piece in enumerate(pieces):
            if k == 1:
                cwd_after_top = ctx.cwd
            if k:
                ctx.cwd = cwd0          # a substitution body runs in a subshell

            masks: list = []
            toks = _tokens(piece, strip_heredocs=False, masks=masks)
            if toks is None:
                ctx.hits.append(Hit("command does not tokenise (unbalanced quote); refused rather than guessed"))
                continue
            words: list[str] = []
            for tok, mask in zip(toks, masks):
                if "{" in tok and "u" in mask:
                    words.extend(w for w, _ in _brace_expand(tok, mask))
                else:
                    words.append(tok)
            for seg in _segments(words):
                if ctx.read_outside is not None:
                    _read_words(seg, ctx)
                _segment(seg, ctx)
        if len(pieces) == 1:
            cwd_after_top = ctx.cwd
    finally:
        ctx.cwd = cwd_after_top if ctx.depth == 1 else cwd0   # sh -c / eval: own process
        ctx.depth -= 1


_NAMED_PATH_RE = re.compile(r"(?<![\w.~})])(?:~|\.\.)?/[^\s$`{}()'\":;|&<>*?\[\]]+")


def _names_guarded(command: str, cwd: str | None, ctx: _Ctx) -> str:
    """T-4487: the first path-shaped piece of any word of `command` (an `=VALUE`, a
    `${X:-VALUE}` default and $(...) bodies included) that `ctx.guarded` rejects, or ""."""
    ctx = _Ctx(cwd=cwd, mentions=False, guarded=ctx.guarded, boundary=True)
    try:
        pieces = executed_texts(command)
    except ParseError:
        return ""
    for piece in pieces:
        for tok in _tokens(piece, strip_heredocs=False) or []:
            for cand in _NAMED_PATH_RE.findall(tok):
                ok, paths = _resolve(cand, ctx)
                # a regex or URL fragment (`/^##`, `//host`) names no directory that exists;
                # a write under a top-level directory that does not exist fails anyway
                paths = [p for p in paths if os.path.isdir("/" + p.lstrip("/").split("/")[0])
                         and p.strip("/")]
                if ok and any((ctx.guarded or is_guarded_path)(p) for p in paths):
                    return cand
    return ""


def scan_boundary(command: str, cwd: str | None, guarded, cd_ok) -> list[Hit]:
    """T-4149: every write the command makes to a path `guarded(path)` rejects, read as
    bash reads it (quote removal, `..`/symlink resolution via realpath+normpath, brace
    and tilde expansion, redirections anywhere, option clusters, $(...)/`...`/<(...)
    bodies, unquoted heredoc bodies, static `sh -c`/`eval` scripts). `cd_ok(path)` judges
    absolute cd destinations. A target only known at run time ($VAR, a path read from a
    file) is not judged — no mention gate applies here. Unparseable text is a hit.
    T-4487 exception: a git diff-family word that may expand to --output is refused when
    the command names a guarded path anywhere (`o=--output=/etc/x; git diff $o`). A value
    that only a file or the environment supplies (`git diff $(cat f)`) is still not seen."""
    ctx = _Ctx(cwd=cwd, mentions=False, guarded=guarded, boundary=True, cd_ok=cd_ok)
    try:
        _scan_boundary_text(command, ctx)
        if ctx.pending_output and not ctx.hits:
            named = _names_guarded(command, cwd, ctx)
            if named:
                ctx.hits.append(Hit(ctx.pending_output + " (an expanded argument may be --output; "
                                    "the command names a path outside the boundary)", named))
    except Exception as e:  # noqa: BLE001 — a scanner bug must not open the gate
        ctx.hits.append(Hit(f"boundary scanner error ({type(e).__name__}); refused rather than guessed"))
    return ctx.hits


_READ_REASON = "Outside-path argument"
_HOME_VAR = re.compile(r"^(?:\$HOME|\$\{HOME\})(?=/|$)")

# T-4284: free-text options are TEXT, never path operands — a commit message, a dispatch
# prompt or a sidecar body that MENTIONS an outside path does not read it. Scoped to the
# commands whose options are known to mean this: elsewhere the same spellings are not
# text (`zip -m` and `gzip --name` are flags that take no value, so the next word IS a
# path operand; `install -m`, `grep -m` take a mode/count). A substitution inside the
# text (`-m "$(cat /x)"`) is its own executed piece and is still judged.
# T-4344: the value-taking free-text options are keyed per command (and per git
# subcommand). One global set let `--summary` (git log, takes no value) or `-m` (git diff,
# takes no value) skip the next word — a path operand — and hide an outside read.
_FREE_TEXT_OPTS_BY_CMD = {
    "fw": {"*": frozenset({"--prompt", "--body", "-m", "--message", "--description", "--name",
                           "--rationale", "--summary", "--detail", "--reason"})},
    "gh": {"*": frozenset({"--body", "-b", "--title", "-t"})},
    "termlink": {"*": frozenset({"--prompt", "--body", "--message", "--description", "--name",
                                 "--summary"})},
    "claude": {"*": frozenset({"--prompt"})},
    "git": {sub: frozenset({"-m", "--message"}) for sub in ("commit", "tag", "merge", "stash", "notes")},
}
_GIT_VALUE_GLOBALS = frozenset({"-C", "-c", "--git-dir", "--work-tree", "--namespace"})


def _git_subcommand(argv: list[str]) -> str | None:
    """The first non-option word after `git`, stepping over the value of `-C`/`-c`/…"""
    it = iter(argv[1:])
    for w in it:
        if w in _GIT_VALUE_GLOBALS:
            next(it, None)
        elif not w.startswith("-"):
            return w
    return None


def _free_text_opts(argv: list[str]) -> frozenset:
    """The value-taking free-text options of this command, or none for any other command."""
    if not argv:
        return frozenset()
    cmd = os.path.basename(argv[0])
    table = _FREE_TEXT_OPTS_BY_CMD.get(cmd)
    if not table:
        return frozenset()
    if cmd == "git":
        return table.get(_git_subcommand(argv) or "", frozenset())
    return table["*"]


def _free_text_value(w: str, opts: frozenset) -> tuple[bool, str | None]:
    """(is `w` a free-text option, its attached value or None when the value is the next word).
    Spellings: `--opt`, `--opt=VALUE`, and `-mVALUE` for a short option."""
    if w in opts:
        return True, None
    if w.startswith("--"):
        name, sep, value = w.partition("=")
        return (True, value) if sep and name in opts else (False, None)
    for o in opts:
        if len(o) == 2 and w.startswith(o) and len(w) > 2 and not w.startswith("--"):
            return True, w[2:]
    return False, None


def _read_words(seg: list[str], ctx: _Ctx) -> None:
    """T-3768: judge every path-shaped word of one segment, AFTER quote removal.

    Path-shaped = absolute, `~`/`$HOME`-led, the value of an `--opt=VALUE` option, or a
    relative word with a `..` component (resolved against the segment's cwd). A relative
    word with no `..` stays under the cwd and is not judged, so sed scripts and regexes
    (`s/a/b/`) cost nothing. normpath, not realpath: a read is judged by the name it
    spells, the same as Pattern 4 always did. Prose (`-m "fix /x"`) is one word that does
    not start with `/`, so it is never a path."""
    outside = ctx.read_outside
    if outside is None:
        return
    argv, _ = _unwrap(list(seg))
    free_text = _free_text_opts(argv)
    skip_next = False
    for w in seg:
        if skip_next:
            skip_next = False
            continue
        if free_text:
            is_free_text, _value = _free_text_value(w, free_text)
            if is_free_text:
                skip_next = _value is None
                continue
        if not w or w.startswith("\x00") or w in _OPSET or w == UNRESOLVED:
            continue
        if w.startswith("-") and "=" in w:
            w = w.split("=", 1)[1]
        w = _HOME_VAR.sub("~", w)
        if w.startswith("~"):
            w = os.path.expanduser(w)
        if not w.startswith("/"):
            if ".." not in w.split("/") or ctx.cwd is None:
                continue
            w = os.path.join(ctx.cwd, w)
        p = os.path.normpath(w)
        if p.startswith("//"):
            p = "/" + p.lstrip("/")
        if outside(p):
            ctx.hits.append(Hit(_READ_REASON, p))


def scan_boundary_reads(command: str, cwd: str | None, read_outside) -> list[Hit]:
    """T-3768: every word that names a path `read_outside(path)` rejects, read as bash
    reads it — quotes and escapes removed, `..` resolved against the cwd (cd-tracked),
    `~`/`$HOME` expanded, brace expansion, and the bodies of $(...)/`...`/<(...),
    here-strings, unquoted heredocs and static `sh -c`/`eval` scripts. Parse failures are
    left to scan_boundary (which refuses them); only read hits are returned."""
    ctx = _Ctx(cwd=cwd, mentions=False, guarded=lambda _p: False, boundary=True,
               cd_ok=lambda _p: True, read_outside=read_outside)
    try:
        _scan_boundary_text(command, ctx)
    except Exception as e:  # noqa: BLE001 — a scanner bug must not open the gate
        return [Hit(f"boundary read scanner error ({type(e).__name__}); refused rather than guessed")]
    return [h for h in ctx.hits if h.reason == _READ_REASON]


def _substitutions(command: str) -> list[str]:
    """Bodies of every `$(...)` (paren-matched, nested included) and `` `...` `` in the text."""
    out, i, n = [], 0, len(command)
    while i < n:
        if command.startswith("$(", i) and not command.startswith("$((", i):
            depth, j = 1, i + 2
            while j < n and depth:
                depth += {"(": 1, ")": -1}.get(command[j], 0)
                j += 1
            body = command[i + 2:j - 1] if depth == 0 else command[i + 2:]
            out.append(body)
            out.extend(_substitutions(body))
            i += 2
        elif command[i] == "`":
            j = command.find("`", i + 1)
            if j < 0:
                out.append(command[i + 1:])
                break
            out.append(command[i + 1:j])
            i = j + 1
        else:
            i += 1
    return out


if __name__ == "__main__":  # pragma: no cover - debugging aid
    import sys
    for h in scan(sys.argv[1], os.getcwd()):
        print(f"{h.reason}: {h.target}")
