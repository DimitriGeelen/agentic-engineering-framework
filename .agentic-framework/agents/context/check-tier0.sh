#!/bin/bash
# Tier 0 Enforcement Hook — PreToolUse gate for Bash tool
# Detects destructive commands and blocks them unless explicitly approved.
#
# Exit codes (Claude Code PreToolUse semantics):
#   0 — Allow tool execution
#   2 — Block tool execution (stderr shown to agent)
#
# Flow:
#   1. Extract bash command from stdin JSON
#   2. Quick keyword check (bash grep — no Python overhead for safe commands)
#   3. If keywords found, Python detailed pattern matching
#   4. If destructive pattern matched:
#      a. Check for one-time approval token
#      b. If valid approval: allow, log, delete token
#      c. If no approval: block with explanation
#   5. If no match: allow
#
# ── SCOPE BOUNDARY (T-2742) — read this before trusting a green ──────────────
# This hook inspects ONE THING: the `tool_input.command` STRING from the
# PreToolUse JSON (see the extraction below). It never opens, reads, or follows
# any file that the command refers to.
#
# Therefore a destructive operation is invisible to this gate whenever it is not
# spelled out in the command string itself:
#
#     bash ./build.sh          # build.sh may `rm -rf "$OUT"` — NOT inspected
#     make clean               # the recipe is NOT inspected
#     python3 deploy.py        # NOT inspected
#     ./agents/foo/foo.sh      # NOT inspected
#
# The keyword pre-filter below exits 0 for any of those on the first check,
# because the string carries no destructive keyword. This is a scope boundary,
# not a defect — inspecting arbitrary interpreted files is a different and much
# larger problem. It is written here because its absence reads as coverage:
# every Tier 0 block anyone has hit came from a TYPED command, so the gate's
# apparent reliability is evidence about agent habits, not about coverage.
#
# The consequence for an agent-authored script that an agent then executes: the
# script is governed at write time (Tier 1, check-active-task.sh) and NOT at run
# time. Tier 0 is not a backstop for what a script does.
#
# Pinned by tests/unit/tier0_scope_boundary.bats — a characterization test, so
# this comment is falsifiable. If coverage is ever extended, that test goes red
# and this block must change with it.
#
# Origin: 832 lost a working tree this way (their G-018, high) — a mutated build
# script ran `rm -rf "$OUT"` with the variable pointing at their repo root. Our
# instance verified independently against this source: OBS-138.
# ────────────────────────────────────────────────────────────────────────────
#
# Part of: Agentic Engineering Framework
# Spec: 011-EnforcementConfig.md §Tier 0 (Unconditional Enforcement)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$FRAMEWORK_ROOT/lib/paths.sh"
source "$FRAMEWORK_ROOT/lib/config.sh"
source "$FRAMEWORK_ROOT/lib/watchtower.sh"
fw_hook_crash_trap "check-tier0"
APPROVAL_FILE="$PROJECT_ROOT/.context/working/.tier0-approval"

# Read stdin JSON from Claude Code
INPUT=$(cat)

# T-3593 round 7: the exact-text approval key is the sha256 of the ORIGINAL
# command bytes, computed from the JSON value itself (a shell variable would
# already have lost trailing newlines and any NUL). No whitespace is collapsed
# anywhere: quoted whitespace is part of an argument, so collapsing it made
# rm -rf ./ "a  b" and rm -rf ./ "a b" share one approval (codex R6 HIGH).
# Retries no longer need text normalisation: duplicate fires of one call are
# recognised by tool_use_id (round 4), and a mapped command matches by action.
COMMAND_HASH=$(echo "$INPUT" | python3 -c "
import sys, json, hashlib
try:
    c = json.load(sys.stdin).get('tool_input', {}).get('command', '')
    print(hashlib.sha256(c.encode('utf-8', 'surrogatepass')).hexdigest() if c else '')
except Exception:
    print('')
" 2>/dev/null)

# Extract the bash command via Python (handles JSON properly)
COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('tool_input', {}).get('command', ''))
except:
    print('')
" 2>/dev/null)

# T-3593: the session cwd, so relative paths and the current branch in a blocked
# command resolve to the same action the operator is shown. Absent → unknown,
# and anything that depends on it stays on the legacy hash path.
T0_CWD=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    print(json.load(sys.stdin).get('cwd', '') or '')
except Exception:
    print('')
" 2>/dev/null)
[ -n "$T0_CWD" ] || T0_CWD="$PWD"

# T-3593 round 4: the id of THIS tool call. A hook registered twice fires twice
# for one call with the same id; two calls never share one. Deduplication of
# duplicate fires is bound to it (see the T-1508 block below). Absent → "",
# and a duplicate fire then gets no grace (fails closed).
T0_CALL_ID=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    print(json.load(sys.stdin).get('tool_use_id', '') or '')
except Exception:
    print('')
" 2>/dev/null)
case "$T0_CALL_ID" in *[!A-Za-z0-9_-]*) T0_CALL_ID="" ;; esac

# If no command extracted, allow (defensive — don't block on parse failure)
if [ -z "$COMMAND" ]; then
    exit 0
fi

# ── Fast path: keyword pre-filter (bash grep, no Python overhead) ──
# Only invoke Python if the command MIGHT be destructive.
# This keeps the hook fast (<5ms) for the 95%+ of safe commands.
# Round 5: the filter also sees a dequoted copy (quotes, backslashes and dollars
# removed), so a spelling the shell reassembles (tier""0, appr\ove) reaches the
# detailed match.
T0_DEQUOTED=$(printf '%s' "$COMMAND" | tr -d "\"'\\\\\$")
# Round 6: ANSI-C quoting ($'tier\x30') is decoded in Python, so any $' skips
# the fast path.
if [[ "$COMMAND" != *"\$'"* ]] && ! printf '%s\n%s\n' "$COMMAND" "$T0_DEQUOTED" | grep -qEi \
    'git\s+(push|reset|clean|checkout|restore|branch)\s|git\s+-|git\s+commit\b[^;|&]*\s-[a-z]*n|(HOME|XDG_CONFIG_HOME|GIT_CONFIG[A-Z0-9_]*)=|hooksPath|include\.path|includeif|tier0|--no-v|rm\s+-|DROP\s|TRUNCATE\s|docker\s+system|kubectl\s+delete|find\s.*-delete|dd\s+if=|chmod\s.*\s000|mkfs|pkill\s|fw\s.*--force|fw\s.*inception\s.*decide'; then
    exit 0
fi

# ── Detailed pattern matching (Python — only reached for suspicious commands) ──
MATCH_RESULT=$(echo "$COMMAND" | T0_CWD="$T0_CWD" T0_ROOT="$PROJECT_ROOT" T0_FRAMEWORK_ROOT="$FRAMEWORK_ROOT" python3 -c "
import re, sys

command = sys.stdin.read().strip()

# Strip heredoc body contents to avoid false positives on embedded text.
# Matches: <<[-]?['\"']?WORD['\"']? ... WORD (on own line)
def strip_heredocs(cmd):
    return re.sub(
        r'(<<-?\s*)[\'\"]?(\w+)[\'\"]?([^\n]*\n)'
        r'.*?'
        r'(\n[ \t]*\2[ \t]*(?:\n|$))',
        r'\1\2\3\4',
        cmd,
        flags=re.DOTALL,
    )

# Strip quoted string contents to avoid false positives on commit messages,
# echo arguments, and embedded Python/test code.
# T-3593 round 3: but a quoted WORD with no whitespace inside is what the shell
# passes as one argument - quoting an option name hides nothing from git:
# '--no-verify', --no-'verify', \"--force\" are all the option. Such words are
# dequoted instead of blanked; multi-word strings (messages, code) are blanked.
SQ, DQ = chr(39), chr(34)
_QPART = SQ + '([^' + SQ + ']*)' + SQ + '|' + DQ + '([^' + DQ + ']*)' + DQ
_QWORD = re.compile(r'(?:[^\s' + SQ + DQ + ']|' + SQ + '[^' + SQ + ']*' + SQ + '|' + DQ + '[^' + DQ + ']*' + DQ + ')+')
def strip_quotes(cmd):
    def word(m):
        w = m.group(0)
        if SQ not in w and DQ not in w:
            return w
        inner = re.sub(_QPART, lambda q: q.group(1) if q.group(1) is not None else q.group(2), w)
        if not re.search(r'\s', inner):
            return inner
        w = re.sub(SQ + '[^' + SQ + ']*' + SQ, SQ + SQ, w)
        return re.sub(DQ + '[^' + DQ + ']*' + DQ, DQ + DQ, w)
    return _QWORD.sub(word, cmd)

# T-1427: Strip bash comments (# through end-of-line) so that commented-out
# references to Tier 0 phrases in diagnostic/exploratory commands don't
# trigger false-positive blocks. Bash treats # as a comment only at the
# start of a token — i.e. at line start or preceded by whitespace. An
# unescaped # after non-whitespace (like URL fragments) is NOT a comment.
# Apply AFTER strip_quotes so # inside quoted strings is already neutralized.
def strip_comments(cmd):
    return re.sub(r'(^|\s)#[^\n]*', r'\1', cmd)

command_stripped = strip_heredocs(command)
command_stripped = strip_quotes(command_stripped)
command_stripped = strip_comments(command_stripped)

# Tier 0 destructive patterns — high confidence, low false positive
# Each tuple: (regex_pattern, risk_description)
# T-3594 A2: 'git -C dir push' and 'git -c k=v push' are pushes too; the push
# patterns below match them as well as a plain git push.
# Round 4: any short global option (-P, -p) and a long option with a separate
# argument (--git-dir /x) too — 'git -P push -f' escaped every push pattern.
# Round 5 (codex HIGH): a word may contain an escaped space — 'git -C /tmp/a\\ b
# push -f' is one -C argument, and the old \\S+ lost the boundary (SAFE).
W = '(?:' + re.escape(chr(92)) + r'\s|\S)+'
GIT_PRE = r'\bgit\s+(?:-[cC]\s*' + W + r'\s+|-[a-zA-Z]+\s+|--[\w-]+(?:=' + W + r'|\s+[^-\s](?:' + W + r')?)?\s+)*'
GIT_PUSH = GIT_PRE + r'push\b'

# T-3593 round 3: git's parse-options accepts any unambiguous PREFIX of a long
# option (--no-verif is --no-verify, --force-w is --force-with-lease, reset --h
# is --hard). ab(name) matches every prefix of --name from the first keep
# characters on, and nothing longer; over-matching a prefix git would reject as
# ambiguous only blocks a command that would have failed anyway.
def ab(name, keep=1):
    tail = ''
    for ch in reversed(name[keep:]):
        tail = '(?:' + re.escape(ch) + tail + ')?'
    return '--' + re.escape(name[:keep]) + tail + r'(?![\w-])'

OPT_FORCE = ab('force-with-lease')
OPT_DELETE = ab('delete')
OPT_NO_VERIFY = ab('no-verify', 4)
APPROVE_VERB = r'(?:\bfw\s+tier0\s+approve\b|\btier0_action\b)'

PATTERNS = [
    # === Git destructive operations ===
    (GIT_PUSH + r'[^;|&]*(\s-[a-zA-Z0-9]*f[a-zA-Z0-9]*\b|' + OPT_FORCE + ')',
     'FORCE PUSH: Can overwrite remote commit history'),
    # T-3593: forced refspec (+ref) and remote ref deletion are the same class
    # as --force; they were not matched before. The pre-push hook (T-3594)
    # enforces both at the ref level regardless of how the push was typed.
    (GIT_PUSH + r'[^;|&]*\s\+[^\s;|&]',
     'FORCE PUSH: +refspec overwrites remote commit history'),
    (GIT_PUSH + r'[^;|&]*(\s-[a-zA-Z0-9]*d[a-zA-Z0-9]*\b|' + OPT_DELETE + r'|\s:[^\s;|&])',
     'REMOTE REF DELETE: Deletes a branch or tag on the remote'),
    (GIT_PRE + r'reset\b[^;|&]*' + ab('hard'),
     'HARD RESET: Permanently discards all uncommitted changes'),
    (r'\bgit\s+clean\b[^;|&]*-[a-zA-Z]*f',
     'GIT CLEAN: Permanently removes untracked files'),
    (r'\bgit\s+(checkout|restore)\s+\.\s*(\s*$|[;&|])',
     'RESTORE ALL: Discards all unstaged changes in working directory'),
    (GIT_PRE + r'branch\b[^;|&]*\s-[a-zA-Z]*D',
     'FORCE DELETE BRANCH: Deletes branch even if changes are unmerged'),
    (GIT_PRE + r'branch\b(?=[^;|&]*(?:\s-[a-zA-Z]*d|' + OPT_DELETE + r'))(?=[^;|&]*(?:\s-[a-zA-Z]*f|' + ab('force') + r'))',
     'FORCE DELETE BRANCH: --delete --force deletes a branch even if changes are unmerged'),

    # === Catastrophic file deletion ===
    # rm with recursive flag targeting dangerous paths
    # Round 4: a closing ')' ends the target too — '(cd sub && rm -rf *)'.
    (r'\brm\s+[^;|&]*-[a-zA-Z]*[rR][a-zA-Z]*[^;|&]*\s+/(\s|$|;|&|\)|\*)',
     'RECURSIVE DELETE: Targets root filesystem (/)'),
    (r'\brm\s+[^;|&]*-[a-zA-Z]*[rR][a-zA-Z]*[^;|&]*\s+(~|\\\$HOME)(\s|$|;|&|\)|/)',
     'RECURSIVE DELETE: Targets home directory'),
    (r'\brm\s+[^;|&]*-[a-zA-Z]*[rR][a-zA-Z]*[^;|&]*\s+\.\s*($|[;&|)])',
     'RECURSIVE DELETE: Targets current directory (.)'),
    (r'\brm\s+[^;|&]*-[a-zA-Z]*[rR][a-zA-Z]*[^;|&]*\s+\*(\s|$|;|&|\))',
     'RECURSIVE DELETE: Targets everything via wildcard (*)'),
    # Round 5: 'rm -rf sub/../..', '..', 'x/.', './' name a parent or the
    # current directory without spelling '.' or '/' alone (the bare '.' case
    # is the pattern above).
    (r'\brm\s+[^;|&]*-[a-zA-Z]*[rR][a-zA-Z]*[^;|&]*\s(?!\.(?:\s|$|[;&|)]))(?:\S*/)?\.\.?/?(?=\s|$|[;&|)])',
     'RECURSIVE DELETE: Targets a parent or the current directory (. or .. as the last path component)'),

    # === Database destructive ===
    (r'(?i)\bDROP\s+(TABLE|DATABASE|SCHEMA)\b',
     'SQL DROP: Permanent data destruction'),
    (r'(?i)\bTRUNCATE\s+TABLE\b',
     'SQL TRUNCATE: Permanent data destruction'),

    # === Hook/enforcement bypass ===
    (r'\bgit\b[^;|&]*' + OPT_NO_VERIFY,
     'HOOK BYPASS: --no-verify skips ALL git hooks (task ref, inception gate, audit)'),
    (GIT_PRE + r'commit\b[^;|&]*\s-[a-zA-Z]*n',
     'HOOK BYPASS: git commit -n is --no-verify (skips pre-commit and commit-msg hooks)'),
    # T-3594 A2: a core.hooksPath override skips every hook as surely as
    # --no-verify, including the pre-push forced-update guard. Reads pass.
    # Round 3: config keys are case-insensitive (core.hookspath works), and
    # --config-env / GIT_CONFIG_* set the same key without -c.
    # Round 4: include.path / includeIf pull config (hooksPath included) from a
    # file; a -c value that strip_quotes blanked ('' / \"\") cannot be read.
    # Round 5 (T-3610 false positive): the -c must be GIT'S global option, in
    # the global-option position — not any -c after a '.git' path (stat -c,
    # bash -c on a later line).
    (r'(?<!\.)' + GIT_PRE + r'(?:-c\s*|--config-env[=\s]\s*)(?:(?i:core\.hookspath|include\.path)\s*=|(?i:includeif)\.|' + SQ + SQ + '|' + DQ + DQ + ')',
     'HOOK BYPASS: -c core.hooksPath / include.path overrides the hook directory (skips pre-push and all other hooks)'),
    # Round 5 (Claude F2): a persistent include.path / includeIf.* pulls in a
    # file that can set core.hooksPath, for every later push.
    (GIT_PRE + r'config\b(?![^;|&]*--(get|list|show|get-all|get-regexp)\b)[^;|&]*\b(?i:core\.hookspath|include\.path|includeif\.\S*)\s+\S',
     'HOOK BYPASS: setting core.hooksPath / include.path / includeIf.* redirects every git hook (skips pre-push and all other hooks)'),
    (r'\bGIT_CONFIG_(?:PARAMETERS|KEY_\d+)=\S*(?i:core\.hookspath)',
     'HOOK BYPASS: GIT_CONFIG_PARAMETERS / GIT_CONFIG_KEY_n sets core.hooksPath for git (skips pre-push and all other hooks)'),
    # Round 4 (N1): every environment variable that selects a config file git
    # reads, or carries config itself, can set core.hooksPath — whatever its
    # value says, which strip_quotes may have blanked (a multi-setting
    # GIT_CONFIG_PARAMETERS). Labelled whenever a hook-running git command
    # follows it anywhere in the command (prefix, env, export; ...).
    (r'\b(?:HOME|XDG_CONFIG_HOME|GIT_CONFIG|GIT_CONFIG_GLOBAL|GIT_CONFIG_SYSTEM|GIT_CONFIG_PARAMETERS|GIT_CONFIG_COUNT|GIT_CONFIG_KEY_\d+|GIT_CONFIG_VALUE_\d+)=[\s\S]*?'
     + GIT_PRE + r'(?:push|commit|merge|pull|rebase|am|cherry-pick|revert)\b',
     'HOOK BYPASS: HOME / XDG_CONFIG_HOME / GIT_CONFIG* select or carry git config, which can set core.hooksPath (skips pre-push and all other hooks)'),

    # === Tier 0 self-approval (T-3593 R2) ===
    # Approval is the operator's. The module refuses under CLAUDECODE=1 unless
    # overridden; the override is recorded as agent-override. Typed, both are Tier 0.
    (r'\btier0_action\b[^;|&]*\bapprove',
     'TIER 0 SELF-APPROVAL: approving a Tier 0 action is human-only (direct module path)'),
    # Round 3 (R2 residue): stripping CLAUDECODE makes the module record
    # approved_by: human. Typed, the env-strip route is Tier 0.
    (r'\bCLAUDECODE=[\s\S]*' + APPROVE_VERB,
     'TIER 0 SELF-APPROVAL: CLAUDECODE= in front of an approval makes an agent look human'),
    (r'\benv\b[^;|&]*' + APPROVE_VERB,
     'TIER 0 SELF-APPROVAL: env-wrapped approval (env -u CLAUDECODE / env -i) makes an agent look human'),
    (r'\bunset\b[^;|&]*\bCLAUDECODE\b[\s\S]*' + APPROVE_VERB,
     'TIER 0 SELF-APPROVAL: unset CLAUDECODE before an approval makes an agent look human'),
    (r'\bfw\s+tier0\s+approve\b[^;|&]*--i-am-human\b',
     'TIER 0 SELF-APPROVAL: fw tier0 approve --i-am-human from an agent session approves its own block'),

    # === Destructive file operations (B-003) ===
    (r'\bfind\b[^;|&]*-delete\b',
     'FIND DELETE: Recursively deletes matching files'),
    (r'\bdd\s+if=',
     'DD: Raw disk/device write — can overwrite filesystems'),
    (r'\bchmod\b[^;|&]*-[a-zA-Z]*R[^;|&]*\s+000\b',
     'CHMOD 000 RECURSIVE: Removes all permissions recursively'),
    (r'\bmkfs\b',
     'MKFS: Creates filesystem — destroys existing data on device'),
    (r'\bpkill\s+-9\b',
     'PKILL -9: Force-kills processes by name (SIGKILL)'),

    # === Infrastructure destructive ===
    (r'\bdocker\s+system\s+prune\b',
     'DOCKER PRUNE: Removes all unused containers, networks, images'),
    (r'\bkubectl\s+delete\s+(namespace|ns)\s',
     'K8S NAMESPACE DELETE: Removes namespace and all resources in it'),

    # === Framework governance bypass (T-510) ===
    (r'\bfw\s+task\s+update\b[^;|&]*--force\b',
     'FW FORCE: Bypasses sovereignty gate (R-033), AC verification (P-010), or verification gate (P-011)'),

    # === Inception decision gate (T-557) ===
    # GO/NO-GO decisions are authority, not initiative. Agent recommends, human decides.
    (r'\bfw\s+inception\s+decide\b',
     'INCEPTION DECISION: GO/NO-GO decisions require human authority. Present your recommendation and rationale, then ask the human to run: fw inception decide T-XXX go|no-go --rationale \"...\"'),
]

# Matched against the command with only heredocs stripped: the call lives in
# quoted code (python3 -c '... tier0_action.approve(...)'), which strip_quotes
# blanks (round 3, R2 residue).
RAW_PATTERNS = [
    (r'\btier0_action\b[^|&]{0,80}?\bapprove\b',
     'TIER 0 SELF-APPROVAL: calling tier0_action.approve() directly records an approval no human gave'),
]

# Round 4 (R2 residue): matched against the command with every quote and
# backslash REMOVED, so a spelling the shell reassembles is seen: bash -c '...',
# appr\"\"ove, appro\\ve. A variable in the verb slot (tier0 \$V) is refused too.
DEQUOTED_PATTERNS = [
    (r'(?:\bCLAUDECODE=|\benv\b|\bunset\b[^;|&]*\bCLAUDECODE\b)[\s\S]*\btier0\s+(?:approve\b|\\\$)',
     'TIER 0 SELF-APPROVAL: environment-stripped approval (CLAUDECODE= / env / unset, quoted or split) makes an agent look human'),
]

# Round 5 (Claude F1): privilege and session wrappers (sudo, su, runuser,
# tmux, screen, setsid, nohup, env -i, bash -c ...) reset CLAUDECODE, and the
# verb can be reassembled at run time (backticks, braces, ANSI-C quoting).
# One rule instead of a list: a command whose dequoted text contains the WORD
# tier0 is Tier 0 unless it is a plainly spelled read-only verb. Dequoting
# removes quotes and backslashes, and the dollar of a dollar-quote.
DOLLAR, BTICK = chr(36), chr(96)
TIER0_WORD = r'(?<![\w./-])tier0(?![\w.-])'
TIER0_READONLY = re.compile(
    r'(?:cd\s+[A-Za-z0-9._/-]+\s+&&\s+)?(?:[A-Za-z0-9._/-]*/)?fw\s+tier0(?:\s+(?:status|list|help|--help|-h))?')
# The direct module path: executed, imported, or attribute-accessed (not merely
# named, so reading or grepping lib/tier0_action.py is not Tier 0).
MODULE_USE = [
    r'\bpython[\d.]*\b[^;|&]*tier0_action\.py\s+(?!(?:status|pending-show|describe)\b)\S',
    r'\b(?:import|from)\s+tier0_action\b',
    r'\btier0_action\.(?!py\b)\w',
]
# Round 7: the module EXECUTED as a command (./lib/tier0_action.py use ...).
# This used to be a regex over the dequoted text, which cannot tell a word in
# command position from a word inside an assignment value once quotes are gone:
# FW_VENDOR_ONLY=(quoted list naming lib/tier0_action.py and other paths) bin/fw
# vendor self was read as running the module (a false block on every T-3593
# vendor sync). Now the command is tokenised the way the shell does (shlex,
# after ANSI-C decoding), leading NAME=value assignments and exec are skipped,
# and only the word in command position counts. A command shlex cannot split
# (unbalanced quotes) falls back to the old regex: fail closed.
MODULE_EXEC_RE = r'(?:^|[;&|(]|\bexec)\s*\S*tier0_action\.py\s+(?!(?:status|pending-show|describe)\b)\S'
ASSIGN_RE = re.compile(r'[A-Za-z_][A-Za-z0-9_]*\+?=')
OPS = set(';&|()') | {'&&', '||', ';;', '|&'}
def module_executed(raw, dq):
    import shlex
    try:
        lx = shlex.shlex(re.sub(re.escape(DOLLAR) + '(?=[' + SQ + DQ + '])', '', ansi_c_decode(raw)),
                         posix=True, punctuation_chars=';&|()')
        lx.whitespace_split = True
        toks = list(lx)
    except ValueError:
        return bool(re.search(MODULE_EXEC_RE, dq))
    at_cmd = True
    for k, tok in enumerate(toks):
        if tok in OPS or set(tok) <= set(';&|()'):
            at_cmd = True
            continue
        if not at_cmd:
            continue
        if ASSIGN_RE.match(tok) or tok == 'exec':
            continue
        at_cmd = False
        if re.search(r'tier0_action\.py$', tok):
            nxt = toks[k + 1] if k + 1 < len(toks) else ''
            if nxt and nxt not in OPS and nxt not in ('status', 'pending-show', 'describe'):
                return True
    return False
# T-3593 R6 (codex MEDIUM): ANSI-C quoting is DECODED before the word check,
# the way bash decodes it, so tier-backslash-x30 spells tier0 here too. Written
# without backslash, dollar or double-quote literals: this script is inside a
# double-quoted shell string. Words built at run time (printf, eval) stay out
# of reach (documented residual).
BS = chr(92)
HEXD, OCTD = '0123456789abcdefABCDEF', '01234567'
ANSI_SIMPLE = {'a': chr(7), 'b': chr(8), 'e': chr(27), 'E': chr(27), 'f': chr(12),
               'n': chr(10), 'r': chr(13), 't': chr(9), 'v': chr(11),
               BS: BS, SQ: SQ, DQ: DQ, '?': '?'}
ANSI_WIDTH = {'x': 2, 'u': 4, 'U': 8}
def ansi_c_decode(raw):
    out, i, n = [], 0, len(raw)
    while i < n:
        if raw[i] != DOLLAR or i + 1 >= n or raw[i + 1] != SQ:
            out.append(raw[i])
            i += 1
            continue
        j = i + 2
        seg = []
        while j < n and raw[j] != SQ:
            c = raw[j]
            if c != BS or j + 1 >= n:
                seg.append(c)
                j += 1
                continue
            e = raw[j + 1]
            j += 2
            if e in ANSI_SIMPLE:
                seg.append(ANSI_SIMPLE[e])
            elif e in ANSI_WIDTH:
                k = j
                while k < n and k - j < ANSI_WIDTH[e] and raw[k] in HEXD:
                    k += 1
                seg.append(chr(min(int(raw[j:k], 16), 0x10FFFF)) if k > j else BS + e)
                j = k
            elif e in OCTD:
                k = j
                while k < n and k - j < 2 and raw[k] in OCTD:
                    k += 1
                seg.append(chr(int(raw[j - 1:k], 8) & 255))
                j = k
            elif e == 'c' and j < n:
                seg.append(chr(ord(raw[j]) & 31))
                j += 1
            else:
                seg.append(BS + e)
        # Round 7 (codex R6 MEDIUM): bash ends an ANSI-C string at the first
        # NUL it decodes (backslash-0, x00, u0000, c@ ...) and drops the rest
        # of that string; what follows the closing quote still concatenates.
        out.append(''.join(seg).split(chr(0), 1)[0])
        i = j + 1
    return ''.join(out)

def dequote(raw):
    raw = ansi_c_decode(raw)
    raw = re.sub(re.escape(DOLLAR) + '(?=[' + SQ + DQ + '])', '', raw)
    return re.sub('[' + SQ + DQ + chr(92) * 2 + ']', '', raw)

def matches(raw):
    t = strip_comments(strip_quotes(raw))
    dq = dequote(raw)
    found = ([d for p, d in PATTERNS if re.search(p, t)]
             + [d for p, d in RAW_PATTERNS if re.search(p, raw)]
             + [d for p, d in DEQUOTED_PATTERNS if re.search(p, dq)])
    if not any(d.startswith('TIER 0 SELF-APPROVAL') for d in found):
        if (re.search(TIER0_WORD, dq) and not TIER0_READONLY.fullmatch(raw.strip())) \
                or any(re.search(p, dq) for p in MODULE_USE) or module_executed(raw, dq):
            found.append('TIER 0 SELF-APPROVAL: a tier0 command other than a plainly spelled '
                         'fw tier0 status|list (wrappers like sudo, su, tmux, bash -c and '
                         'reassembled spellings included) is human-only')
    return found

found = matches(strip_heredocs(command))
if found:
    # Every matching risk is shown, not only the first: a force push that also
    # skips hooks must say so (round 3).
    print('BLOCKED|' + ' + '.join(found))
    # T-3593: map the command to ACTIONS (verb + target) so an approval
    # survives incidental retry text. Pattern list stays here; the module
    # only asks this list whether a segment is flagged. Any failure → no
    # ACTIONS line → the legacy command-hash path, unchanged.
    try:
        import json, os
        sys.path.insert(0, os.environ.get('T0_FRAMEWORK_ROOT', '') + '/lib')
        import tier0_action
        def is_flagged(text):
            # Every matching pattern, so the module can require that ALL of
            # them are covered by the action verb (T-3593 R1).
            return matches(strip_heredocs(text))
        acts = tier0_action.classify(command, is_flagged,
                                     os.environ.get('T0_CWD') or None,
                                     os.environ.get('T0_ROOT') or None)
        if acts:
            print('ACTIONS ' + json.dumps(acts, sort_keys=True))
    except Exception:
        pass
    sys.exit(0)

print('SAFE')
" 2>/dev/null)

# If Python failed or returned SAFE, allow
if [ -z "$MATCH_RESULT" ] || [ "$MATCH_RESULT" = "SAFE" ]; then
    exit 0
fi

# ── Destructive pattern detected ──
ACTIONS_JSON=$(printf '%s\n' "$MATCH_RESULT" | sed -n 's/^ACTIONS //p' | head -1)
MATCH_RESULT=$(printf '%s\n' "$MATCH_RESULT" | head -1)
DESCRIPTION="${MATCH_RESULT#BLOCKED|}"
T0_ACTION_PY="$FRAMEWORK_ROOT/lib/tier0_action.py"

# ── Grant TTL — ONE resolution point for BOTH approval legs (T-3080) ─────────
# Resolved here, below the fast-path keyword filter, so a safe command never
# pays for it; both decision sites below read APPROVAL_TTL and nothing else.
#
# Resolution order (stated once, here, and nowhere else):
#   1. TIER0_WATCHTOWER_TTL   legacy env override — honoured only when EXPLICITLY
#                             set, so any operator or test pinning it keeps working
#   2. FW_TIER0_APPROVAL_TTL  env, then TIER0_APPROVAL_TTL in .framework.yaml
#                             (fw_config tiers 2-3; registry entry in lib/config.sh)
#   3. 300                    registry default
#
# Why 300 and not 3600: before T-3080 the CLI leg carried a bare `300` literal
# and the Watchtower leg defaulted to 3600, so the path that takes one CLICK
# pre-authorised a destructive command for 12x as long as the path that takes a
# TYPED command. Approving does not run the command — it writes the command's
# hash into a grant file, and this hook then admits any command hashing to that
# value, once. A misclick on a card reading `rm -rf /` therefore leaves a live
# pre-authorisation for a genuine `rm -rf /` for the whole window. A misclick is
# the easier mistake to make, so it must carry the SHORTER window. Unified at
# the tight leg; the direction is always tighten-the-loose, never loosen-the-tight.
#
# This is the GRANT clock: how long an approval, once given, admits the command.
# It is NOT the request-staleness clock — how long a *pending* card stays
# offerable in the operator's queue (web/blueprints/approvals.py EXPIRY_SECONDS,
# `fw approvals pending|expire`). Do not collapse the two: a 300s staleness
# window would expire a request filed six minutes ago and the operator could no
# longer act on their own queue. T-3079 owns that leg.
APPROVAL_TTL="${TIER0_WATCHTOWER_TTL:-$(fw_config_int TIER0_APPROVAL_TTL)}"

# Command hash for exact-text approval matching: computed above, from the
# original bytes (round 7). T-1500 used to collapse whitespace here so a
# reflowed retry matched; that also made two different quoted arguments one
# approval, and is gone. If the hash could not be computed, nothing matches.
[ -n "$COMMAND_HASH" ] || COMMAND_HASH="unhashable-$(date +%s%N)"

# ── T-1508 duplicate hook fires — bound to the TOOL CALL (T-3593 round 4) ──
# When the same hook is registered in both .claude/settings.json (project) and
# ~/.claude/settings.json (user), each Bash call fires every hook twice. The
# first fire consumes the approval; without deduplication the second finds no
# approval and BLOCKS its own call (T-1506 RCA).
#
# Until round 4 the second fire was recognised by "same command text within 5 s".
# That is not single use: an approved `git reset --hard HEAD~1` typed twice in
# 5 s ran twice, the second time to a commit nobody approved (review N3). The
# key is now the PreToolUse `tool_use_id`: identical across duplicate fires of
# ONE call, distinct across calls. The sentinel records hash + call id; it lets
# through only the same call. No call id → no grace (a duplicate fire blocks its
# own call; that is the fail-closed direction, and no time window replaces it).
# The action path does the same inside lib/tier0_action.py, under its lock.
CONSUMED_FILE="${APPROVAL_FILE}.consumed"
_t0_same_call() {
    [ -n "$T0_CALL_ID" ] && [ -f "$CONSUMED_FILE" ] || return 1
    local h t c
    read -r h t c < "$CONSUMED_FILE" 2>/dev/null || return 1
    [ "$h" = "$COMMAND_HASH" ] && [ "$c" = "$T0_CALL_ID" ]
}
_t0_mark_consumed() { echo "$COMMAND_HASH $(date +%s) ${T0_CALL_ID:-}" > "$CONSUMED_FILE"; }
# Serialise the legacy check-and-consume so concurrent sibling fires cannot both
# miss (one removes the approval before the other has written the sentinel).
# Round 5 (codex MEDIUM): fail closed. The lock is flock(2) on fd 8, taken by
# python3 (which this hook already requires) rather than util-linux flock, so a
# host without flock (macOS) still locks. The lock belongs to the open file
# description bash holds, so it outlives the python child. If it cannot be
# taken within TIER0_LOCK_TIMEOUT seconds (default 10), T0_LOCKED stays 0 and
# both legacy check-and-consume legs below are SKIPPED: an exact-text approval
# is never consumed unlocked, and the command blocks. The action path has its
# own lock inside lib/tier0_action.py and is unaffected.
# The lock is released before anything is spawned in the background and before
# the block path, so no child can inherit fd 8 and hold it.
T0_LOCKED=0
T0_LOCK_FAILED=1
_t0_unlock() {
    if [ "$T0_LOCKED" = 1 ]; then exec 8>&-; T0_LOCKED=0; fi
    return 0
}
mkdir -p "${APPROVAL_FILE%/*}" 2>/dev/null
if { exec 8>"${APPROVAL_FILE}.lock"; } 2>/dev/null; then
    if T0_LOCK_TIMEOUT="${TIER0_LOCK_TIMEOUT:-10}" python3 -c '
import fcntl, os, sys, time
deadline = time.time() + float(os.environ["T0_LOCK_TIMEOUT"])
while True:
    try:
        fcntl.flock(8, fcntl.LOCK_EX | fcntl.LOCK_NB)
        sys.exit(0)
    except BlockingIOError:
        if time.time() >= deadline:
            sys.exit(1)
        time.sleep(0.05)
    except Exception:
        sys.exit(1)
' 2>/dev/null; then
        T0_LOCKED=1
        T0_LOCK_FAILED=0
    else
        exec 8>&-
    fi
fi
if _t0_same_call; then
    exit 0
fi

# ── T-3593: ACTION approval path ─────────────────────────────────────────────
# Tried first when the command mapped to actions. All-or-nothing: every action
# needs a live, unused approval or nothing is consumed and the legacy hash path
# below still gets its turn (so a Watchtower card approved for this exact text
# keeps working). Push verbs are ADMITTED here and CONSUMED by git pre-push.
if [ -n "$ACTIONS_JSON" ] && [ -f "$T0_ACTION_PY" ]; then
    if PROJECT_ROOT="$PROJECT_ROOT" python3 "$T0_ACTION_PY" use text-gate "$ACTIONS_JSON" "${COMMAND:0:120}" "$T0_CALL_ID" 2>/dev/null; then
        _t0_mark_consumed
        exit 0
    fi
fi

# ── Check for valid approval token (legacy command-hash path) ──
# Only under the lock (round 5): unlocked, nothing is consumed or cleaned up.
if [ "$T0_LOCKED" = 1 ] && [ -f "$APPROVAL_FILE" ]; then
    APPROVAL_HASH=$(awk '{print $1}' "$APPROVAL_FILE" 2>/dev/null)
    APPROVAL_TIME=$(awk '{print $2}' "$APPROVAL_FILE" 2>/dev/null)
    CURRENT_TIME=$(date +%s)

    if [ "$APPROVAL_HASH" = "$COMMAND_HASH" ]; then
        AGE=$((CURRENT_TIME - ${APPROVAL_TIME:-0}))
        if [ "$AGE" -lt "$APPROVAL_TTL" ]; then
            # Valid approval — consume it and allow
            rm -f "$APPROVAL_FILE"
            # T-1508 / round 4: sentinel so the duplicate fire of THIS call passes.
            _t0_mark_consumed
            _t0_unlock

            # Log to bypass-log for audit trail (fire-and-forget)
            # Data passed via env vars to avoid shell interpolation into source code (T-595)
            T0_LOG_FILE="$PROJECT_ROOT/.context/bypass-log.yaml" \
            T0_DESCRIPTION="$DESCRIPTION" \
            T0_COMMAND_PREVIEW="${COMMAND:0:120}" \
            T0_COMMAND_HASH="$COMMAND_HASH" \
            python3 -c "
import yaml, datetime, os

log_file = os.environ['T0_LOG_FILE']
entry = {
    'timestamp': datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),
    'tier': 0,
    'risk': os.environ['T0_DESCRIPTION'],
    'command_preview': os.environ['T0_COMMAND_PREVIEW'],
    'command_hash': os.environ['T0_COMMAND_HASH'],
    'authorized_by': 'human',
    'mechanism': 'fw tier0 approve',
    'match_path': 'command-hash',
}
try:
    if os.path.exists(log_file):
        with open(log_file) as f:
            data = yaml.safe_load(f) or {}
    else:
        data = {}
    data.setdefault('bypasses', []).append(entry)
    # T-100191: same-dir temp + os.replace — atomic write (L-493 class)
    tmp_path = log_file + '.tmp'
    with open(tmp_path, 'w') as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False)
    os.replace(tmp_path, log_file)
except:
    pass
" 2>/dev/null &
            exit 0
        fi
    fi

    # Stale or mismatched approval — clean up
    rm -f "$APPROVAL_FILE"
fi

# ── Check for Watchtower approval in .context/approvals/ (T-612) ──
APPROVAL_DIR="$PROJECT_ROOT/.context/approvals"
RESOLVED_FILE="$APPROVAL_DIR/resolved-${COMMAND_HASH:0:12}.yaml"

if [ "$T0_LOCKED" = 1 ] && [ -f "$RESOLVED_FILE" ]; then
    WT_RESULT=$(T0_RESOLVED="$RESOLVED_FILE" T0_TTL="$APPROVAL_TTL" T0_HASH="$COMMAND_HASH" python3 -c "
import yaml, time, os, sys

resolved_file = os.environ['T0_RESOLVED']
ttl = int(os.environ['T0_TTL'])
expected_hash = os.environ['T0_HASH']

try:
    with open(resolved_file) as f:
        data = yaml.safe_load(f) or {}
except:
    print('SKIP')
    sys.exit(0)

status = data.get('status', '')
full_hash = data.get('command_hash', '')

if status != 'approved' or full_hash != expected_hash:
    print('SKIP')
    sys.exit(0)

# Check TTL from response timestamp
resp = data.get('response', {})
ts = resp.get('responded_at', '') or data.get('timestamp', '')
if not ts:
    print('SKIP')
    sys.exit(0)

from datetime import datetime, timezone
try:
    dt = datetime.fromisoformat(ts.replace('Z', '+00:00'))
    age = time.time() - dt.timestamp()
    if age > ttl:
        print('EXPIRED')
    else:
        print('APPROVED')
except:
    print('SKIP')
" 2>/dev/null)

    if [ "$WT_RESULT" = "APPROVED" ]; then
        # Valid Watchtower approval — consume it and allow
        # Mark as consumed (single-use, keep file for audit trail)
        T0_RESOLVED="$RESOLVED_FILE" python3 -c "
import yaml, os
from datetime import datetime, timezone

f = os.environ['T0_RESOLVED']
with open(f) as fh:
    data = yaml.safe_load(fh) or {}
data['status'] = 'consumed'
data.setdefault('response', {})['consumed_at'] = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
# T-100191: same-dir temp + os.replace — atomic write (L-493 class)
tmp_path = f + '.tmp'
with open(tmp_path, 'w') as fh:
    yaml.dump(data, fh, default_flow_style=False, sort_keys=False)
os.replace(tmp_path, f)
" 2>/dev/null
        _t0_mark_consumed
        _t0_unlock

        # Log to bypass-log for audit trail (fire-and-forget)
        T0_LOG_FILE="$PROJECT_ROOT/.context/bypass-log.yaml" \
        T0_DESCRIPTION="$DESCRIPTION" \
        T0_COMMAND_PREVIEW="${COMMAND:0:120}" \
        T0_COMMAND_HASH="$COMMAND_HASH" \
        python3 -c "
import yaml, datetime, os

log_file = os.environ['T0_LOG_FILE']
entry = {
    'timestamp': datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),
    'tier': 0,
    'risk': os.environ['T0_DESCRIPTION'],
    'command_preview': os.environ['T0_COMMAND_PREVIEW'],
    'command_hash': os.environ['T0_COMMAND_HASH'],
    'authorized_by': 'human',
    'mechanism': 'watchtower',
    'match_path': 'command-hash',
}
try:
    if os.path.exists(log_file):
        with open(log_file) as f:
            data = yaml.safe_load(f) or {}
    else:
        data = {}
    data.setdefault('bypasses', []).append(entry)
    # T-100191: same-dir temp + os.replace — atomic write (L-493 class)
    tmp_path = log_file + '.tmp'
    with open(tmp_path, 'w') as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False)
    os.replace(tmp_path, log_file)
except:
    pass
" 2>/dev/null &
        exit 0
    fi
fi

_t0_unlock

# ── Check for prior rejection feedback (T-641) ──
REJECTION_FEEDBACK=""
if [ -f "$RESOLVED_FILE" ]; then
    REJECTION_FEEDBACK=$(T0_RESOLVED="$RESOLVED_FILE" T0_HASH="$COMMAND_HASH" python3 -c "
import yaml, os, sys

resolved_file = os.environ['T0_RESOLVED']
expected_hash = os.environ['T0_HASH']

try:
    with open(resolved_file) as f:
        data = yaml.safe_load(f) or {}
except:
    sys.exit(0)

if data.get('status') != 'rejected' or data.get('command_hash', '') != expected_hash:
    sys.exit(0)

resp = data.get('response', {})
feedback = resp.get('feedback', '')
if feedback:
    print(feedback)
" 2>/dev/null)
fi

# ── Block with explanation ──
# Detect Watchtower URL via shared helper (T-1154, T-1156)
WT_URL=$(_watchtower_url 2>/dev/null || echo "http://localhost:3000")

echo "" >&2
echo "══════════════════════════════════════════════════════════" >&2
echo "  TIER 0 BLOCK — Destructive Command Detected" >&2
echo "══════════════════════════════════════════════════════════" >&2
echo "" >&2
echo "  Risk: $DESCRIPTION" >&2
echo "  Command: ${COMMAND:0:120}" >&2
echo "" >&2
echo "  This command is classified as Tier 0 (consequential)." >&2
echo "  It requires explicit human approval before execution." >&2
echo "" >&2
if [ -n "$ACTIONS_JSON" ] && [ -f "$T0_ACTION_PY" ]; then
echo "  Action(s) the operator would approve (T-3593):" >&2
python3 "$T0_ACTION_PY" describe "$ACTIONS_JSON" 2>/dev/null | sed 's/^/    - /' >&2
echo "  The approval is for the ACTION, single-use, for ${APPROVAL_TTL}s: a retry" >&2
echo "  in the same plain shape (flag order, spacing, a cd prefix) still matches;" >&2
echo "  a different ref, remote, branch or path does not." >&2
else
echo "  Not mapped to an action — the approval covers this exact command text," >&2
echo "  byte for byte (spacing included). Only plain 'cd PATH && git|rm ...' commands" >&2
echo "  (no quotes, variables, pipes, redirections or wrappers) map to actions." >&2
fi
if [ "$T0_LOCK_FAILED" = 1 ]; then
echo "" >&2
echo "  NOTE: the approval lock could not be taken, so no exact-text approval was" >&2
echo "  checked or consumed (fail closed). Retry when no other hook holds it." >&2
fi
echo "" >&2
echo "  What this gate can and cannot see (T-2742, T-3593):" >&2
echo "    - It reads only the command you typed. A script or other indirection" >&2
echo "      (bash x.sh, make, python3 y.py) is NOT inspected by this gate." >&2
echo "    - Force-push and remote ref deletion are enforced for real at git's" >&2
echo "      pre-push hook (T-3594), whichever way the push is launched." >&2
echo "    - rm -rf (and the other patterns) inside a script has no equivalent" >&2
echo "      control and is not covered." >&2
echo "" >&2
if [ -n "$REJECTION_FEEDBACK" ]; then
echo "  Previous rejection feedback:" >&2
echo "    $REJECTION_FEEDBACK" >&2
echo "" >&2
fi
echo "  To request approval, ask the operator (human-only) to run:" >&2
echo "    $(_emit_user_command "tier0 approve")" >&2
echo "  (approves the action(s) above when listed, else this exact command)" >&2
echo "" >&2
echo "  Or approve this exact command text in Watchtower:" >&2
echo "    ${WT_URL}/approvals" >&2
echo "" >&2
echo "  Policy: 011-EnforcementConfig.md §Tier 0" >&2
echo "══════════════════════════════════════════════════════════" >&2
echo "" >&2

# Write the pending command hash so 'fw tier0 approve' can pick it up
echo "$COMMAND_HASH $(date +%s) PENDING" > "${APPROVAL_FILE}.pending"
# T-3593: and the pending ACTIONS, which 'fw tier0 approve' prefers when present.
if [ -n "$ACTIONS_JSON" ] && [ -f "$T0_ACTION_PY" ]; then
    PROJECT_ROOT="$PROJECT_ROOT" python3 "$T0_ACTION_PY" write-pending text-gate "$ACTIONS_JSON" "${COMMAND:0:200}" "$COMMAND_HASH" 2>/dev/null || true
else
    rm -f "$PROJECT_ROOT/.context/working/.tier0-action.pending.json"
fi

# Also write a human-readable YAML for Watchtower approval surface (T-611)
APPROVAL_DIR="${APPROVAL_DIR:-$PROJECT_ROOT/.context/approvals}"
mkdir -p "$APPROVAL_DIR" 2>/dev/null
APPROVAL_YAML="$APPROVAL_DIR/pending-${COMMAND_HASH:0:12}.yaml"
T0_RISK="$DESCRIPTION" T0_CMD="$COMMAND" T0_HASH="$COMMAND_HASH" T0_ROOT="$PROJECT_ROOT" T0_FRAMEWORK_ROOT="$FRAMEWORK_ROOT" python3 -c "
import yaml, sys, os, subprocess

# ── Provenance (T-3078) ─────────────────────────────────────────────────────
# Derived in lib/tier0_origin.py, not here: the classification needs its own
# tests, and logic embedded in a shell heredoc can only be exercised by running
# the hook — which under bats always looks like a test, so the agent and human
# branches were unreachable. See that module's docstring for why provenance is
# derived from the process ancestry rather than declared by a caller flag.
#
# Import failure degrades to {'kind': 'unknown'} and the card is still written.
# Provenance explains the block; the card IS the block. Never let the
# explanation break the enforcement.
def _origin():
    try:
        sys.path.insert(0, os.environ.get('T0_FRAMEWORK_ROOT', '') + '/lib')
        import tier0_origin
        return tier0_origin.derive(os.environ.get('T0_ROOT', ''))
    except Exception:
        return {'kind': 'unknown'}

data = {
    'timestamp': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
    'type': 'tier0',
    'risk': os.environ.get('T0_RISK', ''),
    'command_preview': os.environ.get('T0_CMD', '')[:200],
    'command_hash': os.environ.get('T0_HASH', ''),
    'status': 'pending',
    'origin': _origin(),
}
# T-100191: same-dir temp + os.replace — atomic create; the approval consumer
# (fw tier0 approve / Watchtower) must never read a half-written file.
tmp_path = sys.argv[1] + '.tmp'
with open(tmp_path, 'w') as f:
    yaml.dump(data, f, default_flow_style=False, allow_unicode=True)
os.replace(tmp_path, sys.argv[1])
" "$APPROVAL_YAML" 2>/dev/null || true

# Push notification for Tier 0 block (T-709)
if [ -f "$FRAMEWORK_ROOT/lib/notify.sh" ]; then
    source "$FRAMEWORK_ROOT/lib/notify.sh"
    fw_notify "Tier 0 Approval Needed" "$DESCRIPTION — Approve: ${WT_URL}/approvals" "task_blocked" "framework"
fi

exit 2
