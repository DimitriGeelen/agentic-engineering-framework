#!/usr/bin/env bash
# T-3257 — live-fire: does the continuous-driver actually hand a turn to a REAL agent?
#
# WHAT THIS PROVES THAT NOTHING ELSE DOES.
#
#   tests/unit/t3275_delivery_confirmation.bats  — stubs the transport. Proves the
#       driver's VERDICT tracks delivery. Cannot prove delivery itself.
#   tools/t3250-transport-probe.sh               — real binaries, but probes the
#       WIRE directly. Never runs the driver.
#
# This runs the actual `continuous-driver.sh` end to end — bounds -> target
# resolution -> transport -> delivery confirmation -> ledger — against a real
# `claude` TUI, and then asks the harder question the other two never ask:
# did the agent PROCESS the turn, or did the text merely land in an input box?
#
# THE THREE LEGS, AND WHY EACH IS LOAD-BEARING.
#
#   A  NEGATIVE (real path): a live tmux pane whose tty has ECHO DISABLED
#      (`stty -echo`), running `sleep`. `tmux send-keys` exits 0 — the transport
#      genuinely succeeds — and the target never reads the input nor renders it.
#      That is the G-097 shape reproduced with real binaries, and the driver must
#      record `refused`. Without this leg a green run cannot distinguish a working
#      confirmation from one that rubber-stamps every tick.
#
#      `stty -echo` IS THE WHOLE POINT AND WAS LEARNED THE HARD WAY. The first
#      version of this leg used a plain `sleep` pane and the driver CONFIRMED
#      delivery into it — a false green. Cause: the tty line discipline echoes
#      keystrokes to the screen even though `sleep` never reads them, so
#      `capture-pane` shows the text regardless. Measured directly, not inferred.
#      That is a real limitation of the confirmation on this transport and is
#      recorded as such; disabling echo is what makes this leg test the driver
#      instead of testing the terminal.
#
#   B  POSITIVE (real agent): a real Claude TUI in a tmux pane. The driver must
#      record `injected` with `confirmed=text-in-pane`.
#
#   C  SEMANTIC: leg B only proves the TEXT arrived. An input box can hold text
#      that was never submitted. So the directive asks for a token that does NOT
#      appear in the directive itself — the agent has to compute it. Finding that
#      token is the only evidence a TURN was actually taken.
#
#   D  NEVER-SENT CONTROL: a token nobody transmitted must be absent. A pane
#      matcher that returns true for everything would otherwise pass A-C.
#
# Usage:  tools/t3257-livefire-driver.sh [--keep]
#           --keep   leave the Claude pane running for visual inspection
set -uo pipefail

PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRIVER="$PROJ/agents/context/continuous-driver.sh"
STAMP="$$"
TM_AGENT="t3257agent$STAMP"      # tmux session holding the real Claude TUI
TM_DEAF="t3257deaf$STAMP"        # tmux session that accepts input and echoes nothing
SB="${TMPDIR:-/tmp}/t3257-sandbox-$STAMP"
KEEP=0
[ "${1:-}" = "--keep" ] && KEEP=1

PASS=0; FAIL=0
ok()   { printf '  \033[0;32mPASS\033[0m  %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '  \033[0;31mFAIL\033[0m  %s\n' "$1"; FAIL=$((FAIL+1)); }
note() { printf '        %s\n' "$1"; }
hdr()  { printf '\n\033[1m%s\033[0m\n' "$1"; }

cleanup() {
    tmux kill-session -t "$TM_DEAF" >/dev/null 2>&1
    if [ "$KEEP" = 1 ]; then
        echo
        echo "KEPT for inspection — the Claude pane is still live:"
        echo "    tmux attach -t $TM_AGENT        # ctrl-b d to detach"
        echo "    tmux capture-pane -p -t $TM_AGENT | tail -30"
        echo "    tmux kill-session -t $TM_AGENT  # when done"
        echo "sandbox (ledger lives here): $SB"
        return
    fi
    tmux kill-session -t "$TM_AGENT" >/dev/null 2>&1
    rm -rf "$SB"
}
trap cleanup EXIT

# Wrap-immune matching: a TUI wraps long input and can break a word mid-token, so
# a matcher that only collapses whitespace RUNS still misses. Remove it entirely.
squash() { printf '%s' "${1:-}" | tr -d '[:space:]'; }
pane()   { timeout 15 tmux capture-pane -p -t "$1" 2>/dev/null | tail -c 8000; }
inpane() { case "$(squash "$(pane "$1")")" in *"$(squash "$2")"*) return 0 ;; esac; return 1; }

ledger_last() { tail -n "${2:-6}" "$SB/.context/working/continuous-run.jsonl" 2>/dev/null; }

hdr "=== T-3257 live-fire — does the driver hand a turn to a REAL agent? ==="
echo "tmux:   $(tmux -V 2>&1)"
echo "claude: $(claude --version 2>&1 | head -1)"
echo "driver: $DRIVER"
echo "sandbox:$SB"

# ── preflight ────────────────────────────────────────────────────────────────
for b in tmux claude python3; do
    command -v "$b" >/dev/null 2>&1 || { bad "$b not on PATH — cannot live-fire"; exit 1; }
done
[ -f "$DRIVER" ] || { bad "driver not found at $DRIVER"; exit 1; }

# ── the sandbox: armed continuous mode, isolated from the real project ───────
# A real project root would let the directive reach real work. This one is empty
# on purpose: the only thing under test is whether a turn is DELIVERED.
mkdir -p "$SB/.context/working" "$SB/.tasks/active" "$SB/bin"
touch "$SB/.framework.yaml"
cat > "$SB/bin/fw" <<SHIM
#!/usr/bin/env bash
exec env PROJECT_ROOT="$SB" FRAMEWORK_ROOT="$PROJ" "$PROJ/bin/fw" "\$@"
SHIM
chmod +x "$SB/bin/fw"
cat > "$SB/.context/working/.continuous-mode.yaml" <<'Y'
enabled: true
current_iteration: 0
tasks_completed: 0
Y

# THE DIRECTIVE AND THE TOKEN ARE DELIBERATELY DIFFERENT STRINGS.
# The reply token must not be a substring of the directive, or leg C would be
# satisfied by the directive's own echo and would prove nothing beyond leg B.
REPLY_TOKEN="BANANA-BANANA"
cat > "$SB/.context/working/.next-directive.yaml" <<'Y'
directive: Reply with only the word BANANA repeated twice joined by a hyphen, and nothing else.
Y
note "directive : $(grep -o 'Reply.*' "$SB/.context/working/.next-directive.yaml")"
note "reply token expected: $REPLY_TOKEN  (NOT a substring of the directive — that is the point)"

run_driver() {  # run_driver <target> <transport>
    PROJECT_ROOT="$SB" timeout 180 bash "$DRIVER" \
        --project-root "$SB" --session "$1" --transport "$2" --settle 2 2>&1
}

# ═══ LEG A — negative control, in the REAL path ══════════════════════════════
hdr "LEG A — a pane that accepts input and echoes nothing (the G-097 shape)"
tmux new-session -d -s "$TM_DEAF" "bash -c 'stty -echo; sleep 600'" >/dev/null 2>&1
sleep 1
if ! tmux has-session -t "$TM_DEAF" 2>/dev/null; then
    bad "could not create the deaf pane — leg A is inconclusive, not negative"
else
    note "pane '$TM_DEAF' runs 'stty -echo; sleep 600': send-keys succeeds, nothing is read or rendered"
    A_OUT="$(run_driver "$TM_DEAF" tmux)"
    A_LED="$(ledger_last)"
    if printf '%s' "$A_LED" | grep -q '"reason": "injected"'; then
        bad "FALSE GREEN — driver recorded 'injected' into a pane that echoed nothing"
        note "$A_OUT"
    elif printf '%s' "$A_LED" | grep -q '"reason": "refused"'; then
        ok "driver REFUSED — the confirmation fires on the real defect, not just on a stub"
        printf '%s' "$A_LED" | grep -o 'UNCONFIRMED[^"]\{0,90\}' | head -1 | sed 's/^/        /'
    else
        bad "driver produced no injected/refused verdict at all"
        note "$A_OUT"
    fi
fi

# ═══ LEG B/C — the real agent ════════════════════════════════════════════════
hdr "LEG B/C — a real Claude TUI, driven by the real driver"
# LAUNCH INTO A CONVERSATION, NOT THE SESSION PICKER.
# Measured 2026-09-05: bare `claude` opens a session-PICKER home screen whose
# input box ("describe a task for a new session") clears on Enter WITHOUT
# starting a turn — text goes in, nothing happens, and the pane retains nothing.
# Driving that screen is neither possible nor meaningful. Passing an initial
# prompt lands directly in a conversation, which is also the realistic target:
# a continuation loop drives a session that is already talking.
tmux new-session -d -s "$TM_AGENT" -c "$SB" -x 200 -y 50 >/dev/null 2>&1
sleep 1
tmux send-keys -t "$TM_AGENT" -l "claude 'reply with the single word ONLINE'" 2>/dev/null
tmux send-keys -t "$TM_AGENT" Enter 2>/dev/null

# Clear the first-run gates (trust folder, MCP server selection) and wait for the
# conversation UI. Each is matched on its own text; a single generic matcher would
# fire on the wrong screen and drive a dialog instead of a prompt.
READY=0
for _i in $(seq 1 50); do
    P="$(squash "$(pane "$TM_AGENT")")"
    case "$P" in
        *"Yes,Itrustthisfolder"*|*"Quicksafetycheck"*)
            note "first-run: trust dialog — accepting (empty sandbox dir)"
            tmux send-keys -t "$TM_AGENT" Enter 2>/dev/null ;;
        *"Selectanyyouwish"*|*"newMCPserversfound"*)
            note "first-run: MCP server dialog — confirming"
            tmux send-keys -t "$TM_AGENT" Enter 2>/dev/null ;;
        *"automodeon"*|*"shift+tabtocycle"*) READY=1; break ;;
    esac
    sleep 3
done
if [ "$READY" != 1 ]; then
    bad "Claude never reached a conversation prompt in ~150s — INCONCLUSIVE, not a negative result"
    note "last pane bytes:"; pane "$TM_AGENT" | grep -v '^$' | tail -6 | sed 's/^/        /'
else
    ok "Claude TUI is up and at an interactive prompt"

    # WAIT FOR QUIET BEFORE DRIVING. The driver refuses a BUSY target by design —
    # injecting into a session mid-answer interleaves input. Right after startup
    # the agent is still finishing its first reply and the token counter is still
    # ticking, so firing here measures the harness's impatience and reports it as
    # a driver failure. Two identical samples = settled.
    QUIET=0; PREV=""
    for _i in $(seq 1 25); do
        CUR="$(squash "$(pane "$TM_AGENT")")"
        if [ -n "$PREV" ] && [ "$CUR" = "$PREV" ]; then QUIET=1; break; fi
        PREV="$CUR"; sleep 3
    done
    [ "$QUIET" = 1 ] && note "target settled (two identical samples) — safe to drive" \
                     || note "target never settled; driving anyway, expect a BUSY refusal"

    # RETRY LIKE CRON DOES. A live TUI has a ticking token counter and a spinner,
    # so it does not reliably hold two byte-identical frames; the driver correctly
    # refuses a BUSY target rather than interleaving input. In production the next
    # cron tick simply tries again. Demanding one perfect instant would make this
    # harness measure luck, so it retries the way the deployment does — and a BUSY
    # refusal is explicitly NOT counted as a delivery failure.
    B_OUT=""; B_LED=""
    for _b in 1 2 3 4 5 6; do
        B_OUT="$(run_driver "$TM_AGENT" tmux)"
        B_LED="$(ledger_last)"
        printf '%s' "$B_LED" | grep -q '"reason": "injected"' && break
        if printf '%s' "$B_LED" | grep -q 'is BUSY'; then
            note "attempt $_b: target BUSY (correct refusal) — retrying as cron would"
            sleep 6; continue
        fi
        break
    done

    if printf '%s' "$B_LED" | grep -q '"reason": "injected"'; then
        ok "LEG B — driver recorded 'injected' with delivery CONFIRMED"
        printf '%s' "$B_LED" | grep -o 'confirmed=[a-zA-Z-]*' | head -1 | sed 's/^/        /'
    else
        bad "LEG B — driver did not confirm delivery into a live Claude TUI"
        note "$B_OUT"
        printf '%s' "$B_LED" | sed 's/^/        /'
    fi

    # ── LEG C — did the agent actually TAKE a turn? ──────────────────────────
    note "waiting for the agent to answer (token '$REPLY_TOKEN' is not in the directive)…"
    GOT=0
    for _i in $(seq 1 40); do
        inpane "$TM_AGENT" "$REPLY_TOKEN" && { GOT=1; break; }
        sleep 3
    done
    if [ "$GOT" = 1 ]; then
        ok "LEG C — agent REPLIED '$REPLY_TOKEN' — a turn was processed, not just text parked"
    else
        bad "LEG C — text was delivered but the agent never produced the computed token"
        note "delivery is not the same as a turn; this is the distinction the leg exists for"
        pane "$TM_AGENT" | tail -8 | sed 's/^/        /'
    fi
fi

# ═══ LEG D — never-sent control ══════════════════════════════════════════════
hdr "LEG D — a token nobody transmitted must be absent (L-653)"
NEVER="NEVERSENT${STAMP}XRAY"
if inpane "$TM_AGENT" "$NEVER"; then
    bad "the pane matcher found a string that was never sent — legs A-C prove nothing"
else
    ok "never-sent token absent — the matcher discriminates"
fi

# ═══ summary ═════════════════════════════════════════════════════════════════
hdr "=== ledger (the artefact that used to lie) ==="
ledger_last "" 8 | python3 -c '
import sys, json
for ln in sys.stdin:
    ln = ln.strip()
    if not ln: continue
    try: d = json.loads(ln)
    except Exception: print("  ?", ln[:120]); continue
    print(f"  {d.get(\"ts\",\"\")}  {d.get(\"reason\",\"\"):<9} {str(d.get(\"detail\",\"\"))[:96]}")
' 2>/dev/null || ledger_last "" 8

hdr "=== RESULT ==="
printf '  passed: %d   failed: %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && printf '  \033[0;32mLIVE-FIRE GREEN\033[0m — the driver delivered a turn to a real agent and refused when it could not.\n'
[ "$FAIL" -ne 0 ] && printf '  \033[0;31mLIVE-FIRE RED\033[0m — see the failing leg(s) above.\n'
[ "$FAIL" -eq 0 ]
