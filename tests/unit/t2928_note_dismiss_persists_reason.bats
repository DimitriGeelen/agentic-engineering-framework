#!/usr/bin/env bats
# T-2928 — `fw note dismiss OBS-NNN --reason "..."` accepted the reason,
# printed it, and discarded it.
#
# do_dismiss parsed --reason into a local, used it in exactly one place (the
# confirmation echo) and wrote:
#
#     _sed_i "/id: $obs_id/,/promoted_to:/{s/status: pending/status: dismissed/}"
#
# `status: dismissed` and nothing else. The reason went to a terminal nobody
# archives while the success line quoted it back on the way out — which
# manufactures confidence at exactly the moment someone is being careful.
#
# The cost is not lost prose. A dismissed observation with no reason cannot
# answer the only question anyone asks of one: was this judged and closed, or
# was it swept? Those are the same row. An inbox that cannot tell them apart
# eventually gets batch-cleared by someone who reasonably concludes the entries
# were never triaged — the exact failure the triage ritual exists to prevent.
#
# Measured here when the fix landed: 81 dismissed observations, 0 with a reason.
# Reported by 832 (rail 547 §F) at 26/0 in their tree. They found it by
# verifying their own dispositions instead of trusting the success message, and
# it falsified a claim a previous session of theirs had made in writing — that
# an observation was "dismissed with that reason rather than deleted, so the
# next person who types it finds the answer". There was no field for it to be in.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    PROJ="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$PROJ/.context"
    cat > "$PROJ/.context/inbox.yaml" <<'YAML'
observations:
- id: OBS-001
  text: first observation
  status: pending
- id: OBS-002
  text: second observation
  status: pending
- id: OBS-003
  text: an already-dismissed legacy entry with no reason
  status: dismissed
YAML
}

# Drives agents/observe/observe.sh — the script `fw note` routes to — rather
# than the fw wrapper. Two reasons, and the first is containment:
#
#   1. `fw` resolves the project from the WORKING DIRECTORY and ignores a
#      PROJECT_ROOT in the environment. An earlier version of this helper set
#      PROJECT_ROOT and stayed in the framework repo, so every write leg
#      addressed the REAL inbox. Nothing was corrupted — but only because the
#      target id happened to be already dismissed there and the refusal path
#      declined to write. That is luck, not containment. observe.sh honours
#      PROJECT_ROOT, so the fixture is addressable without a cd and the real
#      inbox is not reachable by accident.
#   2. The wrapper adds ~3s of project resolution per call and, in a directory
#      that is not a framework project, goes down an onboarding path that does
#      not terminate under bats.
#
# This is still the real producer: observe.sh is the shipped implementation,
# not a re-typed copy of it.
_dismiss() {
    PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$FRAMEWORK_ROOT/agents/observe/observe.sh" dismiss "$@" 2>&1
}

_field() {
    python3 -c "
import yaml, sys
d = yaml.safe_load(open('$PROJ/.context/inbox.yaml')) or {}
o = [x for x in (d.get('observations') or []) if x.get('id') == '$1']
print('' if not o else (o[0].get('$2') if o[0].get('$2') is not None else ''))
"
}

# ── The defect, reconstructed so the fix is demonstrably fixing something ────

@test "t2928: the OLD sed write stored status and dropped the reason" {
    # Anti-vacuity. Runs the pre-fix substitution against the fixture and shows
    # the reason has nowhere to land — the flag could be parsed perfectly and
    # the file still would not receive it.
    run bash -c "
        sed -i '/id: OBS-001/,/promoted_to:/{s/status: pending/status: dismissed/}' '$PROJ/.context/inbox.yaml'
        grep -c 'dismissed_reason' '$PROJ/.context/inbox.yaml' || true
    "
    [ "$status" -eq 0 ]
    [ "$output" = "0" ]
    # ...and the status change DID happen, so the operator sees a successful
    # dismissal with the rationale silently absent.
    run bash -c "grep -A2 'id: OBS-001' '$PROJ/.context/inbox.yaml' | grep -c 'status: dismissed'"
    [ "$output" = "1" ]
}

# ── The repair ───────────────────────────────────────────────────────────────

@test "t2928: the reason is persisted to the observation" {
    run _dismiss OBS-001 --reason "already fixed by T-2927"
    [ "$status" -eq 0 ] || { echo "$output" >&2; return 1; }
    run _field OBS-001 dismissed_reason
    [ "$output" = "already fixed by T-2927" ]
}

@test "t2928: a dismissal timestamp is recorded alongside it" {
    _dismiss OBS-001 --reason "x" >/dev/null
    run _field OBS-001 dismissed_at
    [ -n "$output" ]
    [[ "$output" == 2*"-"* ]]
}

@test "t2928: the reason reads back as structured YAML, not as a grepped line" {
    # Asserted via yaml.safe_load rather than by grepping the text just written.
    # A test that greps for the line it wrote passes even when the surrounding
    # document has been corrupted into something no parser will accept.
    _dismiss OBS-002 --reason "duplicate of OBS-001" >/dev/null
    run python3 -c "
import yaml
d = yaml.safe_load(open('$PROJ/.context/inbox.yaml'))
obs = {o['id']: o for o in d['observations']}
assert obs['OBS-002']['status'] == 'dismissed', obs['OBS-002']
assert obs['OBS-002']['dismissed_reason'] == 'duplicate of OBS-001'
assert obs['OBS-001']['status'] == 'pending', 'sibling entry was mutated'
print('OK')
"
    [ "$status" -eq 0 ] || { echo "$output" >&2; return 1; }
    [ "$output" = "OK" ]
}

@test "t2928: quotes, colons and newlines in the reason round-trip intact" {
    # The reason is operator free text. A sed substitution mangles or truncates
    # every one of these, which is why the write is python and the scalar is
    # json.dumps'd (valid YAML for all three).
    local hostile='blocked by T-1: he said "no", then:
a second line'
    _dismiss OBS-001 --reason "$hostile" >/dev/null
    run python3 -c "
import yaml
d = yaml.safe_load(open('$PROJ/.context/inbox.yaml'))
o = [x for x in d['observations'] if x['id'] == 'OBS-001'][0]
got = o['dismissed_reason']
want = '''blocked by T-1: he said \"no\", then:
a second line'''
assert got == want, 'got %r want %r' % (got, want)
print('OK')
"
    [ "$status" -eq 0 ] || { echo "$output" >&2; return 1; }
}

@test "t2928: omitting --reason still dismisses and records the default" {
    run _dismiss OBS-001
    [ "$status" -eq 0 ]
    run _field OBS-001 status
    [ "$output" = "dismissed" ]
    run _field OBS-001 dismissed_reason
    [ -n "$output" ]
}

# ── Refusing rather than half-writing ────────────────────────────────────────

@test "t2928: dismissing a non-pending observation refuses and leaves the file alone" {
    local before
    before=$(md5sum "$PROJ/.context/inbox.yaml" | cut -d' ' -f1)
    run _dismiss OBS-003 --reason "second dismissal"
    [ "$status" -ne 0 ]
    local after
    after=$(md5sum "$PROJ/.context/inbox.yaml" | cut -d' ' -f1)
    [ "$before" = "$after" ] || {
        echo "refused but still wrote to the inbox" >&2
        return 1
    }
}

@test "t2928: dismissing an unknown id refuses and leaves the file alone" {
    local before
    before=$(md5sum "$PROJ/.context/inbox.yaml" | cut -d' ' -f1)
    run _dismiss OBS-999 --reason "does not exist"
    [ "$status" -ne 0 ]
    [ "$(md5sum "$PROJ/.context/inbox.yaml" | cut -d' ' -f1)" = "$before" ]
}

@test "t2928: the refusal says the inbox was NOT modified" {
    # A non-zero exit that says nothing leaves the operator guessing whether a
    # partial write happened. The message has to state the outcome, not just
    # fail.
    run _dismiss OBS-999 --reason "x"
    [[ "$output" == *"NOT dismissed"* ]]
}

# ── Not backfilling history ──────────────────────────────────────────────────

@test "t2928: pre-existing reason-less dismissals are left distinguishable" {
    # OBS-003 was dismissed before this change and carries no reason. It must
    # stay that way: inventing a rationale for a past decision is worse than
    # recording that none was captured, because the fabricated one is
    # indistinguishable from a real one.
    _dismiss OBS-001 --reason "new-style" >/dev/null
    run _field OBS-003 dismissed_reason
    [ -z "$output" ]
    run _field OBS-003 status
    [ "$output" = "dismissed" ]
}
