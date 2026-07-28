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
# check-block logic against a synthetic tree — full audit.sh per-test is
# slow + flaky. A drift-tripwire test pins the inline replica's regex to the
# string in agents/audit/audit.sh so the two cannot silently diverge.

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

# Inline replica of the audit.sh check block (drift-pinned by the last test).
run_check() {
    local PROJECT_ROOT="$SYNTH_ROOT"
    local splitroot_violations=0
    local splitroot_evidence=""
    local splitroot_pattern='PROJECT_ROOT[[:space:]]*/[[:space:]]*["'\''](lib|agents|policy|bin|web)["'\'']'
    local scan_dir hit
    for scan_dir in web lib; do
        [ -d "$PROJECT_ROOT/$scan_dir" ] || continue
        while IFS= read -r hit; do
            [ -z "$hit" ] && continue
            case "$hit" in
                *value-drivers.yaml*|*bvp-scoring-rubric.md*) continue ;;
                *OBS-097-allow:*) continue ;;
                *tests/*|*docs/*) continue ;;
            esac
            splitroot_violations=$((splitroot_violations + 1))
            splitroot_evidence="$splitroot_evidence$hit"$'\n'
        done < <(grep -RnE "$splitroot_pattern" --include='*.py' \
                       "$PROJECT_ROOT/$scan_dir" 2>/dev/null || true)
    done
    if [ "$splitroot_violations" -eq 0 ]; then
        echo "PASS"
    else
        echo "FAIL $splitroot_violations"
        printf '%s' "$splitroot_evidence" | head -5
    fi
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

@test "drift tripwire: audit.sh carries the same pattern core as this replica" {
    # The source file holds the shell-escaped form of the regex, so pin the
    # two invariant cores that define the check: the resolution prefix and
    # the framework-owned dir alternation. If either changes in audit.sh,
    # update the replica in run_check above in the same commit.
    grep -qF 'PROJECT_ROOT[[:space:]]*/[[:space:]]*' "$REPO_ROOT/agents/audit/audit.sh"
    grep -qF '(lib|agents|policy|bin|web)' "$REPO_ROOT/agents/audit/audit.sh"
    # And the semantic allowlist entries exist in the audit.sh check block.
    grep -qF '*value-drivers.yaml*|*bvp-scoring-rubric.md*' "$REPO_ROOT/agents/audit/audit.sh"
    grep -qF '*OBS-097-allow:*' "$REPO_ROOT/agents/audit/audit.sh"
}
