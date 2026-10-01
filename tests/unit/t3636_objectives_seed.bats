#!/usr/bin/env bats
load ../git_fence  # T-3610: git discovery must not escape a fixture into a repo above the temp dir
# T-3636 (T-3535 IW-3): every project authors .context/project/objectives.yaml ONCE,
# through its own entry point — greenfield T-002, existing-project T-007, or the
# one-time task `fw upgrade` seeds (lib/objectives-seed.sh). Never a copy of the
# framework's own objectives file (Directive 4).
#
# The end-to-end upgrade leg (vendored consumer, real file:// upstream) lives in
# tests/unit/upgrade_fresh_machine_simulation.bats.

load ../test_helper

SEEDS="$FRAMEWORK_ROOT/lib/seeds/tasks"
GREENFIELD="$SEEDS/greenfield/T-002-define-project-goals.md"
EXISTING="$SEEDS/existing-project/T-007-define-project-objectives.md"
UPGRADE="$SEEDS/upgrade/define-project-objectives.md"

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t t3636-XXXXXX)"
    # shellcheck source=lib/objectives-seed.sh
    source "$FRAMEWORK_ROOT/lib/objectives-seed.sh"
}

teardown() { rm -rf "$TEST_TEMP_DIR"; }

# Pull the ## Verification lines of a task file (non-comment, non-empty).
verification_lines() {
    awk '/^## Verification/{v=1;next} /^## /{v=0} v' "$1" | grep -vE '^\s*(#|$)'
}

write_good_objectives() {
    mkdir -p "$1/.context/project"
    cat > "$1/.context/project/objectives.yaml" <<'YAML'
# Project objectives — fixture.
#
# Authored intent; progress is derived, never written here.
headline: A fixture project for people who need one.
objectives:
  - id: O-1
    text: Something a user notices.
    measure: Not measured yet.
out_of_scope:
  - Everything else.
YAML
}

# ── The three authoring seeds carry the same outcome and the same shape ──────

@test "T-3636: all three authoring seeds name objectives.yaml and the T-3635 shape" {
    for f in "$GREENFIELD" "$EXISTING" "$UPGRADE"; do
        [ -f "$f" ]
        grep -q '\.context/project/objectives\.yaml' "$f"
        grep -qi 'authored intent; progress is derived' "$f"
        grep -q '^headline:' "$f"
        grep -q '^objectives:' "$f"
        grep -q 'measure:' "$f"
        grep -q '^out_of_scope:' "$f"
        # tagged so fw upgrade can tell an authoring task already exists
        head -20 "$f" | grep -qE '^tags:.*objectives-authoring'
    done
}

@test "T-3636: greenfield T-002 no longer delivers free prose in docs/reports" {
    ! verification_lines "$GREENFIELD" | grep -q 'docs/reports' || false
    verification_lines "$GREENFIELD" | grep -q 'objectives.yaml'
    # agent drafts, operator ratifies: still an inception owned by the human
    grep -q '^workflow_type: inception' "$GREENFIELD"
    grep -q '^owner: human' "$GREENFIELD"
    # P-01 IW-3 alignment: a file the installer already wrote is refined, not redrafted
    grep -qi 'already exists' "$GREENFIELD"
}

@test "T-3636: the seeds' verification passes on a well-shaped file and fails on a bad one" {
    local proj="$TEST_TEMP_DIR/p" line
    mkdir -p "$proj"
    write_good_objectives "$proj"
    while IFS= read -r line; do
        case "$line" in *Recommendation*) continue ;; esac   # T-002's own recommendation check
        (cd "$proj" && bash -c "set -o pipefail; $line")
    done < <(verification_lines "$EXISTING"; verification_lines "$GREENFIELD")

    # an objective with no measure must fail the shape check
    sed -i '/measure:/d' "$proj/.context/project/objectives.yaml"
    line=$(verification_lines "$EXISTING" | grep '^python3')
    run bash -c "cd '$proj' && $line"
    [ "$status" -ne 0 ]
}

@test "T-3636: existing-project T-007 passes the onboarding gate's write-time check" {
    # owner:agent onboarding tasks must be agent-resolvable (T-2815): no inception,
    # no unticked Human AC.
    grep -q '^owner: agent' "$EXISTING"
    ! grep -q '^workflow_type: inception' "$EXISTING" || false
    ! grep -q '^### Human' "$EXISTING" || false
    python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":sys.argv[1]+"/.tasks/active/T-007-define-project-objectives.md","content":open(sys.argv[2]).read()}}))' "$TEST_TEMP_DIR" "$EXISTING" > "$TEST_TEMP_DIR/payload.json"
    run bash -c "PROJECT_ROOT='$TEST_TEMP_DIR' python3 '$FRAMEWORK_ROOT/agents/context/check-onboarding-gate.py' < '$TEST_TEMP_DIR/payload.json'"
    echo "$output"
    [ "$status" -eq 0 ]
    # anti-vacuity: the same task with a Human AC added IS refused
    python3 -c 'import json,sys; c=open(sys.argv[2]).read().replace("## Verification","### Human\n- [ ] [REVIEW] x\n\n## Verification",1); print(json.dumps({"tool_name":"Write","tool_input":{"file_path":sys.argv[1]+"/.tasks/active/T-007-define-project-objectives.md","content":c}}))' "$TEST_TEMP_DIR" "$EXISTING" > "$TEST_TEMP_DIR/bad.json"
    run bash -c "PROJECT_ROOT='$TEST_TEMP_DIR' python3 '$FRAMEWORK_ROOT/agents/context/check-onboarding-gate.py' < '$TEST_TEMP_DIR/bad.json'"
    [ "$status" -eq 2 ]
}

@test "T-3636: fw init (existing project) seeds T-007 and no objectives file" {
    local proj="$TEST_TEMP_DIR/existing"
    mkdir -p "$proj/src"; echo 'print(1)' > "$proj/src/main.py"
    git init -q "$proj"
    (cd "$proj" && env -i PATH="/usr/local/bin:/usr/bin:/bin" HOME="$TEST_TEMP_DIR/home" \
        "$FRAMEWORK_ROOT/bin/fw" init . --provider claude >/dev/null 2>&1)
    [ -f "$proj/.tasks/active/T-007-define-project-objectives.md" ]
    ! grep -q '__PROJECT_NAME__' "$proj/.tasks/active/T-007-define-project-objectives.md" || false
    [ ! -f "$proj/.context/project/objectives.yaml" ]
    [ "$(fw_objectives_seed_status "$proj" | cut -d' ' -f1)" = "tasked" ]
}

# ── lib/objectives-seed.sh: the fw upgrade entry point ───────────────────────

@test "T-3636: status is needed / present / tasked" {
    local p="$TEST_TEMP_DIR/c"
    mkdir -p "$p/.tasks/active" "$p/.tasks/completed"
    [ "$(fw_objectives_seed_status "$p")" = "needed" ]

    printf -- '---\nid: T-004\ntags: [onboarding, objectives-authoring]\n---\n' > "$p/.tasks/completed/T-004-x.md"
    [[ "$(fw_objectives_seed_status "$p")" == "tasked "*T-004-x.md ]]
    rm "$p/.tasks/completed/T-004-x.md"

    # element-wise match: a lookalike tag is not the authoring tag
    printf -- '---\nid: T-004\ntags: [objectives-authoring-v2]\n---\n' > "$p/.tasks/active/T-004-x.md"
    [ "$(fw_objectives_seed_status "$p")" = "needed" ]

    write_good_objectives "$p"
    [ "$(fw_objectives_seed_status "$p")" = "present" ]
}

@test "T-3636: seeding writes one task with the next free id, then never again" {
    local p="$TEST_TEMP_DIR/c"
    mkdir -p "$p/.tasks/active" "$p/.tasks/completed"
    : > "$p/.tasks/completed/T-008-old.md"
    : > "$p/.tasks/active/T-011-current.md"
    : > "$p/.tasks/active/T-5000-quarantined.md"   # past the quarantine gap: ignored
    run fw_objectives_seed_task "$p" "$FRAMEWORK_ROOT" "demo"
    [ "$status" -eq 0 ]
    local t="$p/.tasks/active/T-012-define-project-objectives.md"
    [ "$output" = "$t" ]
    [ -f "$t" ]
    grep -q '^id: T-012$' "$t"
    ! grep -qE '__(TASK_ID|PROJECT_NAME|DATE)__' "$t" || false
    grep -q 'objectives of demo' "$t"

    run fw_objectives_seed_task "$p" "$FRAMEWORK_ROOT" "demo"
    [ "$status" -ne 0 ]
    [ "$(ls "$p"/.tasks/active/*define-project-objectives.md | wc -l)" -eq 1 ]
}

@test "T-3636: seeding refuses when the project already has its objectives file" {
    local p="$TEST_TEMP_DIR/c"
    mkdir -p "$p/.tasks/active"
    write_good_objectives "$p"
    run fw_objectives_seed_task "$p" "$FRAMEWORK_ROOT" "demo"
    [ "$status" -ne 0 ]
    [ -z "$(ls "$p"/.tasks/active/)" ]
}

@test "T-3636: the seeder never copies the framework's objectives file" {
    # Directive 4, statically: nothing in the seeder or upgrade step reads it.
    ! grep -nE 'cp .*objectives\.yaml|objectives\.yaml.*>' "$FRAMEWORK_ROOT/lib/objectives-seed.sh" || false
    local p="$TEST_TEMP_DIR/c"
    mkdir -p "$p/.tasks/active"
    fw_objectives_seed_task "$p" "$FRAMEWORK_ROOT" "demo" >/dev/null
    [ ! -e "$p/.context/project/objectives.yaml" ]
}

@test "T-3636: fw upgrade --dry-run reports the objectives task and writes nothing" {
    local p="$TEST_TEMP_DIR/up"
    mkdir -p "$p/.tasks/active" "$p/.context/project"
    git init -q "$p"
    printf 'project_name: up\nversion: 1.0.0\nprovider: claude\n' > "$p/.framework.yaml"
    run env -i PATH="/usr/local/bin:/usr/bin:/bin" HOME="$TEST_TEMP_DIR/home" \
        "$FRAMEWORK_ROOT/bin/fw" upgrade "$p" --dry-run
    [[ "$output" == *"WOULD SEED"*"objectives"* ]]
    [ -z "$(ls "$p/.tasks/active/")" ]
    [ ! -e "$p/.context/project/objectives.yaml" ]

    # with the file present, the step stays silent
    write_good_objectives "$p"
    run env -i PATH="/usr/local/bin:/usr/bin:/bin" HOME="$TEST_TEMP_DIR/home" \
        "$FRAMEWORK_ROOT/bin/fw" upgrade "$p" --dry-run
    [[ "$output" != *"objectives (.context/project/objectives.yaml)"* ]]
}
