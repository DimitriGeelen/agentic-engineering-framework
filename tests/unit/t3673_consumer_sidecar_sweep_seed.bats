#!/usr/bin/env bats
# T-3673: consumers never received sidecar-sweep-5m — init seeded `jobs: []` and
# upgrade never merged framework jobs into an existing registry.
#   (a) fresh init registry contains the job (per-project lock, bare `fw`)
#   (b) upgrade adds it to a registry lacking it
#   (c) upgrade leaves an operator-modified job with that id untouched
#   (d) a second upgrade is a no-op

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"; export TEST_TEMP_DIR
    export CONSUMER="$TEST_TEMP_DIR/My_Proj"
    mkdir -p "$CONSUMER"
    git -C "$CONSUMER" init -q
    git -C "$CONSUMER" config user.email t@example.com
    git -C "$CONSUMER" config user.name t
    REG="$CONSUMER/.context/cron-registry.yaml"
}

ids() { python3 -c "import sys,yaml; print(' '.join(j['id'] for j in yaml.safe_load(open(sys.argv[1]))['jobs']))" "$REG"; }

@test "T-3673 (a): fresh fw init seeds sidecar-sweep-5m with per-project lock" {
    run timeout 180 "$FRAMEWORK_ROOT/bin/fw" init "$CONSUMER" --no-first-run
    [ -f "$REG" ]
    [ "$(ids)" = "sidecar-sweep-5m index-reindex-hourly" ]
    grep -q "agentic-cron-sidecar-sweep-5m-my_proj.lock" "$REG"
    grep -q "'fw sidecar sweep'" "$REG"
}

@test "T-3673 (b): upgrade adds the job to a registry lacking it, keeping other jobs" {
    mkdir -p "$CONSUMER/.context"
    cat > "$REG" <<'Y'
# operator comment
jobs:
- id: mine
  name: mine
  schedule: '0 * * * *'
  command: echo hi
  status: active
Y
    run bash -c "cd '$CONSUMER' && source '$FRAMEWORK_ROOT/lib/cron-seed.sh' && cron_seed_ensure_jobs '$REG' '$CONSUMER'"
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf 'ADDED sidecar-sweep-5m\nADDED index-reindex-hourly')" ]  # T-3783: two framework jobs
    [ "$(ids)" = "mine sidecar-sweep-5m index-reindex-hourly" ]
    grep -q "# operator comment" "$REG"
}

@test "T-3673 (b2): upgrade wires the merge and reports ADDED / already present" {
    grep -q 'cron_seed_ensure_jobs "\$target_dir/.context/cron-registry.yaml"' "$FRAMEWORK_ROOT/lib/upgrade.sh"
    grep -q 'already present' "$FRAMEWORK_ROOT/lib/upgrade.sh"
    grep -q '${GREEN}ADDED${NC}  cron job' "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

@test "T-3673 (c): an operator-modified job with the same id is left untouched" {
    mkdir -p "$CONSUMER/.context"
    cat > "$REG" <<'Y'
jobs:
- id: sidecar-sweep-5m
  name: my tuned sweep
  schedule: '*/10 * * * *'
  command: fw sidecar sweep
  status: paused
Y
    cp "$REG" "$TEST_TEMP_DIR/before.yaml"
    run bash -c "source '$FRAMEWORK_ROOT/lib/cron-seed.sh' && cron_seed_ensure_jobs '$REG' '$CONSUMER'"
    [ "$status" -eq 0 ]
    # T-3783: the other framework job is still added, so the file grows — but the
    # operator's tuned block must survive byte for byte as the file's prefix.
    [ "$output" = "$(printf 'PRESENT sidecar-sweep-5m\nADDED index-reindex-hourly')" ]
    n=$(wc -c < "$TEST_TEMP_DIR/before.yaml")
    cmp -n "$n" "$REG" "$TEST_TEMP_DIR/before.yaml"
    grep -q "status: paused" "$REG"
    [ "$(grep -c 'id: sidecar-sweep-5m' "$REG")" -eq 1 ]
}

@test "T-3673 (d): second upgrade is idempotent" {
    mkdir -p "$CONSUMER/.context"
    printf 'jobs: []\n' > "$REG"
    run bash -c "source '$FRAMEWORK_ROOT/lib/cron-seed.sh' && cron_seed_ensure_jobs '$REG' '$CONSUMER'"
    [ "$output" = "$(printf 'ADDED sidecar-sweep-5m\nADDED index-reindex-hourly')" ]  # T-3783: two framework jobs
    cp "$REG" "$TEST_TEMP_DIR/after1.yaml"
    run bash -c "source '$FRAMEWORK_ROOT/lib/cron-seed.sh' && cron_seed_ensure_jobs '$REG' '$CONSUMER'"
    [ "$output" = "$(printf 'PRESENT sidecar-sweep-5m\nPRESENT index-reindex-hourly')" ]
    cmp "$REG" "$TEST_TEMP_DIR/after1.yaml"
}

@test "T-3673: dry-run reports ADDED without writing" {
    mkdir -p "$CONSUMER/.context"
    printf 'jobs: []\n' > "$REG"
    run bash -c "CRON_SEED_DRY_RUN=1 && export CRON_SEED_DRY_RUN && source '$FRAMEWORK_ROOT/lib/cron-seed.sh' && cron_seed_ensure_jobs '$REG' '$CONSUMER'"
    [ "$output" = "$(printf 'ADDED sidecar-sweep-5m\nADDED index-reindex-hourly')" ]  # T-3783: two framework jobs
    [ "$(cat "$REG")" = "jobs: []" ]
}
