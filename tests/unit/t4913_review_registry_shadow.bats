#!/usr/bin/env bats
# T-4913 (dimitri-mint-dev msgs 400f6ed2, 405be7ae): a project-level
# policy/review-backends.yaml replaces the framework registry whole. Their 1.8.3 copy
# kept a retired model pin and had none of the T-4437 isolation blocks, so review seats
# ran unisolated for weeks while nothing said so. Now `fw review registry-shadow` names
# what such a copy lacks (isolation first), fw doctor WARNs, and the retired-pin message
# names the registry actually loaded.

setup() {
    FW_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    P="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$P/policy"
}

_shadow() {
    run env PROJECT_ROOT="$P" FRAMEWORK_ROOT="$FW_ROOT" python3 "$FW_ROOT/lib/review_cost.py" registry-shadow
}

@test "no project copy: OK, exit 0" {
    _shadow
    [ "$status" -eq 0 ]
    [[ "$output" == OK* ]]
}

@test "the framework repo itself (project == framework file) is not a shadow" {
    run env PROJECT_ROOT="$FW_ROOT" FRAMEWORK_ROOT="$FW_ROOT" python3 "$FW_ROOT/lib/review_cost.py" registry-shadow
    [ "$status" -eq 0 ]
}

@test "an identical copy is reported as a shadow with nothing missing" {
    cp "$FW_ROOT/policy/review-backends.yaml" "$P/policy/"
    _shadow
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "^SHADOW	project registry $P/policy/review-backends.yaml replaces"
    ! echo "$output" | grep -q "^MISSING" || false
}

@test "a stale copy: missing isolation blocks listed first, then a missing backend" {
    python3 - "$FW_ROOT/policy/review-backends.yaml" "$P/policy/review-backends.yaml" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
for b in d["backends"]:
    b.pop("isolation", None)
d["backends"] = [b for b in d["backends"] if b["id"] != "antigravity"]
yaml.safe_dump(d, open(sys.argv[2], "w"), sort_keys=False)
PY
    _shadow
    [ "$status" -eq 1 ]
    echo "$output" | sed -n 2p | grep -q "^MISSING	isolation block (T-4437, review seats run unisolated): .*opencode"
    echo "$output" | grep -q "^MISSING	backends: antigravity"
}

@test "fw doctor WARNs on a shadowing registry (wiring)" {
    grep -q 'review_cost.py" registry-shadow' "$FW_ROOT/bin/fw"
    grep -q 'review registry shadowed by a project copy (T-4913)' "$FW_ROOT/bin/fw"
    # Outside the --quick guard: the line after the litellm/ollama guard's end opens it.
    grep -A1 'end --quick guard for litellm/ollama curls' "$FW_ROOT/bin/fw" | grep -q 'T-4913'
}

@test "the retired-pin message names the absolute path of the registry loaded" {
    cp "$FW_ROOT/policy/review-backends.yaml" "$P/policy/"
    run env PROJECT_ROOT="$P" FRAMEWORK_ROOT="$FW_ROOT" python3 - "$FW_ROOT/lib" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import review_model_preflight as m
b = [{"id": "opencode", "worker_kind": "opencode", "model": "zai-coding-plan/glm-5.2",
      "harness": "opencode"}]
r = m.check(b, lister=lambda binary, prov: (0, "zai-coding-plan/glm-5.3\n"),
            which=lambda _b: "/usr/bin/opencode")
print(r[0]["status"], r[0]["detail"])
PY
    [ "$status" -eq 0 ]
    [[ "$output" == retired* ]]
    [[ "$output" == *"re-pin it in $P/policy/review-backends.yaml"* ]]
}
