#!/usr/bin/env bats
# T-3676: cron-seed merge appended the job at column 0 into a registry whose job
# list items are indented 2 spaces (832 live upgrade) -> invalid YAML, merge refused.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"; export TEST_TEMP_DIR
    CONSUMER="$TEST_TEMP_DIR/Proj"; mkdir -p "$CONSUMER/.context"
    REG="$CONSUMER/.context/cron-registry.yaml"
}

ids() { python3 -c "import sys,yaml; print(' '.join(j['id'] for j in yaml.safe_load(open(sys.argv[1]))['jobs']))" "$REG"; }
seed() { bash -c "source '$FRAMEWORK_ROOT/lib/cron-seed.sh' && cron_seed_ensure_jobs '$REG' '$CONSUMER'"; }

@test "T-3676: 2-space-indented registry gets the job, parses, other jobs kept" {
    cat > "$REG" <<'Y'
# header
jobs:
  - id: mine
    name: mine
    schedule: '0 * * * *'
    command: echo hi
    status: active
  - id: other
    name: other
    schedule: '5 * * * *'
    command: echo yo
    status: active
Y
    run seed
    [ "$status" -eq 0 ]
    [ "$output" = "ADDED sidecar-sweep-5m" ]
    [ "$(ids)" = "mine other sidecar-sweep-5m" ]
    grep -q "^  - id: sidecar-sweep-5m" "$REG"
}

@test "T-3676: indented registry followed by a top-level key keeps that key" {
    cat > "$REG" <<'Y'
jobs:
  - id: mine
    name: mine
    schedule: '0 * * * *'
    command: echo hi
    status: active
version: 2
Y
    run seed
    [ "$status" -eq 0 ]
    [ "$(ids)" = "mine sidecar-sweep-5m" ]
    [ "$(python3 -c "import sys,yaml; print(yaml.safe_load(open(sys.argv[1]))['version'])" "$REG")" = "2" ]
}

@test "T-3676: 0-indented registry still works and rerun is PRESENT" {
    cat > "$REG" <<'Y'
jobs:
- id: mine
  name: mine
  schedule: '0 * * * *'
  command: echo hi
  status: active
Y
    run seed
    [ "$status" -eq 0 ]
    [ "$(ids)" = "mine sidecar-sweep-5m" ]
    run seed
    [ "$output" = "PRESENT sidecar-sweep-5m" ]
}
