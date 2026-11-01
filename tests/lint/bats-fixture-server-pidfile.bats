#!/usr/bin/env bats
# T-4976: a bats file that backgrounds a fixture server (tests/fixtures/*_watchtower.py)
# must record the pid in a FILE, not only in a shell variable. Callers start the server
# inside $(...), so a variable set there never reaches teardown, and the server outlived
# every run: 51 foreign_watchtower.py processes were found live on the host, some for days.
# T-4338 fixed t3382 this way; the two sibling files were missed. This lint covers the shape.

setup() {
    ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

@test "every bats file that backgrounds a fixture server writes its pid to a file" {
    local bad=() f
    while IFS= read -r f; do
        grep -qE 'echo "\$[A-Z_]*PID" >>? "[^"]*\.pids?"' "$f" || bad+=("${f#"$ROOT"/}")
    done < <(grep -rlE 'fixtures/[a-z_]*watchtower\.py' "$ROOT/tests" --include='*.bats' \
             | xargs grep -lE '^[[:space:]]*[A-Z_]*PID=\$!' 2>/dev/null)
    if [ "${#bad[@]}" -gt 0 ]; then
        printf 'no pid file for a backgrounded fixture server: %s\n' "${bad[@]}"
        false
    fi
}

@test "control: the scan finds the files that start fixture servers" {
    run bash -c "grep -rlE 'fixtures/[a-z_]*watchtower\.py' '$ROOT/tests' --include='*.bats' | wc -l"
    [ "$output" -ge 3 ]
}
