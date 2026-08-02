#!/usr/bin/env bats
# T-2735 — "which watched source files have no fabric card?" must have exactly
# ONE answer in audit.sh, and it must be the canonical expander's.
#
# T-1842 extracted expand_patterns.py as the single source of truth for the
# glob + exclude predicate, after a parallel copy in register.sh / drift.sh
# produced 5946 junk cards undetected for ~22 days. It migrated those two
# callers. The two copies inside audit.sh were never migrated, so the surface
# that reports a coverage verdict to the operator was the one still globbing
# on its own.
#
# The copy at :1405 had three independent zeroing defects (no PROJECT_ROOT
# join, no recursive=True, no exclude) and reported through two pass() arms,
# so no value it produced could recruit attention. It printed
# "938 registered, 0 unregistered" beside "drift: 1 source file has no card"
# for 14 days. Green agreeing with green is not agreement.
#
# These tests assert the property (one answer, canonical, CWD-independent),
# not the current numbers.

load ../test_helper

EXPANDER="agents/fabric/lib/expand_patterns.py"

_watchfile() {
    # A watch file exercising both the ** recursion and the exclude: key —
    # the two features the removed copies did not implement.
    cat > "$1" <<'EOF'
patterns:
  - glob: "src/**/*.py"
    expected_type: script
  - glob: "web/*.html"
    expected_type: template
    exclude: ["web/_*.html"]
EOF
}

_fixture() {
    local d="$1"
    mkdir -p "$d/src/a/b" "$d/web" "$d/.fabric/components"
    : > "$d/src/top.py"
    : > "$d/src/a/mid.py"
    : > "$d/src/a/b/deep.py"        # only reachable with recursive=True
    : > "$d/web/page.html"
    : > "$d/web/_partial.html"      # only excluded if exclude: is honoured
    _watchfile "$d/.fabric/watch-patterns.yaml"
}

@test "T-2735 fixture control: the fixture actually exercises ** and exclude" {
    # Standing control. If the fixture stops containing a deep file or an
    # excluded file, every discrimination below silently becomes vacuous —
    # the shape that produced two false greens in T-2732.
    _fixture "$TEST_TEMP_DIR/p"
    [ -f "$TEST_TEMP_DIR/p/src/a/b/deep.py" ]
    [ -f "$TEST_TEMP_DIR/p/web/_partial.html" ]
    run grep -c "glob:" "$TEST_TEMP_DIR/p/.fabric/watch-patterns.yaml"
    [ "$output" -eq 2 ]
}

@test "T-2735: audit.sh holds no private glob over watch-patterns" {
    # Source-derived shape guard, no filename allowlist (L-533). Matches the
    # act of globbing a pattern read out of the watch file, however spelled.
    local hits
    hits="$(grep -nE "glob\.glob\([^)]*p\['glob'\]|glob\.glob\(os\.path\.join\(PROJECT_ROOT, g\)" \
        "$FRAMEWORK_ROOT/agents/audit/audit.sh" || true)"
    [ -z "$hits" ] || {
        echo "audit.sh globs watch-patterns directly instead of using the expander:" >&2
        echo "$hits" >&2
        false
    }
}

@test "T-2735 guard control: the shape guard catches a reintroduced glob" {
    # Red is not evidence; red-for-the-stated-reason is. Append a violation to
    # a COPY and require the guard to see it.
    local copy="$TEST_TEMP_DIR/regressed.sh"
    cp "$FRAMEWORK_ROOT/agents/audit/audit.sh" "$copy"
    printf "\n# reintroduced\nfor match in glob.glob(p['glob']):\n    pass\n" >> "$copy"
    run bash -c "grep -nE \"glob\.glob\([^)]*p\['glob'\]|glob\.glob\(os\.path\.join\(PROJECT_ROOT, g\)\" '$copy' || true"
    [ -n "$output" ]
}

@test "T-2735: audit.sh routes coverage through the canonical expander" {
    # Assert the CALL, not a mention. The first version of this test grepped
    # for the bare string "expand_patterns.py" and stayed green through the
    # negative control — because the explanatory comment in the other fabric
    # block names the expander too. A test satisfied by its own documentation
    # is the defect this task is about, one level up.
    local blk
    blk="$(sed -n '/^# Fabric drift: check for unregistered source files/,/^DRIFTEOF/p' \
        "$FRAMEWORK_ROOT/agents/audit/audit.sh")"
    [ -n "$blk" ]
    echo "$blk" | grep -q "subprocess.run("
    echo "$blk" | grep -q '"expand_patterns.py")'
}

@test "T-2735: the expander recurses into ** (the defect that hid 33 files)" {
    _fixture "$TEST_TEMP_DIR/p"
    run python3 "$FRAMEWORK_ROOT/$EXPANDER" \
        "$TEST_TEMP_DIR/p/.fabric/watch-patterns.yaml" "$TEST_TEMP_DIR/p"
    [ "$status" -eq 0 ]
    [[ "$output" == *"src/a/b/deep.py"* ]]
}

@test "T-2735: the expander honours exclude: (dropped by the removed copy)" {
    _fixture "$TEST_TEMP_DIR/p"
    run python3 "$FRAMEWORK_ROOT/$EXPANDER" \
        "$TEST_TEMP_DIR/p/.fabric/watch-patterns.yaml" "$TEST_TEMP_DIR/p"
    [ "$status" -eq 0 ]
    [[ "$output" == *"web/page.html"* ]]
    [[ "$output" != *"web/_partial.html"* ]]
}

@test "T-2735: coverage is CWD-independent" {
    # The removed copy globbed relative paths, so its input set was empty from
    # anywhere but the project root — structurally zero, and silent about it.
    _fixture "$TEST_TEMP_DIR/p"
    local from_root from_elsewhere
    from_root="$(cd "$TEST_TEMP_DIR/p" && python3 "$FRAMEWORK_ROOT/$EXPANDER" \
        .fabric/watch-patterns.yaml "$TEST_TEMP_DIR/p" | sort)"
    from_elsewhere="$(cd / && python3 "$FRAMEWORK_ROOT/$EXPANDER" \
        "$TEST_TEMP_DIR/p/.fabric/watch-patterns.yaml" "$TEST_TEMP_DIR/p" | sort)"
    [ -n "$from_root" ]
    [ "$from_root" = "$from_elsewhere" ]
}

_require_audit_ran() {
    # audit.sh takes a lock; under a concurrent cron run it prints
    # "Another audit is already running — exiting" and nothing else. Every
    # `! grep` assertion below would then pass on output that contains no
    # fabric section at all — a vacuous green of exactly the kind this suite
    # exists to catch. Assert the section is present before asserting about it.
    if echo "$1" | grep -q "Another audit is already running"; then
        skip "audit lock held by a concurrent run"
    fi
    echo "$1" | grep -q "Fabric" || {
        echo "audit produced no Fabric section:" >&2
        echo "$1" >&2
        false
    }
}

@test "T-2735: the live audit reports exactly one coverage number" {
    # Differential over the real audit output. Two lines answering the same
    # question is the state that hid this; assert only one of them makes a
    # coverage claim.
    local out
    # `|| true` — audit exits 1 on WARN by design, and bats runs under set -e,
    # so the substitution would abort the test before any assertion ran.
    out="$(cd "$FRAMEWORK_ROOT" && bash agents/audit/audit.sh --sections structure 2>&1 || true)"
    _require_audit_ran "$out"
    # The registered-count line must no longer carry an unregistered claim.
    echo "$out" | grep -q "Fabric: [0-9]* registered card(s)"
    ! echo "$out" | grep -qE "registered, [0-9]+ unregistered"
}

@test "T-2735: canonical and naive expansion are DISTINGUISHABLE" {
    # Discrimination control for the equality assertion below. On this repo the
    # removed glob and the expander happen to agree, because our one exclude:
    # is neutralised by a second pattern that re-adds the same files. So the
    # live equality test cannot, by itself, tell a correct implementation from
    # the broken one — it would pass either way here.
    #
    # This test proves the two implementations ARE separable on input where the
    # exclude carries weight, which is what makes the equality assertion mean
    # something rather than merely hold.
    _fixture "$TEST_TEMP_DIR/p"
    local canonical naive
    canonical="$(python3 "$FRAMEWORK_ROOT/$EXPANDER" \
        "$TEST_TEMP_DIR/p/.fabric/watch-patterns.yaml" "$TEST_TEMP_DIR/p" | sort)"
    naive="$(cd "$TEST_TEMP_DIR/p" && python3 - <<'PY' | sort
import yaml, glob, os
root = os.getcwd()
pats = yaml.safe_load(open(".fabric/watch-patterns.yaml"))["patterns"]
for p in pats:
    for m in glob.glob(os.path.join(root, p["glob"]), recursive=True):
        if os.path.isfile(m):
            print(os.path.relpath(m, root))
PY
)"
    [ -n "$canonical" ]
    [ -n "$naive" ]
    [ "$canonical" != "$naive" ]
    # and name the difference, so a future change to the fixture cannot make
    # them differ for some unrelated reason
    [[ "$naive" == *"web/_partial.html"* ]]
    [[ "$canonical" != *"web/_partial.html"* ]]
}

@test "T-2735: the live coverage number equals the canonical expander's" {
    local out drift expected
    # `|| true` — audit exits 1 on WARN by design, and bats runs under set -e,
    # so the substitution would abort the test before any assertion ran.
    out="$(cd "$FRAMEWORK_ROOT" && bash agents/audit/audit.sh --sections structure 2>&1 || true)"
    # Without this the `else drift=0` arm below would silently absorb a locked
    # audit and compare 0 against the real expander answer.
    _require_audit_ran "$out"
    if echo "$out" | grep -q "Fabric drift: [0-9]* source file"; then
        drift="$(echo "$out" | grep -oE "Fabric drift: [0-9]+ source" | grep -oE "[0-9]+")"
    else
        drift=0
    fi
    expected="$(cd "$FRAMEWORK_ROOT" && python3 - <<'PY'
import subprocess, glob, os, yaml, sys
root = os.getcwd()
reg = set()
for c in glob.glob(os.path.join(root, ".fabric/components/*.yaml")):
    d = yaml.safe_load(open(c))
    if d and d.get("location"):
        reg.add(d["location"])
out = subprocess.run([sys.executable, "agents/fabric/lib/expand_patterns.py",
                      ".fabric/watch-patterns.yaml", root],
                     capture_output=True, text=True).stdout.split()
print(len([f for f in out if f not in reg]))
PY
)"
    [ "$drift" = "$expected" ]
}

_audit_project() {
    # A minimal project the real audit will accept, so the severity legs below
    # run the actual shell branch rather than grepping for it.
    local d="$1"
    mkdir -p "$d/src/a" "$d/.fabric/components" \
             "$d/.tasks/active" "$d/.tasks/completed" "$d/.tasks/templates"
    touch "$d/.tasks/templates/default.md"
    printf 'patterns:\n  - glob: "src/**/*.py"\n    expected_type: script\n' \
        > "$d/.fabric/watch-patterns.yaml"
    : > "$d/src/a/deep.py"
    printf 'id: c1\nname: deep\nlocation: src/a/deep.py\ntype: script\n' \
        > "$d/.fabric/components/c1.yaml"
}

@test "T-2735 severity: fully-carded project PASSes" {
    _audit_project "$TEST_TEMP_DIR/ap"
    local out
    out="$(cd "$FRAMEWORK_ROOT" && PROJECT_ROOT="$TEST_TEMP_DIR/ap" \
        bash agents/audit/audit.sh --sections structure 2>&1 || true)"
    # T-2737 changed this wording: the old line printed the CARD count, which
    # read as "N files were checked". It now names the measured set size.
    echo "$out" | grep -q "PASS. Fabric drift: all 1 watched file(s) registered"
}

@test "T-2735 severity: injecting one uncarded file flips PASS to WARN" {
    # The injection control AC6 asks for. Severity must be a function of the
    # count, demonstrated by changing the count — not by reading the branch.
    _audit_project "$TEST_TEMP_DIR/ap"
    : > "$TEST_TEMP_DIR/ap/src/a/orphan.py"
    local out
    out="$(cd "$FRAMEWORK_ROOT" && PROJECT_ROOT="$TEST_TEMP_DIR/ap" \
        bash agents/audit/audit.sh --sections structure 2>&1 || true)"
    _require_audit_ran "$out"
    echo "$out" | grep -q "WARN. Fabric drift: 1 source file"
}

@test "T-2735 severity: a corrupt watch file FAILs instead of reporting coverage" {
    # Before this task the same input printed
    #   [PASS] Fabric drift: All watched source files registered ( cards)
    # — coverage entirely unmeasurable, reported as complete coverage. That is
    # the strongest form of the false green this task exists to remove.
    _audit_project "$TEST_TEMP_DIR/ap"
    printf 'patterns:\n  - glob: "src/**/*.py\n   BROKEN: [unclosed\n' \
        > "$TEST_TEMP_DIR/ap/.fabric/watch-patterns.yaml"
    local out
    out="$(cd "$FRAMEWORK_ROOT" && PROJECT_ROOT="$TEST_TEMP_DIR/ap" \
        bash agents/audit/audit.sh --sections structure 2>&1 || true)"
    _require_audit_ran "$out"
    echo "$out" | grep -q "FAIL. Fabric drift: coverage expander failed"
    # red-for-the-stated-reason: it must not merely be non-PASS
    echo "$out" | grep -q "UNMEASURED"
    ! echo "$out" | grep -q "All watched source files registered"
}

@test "T-2735: an unmeasurable coverage check FAILS rather than passing" {
    # The verdict must be a function of the number, and a broken expander must
    # not read as "no drift". Before this task the non-numeric branch fell
    # through to pass() — an instrument that could not run reported as one that
    # ran and found nothing.
    run grep -q "coverage is UNMEASURED" "$FRAMEWORK_ROOT/agents/audit/audit.sh"
    [ "$status" -eq 0 ]
    # and the branch that produces it must be a fail(), not a pass()
    run bash -c "grep -A1 'coverage expander failed' '$FRAMEWORK_ROOT/agents/audit/audit.sh' | head -2"
    [[ "$output" == *"fail "* ]] || [[ "$output" == *'fail "'* ]]
}
