#!/usr/bin/env bats
# T-3096 / G-084 — the Bash task gate must not report a read as a modification.
#
# The gate asks two questions in order: does the command match a write pattern
# (has_bash_write_pattern), and is its base command on the read-only allowlist
# (is_bash_safe_command). When the first answers NO and the second answers NO, the
# command is refused with a message written for the FIRST question — "Cannot modify
# files under a completed task", "before editing source files". Measured live in one
# session: `sed -n RANGE file`, `timeout 30 termlink agent inbox | head` and
# `./x.sh status | tail` were each told they had attempted a modification.
#
# Three things are pinned here, and the third is the one that matters most:
#
#   1. the wrapper stripper — `timeout`/`nohup`/`nice`/`stdbuf`/`env`/`flock` are
#      prefixes, not commands, and the command they wrap is what gets judged;
#   2. the widened read-only set — stdout-only filters and verb-scoped termlink;
#   3. THE DIRECTION OF EVERY FAILURE. A test file for a security predicate that
#      only pins what should now pass is worse than none: it makes a widened hole
#      look tested. Every relaxation below has a matching negative that must stay
#      red, and the wrapper cases are written so that an unparsed option, a missing
#      duration or an empty remainder gates rather than passes.

load ../test_helper

setup() {
    # See safe_commands_chain.bats: the shared teardown rm -rf's TEST_TEMP_DIR and an
    # unset var makes teardown itself the failure, reddening the file for the wrong reason.
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    source "$FRAMEWORK_ROOT/agents/context/lib/safe-commands.sh"
}

# --- 1. transparent wrappers: the wrapped command is what is judged -------------

@test "wrapper: timeout N <safe> is safe (the live block that opened T-3096)" {
    run is_bash_safe_command "timeout 30 termlink agent inbox"
    [ "$status" -eq 0 ]
}

@test "wrapper: timeout N <unsafe> stays gated — the wrapper grants nothing" {
    run is_bash_safe_command "timeout 30 termlink inject sess --enter x"
    [ "$status" -ne 0 ]
}

@test "wrapper: nohup / nice / stdbuf strip to the inner command" {
    run is_bash_safe_command "nohup ls"
    [ "$status" -eq 0 ]
    run is_bash_safe_command "nice -n 5 ls"
    [ "$status" -eq 0 ]
    run is_bash_safe_command "stdbuf -o0 ls"
    [ "$status" -eq 0 ]
}

@test "wrapper: nice -n 5 <unsafe> stays gated (value-option consumed, not the command)" {
    run is_bash_safe_command "nice -n 5 ./deploy.sh"
    [ "$status" -ne 0 ]
}

@test "wrapper: env <script> is gated — closes a pre-existing hole, does not open one" {
    # `env` sat in Category 5 as unconditionally safe, so the base extracted as `env`
    # and `env ./anything.sh` classified SAFE on the strength of the word `env`.
    run is_bash_safe_command "env ./evil.sh"
    [ "$status" -ne 0 ]
}

@test "wrapper: bare env still safe (it prints the environment, runs nothing)" {
    run is_bash_safe_command "env"
    [ "$status" -eq 0 ]
}

@test "wrapper: env K=V <safe> strips both the wrapper and the assignment" {
    run is_bash_safe_command "env FOO=1 ls"
    [ "$status" -eq 0 ]
}

@test "wrapper: command -v is NOT stripped — it queries, it does not run" {
    # Stripping would hand the judge `git` with no sub-verb, which gates.
    run is_bash_safe_command "command -v git"
    [ "$status" -eq 0 ]
}

@test "wrapper: an unparsable wrapper argument gates rather than guessing" {
    # No duration where timeout's grammar requires one: the stripper must leave the
    # base as `timeout`, which matches no arm. Failing toward BLOCKING is the contract.
    run is_bash_safe_command "timeout --foo ls"
    [ "$status" -ne 0 ]
}

@test "wrapper: a bare wrapper with nothing wrapped does not crash or pass through" {
    run is_bash_safe_command "timeout"
    [ "$status" -ne 0 ]
    run is_bash_safe_command "nohup"
    [ "$status" -ne 0 ]
}

# --- 2. stdout-only filters ------------------------------------------------------

@test "filters: sed without -i is safe (the second live block)" {
    run is_bash_safe_command "sed -n '152,262p' agents/context/check-active-task.sh"
    [ "$status" -eq 0 ]
}

@test "filters: sed -i is a WRITE — caught one layer up, never reaches the allowlist" {
    # The safety argument for putting sed on the list is that has_bash_write_pattern
    # runs first and owns the in-place form. Pin the interaction, do not assume it.
    run has_bash_write_pattern "sed -i 's/a/b/' f"
    [ "$status" -eq 0 ]
    run has_bash_write_pattern "sed --in-place s/a/b/ f"
    [ "$status" -eq 0 ]
}

@test "filters: awk's in-program redirect is caught by the outer write scan" {
    # `awk '{print > "f"}'` writes. The `>` is inside single quotes, but
    # has_bash_write_pattern greps the raw command string, so it sees it anyway.
    run has_bash_write_pattern "awk '{print > \"f\"}' x"
    [ "$status" -eq 0 ]
}

@test "filters: the common read-only filters classify safe" {
    for c in "awk '{print \$1}' f" "sort f" "uniq f" "cut -d: -f1 f" "tr a b" \
             "jq . f" "diff a b" "md5sum f" "column -t f" "nl f" "base64 f"; do
        run is_bash_safe_command "$c"
        [ "$status" -eq 0 ] || { echo "expected SAFE but gated: $c"; return 1; }
    done
}

@test "filters: yq is deliberately EXCLUDED — its -i writes and nothing catches it" {
    # The mirror of the sed case, and the reason the list is not "anything that filters".
    run has_bash_write_pattern "yq -i . f"
    [ "$status" -ne 0 ]
    run is_bash_safe_command "yq -i . f"
    [ "$status" -ne 0 ]
}

@test "filters: executing a file is still gated (Tier 0 scope boundary, T-2742)" {
    # A command string cannot see what a script does, so running one is never
    # provably read-only. This is a verdict, not an omission.
    for c in "./agents/context/checkpoint.sh status" "bats tests/unit/x.bats" \
             "make -n" "python3 mutate.py" "bash deploy.sh"; do
        run is_bash_safe_command "$c"
        [ "$status" -ne 0 ] || { echo "expected GATED but passed: $c"; return 1; }
    done
}

# --- 3. termlink is verb-scoped, like git and fw ---------------------------------

@test "termlink: read verbs are safe" {
    for c in "termlink list" "termlink status" "termlink agent inbox" \
             "termlink channel list" "termlink remote list" "termlink kv get k"; do
        run is_bash_safe_command "$c"
        [ "$status" -eq 0 ] || { echo "expected SAFE but gated: $c"; return 1; }
    done
}

@test "termlink: mutating verbs stay gated" {
    for c in "termlink inject s --enter x" "termlink spawn w" "termlink dispatch w" \
             "termlink signal s SIGTERM" "termlink clean" "termlink agent post x" \
             "termlink kv set k v" "termlink hub restart" "termlink remote inject s x"; do
        run is_bash_safe_command "$c"
        [ "$status" -ne 0 ] || { echo "expected GATED but passed: $c"; return 1; }
    done
}

@test "termlink: an unknown sub-verb gates (the list is an allowlist, not a denylist)" {
    run is_bash_safe_command "termlink some-future-verb"
    [ "$status" -ne 0 ]
}

# --- 4. the whole point: the three live commands ---------------------------------

@test "live: the two read-only commands that were blocked now classify safe" {
    run is_bash_safe_command "cat .context/working/.budget-status 2>/dev/null; echo x; timeout 30 termlink agent inbox 2>&1 | head -30"
    [ "$status" -eq 0 ]
    run is_bash_safe_command "sed -n '152,262p' agents/context/check-active-task.sh"
    [ "$status" -eq 0 ]
}

@test "live: the third stays gated, and that is the verdict not the bug" {
    # `./agents/context/checkpoint.sh status | tail -5` reads only, but the gate cannot
    # know that. What T-3096 changes for this command is the MESSAGE, not the verdict.
    run is_bash_safe_command "./agents/context/checkpoint.sh status 2>&1 | tail -5"
    [ "$status" -ne 0 ]
}

# --- 5. the block message names the real reason ----------------------------------
#
# The predicate above decides WHETHER to gate. These pin what the agent is TOLD when it
# does — which is the half of G-084 that costs the gate its credibility. Extracted from
# the hook rather than duplicated, so a message rewritten in check-active-task.sh cannot
# leave these passing against a stale copy.

_load_msg_fns() {
    eval "$(sed -n '/^_bash_gate_reason() {/,/^}/p' "$FRAMEWORK_ROOT/agents/context/check-active-task.sh")"
    eval "$(sed -n '/^_blocked_subject() {/,/^}/p' "$FRAMEWORK_ROOT/agents/context/check-active-task.sh")"
}

@test "message: a genuine write is reported as a write" {
    _load_msg_fns
    BASH_CMD="echo hi > /etc/passwd"
    run _blocked_subject
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "matches a file-write pattern"
}

@test "message: a read-only command is NOT reported as a modification" {
    _load_msg_fns
    BASH_CMD="./agents/context/checkpoint.sh status 2>&1 | tail -5"
    run _blocked_subject
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "writes nothing the gate can detect"
    # the accusation must be absent, not merely accompanied by a correction
    if echo "$output" | grep -qi "matches a file-write pattern"; then
        echo "LEAK: read-only command reported as a write:"; echo "$output"; return 1
    fi
}

@test "message: the unrecognised SEGMENT of a chain is named" {
    _load_msg_fns
    BASH_CMD="cat f; ./deploy.sh; ls"
    run _blocked_subject
    [ "$status" -eq 0 ]
    # Inspect only the line that names the offender — line 1 legitimately echoes the
    # whole command back, so grepping the full output cannot tell the two apart.
    local named
    named=$(echo "$output" | grep 'is not on the read-only allowlist')
    echo "$named" | grep -q '"./deploy.sh"'
    # naming the whole command line instead of the segment would be the easy wrong fix
    if echo "$named" | grep -q 'cat f'; then
        echo "LEAK: named the whole line, not the offending segment:"; echo "$named"; return 1
    fi
}

# --- 6. fw's read-only surface -----------------------------------------------------
#
# The allowlist carried ten fw sub-verbs. Classifying every arm of bin/fw's dispatch
# case found 120 READ pairs of 299, of which 92 were unreachable — including
# `fw watchtower url`, which CLAUDE.md prescribes as THE way to avoid hard-coding
# port 3000. Evidence per verdict: docs/reports/T-3096-fw-verb-classification.md.

@test "fw: the prescribed port-resolution idiom is safe" {
    # CLAUDE.md §Watchtower Port. This gating is why the rule was hard to follow.
    run is_bash_safe_command "bin/fw watchtower url"
    [ "$status" -eq 0 ]
    # The idiom CLAUDE.md actually prescribes, verbatim: no -o.
    run is_bash_safe_command "curl -sf \"\$(bin/fw watchtower url)/page\""
    [ "$status" -eq 0 ]
}

@test "fw: the port-resolution idiom with -o FILE is GATED (T-3222)" {
    # This leg previously asserted the OPPOSITE, as part of the test above:
    #
    #     is_bash_safe_command "curl -sf \"\$(bin/fw watchtower url)/config\" -o /tmp/x"
    #     [ "$status" -eq 0 ]
    #
    # The `-o /tmp/x` was an embellishment — CLAUDE.md's prescribed idiom has no
    # `-o` — and it encoded the T-3222 admission hole as a guarantee: curl and
    # wget sat unconditionally on the safe-list, so a curl WRITING A FILE was
    # admitted with no active task. A test asserting a bug is worse than no
    # test, because the next person to touch the area reads it as a decision.
    #
    # Corrected rather than deleted, and inverted rather than quietly dropped:
    # the assertion now pins the fixed behaviour, and the old text is above so
    # the change is legible to anyone who remembers the original.
    #
    # This does not make the idiom unusable — the safe-list only decides what
    # runs with NO ACTIVE TASK. Under a task, a curl that writes a temp file is
    # ordinary work and passes the gate normally.
    run is_bash_safe_command "curl -sf \"\$(bin/fw watchtower url)/config\" -o /tmp/x"
    [ "$status" -ne 0 ]
    run is_bash_safe_command "curl -sf \"\$(bin/fw watchtower url)/config\" -o -"
    [ "$status" -eq 0 ]
}

@test "fw: read verbs the Quick Reference tells agents to use reflexively are safe" {
    for c in "bin/fw review-queue" "bin/fw learnings" "bin/fw decisions" "bin/fw recall q" \
             "bin/fw ask q" "bin/fw timeline" "bin/fw costs" "bin/fw bus manifest T-1" \
             "bin/fw config get PORT" "bin/fw arc list" "bin/fw cron status" \
             "bin/fw orchestrator status" "bin/fw pause list" "bin/fw write-set check T-1 T-2" \
             "bin/fw outcome evaluate T-1" "bin/fw bvp"; do
        run is_bash_safe_command "$c"
        [ "$status" -eq 0 ] || { echo "expected SAFE but gated: $c"; return 1; }
    done
}

@test "fw: the mutating twin of every added read stays gated" {
    for c in "bin/fw watchtower start" "bin/fw config set X 1" "bin/fw bus post --task T-1" \
             "bin/fw outcome backprop T-1" "bin/fw arc close x" "bin/fw cron install" \
             "bin/fw reviewer override add T-1" "bin/fw task update T-1 --status work-completed"; do
        run is_bash_safe_command "$c"
        [ "$status" -ne 0 ] || { echo "expected GATED but passed: $c"; return 1; }
    done
}

@test "fw: 'reviewer T-XXX' is gated — it WRITES a verdict block into the task file" {
    # Only `reviewer override list` is a read. The bare scan form mutates.
    run is_bash_safe_command "bin/fw reviewer T-3096"
    [ "$status" -ne 0 ]
    run is_bash_safe_command "bin/fw reviewer override list"
    [ "$status" -eq 0 ]
}

@test "fw: 'orchestrator improve' stays gated although it currently only prints" {
    # Classified READ because it is a v2 stub. A stub is a temporary property, not a
    # contract; the verb's name declares intent to act. Excluded on purpose, and this
    # test is what stops a future author from "fixing" the omission.
    run is_bash_safe_command "bin/fw orchestrator improve"
    [ "$status" -ne 0 ]
}

@test "fw: nothing previously allowed was narrowed" {
    # The derivation proposed scoping `integrate` to check|classify and `resume` to
    # quick. Both are whole-command allows today for stated deadlock reasons (T-2471:
    # integrate runs from a worktree whose PROJECT_ROOT resolves to the main repo, so
    # focus is null). Narrowing them would re-open a deadlock closed four times over.
    for c in "bin/fw integrate run master --push" "bin/fw resume status" "bin/fw resume sync" \
             "bin/fw fabric drift" "bin/fw task create --name x" "bin/fw handover"; do
        run is_bash_safe_command "$c"
        [ "$status" -eq 0 ] || { echo "REGRESSION — previously allowed, now gated: $c"; return 1; }
    done
}
