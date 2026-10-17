#!/usr/bin/env bats
# T-4226: one budget ladder from one spawn reserve R. Pins the four worked
# windows from the operator ruling (2026-10-17) and each boundary
# (threshold, threshold - 1) through lib/budget_ladder.py.

setup() {
    FW_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    LADDER="$FW_ROOT/lib/budget_ladder.py"
}

# Print the value of KEY from the ladder CLI output for window $1.
table_value() {
    python3 -I "$LADDER" "$1" | sed -n "s/^$2=//p"
}

# Print LEVEL for window $1 at used $2.
level_at() {
    python3 -I "$LADDER" "$1" "$2" | sed -n 's/^LEVEL=//p'
}

@test "200K window: Amber 160K, Red 170K, Stop 180K used (R=20K)" {
    [ "$(table_value 200000 BUDGET_RESERVE)" -eq 20000 ]
    [ "$(table_value 200000 TOKEN_WARN)" -eq 160000 ]
    [ "$(table_value 200000 TOKEN_URGENT)" -eq 170000 ]
    [ "$(table_value 200000 TOKEN_CRITICAL)" -eq 180000 ]
}

@test "500K window: Amber 412.5K, Red 438.75K, Stop 465K (R=35K)" {
    [ "$(table_value 500000 BUDGET_RESERVE)" -eq 35000 ]
    [ "$(table_value 500000 TOKEN_WARN)" -eq 412500 ]
    [ "$(table_value 500000 TOKEN_URGENT)" -eq 438750 ]
    [ "$(table_value 500000 TOKEN_CRITICAL)" -eq 465000 ]
}

@test "800K window: Amber 650K, Red 700K, Stop 750K (R=50K)" {
    [ "$(table_value 800000 BUDGET_RESERVE)" -eq 50000 ]
    [ "$(table_value 800000 TOKEN_WARN)" -eq 650000 ]
    [ "$(table_value 800000 TOKEN_URGENT)" -eq 700000 ]
    [ "$(table_value 800000 TOKEN_CRITICAL)" -eq 750000 ]
}

@test "975K window (this project): Amber 825K, Red 875K, Stop 925K" {
    [ "$(table_value 975000 BUDGET_RESERVE)" -eq 50000 ]
    [ "$(table_value 975000 TOKEN_WARN)" -eq 825000 ]
    [ "$(table_value 975000 TOKEN_URGENT)" -eq 875000 ]
    [ "$(table_value 975000 TOKEN_CRITICAL)" -eq 925000 ]
}

@test "reserve is 20K below 200K and 50K from 800K up" {
    [ "$(table_value 100000 BUDGET_RESERVE)" -eq 20000 ]
    [ "$(table_value 1000000 BUDGET_RESERVE)" -eq 50000 ]
}

@test "boundaries: threshold is the higher band, threshold - 1 is the lower" {
    # 800K: Amber 650K, Red 700K, Stop 750K
    [ "$(level_at 800000 649999)" = "ok" ]
    [ "$(level_at 800000 650000)" = "warn" ]
    [ "$(level_at 800000 699999)" = "warn" ]
    [ "$(level_at 800000 700000)" = "urgent" ]
    [ "$(level_at 800000 749999)" = "urgent" ]
    [ "$(level_at 800000 750000)" = "critical" ]
}

@test "boundaries hold on the fractional 500K ladder" {
    [ "$(level_at 500000 412499)" = "ok" ]
    [ "$(level_at 500000 412500)" = "warn" ]
    [ "$(level_at 500000 438749)" = "warn" ]
    [ "$(level_at 500000 438750)" = "urgent" ]
    [ "$(level_at 500000 464999)" = "urgent" ]
    [ "$(level_at 500000 465000)" = "critical" ]
}

@test "free tokens are reported next to the level" {
    run python3 -I "$LADDER" 975000 900000
    [ "$status" -eq 0 ]
    [[ "$output" == *"LEVEL=urgent"* ]]
    [[ "$output" == *"FREE_TOKENS=75000"* ]]
}

@test "bad arguments exit 64 with usage" {
    run python3 -I "$LADDER"
    [ "$status" -eq 64 ]
    [[ "$output" == *"usage"* ]]
}
