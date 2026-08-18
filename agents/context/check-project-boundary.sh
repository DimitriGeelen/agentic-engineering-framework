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
# Origin: T-559 (cd block) → T-1702 (read-side block, G-065 fix).
# Part of: Agentic Engineering Framework (P-002: Structural Enforcement)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$FRAMEWORK_ROOT/lib/paths.sh"
source "$FRAMEWORK_ROOT/lib/config.sh"
fw_hook_crash_trap "check-project-boundary"

# Read stdin (JSON from Claude Code)
INPUT=$(cat)

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

    # Quick pre-filter: if no absolute path reference, skip Python analysis.
    # T-1702: include any leading-slash token (read-side detection needs to see
    # /root, /var, /home etc. even when they are not write/cd targets).
    if ! echo "$COMMAND" | grep -qE '(cd\s+/|/opt/|/home/|/root/|/var/|/etc/|/usr/|>+\s*/|tee\s+/|\.agentic-framework/bin/fw)'; then
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
    export _BOUNDARY_CMD="$COMMAND"
    MATCH_RESULT=$(python3 << 'PYEOF'
import re, sys, os

command = os.environ.get('_BOUNDARY_CMD', '')
project_root = os.environ.get('PROJECT_ROOT', '')

# Normalize project root (remove trailing slash)
project_root = project_root.rstrip('/')

if not project_root:
    print('SAFE')
    sys.exit(0)

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
        mask = _strip_quoted(cmd)
        out = list(cmd)
        hit = False
        for s, e in _split_segments(mask):
            if s >= e:
                continue
            if _segment_invokes_termlink(mask[s:e], root):
                hit = True
                for k in range(s, e):
                    if out[k] != '\n':
                        out[k] = ' '
        return ''.join(out) if hit else cmd
    except Exception:
        return cmd


command = _strip_heredocs(command)   # T-2920: must precede _strip_quoted
command = _drop_termlink_segments(command, project_root)   # T-3076
command = _strip_quoted(command)

# Pattern 1: cd to absolute path outside project root
cd_pattern = re.compile(r'cd\s+(/[^\s;&|]+)')
matches = cd_pattern.findall(command)

for target_dir in matches:
    target = target_dir.rstrip('/')
    if not target.startswith(project_root + '/') and target != project_root:
        # Allow cd to safe zones
        if target.startswith('/tmp') or target.startswith('/root/.claude'):
            continue
        print(f'BLOCKED|cd to {target} (outside project root {project_root})')
        sys.exit(0)

# Pattern 2: Direct invocation of fw/agentic-framework tools on another path
fw_pattern = re.compile(r'(/[^\s]+/)\.agentic-framework/bin/fw\b')
for fw_path in fw_pattern.findall(command):
    fw_dir = fw_path.rstrip('/')
    if not fw_dir.startswith(project_root + '/') and fw_dir != project_root:
        print(f'BLOCKED|Direct fw invocation on {fw_dir} (outside project root)')
        sys.exit(0)

# Pattern 3: File write operations targeting absolute paths outside project
write_ops = re.compile(r'(?:>>?\s*|tee\s+)(/[^\s;&|]+)')
for target_file in write_ops.findall(command):
    if target_file.startswith(('/tmp/', '/root/.claude/', '/dev/', '/etc/cron.d/')):
        continue
    if not target_file.startswith(project_root + '/'):
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
)
# Exact-path allowlist (no trailing slash test).
READ_ALLOWED_EXACT = {
    project_root,
    '/tmp', '/usr', '/etc', '/proc', '/sys', '/dev',
    '/bin', '/sbin', '/lib', '/lib64', '/opt', '/var',
    '/root', '/home',
}

# Tokenize: split on whitespace and shell meta. For each /-starting token,
# strip surrounding shell punctuation that can lead it (none expected after
# whitespace split, but be defensive about trailing commas/semicolons).
def _tok_iter(cmd):
    for raw in re.split(r'[\s;&|()]+', cmd):
        if not raw:
            continue
        tok = raw.strip(',\'"`<>')
        if tok.startswith('/'):
            yield tok

for tok in _tok_iter(command):
    # Only check what looks like a real path: at least one slash after the
    # leading one, OR a top-level dir we recognise (e.g. /etc).
    if tok in READ_ALLOWED_EXACT:
        continue
    # Strip glob characters off the end so /var/log/* is checked as /var/log/
    cand = tok
    # Allow paths with leading prefix in the explicit list.
    if any(cand == a.rstrip('/') or cand.startswith(a) for a in READ_ALLOWED_PREFIXES):
        # Special-case /opt/: only allow exactly /opt or /opt/<this-project>.
        # /opt/other-project must still block.
        if cand == '/opt' or cand.startswith('/opt/'):
            if cand == '/opt' or cand.startswith(project_root + '/') or cand == project_root:
                continue
            # /opt/<something-else> — fall through to BLOCK
        else:
            continue
    # Tokens that don't look like paths (single slash, e.g. regex `/foo`):
    # only block when they look filesystem-y. Heuristic: must contain at least
    # 2 slashes OR start with a known top-level dir.
    top = cand.split('/', 2)[1] if '/' in cand[1:] else cand[1:]
    KNOWN_TOPS = ('opt', 'root', 'home', 'srv', 'mnt', 'media',
                  'usr', 'etc', 'var', 'tmp', 'proc', 'sys', 'dev',
                  'bin', 'sbin', 'lib', 'lib64', 'boot', 'run')
    if top not in KNOWN_TOPS:
        continue  # not a recognisable filesystem path; skip rather than FP
    print(f'BLOCKED|Outside-path argument {cand} (not in read-side allowlist)')
    sys.exit(0)

print('SAFE')
PYEOF
)

    if [ -z "$MATCH_RESULT" ] || [ "$MATCH_RESULT" = "SAFE" ]; then
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
    echo "  Project root: $PROJECT_ROOT" >&2
    echo "" >&2
    echo "  Policy: T-559 (Project Boundary Enforcement)" >&2
    echo "══════════════════════════════════════════════════════════" >&2
    echo "" >&2
    exit 2
fi

# Not a Write/Edit/Bash tool — allow
exit 0
