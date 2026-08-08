#!/usr/bin/env bats
# T-2881 — the onboarding gate must distinguish an arc tag from set membership.
#
# `has_onboarding_tag` used `re.search(r"\bonboarding\b", tags)`. Both `:` and
# `-` are non-word characters, so \b sits happily on either side of the
# substring in `arc:onboarding-curriculum` — and every task tagged into the
# onboarding-curriculum ARC was read as a member of the gated onboarding SET.
#
# Those are two different things that share a word:
#
#     tags: [onboarding]                  the T-532 GATED SET — blocks other work
#     tags: [arc:onboarding-curriculum]   an ARC — a grouping, gates nothing
#
# Found when arc-017's Half A build task (T-2877, the human curriculum) was
# refused by arc-017's Half B invariant for carrying an unticked `### Human` AC.
# The refusal logic was right; its membership test was not. It was also a dead
# end in place: the documented override is an env-var prefix and the refusal
# fires on the Write/Edit tool, which gives an agent nowhere to set it.
#
# The fix parses the list instead of pattern-matching its text. The suite's job
# is to hold BOTH directions — stop the false positive AND keep the true
# positive — because "stop refusing things" would satisfy the first alone.

load ../test_helper

GATE="$FRAMEWORK_ROOT/agents/context/check-onboarding-gate.py"

# _mk <tags> <owner> <human_ac yes|no> — write a fixture, echo its path
_mk() {
    local f="$BATS_TEST_TMPDIR/T-0${RANDOM}-fixture.md"
    {
        printf -- '---\nid: T-099\nstatus: started-work\nworkflow_type: build\n'
        printf 'owner: %s\ntags: %s\n---\n\n## Acceptance Criteria\n\n### Agent\n- [x] done\n' "$2" "$1"
        [ "$3" = "yes" ] && printf '\n### Human\n- [ ] someone must eyeball this\n'
    } > "$f"
    echo "$f"
}

# _gate [gate_path] <fixture> — echo exit code
_gate() {
    local g="$GATE"
    if [ "$#" -eq 2 ]; then g="$1"; shift; fi
    local rc=0
    python3 -c "
import json,sys
print(json.dumps({'tool_name':'Write','tool_input':{'file_path':'/probe/.tasks/active/T-099-x.md','content':open(sys.argv[1]).read()}}))" "$1" \
    | CLAUDECODE=1 python3 "$g" >/dev/null 2>&1 || rc=$?
    echo "$rc"
}

@test "T-2881: SMOKE — the gate refuses the case it exists for" {
    # If this is not 2, every other leg is measuring an inert gate (L-555).
    [ "$(_gate "$(_mk '[onboarding]' agent yes)")" -eq 2 ]
}

@test "T-2881: THE FIX — an arc tag is not set membership" {
    # The exact shape that blocked T-2877.
    [ "$(_gate "$(_mk '[arc:onboarding-curriculum]' agent yes)")" -eq 0 ]
}

@test "T-2881: neighbouring substrings are not set membership either" {
    [ "$(_gate "$(_mk '[onboarding-notes]' agent yes)")" -eq 0 ]
    [ "$(_gate "$(_mk '[pre-onboarding]' agent yes)")" -eq 0 ]
    [ "$(_gate "$(_mk '[arc:foo, onboarding-curriculum]' agent yes)")" -eq 0 ]
}

@test "T-2881: real membership still refuses, in every list position" {
    # The fix must not be 'stop refusing things'. Element-wise means the tag
    # matches wherever it sits in the list.
    [ "$(_gate "$(_mk '[onboarding]' agent yes)")" -eq 2 ]
    [ "$(_gate "$(_mk '[onboarding, ui]' agent yes)")" -eq 2 ]
    [ "$(_gate "$(_mk '[ui, onboarding]' agent yes)")" -eq 2 ]
    [ "$(_gate "$(_mk '[ui, onboarding, arc:onboarding-curriculum]' agent yes)")" -eq 2 ]
}

@test "T-2881: the owner:human escape valve is unchanged" {
    [ "$(_gate "$(_mk '[onboarding]' human yes)")" -eq 0 ]
}

@test "T-2881: a resolvable onboarding task is still allowed" {
    # No unticked Human AC — nothing for the gate to object to.
    [ "$(_gate "$(_mk '[onboarding]' agent no)")" -eq 0 ]
}

@test "T-2881: T-2877 itself passes the gate" {
    # The concrete task that motivated this. Guards against the fix being correct
    # in the abstract and wrong on the case that produced it.
    local t="$FRAMEWORK_ROOT/.tasks/active/T-2877-arc-017-half-a-human-onboarding-curricul.md"
    if [ ! -f "$t" ]; then
        t="$FRAMEWORK_ROOT/.tasks/completed/T-2877-arc-017-half-a-human-onboarding-curricul.md"
    fi
    [ -f "$t" ]
    grep -q 'arc:onboarding-curriculum' "$t"    # still carries the arc tag
    [ "$(_gate "$t")" -eq 0 ]
}

@test "T-2881: TEETH — restoring the \\b regex re-opens the false positive" {
    # DURABLE MUTATION of live source (T-2874). The mutant lives beside the real
    # gate so its sys.path bootstrap (_FRAMEWORK_ROOT from __file__) resolves —
    # from a tmpdir it dies at import and the 'defect reproduced' leg would pass
    # for a reason unrelated to the defect (832 rail 477).
    local mutant="$FRAMEWORK_ROOT/agents/context/.t2881-mutant.py"
    python3 - "$GATE" "$mutant" <<'PY'
import sys
src = open(sys.argv[1]).read()
old = 'return "onboarding" in _parse_tags(_field(fm, _TAGS_RE))'
assert old in src, "anchor line not found — mutation would be a no-op"
open(sys.argv[2], 'w').write(
    src.replace(old, 'return bool(re.search(r"\\bonboarding\\b", _field(fm, _TAGS_RE)))'))
PY
    local delta; delta=$(diff "$GATE" "$mutant" || true)   # diff exits 1 on differs (L-387)
    [ -n "$delta" ]
    python3 -c "import ast,sys; ast.parse(open('$mutant').read())"   # parses ≠ runs

    local fx; fx=$(_mk '[arc:onboarding-curriculum]' agent yes)
    # Positive control: the mutant must reach the gate at all, or the next
    # assertion is vacuous. It must still refuse the genuine case.
    [ "$(_gate "$mutant" "$(_mk '[onboarding]' agent yes)")" -eq 2 ]
    # THE DEFECT: with \b restored, the arc tag false-positives again.
    [ "$(_gate "$mutant" "$fx")" -eq 2 ]
    # ...and the fixed source allows it — pins the mutation as the cause.
    [ "$(_gate "$GATE" "$fx")" -eq 0 ]
    rm -f "$mutant"
}

# --- Scan side (check-active-task.sh T-532 block) ---------------------------
# Same conflation, second call site, looser pattern (`^tags:.*onboarding`). Both
# are fixed together: a task refused by the write-time gate but admitted by the
# scan (or vice versa) is worse than either behaviour alone (L-399).

HOOK="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"

# _scan_fixture <extra_task_tags> <extra_task_owner> — build a project whose
# FOCUSED task is ordinary, plus one extra task carrying the given tags.
_scan_fixture() {
    SFIX="$BATS_TEST_TMPDIR/scanproj"
    rm -rf "$SFIX"; mkdir -p "$SFIX/.tasks/active" "$SFIX/.context/working"
    printf 'version: 1\n' > "$SFIX/.framework.yaml"
    printf 'current_task: T-9001\nfocus_session: S-P\n' > "$SFIX/.context/working/focus.yaml"
    printf 'session_id: S-P\n' > "$SFIX/.context/working/session.yaml"
    printf -- '---\nid: T-9001\nstatus: started-work\nowner: agent\ntags: []\n---\n' \
        > "$SFIX/.tasks/active/T-9001-work.md"
    printf -- '---\nid: T-9500\nstatus: started-work\nowner: %s\ntags: %s\n---\n' "$2" "$1" \
        > "$SFIX/.tasks/active/T-9500-extra.md"
}

# _scan — echo the hook's exit code. Clears the fast-path marker FIRST: the hook
# WRITES `.onboarding-complete` when it finds nothing to block on, so a probe
# that ran earlier in the same fixture silently short-circuits every probe after
# it. That contamination made a positive control pass as rc=0 during
# development, which looked exactly like the fix working.
_scan() {
    rm -f "$SFIX/.context/working/.onboarding-complete"
    local rc=0
    python3 -c "
import json,sys
print(json.dumps({'tool_name':'Bash','cwd':sys.argv[1],'tool_input':{'command':'echo x > f'}}))" "$SFIX" \
    | CLAUDECODE=1 bash "$HOOK" >/dev/null 2>&1 || rc=$?
    echo "$rc"
}

@test "T-2881: SCAN — an arc tag does not put a task in the gated set" {
    _scan_fixture '[arc:onboarding-curriculum]' agent
    [ "$(_scan)" -eq 0 ]
}

@test "T-2881: SCAN POSITIVE CONTROL — a real onboarding tag still blocks" {
    # Without this the leg above is indistinguishable from a scan that never runs.
    _scan_fixture '[onboarding]' agent
    [ "$(_scan)" -eq 2 ]
}

@test "T-2881: SCAN — owner:human onboarding tasks stay exempt (T-2815)" {
    _scan_fixture '[onboarding]' human
    [ "$(_scan)" -eq 0 ]
}

@test "T-2881: SCAN — the fast-path marker is what masked this on the framework repo" {
    # Documents why the defect was latent here rather than observed: the marker
    # short-circuits the whole block before any tag is examined.
    _scan_fixture '[onboarding]' agent
    [ "$(_scan)" -eq 2 ]
    touch "$SFIX/.context/working/.onboarding-complete"
    local rc=0
    python3 -c "
import json,sys
print(json.dumps({'tool_name':'Bash','cwd':sys.argv[1],'tool_input':{'command':'echo x > f'}}))" "$SFIX" \
    | CLAUDECODE=1 bash "$HOOK" >/dev/null 2>&1 || rc=$?
    [ "$rc" -eq 0 ]
}

teardown() {
    rm -f "$FRAMEWORK_ROOT/agents/context/.t2881-mutant.py"
}
