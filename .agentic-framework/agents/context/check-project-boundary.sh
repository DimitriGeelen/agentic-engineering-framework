#!/bin/bash
# Project Boundary Enforcement Hook — PreToolUse gate for Write/Edit/Bash
# Blocks file modifications and commands targeting paths outside PROJECT_ROOT.
#
# Exit codes (Claude Code PreToolUse semantics):
#   0 — Allow tool execution
#   2 — Block tool execution (stderr shown to agent)
#
# For Write/Edit: extracts file_path, blocks if outside PROJECT_ROOT.
# For Bash: detects cd, write, fw-on-other-project, AND read-side outside-path
# arguments (T-1702 / G-065 — read-blind hole closed 2026-05-03).
#
# Allowed exceptions (Bash + Write):
#   /tmp/**                — Agent dispatch working files
#   /root/.claude/**       — Claude Code memory/settings
#   /etc/cron.d/**         — Cron install (T-603/T-1191)
#   PROJECT_ROOT/**        — Obviously allowed
#
# Read-side allowlist (Bash outside-path arguments only — broader because
# reads are observably less destructive than mutations):
#   /tmp/**, /usr/**, /etc/**, /var/log/**, /var/lib/**,
#   /root/.local/**, /root/.claude/**, /proc/**, /sys/**, /dev/**,
#   /bin/**, /sbin/**, /lib/**, /lib64/**
#
# T-4361 (GitHub #104): the /root/.claude and /root/.local entries also apply to the
# running account's $HOME/.claude and $HOME/.local, and the registry key
# BOUNDARY_EXTRA_READ_PATHS (colon-separated absolute paths) adds read-only entries.
#
# Origin: T-559 (cd block) → T-1702 (read-side block, G-065 fix).
# Part of: Agentic Engineering Framework (P-002: Structural Enforcement)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$FRAMEWORK_ROOT/lib/paths.sh"
source "$FRAMEWORK_ROOT/lib/config.sh"
fw_hook_crash_trap "check-project-boundary"

# T-4361 (GitHub #104): the Claude/shim zones belong to the RUNNING account, not to
# root. `/root/.claude` and `/root/.local` were literals, so a non-root account was
# refused its own ~/.claude and ~/.local. They are kept (root-run installs) and the
# account's $HOME equivalents are added. An unset, relative or `/` HOME adds nothing.
BOUNDARY_HOME=""
case "${HOME:-}" in
    /?*) BOUNDARY_HOME=$(realpath -m "$HOME" 2>/dev/null || echo "$HOME") ;;
esac
BOUNDARY_HOME="${BOUNDARY_HOME%/}"
# Extra Bash READ paths the operator allows (registry key BOUNDARY_EXTRA_READ_PATHS).
# Only absolute entries count; `/` and empty entries are dropped, never widened.
BOUNDARY_EXTRA_READ=""
_bd_extra_raw=$(fw_config BOUNDARY_EXTRA_READ_PATHS "" 2>/dev/null || true)
IFS=':' read -r -a _bd_extra_list <<< "$_bd_extra_raw"
for _bd_p in "${_bd_extra_list[@]}"; do
    case "$_bd_p" in /?*) ;; *) continue ;; esac
    _bd_p=$(realpath -m "$_bd_p" 2>/dev/null || echo "$_bd_p")
    _bd_p="${_bd_p%/}"
    [ -n "$_bd_p" ] || continue
    BOUNDARY_EXTRA_READ="${BOUNDARY_EXTRA_READ:+$BOUNDARY_EXTRA_READ:}$_bd_p"
done
unset _bd_extra_raw _bd_extra_list _bd_p

# Read stdin (JSON from Claude Code)
INPUT=$(cat)

# T-4652: with python3 unusable every decode below yields '' and the hook would fall
# through to `exit 0`. Scan the raw payload in bash instead; block on a foreign path.
source "$FRAMEWORK_ROOT/lib/hook-degraded.sh"
if ! hook_python_ok; then
    hook_degraded_boundary "$INPUT" "python3 cannot import json/re/os/hashlib"
    exit 0
fi

# Extract tool name
TOOL_NAME=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('tool_name', ''))
except:
    print('')
" 2>/dev/null)

# ── Write/Edit gate ──
if [ "$TOOL_NAME" = "Write" ] || [ "$TOOL_NAME" = "Edit" ] || [ "$TOOL_NAME" = "NotebookEdit" ]; then
    FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    ti = data.get('tool_input', {})
    print(ti.get('file_path', '') or ti.get('notebook_path', ''))
except:
    print('')
" 2>/dev/null)

    # No path — allow (defensive)
    [ -z "$FILE_PATH" ] && exit 0

    # Resolve to absolute path
    RESOLVED=$(realpath -m "$FILE_PATH" 2>/dev/null || echo "$FILE_PATH")

    # Allowed zones
    case "$RESOLVED" in
        "$PROJECT_ROOT"/*)
            exit 0
            ;;
        /tmp/*)
            exit 0
            ;;
        /root/.claude/*)
            exit 0
            ;;
    esac
    # T-4361: the running account's own Claude Code config.
    if [ -n "$BOUNDARY_HOME" ]; then
        case "$RESOLVED" in
            "$BOUNDARY_HOME"/.claude/*) exit 0 ;;
        esac
    fi

    # F-25: a sibling git worktree of THIS repo is the same repository, not
    # another project. `git worktree list` (run against PROJECT_ROOT) only
    # enumerates worktrees that share PROJECT_ROOT's own .git — a genuinely
    # foreign project at another /opt/* path never appears in this list, so
    # this cannot be used to admit anything outside the current repo. Silent
    # no-op (empty stdout) when PROJECT_ROOT is not a git repo, which keeps
    # non-git installs and test fixtures behaving exactly as before.
    while IFS= read -r _wt_root; do
        [ -n "$_wt_root" ] || continue
        case "$RESOLVED" in
            "$_wt_root"|"$_wt_root"/*)
                exit 0
                ;;
        esac
    done < <(git -C "$PROJECT_ROOT" worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p')

    # Everything else: BLOCK
    echo "" >&2
    echo "══════════════════════════════════════════════════════════" >&2
    echo "  PROJECT BOUNDARY BLOCK — Write Outside Project Root" >&2
    echo "══════════════════════════════════════════════════════════" >&2
    echo "" >&2
    echo "  Target:       $FILE_PATH" >&2
    echo "  Project root: $PROJECT_ROOT" >&2
    echo "" >&2
    echo "  Write/Edit operations are restricted to the current project." >&2
    echo "  This prevents accidental modification of other projects," >&2
    echo "  system files, or resources outside your workspace." >&2
    echo "" >&2
    echo "  Allowed zones:" >&2
    echo "    - $PROJECT_ROOT/**  (project files)" >&2
    echo "    - /tmp/**           (agent dispatch scratch)" >&2
    echo "    - /root/.claude/**  (Claude Code config)" >&2
    [ -n "$BOUNDARY_HOME" ] && echo "    - $BOUNDARY_HOME/.claude/**  (this account's Claude Code config)" >&2
    echo "" >&2
    echo "  For cross-project reads, use TermLink dispatch:" >&2
    echo "" >&2
    echo "    $(_fw_cmd) termlink dispatch --name read --project /opt/other \\" >&2
    echo "      --prompt 'cat README.md and return its contents'" >&2
    echo "" >&2
    echo "  Policy: T-559 (Project Boundary Enforcement)" >&2
    echo "══════════════════════════════════════════════════════════" >&2
    echo "" >&2
    exit 2
fi

# ── Bash gate ──
if [ "$TOOL_NAME" = "Bash" ]; then
    COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('tool_input', {}).get('command', ''))
except:
    print('')
" 2>/dev/null)

    # No command — allow (defensive)
    [ -z "$COMMAND" ] && exit 0

    # T-4149: the session cwd, so a relative write target (`touch ../../x`) resolves.
    CMD_CWD=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    print(json.load(sys.stdin).get('cwd', '') or '')
except Exception:
    print('')
" 2>/dev/null)

    # Quick pre-filter: if no absolute path reference, skip Python analysis.
    # T-1702: include any leading-slash token (read-side detection needs to see
    # /root, /var, /home etc. even when they are not write/cd targets).
    # T-4114: any tee with an absolute path anywhere after it must reach the
    # analysis — `tee\s+/` let `tee -a /srv/x` skip it entirely.
    # T-4126: same for the write verbs parsed in Pattern 3 and for `>|`.
    # T-4149: the tokenised pass (Pattern 5) must see every spelling bash can turn
    # into an outside path — any slash, `~`, `..`, a brace, a substitution, an escape,
    # a quote (`"/"etc`), or a cd (bare `cd` goes HOME). A regex that names verbs is
    # exactly the parser differential this task removes, so the filter names
    # characters instead; what it skips cannot spell a path outside the cwd.
# T-4921: here-string, not a pipe — under pipefail a pipe into grep -q can read a match as no match (T-4920).
    if ! grep -qE '(cd\s+/|/opt/|/home/|/root/|/var/|/etc/|/usr/|>+\s*/|tee\s.*/|>\|\s*/|(^|[^[:alnum:]_.-])(cp|mv|install|ln|rsync|dd|sed|perl|truncate|chmod|chown|chgrp|touch|mkdir)\s.*/|\.agentic-framework/bin/fw)' <<<"$COMMAND" \
       && ! grep -qE '[/~{$`\\"'"'"']|\.\.|(^|[^[:alnum:]_.-])(cd|pushd)([^[:alnum:]_.-]|$)' <<<"$COMMAND"; then
        exit 0
    fi

    # TermLink exception: SEE _drop_termlink_segments IN THE PYTHON BLOCK BELOW.
    #
    # T-679 created this exemption because `termlink interact|pty|dispatch` run
    # the command in a DIFFERENT process — a `cd /opt/other` inside their quoted
    # argument targets the TermLink session, not this shell, so analysing that
    # text is a false positive. T-1075 widened it so loop/pipe forms matched.
    #
    # T-3076 removed the `exit 0` that used to live here. It returned before ANY
    # boundary analysis, for the WHOLE line, on a regex that matched the word
    # `termlink` in argument position too — so `grep termlink /opt/other/x` was
    # exempt, and so was `termlink ping && cat /opt/other/.env`. The exemption is
    # now applied per-segment, command-position only, inside the analysis itself.
    # Do not reintroduce a line-scoped short-circuit here.

    # Detailed analysis: detect cd to another project + write operations
    # T-4921: the command goes to the matcher in a file, not an env var. Linux caps one
    # env string at 128 KB (MAX_ARG_STRLEN): a longer command stopped python3 starting,
    # the matcher gave no verdict, and every long command took the degraded path.
    _BOUNDARY_CMD_FILE=$(mktemp "${TMPDIR:-/tmp}/fw-boundary-cmd.XXXXXX") \
        && printf '%s' "$COMMAND" > "$_BOUNDARY_CMD_FILE" || _BOUNDARY_CMD_FILE=""
    export _BOUNDARY_CMD_FILE
    export _BOUNDARY_CWD="$CMD_CWD"
    export _BOUNDARY_FW_LIB="$FRAMEWORK_ROOT/lib"   # T-3766: registered credential files
    export _BOUNDARY_HOME="$BOUNDARY_HOME"           # T-4361
    export _BOUNDARY_EXTRA_READ="$BOUNDARY_EXTRA_READ"
    MATCH_RESULT=$(python3 << 'PYEOF'
import re, sys, os, subprocess


def _read_boundary_cmd():
    # T-4921: from the file the shell wrote. Unreadable raises: no verdict, and the
    # degraded path fails closed.
    with open(os.environ['_BOUNDARY_CMD_FILE'], encoding='utf-8', errors='surrogateescape') as fh:
        return fh.read()


_BOUNDARY_CMD_RAW = _read_boundary_cmd()
command = _BOUNDARY_CMD_RAW
project_root = os.environ.get('PROJECT_ROOT', '')

# Normalize project root (remove trailing slash)
project_root = project_root.rstrip('/')

if not project_root:
    print('SAFE')
    sys.exit(0)

# T-4361 (GitHub #104): account-relative zones and operator-allowed extra reads, both
# already sanitised (absolute, realpath'd, no `/`) by the bash side above.
_HOME = os.environ.get('_BOUNDARY_HOME', '').rstrip('/')
_CLAUDE_ZONES = ('/root/.claude',) + ((_HOME + '/.claude',) if _HOME else ())
_EXTRA_READ = tuple(p.rstrip('/') for p in os.environ.get('_BOUNDARY_EXTRA_READ', '').split(':')
                    if p.startswith('/') and p.rstrip('/'))


def _in_claude_zone(p):
    return any(p == z or p.startswith(z + '/') for z in _CLAUDE_ZONES)

# T-1361 / G-053-C: Strip content between balanced "..." and '...' before
# pattern scanning. Prevents false-positives on quoted string literals (commit
# messages, echo arguments, documentation examples) that happen to mention
# absolute paths. Imperfect for escaped quotes inside strings, but covers 95%+
# of real cases. Lengths preserved so position-dependent patterns still work.
def _strip_quoted(s):
    # Walk char-by-char, tracking quote state.
    out = []
    i = 0
    n = len(s)
    while i < n:
        c = s[i]
        if c == '\\' and i + 1 < n:
            # Preserve escaped pair as-is (two chars)
            out.append(c)
            out.append(s[i + 1])
            i += 2
            continue
        if c == '"' or c == "'":
            quote = c
            out.append(c)
            i += 1
            # Consume until matching quote, replacing content with spaces.
            while i < n and s[i] != quote:
                if s[i] == '\\' and i + 1 < n:
                    out.append(' ')
                    out.append(' ')
                    i += 2
                    continue
                out.append(' ' if s[i] != '\n' else '\n')
                i += 1
            if i < n:
                out.append(s[i])  # closing quote
                i += 1
            continue
        out.append(c)
        i += 1
    return ''.join(out)

# T-2920: heredoc stripping runs BEFORE quote stripping. Order is load-bearing.
#
# _strip_quoted blanks the contents of quoted literals. For the QUOTED heredoc
# form `<<'EOF'` it therefore blanks the marker itself, leaving `<<'   '` — and
# _strip_heredocs matches `<<-?\s*['"]?(\w+)['"]?`, whose \w+ cannot match
# spaces. So with quote-stripping first, a quoted heredoc's body is NEVER
# stripped, and prose inside it is scanned as if it were command text.
#
# Measured before the reorder:
#   bare   <<EOF    marker survives quote-strip? True   -> body stripped
#   quoted <<'EOF'  marker survives quote-strip? False  -> body NEVER STRIPPED
#
# Both mitigations were individually correct and individually tested; the first
# silently voided the second. And L-294 MANDATES the quoted form (the bare form
# command-substitutes $(...)), so following our own learning is what triggered
# the false block — a rail message to 832 whose text quoted our own
# Copy-Pasteable Commands rule.
#
# A heredoc body is a strictly larger unit than a quoted string, so it must be
# removed first. Do not reorder these two calls. Pinned by
# tests/unit/t2920_boundary_heredoc_strip_order.bats.

# T-1702: strip simple heredoc bodies before pattern scanning so /opt/x inside
# `cat > /tmp/x <<EOF\n...\nEOF` doesn't false-positive on Pattern 4. Mirrors
# the _strip_quoted approach: replace body with spaces of equal length so
# downstream position-dependent patterns still work.
def _strip_heredocs(s):
    out = list(s)
    i = 0
    n = len(s)
    heredoc_re = re.compile(r"<<-?\s*['\"]?(\w+)['\"]?")
    while i < n:
        m = heredoc_re.search(s, i)
        if not m:
            break
        marker = m.group(1)
        nl = s.find('\n', m.end())
        if nl == -1:
            break
        j = nl + 1
        found = False
        while j < n:
            line_end = s.find('\n', j)
            if line_end == -1:
                line_end = n
            line = s[j:line_end].lstrip('\t')
            if line == marker:
                # Replace body (between nl and j) with spaces, preserving newlines.
                for k in range(nl + 1, j):
                    if out[k] != '\n':
                        out[k] = ' '
                i = line_end
                found = True
                break
            j = line_end + 1
        if not found:
            break
    return ''.join(out)

# T-3076: TermLink exemption — segment-scoped, command-position only.
#
# Replaces the whole-line `exit 0` that used to sit in the bash gate above.
# That short-circuit returned before any analysis ran, on a regex that matched
# the bare word `termlink` anywhere the shell allowed whitespace around it. Two
# over-matches followed: the word in ARGUMENT position exempted the line
# (`grep termlink /opt/other/x`), and ONE exempt segment exempted every sibling
# segment (`termlink ping && cat /opt/other/.env`). Recorded as L-021 by T-1075
# and left standing; T-3076 is the second instance, so it is fixed rather than
# re-learned.
#
# What survives: the T-679 reason for the exemption. `termlink interact|pty|
# dispatch` run in a different process, so a `cd /opt/other` inside their quoted
# argument targets the TermLink session, not this shell. Those segments are
# still exempt — only the segment that actually invokes TermLink is.
#
# Splitting reuses _strip_quoted rather than defining a second quote-aware
# walker: the quote-blanked view it already produces is exactly the view in
# which a separator inside a quoted argument is invisible. It is length-
# preserving, so mask offsets index the real command directly.
#
# Fail-closed direction is explicit: _drop_termlink_segments returns the command
# UNCHANGED (i.e. fully analysed, nothing exempt) on any parse failure. It must
# never return early, and must never widen the exemption on error.

_TL_WRAPPERS = frozenset({
    'sudo', 'nohup', 'timeout', 'env', 'command', 'exec',
    'time', 'stdbuf', 'nice', 'ionice',
})
# Shell keywords/openers that can precede a command inside a segment, e.g. the
# `do` of the T-1075 loop form `for n in ...; do termlink pty inject ...`.
_TL_KEYWORDS = frozenset({
    'do', 'then', 'else', 'elif', 'if', 'while', 'until', '{', '(', '!',
})
_TL_ASSIGN = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*=')
_TL_DURATION = re.compile(r'^[0-9]+(\.[0-9]+)?[smhd]?$')


def _split_segments(mask):
    """Index ranges of shell segments in `mask` (a quote-blanked command).

    Separators: newline, `;`, `|`, `||`, `&&`, and a bare `&`. A bare `&` is a
    separator only when it is not part of a redirect (`2>&1`, `>&2`, `&>file`).
    Because `mask` came from _strip_quoted, separators inside quoted arguments
    have been blanked and cannot split — which is what keeps the T-679 form
    `termlink pty inject s "cd /opt/other && make"` a single segment.
    """
    bounds = []
    start = 0
    i = 0
    n = len(mask)
    while i < n:
        c = mask[i]
        if c == '\n' or c == ';':
            bounds.append((start, i))
            i += 1
            start = i
            continue
        if c == '|':
            step = 2 if (i + 1 < n and mask[i + 1] == '|') else 1
            bounds.append((start, i))
            i += step
            start = i
            continue
        if c == '&':
            if i + 1 < n and mask[i + 1] == '&':
                bounds.append((start, i))
                i += 2
                start = i
                continue
            prev = mask[i - 1] if i > 0 else ''
            nxt = mask[i + 1] if i + 1 < n else ''
            if prev in '<>' or nxt in '<>':
                i += 1          # redirect, not a separator
                continue
            bounds.append((start, i))
            i += 1
            start = i
            continue
        i += 1
    bounds.append((start, n))
    return bounds


def _segment_invokes_termlink(seg, root):
    """True when `seg`'s COMMAND POSITION is a TermLink invocation.

    Command position = first word of the segment, after skipping shell
    keywords, `VAR=value` prefixes, and wrappers (`sudo`, `env VAR=v`,
    `timeout N`, `nohup`, ...). Accepts `termlink`, `<path>/termlink`,
    `fw termlink`, `bin/fw termlink`, `.agentic-framework/bin/fw termlink`.
    Argument position never counts — that is the T-3076 defect.
    """
    toks = seg.split()
    i = 0
    while i < len(toks):
        t = toks[i]
        if t in _TL_KEYWORDS:
            i += 1
            continue
        if _TL_ASSIGN.match(t):
            i += 1
            continue
        if t.rsplit('/', 1)[-1] in _TL_WRAPPERS:
            i += 1
            while i < len(toks) and (toks[i].startswith('-')
                                     or _TL_DURATION.match(toks[i])):
                i += 1
            continue
        break
    if i >= len(toks):
        return False
    cmd = toks[i]
    # An absolute-path invocation from outside the project is never exempt:
    # `/opt/other/.agentic-framework/bin/fw termlink ...` is precisely the
    # cross-project fw call Pattern 2 exists to block.
    if cmd.startswith('/') and not (cmd == root or cmd.startswith(root + '/')):
        return False
    base = cmd.rsplit('/', 1)[-1]
    if base == 'termlink':
        return True
    if base == 'fw':
        return i + 1 < len(toks) and toks[i + 1] == 'termlink'
    return False


def _drop_termlink_segments(cmd, root):
    """Blank the segments that invoke TermLink; leave every other segment intact.

    Length-preserving (spaces in, newlines kept) so the position-dependent
    patterns downstream are unaffected. Returns `cmd` unchanged when nothing is
    exempt AND when anything goes wrong — the fail-closed direction. A bug here
    costs a false block; the inverse would silently disable the gate.
    """
    try:
        spans = _termlink_spans(cmd, root)
        out = list(cmd)
        for s, e in spans:
            for k in range(s, e):
                if out[k] != '\n':
                    out[k] = ' '
        return ''.join(out) if spans else cmd
    except Exception:
        return cmd


def _segment_mask(cmd):
    """T-4284: the quote-blanked view for SEGMENT SPLITTING — quoted newlines blanked too.

    _strip_quoted keeps a newline inside a quoted string so its mask stays line-aligned,
    but _split_segments splits on every newline it sees. A multi-line quoted argument
    (`termlink dispatch --prompt "line1\\nline2 <project>"`) was cut into segments, only
    the first was blanked as TermLink, and the leftover closing quote then opened a quote
    in the next pass, leaving the prompt text unquoted (`<project>` read as a redirect).
    Length-preserving, so offsets still index the real command."""
    mask = list(_strip_quoted(cmd))
    # Walk the mask with _strip_quoted's own rules: outside quotes a backslash keeps
    # the next char; inside, everything but newlines is already blank.
    quote, k, n = None, 0, len(mask)
    while k < n:
        c = mask[k]
        if quote is None:
            if c == '\\':
                k += 2
                continue
            if c in '"\'':
                quote = c
        elif c == quote:
            quote = None
        elif c == '\n':
            mask[k] = ' '
        k += 1
    return ''.join(mask)


def _termlink_spans(cmd, root):
    """[(start, end)] of the segments of `cmd` that invoke TermLink (may raise)."""
    mask = _segment_mask(cmd)
    return [(s, e) for s, e in _split_segments(mask)
            if s < e and _segment_invokes_termlink(mask[s:e], root)]


# T-3766: the sanctioned credential path. A segment whose first word is this
# project's fw BY ABSOLUTE PATH, then `review credential`, may name a credential
# file the committed backend registry registers (its --source argument); that
# exact token, in that segment only, is exempt from the read-side Pattern 4.
# Nothing else is: the write patterns (1-3) run first and still see the path,
# `cat <file>` in a sibling segment is not exempt, and an unregistered path in
# the same segment still blocks. Fails closed: any error yields no exemption.
def _registered_cred_files():
    try:
        sys.path.insert(0, os.environ.get('_BOUNDARY_FW_LIB', ''))
        import review_cost, review_credential
        return review_credential.registered_files(review_cost.policy_path(),
                                                  review_cost.load_registry())
    except Exception:
        return set()


def _cred_exempt_spans(cmd, root):
    """[(start, end)] of registered-credential-file tokens inside fw-review-credential segments."""
    try:
        files = None
        spans = []
        mask = _segment_mask(cmd)   # T-4284: a quoted newline does not split
        for s, e in _split_segments(mask):
            toks = list(re.finditer(r'\S+', mask[s:e]))
            words = [t.group(0) for t in toks]
            # Exactly this project's fw, by ABSOLUTE path, as the segment's first word: a
            # relative `fw`/`bin/fw` resolves through PATH or the cwd (`PATH=/tmp fw ...`,
            # `cd /tmp && bin/fw ...`), and an assignment prefix could redirect it.
            if len(words) < 3:
                continue
            exe = words[0]
            if exe not in (root + '/bin/fw', root + '/.agentic-framework/bin/fw') \
                    or words[1:3] != ['review', 'credential']:
                continue
            # A strict GRAMMAR, not a cutoff (round 3: `'--exec'` and `--ex""ec` are
            # `--exec` to the shell but not to a text scan, so a child's `--source`
            # slipped through). The exempt segment must be exactly
            #     <abs fw> review credential <backend-id> [--check] --source <file> [--check]
            # with no quote, backslash, `$`, backtick, `<`, `>`, `(` or `)` anywhere in
            # its RAW text. Anything else (--exec, --task, extra words) gets no exemption.
            if re.search(r'[\'"\\$`<>()]', cmd[s:e]):
                continue
            rest = words[3:]
            if not rest or not re.match(r'^[a-z0-9][a-z0-9-]*$', rest[0]):
                continue
            src_idx = None
            k, ok = 1, True
            while k < len(rest):
                if rest[k] == '--check':
                    k += 1
                elif rest[k] == '--source' and src_idx is None and k + 1 < len(rest):
                    src_idx = 3 + k + 1
                    k += 2
                else:
                    ok = False
                    break
            if not ok or src_idx is None:
                continue
            if files is None:
                files = _registered_cred_files()
            if words[src_idx] in files:
                spans.append((s + toks[src_idx].start(), s + toks[src_idx].end()))
        return spans
    except Exception:
        return []


_CRED_SPANS = _cred_exempt_spans(_strip_heredocs(command), project_root)


# T-4751 (010-termlink be.17): the block message's own remedy,
#     <fw> config set BOUNDARY_EXTRA_READ_PATHS /path/one:/path/two
# names outside paths by design: the value is a path list being DECLARED, not read.
# That one value token is exempt from the read-side Patterns 4/4b, in that segment only.
# Strict grammar, as T-3766: the segment is exactly five words, its first word is this
# project's fw (absolute, or `bin/fw` / `.agentic-framework/bin/fw` while the cwd is the
# project root: the session cwd, and every earlier `cd` in the command names the root),
# the key is spelled canonically, the value is colon-joined absolute paths, and the raw
# segment has no quote, escape, `$`, backtick, redirection, glob, brace or `~`. Any other
# key, a sibling segment, or a path given to any other verb is judged as before. Fails
# closed: any error yields no exemption.
_EXTRA_KEY = 'BOUNDARY_EXTRA_READ_PATHS'
_EXTRA_VALUE = re.compile(r'^/[A-Za-z0-9._+@/-]*(:/[A-Za-z0-9._+@/-]*)*$')


def _config_extra_read_spans(cmd, root, cwd):
    try:
        roots = {root, os.path.realpath(root)}
        at_root = (cwd or root).rstrip('/') in roots or os.path.realpath(cwd or root) in roots
        spans = []
        mask = _segment_mask(cmd)
        for s, e in _split_segments(mask):
            words_m = list(re.finditer(r'\S+', mask[s:e]))
            words = [t.group(0) for t in words_m]
            if not words:
                continue
            if words[0] in ('cd', 'pushd', 'popd'):
                tgt = words[1].rstrip('/') if len(words) == 2 else ''
                at_root = bool(tgt) and (tgt in roots or os.path.realpath(tgt) in roots)
                continue
            if len(words) != 5 or words[1:4] != ['config', 'set', _EXTRA_KEY]:
                continue
            exe = words[0]
            if exe not in (root + '/bin/fw', root + '/.agentic-framework/bin/fw') \
                    and not (at_root and exe in ('bin/fw', '.agentic-framework/bin/fw')):
                continue
            if re.search(r'[\'"\\$`<>(){}*?\[\]~]', cmd[s:e]):
                continue
            if not _EXTRA_VALUE.match(words[4]):
                continue
            spans.append((s + words_m[4].start(), s + words_m[4].end()))
        return spans
    except Exception:
        return []


_EXTRA_SPANS = _config_extra_read_spans(_strip_heredocs(command), project_root,
                                        os.environ.get('_BOUNDARY_CWD', ''))
_CRED_SPANS = _CRED_SPANS + _EXTRA_SPANS

command = _strip_heredocs(command)   # T-2920: must precede _strip_quoted
command = _drop_termlink_segments(command, project_root)   # T-3076
command = _strip_quoted(command)

# F-25: a sibling git worktree of THIS repo is the same repository, not
# another project. `git worktree list` run against project_root only
# enumerates worktrees sharing project_root's own .git — a genuinely foreign
# project living at another /opt/* (or anywhere else) path is a DIFFERENT
# repository and never appears in this list, so this cannot be abused to
# admit an unrelated project. Fails closed: any error (not a git repo, git
# missing, timeout) yields an empty list and every pattern below behaves
# exactly as it did before this fix.
def _worktree_roots(root):
    try:
        proc = subprocess.run(
            ['git', '-C', root, 'worktree', 'list', '--porcelain'],
            capture_output=True, text=True, timeout=5,
        )
    except Exception:
        return []
    if proc.returncode != 0:
        return []
    roots = []
    for line in proc.stdout.splitlines():
        if line.startswith('worktree '):
            p = line[len('worktree '):].strip().rstrip('/')
            if p:
                roots.append(p)
    return roots


_WORKTREE_ROOTS = _worktree_roots(project_root)


def _in_sibling_worktree(path):
    p = path.rstrip('/')
    for wt in _WORKTREE_ROOTS:
        if p == wt or p.startswith(wt + '/'):
            return True
    return False


# Pattern 1: cd to absolute path outside project root
cd_pattern = re.compile(r'cd\s+(/[^\s;&|]+)')
matches = cd_pattern.findall(command)

for target_dir in matches:
    target = target_dir.rstrip('/')
    if not target.startswith(project_root + '/') and target != project_root:
        # Allow cd to safe zones
        if target.startswith('/tmp') or _in_claude_zone(target):
            continue
        if _in_sibling_worktree(target):   # F-25
            continue
        print(f'BLOCKED|cd to {target} (outside project root {project_root})')
        sys.exit(0)

# Pattern 2: Direct invocation of fw/agentic-framework tools on another path
fw_pattern = re.compile(r'(/[^\s]+/)\.agentic-framework/bin/fw\b')
for fw_path in fw_pattern.findall(command):
    fw_dir = fw_path.rstrip('/')
    if not fw_dir.startswith(project_root + '/') and fw_dir != project_root:
        if _in_sibling_worktree(fw_dir):   # F-25
            continue
        print(f'BLOCKED|Direct fw invocation on {fw_dir} (outside project root)')
        sys.exit(0)

# Pattern 3: File write operations targeting absolute paths outside project
#
# T-4114: tee is parsed, not matched. `tee\s+(/path)` saw only a path in the
# FIRST argument slot, so `tee -a /etc/fstab` (any option first) and
# `tee /tmp/ok /etc/x` (outside path second) both walked past it — and the
# read-side Pattern 4 allowlists /etc/, so nothing else caught them. Every
# argument of tee up to the end of its segment is a write target; options
# (`-a`, `--append`, `--output-error=warn`, `--`) are skipped, not terminators.
write_ops = re.compile(r'>>?\|?\s*(/[^\s;&|]+)')   # T-4126: `>|` (noclobber override)
_TEE_RE = re.compile(r'(?<![\w.-])tee(?![\w.-])')


def _tee_targets(cmd):
    for m in _TEE_RE.finditer(cmd):
        seg = re.split(r'[;&|<>()\n]', cmd[m.end():], maxsplit=1)[0]
        for tok in seg.split():
            if tok.startswith('/'):
                yield tok


# T-4126: the other write verbs. tee above takes every absolute token; these
# differ in WHICH operands are written, so each verb names its destinations.
# Reading from an outside path is Pattern 4's concern and is not touched here.
_WRAPPERS = {'sudo', 'env', 'nohup', 'command', 'exec', 'time', 'nice', 'ionice',
             'timeout', 'setsid', 'stdbuf', 'builtin', 'doas'}
# wrapper options that consume the next token (`sudo -u root cp ...`)
_WRAPPER_ARG_OPTS = {'sudo': {'-u', '-g', '-h', '-C', '-D', '-R', '-T', '-p', '-r', '-t', '-U'},
                     'doas': {'-u', '-C'}, 'env': {'-u', '-C', '-S'},
                     'nice': {'-n'}, 'ionice': {'-c', '-n', '-p'},
                     'timeout': {'-s', '-k'}, 'stdbuf': set()}
_ALL_ABS = {'chmod', 'chown', 'chgrp', 'truncate', 'touch', 'mkdir', 'mknod', 'mkfifo'}
_DEST_LAST = {'cp', 'install', 'ln', 'rsync'}
_TARGET_DIR_OPT = re.compile(r'^(?:--target-directory=(.*)|-t(.+))$')


def _write_verb_targets(cmd):
    for seg in re.split(r'[;&|<>()\n]', cmd):
        toks = seg.split()
        i = 0
        while i < len(toks):
            t = toks[i]
            base = t.rsplit('/', 1)[-1]
            if re.match(r'^[A-Za-z_][A-Za-z0-9_]*=', t):       # VAR=val prefix
                i += 1
            elif base in _WRAPPERS:
                i += 1
                while i < len(toks) and toks[i].startswith('-'):
                    i += 2 if toks[i] in _WRAPPER_ARG_OPTS.get(base, ()) else 1
                if base == 'timeout' and i < len(toks):          # DURATION operand
                    i += 1
            else:
                break
        if i >= len(toks):
            continue
        verb = toks[i].rsplit('/', 1)[-1]
        args = toks[i + 1:]
        opts_done = False
        pos, tdir, inplace, has_script_opt = [], [], False, False
        j = 0
        while j < len(args):
            a = args[j]
            j += 1
            if not opts_done and a == '--':
                opts_done = True
                continue
            if not opts_done and a.startswith('-') and a != '-':
                m = _TARGET_DIR_OPT.match(a) if verb in _DEST_LAST | {'mv'} else None
                if m:
                    tdir.append(m.group(1) or m.group(2))
                elif a in ('-t', '--target-directory') and verb in _DEST_LAST | {'mv'}:
                    if j < len(args):
                        tdir.append(args[j])
                        j += 1
                elif verb in ('sed', 'perl'):
                    if a.startswith('--'):
                        inplace = inplace or a.startswith('--in-place')
                        has_script_opt = has_script_opt or a.startswith(('--expression', '--file'))
                    else:
                        inplace = inplace or bool(re.match(r'^-[a-hj-zA-HJ-LN-Z]*i(\..*)?$', a))
                        if a in ('-e', '-f'):
                            has_script_opt = True
                            j += 1                              # script operand
                        elif a.startswith(('-e', '-f')) and verb == 'sed':
                            has_script_opt = True
                elif verb == 'truncate' and a in ('-s', '--size', '-r', '--reference'):
                    j += 1
                elif verb in ('chmod', 'chown', 'chgrp') and a in ('--reference',):
                    j += 1
                elif verb == 'touch' and a in ('-d', '-t', '-r', '--date', '--reference'):
                    j += 1
                elif verb == 'rsync' and a in ('-e', '--rsh', '--exclude', '--include',
                                               '--filter', '--rsync-path', '--log-file'):
                    j += 1
                continue
            pos.append(a)
        if verb == 'dd':
            for a in args:
                if a.startswith('of='):
                    yield a[3:]
        elif verb == 'mv':
            # a move removes every source and creates the destination
            for a in tdir + pos:
                yield a
        elif verb in _DEST_LAST:
            if tdir:
                for a in tdir:
                    yield a
            elif pos:
                yield pos[-1]
        elif verb in ('sed', 'perl'):
            if inplace:
                files = pos if (verb == 'perl' or has_script_opt) else pos[1:]
                for a in files:
                    yield a
        elif verb in ('chmod', 'chown', 'chgrp'):
            for a in pos[1:]:                                   # first positional = mode/owner
                yield a
        elif verb in _ALL_ABS:
            for a in pos:
                yield a


for target_file in (list(write_ops.findall(command)) + list(_tee_targets(command))
                    + [t for t in _write_verb_targets(command) if t.startswith('/')]):
    if target_file.startswith(('/tmp/', '/dev/', '/etc/cron.d/')) or _in_claude_zone(target_file):
        continue
    if not target_file.startswith(project_root + '/'):
        if _in_sibling_worktree(target_file):   # F-25
            continue
        print(f'BLOCKED|File write to {target_file} (outside project root)')
        sys.exit(0)

# Pattern 4 (T-1702 / G-065): read-side outside-path arguments.
# Detect absolute-path tokens (du /root/x, find /root/x, grep ... /root/x)
# even when they are not the target of a cd or write redirect. Quote-stripping
# already happened above, so this scans only "real" tokens, not string literals.
#
# Allowlist is broader than cd/write zones because reads are less destructive,
# but explicitly excludes /opt/<other-projects> and /root/<other-frameworks>
# (the original incident: agent du'd /root/.agentic-framework after the cd was
# already blocked).
READ_ALLOWED_PREFIXES = (
    project_root + '/',
    '/tmp/',
    '/usr/',
    '/etc/',
    '/var/log/',
    '/var/lib/',          # postgres data dirs etc — read-only inspection
    '/var/run/',          # pid files
    '/var/cache/',        # apt cache reads
    '/root/.local/',      # user shim install dir (Tier 0 reads)
    '/root/.claude/',     # Claude Code state
    '/proc/',
    '/sys/',
    '/dev/',
    '/bin/',
    '/sbin/',
    '/lib/',
    '/lib64/',
    '/opt/',              # exact /opt only — handled below; SUBDIRS narrowed
) + tuple(z + '/' for z in ((_HOME + '/.local', _HOME + '/.claude') if _HOME else ()))   # T-4361
# T-4731 (010-termlink T-3000): TermLink's own per-account state (~/.termlink: outbound
# queue, identity, hubs.toml) and the hub runtime dir are READ zones for every project
# that uses `fw termlink`. Writes keep their verdict: _write_guarded does not see these.
# /var/lib/termlink and /tmp/termlink-* are already covered above; a TERMLINK_RUNTIME_DIR
# elsewhere counts only when its last component names termlink, so `TERMLINK_RUNTIME_DIR=/opt`
# cannot open every project.
_TL_RT = os.path.realpath(os.environ.get('TERMLINK_RUNTIME_DIR', '') or '/')
READ_ALLOWED_PREFIXES += ('/root/.termlink/',) + ((_HOME + '/.termlink/',) if _HOME else ()) \
    + ((_TL_RT + '/',) if 'termlink' in os.path.basename(_TL_RT) else ())
# Exact-path allowlist (no trailing slash test).
READ_ALLOWED_EXACT = {
    project_root,
    '/tmp', '/usr', '/etc', '/proc', '/sys', '/dev',
    '/bin', '/sbin', '/lib', '/lib64', '/opt', '/var',
    '/root', '/home',
} | ({_HOME} if _HOME else set())   # T-4361: listing the account's own home, as /root

# Tokenize: split on whitespace and shell meta. For each /-starting token,
# strip surrounding shell punctuation that can lead it (none expected after
# whitespace split, but be defensive about trailing commas/semicolons).
def _tok_iter(cmd):
    # T-3766: blank the exempt credential-file tokens (length-preserving) first.
    if _CRED_SPANS:
        chars = list(cmd)
        for s_, e_ in _CRED_SPANS:
            for k in range(s_, e_):
                chars[k] = ' '
        cmd = ''.join(chars)
    for raw in re.split(r'[\s;&|()]+', cmd):
        if not raw:
            continue
        tok = raw.strip(',\'"`<>')
        if tok.startswith('/'):
            yield tok

_READ_ROOTS = {project_root, os.path.realpath(project_root)}


def _read_outside(cand):
    """True when the absolute path `cand` is outside the read-side allowlist."""
    # Only check what looks like a real path: at least one slash after the
    # leading one, OR a top-level dir we recognise (e.g. /etc).
    if cand in READ_ALLOWED_EXACT:
        return False
    if any(cand == r or cand.startswith(r + '/') for r in _READ_ROOTS):
        return False
    if _in_sibling_worktree(cand):   # F-25
        return False
    # T-4361: operator-allowed extra read paths (BOUNDARY_EXTRA_READ_PATHS). Checked
    # before the prefix list so an extra under /opt/ is not sent to the /opt narrowing.
    if any(cand == x or cand.startswith(x + '/') for x in _EXTRA_READ):
        return False
    # Allow paths with leading prefix in the explicit list.
    if any(cand == a.rstrip('/') or cand.startswith(a) for a in READ_ALLOWED_PREFIXES):
        # Special-case /opt/: only allow exactly /opt or /opt/<this-project>.
        # /opt/other-project must still block.
        if cand == '/opt' or cand.startswith('/opt/'):
            if cand == '/opt' or cand.startswith(project_root + '/') or cand == project_root:
                return False
            # /opt/<something-else> — fall through to BLOCK
        else:
            return False
    # Tokens that don't look like paths (single slash, e.g. regex `/foo`):
    # only block when they look filesystem-y. Heuristic: start with a known
    # top-level dir, OR contain at least 2 slashes under a top-level dir that
    # EXISTS on this host (T-4395: NAS mounts, /work, /data). An absent top has
    # nothing to read, and requiring it keeps sed/awk regex words such as
    # `/^## X/,/^## /p` or `/foo/p` from false-positiving.
    top = cand.split('/', 2)[1] if '/' in cand[1:] else cand[1:]
    KNOWN_TOPS = ('opt', 'root', 'home', 'srv', 'mnt', 'media',
                  'usr', 'etc', 'var', 'tmp', 'proc', 'sys', 'dev',
                  'bin', 'sbin', 'lib', 'lib64', 'boot', 'run')
    if top in KNOWN_TOPS:
        return True
    return cand.count('/') >= 2 and bool(top) and os.path.isdir('/' + top)


for tok in _tok_iter(command):
    if _read_outside(tok):
        print(f'BLOCKED|Outside-path argument {tok} (not in read-side allowlist)')
        sys.exit(0)

# Pattern 4b (T-3768): the same read-side predicate, over the words as BASH reads them.
#
# Pattern 4 scans the quote-BLANKED copy, so a quoted (`cat "/root/x"`), escaped
# (`/roo\t/x`), relative (`../../root/x`) or substituted (`<<< "$(cat /root/x)"`) path
# never reached it (codex round 4 on T-3766, docs/reports/T-3766-review-codex-r4.md).
# This pass hands the RAW command to lib/shell_write_scan.py's tokeniser (the one
# Pattern 5 uses for writes) in read mode: quote/escape removal, `..` resolved against
# the cd-tracked cwd, `~`/`$HOME`, brace expansion, and the bodies of $(...), backticks,
# here-strings, unquoted heredocs and static `sh -c`/`eval`. Prose stays safe because a
# quoted message is ONE word (`-m "fix /root/x"` does not start with `/`); a word that
# IS a path, quoted or not, is judged as one. Only ever adds refusals.
#
# Exemptions are applied to the raw text by blanking, never by skipping the pass: the
# TermLink segments (T-3076, whole segment) and the registered credential token of the
# sanctioned resolver form (T-3766).
def _read_scan_text(raw, root):
    chars = list(raw)
    try:
        spans = list(_termlink_spans(_strip_heredocs(raw), root))
    except Exception:
        spans = []
    for s_, e_ in spans + list(_CRED_SPANS):
        for k in range(s_, min(e_, len(chars))):
            if chars[k] != '\n':
                chars[k] = ' '
    return ''.join(chars)


try:
    sys.path.insert(0, os.environ.get('_BOUNDARY_FW_LIB', ''))
    import shell_write_scan
    _rhits = shell_write_scan.scan_boundary_reads(
        _read_scan_text(_BOUNDARY_CMD_RAW, project_root),
        os.environ.get('_BOUNDARY_CWD', '') or project_root, _read_outside)
except Exception as e:   # fail closed, as Pattern 5 does
    _rhits = [type('H', (), {'reason': f'boundary read tokeniser unavailable ({type(e).__name__})',
                             'target': ''})()]
if _rhits:
    h = _rhits[0]
    tgt = f' {h.target}' if h.target else ''
    print(f'BLOCKED|{h.reason}{tgt} (not in read-side allowlist)')
    sys.exit(0)

# Pattern 5 (T-4149): the write targets and cd destinations as BASH reads them.
#
# Patterns 1-3 read a quote-BLANKED copy with regexes, so their reading differed from
# bash: `touch "/etc/X"` (target blanked), `to""uch /etc/X` (verb not recognised),
# `touch /tmp/../etc/X` (prefix test before normalising), `> /tmp/x touch /etc/X`
# (leading redirection taken as the verb), `sed -ibak … /etc/X` (suffix cluster) all
# passed. This pass hands the RAW command to lib/shell_write_scan.py — the bash-style
# tokeniser T-3695 already uses for the task-file guard — in boundary mode: quote
# removal, realpath+normpath of every target, brace/tilde expansion, redirections
# anywhere, option clusters, $(...)/`...`/<(...) bodies, unquoted heredoc bodies and
# static `sh -c`/`eval` scripts. Text that does not lex is refused, not guessed.
# Patterns 1-4 stay: this pass only ever adds refusals.
#
# NOT seen (same boundary as Tier 0, CLAUDE.md T-2742): a script file the command runs,
# a target built at run time ($VAR, printf, a path read from a file), code inside an
# interpreter (python -c, perl -e, awk), and write verbs the scanner does not name.
_ROOTS = {project_root, os.path.realpath(project_root)}
_ZONES = tuple(sorted({z for p in ('/tmp', '/dev', '/etc/cron.d') + _CLAUDE_ZONES
                       for z in (p, os.path.realpath(p))}))


def _under(p, base):
    return p == base or p.startswith(base.rstrip('/') + '/')


def _write_guarded(p):
    p = p.rstrip('/') or '/'
    if any(_under(p, r) for r in _ROOTS) or any(_under(p, z) for z in _ZONES):
        return False
    return not _in_sibling_worktree(p)


def _cd_ok(p):
    p = p.rstrip('/') or '/'
    # `cd /` (leaving a temp dir before `rm -rf $T`) is not another project; a relative
    # write after it resolves under / and is judged as a write.
    return (p == '/' or any(_under(p, r) for r in _ROOTS) or _under(p, '/tmp')
            or any(_under(p, z) for z in _CLAUDE_ZONES) or _in_sibling_worktree(p))


try:
    sys.path.insert(0, os.environ.get('_BOUNDARY_FW_LIB', ''))
    import shell_write_scan
    _hits = shell_write_scan.scan_boundary(
        _BOUNDARY_CMD_RAW,
        os.environ.get('_BOUNDARY_CWD', '') or project_root,
        _write_guarded, _cd_ok)
except Exception as e:   # fail closed: an unreadable command is not a safe one
    _hits = [type('H', (), {'reason': f'boundary tokeniser unavailable ({type(e).__name__})',
                            'target': ''})()]
if _hits:
    h = _hits[0]
    tgt = f' {h.target}' if h.target else ''
    print(f'BLOCKED|{h.reason}{tgt} (outside project root {project_root})')
    sys.exit(0)

# T-4751: a verdict that used the BOUNDARY_EXTRA_READ_PATHS exemption says so, for the log.
_cmd_raw = _strip_heredocs(_BOUNDARY_CMD_RAW)
print('SAFE|' + ' '.join(_cmd_raw[s_:e_] for s_, e_ in _EXTRA_SPANS) if _EXTRA_SPANS else 'SAFE')
PYEOF
)
    [ -n "${_BOUNDARY_CMD_FILE:-}" ] && rm -f "$_BOUNDARY_CMD_FILE"

    # T-4652: the matcher always prints SAFE or BLOCKED; no output means it crashed.
    if [ -z "$MATCH_RESULT" ]; then
        hook_degraded_boundary "$INPUT" "python matcher produced no verdict (crash or nonzero exit)"
        exit 0
    fi
    if [ "$MATCH_RESULT" = "SAFE" ]; then
        exit 0
    fi
    # T-4751: the block message's remedy (declaring BOUNDARY_EXTRA_READ_PATHS) passed on
    # its exemption; record it Tier-2 so a widened read boundary is never silent.
    if [ "${MATCH_RESULT%%|*}" = "SAFE" ]; then
        _bd_log="$PROJECT_ROOT/.context/working/.gate-bypass-log.yaml"
        mkdir -p "${_bd_log%/*}" 2>/dev/null && {
            echo "- timestamp: '$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
            echo "  gate: 'check-project-boundary'"
            echo "  flag: 'config-set-BOUNDARY_EXTRA_READ_PATHS'"
            echo "  value: '${MATCH_RESULT#SAFE|}'"
            echo "  reason: 'declared read path list exempt from outside-path argument check (T-4751)'"
        } >> "$_bd_log" 2>/dev/null
        exit 0
    fi

    DESCRIPTION="${MATCH_RESULT#BLOCKED|}"

    echo "" >&2
    echo "══════════════════════════════════════════════════════════" >&2
    echo "  PROJECT BOUNDARY BLOCK — Command Targets Another Project" >&2
    echo "══════════════════════════════════════════════════════════" >&2
    echo "" >&2
    echo "  Reason: $DESCRIPTION" >&2
    echo "  Command: ${COMMAND:0:150}" >&2
    echo "" >&2
    echo "  Bash commands must operate within the current project." >&2
    echo "" >&2
    echo "  For legitimate cross-project work, use TermLink dispatch which" >&2
    echo "  runs the command in the target project's own session context:" >&2
    echo "" >&2
    echo "    $(_fw_cmd) termlink dispatch --name work --project /opt/other \\" >&2
    echo "      --prompt 'describe the work for the target project'" >&2
    echo "" >&2
    echo "  Or spawn an interactive TermLink session rooted in the target:" >&2
    echo "" >&2
    echo "    termlink spawn --name work --backend background --shell \\" >&2
    echo "      --wait --tags 'task:T-XXX' --cwd /opt/other" >&2
    echo "" >&2
    echo "  Neither path crosses the boundary of *this* session; each" >&2
    echo "  target project enforces its own governance in its own process." >&2
    echo "" >&2
    echo "  To let this project READ an extra path (e.g. a tool install dir):" >&2
    # T-4751: a project-local fw, so the line passes this hook's own exemption verbatim
    # (a bare PATH `fw`, which _fw_cmd may print, is not trusted to be this project's).
    _bd_fw=".agentic-framework/bin/fw"
    [ "$PROJECT_ROOT" = "$FRAMEWORK_ROOT" ] && _bd_fw="bin/fw"
    echo "    cd $PROJECT_ROOT && $_bd_fw config set BOUNDARY_EXTRA_READ_PATHS /path/one:/path/two" >&2
    echo "" >&2
    echo "  Project root: $PROJECT_ROOT" >&2
    echo "" >&2
    echo "  Policy: T-559 (Project Boundary Enforcement)" >&2
    echo "══════════════════════════════════════════════════════════" >&2
    echo "" >&2
    exit 2
fi

# Not a Write/Edit/Bash tool — allow
exit 0
