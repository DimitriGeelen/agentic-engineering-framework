#!/usr/bin/env bats
#
# T-4652: check-tier0.sh and check-project-boundary.sh used to exit 0 (allow) when
# python3 could not decode the payload or run the matcher. They must now fall back
# to a bash-only scan of the raw payload: BLOCK on a hit, allow with a one-line
# degraded warning otherwise. Healthy python is unchanged.
#
# `! cmd` at statement position is inert in bats (T-4398): use `|| false`.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    REAL_PY="$(command -v python3)"
    PROJ="$(realpath "$(mktemp -d)")"
    mkdir -p "$PROJ/.context/working" "$PROJ/.tasks/active"
    export PROJECT_ROOT="$PROJ"

    # A python3 that cannot run at all (broken interpreter).
    BADPY="$(mktemp -d)"
    printf '#!/bin/sh\necho "python3: broken" >&2\nexit 1\n' > "$BADPY/python3"
    chmod +x "$BADPY/python3"

    # A python3 that imports fine but whose tier-0 matcher script crashes.
    CRASHPY="$(mktemp -d)"
    printf '#!/bin/sh\ncase "$*" in *strip_heredocs*) exit 1 ;; esac\nexec %s "$@"\n' "$REAL_PY" > "$CRASHPY/python3"
    chmod +x "$CRASHPY/python3"
}

teardown() {
    rm -rf "$PROJ" "$BADPY" "$CRASHPY"
}

bash_payload() {
    # $1 = command text; JSON-escape quotes by hand (tests use simple commands)
    printf '{"tool_name":"Bash","tool_use_id":"toolu_t4652","cwd":"%s","tool_input":{"command":"%s"}}' "$PROJ" "$1"
}

write_payload() {
    printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"x"}}' "$1"
}

run_hook() {
    # $1 = hook script, $2 = PATH prefix dir (empty = healthy), $3 = payload
    local hook="$ROOT/agents/context/$1" prefix="$2" payload
    payload="$3"
    if [ -n "$prefix" ]; then
        run env PATH="$prefix:$PATH" bash "$hook" <<< "$payload"
    else
        run bash "$hook" <<< "$payload"
    fi
}

# --- Tier 0, broken python ---------------------------------------------------------

@test "T-4652: tier0 + broken python + rm -rf is BLOCKED and says degraded" {
    run_hook check-tier0.sh "$BADPY" "$(bash_payload "rm -rf /var/lib/important")"
    [ "$status" -eq 2 ]
    [[ "$output" == *"HOOK DEGRADED"* ]]
    [[ "$output" == *"python3 cannot import"* ]]
}

@test "T-4652: tier0 + broken python + git push --force is BLOCKED" {
    run_hook check-tier0.sh "$BADPY" "$(bash_payload "git push --force origin master")"
    [ "$status" -eq 2 ]
    [[ "$output" == *"HOOK DEGRADED"* ]]
}

@test "T-4652: tier0 + broken python + git reset --hard is BLOCKED" {
    run_hook check-tier0.sh "$BADPY" "$(bash_payload "git reset --hard HEAD~3")"
    [ "$status" -eq 2 ]
}

@test "T-4652: tier0 + broken python + git branch -D is BLOCKED" {
    run_hook check-tier0.sh "$BADPY" "$(bash_payload "git branch -D victim")"
    [ "$status" -eq 2 ]
}

@test "T-4652: tier0 + broken python + DROP TABLE is BLOCKED" {
    run_hook check-tier0.sh "$BADPY" "$(bash_payload "psql -c 'DROP TABLE users'")"
    [ "$status" -eq 2 ]
}

@test "T-4652: tier0 + broken python + benign command is ALLOWED with a degraded warning" {
    run_hook check-tier0.sh "$BADPY" "$(bash_payload "ls -la")"
    [ "$status" -eq 0 ]
    [[ "$output" == *"DEGRADED"* ]]
}

@test "T-4652: tier0 + matcher crash (python imports fine) + destructive command is BLOCKED" {
    run_hook check-tier0.sh "$CRASHPY" "$(bash_payload "rm -rf /var/lib/important")"
    [ "$status" -eq 2 ]
    [[ "$output" == *"HOOK DEGRADED"* ]]
    [[ "$output" == *"no verdict"* ]]
}

# --- Tier 0, healthy python (unchanged) --------------------------------------------

@test "T-4652: tier0 + healthy python + benign command is allowed silently" {
    run_hook check-tier0.sh "" "$(bash_payload "ls -la")"
    [ "$status" -eq 0 ]
    [[ "$output" != *"DEGRADED"* ]]
}

@test "T-4652: tier0 + healthy python + git reset --hard is blocked by the normal path, not the degraded one" {
    run_hook check-tier0.sh "" "$(bash_payload "git reset --hard HEAD~3")"
    [ "$status" -eq 2 ]
    [[ "$output" == *"TIER 0 BLOCK"* ]]
    [[ "$output" != *"HOOK DEGRADED"* ]]
}

# --- Project boundary, broken python -----------------------------------------------

@test "T-4652: boundary + broken python + Write to another project is BLOCKED" {
    run_hook check-project-boundary.sh "$BADPY" "$(write_payload "/opt/other-project/file.txt")"
    [ "$status" -eq 2 ]
    [[ "$output" == *"HOOK DEGRADED"* ]]
}

@test "T-4652: boundary + broken python + Bash cd into another project is BLOCKED" {
    run_hook check-project-boundary.sh "$BADPY" "$(bash_payload "cd /opt/other-project && touch x")"
    [ "$status" -eq 2 ]
}

@test "T-4652: boundary + broken python + Write inside this project is ALLOWED with a warning" {
    run_hook check-project-boundary.sh "$BADPY" "$(write_payload "$PROJ/docs/a.md")"
    [ "$status" -eq 0 ]
    [[ "$output" == *"DEGRADED"* ]]
}

@test "T-4652: boundary + broken python + benign Bash is ALLOWED with a warning" {
    run_hook check-project-boundary.sh "$BADPY" "$(bash_payload "ls -la")"
    [ "$status" -eq 0 ]
    [[ "$output" == *"DEGRADED"* ]]
}

# --- Project boundary, healthy python (unchanged) ----------------------------------

@test "T-4652: boundary + healthy python + Write to another project uses the normal block" {
    run_hook check-project-boundary.sh "" "$(write_payload "/opt/other-project/file.txt")"
    [ "$status" -eq 2 ]
    [[ "$output" == *"PROJECT BOUNDARY BLOCK"* ]]
    [[ "$output" != *"HOOK DEGRADED"* ]]
}

@test "T-4652: boundary + healthy python + Write inside this project is allowed silently" {
    run_hook check-project-boundary.sh "" "$(write_payload "$PROJ/docs/a.md")"
    [ "$status" -eq 0 ]
    [[ "$output" != *"DEGRADED"* ]]
}
