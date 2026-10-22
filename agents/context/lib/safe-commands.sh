#!/bin/bash
# Safe-command allowlist for Bash task gate (T-650, T-630)
#
# is_bash_safe_command() returns 0 if the command is read-only/diagnostic
# and should be allowed without an active task.
#
# Design evidence: 7920 Bash invocations analyzed from real session data.
# Only 1.4% are file-writing operations. This allowlist catches the safe
# 98.6% for fast-path bypass.
#
# Categories (27 patterns):
#   1. Git read-only (8 patterns)
#   2. File reading (7 patterns)
#   3. Searching (4 patterns)
#   4. FW diagnostics (6 patterns)
#   5. System utilities (6 patterns)
#   6. Validation (2 patterns)
#
# T-4662: CALLER CONTRACT — the shell's cwd. A git clause is judged against the
# repository git would discover from the shell's cwd (T-4409), so the caller must
# say where the shell is. The hook sets _FW_PAYLOAD_CWD from the payload's `cwd`
# (check-active-task.sh). A caller with no payload (a test harness) does the same:
#     export PROJECT_ROOT=<project> _FW_PAYLOAD_CWD=<absolute cwd of the command>
# Without it the cwd is known only when $PWD IS PROJECT_ROOT. Otherwise every git
# clause is NOT SAFE, and the first such refusal in a process says so on stderr.
# There is deliberately no fallback to "$PWD somewhere inside PROJECT_ROOT": the
# hook's $PWD does not follow the Bash tool's shell, which keeps its cwd across calls.

# --- T-2834: chain-aware entry point -------------------------------------
#
# _fw_chain_split emits one NUL-TERMINATED segment per chain operator that is
# NOT inside quotes: `&&`, `||`, `&`, `|`, `;`, and newline. Quote tracking
# matters — without it `grep -q "a && b"` splits into two bogus segments and a
# read-only command starts blocking.
#
# T-3223: the delimiter is NUL, not newline, and that is the whole point.
#
# This function was already quote-aware, so a newline inside a quoted argument
# was correctly kept INSIDE its segment. Then the segment was printed with
# `printf '%s\n'` and read back by `mapfile -t` / `read -r` — line-delimited.
# A segment that legitimately contained a newline arrived at the caller as
# several segments, each a fragment of a quoted string, none of them a command.
#
# Measured: a real multi-line commit message split into six clauses, five of
# which were prose from the message body, all read as unsafe. So `git add -A
# … && git commit -q -m "<multi-line message>"` — the framework's own
# documented post-completion form, in the shape agents actually type it —
# was refused. The short single-line fixtures in the test suite never met it.
#
# The structure was right and the CHANNEL threw it away, which is the same
# class this whole cluster keeps hitting (L-547, OBS-355) one layer down: a
# delimiter-scan standing in for structure, so an argument that CONTAINS a
# delimiter is treated as a boundary. NUL cannot appear in a bash command
# string, so it is the only delimiter that cannot collide with content.
#
# Callers MUST read with `-d ''`:
#     while IFS= read -r -d '' seg; do … done < <(_fw_chain_split "$cmd")
# `read -d ''` is bash 4.0+; `mapfile -d` would need 4.4, so the loop form is
# used at every call site for portability (D4).
#
# Deliberately NOT handled: command substitution. `echo $(git commit -m 'T-X: y')`
# still reads as safe. Extracting `$(...)` as a segment would also catch the
# framework's own documented idiom `curl -sf "$(bin/fw watchtower url)/page"` —
# `fw watchtower` is not on the allowlist, so that verification pattern would
# start blocking whenever no task is active, which is exactly the recovery state
# where friction hurts most. Chain operators are the measured, high-frequency
# hole; substitution is narrower and is filed rather than papered over (OBS-185).
#
# T-4409: `_fw_chain_split CMD ops` emits each segment followed by a second
# NUL-terminated record, the operator that ENDED it: `&&`, `||`, `|`, `&`, `;`
# (a newline reads as `;`), or empty after the last segment. Callers that only
# want segments call it with one argument and get the unchanged stream.
_fw_chain_split() {
    local cmd="$1" seg="" q="" ch nxt i n=${#1} _ops="${2:-}" _op
    for (( i=0; i<n; i++ )); do
        ch="${cmd:i:1}"
        if [ -n "$q" ]; then
            seg+="$ch"
            [ "$ch" = "$q" ] && q=""
            continue
        fi
        case "$ch" in
            "'"|'"') q="$ch"; seg+="$ch" ;;
            '\')     seg+="$ch"; i=$((i+1)); [ "$i" -lt "$n" ] && seg+="${cmd:i:1}" ;;
            '&'|'|')
                # T-2879: an `&` that is part of a file-descriptor duplication is NOT a
                # chain separator. `bin/fw note "x" 2>&1` was splitting into
                # `bin/fw note "x" 2>` and `1`; the bare `1` matches nothing in the
                # allowlist, so the compound failed. That neutralised the ENTIRE safe-list
                # for the commonest redirect idiom there is — `fw doctor 2>&1`,
                # `git status 2>&1`, `ls -la 2>&1` all gated — precisely in the no-task and
                # drift states where the safe-list is the only thing preventing a deadlock.
                #
                # Narrow on purpose: require the `&` to sit between a redirect operator and
                # an fd target (digit or `-`), which is the only form that duplicates rather
                # than writes. `cmd >& file` is a genuine write to `file` and MUST keep
                # splitting (and gating) — the next-char test is what preserves that, so do
                # not relax it to "preceded by > or <" alone.
                nxt="${cmd:i+1:1}"
                if [ "$ch" = '&' ] && [[ "${seg: -1}" == [\<\>] ]] && [[ "$nxt" == [0-9-] ]]; then
                    seg+="$ch"
                    continue
                fi
                _op="$ch"
                [ "$nxt" = "$ch" ] && { i=$((i+1)); _op="$ch$ch"; }
                printf '%s\0' "$seg"; [ -n "$_ops" ] && printf '%s\0' "$_op"; seg="" ;;
            ';'|$'\n') printf '%s\0' "$seg"; [ -n "$_ops" ] && printf ';\0'; seg="" ;;
            *)       seg+="$ch" ;;
        esac
    done
    printf '%s\0' "$seg"; [ -n "$_ops" ] && printf '\0'
    return 0
}

# A compound command is safe only if EVERY segment is safe.
#
# The predecessor asserted the opposite in a comment — "for compound commands,
# the first word is still the primary command" — and judged `echo hi && git
# commit -m 'T-X: y'` by `echo` alone, exiting the caller (check-active-task.sh
# :95) before the no-active-task check, the task-is-active check, the G-020
# readiness gate and the T-1730 focus-drift gate ever ran. Everything after `&&`
# was unexamined. OBS-184 has the measured matrix.
#
# Failure direction is asymmetric and this errs the safe way: misjudging a safe
# chain as unsafe merely sends it to the task gate, which allows it whenever a
# task is active; misjudging an unsafe chain as safe skips every gate there is.
# T-4343: advance the tracked cwd (_FW_GIT_CWD, a local of is_bash_safe_command)
# past one chain segment that changes directory. Only a literal `cd <path>` whose
# base is known moves it. Any other directory-changing segment (bare cd, cd -,
# cd $VAR, pushd, source, eval) leaves it unknown, and so does a cd to something
# that is not an existing directory: the shell would have stayed put, so the next
# command's directory cannot be known. A relative -C then fails closed.
_fw_track_cwd() {
    _fw_segment_may_change_dir "$1" || return 0
    local _s="$1" _t="" _base="${_FW_GIT_CWD:-}" _abs=""
    _s="${_s#"${_s%%[![:space:]]*}"}"
    if [[ "$_s" =~ ^cd[[:space:]]+([^[:space:]]+)[[:space:]]*$ ]]; then
        _t="${BASH_REMATCH[1]}"
    fi
    _FW_GIT_CWD=""
    [ -n "$_t" ] && [[ "$_t" =~ ^[A-Za-z0-9._/+:@%,=-]+$ ]] && [[ "$_t" != -* ]] || return 0
    if [[ "$_t" == /* ]]; then
        _abs="$_t"
    elif [[ "$_base" == /* ]]; then
        _abs="$_base/$_t"
    else
        return 0
    fi
    _abs="$(realpath -m -- "$_abs" 2>/dev/null)" || return 0
    [ -d "$_abs" ] && _FW_GIT_CWD="$_abs"
    return 0
}

# T-4409: _fw_advance_cwd <segment> <operator that ended it>. Only `&&` and `;`
# carry a cd into what follows. After `|` or `&` the cd ran in a subshell; after
# `||` the next command runs only if it failed, and later ones run from either
# place. Rather than model each, the cwd becomes unknown.
_fw_advance_cwd() {
    _fw_track_cwd "$1"
    case "$2" in
        '&&'|';'|'') ;;
        *) _fw_segment_may_change_dir "$1" && _FW_GIT_CWD="" ;;
    esac
    return 0
}

# T-4536: _fw_note_literal_vars <segment> <operator that ended it>. T-4512 made
# the curl/wget check treat a word that begins with "$X" as a possible option,
# which is right when X comes from the environment and wrong for the T-3644 idiom
# `WURL=x; curl -sf "$WURL/"`, where the line itself fixed X. _FW_LIT_VARS holds
# the names a literal assignment set to a value that cannot begin an option
# (non-empty, no leading -, no $, backtick or backslash). It survives only `&&`
# and `;`, and only into further literal assignments or a curl/wget clause: any
# other segment (read, export, printf -v, eval, a loop ...) may reassign, so it
# empties the set. Unknown stays unknown, which is the blocking direction.
_fw_note_literal_vars() {
    local _s="${1#"${1%%[![:space:]]*}"}" _b _n _v
    _s="${_s%"${_s##*[![:space:]]}"}"
    case "$2" in '&&'|';'|'') ;; *) _FW_LIT_VARS=" "; return 0 ;; esac
    if [[ "$_s" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(([^[:space:]\"\'\`\;\&\|\<\>\(\)]|\"[^\"\`]*\"|\'[^\']*\')*)$ ]]; then
        _n="${BASH_REMATCH[1]}"; _v="${BASH_REMATCH[2]}"
        _FW_LIT_VARS="${_FW_LIT_VARS// $_n / }"
        case "$_v" in *'$'*|*'\'*) return 0 ;; esac
        _v="${_v//\"/}"; _v="${_v//\'/}"
        [ -n "$_v" ] && [[ "$_v" != -* ]] && _FW_LIT_VARS+="$_n "
        return 0
    fi
    _b="${_s%%[[:space:]]*}"; _b="${_b##*/}"
    case "$_b" in curl|wget) ;; *) _FW_LIT_VARS=" " ;; esac
    return 0
}

# T-4536: is this option word (kind E) an expansion of a name in _FW_LIT_VARS,
# i.e. `$NAME` or `${NAME}` followed by nothing or a non-name character?
_fw_word_is_literal_var() {
    [[ "$1" =~ ^\$(\{([A-Za-z_][A-Za-z0-9_]*)\}|([A-Za-z_][A-Za-z0-9_]*)([^A-Za-z0-9_]|$)) ]] || return 1
    local _n="${BASH_REMATCH[2]:-${BASH_REMATCH[3]}}"
    [[ "${_FW_LIT_VARS:- }" == *" $_n "* ]]
}

# T-4409: the shell's cwd at the start of a command line: the payload cwd when it is
# absolute; else the hook's $PWD only when it IS PROJECT_ROOT; else empty (unknown).
_fw_initial_git_cwd() {
    if [[ "${_FW_PAYLOAD_CWD:-}" == /* ]]; then
        printf '%s' "$_FW_PAYLOAD_CWD"
    elif [ -n "${PROJECT_ROOT:-}" ]; then
        local _rp _rr
        _rp="$(realpath -e -- "$PWD" 2>/dev/null)"; _rr="$(realpath -e -- "$PROJECT_ROOT" 2>/dev/null)"
        [ -n "$_rp" ] && [ "$_rp" = "$_rr" ] && printf '%s' "$_rp"
    fi
    return 0
}

# T-4662: say once per process why a git clause was refused for want of a cwd
# (the caller has checked that the cwd was unknown, not foreign), but only when no
# payload cwd was given at all: the harness case. A foreign cwd stays quiet.
_fw_note_unknown_git_cwd() {
    [[ "${_FW_PAYLOAD_CWD:-}" == /* ]] && return 0
    [ -n "${_FW_NO_CWD_NOTED:-}" ] && return 0
    _FW_NO_CWD_NOTED=1
    echo "safe-commands: git clause refused: the shell's cwd is unknown (no absolute _FW_PAYLOAD_CWD, and \$PWD is not PROJECT_ROOT). Callers without a hook payload: export _FW_PAYLOAD_CWD=<absolute cwd> (T-4662)." >&2
    return 0
}

# T-4511: does the text carry process substitution, `<(CMD)` or `>(CMD)`? Bash runs
# CMD whatever the outer verb is, so `cat <(touch x)` executes touch, and the outer
# redirect scan only sees `>`. A mention is not a use: a backslash-escaped character
# is skipped, and so is single-quoted text, but only on a line with NO double quote.
# Inside "…" a `'` is literal while inside "$(…)" it opens a quote again, so a
# flat scan of a line mixing the two could misread where a quote ends and skip a
# real `<(`; refusing every unescaped `<(` / `>(` there over-blocks toward the gate.
_fw_has_process_subst() {
    local s="$1" i n=${#1} ch sq=0 honour_sq=1
    [[ "$s" == *'"'* ]] && honour_sq=0
    for (( i=0; i<n; i++ )); do
        ch="${s:i:1}"
        if [ "$sq" -eq 1 ]; then
            [ "$ch" = "'" ] && sq=0
            continue
        fi
        case "$ch" in
            "'") sq=$honour_sq ;;
            '\') i=$((i+1)) ;;
            '<'|'>') [ "${s:i+1:1}" = "(" ] && return 0 ;;
        esac
    done
    return 1
}

is_bash_safe_command() {
    # T-4511: process substitution runs a command anywhere on the line.
    _fw_has_process_subst "$1" && return 1
    local _cmd="$1" _seg _n=0
    # T-4343: the cwd the git arm resolves -C / --git-dir against. Top level starts at
    # the shell's cwd from the hook payload. A nested call (F-15 `X=$(...)`) inherits
    # the caller's value, and `local` keeps a cd inside it from leaking back out.
    # T-4409: with no absolute payload cwd, the hook's $PWD counts only when it IS
    # PROJECT_ROOT (then the shell started there too); otherwise the cwd is unknown
    # and the git arm fails closed.
    # Decided before `local`, which would hide the caller's value.
    local _c0=""
    if [ -n "${_FW_GIT_CWD+x}" ]; then
        _c0="$_FW_GIT_CWD"
    else
        _c0="$(_fw_initial_git_cwd)"
    fi
    local _FW_GIT_CWD="$_c0"
    # T-4536: names this line assigned a literal that cannot read as an option
    # (_fw_note_literal_vars). Never inherited: a nested `X=$(...)` starts empty.
    local _FW_LIT_VARS=" "
    # T-4409: _FW_SEG_OPS[i] is the operator that ended kept segment i, read by
    # _fw_segments_are_safe to decide whether a cd carries into the next segment.
    local -a _segs=() _kept=() _FW_SEG_OPS=()
    local _op
    # T-3223: `-d ''`. mapfile -t here read the splitter's NUL stream as lines,
    # so a segment containing a newline arrived as several bogus segments.
    while IFS= read -r -d '' _seg && IFS= read -r -d '' _op; do
        if [[ "$_seg" =~ ^[[:space:]]*$ ]]; then
            # an empty segment cannot change directory, but a non-advancing
            # operator after it still breaks the && / ; chain it sits in
            case "$_op" in '&&'|';'|'') ;; *) [ "$_n" -gt 0 ] && _FW_SEG_OPS[$((_n-1))]="$_op" ;; esac
            continue
        fi
        _kept+=("$_seg"); _FW_SEG_OPS+=("$_op"); _n=$((_n+1))
    done < <(_fw_chain_split "$_cmd" ops)
    if [ "$_n" -gt 1 ]; then
        _fw_segments_are_safe "$_cmd" "${_kept[@]}"
        return
    fi
    _fw_single_command_is_safe "$_cmd"
}

# --- T-4396: for / while / until loops ---------------------------------------
#
# A loop arrives from _fw_chain_split as keyword segments — `for t in a b`,
# ` do grep x "$t"`, ` done` — and `for`, `do` and `done` match no allowlist arm,
# so every loop gated, `for t in T-1 T-2; do grep -m1 name …; done` included.
#
# _fw_segments_are_safe walks the segments with a small grammar instead of judging
# each keyword as a command. Everything outside the grammar keeps the old verdict
# (a segment starting with a keyword was unsafe before and is unsafe now unless the
# whole loop parses), so this can only admit loops whose every command is admitted:
#   for NAME [in WORDS]  WORDS may hold $(…) only when the inner command is itself
#                        safe; backticks, <( and >( are refused
#   while|until COND     COND judged as a command; `read [-r…] NAME…`, `true` and
#                        `:` are accepted there and only there
#   do [CMD]             CMD judged like any segment (a nested loop recurses here)
#   done [TAIL]          TAIL may only be `< PATH`, `N>/dev/null` or `N>&M`
# Refused: if/case/select and C-style for (no arm), a missing do/done, a stray
# done, and any directory change inside a body — the second iteration runs from a
# cwd the T-4343 -C resolution cannot know. When a loop is present the whole line
# must also clear has_bash_write_pattern, so a redirect in a body is refused here
# and not only by the caller's scan.
#
# Known over-block, toward the gate: _fw_chain_split is not paren-aware, so a
# word-list `$(ls | head)` splits inside the substitution and reads unbalanced.
_fw_segments_are_safe() {
    local _orig="$1"; shift
    local _seg _s _kw _rest _depth=0 _expect="" _loops=0 _si=-1
    for _seg in "$@"; do
        _si=$((_si+1))
        _s="${_seg#"${_seg%%[![:space:]]*}"}"
        _s="${_s%"${_s##*[![:space:]]}"}"
        while :; do
            _kw="${_s%%[[:space:]]*}"
            _rest="${_s#"$_kw"}"
            _rest="${_rest#"${_rest%%[![:space:]]*}"}"
            case "$_kw" in
                for|while|until) _FW_LIT_VARS=" " ;;
            esac
            case "$_kw" in
                for)
                    [ -z "$_expect" ] || return 1
                    _fw_loop_for_header_is_safe "$_rest" || return 1
                    _depth=$((_depth+1)); _loops=1; _expect=do
                    ;;
                while|until)
                    [ -z "$_expect" ] && [ -n "$_rest" ] || return 1
                    _depth=$((_depth+1)); _loops=1; _expect=cond
                    _s="$_rest"; continue
                    ;;
                do)
                    [ "$_expect" = do ] || [ "$_expect" = cond ] || return 1
                    _expect=""
                    [ -n "$_rest" ] || break
                    _s="$_rest"; continue
                    ;;
                done)
                    [ "$_depth" -gt 0 ] && [ -z "$_expect" ] || return 1
                    _fw_loop_done_tail_is_safe "$_rest" || return 1
                    _depth=$((_depth-1))
                    ;;
                *)
                    [ "$_expect" = do ] && return 1
                    if [ "$_depth" -gt 0 ]; then
                        _fw_segment_may_change_dir "$_s" && return 1
                        if [ "$_expect" = cond ] && _fw_loop_cond_is_builtin "$_s"; then
                            break
                        fi
                    fi
                    _fw_single_command_is_safe "$_s" || return 1
                    _fw_advance_cwd "$_s" "${_FW_SEG_OPS[$_si]:-}"
                    if [ "$_depth" -gt 0 ]; then
                        _FW_LIT_VARS=" "
                    else
                        _fw_note_literal_vars "$_s" "${_FW_SEG_OPS[$_si]:-}"
                    fi
                    ;;
            esac
            break
        done
    done
    [ "$_depth" -eq 0 ] && [ -z "$_expect" ] || return 1
    if [ "$_loops" -eq 1 ]; then
        has_bash_write_pattern "$_orig" && return 1
    fi
    return 0
}

# `for` header after the keyword: NAME, optionally `in WORDS`.
_fw_loop_for_header_is_safe() {
    local _h="$1"
    [[ "$_h" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] && return 0
    [[ "$_h" =~ ^[A-Za-z_][A-Za-z0-9_]*[[:space:]]+in([[:space:]]+(.*))?$ ]] || return 1
    _fw_loop_words_are_safe "${BASH_REMATCH[2]}"
}

# A word list expands; the only expansion that can run a command is substitution.
# Each `$(…)` must hold a command is_bash_safe_command admits. Backticks and
# process substitution are refused rather than parsed.
_fw_loop_words_are_safe() {
    local _w="$1" _q="" _ch _i _j _d _n=${#1}
    for (( _i=0; _i<_n; _i++ )); do
        _ch="${_w:_i:1}"
        if [ "$_q" = "'" ]; then
            [ "$_ch" = "'" ] && _q=""
            continue
        fi
        case "$_ch" in
            '\') _i=$((_i+1)) ;;
            "'") [ -z "$_q" ] && _q="'" ;;
            '"') if [ "$_q" = '"' ]; then _q=""; else _q='"'; fi ;;
            '`') return 1 ;;
            '<'|'>') [ "${_w:_i+1:1}" = '(' ] && return 1 ;;
            '$')
                [ "${_w:_i+1:1}" = '(' ] || continue
                _d=1
                for (( _j=_i+2; _j<_n; _j++ )); do
                    case "${_w:_j:1}" in
                        '(') _d=$((_d+1)) ;;
                        ')') _d=$((_d-1)); [ "$_d" -eq 0 ] && break ;;
                    esac
                done
                [ "$_d" -eq 0 ] || return 1
                is_bash_safe_command "${_w:_i+2:_j-_i-2}" || return 1
                _i=$_j
                ;;
        esac
    done
    [ -z "$_q" ]
}

# What may follow `done`: an input redirect from a plain path, a redirect to
# /dev/null, or an fd duplication. Nothing that names an output file, no
# here-string, no process substitution.
_fw_loop_done_tail_is_safe() {
    local _t="$1"
    local _re='^([0-9&]?>>?[[:space:]]*/dev/null|[0-9]?>&[0-9-]|<[[:space:]]*[A-Za-z0-9._/+:@%,=-]+)([[:space:]]+|$)'
    while [ -n "$_t" ]; do
        [[ "$_t" =~ $_re ]] || return 1
        _t="${_t:${#BASH_REMATCH[0]}}"
    done
    return 0
}

# Builtins accepted only as a while/until condition: they set shell variables or
# a status and touch no file.
_fw_loop_cond_is_builtin() {
    [[ "$1" =~ ^(true|:)$ ]] && return 0
    [[ "$1" =~ ^read([[:space:]]+-[ra]+)*([[:space:]]+[A-Za-z_][A-Za-z0-9_]*)+$ ]]
}

# --- T-3374 (OBS-423): env-prefix denylist ------------------------------------
#
# The T-1908 stripper below removes leading `NAME=VALUE` prefixes so the base
# command can be read. It stripped ANY name. That is fail-OPEN: the classifier
# decides SAFE from the base command AFTER stripping, while some of those
# prefixes are precisely what decides what that base name RESOLVES to.
#
# Measured before this fix, all four classified SAFE:
#     PATH=/tmp cat x            LD_PRELOAD=/tmp/e.so cat x
#     BASH_ENV=/tmp/e.sh cat x   IFS=x cat y
#
# A grep for these names in this file returned nothing — there was no denylist
# that missed them; the category was never represented. Sibling of OBS-422 in
# the same function, but the opposite direction: that one over-blocks reads,
# this one under-blocks writes.
#
# WHY A DENYLIST AND NOT A NAME ALLOWLIST. An allowlist (`FW_*` only) is
# strictly safer and was rejected deliberately: tests/unit/safe_commands_env_-
# prefix.bats pins `FOO=1 BAR=2 fw work-on T-X` as SAFE, a documented T-1908 /
# L-399 contract. Rewriting that test so this change could pass would be
# weakening a pinned contract to accommodate the fix. The denylist keeps every
# pinned contract green and still closes the measured hole. The residual — a
# denylist cannot cover a name nobody thought of — is real, is NOT claimed away,
# and the allowlist alternative is recorded as a Sovereign question in T-3374.
#
# FAILURE DIRECTION IS TOWARD BLOCKING, same idiom as the T-3096 wrapper loop:
# on a denied name the strip loop STOPS, leaving `NAME=VALUE` as the first word,
# which matches no case arm, so the line gates. This function can only ever
# REFUSE something that previously passed; it cannot admit anything.

# _fw_env_prefix_is_denied <NAME> — true when NAME redirects what a following
# command resolves to, makes the shell/interpreter execute extra code, or
# changes how the line is parsed.
_fw_env_prefix_is_denied() {
    case "$1" in
        # binary resolution / the shell itself
        PATH|SHELL) return 0 ;;
        # dynamic linker — LD_* (ELF) and DYLD_* (macOS; D4 portability, the
        # framework is not Linux-only)
        LD_*|DYLD_*) return 0 ;;
        # shell startup files, option sets, and exported-function smuggling
        ENV|BASH_ENV|SHELLOPTS|BASHOPTS|BASH_FUNC_*) return 0 ;;
        # word splitting — changes how the command line itself is parsed
        IFS) return 0 ;;
        # interpreter module/option paths: these run code at interpreter start
        PYTHONPATH|PYTHONHOME|PYTHONSTARTUP|PERL5LIB|PERL5OPT|RUBYOPT|NODE_OPTIONS) return 0 ;;
        # git hands these to a shell. `git` is broadly allowlisted for read-only
        # sub-verbs, so these turn an allowlisted read into arbitrary execution.
        GIT_SSH|GIT_SSH_COMMAND|GIT_ASKPASS|GIT_PROXY_COMMAND) return 0 ;;
        GIT_EXTERNAL_DIFF|GIT_PAGER|GIT_EDITOR|GIT_SEQUENCE_EDITOR) return 0 ;;
        # GIT_CONFIG_* can inject core.pager / diff.external at invocation time,
        # which is the same arbitrary-execution vector one indirection further out.
        # T-4408: every GIT_CONFIG* name, GIT_CONFIG_PARAMETERS included (the
        # `git -c` channel: 'core.fsmonitor=CMD'), except GIT_CONFIG_NOSYSTEM, which
        # only switches the system file off and so can only remove config.
        GIT_CONFIG_NOSYSTEM) return 1 ;;
        GIT_CONFIG*) return 0 ;;
        # T-4408: GIT_EXEC_PATH is where git looks up its helper programs
        # (git-remote-https for fetch/push, ...): a directory of programs it runs.
        GIT_EXEC_PATH) return 0 ;;
        # T-4408: a colon-separated list of object stores. Not resolvable as one
        # path, rarely used, so denied rather than parsed.
        GIT_ALTERNATE_OBJECT_DIRECTORIES) return 0 ;;
        #
        # NOT DENIED BY NAME — repository selection: GIT_DIR, GIT_WORK_TREE,
        # GIT_COMMON_DIR, GIT_INDEX_FILE, GIT_OBJECT_DIRECTORY. These are judged on
        # their VALUE by _fw_env_assign_is_denied below (T-4408). The old comment
        # here said "a read of a different repo is still a read"; T-4343 showed it
        # is not, because the selected repository's config runs commands
        # (core.fsmonitor, core.pager, diff.external, filters), and the index and
        # object store are written by allowlisted verbs (status refreshes the index,
        # add writes objects). So they are admitted only inside PROJECT_ROOT, the
        # same rule as -C / --git-dir / --work-tree. `GIT_DIR=foo git status`
        # (safe_commands_env_prefix.bats) stays SAFE when foo is in the project.
        # GIT_CEILING_DIRECTORIES is allowed: it can only stop repository discovery
        # early, never point it at another repository.
        # generic spawn-a-program hooks
        PAGER|EDITOR|VISUAL) return 0 ;;
        # T-4626: an rg config file can carry --pre / --hostname-bin.
        RIPGREP_CONFIG_PATH) return 0 ;;
        # T-4630: journalctl (and every systemd tool) runs SYSTEMD_PAGER via a shell.
        SYSTEMD_PAGER|SYSTEMD_PAGERSECURE) return 0 ;;
        *) return 1 ;;
    esac
}

# T-4408: _fw_env_assign_is_denied <NAME> <VALUE> — the name denylist above, plus
# the repository-selecting git names judged on VALUE: denied unless VALUE resolves
# inside PROJECT_ROOT (_fw_git_dir_is_project, relative values against the tracked
# cwd). A quoted, variable or otherwise unresolvable value is denied. Every place
# that strips or admits an assignment calls this, not the name-only predicate.
_fw_env_assign_is_denied() {
    _fw_env_prefix_is_denied "$1" && return 0
    case "$1" in
        GIT_DIR|GIT_WORK_TREE|GIT_COMMON_DIR|GIT_INDEX_FILE|GIT_OBJECT_DIRECTORY)
            _fw_git_dir_is_project "$2" "${_FW_GIT_CWD-${_FW_PAYLOAD_CWD:-$PWD}}" >/dev/null || return 0 ;;
    esac
    return 1
}

# _fw_strip_env_prefixes <cmd> — strip leading NAME=VALUE prefixes, stopping at
# the first DENIED name. Result in $_FW_ENV_STRIPPED (a global rather than a
# command substitution: this runs on the hook hot path and a fork per Bash tool
# call is a cost with no benefit).
#
# ONE implementation, deliberately. The regex used to appear TWICE — once here
# and once re-entered inside the T-3096 wrapper loop, which is what makes
# `env PATH=/tmp cat x` a distinct bypass from `PATH=/tmp cat x`. Two copies of
# a security predicate is two chances to fix only one; the duplication is
# removed rather than the denylist being pasted into both.
# T-3454: the loop also consumes a leading `time` keyword. `time` changes
# nothing about what resolves or what executes — it reports how long the
# remainder took — but an unstripped `time` made the whole line unclassifiable,
# so the gate refused it as "writes nothing the gate can detect". The effect was
# perverse rather than merely inconvenient: MEASURING the cost of an otherwise
# permitted command required a wrapper that turned it into a refusal, so the
# pressure ran against measuring. That is a bad direction for a framework whose
# repeated failure mode is acting on unmeasured cost (T-3450, T-3451, L-621).
#
# Safe for the same reason the NAME=VALUE strip is safe: stripping only ever
# exposes the REMAINDER to the identical classification, and write detection
# (has_bash_write_pattern) runs against the ORIGINAL, unstripped line at every
# call site. `time rm -rf x` strips to `rm -rf x`, which is still a write and
# still blocked. Interleaving is handled because both forms are consumed by the
# same loop, so `time FOO=1 git status` and `FOO=1 time git status` behave alike.
_fw_strip_env_prefixes() {
    local c="$1" _name _val _next _prev=""
    while [ "$c" != "$_prev" ]; do
        _prev="$c"
        if [[ "$c" =~ ^([A-Za-z_][A-Za-z0-9_]*)=([^[:space:]]+)[[:space:]]+(.*)$ ]]; then
            # the predicate runs regexes of its own, so BASH_REMATCH is read first
            _name="${BASH_REMATCH[1]}"; _val="${BASH_REMATCH[2]}"; _next="${BASH_REMATCH[3]}"
            _fw_env_assign_is_denied "$_name" "$_val" && break
            c="$_next"
            continue
        fi
        # Bare `time` and POSIX `time -p`. Deliberately NOT `/usr/bin/time`,
        # which takes its own options (-o FILE writes a file) and is a real
        # program rather than a shell keyword.
        if [[ "$c" =~ ^time([[:space:]]+-p)?[[:space:]]+(.*)$ ]]; then
            c="${BASH_REMATCH[2]}"
        fi
    done
    _FW_ENV_STRIPPED="$c"
}

# F-26 (T-4264): git takes its global options BEFORE the sub-verb, so the word
# after `git` is `-C`, `--git-dir=...`, `-P` and so on, not the verb. This strips
# them and prints `git <verb> <args...>` for the caller to classify. The verb is
# then judged exactly as the bare form is, so a write behind a global option stays
# a write: `git -C DIR commit` is still refused. Anything not recognised (an
# unknown global, a value option with no value) returns non-zero: fail closed.
# `-c` is the one that can run code: `-c core.fsmonitor=CMD status` executes CMD,
# so keys that name a program are refused here rather than admitted as read-only.
# T-4343: -C / --git-dir / --work-tree choose the repository git reads, and that
# repository's config can run commands (core.fsmonitor, core.pager, diff.external,
# filters). So a value is accepted only when it resolves inside PROJECT_ROOT.
# _fw_git_dir_is_project <value> <base> prints the resolved path when VALUE lies in
# PROJECT_ROOT. A relative VALUE resolves against BASE, the absolute effective cwd.
# Fail closed: a quoted, variable, ~ or glob word (this is no shell, nothing is
# expanded), a leading -, an unknown base, an unset or missing PROJECT_ROOT, or a
# path that realpath puts outside it (`..` and symlinks included).
_fw_git_dir_is_project() {
    local _v="$1" _base="$2" _pr _abs
    [[ "$_v" =~ ^[A-Za-z0-9._/+:@%,=-]+$ ]] || return 1
    [[ "$_v" == -* ]] && return 1
    if [[ "$_v" == /* ]]; then
        _abs="$_v"
    elif [[ "$_base" == /* ]]; then
        _abs="$_base/$_v"
    else
        return 1
    fi
    [ -n "${PROJECT_ROOT:-}" ] || return 1
    _pr="$(realpath -e -- "$PROJECT_ROOT" 2>/dev/null)" || return 1
    _abs="$(realpath -m -- "$_abs" 2>/dev/null)" || return 1
    case "$_abs" in "$_pr"|"$_pr"/*) printf '%s' "$_abs" ;; *) return 1 ;; esac
}

_fw_git_skip_globals() {
    local -a words
    read -ra words <<< "$1"
    local i=1 n=${#words[@]} tok key _cwd="${_FW_GIT_CWD:-}" _p
    while [ "$i" -lt "$n" ]; do
        tok="${words[$i]}"
        case "$tok" in
            # T-4343: -C moves the cwd for every later relative value, exactly as git
            # does, so the next value is judged against the resolved one.
            -C)
                _p="$(_fw_git_dir_is_project "${words[$((i + 1))]:-}" "$_cwd")" || return 1
                _cwd="$_p"
                i=$((i + 2)) ;;
            --git-dir|--work-tree)
                _fw_git_dir_is_project "${words[$((i + 1))]:-}" "$_cwd" >/dev/null || return 1
                i=$((i + 2)) ;;
            --git-dir=*|--work-tree=*)
                _fw_git_dir_is_project "${tok#*=}" "$_cwd" >/dev/null || return 1
                i=$((i + 1)) ;;
            --namespace)
                i=$((i + 2)) ;;
            --namespace=*|-P|--no-pager)
                i=$((i + 1)) ;;
            # -c k=v is never read-only: too many config keys run a program
            # (pager, fsmonitor, textconv, filters, ssh/askpass, aliases, ...)
            # for a denylist to be complete, so it fails closed with the rest.
            -*) return 1 ;;
            *) break ;;
        esac
    done
    [ "$i" -lt "$n" ] || return 1
    # T-4409: with no -C/--git-dir (or with them), git discovers the repository from
    # its cwd, so the effective cwd must itself be inside PROJECT_ROOT. Unknown
    # (empty) fails the check: `cd /tmp/evil && git status` reads /tmp/evil's config.
    _fw_git_dir_is_project "$_cwd" / >/dev/null || { [ -z "$_cwd" ] && return 2; return 1; }
    echo "git ${words[*]:$i}"
}

# T-4367: git diff|log|show|diff-tree|diff-index|whatchanged take --output=FILE (or
# `--output FILE`), which writes FILE although the verb is a read. git accepts any
# unambiguous prefix of a long option, so --ou/--out/--outp/--outpu match too.
# --output-indicator-* are display options and `-o` is not an output flag: neither
# matches. Words after `--` are pathspecs but are refused as well (fail closed).
# _fw_git_has_output_opt <sub-verb> <normalised "git verb args...">; 0 = has one.
_fw_git_has_output_opt() {
    case "$1" in
        diff|log|show|diff-tree|diff-index|whatchanged) ;;
        *) return 1 ;;
    esac
    local w
    for w in $2; do
        [[ "$w" =~ ^--ou(t(p(u(t)?)?)?)?(=.*)?$ ]] && return 0
    done
    # T-4485: those were RAW words. git gets the word after bash's quote removal and
    # expansion, so "--output=F", --out\put=F, $o and ${O:---output=F} all hid the
    # option. Any quote, backslash, $, backtick, glob or brace sends the words to
    # lib/shell_write_scan.py git_output_risk — the write scanner's tokenizer, so both
    # gates read the same words. Only its exit 3 ("no risk") clears; a missing
    # python3 or library, or any error, keeps the command gated.
    local _special="[]\$\`'\"\\\\*?[{]"
    [[ "$2" =~ $_special ]] || return 1
    python3 -I -c 'import sys
sys.path.insert(0, sys.argv[1])
import shell_write_scan as s
sys.exit(1 if s.git_output_risk(sys.argv[2]) else 3)' "$_FW_SAFE_COMMANDS_LIB" "$2" 2>/dev/null
    [ $? -eq 3 ] && return 1
    return 0
}
_FW_SAFE_COMMANDS_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../lib" 2>/dev/null && pwd)"

# T-4513: git grep -O[CMD] / --open-files-in-pager[=CMD] STARTS CMD (default: the
# pager) on the matching files although the verb is a read. Judged on the dequoted
# words (_fw_option_words): a short bundle with O before a letter that takes an
# argument (-iO, -Ovim; not -eO, whose O is the pattern), any unambiguous prefix
# of the long option (git accepts --op…), or a word that begins with an expansion.
# Words after `--` are pathspecs but are refused as well (fail closed).
# _fw_git_grep_opens_pager <normalised "git grep args...">; 0 = may open one.
_fw_git_grep_opens_pager() {
    local i j tok
    _fw_option_words "$1" || return 0
    for (( i=2; i<${#_FW_OW[@]}; i++ )); do
        tok="${_FW_OW[i]}"
        [ "${_FW_OWK[i]}" = E ] && return 0
        case "$tok" in
            --op*)
                tok="${tok%%=*}"
                case --open-files-in-pager in "$tok"*) return 0 ;; esac ;;
            --*) ;;
            -?*)
                for (( j=1; j<${#tok}; j++ )); do
                    case "${tok:j:1}" in
                        O) return 0 ;;
                        e|f|A|B|C|m|-) break ;;
                    esac
                done ;;
        esac
    done
    return 1
}

# T-4631: git help -w / --web starts a web browser (via its web--browse helper) whatever the
# configuration says, so it is an action, not a read. Judged on the dequoted words:
# a short bundle holding w, any prefix of --web (git accepts --w, --we), or a word
# that begins with an expansion. Words after `--` are refused as well.
# _fw_git_help_opens_browser <normalised "git help args...">; 0 = may open one.
_fw_git_help_opens_browser() {
    local i tok
    _fw_option_words "$1" || return 0
    for (( i=2; i<${#_FW_OW[@]}; i++ )); do
        tok="${_FW_OW[i]}"
        [ "${_FW_OWK[i]}" = E ] && return 0
        case "$tok" in
            --?*) case --web in "${tok%%=*}"*) return 0 ;; esac ;;
            -?*) case "${tok:1}" in *w*) return 0 ;; esac ;;
        esac
    done
    return 1
}

# T-4629: git remote and git reflog are mixed verbs (T-2888's class): `remote add|
# remove|set-url|…` write .git/config, `reflog expire|delete|drop` destroy history.
# remote is admitted only bare, after -v/--verbose, or with show / get-url; reflog
# unless any word is expire, delete or drop (its default is show, and an argument
# that is not a sub-verb is a ref to show). Judged on the dequoted words; a word
# that begins with an expansion, or words that cannot be resolved, are refused.
# _fw_git_mixed_verb_is_read <normalised "git verb args...">; 0 = read.
_fw_git_mixed_verb_is_read() {
    local i tok
    _fw_option_words "$1" || return 1
    for (( i=2; i<${#_FW_OW[@]}; i++ )); do
        [ "${_FW_OWK[i]}" = E ] && return 1
    done
    case "${_FW_OW[1]:-}" in
        remote)
            for (( i=2; i<${#_FW_OW[@]}; i++ )); do
                tok="${_FW_OW[i]}"
                case "$tok" in
                    -v) continue ;;
                    --v*) case --verbose in "$tok"*) continue ;; esac; return 1 ;;
                    show|get-url) return 0 ;;
                    *) return 1 ;;
                esac
            done
            return 0 ;;
        reflog)
            for (( i=2; i<${#_FW_OW[@]}; i++ )); do
                case "${_FW_OW[i]}" in expire|delete|drop) return 1 ;; esac
            done
            return 0 ;;
    esac
    return 1
}

# T-4627: git ls-remote / fetch --upload-pack=CMD and push --receive-pack=CMD /
# --exec=CMD RUN CMD as the remote's pack program (local-path and ssh transports),
# although the verbs are admitted by name. Judged on the dequoted words: any
# unambiguous prefix of those long options (git accepts --u…, --rece…, --e…), any
# short bundle holding u on ls-remote/fetch (-u is --upload-pack on ls-remote,
# --update-head-ok on fetch: refused on both, fail closed), and a word that begins
# with an expansion. Words after `--` are refused as well.
# _fw_git_transport_runs_program <normalised "git verb args...">; 0 = may run one.
_fw_git_transport_runs_program() {
    local i j tok sub
    _fw_option_words "$1" || return 0
    sub="${_FW_OW[1]:-}"
    for (( i=2; i<${#_FW_OW[@]}; i++ )); do
        tok="${_FW_OW[i]}"
        [ "${_FW_OWK[i]}" = E ] && return 0
        case "$tok" in
            --?*)
                tok="${tok%%=*}"
                [ "${#tok}" -ge 3 ] || continue
                case "$sub" in
                    push) case --receive-pack in "$tok"*) [ "${#tok}" -ge 4 ] && return 0 ;; esac
                          case --exec in "$tok"*) return 0 ;; esac ;;
                    *)    case --upload-pack in "$tok"*) return 0 ;; esac ;;
                esac ;;
            -?*)
                [ "$sub" = push ] && continue
                for (( j=1; j<${#tok}; j++ )); do
                    [ "${tok:j:1}" = u ] && return 0
                done ;;
        esac
    done
    return 1
}

# T-4512: THE word list every option check reads. The find and curl/wget checks
# matched quote-stripped words and sed/sort matched raw text, so -'exec', "-o",
# $'-i' and -{o,u} hid the option they look for (G-121; T-4485 fixed git alone).
# _fw_option_words <one clause> fills _FW_OW (words as the program gets them) and
# _FW_OWK (L = literal, E = begins with a quoted expansion, content unknown).
# Plain text is split in bash; anything with a quote, backslash, $, backtick, glob
# or brace goes to lib/shell_write_scan.py option_words, the tokenizer git_output_risk
# uses. Returns 1 when the words cannot be resolved (unquoted $, backtick, unquoted
# glob, unterminated quote) or python3/the library fails: callers treat 1 as unsafe.
# T-4650: `_fw_option_words CLAUSE globs` admits an unquoted glob whose first
# character is a literal other than `-` as kind G (file names, never an option);
# only a caller that checks where a G stands may pass it.
_fw_option_words() {
    _FW_OW=(); _FW_OWK=()
    local _special="[]\$\`'\"\\\\*?[{]" _rec _ok=0
    if ! [[ "$1" =~ $_special ]]; then
        read -ra _FW_OW <<< "$1"
        local _i
        for _i in "${!_FW_OW[@]}"; do _FW_OWK[_i]=L; done
        return 0
    fi
    while IFS= read -r -d '' _rec; do
        if [ "$_rec" = OK ]; then _ok=1; break; fi
        _FW_OWK+=("${_rec:0:1}"); _FW_OW+=("${_rec:1}")
    done < <(python3 -I -c 'import sys
sys.path.insert(0, sys.argv[1])
import shell_write_scan as s
words, why = s.option_words(sys.argv[2], globs=(sys.argv[3] == "globs"))
if words is None:
    sys.exit(1)
sys.stdout.write("".join(k + w + "\0" for w, k in words) + "OK\0")' "$_FW_SAFE_COMMANDS_LIB" "$1" "${2:-}" 2>/dev/null)
    [ "$_ok" -eq 1 ] && return 0
    _FW_OW=(); _FW_OWK=()
    return 1
}

# T-4509: can this awk clause run a command? The arm below admitted awk on the
# argument that its only write form needs a literal `>`, but awk also RUNS commands:
# system("…"), "cmd" | getline, print | "cmd", gawk's |& coprocess. The program text
# is judged by lib/shell_write_scan.py awk_program_risk (strings, regex literals and
# comments are data). Options are a whitelist: -f/-E/-i/-l load code the text does
# not show, -d/-D/-o/-p write files (gawk), and anything unknown fails closed, as do
# a program that begins with an expansion and a missing python3 or library.
_fw_awk_runs_command() {
    local i tok n prog_seen=0
    local -a progs=()
    _fw_option_words "$1" || return 0
    n=${#_FW_OW[@]}
    for (( i=1; i<n; i++ )); do
        tok="${_FW_OW[i]}"
        [ "${_FW_OWK[i]}" = E ] && return 0
        case "$tok" in
            --) i=$((i + 1)); break ;;
            -F|-v|--field-separator|--assign) i=$((i + 1)) ;;
            -F?*|-v?*|--field-separator=*|--assign=*) ;;
            -e|--source) i=$((i + 1)); progs+=("${_FW_OW[i]:-}"); prog_seen=1 ;;
            --source=*) progs+=("${tok#--source=}"); prog_seen=1 ;;
            -b|-c|-n|-N|-M|-O|-P|-r|-s|-S|-t|-L|-V|--posix|--traditional|--sandbox|--version|\
            --characters-as-bytes|--non-decimal-data|--re-interval|--bignum|--optimize|\
            --use-lc-numeric|--lint|--lint=*|--copyright) ;;
            -*) return 0 ;;
            *) break ;;
        esac
    done
    if [ "$prog_seen" -eq 0 ]; then
        [ "$i" -lt "$n" ] || return 1
        [ "${_FW_OWK[i]}" = E ] && return 0
        progs+=("${_FW_OW[i]}")
    fi
    python3 -I -c 'import sys
sys.path.insert(0, sys.argv[1])
import shell_write_scan as s
sys.exit(1 if any(s.awk_program_risk(p) for p in sys.argv[2:]) else 3)' "$_FW_SAFE_COMMANDS_LIB" "${progs[@]}" 2>/dev/null
    [ $? -eq 3 ] && return 1
    return 0
}

# T-4510: can this sed clause run a command? GNU sed runs one with the `e` command
# and the `e` flag of `s`. The scripts (-e/--expression, joined by newlines as sed
# joins them, or the first operand when none is given) are judged by
# lib/shell_write_scan.py sed_script_risk. Options are a whitelist: -f/--file loads
# a script the text does not show, and anything unknown or ambiguous fails closed,
# as do a word that begins with an expansion and a missing python3 or library.
_fw_sed_runs_command() {
    local i j tok n opt script_seen=0 script=""
    local -a longs=(--expression= --file= --line-length= --quiet --silent --regexp-extended \
        --separate --unbuffered --null-data --posix --debug --sandbox --binary \
        --follow-symlinks --version --help --in-place)
    _fw_option_words "$1" globs || return 0
    n=${#_FW_OW[@]}
    for (( i=1; i<n; i++ )); do
        tok="${_FW_OW[i]}"
        [ "${_FW_OWK[i]}" = E ] && return 0
        case "$tok" in
            --) i=$((i + 1)); break ;;
            --?*)
                opt=""
                for j in "${longs[@]}"; do
                    case "${j%=}" in "${tok%%=*}"*) [ -n "$opt" ] && return 0; opt="$j" ;; esac
                done
                case "$opt" in
                    '') return 0 ;;
                    --file=|--in-place=) return 0 ;;
                    --expression=|--line-length=)
                        if [ "${tok#*=}" != "$tok" ]; then j="${tok#*=}"
                        else i=$((i + 1)); j="${_FW_OW[i]:-}"; case "${_FW_OWK[i]:-}" in E|G) return 0 ;; esac; fi
                        [ "$opt" = --expression= ] && { script+="${j}"$'\n'; script_seen=1; } ;;
                esac ;;
            -?*)
                for (( j=1; j<${#tok}; j++ )); do
                    case "${tok:j:1}" in
                        n|E|r|s|u|z|b) ;;
                        e|l)
                            opt="${tok:j+1}"
                            if [ -z "$opt" ]; then i=$((i + 1)); opt="${_FW_OW[i]:-}"; case "${_FW_OWK[i]:-}" in E|G) return 0 ;; esac; fi
                            [ "${tok:j:1}" = e ] && { script+="${opt}"$'\n'; script_seen=1; }
                            break ;;
                        *) return 0 ;;
                    esac
                done ;;
            *) break ;;
        esac
    done
    if [ "$script_seen" -eq 0 ]; then
        [ "$i" -lt "$n" ] || return 1
        case "${_FW_OWK[i]}" in E|G) return 0 ;; esac
        script="${_FW_OW[i]}"
        i=$((i + 1))
    fi
    # T-4650: a glob FILE operand is admitted only beside a print-only script
    # (ADDR[,ADDR]p per line) and with no operand that is a bare sed command
    # letter (`*.md w out` reads as a detached w command, so it is refused).
    for (( j=i; j<n; j++ )); do
        [ "${_FW_OWK[j]}" = G ] || continue
        for (( j=i; j<n; j++ )); do
            case "${_FW_OW[j]}" in w|W|e|r|R) return 0 ;; esac
        done
        local _addr='([0-9]+|\$|/[^/]*/)' _line
        while IFS= read -r _line; do
            [ -z "$_line" ] && continue
            [[ "$_line" =~ ^${_addr}(,${_addr})?p$ ]] || return 0
        done <<< "$script"
        break
    done
    python3 -I -c 'import sys
sys.path.insert(0, sys.argv[1])
import shell_write_scan as s
sys.exit(1 if s.sed_script_risk(sys.argv[2]) else 3)' "$_FW_SAFE_COMMANDS_LIB" "$script" 2>/dev/null
    [ $? -eq 3 ] && return 1
    return 0
}

# T-4512: does this sed/sort clause name its in-place / output option? The outer
# has_bash_write_pattern regexes read the raw line, so a quoted or brace-built
# `-i` / `-o` passed them. Judged on _fw_option_words; a word that cannot be
# resolved, or one that begins with an expansion, counts as the option.
_fw_filter_option_writes() {
    local base="$1" i tok globs=""
    # T-4650: a G word never begins with `-`, so it cannot hide sed's -i.
    [ "$base" = sed ] && globs=globs
    _fw_option_words "$2" $globs || return 0
    for (( i=1; i<${#_FW_OW[@]}; i++ )); do
        tok="${_FW_OW[i]}"
        [ "${_FW_OWK[i]}" = E ] && return 0
        [ "$tok" = -- ] && return 1
        case "$base:$tok" in
            sed:--i*|sort:--o*) return 0 ;;
            *:--*) ;;
            sed:-*i*|sort:-*o*) return 0 ;;
        esac
    done
    return 1
}

# T-4628: does this uniq/xxd/gunzip clause write a file with no redirect? uniq and
# xxd write their SECOND operand (`uniq IN OUT`, `xxd -r -p IN OUT`); gunzip replaces
# X.gz with X unless it writes to stdout (-c) or only inspects (-t, -l). Operands are
# counted on _fw_option_words with option values skipped: uniq -f/-s/-w and their long
# forms (getopt permutes, so options may follow operands); xxd -c/-g/-l/-n/-o/-s/-R and
# their long spellings, options only before the first operand (xxd stops there, so
# `xxd IN -r` writes a file named -r); gunzip -S/--suffix. A word that cannot be
# resolved, or one that begins with an expansion, counts as a write.
_fw_filter_operand_writes() {
    local base="$1" i j tok ops=0 out=0 opts=1
    _fw_option_words "$2" || return 0
    for (( i=1; i<${#_FW_OW[@]}; i++ )); do
        tok="${_FW_OW[i]}"
        [ "${_FW_OWK[i]}" = E ] && return 0
        if [ "$opts" -eq 0 ] || [ "$tok" = - ] || [[ "$tok" != -* ]]; then
            ops=$((ops + 1))
            [ "$base" = xxd ] && opts=0
            [ "$base" = gunzip ] && [ "$tok" = - ] && ops=$((ops - 1))
            continue
        fi
        [ "$tok" = -- ] && { opts=0; continue; }
        case "$base:$tok" in
            uniq:--*=*|gunzip:--*=*) ;;
            uniq:--*)
                for j in --skip-fields --skip-chars --check-chars; do
                    case "$j" in "$tok"*) i=$((i + 1)); break ;; esac
                done ;;
            uniq:-*)
                for (( j=1; j<${#tok}; j++ )); do
                    case "${tok:j:1}" in
                        f|s|w) [ $((j + 1)) -eq ${#tok} ] && i=$((i + 1)); break ;;
                    esac
                done ;;
            xxd:-c|xxd:-g|xxd:-l|xxd:-n|xxd:-o|xxd:-s|xxd:-R|xxd:-cols|xxd:-groupsize|\
            xxd:-len|xxd:-name|xxd:-offset|xxd:-seek) i=$((i + 1)) ;;
            xxd:-*) ;;
            gunzip:--stdout|gunzip:--to-stdout|gunzip:--test|gunzip:--list) out=1 ;;
            gunzip:--suffix) i=$((i + 1)) ;;
            gunzip:--*) ;;
            gunzip:-*)
                for (( j=1; j<${#tok}; j++ )); do
                    case "${tok:j:1}" in
                        c|t|l) out=1 ;;
                        S) [ $((j + 1)) -eq ${#tok} ] && i=$((i + 1)); break ;;
                    esac
                done ;;
        esac
    done
    case "$base" in
        uniq|xxd) [ "$ops" -ge 2 ] ;;
        gunzip) [ "$ops" -ge 1 ] && [ "$out" -eq 0 ] ;;
        *) return 1 ;;
    esac
}

# T-4630: does this journalctl/dmesg clause change system state? journalctl's
# maintenance options delete, rotate, flush or sync journal files, regenerate the
# catalog or FSS keys, and --cursor-file=FILE rewrites FILE; dmesg -C/-c clear the
# ring buffer and -D/-E/-n change console logging. Both use getopt_long, so any
# prefix of a long option counts (an ambiguous one fails in the tool, so refusing it
# costs nothing); `--cursor` itself is journalctl's read option and stays. dmesg
# short bundles are scanned whole (fail closed). Judged on the dequoted words; a
# word that cannot be resolved, or one that begins with an expansion, counts.
_fw_option_changes_state() {
    local base="$1" i j tok longs
    case "$base" in
        journalctl) longs="--vacuum-time --vacuum-size --vacuum-files --rotate --flush --sync --relinquish-var --smart-relinquish-var --update-catalog --setup-keys --cursor-file" ;;
        dmesg) longs="--clear --read-clear --console-off --console-on --console-level" ;;
        *) return 1 ;;
    esac
    _fw_option_words "$2" || return 0
    for (( i=1; i<${#_FW_OW[@]}; i++ )); do
        tok="${_FW_OW[i]}"
        [ "${_FW_OWK[i]}" = E ] && return 0
        [ "$tok" = -- ] && return 1
        case "$tok" in
            --?*)
                tok="${tok%%=*}"
                [ "$base:$tok" = journalctl:--cursor ] && continue
                for j in $longs; do
                    case "$j" in "$tok"*) return 0 ;; esac
                done ;;
            -?*)
                [ "$base" = dmesg ] || continue
                case "${tok:1}" in *[cCDEn]*) return 0 ;; esac ;;
        esac
    done
    return 1
}

# T-4626: does this sort/rg clause name an option that STARTS a program? sort
# --compress-program=CMD runs CMD when it spills to temp files (getopt accepts any
# unambiguous prefix; `--c` alone is ambiguous with --check, so `--co…` is it). rg
# --pre CMD runs CMD per searched file and --hostname-bin CMD runs it once; rg takes
# no abbreviations. Judged on _fw_option_words like the write check above: a word
# that cannot be resolved, or one that begins with an expansion, counts as the option.
_fw_option_runs_program() {
    local base="$1" i tok
    _fw_option_words "$2" || return 0
    for (( i=1; i<${#_FW_OW[@]}; i++ )); do
        tok="${_FW_OW[i]}"
        [ "${_FW_OWK[i]}" = E ] && return 0
        [ "$tok" = -- ] && return 1
        case "$base:${tok%%=*}" in
            sort:--co*) case --compress-program in "${tok%%=*}"*) return 0 ;; esac ;;
            rg:--pre|rg:--hostname-bin) return 0 ;;
        esac
    done
    return 1
}

# Single (non-compound) command classification. This is the original
# is_bash_safe_command body, unchanged apart from the name.
_fw_single_command_is_safe() {
    local cmd="$1"

    # T-2834: trim surrounding whitespace. Chain segments arrive with the space
    # that followed the operator (`ls && FW_X=1 fw work-on T-1` → segment 2 is
    # " FW_X=1 fw work-on T-1"), and the T-1908 env-prefix regex below is
    # ^-anchored — a leading space defeats it, the base extracts as the env
    # assignment, nothing matches, and the segment reads unsafe. Caught by
    # tests/unit/safe_commands_chain.bats "env-var prefix is stripped per
    # segment", which failed on the first run of this very fix.
    cmd="${cmd#"${cmd%%[![:space:]]*}"}"
    cmd="${cmd%"${cmd##*[![:space:]]}"}"

    # F-15 (T-3466): a TERMINAL `VAR=$(cmd)` assignment — the whole remaining
    # segment is one assignment whose value is a command substitution, nothing
    # after it. This is a different shape from the T-1908 env-prefix stripper
    # below: that one strips a `KEY=VALUE` PREFIX in front of a command that
    # follows it (`KEY=VALUE cmd args`); here the assignment IS the entire
    # statement and the command to judge sits INSIDE `$( )`. The file's own
    # header comment (T-2834 block, "Deliberately NOT handled: command
    # substitution") scoped that exclusion to the general case — an argument
    # elsewhere on the line containing `$(...)`, e.g. `curl "$(fw watchtower
    # url)/page"`, where widening would risk admitting the OUTER command on the
    # strength of an inner one it doesn't share safety with. A terminal
    # assignment has no outer command to conflate with; the substitution's
    # result is the entire effect of the line.
    #
    # Delegates to the top-level, chain-aware entry point (not a second call
    # into this function) so `X=$(cmd1 && cmd2)` requires EVERY clause inside
    # the substitution to be independently safe, same as top-level chains
    # (T-2834's compound-command rule). Recursion terminates because the
    # matched string is strictly shorter than $cmd each time (the `VAR=$(` and
    # trailing `)` are stripped), and the outer redirect/rm/tee/heredoc scan
    # (has_bash_write_pattern) still runs against the ORIGINAL, un-recursed
    # line at every call site — this cannot admit a write no matter what the
    # inner command resolves to.
    #
    # Extraction is a plain prefix/suffix strip, not a balanced-paren parser:
    # for a well-formed `VAR=$( ... )` matching this anchored pattern, stripping
    # `VAR=$(` off the front and the LAST `)` off the back is exactly correct
    # for arbitrary nesting (each inner `$(...)` still closes inside what's
    # captured) — verified against `X=$(echo $(hostname))` in the Decisions
    # section. It only goes wrong if the line contains a literal unbalanced `)`
    # as DATA, which is not a shape this dispatch's two reproduction cases hit,
    # and the failure direction there is a garbled inner string that will not
    # match any allowlist arm — i.e. still toward blocking, not toward opening.
    if [[ "$cmd" =~ ^[A-Za-z_][A-Za-z0-9_]*=\$\((.*)\)[[:space:]]*$ ]]; then
        is_bash_safe_command "${BASH_REMATCH[1]}" && return 0
        return 1
    fi

    # T-3644 (ported from 055, framework:pickup offset 227): a segment that is
    # ONLY a literal assignment — `WURL=x` in `WURL=x; curl -sf "$WURL/"` — runs
    # nothing and writes nothing. The whole segment must be the assignment: the
    # value is unquoted words, "double" or 'single' quoted runs, nothing else,
    # so `X=1 rm -rf /` (whitespace after the value) never matches. No command
    # substitution in any form: `$(`, `$((` and backticks are refused here even
    # inside double quotes (the terminal `VAR=$(cmd)` shape is F-15 above).
    # A bare assignment persists for the REST of the line, so `PATH=/tmp; cat x`
    # changes what `cat` resolves to — the T-3374 denylist applies here too.
    # Writes are still judged separately by has_bash_write_pattern on the
    # original line, so `X=1 > f` stays blocked.
    if [[ "$cmd" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(([^[:space:]\"\'\`\;\&\|\<\>\(\)]|\"[^\"\`]*\"|\'[^\']*\')*)$ ]]; then
        # T-4408: name AND value (a GIT_DIR=/outside the next git inherits once
        # exported). BASH_REMATCH is read before the predicate overwrites it.
        local _an="${BASH_REMATCH[1]}" _av="${BASH_REMATCH[2]}"
        _fw_env_assign_is_denied "$_an" "$_av" && return 1
        [[ "$_av" == *'$('* ]] && return 1
        return 0
    fi

    # T-2988: strip shell grouping punctuation from the segment's edges.
    #
    # Both readers below take a token positionally — `awk '{print $1}'` for the
    # base and `awk '{print $2}'` for the sub-verb — so a grouping character
    # touching either token corrupts it. Measured, all previously blocked:
    #
    #     (fw doctor)      base `(fw`     no case arm matches
    #     ( fw doctor )    base `(`       the paren IS the first word
    #     (bin/fw doctor)  base `fw` ✓, sub-verb `doctor)` ✗
    #
    # The third is why this hid for so long: `s|.*/||` in the base extraction
    # eats a leading `(` as a side effect whenever a path follows it, so the
    # path-ful spellings agents use in this repo (`bin/fw …`) classify correctly
    # more often than the bare `fw …` a consumer's shim produces. Correctness
    # there was an accident of the path, not of the parser.
    #
    # Iterate: `( fw doctor )` needs paren, then whitespace, then paren.
    #
    # This cannot widen the allowlist. Punctuation contributes nothing to the
    # safety verdict — write patterns are judged separately by
    # has_bash_write_pattern against the ORIGINAL, unstripped command line in
    # check-active-task.sh, so `(fw doctor > /tmp/x)` stays blocked on the
    # redirect. Stripping only ever exposes the real command to the same case
    # arms: `(rm -rf /tmp/x)` becomes `rm -rf /tmp/x`, which no arm matches.
    #
    # Same family as the env-prefix stripper immediately below (T-1908) and
    # L-547 / T-2834 — three incidents now of a positional token reader meeting
    # a prefix it was not taught about.
    # Stripped with `case`, not `${cmd%[)};]}`: a `}` inside a bracket expression
    # closes the parameter expansion early, so that form silently APPENDS `;]}`
    # to cmd on every pass and the loop never converges. (Found by hanging this
    # function for five minutes — the same class of defect as the one being
    # fixed, one layer down: a pattern reader meeting punctuation nobody taught
    # it about.) `case` arms need no such escaping, and cmd can only shrink here,
    # so termination is structural rather than hoped for.
    local _prev=""
    while [ "$cmd" != "$_prev" ]; do
        _prev="$cmd"
        case "$cmd" in
            '('*|'{'*) cmd="${cmd#?}" ;;
        esac
        case "$cmd" in
            *')'|*'}'|*';') cmd="${cmd%?}" ;;
        esac
        cmd="${cmd#"${cmd%%[![:space:]]*}"}"
        cmd="${cmd%"${cmd##*[![:space:]]}"}"
    done

    # A segment that was nothing but grouping punctuation (`}` from `{ cmd; }`)
    # carries no command, so there is nothing in it to judge unsafe.
    [ -z "$cmd" ] && return 0

    # T-1908: strip leading env-var prefixes (`KEY=val [KEY2=val2 ...] cmd args`).
    # Without this, the L-399 / T-1890 bypass-mechanism contract that promises
    # `FW_SWITCH_FOCUS=1 fw work-on T-XXX` works actually fails — the awk
    # extraction below returns `FW_SWITCH_FOCUS=1` as the base, no case
    # matches, the safe-command path is skipped, and the downstream
    # captured-status check blocks the very command the focus-drift block
    # message recommended. Strip one prefix at a time until none remain.
    # T-3374: now stops at a denied name (PATH/LD_*/BASH_ENV/IFS/...), leaving it
    # as the first word so no case arm matches and the line gates.
    _fw_strip_env_prefixes "$cmd"; cmd="$_FW_ENV_STRIPPED"

    # T-3096: strip TRANSPARENT WRAPPERS and judge the command they wrap.
    #
    # `timeout 30 termlink agent inbox` extracts base `timeout`, matches no arm, and
    # reads unsafe — so wrapping any allowed command in a timeout gated it. This is the
    # THIRD recorded instance of one class: a positional token reader meeting a prefix
    # nobody taught it about. The other two are named directly above (T-1908 env-var
    # prefixes) and at :117 (T-2988 grouping punctuation). Adding `timeout` to the
    # allowlist as if it were a command would have been the fourth patch of a symptom;
    # a wrapper is not a command, it is a prefix, and prefixes belong in a stripper.
    #
    # This is strictly SAFER than an allowlist entry would have been, and it closes a
    # pre-existing hole rather than opening one: `env` sat in Category 5 as
    # unconditionally safe, so `env ./anything.sh` classified safe on the strength of
    # the word `env`. After stripping, the same line is judged on `./anything.sh` —
    # which no arm matches, so it gates. Measured both ways in the task's Decisions.
    #
    # Every failure direction here is toward BLOCKING. An option we do not recognise, a
    # missing duration, an empty remainder, or a wrapper whose own argument grammar does
    # not match leaves `cmd` untouched, so the base stays the wrapper name, which no arm
    # matches. `xargs` is deliberately NOT a wrapper: its command is assembled from stdin
    # at runtime, so there is nothing static to judge.
    local _wprev=""
    while [ "$cmd" != "$_wprev" ]; do
        _wprev="$cmd"
        local _wbase _wrest _wtok _wnext
        _wbase=$(printf '%s' "$cmd" | awk '{print $1}' | sed 's|.*/||')
        case "$_wbase" in
            timeout|nohup|nice|stdbuf|command|env|flock) ;;
            *) break ;;
        esac
        # `command -v X` / `command -V X` do not RUN X, they print where it lives —
        # read-only, and Category 3 already answers for them. Stripping would hand the
        # judge `X` itself, so `command -v git` would be decided as if it were `git`
        # with no sub-verb, and gate. Leave the wrapper in place for the query forms.
        if [ "$_wbase" = "command" ] && [[ "${cmd#*[[:space:]]}" == -[vV]* ]]; then
            break
        fi
        _wrest="${cmd#*[[:space:]]}"
        [ "$_wrest" = "$cmd" ] && break     # bare wrapper, no wrapped command
        _wrest="${_wrest#"${_wrest%%[![:space:]]*}"}"
        [ -z "$_wrest" ] && break

        # 1. the wrapper's own options, including the ones that consume a value.
        while [[ "$_wrest" == -* ]]; do
            _wtok=$(printf '%s' "$_wrest" | awk '{print $1}')
            _wnext="${_wrest#*[[:space:]]}"
            [ "$_wnext" = "$_wrest" ] && { _wrest=""; break; }
            _wrest="${_wnext#"${_wnext%%[![:space:]]*}"}"
            # Value-taking options are per-wrapper, not global: `-n` is nice's
            # adjustment (takes a value) and flock's --nonblock (takes none). A global
            # list would make `flock -n /tmp/l true` eat the lock path as -n's value,
            # then eat `true` as flock's positional, and gate a safe line.
            case "$_wbase:$_wtok" in
                timeout:-s|timeout:--signal|timeout:-k|timeout:--kill-after|\
                nice:-n|nice:--adjustment|\
                stdbuf:-i|stdbuf:-o|stdbuf:-e|stdbuf:--input|stdbuf:--output|stdbuf:--error|\
                flock:-w|flock:--wait|flock:-E|flock:--conflict-exit-code)
                    # consumes the following token as its value
                    _wnext="${_wrest#*[[:space:]]}"
                    [ "$_wnext" = "$_wrest" ] && { _wrest=""; break; }
                    _wrest="${_wnext#"${_wnext%%[![:space:]]*}"}"
                    ;;
            esac
        done
        [ -z "$_wrest" ] && break

        # 2. the wrapper's own positional argument, where it has one.
        case "$_wbase" in
            timeout)
                _wtok=$(printf '%s' "$_wrest" | awk '{print $1}')
                [[ "$_wtok" =~ ^[0-9]+(\.[0-9]+)?[smhd]?$ ]] || break
                _wnext="${_wrest#*[[:space:]]}"
                [ "$_wnext" = "$_wrest" ] && break
                _wrest="${_wnext#"${_wnext%%[![:space:]]*}"}"
                ;;
            flock)
                # the lock path — any single non-option token
                _wnext="${_wrest#*[[:space:]]}"
                [ "$_wnext" = "$_wrest" ] && break
                _wrest="${_wnext#"${_wnext%%[![:space:]]*}"}"
                ;;
        esac
        [ -z "$_wrest" ] && break
        cmd="$_wrest"
        # `env`'s K=V assignments are re-stripped by re-entering the T-1908 loop.
        # T-3374: this is the SECOND entry point, and the one that makes
        # `env PATH=/tmp cat x` a distinct bypass from the bare form. It calls
        # the same helper, so the denylist cannot drift between the two.
        _fw_strip_env_prefixes "$cmd"; cmd="$_FW_ENV_STRIPPED"
    done

    # T-3344: strip trailing NON-WRITING redirection tokens — fd-dups (`2>&1`,
    # `1>&2`) and /dev/null sinks (`2>/dev/null`, `>/dev/null`, `&>/dev/null`).
    # Fourth recorded instance of the positional-token-reader class (T-1908
    # env prefixes, T-2988 grouping, T-3096 wrappers): `fw bvp 2>&1` extracted
    # `2>&1` as the sub-verb, matched no arm, and a command this file already
    # allowlists read back as unsafe. Only fd-dups and /dev/null are stripped —
    # a redirect to any real file never matches, and has_bash_write_pattern
    # judges the ORIGINAL unstripped line separately, so this cannot widen
    # what writes are admitted.
    local _rprev=""
    while [ "$cmd" != "$_rprev" ]; do
        _rprev="$cmd"
        case "$cmd" in
            *[[:space:]][0-9]'>&'[0-9]) cmd="${cmd%[[:space:]][0-9]>&[0-9]}" ;;
            *[[:space:]]'2>/dev/null'|*[[:space:]]'2> /dev/null') cmd="${cmd%2>*/dev/null}"; cmd="${cmd%2>/dev/null}" ;;
            *[[:space:]]'>/dev/null'|*[[:space:]]'> /dev/null') cmd="${cmd%>*/dev/null}"; cmd="${cmd%>/dev/null}" ;;
            *[[:space:]]'&>/dev/null') cmd="${cmd%&>/dev/null}" ;;
        esac
        cmd="${cmd%"${cmd##*[![:space:]]}"}"
    done

    # Extract the base command (first word, strip path).
    # Callers must pass a SINGLE command — is_bash_safe_command splits compound
    # commands into segments before reaching here (T-2834). The previous version
    # of this comment claimed the first word was still the primary command for
    # compound commands; it is not, and that assumption was the whole defect.
    local base
    base=$(echo "$cmd" | awk '{print $1}' | sed 's|.*/||')

    case "$base" in
        # Category 1: Git read-only
        git)
            # F-26 (T-4264): judge the verb after git's global options, not the first word.
            local git_norm git_sub
            # T-4662: exit 2 = refused only because the cwd is unknown; the note is
            # printed here, outside the $(...), so its once-per-process guard sticks.
            git_norm=$(_fw_git_skip_globals "$cmd") || { [ $? -eq 2 ] && _fw_note_unknown_git_cwd; return 1; }
            git_sub=$(echo "$git_norm" | awk '{print $2}')
            # T-4367: --output[=FILE] on the diff-family verbs WRITES FILE.
            _fw_git_has_output_opt "$git_sub" "$git_norm" && return 1
            # T-4513: git grep -O / --open-files-in-pager starts a program.
            [ "$git_sub" = grep ] && _fw_git_grep_opens_pager "$git_norm" && return 1
            # T-4627: --upload-pack / --receive-pack / --exec run a program.
            case "$git_sub" in
                ls-remote|fetch|push) _fw_git_transport_runs_program "$git_norm" && return 1 ;;
            esac
            # T-4631: git help -w / --web starts a browser.
            [ "$git_sub" = help ] && _fw_git_help_opens_browser "$git_norm" && return 1
            # T-4631 (decision): --ext-diff and --textconv are NOT refused. Measured on
            # git 2.43: plain `git diff` already runs diff.external, and plain diff /
            # show / log -p already run textconv drivers, so refusing the flags would
            # close nothing. The programs come from configuration, and this arm trusts
            # only configuration the command line cannot choose: the repository is held
            # to PROJECT_ROOT (T-4343, T-4408), and -c, GIT_CONFIG_*, GIT_EXTERNAL_DIFF
            # and the other injection channels are refused above. `git config` is gated.
            # T-4639 closed the residual on the write side: the Write/Edit gate no longer
            # exempts .git/config, info/attributes or hooks/ (check-active-task.sh), so
            # naming a driver (or core.fsmonitor, which plain `git status` runs) needs a
            # task, and a newly set exec-capable key is flagged and logged.
            case "$git_sub" in
                # T-2888 added the second line. The first had grown one verb per
                # incident — T-2052, T-2054, T-2462 and T-2878 each patched this
                # function after an agent hit the null-focus deadlock live — so
                # the sweep was done against a DERIVED set instead of a
                # remembered one: every git sub-verb appearing in this repo's own
                # .sh/.py/.bats, intersected with `git --list-cmds=main` to drop
                # prose, then run through the predicate. Six read-only verbs our
                # own tooling uses came back GATED. Table in the task file.
                #
                # `symbolic-ref` is deliberately NOT here despite being in that
                # residue: `git symbolic-ref HEAD refs/heads/x` writes. Same
                # reason `config` stays out — a verb whose read and write forms
                # differ only by an argument cannot be decided on the verb alone.
                status|log|diff|show|describe|rev-parse|shortlog|blame|ls-files|ls-tree|cat-file|name-rev)
                    return 0
                    ;;
                # T-4629: remote and reflog write on some sub-verbs.
                remote|reflog)
                    _fw_git_mixed_verb_is_read "$git_norm" && return 0
                    return 1
                    ;;
                # T-2889: branch, tag and stash are the same class as config —
                # read and write forms differ only by arguments (`git stash`
                # stashes the working tree, `git branch -d x` / `git tag -d x`
                # delete refs). Decided on the arguments, gated when unsure.
                branch|tag|stash)
                    _fw_git_refverb_is_read "$git_sub" "$git_norm" && return 0
                    return 1
                    ;;
                # T-4368: check-attr and check-ref-format only print; diff-index is a
                # read except --output, refused above (T-4367).
                rev-list|ls-remote|merge-base|grep|for-each-ref|count-objects|check-ignore|verify-commit|var|whatchanged|cherry|diff-tree|diff-index|check-attr|check-ref-format|show-ref|help|version)
                    return 0
                    ;;
                # T-2054: `git add` is task-agnostic — it stages already-produced
                # content (the Write/Edit gate ensured that content was created
                # under a task) and carries no T-XXX reference, so it cannot drift.
                # Safe with no active task. `git commit` is deliberately NOT here:
                # it must reach the focus-drift gate (T-1730) in check-active-task.sh
                # when a focus exists, so its post-completion (null-focus) allow is
                # handled there instead — see the T-2054 block in check-active-task.sh.
                add)
                    return 0
                    ;;
                # T-2462: `git push` / `git fetch` are task-agnostic. Push only
                # PUBLISHES commits that already passed the commit-msg T-XXX gate
                # (P-002) — it creates no work artifact, mutates no working tree,
                # and is not inspected by the focus-drift detector (T-1730 only
                # looks at fw task update / fw context add / git commit -m T-X:).
                # Fetch is pure network read. Gating either on an active task adds
                # zero governance and manufactures a deadlock that fires whenever
                # focus is null: (1) post-completion — `--status work-completed`
                # nulls focus, but "never end a session with unpushed commits"
                # still requires the push (T-2054 exempted commit+add but stopped
                # before push — this closes that 3rd leg of the commit→push
                # pipeline, L-399 producer/consumer parity); (2) worktree sessions
                # where the Bash hook resolves PROJECT_ROOT to the main repo (null
                # focus). This does NOT weaken the pre-push hooks (self-vendor
                # drift, secret scan) — those run inside git, independently of this
                # active-task gate. `pull` is deliberately EXCLUDED: it merges into
                # the working tree (a write), so it stays gated.
                push|fetch)
                    return 0
                    ;;
            esac
            ;;

        # Category 2: File reading
        cat|head|tail|ls|wc|file|stat|realpath|readlink|basename|dirname|test|\[)
            return 0
            ;;

        # Category 3: Searching
        grep|rg|which|where|type|command)
            # T-4626: rg --pre / --hostname-bin run a program.
            [ "$base" = rg ] && _fw_option_runs_program rg "$cmd" && return 1
            return 0
            ;;

        # T-3344: the G-087-safe budget reader. /resume prescribes
        # `checkpoint.sh budget` as THE way to read the budget cache, and the
        # gate blocked it whenever focus sat on a completed task — exactly the
        # moment /resume runs it. `budget` and `status` are pure reads
        # (verified against the case arms at checkpoint.sh:547/:599 — echo,
        # cat, python-print only). `post-tool`, `reset`, and `baseline` write
        # counters/caches and are deliberately absent.
        checkpoint.sh)
            local cp_sub
            cp_sub=$(echo "$cmd" | awk '{print $2}')
            case "$cp_sub" in
                budget|status)
                    return 0
                    ;;
            esac
            ;;

        # T-3238: find is a search tool with a MUTATION grammar bolted on.
        # `-delete` removes what it matches, `-exec`/`-execdir`/`-ok`/`-okdir`
        # run an arbitrary command per match, and `-fprint`/`-fprintf`/
        # `-fprint0`/`-fls` write files with no shell redirect — so the
        # unconditional arm above admitted `find . -delete` with no active
        # task. Same L-547 class as T-3237's bare wget one arm up: the verdict
        # was keyed on the first word, not the whole command. Pure-search
        # forms (-name/-type/-mtime/-print/-print0) stay safe.
        find)
            _fw_find_has_action_predicate "$cmd" && return 1
            return 0
            ;;

        # Category 2b (T-3096): stdout-only text filters.
        #
        # None of these can write anywhere except through a redirect, and a redirect is
        # judged by has_bash_write_pattern against the WHOLE original command line
        # BEFORE this function is consulted (check-active-task.sh :220). So the safety
        # argument is not "these tools are harmless" — it is that their only write route
        # is already gated one layer up, which is the same argument the T-2887 comment
        # on the echo branch makes.
        #
        # `awk` is here despite having a write form (`{print > "f"}`): that form needs a
        # literal `>`, which the outer redirect scan sees whether or not it sits inside
        # quotes. Verified in the task's Decisions rather than assumed. That argument
        # covers WRITING only: awk also runs commands, judged by _fw_awk_runs_command
        # below (T-4509).
        #
        # `sed` is here despite `sed -i`: has_bash_write_pattern carries a dedicated
        # `\bsed\b.*-i` rule (:430), so in-place edits never reach this arm. Same
        # verified-not-assumed treatment. `yq` is deliberately EXCLUDED for the mirror
        # reason — yq v4's `-i` writes in place and NO rule catches it.
        #
        # Derived, not remembered (T-2888 precedent): the set is the read-only bases
        # appearing in this repo's own .sh/.py/.bats and task verification lines that
        # measured GATED. `xargs` is excluded — it runs a command assembled at runtime.
        # `bats`, `make`, `python3 <file>` and `./script.sh` are excluded on the Tier 0
        # scope boundary (CLAUDE.md §Enforcement Tiers, T-2742): a file's contents are
        # not visible to a command-string scan, so executing one is never provably read-only.
        sed|awk|sort|uniq|cut|tr|nl|od|paste|join|fold|expand|unexpand|rev|comm|cmp|diff|colordiff|column|jq|seq|base64|md5sum|sha1sum|sha256sum|cksum|strings|xxd|tput|zcat|gunzip)
            # T-4512: the outer sed -i / sort -o rules read raw text; a quoted or
            # brace-built option is judged here on the dequoted words.
            case "$base" in sed|sort) _fw_filter_option_writes "$base" "$cmd" && return 1 ;; esac
            # T-4628: uniq/xxd write a second operand; gunzip writes in place.
            case "$base" in uniq|xxd|gunzip) _fw_filter_operand_writes "$base" "$cmd" && return 1 ;; esac
            # T-4626: sort --compress-program runs a program.
            [ "$base" = sort ] && _fw_option_runs_program sort "$cmd" && return 1
            # T-4509: awk runs commands with system(), | getline, print | and |&.
            [ "$base" = awk ] && _fw_awk_runs_command "$cmd" && return 1
            # T-4510: GNU sed runs commands with the e command and the e flag of s.
            [ "$base" = sed ] && _fw_sed_runs_command "$cmd" && return 1
            return 0
            ;;

        # Category 3b (T-3096): read-only process / system inspection.
        # Verb-scoped where the tool has both forms; omitted entirely where it does not
        # (`kill`, `ip`, `mount` and friends are NOT here — `ip addr` reads but `ip link
        # set` writes, and a verb-level split there is wider than this task measured).
        pgrep|pidof|getent|journalctl|dmesg|tty|logname|groups|locale|ulimit)
            # T-4630: journalctl --vacuum-*/--rotate/… and dmesg -C/-c/-n change state.
            _fw_option_changes_state "$base" "$cmd" && return 1
            return 0
            ;;
        systemctl)
            local sc_sub
            sc_sub=$(echo "$cmd" | awk '{print $2}')
            case "$sc_sub" in
                status|show|is-active|is-enabled|is-failed|list-units|list-timers|list-unit-files|cat)
                    return 0
                    ;;
            esac
            ;;

        # Category 4b (T-3096): TermLink read verbs, scoped exactly like git and fw.
        #
        # The mutating half is the larger half and stays gated: inject, spawn, dispatch,
        # exec, run, interact, signal, clean, send, post, reply, react, emit, register,
        # deregister, tag, resize, kv set/del, hub start/stop/restart, remote inject/exec,
        # file send, token create, channel create/claim/release. CLAUDE.md's own
        # cross-agent protocol table turns on that read/write split, so encoding it here
        # keeps one boundary rather than two that can disagree (L-399).
        termlink)
            local tl_sub tl_sub2
            tl_sub=$(echo "$cmd" | awk '{print $2}')
            tl_sub2=$(echo "$cmd" | awk '{print $3}')
            case "$tl_sub" in
                list|status|discover|overview|whoami|info|version|help|topics|output|doctor|events|ping)
                    return 0
                    ;;
                agent)
                    case "$tl_sub2" in
                        inbox|unread|recent|history|thread|threads|search|peers|identity|\
                        who_is|who-is|describe|info|help|stats|overview|mentions|digest|\
                        state|timeline|dms|listeners|presence_now|active_now)
                            return 0
                            ;;
                    esac
                    ;;
                channel)
                    # T-3425: `subscribe` is a cursor-bounded read of a topic (the
                    # sidecar inbox's own primitive) and `cv-keys` reads the hub's
                    # in-memory client_msg_id index; neither writes. `post`, `ack`,
                    # `create`, `claim`, `release`, `react`, `reply` stay absent.
                    case "$tl_sub2" in
                        list|info|members|search|thread|threads|unread|state|pinned|\
                        digest|snippet|receipts|describe|claims|subscribe|cv-keys|\
                        ack-status|ack-history)
                            return 0
                            ;;
                    esac
                    ;;
                pty)
                    # T-3344: `pty output <session>` reads a session's recent
                    # output — the worker-observability read /resume-era
                    # monitoring uses. `pty inject` and `pty mode` write into
                    # the session and are deliberately absent.
                    case "$tl_sub2" in
                        output)
                            return 0
                            ;;
                    esac
                    ;;
                remote)
                    # remote list/ping are network reads; remote inject/exec are not.
                    case "$tl_sub2" in
                        list|ping|doctor)
                            return 0
                            ;;
                    esac
                    ;;
                kv)
                    case "$tl_sub2" in
                        get|list)
                            return 0
                            ;;
                    esac
                    ;;
                hub)
                    case "$tl_sub2" in
                        status|probe|fingerprint)
                            return 0
                            ;;
                    esac
                    ;;
                fleet)
                    case "$tl_sub2" in
                        status|history|doctor|verify)
                            return 0
                            ;;
                    esac
                    ;;
            esac
            ;;

        # Category 4: FW diagnostics
        fw|bin/fw)
            local fw_sub
            fw_sub=$(echo "$cmd" | awk '{print $2}')
            local fw_sub3
            fw_sub3=$(echo "$cmd" | awk '{print $3}')
            case "$fw_sub" in
                doctor|metrics|audit|version|resume|help|status|fabric|gaps|promote)
                    return 0
                    ;;

                # ── T-3096: the rest of fw's read-only surface ──────────────────
                #
                # The ten names above were the whole allowlist; measurement found 92 more
                # READ (command, sub-verb) pairs unreachable through it, out of 120 READ
                # of 299 total pairs. The consequence was not theoretical: CLAUDE.md
                # prescribes `curl -sf "$(bin/fw watchtower url)/page"` as THE way to
                # avoid hard-coding port 3000, and `fw watchtower url` gated — so the
                # framework's own canonical idiom was refused whenever focus was null or
                # completed. Same for `fw reviewer`, `fw review-queue`, `fw learnings`,
                # `fw recall`, `fw ask` and `fw bus manifest`, all of which the Quick
                # Reference tells agents to reach for reflexively.
                #
                # Derived by classifying every arm of bin/fw's dispatch case against the
                # function it routes to, with file:line evidence per verdict, in
                # docs/reports/T-3096-fw-verb-classification.md. MIXED and UNKNOWN pairs
                # (20 + 4) are excluded by construction — a verb whose read and write
                # forms differ by an argument cannot be decided on the verb alone, which
                # is the same rule that keeps `git config` and `git symbolic-ref` out.
                #
                # Two deliberate departures from that derivation, both toward gating:
                #
                #   `orchestrator improve` was classified READ because it is currently a
                #   stub that prints. A stub is a temporary property, not a contract, and
                #   the verb's name declares an intent to act — the day it is implemented
                #   the gate would silently permit it. Excluded.
                #
                #   Nothing already allowed above is NARROWED here. The derivation
                #   proposed scoping `integrate` to check|classify and `resume` to quick;
                #   both are whole-command allows today for stated deadlock reasons
                #   (T-2471 runs integrate from a worktree whose PROJECT_ROOT resolves to
                #   the main repo, i.e. null focus). Tightening them would re-open a
                #   deadlock this file has already been patched four times to close.
                ask|recall|search|decisions|timeline|learnings|patterns|practices|policy|\
                costs|review-queue|sessions|approvals)
                    return 0
                    ;;
                watchtower)
                    # T-4562: reachable = do_url + an identity GET; writes nothing.
                    case "$fw_sub3" in port|url|status|reachable) return 0 ;; esac
                    ;;
                config)
                    case "$fw_sub3" in get|list|overrides) return 0 ;; esac
                    ;;
                git)
                    case "$fw_sub3" in status|log|worker-commits) return 0 ;; esac
                    ;;
                arc)
                    # T-3536: judge-driver and review-driver added. Both post-date
                    # T-3096's derivation, which is why they were absent rather than
                    # excluded — see the parity note at the end of this arm.
                    #   judge-driver  lib/arc.sh:1971 "Read-only. … never mutates the
                    #                 arc YAML … it only reports a verdict"; and
                    #                 lib/arc_driver_judge.py has zero write calls.
                    #   review-driver T-3429's static check. `approve-driver` DOES
                    #                 mutate scoped_drivers[] and stays absent.
                    case "$fw_sub3" in list|ls|show|review|show-suggestions|help|judge-driver|review-driver) return 0 ;; esac
                    ;;
                bvp)
                    # bare `fw bvp` is the ranking; `fw bvp T-123` is per-task detail.
                    # T-3536: `judge` added — lib/bvp_judge.py:383 "Never writes
                    # anything. Never touches `bvp_scores:`", zero write calls in the
                    # module. `confirm` writes bvp_scores: and stays absent, as does
                    # `estimate-cost`, which writes cost_estimate:.
                    case "$fw_sub3" in ""|arcs|--quadrant|--include-proposed|--include-completed|--help|-h|T-*|judge) return 0 ;; esac
                    ;;
                healing)
                    case "$fw_sub3" in diagnose|patterns|suggest) return 0 ;; esac
                    ;;
                inception)
                    case "$fw_sub3" in status) return 0 ;; esac
                    ;;
                orchestrator)
                    case "$fw_sub3" in status|routes|next-dispatch|pre-flight) return 0 ;; esac
                    ;;
                resolver)
                    case "$fw_sub3" in workflows|explain|stalled|latched) return 0 ;; esac
                    ;;
                outcome)
                    # `evaluate` prints (lib/outcome.py:347-350); `backprop` appends to
                    # dispatch-outcomes.jsonl (:368) and is deliberately absent.
                    case "$fw_sub3" in evaluate|read|list) return 0 ;; esac
                    ;;
                bus)
                    case "$fw_sub3" in manifest|read) return 0 ;; esac
                    ;;
                pause|assumption|pending)
                    case "$fw_sub3" in list) return 0 ;; esac
                    ;;
                dispatch)
                    case "$fw_sub3" in hosts) return 0 ;; esac
                    ;;
                rail)
                    case "$fw_sub3" in identity|status) return 0 ;; esac
                    ;;
                mcp)
                    case "$fw_sub3" in manifest-show|show|check|wire-fragment|status) return 0 ;; esac
                    ;;
                tier0|onboarding|traceability|enforcement|mirror|release|notify|worktree|designer)
                    case "$fw_sub3" in status|path|url|pending) return 0 ;; esac
                    ;;
                prompt)
                    case "$fw_sub3" in list|ls|show|cat|copy|render) return 0 ;; esac
                    ;;
                termlink)
                    case "$fw_sub3" in check|status|result) return 0 ;; esac
                    ;;
                sidecar)
                    # T-3425 (OBS-461): the peer-consult sidecar's read surface.
                    # `whoami` prints ids; `inbox --peek` reads the topic without
                    # advancing the cursor (plain `inbox` ADVANCES it and is absent);
                    # `status` reads our own outbox/ledger files — unless `--probe`,
                    # which calls the hub, so that form stays gated. `send`, `sweep`
                    # and `e2e` all write (ledger rows, a dispatched worker) and are
                    # deliberately absent. Without this arm a session whose focus
                    # is captured or partial-complete could not even see whether a
                    # consult was waiting for it.
                    # T-3856: `alerts` is the /resume step-7 mail check; it runs at
                    # session START, before focus. It reads; `--mark-seen` writes
                    # only the sidecar shown ledger (framework state, like `fw context`).
                    case "$fw_sub3" in
                        whoami|alerts) return 0 ;;
                        inbox)  case " $cmd " in *" --peek "*) return 0 ;; esac ;;
                        status) case " $cmd " in *" --probe "*) ;; *) return 0 ;; esac ;;
                    esac
                    ;;
                cron)
                    case "$fw_sub3" in status|list) return 0 ;; esac
                    ;;
                corpus)
                    case "$fw_sub3" in lint|explain) return 0 ;; esac
                    ;;
                write-set)
                    case "$fw_sub3" in check) return 0 ;; esac
                    ;;
                reviewer)
                    # `fw reviewer T-XXX` SCANS and writes a verdict block into the task
                    # file, so the bare form is NOT here. Only the override reader is.
                    if [ "$fw_sub3" = "override" ] && [ "$(echo "$cmd" | awk '{print $4}')" = "list" ]; then
                        return 0
                    fi
                    ;;
                context)
                    local ctx_sub
                    ctx_sub=$(echo "$cmd" | awk '{print $3}')
                    case "$ctx_sub" in
                        # T-2878: the four capture verbs are allowed with no
                        # active task for the same reason `task create` is
                        # (T-2052) — they are what the framework PRESCRIBES
                        # after completing work, and completion is the exact
                        # transition that nulls focus. Verb-scoped, not a
                        # blanket `context)` allowance: a mutating context
                        # sub-verb must still fall through to the task check.
                        status|focus|init|add-learning|add-pattern|add-decision|generate-episodic)
                            return 0
                            ;;
                    esac
                    ;;
                task)
                    local task_sub
                    task_sub=$(echo "$cmd" | awk '{print $3}')
                    case "$task_sub" in
                        # T-2052: `create` is task-bootstrap (writes only to the
                        # exempt .tasks/ dir) — must be allowed with no active task,
                        # else the gate deadlocks its own "create a task" advice.
                        # T-4115: `stale` only reads .tasks/active/ (bin/fw `stale)`
                        # arm, no writes, every form incl. --days N) — and fw doctor's
                        # Task-debt WARN tells the agent to run it, often at null focus.
                        list|verify|review|create|stale)
                            return 0
                            ;;
                    esac
                    ;;
                whoami)
                    # T-3534: bare `fw whoami` only reads .framework.yaml and the
                    # hostname. `--register` MINTS an id and writes the file, so it
                    # is absent — same sub-verb granularity as `fw config get` vs
                    # `set`. Identity questions are exactly what an agent asks
                    # between tasks, when focus is most likely to be null.
                    case " $cmd " in *" --register "*) ;; *) return 0 ;; esac
                    ;;
                note)
                    # T-2878: observation capture. Same class as the context
                    # add-* verbs above — the gate must not block the record
                    # of why it fired.
                    return 0
                    ;;
                handover)
                    # T-2878: session handover is the Session End Protocol's
                    # mandatory step; it runs precisely when no task is active.
                    return 0
                    ;;
                work-on|inception)
                    # work-on and inception commands are task bootstrap — always allowed
                    return 0
                    ;;
                upstream)
                    # T-2410 case 2: `fw upstream` has read-only sub-verbs
                    # (status, list, info) — exempt these from the active-task
                    # gate so consumers can inspect upstream pin state under
                    # any focus condition. Mutating sub-verbs (pin, set, sync)
                    # are NOT exempt; they fall through to the task check.
                    local ups_sub
                    ups_sub=$(echo "$cmd" | awk '{print $3}')
                    case "$ups_sub" in
                        status|list|info|show|help|--help|-h|--version|"")
                            return 0
                            ;;
                    esac
                    ;;
                hook)
                    # fw hook * — hooks calling hooks, always allowed
                    return 0
                    ;;
                integrate)
                    # T-2471: `fw integrate {check,classify}` are read-only; `fw
                    # integrate run` is the mutating merge-back verb. All three are
                    # task-agnostic meta-operations on git history: the merge
                    # commits run creates are --no-ff --no-edit (no T-XXX work
                    # artifact — the commit-msg hook already exempts MERGE_HEAD),
                    # and gating them on an active task manufactures a deadlock —
                    # integration runs from a worktree whose Bash-hook PROJECT_ROOT
                    # resolves to the main repo (null focus). This verb-scoped
                    # exemption is the EFFECTIVE focus-gate bypass; it deliberately
                    # does NOT use an FW_INTEGRATION_IN_PROGRESS env honor, which
                    # would reintroduce the T-2446 inherited-env poison class this
                    # arc exists to eliminate. Same category as git push/add/commit
                    # (T-2054/T-2462). run sets FW_INTEGRATION_IN_PROGRESS=1 only
                    # for the python subprocess's own internal git calls.
                    return 0
                    ;;
            esac
            ;;

        # Category 5: System utilities
        #
        # T-3222: curl and wget are NOT unconditionally safe, and their presence
        # here contradicted the admission rule this list states for itself —
        # "only verbs that cannot write a file WITHOUT a shell redirect", which
        # is the basis on which it excludes awk and uniq. `curl -o FILE` and
        # `wget -O FILE` write a file with no redirect, so has_bash_write_pattern
        # (which looks for redirects) never sees them, and both were admitted
        # with NO ACTIVE TASK. Reported by peer 832-Workflow-designer as a side
        # finding on their T-638; confirmed here against the live hook.
        #
        # The destination is the hazard, not the flag: `curl -o -` and
        # `wget -O -` write to stdout and stay safe. T-3237 closed the bare
        # form too: `wget URL` with no flag writes the remote filename into
        # cwd (wget's default), so wget is safe only with an explicit stdout
        # destination; bare `curl URL` (stdout default) stays safe.
        curl|wget)
            _fw_fetch_writes_file "$cmd" && return 1
            return 0
            ;;
        date|uname|ps|ss|id|whoami|hostname|env|printenv|df|du|free|uptime|lsb_release|nproc)
            return 0
            ;;

        # Category 6: Validation
        python3|python)
            # Only safe if it's a parse/check command (no file writes)
            if grep -qE '^\s*(python3?)\s+-c\s' <<< "$cmd"; then
                # Check for write indicators in the inline script
                if grep -qE "(open\(.*, *['\"]w|\.write\(|shutil\.|os\.(rename|remove|unlink|makedirs|system))" <<< "$cmd"; then
                    return 1
                fi
                return 0
            fi
            ;;
        bash|sh)
            # bash -n (syntax check only) is safe
            if grep -qE '^\s*(ba)?sh\s+-n\b' <<< "$cmd"; then
                return 0
            fi
            ;;

        # Special: echo without redirect is safe (diagnostic output)
        #
        # T-2887: this branch used to carry its OWN copy of the redirect regex,
        # `[^>]>[^>]|>>`. has_bash_write_pattern's copy below grew the `2` and `&`
        # exemptions that distinguish a file write from a file-descriptor
        # redirect; this copy never did. So the two disagreed on exactly the
        # fd forms — `echo x 2>&1` and `echo x 2>/dev/null` read as file writes
        # here and as no-write there. Measured, both directions:
        #
        #   echo hi 2>&1          echo-branch:MATCH   has_write:no
        #   echo hi 2>/dev/null   echo-branch:MATCH   has_write:no
        #   echo hi > f           echo-branch:MATCH   has_write:MATCH
        #
        # Delegate instead of re-deriving (L-399: N copies of a predicate can
        # disagree and nothing makes them agree — the same shape as T-2883's
        # six git-identity probes). Reported by 832 as their rail 489 defect;
        # L-518 says sweep our equivalent, and ours had it.
        #
        # Delegating is strictly more conservative than the old copy on the
        # non-fd shapes (it also catches rm / sed -i / tee / heredoc text), and
        # that costs nothing in production: check-active-task.sh:173 already runs
        # has_bash_write_pattern over the WHOLE command before consulting this
        # function at all. The private copy could therefore never contribute a
        # true positive the outer check had not already caught — only the two
        # false positives above.
        echo|printf)
            if ! has_bash_write_pattern "$cmd"; then
                return 0
            fi
            ;;

        # Special: cd is always safe
        cd)
            return 0
            ;;

        # Special: npm/cargo/brew read operations
        npm|npx|cargo|brew)
            local pkg_sub
            pkg_sub=$(echo "$cmd" | awk '{print $2}')
            case "$pkg_sub" in
                list|ls|info|show|search|view|outdated|audit|help|version|--version|-v|-V)
                    return 0
                    ;;
            esac
            ;;
    esac

    # Not in allowlist — caller should check for active task
    return 1
}

# Check if a command contains file-write patterns
has_bash_write_pattern() {
    local cmd="$1"

    # T-3643 (ported from 055, framework:pickup offset 224): a redirect to
    # /dev/null writes nothing. Strip those tokens (`>/dev/null`, `> /dev/null`,
    # `1>`, `2>`, `&>`, `>>`) before the redirect scan, so `cat a > /dev/null`
    # is not a write. The terminator must be whitespace, a separator or end of
    # line: `/dev/nullx`, `/dev/null.bak`, `/dev/null/sub` are ordinary paths
    # and stay writes, and any OTHER redirect on the line still bites below.
    # (The T-3344 strip in is_bash_safe_command covers the allowlist side only;
    # check-active-task consults THIS scan first.)
    # T-4479 (010-termlink T-3370): /dev/stdout and /dev/stderr join the strip;
    # they are the command's own output streams, already visible to the caller.
    # Same terminator rule, so `/dev/stdoutx` and `/dev/stderr.bak` stay writes.
    #
    # T-4479 (010-termlink T-3178): every rule below reads a HERESTRING, never
    # an echo piped into `grep -qE`. The hook runs with pipefail; on a multi-line
    # command over the 64KB pipe buffer, grep -q matches line 1 and exits, echo
    # takes SIGPIPE, the pipeline returns 141, and a non-zero return here means
    # "no write found": the gate failed OPEN on a match (measured 0/5 at HEAD).
    local _scan="$cmd" _sprev=""
    while [ "$_scan" != "$_sprev" ]; do
        _sprev="$_scan"
        _scan=$(printf '%s' "$_scan" | sed -E 's#(^|[^>&0-9])([0-9]|&)?>>?[[:space:]]*/dev/(null|stdout|stderr)([[:space:];|&)]|$)#\1 \4#')
    done

    # Redirect operators (but not comparison operators like 2>&1)
    if grep -qE '[^2>&]>[^>&]|>>' <<< "$_scan"; then
        return 0
    fi

    # T-3746 (832 T-1005): the exemption above excludes `2>` and `&>` wholesale,
    # but only the fd-duplication form (`2>&1`, `&>&2`) writes nothing. `2>err.log`
    # and `&>out.log` redirect to a FILE and must count. /dev/null targets were
    # already stripped from _scan, so `2>/dev/null` stays a read.
    if grep -qE '(2|&)>[^>&]' <<< "$_scan"; then
        return 0
    fi

    # In-place sed. T-4479: anchored on a FLAG token, not a bare `-i` substring,
    # which refused `sed -n p notes-in-x.md` as a write. A flag is a `-` not
    # preceded by a word character, `.` or `-`, then either a short cluster
    # containing `i` (`-i`, `-i.bak`, `-iE`, `-ni`) or any long option opening
    # `--i` (GNU accepts `--in`, `--in-pl` for `--in-place`). Quote-preceded
    # `"-i"` still counts. termlink's version required a non-alphanumeric after
    # the `i`, which let `-iE` (in-place, suffix E) and `--in` through.
    if grep -qE '\bsed\b.*(^|[^[:alnum:]_.-])-(-i|[a-zA-Z]*i)' <<< "$cmd"; then
        return 0
    fi

    # T-3746: sed writes files with no redirect — the `w FILE` command
    # (`sed -n '/x/w out'`) and the `s///w FILE` flag. A `w`/`W` right after a
    # delimiter, quote, `;`, `$` or line number (optionally after s-flags) and
    # followed by a filename. Conservative: replacement text ending `/w x/`
    # also matches, which errs toward the task gate.
    if grep -qE "\\bsed\\b.*[/;'\"\$0-9][gpIiMme0-9]*[wW][[:space:]]+[^[:space:]]" <<< "$cmd"; then
        return 0
    fi

    # T-3746: `sort -o FILE` / `sort --output[=]FILE` write the output file.
    if grep -qE '\bsort\b[^|;&]*[[:space:]](-[a-zA-Z]*o|--output)' <<< "$cmd"; then
        return 0
    fi

    # Destructive file operations (already caught by Tier 0 but belt-and-suspenders)
    if grep -qE '\b(rm|rmdir)\b' <<< "$cmd"; then
        return 0
    fi

    # Heredoc
    if grep -qE '<<\s*['"'"'"]?EOF' <<< "$cmd"; then
        return 0
    fi

    # tee (writes to file)
    if grep -qE '\btee\b' <<< "$cmd"; then
        return 0
    fi

    return 1
}

# ─────────────────────────────────────────────────────────────────────────────
# T-3221: is this command a COMMIT CHECKPOINT, as opposed to a command that
# merely mentions one?
#
# Two branches in check-active-task.sh admit a Bash command on the strength of
# it being a `git commit` — the T-2054 null-focus branch (a completed task must
# still be able to commit its own file-move) and the T-3179 partial-complete
# branch. Both rationales are correct: a commit persists work already produced
# under the Write/Edit gate, so it is not new work.
#
# Both tested whether the command CONTAINED the words, against the raw
# unstripped string, unanchored to any clause:
#
#     [[ "$BASH_CMD" =~ (^|[[:space:]])git[[:space:]]+commit($|[[:space:]]) ]]
#
# Measured against the live hook with focus null, that admitted (T-3221):
#
#     git commit -m "…" ; rm -rf /tmp/x          every clause, past every gate
#     git commit -m "…" | tee f                  a write the gate had FLAGGED
#     somebinary --flag "please git commit this" an unknown binary, admitted
#                                                because a quoted ARGUMENT said so
#     git commit -m "$(cat /etc/hostname)"       arbitrary substitution
#
# The accident that makes this hard to see: `echo "git commit" > f` was blocked,
# because a quote character sits immediately before `git` and the regex wants a
# space there. Whether the hole opened depended on whether a space happened to
# precede the word inside the quotes. Correctness was punctuation luck.
#
# Reported by peer 832-Workflow-designer (their T-638) and confirmed in-tree
# here before acting. This is L-547 (T-2834) once more — a fast-path exemption
# classifying part of a command instead of the whole of it — keyed on the quoted
# payload rather than the first word.
#
# COMPOSITION, not a hand-rolled list. Requiring every clause to be
# independently admissible via _fw_single_command_is_safe, OR to be the commit
# itself, is what keeps `git add -A && git commit -m "…"` working: that is the
# documented post-completion form, and `git add`'s admissibility lives in the
# shared allowlist. A hand-written "cd or git commit" pair would have broken it,
# and would drift from the allowlist the moment either changed.
#
# Every failure direction is toward BLOCKING: an unrecognised clause, an
# unbalanced quote, a substitution, or no commit clause at all all return 1,
# which sends the command to the task gate rather than past it.
# T-3222: does this SINGLE clause make curl/wget write a file?
#
# WHY THIS IS CLAUSE-SCOPED and not an extra pattern in has_bash_write_pattern,
# which is where the admission rule would otherwise suggest it belongs:
# has_bash_write_pattern scans the whole raw command string, so it already
# classifies `git commit -m "we no longer rm -rf the output dir"` as a WRITE —
# a MENTION in a commit message, treated as an action. Measured, and registered
# as OBS-356; it predates all of this. Adding curl to that scanner would have
# added another instance of the exact class this cluster of tasks exists to
# remove. Here the input is one clause, quote-stripped, with its base already
# extracted — so only a real invocation can match.
#
# The DESTINATION is the hazard, not the flag. `curl -o -` and `wget -O -`
# write to stdout and are safe; `wget -o LOG` writes a log file and is not.
#
# Failure direction is toward TREATING IT AS A WRITE, which blocks: an
# unparseable clause (unbalanced quote) returns 0 here, and an unrecognised
# spelling of an output flag falls into the catch-all cluster tests rather than
# out of them. Blocking sends the command to the task gate, which admits it
# whenever a task is active; admitting it skips every gate there is.
_fw_fetch_writes_file() {
    local cmd="$1" stripped base tok rest
    # T-3237: the two tools invert their DEFAULTS, and the pre-fix version only
    # judged flags — so bare `wget URL`, which writes the remote filename into
    # cwd with no flag at all, classified safe on the strength of having typed
    # nothing. curl bare writes to stdout and genuinely is safe. So for wget the
    # burden of proof flips: it is a write UNLESS an explicit stdout destination
    # (`-O-`, `-O -`, `--output-document=-`) or a no-download mode (`--spider`,
    # `--help`, `--version`) is present. The two trackers below carry that.
    local wget_stdout=0 wget_nofetch=0
    # T-4512: the words curl/wget get (_fw_option_words), not quote-stripped ones:
    # stripping turned `curl -'o' F URL` into `curl - F URL`. No value grammar is
    # tracked here, so a word that begins with an expansion counts as a write.
    _fw_option_words "$cmd" || return 0
    # T-4536: except an expansion of a literal this line assigned.
    local _wi
    for _wi in "${!_FW_OWK[@]}"; do
        [ "${_FW_OWK[_wi]}" = E ] || continue
        _fw_word_is_literal_var "${_FW_OW[_wi]}" || return 0
    done
    set -- "${_FW_OW[@]}"
    [ $# -eq 0 ] && return 1
    base="${1##*/}"
    shift

    while [ $# -gt 0 ]; do
        tok="$1"; shift
        case "$tok" in
            # Long forms, both spellings, for both tools.
            --output=-|--output-document=-)   wget_stdout=1; continue ;;
            --output=*|--output-document=*)   return 0 ;;
            --output|--output-document|--output-file)
                [ "${1:-}" = "-" ] || return 0
                wget_stdout=1
                continue ;;
            --remote-name|--remote-header-name|--output-dir|--create-dirs)
                return 0 ;;
            --spider|--help|--version)
                # No-download modes: nothing is fetched, so nothing lands in cwd.
                wget_nofetch=1; continue ;;
            --*) continue ;;
            -) continue ;;
            -h|-V)
                wget_nofetch=1; continue ;;
            -*)
                # Short-flag cluster. curl allows bundling (`-sO`, `-so FILE`),
                # so test the letters rather than the whole token.
                rest="${tok#-}"
                # curl -O / wget -O: writes to a file with no separate argument
                # for curl (remote name) and with one for wget.
                case "$rest" in
                    *O*)
                        if [ "$base" = wget ]; then
                            # wget -O takes a value: attached (`-O-`, `-Ofile`)
                            # or the next token.
                            case "$rest" in
                                *O)   [ "${1:-}" = "-" ] || return 0
                                      wget_stdout=1 ;;
                                *O-)  wget_stdout=1 ;;
                                *)    return 0 ;;
                            esac
                        else
                            return 0   # curl -O always names a local file
                        fi
                        continue ;;
                esac
                case "$rest" in
                    *o*)
                        # wget -o is the LOG file (always a write). curl -o is
                        # the output file (stdout when the target is `-`).
                        if [ "$base" = wget ]; then return 0; fi
                        # T-3643: /dev/null joins `-` — it discards the body.
                        case "$rest" in
                            *o)   [ "${1:-}" = "-" ] || [ "${1:-}" = "/dev/null" ] || return 0 ;;
                            *o-)  ;;
                            *)    return 0 ;;   # attached value, e.g. -ofile
                        esac
                        continue ;;
                esac
                continue ;;
            *) continue ;;
        esac
    done
    # T-3237: wget with no explicit stdout destination and no no-download mode
    # is running its DEFAULT, and the default writes the remote filename to cwd.
    if [ "$base" = wget ] && [ "$wget_stdout" -eq 0 ] && [ "$wget_nofetch" -eq 0 ]; then
        return 0
    fi
    return 1
}

# T-2889: is this `git branch|tag|stash` clause a READ form?
#
# The three verbs list on their own and write with arguments, so the verb alone
# cannot decide them (the reason `config` and `symbolic-ref` are absent from the
# git allowlist). Words are split plainly, NOT through _fw_strip_quoted: that
# drops quoted words, which would turn `git branch "new"` (a create) into a bare
# listing. Plain splitting can only ADD positional words, and an unexpected
# positional reads as a write — the failure direction is toward the task gate.
#
#   stash   read only as `stash list` / `stash show`; bare stash and every other
#           sub-verb (push, pop, apply, drop, clear, save, create, store, branch)
#           write the working tree or refs/stash.
#   branch  write on any of -d -D -m -M -c -C -f -u -t (alone or in a short-flag
#           cluster) or --delete/--move/--copy/--force/--track/--no-track/
#           --set-upstream-to/--unset-upstream/--edit-description/--create-reflog.
#           A positional word is a branch to create unless a list-mode option
#           (-l/--list or --contains/--no-contains/--merged/--no-merged/
#           --points-at, which imply --list) is present.
#   tag     write on any of -d -a -s -u -f -m -F -e (alone or clustered) or
#           --delete/--annotate/--sign/--local-user/--force/--message/--file/
#           --edit. A positional word is a tag to create unless a list-mode
#           option (-l/--list/-n*/--contains/--no-contains/--merged/--no-merged/
#           --points-at) or -v/--verify is present.
_fw_git_refverb_is_read() {
    local verb="$1" cmd="$2"
    local -a words
    # T-4512: the words git gets, so `$'-D'` or `-'d'` is the flag it spells. A word
    # that begins with an expansion may be any flag: not a read.
    _fw_option_words "$cmd" || return 1
    [[ " ${_FW_OWK[*]} " == *" E "* ]] && return 1
    words=("${_FW_OW[@]}")
    # words[0]=git, words[1]=verb; arguments start at index 2.
    local args=("${words[@]:2}")

    if [ "$verb" = "stash" ]; then
        case "${args[0]:-}" in list|show) return 0 ;; esac
        return 1
    fi

    local w_short w_long listing=0 positional=0 endopts=0 tok
    if [ "$verb" = "branch" ]; then
        w_short='dDmMcCfut'
        w_long='^--(delete|move|copy|force|track(=.*)?|no-track|set-upstream-to(=.*)?|unset-upstream|edit-description|create-reflog)$'
    else
        w_short='dasufmFe'
        w_long='^--(delete|annotate|sign|local-user(=.*)?|force|message(=.*)?|file(=.*)?|edit)$'
    fi
    for tok in "${args[@]}"; do
        if [ "$endopts" -eq 1 ]; then positional=1; continue; fi
        case "$tok" in
            --) endopts=1 ;;
            -l|--list|--contains|--contains=*|--no-contains|--no-contains=*|\
            --merged|--merged=*|--no-merged|--no-merged=*|--points-at|--points-at=*)
                listing=1 ;;
            --*)
                [[ "$tok" =~ $w_long ]] && return 1
                [ "$verb" = "tag" ] && [ "$tok" = "--verify" ] && listing=1
                ;;
            -?*)
                [[ "${tok:1}" == *["$w_short"]* ]] && return 1
                if [ "$verb" = "tag" ]; then
                    [[ "$tok" == -n* || "${tok:1}" == *[lv]* ]] && listing=1
                else
                    [[ "${tok:1}" == *l* ]] && listing=1
                fi
                ;;
            *) positional=1 ;;
        esac
    done
    [ "$positional" -eq 1 ] && [ "$listing" -eq 0 ] && return 1
    return 0
}

# T-3238: does this SINGLE find clause carry an action/mutation predicate?
#
# Clause-scoped on quote-stripped text, for the same reason _fw_fetch_writes_file
# above is: a whole-string scan would turn a MENTION into an action —
# `grep -q '\-delete' file` or `find . -name "-delete"` must not gate. After
# _fw_strip_quoted, quoted arguments are gone, so only a bare predicate token in
# argv position can match. Backslash-escaped chars are dropped by the stripper
# too (`\;` after -exec), which costs nothing: the `-exec` itself is the signal.
#
# Failure direction is toward BLOCKING: an unparseable clause (unbalanced quote)
# reads as carrying an action, which sends the command to the task gate rather
# than past it — the same asymmetry argument as the compound-command judge.
#
# T-4512: quote-stripping hid a QUOTED predicate as well (`find . -'exec' touch {} \;`:
# find gets -exec, the stripper left `-`). The words are now the ones find gets
# (_fw_option_words), and the mention case is kept by the grammar instead: a test
# that takes a value consumes the next word, so `-name "-delete"` is a name. A word
# that begins with an expansion ("$X") in predicate position may be any predicate.
_fw_find_has_action_predicate() {
    local i tok
    _fw_option_words "$1" || return 0
    for (( i=1; i<${#_FW_OW[@]}; i++ )); do
        tok="${_FW_OW[i]}"
        [ "${_FW_OWK[i]}" = E ] && return 0
        case "$tok" in
            -delete|-exec|-execdir|-ok|-okdir|-fprint|-fprintf|-fprint0|-fls)
                return 0 ;;
            -name|-iname|-path|-ipath|-wholename|-iwholename|-regex|-iregex|-lname|-ilname|\
            -type|-xtype|-user|-group|-uid|-gid|-perm|-size|-mtime|-mmin|-atime|-amin|\
            -ctime|-cmin|-newer|-anewer|-cnewer|-newer??|-samefile|-inum|-links|-maxdepth|\
            -mindepth|-fstype|-context|-used|-regextype|-printf|-files0-from|-D)
                i=$((i + 1)) ;;
        esac
    done
    return 1
}

# T-3454: env prefixes are stripped before the match, which is what makes the
# T-3179 partial-complete allowance reachable at all.
#
# The measured deadlock: focus sits on a partial-complete task, the commit
# targets a DIFFERENT (closed) task, so the focus-drift gate refuses and its
# block message prescribes `FW_SWITCH_FOCUS=1 <cmd>` as the universal remedy —
# correctly noting that focusing the target is impossible because it is closed.
# Adding that prefix then broke this regex, so the commit was no longer
# recognised as a commit clause, fell through to _fw_single_command_is_safe,
# and was refused as a write. Drop the prefix and focus-drift refuses again.
# Two gates, two prescribed remedies, no line satisfying both — the same class
# as T-3299, where G-020 blocks both escape routes its own message names.
#
# Reuses _fw_strip_env_prefixes rather than adding a second regex: that
# primitive already carries the denylist of execution-causing names, so
# `PATH=/tmp git commit` still fails this match (the strip stops at the denied
# name, the residue does not look like a commit clause) and is refused. Fails
# closed, and there is one copy of the denylist rather than two.
# T-4203: the project's OWN tracked `bin/fw` shim, resolved. A consumer may track
# a `bin/fw` shim that execs `.agentic-framework/bin/fw` (CLAUDE.md tells the
# consumer's agent to type `bin/fw`), so that path is its own launcher too. Rule:
# PROJECT_ROOT/bin/fw counts only when it is a REGULAR FILE and its realpath lies
# under realpath(PROJECT_ROOT). A symlink escaping the project, a directory, or
# an unset PROJECT_ROOT prints nothing and admits nothing. The shim's content is
# not inspected: it is the tracked file the project itself ships.
_fw_project_shim_real() {
    [ -n "${PROJECT_ROOT:-}" ] || return 1
    local _pr _s
    _pr="$(realpath -e -- "$PROJECT_ROOT" 2>/dev/null)" || return 1
    _s="$(realpath -e -- "$PROJECT_ROOT/bin/fw" 2>/dev/null)" || return 1
    [ -f "$_s" ] || return 1
    case "$_s" in "$_pr"/*) printf '%s' "$_s" ;; *) return 1 ;; esac
}

# T-4108: does this launcher path resolve to THIS project's own fw?
_fw_is_own_launcher() {
    local _l _a _b _c
    _l="$(realpath -m -- "$1" 2>/dev/null)" || return 1
    _a="$(realpath -m -- "${FRAMEWORK_ROOT:-/nonexistent}/bin/fw" 2>/dev/null)"
    _b="$(realpath -m -- "${PROJECT_ROOT:-/nonexistent}/.agentic-framework/bin/fw" 2>/dev/null)"
    _c="$(_fw_project_shim_real)" || _c=""
    [ -n "$_l" ] && { [ "$_l" = "$_a" ] || [ "$_l" = "$_b" ] || { [ -n "$_c" ] && [ "$_l" = "$_c" ]; }; }
}

# T-4108 round 2: can this (already safe-judged) segment change the shell's
# cwd? Only builtins can; an external program cannot. Unclassifiable → yes.
_fw_segment_may_change_dir() {
    local s w
    s="$(_fw_strip_quoted "$1")" || return 0
    s="${s#"${s%%[![:space:]]*}"}"
    _fw_strip_env_prefixes "$s"; s="$_FW_ENV_STRIPPED"
    w="${s%%[[:space:]]*}"
    [ -z "$w" ] && return 1
    [[ "$w" =~ ^[A-Za-z0-9_./+:@%,=-]+$ ]] || return 0
    case "$w" in
        cd|pushd|popd|source|.|eval|builtin|command|exec|trap|alias|enable|shopt|function) return 0 ;;
    esac
    return 1
}

_fw_is_git_commit_clause() {
    local seg _lead _tok
    local -a _toks=()
    seg="$(_fw_strip_quoted "$1")" || return 1
    seg="${seg#"${seg%%[![:space:]]*}"}"
    # T-4204: judge the prefix BEFORE it is stripped. The stripper below removes
    # any NAME=VALUE it does not deny, so `PROJECT_ROOT=/x .agentic-framework/bin/fw
    # git commit` reduced to the bare project launcher and was admitted, while
    # fw ran with the overridden root. cmd_classify.py refuses the same command.
    # Only the four documented commit-time bypass prefixes may lead a commit:
    # they are read by the git hooks and the focus-drift gate, not by fw's root
    # resolution. `time` (a keyword that changes nothing) is still tolerated.
    _fw_strip_env_prefixes "$seg"
    _lead="${seg:0:${#seg}-${#_FW_ENV_STRIPPED}}"
    read -r -a _toks <<< "$_lead"
    for _tok in "${_toks[@]}"; do
        case "$_tok" in
            time|-p) ;;
            FW_SWITCH_FOCUS=1|FW_ALLOW_STALE_INDEX=1|FW_ALLOW_MASTER_COMMIT=1|FW_ALLOW_WORKTREE_CORPUS_COMMIT=1) ;;
            *) return 1 ;;
        esac
    done
    seg="$_FW_ENV_STRIPPED"
    # T-3814 (010 H1): the framework's own documented, secret-scanned spellings
    # are a commit too. The launcher must be exactly `fw`, `[./]bin/fw`,
    # `[./].agentic-framework/bin/fw`, or an absolute path ending in one of the
    # last two — not any binary whose name ends in "fw".
    [[ "$seg" =~ ^fw[[:space:]]+git[[:space:]]+commit([[:space:]]|$) ]] && return 0
    # T-4108 round 2: a RELATIVE launcher runs from the SHELL's cwd, not the
    # hook's — the Bash tool keeps its cwd across calls, so `cd /tmp/x` in one
    # call made `bin/fw git commit` in the next run /tmp/x/bin/fw while the
    # hook resolved the project's own. Resolve it against the payload `cwd`
    # (the shell's cwd at the call); no absolute payload cwd → refuse. Any
    # directory change earlier in the SAME command (cd/pushd/popd/source/…,
    # flagged by is_commit_checkpoint_command) → refuse, even if it would land
    # on the project: segments are judged one by one, so the cwd at this
    # segment is unknowable here. No state is carried between calls.
    if [[ "$seg" =~ ^((\./)?(\.agentic-framework/)?bin/fw)[[:space:]]+git[[:space:]]+commit([[:space:]]|$) ]]; then
        [ "${_FW_CWD_CHANGED:-0}" = 0 ] || return 1
        case "${_FW_PAYLOAD_CWD:-}" in /*) ;; *) return 1 ;; esac
        _fw_is_own_launcher "${_FW_PAYLOAD_CWD}/${BASH_REMATCH[1]}"
        return
    fi
    # T-4108: an ABSOLUTE launcher is admitted only when it resolves to this
    # project's own fw — a planted /tmp/x/bin/fw would otherwise pass the
    # wrap-up gates (critical budget included). Independent of cwd.
    if [[ "$seg" =~ ^(/[^[:space:]]*/bin/fw)[[:space:]]+git[[:space:]]+commit([[:space:]]|$) ]]; then
        _fw_is_own_launcher "${BASH_REMATCH[1]}"
        return
    fi
    [[ "$seg" =~ ^git[[:space:]]+commit([[:space:]]|$) ]] || return 1
    # T-4409: a bare git commit uses the repository of its cwd (hooks and config
    # included), so that cwd must be inside PROJECT_ROOT; unknown refuses.
    _fw_git_dir_is_project "${_FW_GIT_CWD-$(_fw_initial_git_cwd)}" / >/dev/null
}

# Remove quoted spans, tracking WHICH quote opened each one. A regex that
# strips `'[^']*'` and `"[^"]*"` independently pairs an apostrophe inside a
# double-quoted string with the next unrelated quote and desyncs everything
# after it — the same defect T-3217's linter had, and the reason that one is a
# state machine too. An unterminated quote returns non-zero, so the caller
# blocks rather than guessing.
_fw_strip_quoted() {
    local s="$1" out="" q="" ch i n=${#1}
    for (( i=0; i<n; i++ )); do
        ch="${s:i:1}"
        if [ -n "$q" ]; then
            [ "$ch" = "$q" ] && q=""
            continue
        fi
        case "$ch" in
            "'"|'"') q="$ch" ;;
            '\')     i=$((i+1)) ;;
            *)       out+="$ch" ;;
        esac
    done
    [ -n "$q" ] && return 1
    printf '%s' "$out"
}

# ─────────────────────────────────────────────────────────────────────────────
# T-3299: is this command a METADATA-ONLY `fw task update` — the shape the
# G-020 block message itself prescribes as the escape route?
#
# G-020 (check-active-task.sh, build-readiness gate) blocks everything that
# falls through to it while the focused build task has placeholder ACs — and
# its own printed remedy, `fw task update T-XXX --type inception`, fell
# through with everything else: `update` is not a safe-listed task sub-verb,
# and no earlier checkpoint admits it. The gate quoted the remedy back
# verbatim while refusing it (OBS-353, measured 2026-08-29). Sibling of
# L-399/T-1890, one notch worse: there the bypass was rejected downstream;
# here the gate rejects its own prescription before anything downstream runs.
#
# NARROW BY CONSTRUCTION. A clause qualifies only when its argv is exactly
# `fw task update`, ONE task id, and flags drawn from the metadata set the
# gate's remedies need: --type/-t, --horizon, --status/-s, --reason/-r (each
# consuming the next token as its value) and bare --switch-focus (the T-1890
# sentinel update-task.sh consumes silently). Anything else — --add-tag,
# --owner, --skip-*, a second task id, an unrecognised token — disqualifies
# the clause and the command falls through to the gate as before.
#
# NO `=`-ATTACHED FORMS (`--type=inception`). update-task.sh's parser takes
# values as the NEXT argv token only; admitting a form the downstream parser
# rejects with "Unknown option" would be the exact T-1890 parity break this
# fix exists to close, from the other direction.
#
# Values must be UNQUOTED single tokens. _fw_strip_quoted deletes quoted
# content, so a double-quoted value leaves a valueless flag and the clause is
# refused — toward blocking, which every failure direction here is: command
# substitution, an unbalanced quote, a write pattern on the stripped view, an
# unrecognised flag, and a missing value all return 1, sending the command to
# the gate rather than past it.
#
# Same composition as is_commit_checkpoint_command below, for the same reason:
# chained clauses (`cd … && bin/fw task update …`) are admitted only when every
# other clause is independently safe via the SHARED allowlist, so this cannot
# drift from it.
#
# CONSUMED AT EXACTLY ONE CHECKPOINT — the G-020 block branch in
# check-active-task.sh — per that file's SAFE_ALLOWED argument (:269): a
# predicate honoured at one site fails toward blocking if the site is ever
# lost; one honoured at many fails toward permitting when one forgets. The
# drift gate (T-1730) runs BEFORE that branch, so a metadata update naming a
# task other than the focus is still blocked (or Tier-2 logged) upstream.
_fw_is_task_metadata_update_clause() {
    local seg tok
    seg="$(_fw_strip_quoted "$1")" || return 1
    seg="${seg#"${seg%%[![:space:]]*}"}"
    # T-1908/T-1890: tolerate env-var prefixes (FW_SWITCH_FOCUS=1 fw task update …)
    while [[ "$seg" =~ ^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+(.*)$ ]]; do
        seg="${BASH_REMATCH[1]}"
    done
    # shellcheck disable=SC2086  # deliberate word-splitting: tokenising argv
    set -- $seg
    [ $# -ge 4 ] || return 1
    [ "${1##*/}" = "fw" ] || return 1
    [ "$2" = "task" ] && [ "$3" = "update" ] || return 1
    shift 3
    local task_seen=0
    while [ $# -gt 0 ]; do
        tok="$1"; shift
        case "$tok" in
            T-[0-9]*)
                [[ "$tok" =~ ^T-[0-9]+$ ]] || return 1
                [ "$task_seen" -eq 1 ] && return 1
                task_seen=1 ;;
            --type|-t|--horizon|--status|-s|--reason|-r)
                [ $# -ge 1 ] || return 1
                case "$1" in -*|T-[0-9]*) return 1 ;; esac
                shift ;;
            --switch-focus) ;;
            *) return 1 ;;
        esac
    done
    [ "$task_seen" -eq 1 ]
}

# TRUE only for a command whose every clause is either the metadata-only task
# update itself or independently admissible via the shared allowlist.
is_task_metadata_update_command() {
    local cmd="$1" seg found=0
    local -a segs=()

    case "$cmd" in *'$('*|*'`'*) return 1 ;; esac

    local cmd_view
    cmd_view="$(_fw_strip_quoted "$cmd")" || return 1
    has_bash_write_pattern "$cmd_view" && return 1

    # T-4409: same cwd tracking as is_commit_checkpoint_command, for git clauses.
    local _FW_GIT_CWD _op _si=-1
    _FW_GIT_CWD="$(_fw_initial_git_cwd)"
    local -a ops=()
    while IFS= read -r -d '' seg && IFS= read -r -d '' _op; do
        segs+=("$seg"); ops+=("$_op")
    done < <(_fw_chain_split "$cmd" ops)
    for seg in "${segs[@]}"; do
        _si=$((_si+1))
        [[ "$seg" =~ ^[[:space:]]*$ ]] && continue
        if _fw_is_task_metadata_update_clause "$seg"; then
            found=1
            continue
        fi
        _fw_single_command_is_safe "$seg" || return 1
        _fw_advance_cwd "$seg" "${ops[$_si]}"
    done
    [ "$found" -eq 1 ]
}

# TRUE only for a command that IS a commit checkpoint: at least one clause is a
# real `git commit`, and every other clause is independently admissible.
is_commit_checkpoint_command() {
    local cmd="$1" seg found=0
    # T-4108 round 2: set once a segment may have changed directory; read by
    # _fw_is_git_commit_clause (dynamic scope, so it never outlives this call).
    local _FW_CWD_CHANGED=0
    local -a segs=()

    # Command substitution can carry anything and is judged by nothing here.
    case "$cmd" in *'$('*|*'`'*) return 1 ;; esac

    # `--no-verify`/`-n` skips the commit-msg hook that enforces P-002, which is
    # the thing that makes this whole allowance sound. Pre-existing rule at both
    # call sites, kept here so the two branches cannot drift apart on it.
    [[ "$cmd" =~ (^|[[:space:]])(--no-verify|-n)([[:space:]]|$) ]] && return 1

    # Defect 2 (T-3221): the has_bash_write_pattern check in check-active-task.sh
    # falls through with `:` rather than exiting, so a command already correctly
    # identified as a WRITE reached these branches and was handed exit 0 — the
    # gate saw the write and admitted it anyway. Re-asserted here rather than
    # patched at that one call site, so the guarantee travels with the predicate
    # to every caller. This is also what makes the T-3179 block message's claim
    # that "write patterns void the allowance" true; it was not before.
    #
    # T-3245: judged on a QUOTE-STRIPPED view, not the raw line. CLAUDE.md
    # mandates a `Co-Authored-By: ... <noreply@anthropic.com>` trailer on every
    # commit, and that `<...>` sits inside a quoted `-m` argument —
    # has_bash_write_pattern's redirect regex cannot tell it from a real `<`
    # operator, so the ONLY remedy the T-3179 block message names ("drop the
    # redirect and run the commit bare") was unreachable for a commit carrying
    # the trailer the framework itself requires. Scope decision: reuse
    # _fw_strip_quoted (the same primitive _fw_is_git_commit_clause already
    # trusts, a few lines below) HERE ONLY, rather than making
    # has_bash_write_pattern itself quote-aware. That keeps the blast radius to
    # this one predicate's two call sites (T-2054 null-focus, T-3179
    # partial-complete) instead of every caller of has_bash_write_pattern
    # (T-3096's sed/awk/yq write-detection among them) — a general rewrite of
    # that scanner is a separate, larger change this task does not need to make
    # to close the measured deadlock. Fails closed the same way _fw_strip_quoted
    # always has: an unbalanced quote makes it return non-zero, cmd_view falls
    # back to the untouched original, and the stray metacharacter still blocks.
    local cmd_view
    cmd_view="$(_fw_strip_quoted "$cmd")" || cmd_view="$cmd"
    has_bash_write_pattern "$cmd_view" && return 1

    # T-3223: `-d ''` — see the splitter's contract note.
    # T-4409: git in a clause runs in the tracked cwd (read by the git arm and by
    # the bare `git commit` clause), so it is established and advanced here too.
    local _FW_GIT_CWD _op _si=-1
    _FW_GIT_CWD="$(_fw_initial_git_cwd)"
    local -a ops=()
    while IFS= read -r -d '' seg && IFS= read -r -d '' _op; do
        segs+=("$seg"); ops+=("$_op")
    done < <(_fw_chain_split "$cmd" ops)
    for seg in "${segs[@]}"; do
        _si=$((_si+1))
        [[ "$seg" =~ ^[[:space:]]*$ ]] && continue
        if _fw_is_git_commit_clause "$seg"; then
            found=1
            continue
        fi
        _fw_single_command_is_safe "$seg" || return 1
        _fw_segment_may_change_dir "$seg" && _FW_CWD_CHANGED=1
        _fw_advance_cwd "$seg" "${ops[$_si]}"
    done
    [ "$found" -eq 1 ]
}
