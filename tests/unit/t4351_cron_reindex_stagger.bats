#!/usr/bin/env bats
# T-4351 — `fw cron generate` copied index-reindex-hourly's seeded `20 * * * *`
# verbatim, so every project on a host ran its heaviest disk writer at :20
# (6 of 8 on .107). The minute is now derived per project (lib/cron_schedule.py)
# unless the registry pins it, and INDEX_REINDEX_INTERVAL_HOURS sets the hour field.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    TEST_PROJECT="$TEST_TEMP_DIR/proj-stagger"
    mkdir -p "$TEST_PROJECT/.context/cron" "$TEST_PROJECT/.context/working" \
             "$TEST_PROJECT/.tasks/active" "$TEST_PROJECT/.tasks/completed" \
             "$TEST_PROJECT/.tasks/templates"
    echo "# template" > "$TEST_PROJECT/.tasks/templates/default.md"
    echo "framework_root: $FRAMEWORK_ROOT" > "$TEST_PROJECT/.framework.yaml"
    export PROJECT_ROOT="$TEST_PROJECT"
    unset FW_INDEX_REINDEX_INTERVAL_HOURS
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_minute_of() {
    python3 "$FRAMEWORK_ROOT/lib/cron_schedule.py" "$1"
}

_registry() {  # $1 = schedule, $2 = extra yaml line (optional)
    cat > "$TEST_PROJECT/.context/cron-registry.yaml" <<EOF
jobs:
  - id: index-reindex-hourly
    name: "Vector index incremental reindex (hourly)"
    schedule: "$1"
    command: "flock -n /var/lock/x.lock -c 'fw index reindex'"
    status: active
${2:-}
EOF
}

_reindex_schedule() {
    grep -E '^[0-9*H]' "$TEST_PROJECT/.context/cron/agentic-audit.crontab" \
        | grep 'index reindex' | awk '{print $1, $2, $3, $4, $5}'
}

@test "T-4351: two different project roots get different minutes" {
    a="$(_minute_of /srv/proj-0)"
    b="$(_minute_of /srv/proj-1)"
    [ "$a" != "$b" ]
}

@test "T-4351: eight roots spread over the hour (no stacking)" {
    distinct="$(for i in 0 1 2 3 4 5 6 7; do _minute_of "/srv/proj-$i"; done | sort -u | wc -l)"
    [ "$distinct" -ge 6 ]
}

@test "T-4351: same root gives the same minute every run, and generate uses it" {
    [ "$(_minute_of "$TEST_PROJECT")" = "$(_minute_of "$TEST_PROJECT")" ]
    want="$(_minute_of "$TEST_PROJECT") * * * *"
    _registry "20 * * * *"
    run "$FRAMEWORK_ROOT/bin/fw" cron generate
    [ "$status" -eq 0 ]
    [ "$(_reindex_schedule)" = "$want" ]
    run "$FRAMEWORK_ROOT/bin/fw" cron generate
    [ "$(_reindex_schedule)" = "$want" ]
}

@test "T-4351: H minute token is derived" {
    _registry "H * * * *"
    run "$FRAMEWORK_ROOT/bin/fw" cron generate
    [ "$status" -eq 0 ]
    [ "$(_reindex_schedule)" = "$(_minute_of "$TEST_PROJECT") * * * *" ]
}

@test "T-4351: an explicitly chosen minute is kept" {
    _registry "47 * * * *"
    run "$FRAMEWORK_ROOT/bin/fw" cron generate
    [ "$status" -eq 0 ]
    [ "$(_reindex_schedule)" = "47 * * * *" ]
}

@test "T-4351: schedule_pinned keeps even the seeded minute 20 and ignores the knob" {
    _registry "20 * * * *" "    schedule_pinned: true"
    export FW_INDEX_REINDEX_INTERVAL_HOURS=6
    run "$FRAMEWORK_ROOT/bin/fw" cron generate
    [ "$status" -eq 0 ]
    [ "$(_reindex_schedule)" = "20 * * * *" ]
}

@test "T-4351: INDEX_REINDEX_INTERVAL_HOURS changes the hour field (env and .framework.yaml)" {
    m="$(_minute_of "$TEST_PROJECT")"
    _registry "20 * * * *"
    FW_INDEX_REINDEX_INTERVAL_HOURS=6 run "$FRAMEWORK_ROOT/bin/fw" cron generate
    [ "$status" -eq 0 ]
    [ "$(_reindex_schedule)" = "$m */6 * * *" ]
    echo "INDEX_REINDEX_INTERVAL_HOURS: 4" >> "$TEST_PROJECT/.framework.yaml"
    run "$FRAMEWORK_ROOT/bin/fw" cron generate
    [ "$(_reindex_schedule)" = "$m */4 * * *" ]
}

@test "T-4351: an invalid interval falls back to hourly, with a note" {
    _registry "20 * * * *"
    FW_INDEX_REINDEX_INTERVAL_HOURS=99 run "$FRAMEWORK_ROOT/bin/fw" cron generate
    [ "$status" -eq 0 ]
    [[ "$output" == *"not an integer 1-24"* ]]
    [ "$(_reindex_schedule)" = "$(_minute_of "$TEST_PROJECT") * * * *" ]
}

@test "T-4351: other jobs keep their seeded schedule verbatim" {
    cat > "$TEST_PROJECT/.context/cron-registry.yaml" <<'EOF'
jobs:
  - id: other-hourly
    name: "Other"
    schedule: "20 * * * *"
    command: "fw doctor"
    status: active
EOF
    run "$FRAMEWORK_ROOT/bin/fw" cron generate
    [ "$status" -eq 0 ]
    grep -q '^20 \* \* \* \* root' "$TEST_PROJECT/.context/cron/agentic-audit.crontab"
}

@test "T-4351: doctor's dry run matches generate (no false registry drift)" {
    _registry "20 * * * *"
    FW_INDEX_REINDEX_INTERVAL_HOURS=3 run "$FRAMEWORK_ROOT/bin/fw" cron generate
    [ "$status" -eq 0 ]
    dry="$(FW_INDEX_REINDEX_INTERVAL_HOURS=3 python3 "$FRAMEWORK_ROOT/lib/cron_dry_run.py" \
        "$TEST_PROJECT" "$TEST_PROJECT/.context/cron-registry.yaml" "$FRAMEWORK_ROOT/bin/fw")"
    [ "$dry" = "$(cat "$TEST_PROJECT/.context/cron/agentic-audit.crontab")" ]
}
