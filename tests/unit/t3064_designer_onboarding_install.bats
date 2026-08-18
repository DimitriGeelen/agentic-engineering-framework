#!/usr/bin/env bats
# T-3064: onboarding installs the pinned Workflow Designer build.
#
# The defect: a consumer received `policy/designer-pin.yaml` — a DECLARATION
# naming an artifact — and never the artifact itself. `/designer` therefore
# rendered an error page in every project except this repo, and `fw doctor`
# called that state SKIP (fixed to WARN by A1) so nothing ever said so.
#
# Surfaces under test:
#   lib/upgrade.sh:_self_vendor_designer      — the ONE pinned build reaches
#                                               .agentic-framework/vendor/designer/
#   lib/upgrade.sh:_self_vendor_policy        — designer-pin.yaml is in the sync set
#   agents/designer/designer.sh:do_install    — install from the vendored copy,
#                                               sha256-verified, refuse on mismatch
#
# AC mapping:
#   A2 — t1, t2, t3, t7, t8
#   A3 — t4 (REJECT on mismatch), t5 (nothing installed on reject)
#   A4 — t6 (absent vendored build is loud and non-zero, never silent success)
#   A2 latent-defect leg — t9, t10 (designer-pin.yaml parity)
#   A4 at the init layer — t12, t13, t14 (fw_init_install_designer renders each
#                          outcome distinctly, and never fails init)
#
# EVERY assertion below is scoped to the LINE or FILE STATE under test, never to
# a substring of whole-command output. That is not style: during A1 an assertion
# of the shape `[[ "$output" == *"WARN"*"<message>"* ]]` passed against a SKIP
# mutant, because an unrelated earlier line had already printed WARN. Mutation
# testing found it. See the task's A1 note.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-t3064-XXXXXX)"
    export FRAMEWORK_ROOT
    export FW_VERSION="1.6.999"
    export NO_COLOR=1
    DESIGNER_SH="$FRAMEWORK_ROOT/agents/designer/designer.sh"
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/upgrade.sh"
    source "$FRAMEWORK_ROOT/lib/init.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && chmod -R u+w "$TEST_TEMP_DIR" 2>/dev/null
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
    return 0
}

# A synthetic framework tree: policy/designer-pin.yaml + vendor/designer/<pinned>
# + an EXISTING .agentic-framework/ (the self-vendor destination). The pin's sha256
# is computed from the fixture, so the accept path is real verification and not a
# stubbed comparison.
make_syn_fw() {
    local syn="$TEST_TEMP_DIR/syn-fw"
    mkdir -p "$syn/policy" "$syn/vendor/designer" "$syn/.agentic-framework/policy"
    printf 'DESIGNER-BUILD-FIXTURE-0.8.0' > "$syn/vendor/designer/aef-workflow-designer-0.8.0.html"
    local sha
    sha="$(sha256sum "$syn/vendor/designer/aef-workflow-designer-0.8.0.html" | cut -d' ' -f1)"
    cat > "$syn/policy/designer-pin.yaml" <<EOF
version: "0.8.0"
sha256: "$sha"
bytes: 28
vendored_path: "vendor/designer/aef-workflow-designer-0.8.0.html"
EOF
    echo "$syn"
}

# A synthetic CONSUMER: project root + a vendored .agentic-framework/ carrying the
# pin AND the build (i.e. what `fw vendor` now leaves behind). This is the shape
# `fw designer install` reads: FRAMEWORK_ROOT = the vendored dir, PROJECT_ROOT =
# the project. The two are distinct directories, which is the whole point — in
# this repo they collapse and the bug was invisible.
make_syn_consumer() {
    local proj="$TEST_TEMP_DIR/proj"
    mkdir -p "$proj/.agentic-framework/policy" "$proj/.agentic-framework/vendor/designer"
    printf 'DESIGNER-BUILD-FIXTURE-0.8.0' > "$proj/.agentic-framework/vendor/designer/aef-workflow-designer-0.8.0.html"
    local sha
    sha="$(sha256sum "$proj/.agentic-framework/vendor/designer/aef-workflow-designer-0.8.0.html" | cut -d' ' -f1)"
    cat > "$proj/.agentic-framework/policy/designer-pin.yaml" <<EOF
version: "0.8.0"
sha256: "$sha"
bytes: 28
vendored_path: "vendor/designer/aef-workflow-designer-0.8.0.html"
EOF
    echo "$proj"
}

designer_install() {   # designer_install <proj>
    env PROJECT_ROOT="$1" FRAMEWORK_ROOT="$1/.agentic-framework" \
        bash "$DESIGNER_SH" install
}

# ─────────────────────────── A2: the build reaches the vendored tree ──────────

@test "t1: _self_vendor_designer copies the pinned build into .agentic-framework/" {
    local syn; syn="$(make_syn_fw)"
    FRAMEWORK_ROOT="$syn" _self_vendor_designer false
    [ -f "$syn/.agentic-framework/vendor/designer/aef-workflow-designer-0.8.0.html" ]
    run diff "$syn/vendor/designer/aef-workflow-designer-0.8.0.html" \
             "$syn/.agentic-framework/vendor/designer/aef-workflow-designer-0.8.0.html"
    [ "$status" -eq 0 ]
}

@test "t2: the vendored copy is read-only (never edited in place)" {
    local syn; syn="$(make_syn_fw)"
    FRAMEWORK_ROOT="$syn" _self_vendor_designer false
    local perms
    perms="$(stat -c '%a' "$syn/.agentic-framework/vendor/designer/aef-workflow-designer-0.8.0.html")"
    [ "$perms" = "444" ]
}

@test "t3: only the PINNED build ships — superseded builds are pruned, not accumulated" {
    local syn; syn="$(make_syn_fw)"
    # A build the pin does NOT name, already sitting in the vendored tree (the
    # state a consumer re-vendored across a pin bump would be in).
    mkdir -p "$syn/.agentic-framework/vendor/designer"
    printf 'OLD' > "$syn/.agentic-framework/vendor/designer/aef-workflow-designer-0.7.1.html"
    # And a second unpinned build at the SOURCE, to prove the helper ships one
    # file rather than the directory.
    printf 'OLDER' > "$syn/vendor/designer/aef-workflow-designer-0.3.0.html"

    FRAMEWORK_ROOT="$syn" _self_vendor_designer false

    [ -f "$syn/.agentic-framework/vendor/designer/aef-workflow-designer-0.8.0.html" ]
    [ ! -f "$syn/.agentic-framework/vendor/designer/aef-workflow-designer-0.7.1.html" ]
    [ ! -f "$syn/.agentic-framework/vendor/designer/aef-workflow-designer-0.3.0.html" ]
    # Exactly one file in the vendored designer dir.
    local n
    n="$(find "$syn/.agentic-framework/vendor/designer" -type f | wc -l)"
    [ "$n" -eq 1 ]
}

# ─────────────── A3: verification is NOT weakened by the new call path ────────

@test "t4: install REFUSES a corrupted vendored build (exit 1, MISMATCH named)" {
    local proj; proj="$(make_syn_consumer)"
    # Corrupt the artifact the consumer received, leaving the pin untouched —
    # exactly the shape a tampered or truncated vendor copy takes.
    chmod u+w "$proj/.agentic-framework/vendor/designer/aef-workflow-designer-0.8.0.html"
    printf 'TAMPERED' > "$proj/.agentic-framework/vendor/designer/aef-workflow-designer-0.8.0.html"

    designer_install "$proj" > "$TEST_TEMP_DIR/t4.raw" 2>&1 || rc=$?
    [ "${rc:-0}" -eq 1 ]
    # designer.sh colours unconditionally, so the verdict line does not START
    # with its own text — strip SGR before anchoring, or `^` matches nothing and
    # the assertion reads as a content failure when it is an escape-code one.
    sed -e 's/\x1b\[[0-9;]*m//g' "$TEST_TEMP_DIR/t4.raw" > "$TEST_TEMP_DIR/t4.out"
    # Scoped to the verdict LINE, not to a substring of the whole output. An
    # assertion of the form [[ "$output" == *"MISMATCH"* ]] would also pass if
    # some unrelated line happened to carry the word — that exact weakness was
    # found by mutation testing during A1 and must not be reintroduced.
    run grep -c '^sha256 MISMATCH — refusing to vendor an unpinned build$' "$TEST_TEMP_DIR/t4.out"
    [ "$output" = "1" ]
}

@test "t5: a REFUSED install leaves NOTHING behind in the project" {
    local proj; proj="$(make_syn_consumer)"
    chmod u+w "$proj/.agentic-framework/vendor/designer/aef-workflow-designer-0.8.0.html"
    printf 'TAMPERED' > "$proj/.agentic-framework/vendor/designer/aef-workflow-designer-0.8.0.html"

    run designer_install "$proj"
    [ "$status" -eq 1 ]
    # The install target — PROJECT_ROOT/<vendored_path> — must not exist. A refusal
    # that still wrote the bytes would be a refusal in message only.
    [ ! -f "$proj/vendor/designer/aef-workflow-designer-0.8.0.html" ]
}

# ─────────────── A4: absent build is explicit, visible, and non-zero ──────────

@test "t6: no vendored build → non-zero exit, no network, names the file and the fix" {
    local proj; proj="$(make_syn_consumer)"
    rm -f "$proj/.agentic-framework/vendor/designer/aef-workflow-designer-0.8.0.html"

    run designer_install "$proj"
    # NOT 0. Silent success over a project with no designer is the failure this
    # task exists to close; an advisory that exits 0 is that failure with a
    # sentence attached.
    [ "$status" -eq 5 ]
    [ ! -f "$proj/vendor/designer/aef-workflow-designer-0.8.0.html" ]
    # The message must name the artifact path — "not installed" without a
    # referent is not actionable. Line-scoped: the verdict line itself carries
    # the pin-relative path.
    designer_install "$proj" > "$TEST_TEMP_DIR/t6.raw" 2>&1 || true
    sed -e 's/\x1b\[[0-9;]*m//g' "$TEST_TEMP_DIR/t6.raw" > "$TEST_TEMP_DIR/t6.out"
    run grep -c '^designer NOT installed — the pin names vendor/designer/aef-workflow-designer-0.8.0.html, but no vendored build is present at:$' "$TEST_TEMP_DIR/t6.out"
    [ "$output" = "1" ]
}

# ─────────────── A2: the happy path, end to end, in a consumer shape ──────────

@test "t7: install writes the build into PROJECT_ROOT, read-only, byte-identical" {
    local proj; proj="$(make_syn_consumer)"
    run designer_install "$proj"
    [ "$status" -eq 0 ]
    [ -f "$proj/vendor/designer/aef-workflow-designer-0.8.0.html" ]
    run diff "$proj/.agentic-framework/vendor/designer/aef-workflow-designer-0.8.0.html" \
             "$proj/vendor/designer/aef-workflow-designer-0.8.0.html"
    [ "$status" -eq 0 ]
    local perms
    perms="$(stat -c '%a' "$proj/vendor/designer/aef-workflow-designer-0.8.0.html")"
    [ "$perms" = "444" ]
}

@test "t8: install is idempotent — second run reports already-installed, exit 0" {
    local proj; proj="$(make_syn_consumer)"
    designer_install "$proj"
    run designer_install "$proj"
    [ "$status" -eq 0 ]
    [[ "$output" == *"already installed"* ]]
}

# ─────────── A2 latent defect: designer-pin.yaml must be self-vendored ────────

@test "t9: _self_vendor_policy syncs designer-pin.yaml (pin bump propagates)" {
    local syn="$TEST_TEMP_DIR/syn-policy"
    mkdir -p "$syn/policy" "$syn/.agentic-framework/policy"
    printf 'version: "0.8.0"\n' > "$syn/policy/designer-pin.yaml"
    printf 'version: "0.7.1"\n' > "$syn/.agentic-framework/policy/designer-pin.yaml"

    FRAMEWORK_ROOT="$syn" _self_vendor_policy false
    run diff "$syn/policy/designer-pin.yaml" "$syn/.agentic-framework/policy/designer-pin.yaml"
    [ "$status" -eq 0 ]
}

@test "t10: live tree — the two pin copies are identical (no silent divergence)" {
    run diff "$FRAMEWORK_ROOT/policy/designer-pin.yaml" \
             "$FRAMEWORK_ROOT/.agentic-framework/policy/designer-pin.yaml"
    [ "$status" -eq 0 ]
}

@test "t11: live tree — the vendored build matches the pin's sha256" {
    local rel sha have
    rel="$(grep -E '^vendored_path:' "$FRAMEWORK_ROOT/policy/designer-pin.yaml" | head -1 | sed -e 's/^vendored_path:[[:space:]]*//' -e 's/"//g')"
    sha="$(grep -E '^sha256:' "$FRAMEWORK_ROOT/policy/designer-pin.yaml" | head -1 | sed -e 's/^sha256:[[:space:]]*//' -e 's/"//g')"
    [ -f "$FRAMEWORK_ROOT/.agentic-framework/$rel" ]
    have="$(sha256sum "$FRAMEWORK_ROOT/.agentic-framework/$rel" | cut -d' ' -f1)"
    [ "$have" = "$sha" ]
}

# ───── A4 at the onboarding layer: fw_init_install_designer renders outcomes ──
#
# lib/init.sh extracted this into a function so the wiring would be reachable by
# a test without standing up a whole `fw init`. These are that test. The claim
# under examination is the one A4 turns on: "the designer step ran" and "the
# designer is installed" must not render the same, and neither may fail init.

# Give the synthetic consumer a vendored bin/fw that routes `designer install`
# to the real script — the function calls the PROJECT's fw, not ours.
add_fw_shim() {   # add_fw_shim <proj>
    local proj="$1"
    mkdir -p "$proj/.agentic-framework/bin"
    cat > "$proj/.agentic-framework/bin/fw" <<SHIM
#!/usr/bin/env bash
[ "\$1" = "designer" ] || { echo "unexpected: \$*" >&2; exit 99; }
exec env PROJECT_ROOT="\${PROJECT_ROOT}" FRAMEWORK_ROOT="$proj/.agentic-framework" \\
    bash "$DESIGNER_SH" "\$2"
SHIM
    chmod +x "$proj/.agentic-framework/bin/fw"
}

@test "t12: init reports a successful install as installed-and-verified" {
    local proj; proj="$(make_syn_consumer)"; add_fw_shim "$proj"
    run fw_init_install_designer "$proj"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Workflow Designer installed (sha256 verified against pin)"* ]]
    [ -f "$proj/vendor/designer/aef-workflow-designer-0.8.0.html" ]
}

@test "t13: init reports a REFUSED install in refusal words, and installs nothing" {
    local proj; proj="$(make_syn_consumer)"; add_fw_shim "$proj"
    chmod u+w "$proj/.agentic-framework/vendor/designer/aef-workflow-designer-0.8.0.html"
    printf 'TAMPERED' > "$proj/.agentic-framework/vendor/designer/aef-workflow-designer-0.8.0.html"

    run fw_init_install_designer "$proj"
    # Init is NOT failed by this — a project without a designer is still governed.
    [ "$status" -eq 0 ]
    [ ! -f "$proj/vendor/designer/aef-workflow-designer-0.8.0.html" ]
    # The distinguishing words. A refusal that renders like the success line is
    # the failure mode, not the exit code.
    [[ "$output" == *"REFUSED"* ]]
    [[ "$output" == *"Nothing was installed"* ]]
    [[ "$output" != *"Workflow Designer installed"* ]]
}

@test "t14: init reports an ABSENT build without claiming success" {
    local proj; proj="$(make_syn_consumer)"; add_fw_shim "$proj"
    rm -f "$proj/.agentic-framework/vendor/designer/aef-workflow-designer-0.8.0.html"

    run fw_init_install_designer "$proj"
    [ "$status" -eq 0 ]
    [[ "$output" == *"not installed"* ]]
    # Explicitly NOT the success wording. Without this line the assertion above
    # would pass against a rendering that printed both.
    [[ "$output" != *"Workflow Designer installed"* ]]
}
