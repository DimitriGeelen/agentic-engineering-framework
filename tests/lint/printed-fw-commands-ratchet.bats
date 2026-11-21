#!/usr/bin/env bats
#
# T-5306 (slice 4 of T-5302) — ratchet on hand-written `bin/fw <verb>` and
# `bin/watchtower.sh ...` in text printed to a person or an agent.
#
# Rule (T-5302 GO): printed commands come from the builder —
#   shell   $(_emit_user_command "<args>") / "$(_fw_cmd) <args>"   lib/fw-command.sh
#   python  user_command("<args>") / fw_path()                      lib/fw_command.py
#   jinja   {{ fw_cmd('<args>') }}                                  web/app.py
# A vendored project has no bin/ at its root, so a hand-written one fails as
# printed. Detector and its heuristics: tools/printed-fw-commands-lint.py.
# Baseline (path -> count, may only shrink):
#   tests/lint/fixtures/printed-fw-commands-baseline.json
# Shrink it after a fix with:
#   python3 tools/printed-fw-commands-lint.py --regenerate
# The test never writes the baseline itself.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    LINT="$ROOT/tools/printed-fw-commands-lint.py"
    BASE="$ROOT/tests/lint/fixtures/printed-fw-commands-baseline.json"
    T="$BATS_TEST_TMPDIR/tree"
    mkdir -p "$T/bin" "$T/lib" "$T/agents" "$T/web/templates"
    # The verb list comes from the real router; the temp tree has no bin/fw.
    export ROOT LINT BASE T
}

_base_from() {  # write a baseline for the temp tree
    run python3 "$LINT" --root "$T" --baseline "$BATS_TEST_TMPDIR/base.json" --regenerate
    [ "$status" -eq 0 ]
}

_check() {
    run python3 "$LINT" --root "$T" --baseline "$BATS_TEST_TMPDIR/base.json" "$@"
}

@test "live tree: no file above its baseline, no file outside it" {
    run python3 "$LINT" --baseline "$BASE"
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" == *"new 0"* ]]
    if [[ "$output" == *"NOTE "* ]]; then
        echo "# baseline can shrink: python3 tools/printed-fw-commands-lint.py --regenerate" >&3
    fi
}

@test "control: a new printed bin/fw doctor line turns it red, naming file, line and builder" {
    printf '%s\n' '#!/usr/bin/env bash' 'echo "old: bin/fw audit"' > "$T/lib/probe.sh"
    _base_from
    _check
    [ "$status" -eq 0 ]

    printf '%s\n' 'echo "  Run: bin/fw doctor" >&2' >> "$T/lib/probe.sh"
    _check
    echo "$output"
    [ "$status" -eq 1 ]
    [[ "$output" == *"NEW lib/probe.sh: 2 now, baseline 1"* ]]
    [[ "$output" == *"lib/probe.sh:3:"* ]]
    [[ "$output" == *"_emit_user_command"* ]]
}

@test "a file outside the baseline is red; python and jinja builders are named" {
    printf '%s\n' 'x = 1' > "$T/lib/a.py"
    _base_from
    printf '%s\n' 'print("then run bin/fw task review T-1")' > "$T/lib/new.py"
    printf '%s\n' '<p>Run <code>bin/watchtower.sh restart</code></p>' > "$T/web/templates/new.html"
    _check
    echo "$output"
    [ "$status" -eq 1 ]
    [[ "$output" == *"NEW lib/new.py: new file, not in baseline"* ]]
    [[ "$output" == *"user_command("* ]]
    [[ "$output" == *"NEW web/templates/new.html: new file, not in baseline"* ]]
    [[ "$output" == *"fw_cmd("* ]]
}

@test "a count below baseline stays green and says how to regenerate" {
    printf '%s\n' 'echo "bin/fw doctor"' 'echo "bin/fw audit"' > "$T/lib/two.sh"
    _base_from
    sed -i '2d' "$T/lib/two.sh"
    cp "$BATS_TEST_TMPDIR/base.json" "$BATS_TEST_TMPDIR/base.before"
    _check
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" == *"NOTE lib/two.sh: 1 now, baseline 2"* ]]
    [[ "$output" == *"--regenerate"* ]]
    # never auto-written
    cmp "$BATS_TEST_TMPDIR/base.json" "$BATS_TEST_TMPDIR/base.before"
}

@test "not counted: comments, exec/substitution, longer paths, prose about the file, builders" {
    cat > "$T/lib/quiet.sh" <<'EOF'
#!/usr/bin/env bash
# echo "Run: bin/fw doctor"
"$FRAMEWORK_ROOT/bin/fw" doctor
bin/fw doctor >/dev/null
url="$(bin/fw watchtower url)"
echo "$(bin/fw watchtower url)/review"
echo "Hooks should reference: .agentic-framework/bin/fw hook <name>"
echo "  OK  bin/fw is the real CLI"
echo "Run: $(_emit_user_command "doctor")"
cat > "$hook" <<'HOOK'
# hook comment: bin/fw doctor
bin/fw hook check-x
HOOK
EOF
    cat > "$T/lib/quiet.py" <<'EOF'
"""Docstring: run bin/fw doctor."""
import subprocess, re
subprocess.run(["bash", "-c", "bin/fw doctor"])
PAT = re.compile(r"bin/fw doctor")
RAW = [r"bin/fw write-set"]
if cmd == "bin/fw doctor":
    pass
# print("bin/fw doctor")
EOF
    printf '%s\n' '{# bin/fw doctor #}' '<!-- bin/fw doctor -->' '<p>{{ fw_cmd("doctor") }}</p>' > "$T/web/templates/q.html"
    mkdir -p "$T/lib"
    printf '%s\n' 'echo "bin/fw doctor"' > "$T/lib/fw-command.sh"
    run python3 "$LINT" --root "$T" --no-baseline --list
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" == *"total 0 in 0 files"* ]]
}

@test "counted: echo/printf, stdout heredoc, echo inside a generated hook, python print and f-string" {
    cat > "$T/lib/loud.sh" <<'EOF'
#!/usr/bin/env bash
echo "Fix: cd $PROJECT_ROOT && bin/fw upgrade"
printf '  - bin/watchtower.sh restart\n'
cat <<MSG >&2
  1. bin/fw config set X 1
MSG
cat > "$hook" <<'HOOK'
echo "run bin/fw vendor self" >&2
HOOK
EOF
    cat > "$T/lib/loud.py" <<'EOF'
print("Run: bin/fw doctor")
msg = f"then `bin/fw task review {tid}`"
EOF
    run python3 "$LINT" --root "$T" --no-baseline --list
    echo "$output"
    [ "$status" -eq 1 ]
    [[ "$output" == *"total 6 in 2 files"* ]]
}

@test "missing baseline is a usage error, not a pass" {
    run python3 "$LINT" --root "$T" --baseline "$BATS_TEST_TMPDIR/nope.json"
    [ "$status" -eq 2 ]
}
