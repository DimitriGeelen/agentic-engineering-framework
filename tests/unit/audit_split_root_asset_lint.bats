#!/usr/bin/env bats
# T-2648 (OBS-097, 832's G-004 class): pin the split-root asset-resolution
# audit lint.
#
# The check forbids PROJECT_ROOT-resolution of framework-owned asset dirs
# (lib/ agents/ policy/ bin/ web/) in Python under web/ and lib/ — the class
# that shipped a dead /review queue to a split-root consumer (T-2645, 832
# rail 253). Semantic allowlist: the two per-project policy INSTANCE files
# (value-drivers.yaml, bvp-scoring-rubric.md — T-2229 --init model) are
# legitimate PROJECT_ROOT reads.
#
# Strategy (same as audit_ctl_arc_tag_only_pattern.bats): exercise only the
# check block, extracted from agents/audit/audit.sh, against a synthetic tree —
# full audit.sh per-test is slow + flaky.

setup() {
    SYNTH_ROOT="$(mktemp -d)"
    mkdir -p "$SYNTH_ROOT/web/blueprints" "$SYNTH_ROOT/lib" \
             "$SYNTH_ROOT/agents/foo" "$SYNTH_ROOT/tests/unit"
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export SYNTH_ROOT REPO_ROOT
}

teardown() {
    [ -n "${SYNTH_ROOT:-}" ] && [ -d "$SYNTH_ROOT" ] && rm -rf "$SYNTH_ROOT"
}

# Run the SHIPPED check block against the synthetic tree. T-4380: the block is cut
# out of agents/audit/audit.sh (from its first assignment to the next check's
# header comment); this file used to carry an inline replica, which stayed green
# when the shipped violation counter was disabled. A moved or renamed block fails
# loudly instead of yielding an empty script that "passes".
run_check() {
    local block="$SYNTH_ROOT/.splitroot-block.sh"
    awk '/^splitroot_violations=0$/{f=1} /^# T-1975 \(L-417 prevention\)/{f=0} f' \
        "$REPO_ROOT/agents/audit/audit.sh" > "$block"
    [ -s "$block" ] || { echo "extraction empty - did the block move?" >&2; return 1; }
    grep -q 'OBS-097-allow' "$block" || { echo "extraction lost the allowlist" >&2; return 1; }
    PROJECT_ROOT="$SYNTH_ROOT" bash -c '
        pass_over() { echo "PASS"; }
        fail() { echo "FAIL $splitroot_violations"; printf "%b" "$2" | head -5; }
        source "$1"
    ' _ "$block"
}

@test "clean tree emits PASS" {
    cat > "$SYNTH_ROOT/web/blueprints/good.py" <<'EOF'
from web.shared import FRAMEWORK_ROOT, PROJECT_ROOT
PIN = FRAMEWORK_ROOT / "policy" / "pin.yaml"
STATE = PROJECT_ROOT / ".context" / "state.yaml"
EOF
    run run_check
    [ "$output" = "PASS" ]
}

@test "PROJECT_ROOT / 'lib' in web/ is flagged" {
    cat > "$SYNTH_ROOT/web/blueprints/bad.py" <<'EOF'
import sys
sys.path.insert(0, str(PROJECT_ROOT / "lib"))
EOF
    run run_check
    [[ "$output" == FAIL* ]]
    [[ "$output" == *"bad.py"* ]]
}

@test "PROJECT_ROOT / 'bin' subprocess path in lib/ is flagged" {
    cat > "$SYNTH_ROOT/lib/runner.py" <<'EOF'
FW = PROJECT_ROOT / "bin" / "fw"
EOF
    run run_check
    [[ "$output" == FAIL* ]]
    [[ "$output" == *"runner.py"* ]]
}

@test "single-quoted form and spacing variants are flagged" {
    cat > "$SYNTH_ROOT/lib/sq.py" <<'EOF'
POLICY = PROJECT_ROOT/'policy'/'other-framework-asset.yaml'
AGENTS = PROJECT_ROOT  /  "agents"
EOF
    run run_check
    [[ "$output" == "FAIL 2"* ]]
}

@test "allowlist: value-drivers.yaml and rubric reads pass (T-2229 per-project instances)" {
    cat > "$SYNTH_ROOT/web/blueprints/bvp_like.py" <<'EOF'
POLICY_PATH = PROJECT_ROOT / "policy" / "value-drivers.yaml"
RUBRIC_PATH = PROJECT_ROOT / "policy" / "bvp-scoring-rubric.md"
EOF
    run run_check
    [ "$output" = "PASS" ]
}

@test "allowlist suppresses ONLY its stated entries — other policy/ reads still flagged" {
    cat > "$SYNTH_ROOT/web/blueprints/mixed.py" <<'EOF'
POLICY_PATH = PROJECT_ROOT / "policy" / "value-drivers.yaml"
OTHER = PROJECT_ROOT / "policy" / "designer-pin.yaml"
EOF
    run run_check
    [[ "$output" == "FAIL 1"* ]]
    [[ "$output" == *"mixed.py"* ]]
    [[ "$output" == *"designer-pin"* ]]
}

@test "project-owned dirs (.context, .tasks, docs) are out of pattern scope" {
    cat > "$SYNTH_ROOT/web/blueprints/state.py" <<'EOF'
A = PROJECT_ROOT / ".context" / "x.yaml"
B = PROJECT_ROOT / ".tasks" / "active"
C = PROJECT_ROOT / "docs" / "reports"
EOF
    run run_check
    [ "$output" = "PASS" ]
}

@test "shell files are out of V1 scope (Python-only lint)" {
    cat > "$SYNTH_ROOT/lib/legacy.sh" <<'EOF'
PIN_FILE="$PROJECT_ROOT/policy/designer-pin.yaml"
EOF
    run run_check
    [ "$output" = "PASS" ]
}

@test "inline OBS-097-allow annotation exempts a site; unannotated sibling still flagged" {
    cat > "$SYNTH_ROOT/web/blueprints/annotated.py" <<'EOF'
agents_dir = PROJECT_ROOT / "agents"  # OBS-097-allow: end-to-end PROJECT_ROOT surface
other_dir = PROJECT_ROOT / "agents"
EOF
    run run_check
    [[ "$output" == "FAIL 1"* ]]
}

@test "shell-idiom ratchet (T-2649): PROJECT_ROOT framework-asset sites in shell stay at the reviewed baseline" {
    # T-2649 dispositioned all shell sites resolving framework-owned dirs via
    # $PROJECT_ROOT: 12 remain, each kept WITH a reason (framework-repo
    # detection guards, documented fallback chains, per-project policy
    # instances, documented design choices) — see T-2649 ## Decisions.
    # The `FRAMEWORK_ROOT:-` exclusion skips the sanctioned fallback shape.
    # If this count RISES: a new unreviewed site landed — fix it or disposition
    # it in a task and update this baseline in the same commit.
    # If it FALLS: a kept site was fixed/removed — just update the baseline.
    #
    # T-4484: baseline 12 -> 22. The 10 added since T-2649 are deliberate,
    # each an in-repo SOURCE read or framework-repo existence guard (never
    # resolved from a consumer's PROJECT_ROOT): T-2980 audit seed-ref check
    # (audit.sh x2), T-2433 sandbox profile (audit.sh x1, bin/fw x3 + $PROJECT_ROOT/
    # policy/sandbox-profile.d), designer-pin dz/dc + bvp scoring guard (bin/fw x2),
    # T-4449 template-sync pre-commit leg (hooks.sh x2). The test never ratcheted
    # them in, so it sat red until now.
    sites=$(grep -rnE '\$\{?PROJECT_ROOT\}?/(lib|agents|policy|web)/' \
                "$REPO_ROOT/agents/" "$REPO_ROOT/lib/" "$REPO_ROOT/bin/fw" 2>/dev/null \
            | grep -v ".agentic-framework" \
            | grep -v "FRAMEWORK_ROOT:-" || true)
    count=$(printf '%s\n' "$sites" | grep -c .)
    if [ "$count" -ne 22 ]; then
        echo "PROJECT_ROOT framework-asset sites: $count (baseline 22)" >&2
        printf '%s\n' "$sites" >&2
        false
    fi
}

@test "source pin: audit.sh carries the pattern core and the allowlist entries" {
    # The source file holds the shell-escaped form of the regex, so pin the
    # two invariant cores that define the check: the resolution prefix and
    # the framework-owned dir alternation. If either changes in audit.sh,
    # update the behavioural tests above in the same commit.
    grep -qF 'PROJECT_ROOT[[:space:]]*/[[:space:]]*' "$REPO_ROOT/agents/audit/audit.sh"
    grep -qF '(lib|agents|policy|bin|web)' "$REPO_ROOT/agents/audit/audit.sh"
    # And the semantic allowlist entries exist in the audit.sh check block.
    grep -qF '*value-drivers.yaml*|*bvp-scoring-rubric.md*' "$REPO_ROOT/agents/audit/audit.sh"
    grep -qF '*OBS-097-allow:*' "$REPO_ROOT/agents/audit/audit.sh"
}
