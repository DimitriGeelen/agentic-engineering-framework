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
_fw_chain_split() {
    local cmd="$1" seg="" q="" ch nxt i n=${#1}
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
                [ "$nxt" = "$ch" ] && i=$((i+1))
                printf '%s\0' "$seg"; seg="" ;;
            ';'|$'\n') printf '%s\0' "$seg"; seg="" ;;
            *)       seg+="$ch" ;;
        esac
    done
    printf '%s\0' "$seg"
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
is_bash_safe_command() {
    local _cmd="$1" _seg _n=0
    local -a _segs=() _kept=()
    # T-3223: `-d ''`. mapfile -t here read the splitter's NUL stream as lines,
    # so a segment containing a newline arrived as several bogus segments.
    while IFS= read -r -d '' _seg; do
        _segs+=("$_seg")
    done < <(_fw_chain_split "$_cmd")
    for _seg in "${_segs[@]}"; do
        [[ "$_seg" =~ ^[[:space:]]*$ ]] && continue
        _kept+=("$_seg"); _n=$((_n+1))
    done
    if [ "$_n" -gt 1 ]; then
        for _seg in "${_kept[@]}"; do
            _fw_single_command_is_safe "$_seg" || return 1
        done
        return 0
    fi
    _fw_single_command_is_safe "$_cmd"
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
    while [[ "$cmd" =~ ^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+(.*)$ ]]; do
        cmd="${BASH_REMATCH[1]}"
    done

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
        while [[ "$cmd" =~ ^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+(.*)$ ]]; do
            cmd="${BASH_REMATCH[1]}"
        done
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
            local git_sub
            git_sub=$(echo "$cmd" | awk '{print $2}')
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
                status|log|diff|show|branch|remote|describe|rev-parse|tag|stash|shortlog|blame|ls-files|ls-tree|cat-file|name-rev|reflog)
                    return 0
                    ;;
                rev-list|ls-remote|merge-base|grep|for-each-ref|count-objects|check-ignore|verify-commit|var|whatchanged|cherry|diff-tree|show-ref|help)
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
        grep|rg|find|which|where|type|command)
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
        # quotes. Verified in the task's Decisions rather than assumed.
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
            return 0
            ;;

        # Category 3b (T-3096): read-only process / system inspection.
        # Verb-scoped where the tool has both forms; omitted entirely where it does not
        # (`kill`, `ip`, `mount` and friends are NOT here — `ip addr` reads but `ip link
        # set` writes, and a verb-level split there is wider than this task measured).
        pgrep|pidof|getent|journalctl|dmesg|tty|logname|groups|locale|ulimit)
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
                    case "$tl_sub2" in
                        list|info|members|search|thread|threads|unread|state|pinned|\
                        digest|snippet|receipts|describe|claims)
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
                    case "$fw_sub3" in port|url|status) return 0 ;; esac
                    ;;
                config)
                    case "$fw_sub3" in get|list|overrides) return 0 ;; esac
                    ;;
                git)
                    case "$fw_sub3" in status|log|worker-commits) return 0 ;; esac
                    ;;
                arc)
                    case "$fw_sub3" in list|ls|show|review|show-suggestions|help) return 0 ;; esac
                    ;;
                bvp)
                    # bare `fw bvp` is the ranking; `fw bvp T-123` is per-task detail.
                    case "$fw_sub3" in ""|arcs|--quadrant|--include-proposed|--include-completed|--help|-h|T-*) return 0 ;; esac
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
                        list|verify|review|create)
                            return 0
                            ;;
                    esac
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
        # `wget -O -` write to stdout and stay safe.
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
            if echo "$cmd" | grep -qE '^\s*(python3?)\s+-c\s'; then
                # Check for write indicators in the inline script
                if echo "$cmd" | grep -qE "(open\(.*, *['\"]w|\.write\(|shutil\.|os\.(rename|remove|unlink|makedirs|system))"; then
                    return 1
                fi
                return 0
            fi
            ;;
        bash|sh)
            # bash -n (syntax check only) is safe
            if echo "$cmd" | grep -qE '^\s*(ba)?sh\s+-n\b'; then
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

    # Redirect operators (but not comparison operators like 2>&1)
    if echo "$cmd" | grep -qE '[^2>&]>[^>&]|>>'; then
        return 0
    fi

    # In-place sed
    if echo "$cmd" | grep -qE '\bsed\b.*-i'; then
        return 0
    fi

    # Destructive file operations (already caught by Tier 0 but belt-and-suspenders)
    if echo "$cmd" | grep -qE '\b(rm|rmdir)\b'; then
        return 0
    fi

    # Heredoc
    if echo "$cmd" | grep -qE '<<\s*['"'"'"]?EOF'; then
        return 0
    fi

    # tee (writes to file)
    if echo "$cmd" | grep -qE '\btee\b'; then
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
    stripped="$(_fw_strip_quoted "$cmd")" || return 0

    # shellcheck disable=SC2086  # deliberate word-splitting: tokenising argv
    set -- $stripped
    [ $# -eq 0 ] && return 1
    base="${1##*/}"
    shift

    while [ $# -gt 0 ]; do
        tok="$1"; shift
        case "$tok" in
            # Long forms, both spellings, for both tools.
            --output=-|--output-document=-)   continue ;;
            --output=*|--output-document=*)   return 0 ;;
            --output|--output-document|--output-file)
                [ "${1:-}" = "-" ] || return 0
                continue ;;
            --remote-name|--remote-header-name|--output-dir|--create-dirs)
                return 0 ;;
            --*) continue ;;
            -) continue ;;
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
                                *O)   [ "${1:-}" = "-" ] || return 0 ;;
                                *O-)  ;;
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
                        case "$rest" in
                            *o)   [ "${1:-}" = "-" ] || return 0 ;;
                            *o-)  ;;
                            *)    return 0 ;;   # attached value, e.g. -ofile
                        esac
                        continue ;;
                esac
                continue ;;
            *) continue ;;
        esac
    done
    return 1
}

_fw_is_git_commit_clause() {
    local seg
    seg="$(_fw_strip_quoted "$1")" || return 1
    seg="${seg#"${seg%%[![:space:]]*}"}"
    [[ "$seg" =~ ^git[[:space:]]+commit([[:space:]]|$) ]]
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

# TRUE only for a command that IS a commit checkpoint: at least one clause is a
# real `git commit`, and every other clause is independently admissible.
is_commit_checkpoint_command() {
    local cmd="$1" seg found=0
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
    has_bash_write_pattern "$cmd" && return 1

    # T-3223: `-d ''` — see the splitter's contract note.
    while IFS= read -r -d '' seg; do
        segs+=("$seg")
    done < <(_fw_chain_split "$cmd")
    for seg in "${segs[@]}"; do
        [[ "$seg" =~ ^[[:space:]]*$ ]] && continue
        if _fw_is_git_commit_clause "$seg"; then
            found=1
            continue
        fi
        _fw_single_command_is_safe "$seg" || return 1
    done
    [ "$found" -eq 1 ]
}
