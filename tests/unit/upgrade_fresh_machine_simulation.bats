#!/usr/bin/env bats
# T-1635: fresh-machine simulation guard for fw upgrade.
#
# Validates that fw upgrade works end-to-end on a "fresh-from-vendor"
# consumer — only .agentic-framework/ + .framework.yaml, no /opt/999
# source-of-truth nearby, no ~/.local/bin/fw shim, scrubbed PATH.
#
# Slim slice (no docker required, runs in any bats environment):
#   - tempdir = simulated "fresh machine"
#   - upstream bare repo locally = simulated "tagged framework release"
#   - consumer = vendored .agentic-framework/ + .framework.yaml
#   - scrubbed env (no FRAMEWORK_ROOT / PROJECT_ROOT, minimal PATH)
#   - invoke consumer's vendored bin/fw upgrade as a subprocess
#
# Distinct from tests/unit/upgrade_auto_clone.bats: that file sources
# lib/upgrade.sh and exercises do_upgrade as a function with a stub
# upstream fw. This test goes end-to-end with a real bin/fw subprocess
# against a real file:// upstream bare repo cloned from FRAMEWORK_ROOT.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-fresh-machine-XXXXXX)"
    export FRAMEWORK_ROOT
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Build a simulated "tagged framework release" by cloning FRAMEWORK_ROOT
# into a bare repo. The bare URL is suitable for file:// upstream_repo.
make_upstream_bare() {
    local bare="$1"
    # --shared keeps it cheap (no full object copy); --bare is required for
    # the consumer's clone-from-upstream path.
    git clone --quiet --bare --shared "$FRAMEWORK_ROOT" "$bare" 2>/dev/null
}

# Build a consumer project: proj/.agentic-framework/ (clone of upstream)
# + proj/.framework.yaml (with upstream_repo pointing at the bare).
make_fresh_consumer() {
    local proj="$1"
    local upstream_bare="$2"
    mkdir -p "$proj"
    git clone --quiet --depth=1 "file://$upstream_bare" "$proj/.agentic-framework" 2>/dev/null
    cat > "$proj/.framework.yaml" <<YAML
project_name: $(basename "$proj")
version: 1.0.0
provider: claude
upstream_repo: file://$upstream_bare
YAML
}

# Run a command under "fresh-machine" simulation:
#   - cwd = consumer project (so PROJECT_ROOT resolves to it, not to the
#     dev-host's framework repo via find_project_root's upward walk)
#   - env -i  (full env strip — no FRAMEWORK_ROOT, no PROJECT_ROOT, no
#     framework-shim PATH entries leaking from the dev machine)
#   - minimal PATH (/usr/local/bin:/usr/bin:/bin only — what a fresh
#     LXC / container would have)
#   - HOME = tempdir (so any ~/.local/bin/fw shim on the dev host is
#     invisible)
fresh_run() {
    local proj="$1"; shift
    (cd "$proj" && env -i \
        PATH="/usr/local/bin:/usr/bin:/bin" \
        HOME="$TEST_TEMP_DIR/home" \
        "$proj/.agentic-framework/bin/fw" "$@")
}

@test "fresh-machine: vendored bin/fw runs --version in scrubbed env" {
    local upstream_bare="$TEST_TEMP_DIR/upstream.git"
    local proj="$TEST_TEMP_DIR/proj"
    make_upstream_bare "$upstream_bare"
    make_fresh_consumer "$proj" "$upstream_bare"

    run fresh_run "$proj" --version
    [ "$status" -eq 0 ]
    [[ "$output" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]
}

@test "fresh-machine: vendored bin/fw upgrade --dry-run completes in scrubbed env" {
    local upstream_bare="$TEST_TEMP_DIR/upstream.git"
    local proj="$TEST_TEMP_DIR/proj"
    make_upstream_bare "$upstream_bare"
    make_fresh_consumer "$proj" "$upstream_bare"

    # bare-from-consumer guard MUST fire (FRAMEWORK_ROOT == target/.agentic-framework)
    # AND auto-clone path MUST take over via .framework.yaml upstream_repo.
    run fresh_run "$proj" upgrade "$proj" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Bare-from-consumer"* ]] || [[ "$output" == *"upgrade"* ]] || [[ "$output" == *"Upgrade"* ]]
}

@test "fresh-machine: vendored bin/fw upgrade --dry-run shows the bare-from-consumer + auto-clone handoff plan" {
    # Stronger assertion on test 2's plan: bare-from-consumer message AND the
    # auto-clone target path are both surfaced. This is what blocks a regression
    # in the T-1542 (bare-from-consumer detection) or T-1634 (auto-clone path)
    # code paths from shipping silently.
    local upstream_bare="$TEST_TEMP_DIR/upstream.git"
    local proj="$TEST_TEMP_DIR/proj"
    make_upstream_bare "$upstream_bare"
    make_fresh_consumer "$proj" "$upstream_bare"

    run fresh_run "$proj" upgrade "$proj" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"file://$upstream_bare"* ]]
    [[ "$output" == *"would clone"* ]] || [[ "$output" == *"would re-invoke"* ]]
}

# ── T-2637 (OBS-096, 832 G-011): reviewer code-requires-data guard ──────────
# 832's vendored consumer had lib/reviewer/* but no policy/ catalogues —
# `fw reviewer` crashed on first invocation (exit 3, "catalogue not found").
# T-2329 added policy/ to the vendor set; these tests make the pairing a
# simulation invariant so a future code-requires-data split (new catalogue
# file, new data dir) fails here instead of shipping silently.

@test "fresh-machine: vendored tree ships reviewer catalogues alongside lib/reviewer (G-011 pairing)" {
    local upstream_bare="$TEST_TEMP_DIR/upstream.git"
    local proj="$TEST_TEMP_DIR/proj"
    make_upstream_bare "$upstream_bare"
    make_fresh_consumer "$proj" "$upstream_bare"

    [ -d "$proj/.agentic-framework/lib/reviewer" ]
    [ -f "$proj/.agentic-framework/policy/anti-patterns.yaml" ]
    [ -f "$proj/.agentic-framework/policy/escalation-patterns.yaml" ]
}

@test "fresh-machine: fw reviewer smoke-run resolves vendored catalogues in scrubbed env (G-011 guard)" {
    local upstream_bare="$TEST_TEMP_DIR/upstream.git"
    local proj="$TEST_TEMP_DIR/proj"
    make_upstream_bare "$upstream_bare"
    make_fresh_consumer "$proj" "$upstream_bare"

    mkdir -p "$proj/.tasks/active"
    cat > "$proj/.tasks/active/T-9999-smoke.md" <<'TASK'
---
id: T-9999
name: reviewer-smoke
status: started-work
workflow_type: build
owner: agent
---

# T-9999: reviewer smoke

## Acceptance Criteria

### Agent
- [x] File exists

## Verification

test -f .framework.yaml
TASK

    run fresh_run "$proj" reviewer T-9999 --no-write
    # exit 3 = "catalogue not found" — the exact G-011 failure this guards
    [ "$status" -ne 3 ]
    [[ "$output" != *"catalogue not found"* ]]
    # a resolved catalogue produces a verdict line
    [[ "$output" == *"PASS"* ]] || [[ "$output" == *"Overall"* ]] || [[ "$output" == *"verdict"* ]]
}

# ── T-2647 (832 G-001): vendor payload completeness + no-silent-skip ────────
# 832's consumer (their F4) committed for weeks with "secret-scan: scanner not
# found (skipping)" — a security control that silently no-ops. Two guards:
# payload-completeness (runtime-referenced files exist in the vendored tree)
# and the no-silent-skip contract (missing scanner warns LOUDLY, strict mode
# blocks) pinned against the INSTALLED hook, not the template.

@test "fresh-machine: vendored tree ships runtime-referenced git/audit scripts (G-001 payload completeness)" {
    local upstream_bare="$TEST_TEMP_DIR/upstream.git"
    local proj="$TEST_TEMP_DIR/proj"
    make_upstream_bare "$upstream_bare"
    make_fresh_consumer "$proj" "$upstream_bare"

    # Referenced by the installed pre-commit hook at runtime:
    [ -f "$proj/.agentic-framework/agents/git/lib/secret-scan.sh" ]
    [ -f "$proj/.agentic-framework/agents/git/lib/master-guard.sh" ]
    # Referenced by audit's orchestrator section at runtime:
    [ -f "$proj/.agentic-framework/agents/audit/orchestrator-mcp-scan.sh" ]
}

@test "fresh-machine: missing secret-scan is LOUD and strict mode blocks (G-001 no-silent-skip)" {
    local upstream_bare="$TEST_TEMP_DIR/upstream.git"
    local proj="$TEST_TEMP_DIR/proj"
    make_upstream_bare "$upstream_bare"
    make_fresh_consumer "$proj" "$upstream_bare"

    # Extract the pre-commit template exactly as install-hooks writes it, into
    # a git repo whose vendored payload LACKS the scanner (the 832 field state).
    (cd "$proj" && git init --quiet . 2>/dev/null || true)
    # Install hooks via the vendored fw (consumer-facing path under test).
    run fresh_run "$proj" git install-hooks
    [ -f "$proj/.git/hooks/pre-commit" ]

    rm -f "$proj/.agentic-framework/agents/git/lib/secret-scan.sh"

    # Default: fail-open but UNMISSABLE (multi-line warning naming the risk).
    run bash -c "cd '$proj' && env -i PATH='/usr/local/bin:/usr/bin:/bin' HOME='$TEST_TEMP_DIR/home' bash .git/hooks/pre-commit"
    [ "$status" -eq 0 ]
    [[ "$output" == *"SECRET SCAN IS NOT RUNNING"* ]]
    [[ "$output" == *"WITHOUT secret scanning"* ]]

    # Strict: blocks.
    run bash -c "cd '$proj' && env -i PATH='/usr/local/bin:/usr/bin:/bin' HOME='$TEST_TEMP_DIR/home' FW_SECRET_SCAN_STRICT=1 bash .git/hooks/pre-commit"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Commit blocked"* ]]
}

# NOTE on live (non-dry-run) upgrade: a network-backed upgrade against a real
# remote (git fetch/clone over the wire, plus docs/component regen) can run
# minutes long — impractical for a unit test gate. The "framework -> consumer"
# path beyond re-exec is already covered by tests/unit/lib_upgrade.bats; the
# re-exec handoff is asserted by the dry-run test above. A docker-container
# variant of that full network-backed upgrade is the natural release-gate
# follow-up (see T-1635 ## Evolution).
#
# What IS practical, and load-bearing enough to gate on: the self-replacement
# hazard in isolation (T-2793 AC4). `fw upgrade`'s bare-from-consumer path
# clones upstream to a TEMPDIR first, then do_vendor's rsync overwrites the
# consumer's bin/, lib/, agents/, etc. — including the bin/fw file the running
# process was exec'd from. With a local file:// upstream (no network), that
# whole path runs in a few seconds, so it belongs in the gate.
@test "T-2793 AC4: live (non-dry-run) fw upgrade safely overwrites its own currently-executing bin/fw" {
    local upstream_bare="$TEST_TEMP_DIR/upstream.git"
    local proj="$TEST_TEMP_DIR/selfrepl-proj"
    make_upstream_bare "$upstream_bare"

    # A genuinely vendored consumer (do_vendor's rsync copy, no .git — same
    # shape `fw init`/`fw vendor` produce), pointed at a LOCAL upstream so the
    # bare-from-consumer auto-clone needs no network and carries no creds.
    "$FRAMEWORK_ROOT/bin/fw" vendor --target "$proj" --source "$FRAMEWORK_ROOT" >/dev/null
    cat > "$proj/.framework.yaml" <<YAML
project_name: selfrepl-proj
version: $(tr -d '\n' < "$proj/.agentic-framework/VERSION")
provider: claude
upstream_repo: file://$upstream_bare
YAML

    local fw_bin="$proj/.agentic-framework/bin/fw"
    # Distinguishing marker in the file the process is about to run FROM —
    # proves a real overwrite happened, not a same-content no-op copy.
    sed -i '2a # T2793-SELFREPLACE-MARKER-STALE' "$fw_bin"
    grep -q "T2793-SELFREPLACE-MARKER-STALE" "$fw_bin"

    run env -i PATH="/usr/local/bin:/usr/bin:/bin" HOME="$TEST_TEMP_DIR/home" "$fw_bin" upgrade "$proj"
    [ "$status" -eq 0 ]

    # The file the process executed from must now be different (marker gone)
    # AND still be a valid, runnable script (rename-over-open-fd did not
    # leave a truncated/corrupt file).
    if grep -q "T2793-SELFREPLACE-MARKER-STALE" "$fw_bin"; then false; fi
    run env -i PATH="/usr/local/bin:/usr/bin:/bin" HOME="$TEST_TEMP_DIR/home" bash -c "cd '$proj' && '$fw_bin' --version"
    [ "$status" -eq 0 ]
    [[ "$output" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]
    [[ "$output" == *"$proj/.agentic-framework"* ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# T-2793 — total isolation: the version a consumer reports, and whether it works
# at all without a global install.
#
# These use `fw init` (the real do_vendor path a consumer is actually built by)
# rather than make_fresh_consumer's git clone, because the two produce different
# artefacts: a clone carries .git, so _derive_version answers from git describe;
# a vendored copy has none, so VERSION is the only statement of which framework
# is running — which is exactly what T-2793 makes load-bearing.
# ─────────────────────────────────────────────────────────────────────────────

# Build a consumer the way a user does: `fw init` in an empty git repo.
make_vendored_consumer() {
    local proj="$1"
    mkdir -p "$proj"
    git init -q "$proj"
    (cd "$proj" && "$FRAMEWORK_ROOT/bin/fw" init . --provider claude >/dev/null 2>&1)
}

@test "T-2793: vendored consumer agrees with itself about its version" {
    local proj="$TEST_TEMP_DIR/vproj"
    make_vendored_consumer "$proj"
    [ -x "$proj/.agentic-framework/bin/fw" ]

    local reported pinned vfile
    reported="$(fresh_run "$proj" --version | head -1 | sed 's/^fw v//')"
    pinned="$(grep -m1 '^version:' "$proj/.framework.yaml" | awk '{print $2}')"
    vfile="$(tr -d '\n' < "$proj/.agentic-framework/VERSION")"

    # Non-empty first: three empty strings compare equal, and an equality test
    # that passes on nothing is the vacuous-pass class this suite exists to catch.
    [ -n "$reported" ]; [ -n "$pinned" ]; [ -n "$vfile" ]
    [[ "$reported" =~ ^[0-9]+\.[0-9]+\. ]]

    # The split brain printed two true lines that disagreed. Three sources, one
    # answer, or the consumer cannot say what it is running.
    [ "$reported" = "$pinned" ] || { echo "fw --version=$reported .framework.yaml=$pinned"; false; }
    [ "$reported" = "$vfile" ]  || { echo "fw --version=$reported VERSION=$vfile";  false; }
}

@test "T-2793: the router reaches the consumer's own CLI with no global install" {
    local proj="$TEST_TEMP_DIR/vproj2"
    make_vendored_consumer "$proj"
    mkdir -p "$TEST_TEMP_DIR/home2/.local/bin"
    cp "$FRAMEWORK_ROOT/bin/fw-router" "$TEST_TEMP_DIR/home2/.local/bin/fw"
    chmod +x "$TEST_TEMP_DIR/home2/.local/bin/fw"
    # HOME has NO .agentic-framework — `rm -rf ~/.agentic-framework` is what
    # fw doctor already recommends, and it must not break any vendored project.
    [ ! -d "$TEST_TEMP_DIR/home2/.agentic-framework" ]

    # Deep subdirectory, so the walk-up is doing real work.
    mkdir -p "$proj/src/nested"
    run bash -c "cd '$proj/src/nested' && env -i \
        PATH='$TEST_TEMP_DIR/home2/.local/bin:/usr/local/bin:/usr/bin:/bin' \
        HOME='$TEST_TEMP_DIR/home2' fw --version"
    [ "$status" -eq 0 ]
    local vfile
    vfile="$(tr -d '\n' < "$proj/.agentic-framework/VERSION")"
    [[ "$output" == *"$vfile"* ]] || { echo "expected $vfile, got: $output"; false; }
    # And it must be THIS project's framework, not something found elsewhere.
    [[ "$output" == *"$proj/.agentic-framework"* ]]
}

@test "T-2793: the router ignores a STALE global install when the project has its own" {
    # Dual to the "absent" case above: here $HOME/.agentic-framework EXISTS
    # but is a different (older/mismatched) version. The walk-up finds the
    # project's own vendored copy first and must never fall through to the
    # global one, stale or not.
    local proj="$TEST_TEMP_DIR/vproj3"
    make_vendored_consumer "$proj"
    mkdir -p "$TEST_TEMP_DIR/home3/.local/bin"
    cp "$FRAMEWORK_ROOT/bin/fw-router" "$TEST_TEMP_DIR/home3/.local/bin/fw"
    chmod +x "$TEST_TEMP_DIR/home3/.local/bin/fw"

    # A stale global install: same shape as a vendored project, deliberately
    # stamped with a VERSION that cannot collide with the real one.
    mkdir -p "$TEST_TEMP_DIR/home3/.agentic-framework/bin"
    cp "$FRAMEWORK_ROOT/bin/fw-router" "$TEST_TEMP_DIR/home3/.agentic-framework/bin/fw-router"
    printf '0.0.1-stale\n' > "$TEST_TEMP_DIR/home3/.agentic-framework/VERSION"
    cat > "$TEST_TEMP_DIR/home3/.agentic-framework/bin/fw" <<'SCRIPT'
#!/bin/bash
echo "fw v0.0.1-stale (WRONG — this is the stale global install, not the project's)"
exit 0
SCRIPT
    chmod +x "$TEST_TEMP_DIR/home3/.agentic-framework/bin/fw"

    mkdir -p "$proj/src/nested"
    run bash -c "cd '$proj/src/nested' && env -i \
        PATH='$TEST_TEMP_DIR/home3/.local/bin:/usr/local/bin:/usr/bin:/bin' \
        HOME='$TEST_TEMP_DIR/home3' fw --version"
    [ "$status" -eq 0 ]
    local vfile
    vfile="$(tr -d '\n' < "$proj/.agentic-framework/VERSION")"
    [[ "$output" == *"$vfile"* ]] || { echo "expected $vfile, got: $output"; false; }
    [[ "$output" != *"stale"* ]] || { echo "router fell through to the stale global install: $output"; false; }
    [[ "$output" == *"$proj/.agentic-framework"* ]]
}
