#!/usr/bin/env bats
# T-2932 — `fw note count` reported the urgent figure from a whole-file grep.
#
#     urgent=$(grep -c 'urgent: true' "$INBOX_FILE")
#
# No status filter. Every observation ever marked urgent was counted forever,
# including ones dismissed months earlier.
#
# Measured on the live inbox when this was found: **reported 8, true 4.** The four
# phantoms — OBS-002, OBS-029, OBS-030, OBS-031 — were all dismissed.
#
# That figure is the headline in the handover and in the session-start ritual, so
# it inflated the one number an agent is told to act on before starting work.
#
# Over-reporting urgency is not the safe direction. An operator who opens the
# queue and finds half the "urgent" items already dismissed learns the number is
# decorative, and the next real one gets the same shrug. An urgency signal dies by
# inflation, not by silence.
#
# Sibling-site note (L-533): the urgent count was already YAML-parsed in
# handover.sh (T-2927) and audit.sh (T-2514). This site was never swept — the
# third instance of the same class in the same subsystem. do_list had it too, one
# screen above: T-2317 converted the LISTING to yaml.safe_load and left the header
# count on the grep, so a header could disagree with the rows printed under it.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    OBSERVE="$FRAMEWORK_ROOT/agents/observe/observe.sh"
    PROJ="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$PROJ/.context"
    INBOX="$PROJ/.context/inbox.yaml"
    cat > "$INBOX" <<'YAML'
observations:
- id: OBS-001
  text: a pending non-urgent observation
  status: pending
- id: OBS-002
  text: a pending URGENT observation
  status: pending
  urgent: true
- id: OBS-003
  text: an urgent observation that was already dismissed
  status: dismissed
  urgent: true
- id: OBS-004
  text: another dismissed urgent one
  status: dismissed
  urgent: true
YAML
}

# Drives the shipped script directly. `fw` resolves the project from the working
# directory and would address the REAL inbox from this repo (t2928's lesson —
# that helper only failed to corrupt anything by luck). observe.sh honours
# PROJECT_ROOT, so the fixture is addressable without a cd.
_note() {
    PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$OBSERVE" "$@" 2>&1
}

# ── The defect, reconstructed ────────────────────────────────────────────────

@test "t2932: the OLD whole-file grep over-counts urgent on this fixture" {
    # Anti-vacuity. 3 lines say `urgent: true`; only 1 belongs to a pending
    # observation. Reconstructed inline rather than read from git — a leg that
    # reads pre-fix bytes from HEAD goes stale the moment the fix is committed
    # (t2927's leg 9, green when written and red within the hour).
    run bash -c "grep -c 'urgent: true' '$INBOX'"
    [ "$output" = "3" ]
}

# ── The repair ───────────────────────────────────────────────────────────────

@test "t2932: count reports only PENDING urgent observations" {
    run _note count
    [ "$status" -eq 0 ] || { echo "$output" >&2; return 1; }
    [ "$output" = "2 pending (1 urgent)" ] || { echo "got: $output" >&2; return 1; }
}

@test "t2932: dismissing the last pending urgent drops the urgent figure" {
    _note dismiss OBS-002 --reason "handled" >/dev/null
    run _note count
    # No urgent left pending — and the parenthetical disappears rather than
    # reading "(0 urgent)".
    [ "$output" = "1 pending" ] || { echo "got: $output" >&2; return 1; }
}

@test "t2932: the count matches an independent YAML-parsed count exactly" {
    # Asserted against a separate parse rather than against the literal string
    # above, so this leg still holds if the fixture changes.
    local truth
    truth=$(python3 -c "
import yaml
d = yaml.safe_load(open('$INBOX'))
p = [o for o in d['observations'] if o.get('status') == 'pending']
print(len(p), sum(1 for o in p if o.get('urgent') is True))
")
    run _note count
    local got="${truth% *} pending (${truth#* } urgent)"
    [ "$output" = "$got" ] || { echo "count=$output truth=$got" >&2; return 1; }
}

@test "t2932: the header on 'list' agrees with the rows it prints" {
    # The original defect one screen up: T-2317 converted the LISTING to YAML and
    # left the header on a grep, so the two could disagree with nothing to notice.
    run _note list
    [ "$status" -eq 0 ]
    local header rows
    header=$(printf '%s\n' "$output" | grep -oE '\([0-9]+ pending\)' | grep -oE '[0-9]+')
    rows=$(printf '%s\n' "$output" | grep -cE 'OBS-00[0-9]')
    [ "$header" = "$rows" ] || {
        echo "header says $header, printed $rows rows" >&2
        printf '%s\n' "$output" >&2
        return 1
    }
}

@test "t2932: an urgent row is only listed while it is pending" {
    run _note list
    [[ "$output" == *"OBS-002"* ]]
    [[ "$output" != *"OBS-003"* ]]
    [[ "$output" != *"OBS-004"* ]]
}

# ── The third answer ─────────────────────────────────────────────────────────

@test "t2932: an unparseable inbox refuses loudly instead of counting zero" {
    # L-578: two-valued checks lie on the branch nobody looks at. `0 pending` from
    # a corrupted inbox is indistinguishable from a healthy empty one, and the
    # session-start ritual reads that number as permission to start work.
    printf 'observations:\n- id: OBS-001\n  text: "unterminated\n' > "$INBOX"
    run _note count
    [ "$status" -ne 0 ]
    [[ "$output" == *"unreadable"* ]] || { echo "got: $output" >&2; return 1; }
    [[ "$output" != *"0 pending"* ]]
}

@test "t2932: list refuses on the same corruption rather than printing an empty inbox" {
    printf 'observations:\n- id: OBS-001\n  text: "unterminated\n' > "$INBOX"
    run _note list
    [ "$status" -ne 0 ]
    [[ "$output" != *"Inbox empty"* ]] || {
        echo "a corrupt inbox reported itself as empty" >&2
        return 1
    }
}

@test "t2932: a genuinely empty inbox still reports empty, not unreadable" {
    # Anti-vacuity for the two legs above: proves 'unreadable' means unreadable
    # and not 'anything unusual'.
    printf 'observations: []\n' > "$INBOX"
    run _note count
    [ "$status" -eq 0 ]
    [ "$output" = "0 pending" ]
    run _note list
    [ "$status" -eq 0 ]
    [[ "$output" == *"Inbox empty"* ]]
}

# ── Sibling sites: latent, so guard rather than silently rely on them ────────

@test "t2932: no grep-based urgent counter remains in observe.sh" {
    # Enumerating guard. Whole-line comments stripped first — the block comment
    # added by this task quotes the old grep, and a naive scan flags the
    # explanation as the defect (the rake t2926 leg 5 hit in bin/fw).
    local hits
    hits=$(sed 's/[[:space:]]*#.*$//' "$OBSERVE" | grep -n "grep -c 'urgent: true'" || true)
    [ -z "$hits" ] || { echo "grep-based urgent counter still present: $hits" >&2; return 1; }
}

@test "t2932: no sibling site counts pending observations by grep" {
    # This leg was written to GUARD a latency and went red inside the hour.
    #
    # `handover.sh:381` and `audit.sh:2663` counted pending with
    # `grep -c 'status: pending'`. Measured at the start of this task that was
    # exactly right — no observation's text contained the string — so it was
    # filed as OBS-233 rather than fixed here (one bug, one task). Then OBS-233,
    # whose text quotes the very string it is about, pushed grep to 119 against a
    # true 118. **The observation describing the latent case is what made it
    # live.** The "latent, defer it" call was falsified by the act of recording
    # it, so both sites were fixed under this task after all.
    #
    # The leg now asserts the fix rather than the latency: no grep-based pending
    # counter anywhere in the inbox-reading set. Comments are stripped first —
    # all three files now carry block comments quoting the old form.
    local f hits
    for f in "$FRAMEWORK_ROOT/agents/observe/observe.sh" \
             "$FRAMEWORK_ROOT/agents/handover/handover.sh" \
             "$FRAMEWORK_ROOT/agents/audit/audit.sh"; do
        hits=$(sed 's/[[:space:]]*#.*$//' "$f" | grep -n "grep -c 'status: pending'" || true)
        [ -z "$hits" ] || {
            echo "$f still counts pending by grep: $hits" >&2
            return 1
        }
    done
}

@test "t2932: the real inbox exercises the case that broke the grep" {
    # Anti-vacuity for the leg above. If no observation quoted the string, a
    # grep-based counter would still agree with the parse and the leg above would
    # be guarding nothing. Pins the specimen: at least one observation's TEXT
    # contains `status: pending`, so grep and parse genuinely disagree here.
    local real_inbox="$FRAMEWORK_ROOT/.context/inbox.yaml"
    [ -f "$real_inbox" ] || skip "no inbox in this tree"
    run python3 -c "
import yaml
d = yaml.safe_load(open('$real_inbox')) or {}
obs = d.get('observations') or []
quoting = [o['id'] for o in obs if 'status: pending' in (o.get('text') or '')]
parsed = sum(1 for o in obs if o.get('status') == 'pending')
print(len(quoting), parsed)
"
    [ "$status" -eq 0 ]
    local quoting="${output% *}" parsed="${output#* }"
    [ "$quoting" -gt 0 ] || skip "no observation quotes the string yet — guard is not yet exercised"
    # grep must now DISAGREE with the parse, which is what makes the fix load-bearing
    local g
    g=$(grep -c 'status: pending' "$real_inbox")
    [ "$g" -ne "$parsed" ] || {
        echo "grep ($g) and parse ($parsed) agree despite $quoting quoting observation(s)" >&2
        return 1
    }
}
