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
The command is tokenised with shlex (quote-aware, so a `>` inside a quoted sed script is
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
import shlex
from dataclasses import dataclass, field

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


def _decode_ansi_c(text: str) -> str:
    """Decode bash $'...' quoting so `$'\\x2etasks'` is seen as `.tasks`."""
    def dec(m):
        try:
            return m.group(1).encode("latin-1", "backslashreplace").decode("unicode_escape")
        except Exception:  # noqa: BLE001
            return m.group(1)
    return re.sub(r"\$'((?:[^'\\]|\\.)*)'", dec, text)


def normalised(command: str) -> str:
    t = _decode_ansi_c(command)
    return t.replace("'", "").replace('"', "").replace("\\", "")


def mentions_guarded(command: str) -> bool:
    return bool(MENTION_RE.search(normalised(command)))


def _tokens(command: str) -> list[str] | None:
    cmd = _decode_ansi_c(command).replace("`", "\n")
    lex = shlex.shlex(cmd, posix=True, punctuation_chars=";&|()<>\n")
    lex.whitespace_split = True
    lex.commenters = ""
    lex.whitespace = " \t\r"
    try:
        return list(lex)
    except ValueError:
        return None


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


def _resolve(target: str, ctx: _Ctx) -> tuple[bool, list[str]]:
    """(resolved?, absolute paths). Unresolvable → (False, [])."""
    if target == UNRESOLVED or not target:
        return False, []
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
        if not matches:
            return False, []
        return True, [os.path.realpath(m) for m in matches] + matches
    return True, [os.path.realpath(t), os.path.normpath(t)]


def _check_target(target: str, ctx: _Ctx, reason: str) -> None:
    ok, paths = _resolve(target, ctx)
    if ok:
        if any(is_guarded_path(p) for p in paths):
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

    if verb in NETWORK_VERBS and "toggle-ac" in normalised(seg_text):
        ctx.hits.append(Hit("calls the Watchtower toggle-ac endpoint (that IS a tick)"))
        return
    ops = [a for a in args if not a.startswith("-")]
    if any(os.path.basename(a) in ("human_ac_ticks.py", "human_ac_ticks") for a in ops[:2]) and "ack" in ops:
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
        if any(re.match(r"^(-[a-zA-Z]*i|--in-place)", a) for a in args if a.startswith("-") and not a.startswith("--e")):
            has_e = any(a in ("-e", "-f", "--expression", "--file") or a.startswith(("--expression=", "--file="))
                        for a in args)
            ops = _operands(args, {"-e", "-f", "--expression", "--file", "-l"})
            if not has_e and ops:
                ops = ops[1:]
            for t in ops:
                _check_target(t, ctx, "sed -i")
        return
    if verb.startswith(("perl", "ruby")):
        flags = [a for a in args if a.startswith("-") and not a.startswith("--")]
        inline = any(re.match(r"^-[a-zA-Z]*[eE]", f) for f in flags)
        if any(re.match(r"^-[a-zA-Z]*i", f) for f in flags):
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
        if any(a in ("-i", "--include") and "inplace" in (args[k + 1] if k + 1 < len(args) else "")
               or re.match(r"^(-iinplace|--include=inplace)", a) for k, a in enumerate(args)):
            ops = _operands(args, {"-i", "-f", "-v", "-F", "--include"})
            for t in ops[1:]:
                _check_target(t, ctx, f"{verb} -i inplace")
        prog = next(iter(_operands(args, {"-i", "-f", "-v", "-F", "--include"})), "")
        if re.search(r">|\|\s*\"|system|getline\s*<|fflush|printf?\s*>", prog):
            _inline(ctx, verb)
        return
    if verb in ("tee", "sponge"):
        for t in _operands(args):
            _check_target(t, ctx, verb)
        return
    if verb in ("sort", "gsort", "shuf", "uniq"):
        for k, a in enumerate(args):
            if a in ("-o", "--output") and k + 1 < len(args):
                _check_target(args[k + 1], ctx, f"{verb} -o")
            elif a.startswith("--output="):
                _check_target(a.split("=", 1)[1], ctx, f"{verb} -o")
            elif re.match(r"^-[a-zA-Z]*o.+", a) and verb != "uniq":
                _check_target(a[a.index("o") + 1:], ctx, f"{verb} -o")
        if verb == "uniq":
            ops = _operands(args, {"-f", "-s", "-w"})
            if len(ops) >= 2:
                _check_target(ops[1], ctx, "uniq OUTPUT")
        return
    if verb in COPY_FAMILY:
        tval = {"-t", "--target-directory", "-S", "--suffix", "-m", "--mode", "-o", "--owner",
                "-g", "--group", "-e", "--exclude", "--include", "-f", "--filter"}
        for k, a in enumerate(args):
            if a in ("-t", "--target-directory") and k + 1 < len(args):
                _check_target(args[k + 1], ctx, f"{verb} -t")
                return
            if a.startswith("--target-directory="):
                _check_target(a.split("=", 1)[1], ctx, f"{verb} -t")
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
        if sub in ("checkout", "restore", "apply", "am", "show", "cat-file", "stash", "switch") and \
                MENTION_RE.search(normalised(seg_text)):
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
                    if b in (";", "+", "\\;"):
                        break
                    inner.append(UNRESOLVED if "{}" in b else b)
                if inner:
                    _segment(inner, ctx)
        return
    if verb in EXTRACTORS:
        if MENTION_RE.search(normalised(seg_text)):
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


def _script_form(verb: str, seg_text: str, ctx: _Ctx) -> None:
    """`python3 tool.py ARGS`: the script is not opened (residual); its ARGUMENTS are seen."""
    if MENTION_RE.search(normalised(seg_text)):
        ctx.hits.append(Hit(f"{verb} script is handed a guarded path (the script itself is not inspected)"))


def scan(command: str, cwd: str | None = None) -> list[Hit]:
    """Every reason `command` writes (or may write) a guarded path. Empty list = no write seen."""
    ctx = _Ctx(cwd=cwd, mentions=mentions_guarded(command))
    toks = _tokens(command)
    if toks is None:
        if ctx.mentions:
            ctx.hits.append(Hit("command does not tokenise (unbalanced quote) and names a guarded path"))
        return ctx.hits
    for seg in _segments(toks):
        _segment(seg, ctx)
    return ctx.hits


if __name__ == "__main__":  # pragma: no cover - debugging aid
    import sys
    for h in scan(sys.argv[1], os.getcwd()):
        print(f"{h.reason}: {h.target}")
