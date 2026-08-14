#!/usr/bin/env bats
# T-2991: P-011 must never eval a line bash cannot parse.
#
# The gate is line-oriented (update-task.sh:1149,1169). A `python3 -c "` command
# written across several lines is therefore not one command: line 1 is an
# unterminated quote and the PYTHON BODY below it gets eval'd as bash. That put
# 56MB of ImageMagick PostScript into this repo's root across four incidents over
# three months, because `import yaml,sys` is a valid bash line and `import` is a
# screenshot tool whose last argument is its output filename (T-2990).
#
# The load-bearing test is `the import line is never reached`. It plants a fake
# `import` on PATH that TOUCHES A FILE when run — so if the preflight ever stops
# working, the test fails on evidence rather than on an assertion about wording.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    LIB="$FRAMEWORK_ROOT/lib/verification-port.sh"
    [ -f "$LIB" ] || skip "lib/verification-port.sh not found"
    source "$LIB"
    SB="$(mktemp -d)"
    mkdir -p "$SB/bin"

    # Stands in for /usr/bin/import. Records that it was reached AND writes the
    # file the real one would, so both the trace and the side effect are visible.
    cat > "$SB/bin/import" <<'SHIM'
#!/usr/bin/env bash
out=""
for a in "$@"; do case "$a" in -*) ;; *) out="$a" ;; esac; done
echo "REACHED $*" >> "$IMPORT_TRACE"
[ -n "$out" ] && printf '%%!PS-Adobe-3.0\n' > "$out"
exit 1
SHIM
    chmod +x "$SB/bin/import"
    export IMPORT_TRACE="$SB/trace"
    : > "$IMPORT_TRACE"

    # The exact shape from T-2990.
    BAD_BLOCK='python3 -c "
import yaml,sys
d = yaml.safe_load(open('"'"'policy/value-drivers.yaml'"'"'))
sys.exit(0 if d else 1)
"'
    GOOD_BLOCK='python3 -c "import sys; sys.exit(0)"
test -f README.md
out=$(bin/fw doctor 2>&1); echo "$out" | grep -q OK'
}

teardown() {
    rm -rf "$SB" 2>/dev/null
    unset FW_ALLOW_UNPARSEABLE_VERIFICATION
}

# --- the predicate ---

@test "T-2991: a well-formed block is parseable" {
    run find_unparseable_verification_lines "$GOOD_BLOCK"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "T-2991: the T-2990 block is reported unparseable" {
    run find_unparseable_verification_lines "$BAD_BLOCK"
    [ -n "$output" ]
    echo "$output" | grep -q 'python3 -c "'
}

@test "T-2991: check_verification_parseable passes a clean block" {
    run check_verification_parseable "$GOOD_BLOCK"
    [ "$status" -eq 0 ]
}

@test "T-2991: check_verification_parseable refuses the T-2990 block" {
    run check_verification_parseable "$BAD_BLOCK"
    [ "$status" -eq 1 ]
}

# --- the point of the whole task ---

@test "T-2991: the import line is never reached" {
    # Simulate the gate: preflight, and only then the read/eval loop. If the
    # preflight is removed or inverted, `import` runs and the trace is non-empty.
    export PATH="$SB/bin:$PATH"
    cd "$SB"
    if check_verification_parseable "$BAD_BLOCK" 2>/dev/null; then
        while IFS= read -r cmd; do
            [ -z "$cmd" ] && continue
            (eval "$cmd") >/dev/null 2>&1 || true
        done <<< "$BAD_BLOCK"
    fi
    [ ! -s "$IMPORT_TRACE" ] || {
        echo "import was reached: $(cat "$IMPORT_TRACE")" >&2; return 1; }
    [ ! -e "$SB/yaml,sys" ] || { echo "junk file was created" >&2; return 1; }
}

@test "T-2991: the fake import CAN fire — the guard above is not vacuous" {
    # Positive control for the test itself. Without it, a broken $PATH or a
    # mis-set trace variable would make the test above pass for the wrong reason,
    # which is the exact failure mode T-2990's first detector had.
    export PATH="$SB/bin:$PATH"
    cd "$SB"
    while IFS= read -r cmd; do
        [ -z "$cmd" ] && continue
        (eval "$cmd") >/dev/null 2>&1 || true
    done <<< "$BAD_BLOCK"
    [ -s "$IMPORT_TRACE" ]
    grep -q 'yaml,sys' "$IMPORT_TRACE"
    [ -e "$SB/yaml,sys" ]
}

# --- the refusal has to be actionable ---

@test "T-2991: the refusal names the offending line and both alternatives" {
    run check_verification_parseable "$BAD_BLOCK"
    echo "$output" | grep -q 'ONE LINE AT A TIME'
    echo "$output" | grep -q 'python3 -c "import yaml,sys;'   # the collapsed form
    echo "$output" | grep -q 'tests/check_f.py'               # the file form
    echo "$output" | grep -q 'FW_ALLOW_UNPARSEABLE_VERIFICATION'
}

@test "T-2991: the bypass works" {
    FW_ALLOW_UNPARSEABLE_VERIFICATION=1 run check_verification_parseable "$BAD_BLOCK"
    [ "$status" -eq 0 ]
}

# --- both execution sites ---

@test "T-2991: the close gate preflights before its eval loop" {
    local f="$FRAMEWORK_ROOT/agents/task-create/update-task.sh"
    local pre loop
    pre=$(grep -n 'check_verification_parseable' "$f" | head -1 | cut -d: -f1)
    loop=$(grep -n 'while IFS= read -r cmd' "$f" | head -1 | cut -d: -f1)
    [ -n "$pre" ] && [ -n "$loop" ]
    # Order is the entire mechanism: checking after the loop prevents nothing.
    [ "$pre" -lt "$loop" ]
}

@test "T-2991: verify_queue refuses the same block" {
    # L-399: a gate shipped on one side only is circumvented by the other side.
    grep -q '_unparseable' "$FRAMEWORK_ROOT/lib/verify_queue.py"
    grep -q 'unparseable' "$FRAMEWORK_ROOT/lib/verify_queue.py"
    python3 -c "import ast,sys; ast.parse(open('$FRAMEWORK_ROOT/lib/verify_queue.py').read())"
}

@test "T-2991: the existing corpus is unaffected" {
    # Measured at 0/2118 before the change. If this ever goes red, the preflight
    # is refusing real blocks and the corpus needs migrating before it ships.
    cd "$FRAMEWORK_ROOT"
    local bad=0 f cmds
    for f in .tasks/active/T-*.md; do
        [ -f "$f" ] || continue
        cmds=$(extract_verification_block "$f" 2>/dev/null) || continue
        [ -z "$cmds" ] && continue
        if [ -n "$(find_unparseable_verification_lines "$cmds")" ]; then
            echo "would now be refused: $f" >&2
            bad=$((bad + 1))
        fi
    done
    [ "$bad" -eq 0 ]
}
