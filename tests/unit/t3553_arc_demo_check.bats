#!/usr/bin/env bats
# T-3553 (T-3548 Slice B) — `fw arc demo-check` reads the demo evidence an arc
# ALREADY carries.
#
# `_arc_validate_demo_path` / `_arc_validate_demo_url` (T-1668 §ACD Layer B) have
# been thorough since they were written, and have run at exactly one moment: when
# the operator types `fw arc close --demo <path>`. Nothing ever checked the
# `demo_evidence:` recorded on the arc. So an arc could be surfaced close-ready
# with no demo at all — live at the time of writing, `readme-first-run` cleared
# L1+L2+L3 with `demo_evidence: null`, and 14 of 18 in-progress arcs record none.
#
# THE CONTROL IS LOAD-BEARING: `a valid traceable artefact passes` is what
# separates this from a check that fails everything. 14 of 18 arcs failing is the
# honest answer here, which is exactly the shape in which a broken check hides.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    P="$(mktemp -d)"
    mkdir -p "$P/.context/arcs" "$P/docs"
}

teardown() {
    [ -n "${P:-}" ] && rm -rf "$P"
    return 0
}

# Write an arc yaml whose demo_evidence: is $2.
_arc() {
    local slug="$1" demo="$2"
    { printf 'id: %s\nslug: %s\nname: "fixture"\nstatus: in-progress\n' "$slug" "$slug"
      printf 'headline_mechanic: "agent does a thing and observes a result"\n'
      printf 'anchor_task: T-9001\n'
      printf 'demo_evidence: %s\n' "$demo"; } > "$P/.context/arcs/$slug.yaml"
}

# An evidence file that satisfies every rule: >=256 bytes, allowlisted extension,
# and references the arc id so it is traceable.
_evidence() {
    local path="$1" ref="$2"
    mkdir -p "$(dirname "$path")"
    { printf '# demo evidence for %s\n\n' "$ref"
      printf 'This artefact references %s so the traceability rule is satisfied.\n' "$ref"
      head -c 400 /dev/zero | tr '\0' 'x'; printf '\n'; } > "$path"
}

_check() {
    ( cd "$P" && PROJECT_ROOT="$P" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash -c "source '$FRAMEWORK_ROOT/lib/arc.sh'; arc_demo_check '$1'" 2>&1 )
}

_rc() {
    ( cd "$P" && PROJECT_ROOT="$P" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash -c "source '$FRAMEWORK_ROOT/lib/arc.sh'; arc_demo_check '$1' >/dev/null 2>&1"; echo $? )
}

# ── the control ──────────────────────────────────────────────────────────────

@test "CONTROL: a valid, traceable artefact passes (exit 0)" {
    _evidence "$P/docs/good.md" "demo-ok"
    _arc demo-ok "docs/good.md"
    [ "$(_rc demo-ok)" -eq 0 ]
    _check demo-ok | grep -q 'valid:'
}

# ── absent is its own state ──────────────────────────────────────────────────

@test "demo_evidence: null is ABSENT, not merely invalid" {
    _arc demo-null "null"
    [ "$(_rc demo-null)" -eq 1 ]
    _check demo-null | grep -q 'absent:'
}

@test "an empty demo_evidence: is also absent" {
    _arc demo-empty ""
    [ "$(_rc demo-empty)" -eq 1 ]
    _check demo-empty | grep -q 'absent:'
}

@test "the absent message names WHY it matters, not just that it is missing" {
    # A bare "missing field" tells an operator nothing about the decision it
    # blocks. §ACD's question is the reason the field exists.
    _arc demo-null2 "null"
    _check demo-null2 | grep -qi 'headline_mechanic'
}

# ── recorded but failing a rule ──────────────────────────────────────────────

@test "a missing file is reported, and is NOT reported as absent" {
    _arc demo-gone "docs/not-here.md"
    [ "$(_rc demo-gone)" -eq 1 ]
    run _check demo-gone
    [ "$(echo "$output" | grep -c 'absent:')" -eq 0 ]
    echo "$output" | grep -qi 'does not exist'
}

@test "a too-small file fails the 256-byte rule" {
    mkdir -p "$P/docs"; printf 'tiny\n' > "$P/docs/small.md"
    _arc demo-small "docs/small.md"
    [ "$(_rc demo-small)" -eq 1 ]
    _check demo-small | grep -qi 'too small'
}

@test "an untraceable artefact fails even when it is large and allowlisted" {
    # The rule that matters most: evidence must be tied to THIS arc.
    mkdir -p "$P/docs"
    head -c 500 /dev/zero | tr '\0' 'x' > "$P/docs/anon.md"
    _arc demo-anon "docs/anon.md"
    [ "$(_rc demo-anon)" -eq 1 ]
    _check demo-anon | grep -qi 'does not reference'
}

# ── URL: indeterminate, and offline ──────────────────────────────────────────

@test "a URL demo is INDETERMINATE (exit 2), never a pass" {
    _arc demo-url "https://example.invalid/evidence"
    [ "$(_rc demo-url)" -eq 2 ]
    _check demo-url | grep -qi 'indeterminate'
}

@test "the URL path makes no network call" {
    # Surfacing must not depend on the network. A hostname that cannot resolve
    # returns instantly if nothing dials it; the timeout is the assertion.
    _arc demo-url2 "https://this-host-does-not-exist.invalid/x"
    run timeout 5 bash -c "cd '$P' && PROJECT_ROOT='$P' FRAMEWORK_ROOT='$FRAMEWORK_ROOT' \
        bash -c \"source '$FRAMEWORK_ROOT/lib/arc.sh'; arc_demo_check demo-url2\" >/dev/null 2>&1"
    [ "$status" -eq 2 ]
}

# ── multi-artefact entries ───────────────────────────────────────────────────

@test "ANY valid candidate passes a multi-artefact entry" {
    # Shape taken from the live `parallel-execution-aef`, whose recorded evidence
    # leads with a .sh (not allowlisted) followed by a .md that validates. Judging
    # only the first token reported that real arc invalid — a false negative in
    # the leg built to remove false negatives.
    _evidence "$P/docs/wire.md" "demo-multi"
    printf 'x\n' > "$P/docs/run.sh"
    _arc demo-multi "docs/run.sh (T-2341, exit 0) + docs/wire.md"
    [ "$(_rc demo-multi)" -eq 0 ]
    _check demo-multi | grep -q 'docs/wire.md'
}

@test "a multi-artefact entry where NOTHING validates still fails" {
    printf 'x\n' > "$P/docs/a.sh"
    _arc demo-multi-bad "docs/a.sh + docs/missing.md"
    [ "$(_rc demo-multi-bad)" -eq 1 ]
}

# ── the rules are not re-implemented ─────────────────────────────────────────

@test "demo-check delegates to _arc_validate_demo_path" {
    body=$(awk '/^arc_demo_check\(\)/,/^}/' "$FRAMEWORK_ROOT/lib/arc.sh" | grep -v '^[[:space:]]*#')
    [ -n "$body" ]
    printf '%s\n' "$body" | grep -q '_arc_validate_demo_path'
    # and must not restate the allowlist itself
    [ "$(printf '%s\n' "$body" | grep -c 'jsonl')" -eq 0 ]
}

@test "the verb is routed from arc_dispatch" {
    grep -q 'demo-check) arc_demo_check' "$FRAMEWORK_ROOT/lib/arc.sh"
}

@test "demo-check never writes to the arc file" {
    _evidence "$P/docs/good2.md" "demo-ro"
    _arc demo-ro "docs/good2.md"
    before=$(md5sum "$P/.context/arcs/demo-ro.yaml" | awk '{print $1}')
    _check demo-ro >/dev/null
    after=$(md5sum "$P/.context/arcs/demo-ro.yaml" | awk '{print $1}')
    [ "$before" = "$after" ]
}

@test "lib/arc.sh parses" {
    bash -n "$FRAMEWORK_ROOT/lib/arc.sh"
}
