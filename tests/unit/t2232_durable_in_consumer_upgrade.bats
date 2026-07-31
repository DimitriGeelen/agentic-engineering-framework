#!/usr/bin/env bats
# T-2232: durable in-consumer fw upgrade — vendor .upstream sentinel +
# upgrade-time fallback chain. Origin: ring20-dashboard .121do field failure
# (T-2231). Pivot from the T-2078 V1-D spec'd self-vendor refactor (kept
# under T-2095 captured-now) to the actually-durable fix for the
# in-consumer upgrade path class.
#
# Surfaces under test:
#   - bin/fw:do_vendor — writes .agentic-framework/.upstream sentinel
#   - lib/upgrade.sh:do_upgrade — fallback chain extension:
#       1. --from-upstream flag
#       2. .framework.yaml upstream_repo:
#       3. vendored .agentic-framework/.upstream sentinel  (T-2232)
#       4. error with helpful 3-path remediation
#
# AC mapping (per .tasks/active/T-2232-*.md):
#   AC#1 — t1, t2 (do_vendor writes sentinel when origin exists)
#   AC#2 — t3 (do_vendor skips sentinel when origin absent)
#   AC#3 — t4-t7 (fallback chain precedence)
#   AC#4 — t6 (observability "Resolved via" line names sentinel leg)
#   AC#5 — t8 (self-healing branch present in source; live persist guarded by dry-run)
#   AC#6 — this file (six paths covered)
#   AC#7 — upgrade_fresh_machine_simulation.bats (separate Verification line)
#   AC#8 — bin/fw reviewer T-2232 (separate Verification line)

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-t2232-XXXXXX)"
    export FRAMEWORK_ROOT
    export FW_VERSION="1.5.0"
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Build a synthetic framework source dir with optional git origin.
# If $2 is non-empty, set it as `origin` remote URL; otherwise no origin.
make_synthetic_framework_src() {
    local src="$1"
    local origin_url="$2"
    mkdir -p "$src/bin" "$src/lib" "$src/agents" "$src/web" "$src/docs"
    touch "$src/FRAMEWORK.md" "$src/metrics.sh"
    cp "$FRAMEWORK_ROOT/bin/fw" "$src/bin/fw"
    chmod +x "$src/bin/fw"
    # T-2693: do_vendor resolves the sentinel URL via lib/url-credentials.sh
    # (credential stripping + public-mirror preference). Without it the vendor
    # step deliberately refuses to write a sentinel at all, so the fixture must
    # carry the dependency a real framework tree always has.
    cp "$FRAMEWORK_ROOT/lib/url-credentials.sh" "$src/lib/url-credentials.sh"
    # Minimal git repo so do_vendor's `git -C remote get-url origin` works.
    (cd "$src" && git init -q 2>/dev/null && \
        git -c user.email=t@t -c user.name=t add FRAMEWORK.md && \
        git -c user.email=t@t -c user.name=t commit -q -m init 2>/dev/null)
    if [ -n "$origin_url" ]; then
        (cd "$src" && git remote add origin "$origin_url" 2>/dev/null)
    fi
}

# Build a consumer fixture whose vendored .agentic-framework/ has its own
# .git (so the FRAMEWORK_ROOT==target_dir/.agentic-framework collapse fires
# in do_upgrade), and an optional pre-written .upstream sentinel.
make_consumer_with_sentinel() {
    local proj="$1"
    local sentinel_url="$2"  # may be empty
    local yaml_upstream="$3" # may be empty
    mkdir -p "$proj/.agentic-framework"
    (cd "$proj/.agentic-framework" && git init -q 2>/dev/null && \
        touch FRAMEWORK.md && \
        git -c user.email=t@t -c user.name=t add FRAMEWORK.md && \
        git -c user.email=t@t -c user.name=t commit -q -m init 2>/dev/null)
    if [ -n "$sentinel_url" ]; then
        cat > "$proj/.agentic-framework/.upstream" <<EOF
# Test sentinel (T-2232)
$sentinel_url
EOF
    fi
    if [ -n "$yaml_upstream" ]; then
        cat > "$proj/.framework.yaml" <<YAML
project_name: $(basename "$proj")
version: 1.4.0
upstream_repo: $yaml_upstream
YAML
    else
        cat > "$proj/.framework.yaml" <<YAML
project_name: $(basename "$proj")
version: 1.4.0
YAML
    fi
}

# ─────────────────────────────────────────────────────────────────────────
# AC#1: do_vendor writes .upstream sentinel when source has git origin
# ─────────────────────────────────────────────────────────────────────────

@test "t2232 t1: do_vendor writes .upstream sentinel containing origin URL (AC#1)" {
    local src="$TEST_TEMP_DIR/framework-src"
    local dst_proj="$TEST_TEMP_DIR/consumer-a"
    local origin_url="https://github.com/test/framework.git"
    make_synthetic_framework_src "$src" "$origin_url"
    mkdir -p "$dst_proj"

    # Invoke do_vendor via the synthetic src's bin/fw
    run env FRAMEWORK_ROOT="$src" PROJECT_ROOT="$dst_proj" \
        "$src/bin/fw" vendor --target "$dst_proj" --source "$src"
    [ "$status" -eq 0 ]
    [ -f "$dst_proj/.agentic-framework/.upstream" ]

    # Sentinel content: at least one non-comment, non-empty line == origin URL
    local resolved
    resolved=$(grep -v '^[[:space:]]*#' "$dst_proj/.agentic-framework/.upstream" \
                 | grep -v '^[[:space:]]*$' | head -1 | sed -E 's/[[:space:]]+$//')
    [ "$resolved" = "$origin_url" ]
}

@test "t2232 t2: do_vendor sentinel header documents T-2232 origin (AC#1)" {
    local src="$TEST_TEMP_DIR/framework-src"
    local dst_proj="$TEST_TEMP_DIR/consumer-b"
    make_synthetic_framework_src "$src" "https://example.com/framework.git"
    mkdir -p "$dst_proj"

    run env FRAMEWORK_ROOT="$src" PROJECT_ROOT="$dst_proj" \
        "$src/bin/fw" vendor --target "$dst_proj" --source "$src"
    [ "$status" -eq 0 ]
    grep -q "T-2232" "$dst_proj/.agentic-framework/.upstream"
    grep -q "upstream sentinel" "$dst_proj/.agentic-framework/.upstream"
}

# ─────────────────────────────────────────────────────────────────────────
# AC#2: do_vendor skips sentinel cleanly when source has no origin
# ─────────────────────────────────────────────────────────────────────────

@test "t2232 t3: do_vendor skips .upstream sentinel when source has no git origin (AC#2)" {
    local src="$TEST_TEMP_DIR/framework-src"
    local dst_proj="$TEST_TEMP_DIR/consumer-c"
    make_synthetic_framework_src "$src" ""  # no origin
    mkdir -p "$dst_proj"

    run env FRAMEWORK_ROOT="$src" PROJECT_ROOT="$dst_proj" \
        "$src/bin/fw" vendor --target "$dst_proj" --source "$src"
    [ "$status" -eq 0 ]
    [ ! -f "$dst_proj/.agentic-framework/.upstream" ]
}

# ─────────────────────────────────────────────────────────────────────────
# AC#3: do_upgrade fallback chain (3 precedence levels)
# ─────────────────────────────────────────────────────────────────────────

@test "t2232 t4: upgrade fallback chain — --from-upstream flag wins over yaml + sentinel (AC#3 precedence-1)" {
    local proj="$TEST_TEMP_DIR/prec1-proj"
    make_consumer_with_sentinel "$proj" \
        "https://sentinel.example.com/fw.git" \
        "https://yaml.example.com/fw.git"

    local _saved_fw="$FRAMEWORK_ROOT"
    export FRAMEWORK_ROOT="$proj/.agentic-framework"
    run do_upgrade "$proj" --dry-run --from-upstream "https://flag.example.com/fw.git"
    export FRAMEWORK_ROOT="$_saved_fw"

    [ "$status" -eq 0 ]
    [[ "$output" == *"https://flag.example.com/fw.git"* ]]
    [[ "$output" == *"--from-upstream flag"* ]]
    # Negative: yaml + sentinel URLs MUST NOT appear (precedence wins early)
    [[ "$output" != *"https://yaml.example.com/fw.git"* ]]
    [[ "$output" != *"https://sentinel.example.com/fw.git"* ]]
}

@test "t2232 t5: upgrade fallback chain — yaml upstream_repo wins over sentinel (AC#3 precedence-2)" {
    local proj="$TEST_TEMP_DIR/prec2-proj"
    make_consumer_with_sentinel "$proj" \
        "https://sentinel.example.com/fw.git" \
        "https://yaml.example.com/fw.git"

    local _saved_fw="$FRAMEWORK_ROOT"
    export FRAMEWORK_ROOT="$proj/.agentic-framework"
    run do_upgrade "$proj" --dry-run
    export FRAMEWORK_ROOT="$_saved_fw"

    [ "$status" -eq 0 ]
    [[ "$output" == *"https://yaml.example.com/fw.git"* ]]
    [[ "$output" == *".framework.yaml upstream_repo:"* ]]
    # Negative: sentinel URL not used when yaml has the answer
    [[ "$output" != *"https://sentinel.example.com/fw.git"* ]]
}

@test "t2232 t6: upgrade fallback chain — sentinel resolves when flag+yaml empty + emits Resolved via line (AC#3 precedence-3, AC#4)" {
    local proj="$TEST_TEMP_DIR/prec3-proj"
    make_consumer_with_sentinel "$proj" \
        "https://sentinel.example.com/fw.git" \
        ""  # NO yaml upstream

    local _saved_fw="$FRAMEWORK_ROOT"
    export FRAMEWORK_ROOT="$proj/.agentic-framework"
    run do_upgrade "$proj" --dry-run
    export FRAMEWORK_ROOT="$_saved_fw"

    [ "$status" -eq 0 ]
    [[ "$output" == *"https://sentinel.example.com/fw.git"* ]]
    # AC#4 — observability line names the sentinel leg explicitly
    [[ "$output" == *"vendored .agentic-framework/.upstream sentinel"* ]]
    [[ "$output" == *"Resolved via"* ]]
}

@test "t2232 t7: upgrade fallback chain — all three legs empty surfaces existing helpful error (AC#3 fallthrough)" {
    local proj="$TEST_TEMP_DIR/none-proj"
    make_consumer_with_sentinel "$proj" "" ""  # no sentinel, no yaml upstream

    local _saved_fw="$FRAMEWORK_ROOT"
    export FRAMEWORK_ROOT="$proj/.agentic-framework"
    run do_upgrade "$proj"
    export FRAMEWORK_ROOT="$_saved_fw"

    [ "$status" -ne 0 ]
    [[ "$output" == *"no upstream URL is known"* ]]
    [[ "$output" == *"Remediation"* ]]
    [[ "$output" == *"upstream_repo:"* ]]
    [[ "$output" == *"--from-upstream"* ]]
}

# ─────────────────────────────────────────────────────────────────────────
# AC#5: self-healing yaml-persist branch present in source (live persist
# requires a real auto-clone success — slow, gated by dry-run check below)
# ─────────────────────────────────────────────────────────────────────────

@test "t2232 t8: self-healing yaml-persist branch present in lib/upgrade.sh (AC#5 structural)" {
    # Branch shape: condition checks BOTH the sentinel-source label AND the
    # zero return code AND absence of existing upstream_repo: line. Verifies
    # the structural path exists; live append is covered by the source
    # invariant (would need a real bare upstream clone to exercise live).
    local fw_src="$FRAMEWORK_ROOT/lib/upgrade.sh"
    grep -q "Self-heal" "$fw_src"
    grep -q "vendored .agentic-framework/.upstream sentinel" "$fw_src"
    # Persist append uses target_dir's .framework.yaml
    grep -q 'upstream_repo: \$_upstream_url' "$fw_src"
    # Dry-run safety: persist is AFTER the dry-run early-return path,
    # so dry-runs never mutate .framework.yaml.
    local proj="$TEST_TEMP_DIR/dryrun-no-persist"
    make_consumer_with_sentinel "$proj" "https://sentinel.example.com/fw.git" ""
    local _saved_fw="$FRAMEWORK_ROOT"
    export FRAMEWORK_ROOT="$proj/.agentic-framework"
    run do_upgrade "$proj" --dry-run
    export FRAMEWORK_ROOT="$_saved_fw"
    [ "$status" -eq 0 ]
    # .framework.yaml MUST NOT have grown an upstream_repo: line from the dry-run.
    ! grep -q "^upstream_repo:" "$proj/.framework.yaml"
}
