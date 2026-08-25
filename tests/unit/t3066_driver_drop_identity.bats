#!/usr/bin/env bats
# T-3066: approving a queued driver proposal must not delete whichever driver
# happens to hold the proposed slot id at approval time.
#
# Reported by the 832-Workflow-designer agent (thread
# aef-upstream-findings-2026-08-16, item 1). Reproduced here end-to-end against
# a scratch register before the fix existed: a proposal filed to drop V_ALPHA,
# approved after slot F1 had been vacated and reallocated, deleted V_DIFFERENT
# — a driver created after the proposal was written, which nobody proposed
# dropping — and exited 0 printing "dropped F1", a message that is literally
# true and completely misleading.
#
# Driver ids are SLOTS. lib/bvp.sh allocates `F{n}` at the lowest free number,
# so vacating F1 hands that id to the next driver added. A proposal that records
# only the slot records where its target was standing, not who it was.
#
# Isolation: every test drives the real `bin/fw bvp driver` CLI with PROJECT_ROOT
# pointed at a scratch register, so nothing here touches policy/value-drivers.yaml
# or the live proposals queue.

FW=/opt/999-Agentic-Engineering-Framework/bin/fw

setup() {
    cd /opt/999-Agentic-Engineering-Framework
    SCRATCH="$(mktemp -d)"
    mkdir -p "$SCRATCH/policy" "$SCRATCH/.context" "$SCRATCH/.tasks/active"
    touch "$SCRATCH/.framework.yaml"
    cat > "$SCRATCH/policy/value-drivers.yaml" <<'EOF'
protected_drivers:
  - {id: D1, name: Antifragility, weight: 9, protected: true}
free_drivers:
  - {id: F1, name: V_ALPHA, weight: 5, protected: false, rationale: "scratch seed row for the T-3066 slot-recycling reproduction"}
  - {id: F2, name: V_BETA, weight: 4, protected: false, rationale: "scratch seed row for the T-3066 slot-recycling reproduction"}
EOF
    export SCRATCH
}

teardown() {
    [ -n "${SCRATCH:-}" ] && [ -d "$SCRATCH" ] && rm -rf "$SCRATCH"
}

# Drive the CLI against the scratch register. --from-watchtower stands in for the
# Sovereign click (§ACD refuses agent sessions otherwise); these tests run under
# $CLAUDECODE=1 in an agent session and via bats in cron, so it is required in both.
drv() {
    ( cd "$SCRATCH" && PROJECT_ROOT="$SCRATCH" "$FW" bvp driver "$@" 2>&1 )
}

names() {
    grep -oE 'name: [A-Za-z_][A-Za-z0-9_-]*' "$SCRATCH/policy/value-drivers.yaml" | sed 's/name: //'
}

# ------------------------------------------------ propose records the identity

@test "T-3066: propose with --drop stores the target's name, not just its slot" {
    run drv --propose V_NEW --weight 6 \
        --rationale "records what it means to drop, so approval can verify it later" \
        --drop F1
    [ "$status" -eq 0 ]

    row=$(tail -1 "$SCRATCH/.context/bvp-driver-proposals.jsonl")
    echo "$row" | grep -q '"drop": "F1"'
    # The load-bearing assertion: the NAME is persisted. A slot id alone is what
    # made the intent unrecoverable.
    echo "$row" | grep -q '"drop_name": "V_ALPHA"'
}

@test "T-3066: propose refuses a --drop id that denotes nothing" {
    # Filing an intent that is already unresolvable just defers the failure to
    # the operator's click.
    run drv --propose V_NEW --weight 6 \
        --rationale "this proposal names a slot that no free driver occupies today" \
        --drop F7
    [ "$status" -ne 0 ]
    echo "$output" | grep -q "not found in free_drivers"
    [ ! -f "$SCRATCH/.context/bvp-driver-proposals.jsonl" ]
}

# ------------------------------------- the recycle sequence, end to end (AC5)

@test "T-3066: approving after the slot changed hands refuses and changes nothing" {
    # 1. Propose: add V_NEW, drop V_ALPHA (which is F1 today).
    run drv --propose V_NEW --weight 6 \
        --rationale "proposed while F1 denoted V_ALPHA; that intent must survive the wait" \
        --drop F1
    [ "$status" -eq 0 ]
    stored_drop=$(python3 -c "
import json,sys
print(json.loads(open('$SCRATCH/.context/bvp-driver-proposals.jsonl').readlines()[-1])['drop'])")
    stored_name=$(python3 -c "
import json,sys
print(json.loads(open('$SCRATCH/.context/bvp-driver-proposals.jsonl').readlines()[-1])['drop_name'])")

    # 2. V_ALPHA leaves by another route, vacating the slot.
    run drv --remove F1 --rationale "operator retires V_ALPHA directly, vacating slot F1" --from-watchtower
    [ "$status" -eq 0 ]

    # 3. A different driver is added and the allocator recycles the vacated id.
    run drv --add V_DIFFERENT --weight 7 \
        --rationale "a brand new driver that nobody has proposed dropping at all" --from-watchtower
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "added F1 'V_DIFFERENT'"   # the recycle, asserted

    # 4. Approve the stored proposal exactly as web/blueprints/bvp.py does.
    run drv --add V_NEW --weight 6 \
        --rationale "proposed while F1 denoted V_ALPHA; that intent must survive the wait" \
        --drop "$stored_drop" --drop-name "$stored_name" --from-watchtower
    [ "$status" -ne 0 ]

    # The message must name BOTH sides — an operator reading only "refused"
    # cannot tell whether the register or the proposal is the stale one.
    echo "$output" | grep -q "V_ALPHA"
    echo "$output" | grep -q "V_DIFFERENT"

    # Fail-safe, not best-effort: no deletion AND no addition.
    names | grep -q '^V_DIFFERENT$'
    ! names | grep -q '^V_NEW$'
}

# --------------------------------------- the guard must not break the cap (AC4)

@test "T-3066: an unchanged referent still approves, including at cap" {
    # Fill to the cap of 9 (1 protected + 8 free).
    for n in 3 4 5 6 7 8; do
        run drv --add "V_FILL$n" --weight 3 \
            --rationale "filler driver added to drive the register to the cap of nine" --from-watchtower
        [ "$status" -eq 0 ]
    done
    total=$(names | wc -l)
    [ "$total" -eq 9 ]

    # At cap, a drop is mandatory — and the pair still works when nothing moved.
    run drv --add V_NEW --weight 6 \
        --rationale "add-one-drop-one at the cap with a referent that has not moved" \
        --drop F2 --drop-name V_BETA --from-watchtower
    [ "$status" -eq 0 ]
    names | grep -q '^V_NEW$'
    if names | grep -q '^V_BETA$'; then false; fi
    [ "$(names | wc -l)" -eq 9 ]
}

@test "T-3066: at-cap refusal message tells the operator to pass both flags" {
    for n in 3 4 5 6 7 8; do
        run drv --add "V_FILL$n" --weight 3 \
            --rationale "filler driver added to drive the register to the cap of nine" --from-watchtower
    done
    run drv --add V_NEW --weight 6 \
        --rationale "at cap with no drop at all, so this must be refused outright" --from-watchtower
    [ "$status" -ne 0 ]
    echo "$output" | grep -q -- "--drop-name"
}

# ------------------------------------------ neither flag may travel alone

@test "T-3066: --drop without --drop-name is refused, not silently unchecked" {
    # An optional identity check is one a caller forgets, and a guard that was
    # skipped looks exactly like a guard that passed (L-616).
    run drv --add V_NEW --weight 6 \
        --rationale "passes only the slot id, the shape the defect was reported for" \
        --drop F1 --from-watchtower
    [ "$status" -ne 0 ]
    echo "$output" | grep -q -- "requires --drop-name"
    echo "$output" | grep -q "V_ALPHA"        # tells them what F1 means right now
    if names | grep -q '^V_NEW$'; then false; fi
    names | grep -q '^V_ALPHA$'
}

@test "T-3066: --drop-name without --drop is refused rather than ignored" {
    # Found while probing the fix: the stray flag was accepted and the add went
    # through with nothing dropped — a caller who believes they displaced a
    # driver and did not.
    run drv --add V_NEW --weight 6 \
        --rationale "names a driver to drop but never says which slot it occupies" \
        --drop-name V_ALPHA --from-watchtower
    [ "$status" -ne 0 ]
    echo "$output" | grep -q -- "without --drop"
    ! names | grep -q '^V_NEW$'
}

# ------------------------------- the join: both consumers wired (AC3, L-399)

@test "T-3066: every Watchtower route that builds a driver --add passes --drop-name" {
    # AC3. The guard lives in the CLI, so both legs inherit it — but only if the
    # caller actually passes the flag. A guard wired to one leg is the
    # producer/consumer split L-399 names and T-3065 paid for earlier today, and
    # a correct helper wired nowhere reads exactly like one wired everywhere.
    # So assert the join at the source, per function, rather than trusting it.
    run python3 - <<'PY'
import ast, pathlib, sys
src = pathlib.Path("web/blueprints/bvp.py").read_text()
tree = ast.parse(src)
lines = src.splitlines(keepends=True)
offenders = []
checked = []
for node in ast.walk(tree):
    if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
        continue
    body = ast.get_source_segment(src, node) or ""
    # Only functions that shell out to `driver --add` can delete a driver.
    if '"--add"' not in body or '"--drop"' not in body:
        continue
    checked.append(node.name)
    if '"--drop-name"' not in body:
        offenders.append(node.name)
print("checked:", checked)
if offenders:
    print("MISSING --drop-name in:", offenders)
    sys.exit(1)
# Positive control: if nothing matched, the assertion above proved nothing.
if not checked:
    print("no --add/--drop call site found — this test has stopped testing anything")
    sys.exit(1)
print("PASS")
PY
    [ "$status" -eq 0 ]
    echo "$output" | grep -q PASS
}

@test "T-3066: the approve route refuses legacy rows that record a slot but no name" {
    # 100 append-only rows predate `drop_name`. Those whose `drop` is non-null
    # carry an intent nobody can read, so the route must refuse rather than
    # resolve the slot at approval time — which is the defect itself.
    run grep -n "predates drop-identity recording" web/blueprints/bvp.py
    [ "$status" -eq 0 ]
    run python3 -c "
import ast, pathlib
src = pathlib.Path('web/blueprints/bvp.py').read_text()
fn = next(n for n in ast.walk(ast.parse(src))
          if isinstance(n, ast.FunctionDef) and n.name == 'bvp_driver_approve')
body = ast.get_source_segment(src, fn)
assert 'drop_name' in body, 'approve route does not read drop_name at all'
assert '409' in body, 'legacy-row refusal does not return a status code'
print('PASS')
"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q PASS
}
