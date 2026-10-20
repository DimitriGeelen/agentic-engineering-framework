#!/usr/bin/env bash
# runme-launcher.sh — the operator's one command, as ONE reviewed launcher (832 T-1055, from the
# T-1054 decision, operator 2026-10-05: option 3).
#
# The operator always types:   bash /opt/832-Workflow-designer/runme.sh   (runme.sh execs this)
#
# WHY: until T-1055 the agent hand-wrote runme.sh per job, re-implementing preflight, y/N prompts,
# logging and signals each time, in the one file the operator runs without reading. An external
# panel (consult t1054-runme-path, 5/5) and a real incident (a second agent copy rewrote runme.sh
# while the operator had been told a different job was waiting, T-1052) showed the safeguards were
# in the wrong place. Now they live HERE, once, tested (tests/test_t1055_runme_launcher.py), and the
# agent writes only a job: data, never safety code.
#
# A JOB is .context/runme/<NNN>-<name>/job.sh. It only DEFINES things (refused otherwise):
#     JOB_TITLE="Upgrade AEF to 1.8.2"      JOB_TASK="T-1049"
#     JOB_WHY="one or more lines the operator reads before anything runs"
#     preflight() { check "on bleeding-edge" '[ "$(git rev-parse --abbrev-ref HEAD)" = bleeding-edge ]'; }
#     steps()     { step "Run the upgrade" 'run_upgrade'; step "Commit it" 'git commit ...'; }
#     run_upgrade() { ... }               # helper functions are fine; they run only inside a step
# Scaffold one with:  bash tools/runme-new.sh <name>
#
# THE SAFEGUARDS (all here, none in the job):
#   --dry-run [name]  the agent's rehearsal: loads the job, runs every check, prints the plan, then
#                     records the job's sha256 in dryrun.ok and makes job.sh read-only.
#   real run          lists pending jobs; when several, the operator picks one or a BATCH in their own order
#                     (T-1227: arrow keys + space on a terminal, or typed: 3,1,2 / x = all), shows name + sha + dry-run
#                     time, REFUSES a job with no dry-run or changed since it, re-runs the checks,
#                     asks y/N (from the terminal only, typeahead discarded) before EVERY step,
#                     logs to the job dir, signals the agent (runme-signal.sh: events + topic, so
#                     tools/runme-watch.sh wakes it), and writes `done`. A done job never runs again.
#   retired           (T-1112) a `retired` file in the job dir (its text = the reason) takes a superseded
#                     job out of the queue without claiming it completed: never offered, never run.
#   menu / --list     (T-1112) one line per job: name, title, state (ready / CHANGED since dry-run /
#                     NOT REHEARSED) and last outcome (never run / completed / STOPPED: <reason>, when).
#
#   bash runme.sh [--dry-run [name]] [--list [--all]]
#   exit 0 = done / nothing to do; 1 = stopped or refused (the reason is printed and logged)
[ -z "${BASH_VERSION:-}" ] && exec bash "$0" "$@"
set -uo pipefail

PROJ=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
REAL_JOBS="$PROJ/.context/runme"
JOBS="${RUNME_JOBS_DIR:-$REAL_JOBS}"
TTY=/dev/tty
if [ -n "${RUNME_TTY:-}" ]; then
    # Answers from a file exist for the test only. On the real job directory they would let a
    # script answer the operator's prompts, which is exactly what this launcher exists to prevent.
    # realpath -m: compare the paths even when the job dir does not exist yet (a cd-based check
    # passed silently on a fresh project — found by the test, leg 11).
    [ "$(realpath -m "$JOBS")" != "$(realpath -m "$REAL_JOBS")" ] || { echo "REFUSED: RUNME_TTY is for tests only, never on $REAL_JOBS"; exit 1; }
    TTY=$RUNME_TTY
fi

say()  { printf '%s\n' "$*"; }
fail() { say "STOPPED: $*"; exit 1; }

# ---------------------------------------------------------------- job loading
CHECK_T=(); CHECK_C=(); STEP_T=(); STEP_C=()
check() { CHECK_T+=("$1"); CHECK_C+=("$2"); }
step()  { STEP_T+=("$1"); STEP_C+=("$2"); }

job_sha() { sha256sum "$1/job.sh" | cut -c1-64; }

load_job() {  # load_job <dir>  — refuses anything but a definitions-only job
    local d=$1 f=$1/job.sh probe
    [ -f "$f" ] || fail "no job.sh in $d"
    bash -n "$f" 2>/dev/null || fail "$(basename "$d")/job.sh does not parse (bash -n)"
    # Load-time side effects: source it with NO usable PATH. A job that only defines things loads
    # silently; one that runs an external command at load time reports "command not found".
    probe=$(env -i PATH=/nonexistent HOME=/nonexistent "$BASH" --norc --noprofile -c \
        'check(){ :; }; step(){ :; }; source "$1"' _ "$f" 2>&1)
    if grep -q 'command not found\|No such file' <<<"$probe"; then
        fail "$(basename "$d")/job.sh runs a command when it is loaded; a job may only define JOB_* variables and functions ($(head -1 <<<"$probe"))"
    fi
    unset JOB_TITLE JOB_WHY JOB_TASK
    unset -f preflight steps 2>/dev/null
    # shellcheck source=/dev/null
    source "$f"
    [ -n "${JOB_TITLE:-}" ] || fail "$(basename "$d")/job.sh sets no JOB_TITLE"
    declare -F steps >/dev/null || fail "$(basename "$d")/job.sh defines no steps()"
    CHECK_T=(); CHECK_C=(); STEP_T=(); STEP_C=()
    declare -F preflight >/dev/null && preflight
    steps
    [ "${#STEP_T[@]}" -gt 0 ] || fail "$(basename "$d")/job.sh steps() registers no step"
}

run_checks() {  # every check runs; any failure fails the whole preflight
    local i bad=0
    for i in "${!CHECK_T[@]}"; do
        if (cd "$PROJ" && eval "${CHECK_C[$i]}") >/dev/null 2>&1; then
            say "ok    ${CHECK_T[$i]}"
        else
            say "FAIL  ${CHECK_T[$i]}"; bad=1
        fi
    done
    [ "${#CHECK_T[@]}" -gt 0 ] || say "(this job declares no preflight checks)"
    return $bad
}

show_plan() {
    local i
    say "Job:   $(basename "$1")   ${JOB_TASK:+($JOB_TASK)}"
    say "What:  $JOB_TITLE"
    [ -n "${JOB_WHY:-}" ] && sed 's/^/       /' <<<"$JOB_WHY"
    say "Steps (each asks y/N first):"
    for i in "${!STEP_T[@]}"; do say "  $((i + 1)). ${STEP_T[$i]}"; done
}

pending() {  # job dirs with a job.sh and no done or retired marker, in number order
    local d
    for d in "$JOBS"/*/; do
        d=${d%/}
        [ -f "$d/job.sh" ] && [ ! -f "$d/done" ] && [ ! -f "$d/retired" ] && echo "$d"
    done 2>/dev/null | sort
}

# T-1112: what the operator needs to choose well, read WITHOUT running the job (sed, never source).
job_state() {
    local d=$1
    [ -f "$d/dryrun.ok" ] || { echo "NOT REHEARSED"; return; }
    [ "$(sed -n 's/^sha=//p' "$d/dryrun.ok")" = "$(job_sha "$d")" ] && echo "ready" || echo "CHANGED since dry-run"
}
job_title() { sed -n 's/^JOB_TITLE="\(.*\)"$/\1/p' "$1/job.sh" | head -1; }
last_outcome() {  # never run | completed <when> | STOPPED <when>: <reason>
    local d=$1 log ts when line why
    log=$(ls -1 "$d"/run-*.log 2>/dev/null | sort | tail -1)
    [ -n "$log" ] || { echo "never run"; return; }
    ts=${log##*/run-}; ts=${ts%.log}
    when="${ts:4:2}-${ts:6:2} ${ts:9:2}:${ts:11:2}"
    if grep -q '^DONE: ' "$log"; then echo "completed $when"; return; fi
    line=$(grep '^STOPPED: ' "$log" | tail -1); line=${line#STOPPED: }
    # a failed step prints its own reason on the line above (after the y/N prompt)
    why=$(grep -B1 '^STOPPED: ' "$log" | tail -2 | head -1 | sed 's/^Run step [0-9]*\/[0-9]*? \[y\/N\] //')
    case "$line" in step*failed*) [ -n "$why" ] && line="$line — $why" ;; esac
    echo "STOPPED $when: ${line:-no outcome recorded (run interrupted?)}"
}
job_line() { local d=$1 t; t=$(job_title "$d"); echo "$(basename "$d")${t:+ — $t}  [$(job_state "$d"); last: $(last_outcome "$d")]"; }

# ---------------------------------------------------------------- terminal answers
open_tty() { exec 3<"$TTY" || fail "cannot read answers from $TTY (run this in a terminal)"; }
ask() {  # ask <prompt> -> REPLY ; discards typeahead from a real terminal first
    local _junk
    if [ "$TTY" = /dev/tty ]; then
        while read -r -t 0.05 -n 10000 _junk <&3 2>/dev/null; do :; done
    fi
    printf '%s ' "$1"
    REPLY=""; read -r REPLY <&3 || REPLY=""
    [ "$TTY" = /dev/tty ] || say "$REPLY"   # echo test answers into the log
}
confirm() { ask "$1 [y/N]"; [ "$REPLY" = y ] || [ "$REPLY" = Y ]; }

# T-1227 (operator 2026-10-20): choose a batch with the arrow keys. up/down (or k/j) moves; space marks or unmarks
# the highlighted job, and its place in the sequence shows beside it; a marks all in listed order; Enter runs the
# marked jobs in marked order (the highlighted one alone when none is marked); t = type numbers instead; q or Esc
# stops. Sets chosen=(); returns 2 for "type instead", 1 for stop. Keys come from fd 3 like every other answer.
use_picker() {
    case "${RUNME_PICKER:-}" in
        0) return 1 ;;
        1) return 0 ;;   # tests: keys fed as bytes through RUNME_TTY
    esac
    [ "$TTY" = /dev/tty ] && [ -t 1 ] && [ "${TERM:-dumb}" != dumb ]
}
pick_jobs() {
    local n=${#todo[@]} cur=0 i k rest pos mark lines=() order=() new _junk
    for i in "${!todo[@]}"; do lines+=("$(job_line "${todo[$i]}")"); done
    if [ "$TTY" = /dev/tty ]; then
        while read -r -t 0.05 -n 10000 _junk <&3 2>/dev/null; do :; done
    fi
    say "Pending jobs: up/down move, space = add to / remove from the batch (the number is its place in the order),"
    say "  a = all in this order, Enter = run (the highlighted job alone if none is marked), t = type numbers, q = stop"
    draw() {
        for i in "${!todo[@]}"; do
            pos=""
            for k in "${!order[@]}"; do [ "${order[$k]}" = "$i" ] && pos=$((k + 1)); done
            [ "$i" = "$cur" ] && mark=">" || mark=" "
            printf '\033[2K%s [%2s] %d. %s\n' "$mark" "$pos" "$((i + 1))" "${lines[$i]}"
        done
    }
    draw
    while :; do
        IFS= read -rsn1 -d '' k <&3 || return 1
        case "$k" in
            $'\033')
                rest=""; IFS= read -rsn2 -t 0.1 -d '' rest <&3
                case "$rest" in
                    '[A') k=up ;; '[B') k=down ;;
                    '') return 1 ;;   # Esc alone
                    *) continue ;;
                esac ;;
        esac
        case "$k" in
            up|k)   [ "$cur" -gt 0 ] && cur=$((cur - 1)) ;;
            down|j) [ "$cur" -lt $((n - 1)) ] && cur=$((cur + 1)) ;;
            ' ')    new=(); for i in "${order[@]}"; do [ "$i" = "$cur" ] || new+=("$i"); done
                    [ "${#new[@]}" -eq "${#order[@]}" ] && new+=("$cur")
                    order=("${new[@]}") ;;
            a|A)    order=(); for i in "${!todo[@]}"; do order+=("$i"); done ;;
            $'\n'|$'\r')
                    [ "${#order[@]}" -gt 0 ] || order=("$cur")
                    chosen=(); for i in "${order[@]}"; do chosen+=("${todo[$i]}"); done
                    say "Chosen, in this order: $(for i in "${order[@]}"; do printf '%d ' "$((i + 1))"; done)"
                    return 0 ;;
            t|T)    return 2 ;;
            q|Q)    return 1 ;;
            *)      continue ;;
        esac
        printf '\033[%dA' "$n"
        draw
    done
}

# T-1227: the typed form. "x" (or all) runs every pending job in this order; "3,1,2" (or "3 1 2", "3, 1") runs exactly
# those, in the order typed; one number runs that job alone. Each job still asks y/N per step.
type_jobs() {
    local i p sel seen picks
    say "Pending jobs:"
    for i in "${!todo[@]}"; do say "  $((i + 1)). $(job_line "${todo[$i]}")"; done
    ask "Which job? [1-${#todo[@]}; several in your order, e.g. 3,1,2; x = all in this order; anything else = stop]"
    sel=$(tr 'A-Z' 'a-z' <<<"$REPLY" | sed -E 's/[[:space:];,]+/,/g; s/^,+//; s/,+$//')
    chosen=()
    if [ "$sel" = x ] || [ "$sel" = all ] || [ "$sel" = '*' ]; then
        chosen=("${todo[@]}")
    elif [[ "$sel" =~ ^[0-9]+(,[0-9]+)*$ ]]; then
        IFS=, read -ra picks <<<"$sel"
        seen=" "
        for p in "${picks[@]}"; do
            p=$((10#$p))
            { [ "$p" -ge 1 ] && [ "$p" -le "${#todo[@]}" ]; } || fail "there is no job $p in the list; nothing run"
            case "$seen" in *" $p "*) fail "job $p was chosen twice; nothing run" ;; esac
            seen="$seen$p "; chosen+=("${todo[$((p - 1))]}")
        done
    else
        fail "no job chosen; nothing run"
    fi
}

# ---------------------------------------------------------------- modes
mode=run; name=""
case "${1:-}" in
    --dry-run) mode=dry; name=${2:-} ;;
    --list)    mode=list; [ "${2:-}" = --all ] && mode=listall ;;
    "")        ;;
    -h|--help) sed -n '2,32p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *)         fail "unknown argument: $1 (use --dry-run [name], --list [--all], or nothing)" ;;
esac

if [ "$mode" = list ]; then
    found=0
    while read -r d; do
        [ -n "$d" ] || continue; found=1
        say "$(job_line "$d")"
    done < <(pending)
    [ "$found" = 1 ] || say "no pending jobs"
    exit 0
fi
if [ "$mode" = listall ]; then   # every job, with done / retired named
    for d in $(ls -d "$JOBS"/*/ 2>/dev/null | sort); do
        d=${d%/}; [ -f "$d/job.sh" ] || continue
        if [ -f "$d/retired" ]; then say "$(basename "$d")  [RETIRED: $(head -1 "$d/retired")]"
        elif [ -f "$d/done" ]; then say "$(basename "$d")  [done]"
        else say "$(job_line "$d")"; fi
    done
    exit 0
fi

if [ "$mode" = dry ]; then
    mapfile -t todo < <(if [ -n "$name" ]; then ls -d "$JOBS"/*"$name"* 2>/dev/null; else pending; fi)
    [ "${#todo[@]}" -gt 0 ] || { say "dry-run: no pending job${name:+ matching '$name'}"; exit 0; }
    rc=0
    for d in "${todo[@]}"; do
        say "== DRY RUN $(basename "$d")"
        load_job "$d"
        show_plan "$d"
        if run_checks; then
            sha=$(job_sha "$d")
            chmod u+w "$d" 2>/dev/null
            printf 'sha=%s\nat=%s\n' "$sha" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$d/dryrun.ok"
            chmod a-w "$d/job.sh"
            say "dry-run passed: job.sh sha ${sha:0:12} recorded, job.sh now read-only. Nothing was run."
        else
            rm -f "$d/dryrun.ok"; rc=1
            say "dry-run FAILED: preflight did not pass; no dryrun.ok written."
        fi
    done
    exit $rc
fi

# ---- real run
mapfile -t todo < <(pending)
[ "${#todo[@]}" -gt 0 ] || { say "Nothing to run: no pending job in $JOBS."; exit 0; }
open_tty
chosen=()
if [ "${#todo[@]}" -eq 1 ]; then
    chosen=("${todo[0]}")
else
    # The arrow-key picker on a real terminal (T-1227); typed numbers otherwise, or when the operator presses t.
    prc=2
    if use_picker; then pick_jobs; prc=$?; [ "$prc" = 1 ] && fail "no job chosen; nothing run"; fi
    [ "$prc" = 2 ] && type_jobs
fi

# T-1227: a batch is refused BEFORE anything runs when any chosen job is not rehearsed or changed since its dry run,
# so it can never stop half way for a reason that was knowable at the start.
if [ "${#chosen[@]}" -gt 1 ]; then
    bad=""
    for d in "${chosen[@]}"; do
        if [ ! -f "$d/dryrun.ok" ]; then bad="$bad $(basename "$d") (not rehearsed);"
        elif [ "$(sed -n 's/^sha=//p' "$d/dryrun.ok")" != "$(job_sha "$d")" ]; then bad="$bad $(basename "$d") (CHANGED since its dry-run);"; fi
    done
    if [ -n "$bad" ]; then
        . "$PROJ/tools/runme-signal.sh"; runme_signal STOPPED "batch refused:$bad"
        fail "batch refused before anything ran:$bad the agent must dry-run those jobs again."
    fi
    say "Batch of ${#chosen[@]}, in this order: $(for d in "${chosen[@]}"; do printf '%s ' "$(basename "$d")"; done)"
    say "Each job still asks y/N before every step; the batch stops at the first job that does not complete."
fi

run_one() {  # run_one <job dir> — one job, end to end; runs in a subshell so its own stop/exit ends only it
    local d=$1 sha dsha dat i n
    RUNME_RUN_ID="runme-$(date +%Y%m%dT%H%M%S)-$BASHPID"   # one id per job, also inside a batch
    # Log and signal BEFORE the refusals below, so a refused run still wakes the agent (STOPPED event).
    sha=$(job_sha "$d")
    TS=$(date +%Y%m%dT%H%M%S)
    LOG="$d/run-$TS.log"
    chmod u+w "$d" 2>/dev/null
    touch "$LOG" 2>/dev/null || fail "cannot write $LOG"
    exec > >(tee -a "$LOG") 2>&1
    . "$PROJ/tools/runme-signal.sh"
    runme_signal_init "$(basename "$d") [sha ${sha:0:12}]" "$LOG"

    [ -f "$d/dryrun.ok" ] || fail "$(basename "$d") has not been rehearsed (no dryrun.ok). Nothing run. The agent runs: bash runme.sh --dry-run $(basename "$d")"
    dsha=$(sed -n 's/^sha=//p' "$d/dryrun.ok"); dat=$(sed -n 's/^at=//p' "$d/dryrun.ok")
    [ "$sha" = "$dsha" ] || fail "$(basename "$d")/job.sh CHANGED since its dry-run (now ${sha:0:12}, rehearsed ${dsha:0:12}). Nothing run; the agent must dry-run it again."
    load_job "$d"
    # T-1204: steps sign with 832's own TermLink key (T-1203). A job can restart a daemon that then inherits this
    # shell's env: job 048's fw upgrade restarted the sidecar receiver on 2026-10-18 from a terminal without the
    # variable, and mail went out under the shared host key again. Exported only when the key file EXISTS: termlink
    # MINTS a key at a missing TERMLINK_IDENTITY_FILE path (T-1151), so a lost key unsets it instead.
    RUNME_KEY="${RUNME_IDENTITY_KEY:-$PROJ/.context/secrets/termlink-identity.key}"   # override: tests only
    if [ -f "$RUNME_KEY" ]; then export TERMLINK_IDENTITY_FILE="$RUNME_KEY"; else unset TERMLINK_IDENTITY_FILE; fi
    # T-1203: termlink >= 0.12.786 (010 T-3467) refuses to mint ANY key under this, the host key included; an
    # existing key loads as before. Set whatever the key file says, so no step can create an identity by accident.
    export TERMLINK_IDENTITY_NO_CREATE=1
    say "runme  $(basename "$d")   sha ${sha:0:12}   rehearsed $dat   log: $LOG"
    show_plan "$d"
    say
    run_checks || fail "preflight failed (state changed since the dry-run?); nothing run"
    n=${#STEP_T[@]}
    for i in "${!STEP_T[@]}"; do
        say
        say "Step $((i + 1))/$n: ${STEP_T[$i]}"
        say "  runs: ${STEP_C[$i]}"
        confirm "Run step $((i + 1))/$n?" || fail "not confirmed at step $((i + 1))/$n; steps before it ran, nothing after"
        runme_signal step "$((i + 1))/$n ${STEP_T[$i]}"
        (cd "$PROJ" && eval "${STEP_C[$i]}") || fail "step $((i + 1))/$n failed (rc=$?); later steps not run"
        say "ok    step $((i + 1))/$n"
    done
    chmod u+w "$d" 2>/dev/null
    printf 'at=%s\nsha=%s\nlog=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$sha" "$(basename "$LOG")" > "$d/done"
    say
    say "DONE: $(basename "$d") — all $n step(s) ran. rc=0  (log: $LOG)"
}

completed=(); rc=0; stopped=""
for d in "${chosen[@]}"; do
    ( run_one "$d" ); rc=$?
    if [ "$rc" -ne 0 ]; then stopped=$(basename "$d"); break; fi
    completed+=("$(basename "$d")")
done
if [ "${#chosen[@]}" -gt 1 ]; then
    sleep 0.2   # let the last job's log tee flush before the summary
    say
    say "BATCH: ${#completed[@]} of ${#chosen[@]} completed${completed[*]:+ (${completed[*]})}${stopped:+; STOPPED at $stopped, the rest not started}."
fi
exit $rc
