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

@test "T-3680: merge that fails to parse prints no ADDED, errors, leaves registry unchanged" {
    printf 'jobs: []\n' > "$REG"
    cp "$REG" "$TEST_TEMP_DIR/before"
    # Shim yaml so the first parse (original) succeeds and the second (merged) fails.
    mkdir -p "$TEST_TEMP_DIR/shim"
    cat > "$TEST_TEMP_DIR/shim/yaml.py" <<'P'
import importlib.util, sys, sysconfig, glob, os
for d in sys.path:
    f = os.path.join(d, "yaml", "__init__.py")
    if os.path.isfile(f) and d != os.path.dirname(__file__):
        spec = importlib.util.spec_from_file_location("_realyaml", f, submodule_search_locations=[os.path.dirname(f)])
        real = importlib.util.module_from_spec(spec); sys.modules["_realyaml"] = real; spec.loader.exec_module(real); break
_n = [0]
def safe_load(t):
    _n[0] += 1
    if _n[0] > 1:
        raise ValueError("forced merge parse failure")
    return real.safe_load(t)
P
    run bash -c "PYTHONPATH='$TEST_TEMP_DIR/shim' && export PYTHONPATH && source '$FRAMEWORK_ROOT/lib/cron-seed.sh' && cron_seed_ensure_jobs '$REG' '$CONSUMER' 2>&1"
    [ "$status" -ne 0 ]
    if echo "$output" | grep -q "^ADDED"; then false; fi
    echo "$output" | grep -q "ERROR merged"
    cmp "$REG" "$TEST_TEMP_DIR/before"
}

@test "T-3680: dry run on a good registry prints ADDED and writes nothing" {
    printf 'jobs: []\n' > "$REG"
    run bash -c "CRON_SEED_DRY_RUN=1; export CRON_SEED_DRY_RUN; source '$FRAMEWORK_ROOT/lib/cron-seed.sh' && cron_seed_ensure_jobs '$REG' '$CONSUMER'"
    [ "$status" -eq 0 ]
    [ "$output" = "ADDED sidecar-sweep-5m" ]
    [ "$(cat "$REG")" = "jobs: []" ]
}
