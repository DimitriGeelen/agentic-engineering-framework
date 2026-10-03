#!/usr/bin/env bats
# T-3783 (010 T-3336): the vector index froze in 47 of 49 projects on .107.
# (1) every consumer is seeded with the hourly reindex job;
# (2) `fw index reindex` and `fw ask` import web/ from FRAMEWORK_ROOT, not PROJECT_ROOT;
# (3) an unimportable reindex is a failure (exit 2), never a quiet exit 0.

ROOT="${BATS_TEST_DIRNAME}/../.."

setup() { TMPD="$(mktemp -d)"; mkdir -p "$TMPD/proj"; }
teardown() { rm -rf "$TMPD"; }

@test "cron seed adds index-reindex-hourly to a consumer registry, once" {
    printf 'jobs:\n- id: other\n  schedule: "0 * * * *"\n  command: "true"\n' > "$TMPD/r.yaml"
    source "$ROOT/lib/cron-seed.sh"
    run cron_seed_ensure_jobs "$TMPD/r.yaml" "$TMPD/proj"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ADDED index-reindex-hourly"* ]]
    run cron_seed_ensure_jobs "$TMPD/r.yaml" "$TMPD/proj"
    [[ "$output" == *"PRESENT index-reindex-hourly"* ]]
    [ "$(grep -c 'id: index-reindex-hourly' "$TMPD/r.yaml")" -eq 1 ]
}

@test "web.embeddings is importable from a consumer cwd only with FRAMEWORK_ROOT on the path (the bug and the fix)" {
    cd "$TMPD/proj"
    run python3 -c "import web.embeddings"
    [ "$status" -ne 0 ]
    run env PYTHONPATH="$ROOT" python3 -c "from web.embeddings import reindex_incremental"
    [ "$status" -eq 0 ]
}

@test "fw index reindex runs python with FRAMEWORK_ROOT on PYTHONPATH and exits 2 when unimportable" {
    blk="$(sed -n '/^            reindex)$/,/^                ;;$/p' "$ROOT/bin/fw")"
    [[ "$blk" == *'PYTHONPATH="$FRAMEWORK_ROOT'* ]]
    [[ "$blk" == *'"unimportable"'* ]]
    echo "$blk" | grep -A3 '"unimportable"' | grep -q 'sys.exit(2)'
}

@test "lib/ask.py starts from a consumer cwd (FRAMEWORK_ROOT first on sys.path)" {
    cd "$TMPD/proj"
    run env PROJECT_ROOT="$TMPD/proj" FRAMEWORK_ROOT="$ROOT" timeout 60 python3 "$ROOT/lib/ask.py" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"usage: ask.py"* ]]
}
