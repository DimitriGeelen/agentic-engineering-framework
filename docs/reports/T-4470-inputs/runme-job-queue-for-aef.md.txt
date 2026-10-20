# The runme job queue: one operator command, rehearsed jobs, and a signal that wakes the agent

**From:** 832-Workflow-designer, for inclusion in the framework (AEF). **Status:** in daily use in 832 since 2026-10-05
(T-1055), 56 jobs so far: framework upgrades, designer releases, re-keying the TermLink stack, Tier-0 inception
decisions. **Code:** 5 small files, ~540 lines (the launcher ~370 of them), plus 2 tests (~400 lines). Paths below are 832's.
Code excerpts below are real code, condensed (lines joined, long messages cut with `...`); the files are the
reference: `runme.sh`, `tools/runme-{launcher,signal,watch,new}.sh`, `tests/test_t1055_runme_launcher.py`,
`tests/test_t1003_runme_signal.sh`.

## 1. What problem it solves

When the agent needs the operator to run something (a release, an upgrade, a Tier-0 decision, anything outside the
agent's authority), the naive form is a command pasted into chat, or a script the agent writes per job. Both fail in
ways we hit in practice:

- **The operator runs what they do not read.** A per-job script is rewritten every time; its safety code (preflight,
  confirmation, logging) is re-implemented each time, in the one file nobody reviews.
- **A second agent copy rewrote the script** while the operator had been told a different job was waiting (T-1052).
- **The agent cannot see the run.** Without a signal it polls, or waits for the operator to paste the output back.
- **Typeahead answered a prompt** that had not been asked yet: keys pressed during a 10-minute hook confirmed the next
  step the instant it appeared (2026-10-02).
- **Several jobs pile up** and the operator cannot tell which is ready, which changed, which failed last time.

The design answer (operator decision T-1054, option 3; an external review panel agreed 5/5): **safety lives once, in a
tested launcher; the agent writes only data (a job); the operator always types the same single command.**

## 2. The operator's side

The operator always runs exactly one command, from any directory:

    bash /opt/832-Workflow-designer/runme.sh

What they see, when several jobs are pending:

    Pending jobs:
      1. 054-decide-t1219-go — Record the GO on inception T-1219 ...  [ready; last: never run]
      2. 055-upgrade-aef-be-89c4823f3 — Upgrade AEF v1.8.12 -> ...      [ready; last: never run]
      3. 056-decide-t1215-go — Record the GO on inception T-1215 ...     [ready; last: never run]
    Which job? [1-3; several in your order, e.g. 3,1,2; x = all in this order; anything else = stop]

On a real terminal the operator does not even type: an **arrow-key picker** (T-1227) shows the same list with a
cursor. Up/down moves, space adds the highlighted job to the batch or takes it out, and the number in its brackets
is its place in the sequence; `a` marks all; Enter runs the marked jobs in marked order (the highlighted one alone
if none is marked); `t` switches to typing numbers; `q` or Esc stops. Captured from a real terminal after
down, down, space, up, up, space:

    > [ 2] 1. 001-release-designer — ...  [ready; last: never run]
      [  ] 2. 002-upgrade-aef — ...       [ready; last: never run]
      [ 1] 3. 003-decide-t1215 — ...      [ready; last: never run]

Enter then prints `Chosen, in this order: 3 1` and runs job 3, then job 1.

**Batches, in the operator's order (T-1227, operator request 2026-10-20).** One number runs one job, as before.
`x` (or `all`) runs every pending job in the listed order. `3,1,2` (also `3 1 2` or `3, 1`) runs those jobs in the
order typed, so the operator sets the priority. The rules: each job keeps its own y/N per step; the batch stops at the
first job that does not complete, and the rest are not started; the whole batch is refused before anything runs if any
chosen job is not rehearsed or has changed since its dry run; each job keeps its own log, `done` file and events; the
run ends with one line, `BATCH: 1 of 3 completed (056-decide-t1215-go); STOPPED at 054-decide-t1219-go, the rest not started.` A typo
(`1,5` out of range, `2,2` repeated) stops with nothing run.

Then for the chosen job: its name, the job file's sha256 and when it was rehearsed, the title and the WHY in plain
language, the numbered step list, the preflight checks re-run live, and a **y/N before every step**. Everything is
logged to the job's directory. A finished job writes `done` and is never offered again. The other states:
`CHANGED since dry-run` (refused), `NOT REHEARSED` (refused), `last: STOPPED <when>: <reason>`.

## 3. The agent's side

1. `bash tools/runme-new.sh <name>` scaffolds `.context/runme/<NNN>-<name>/job.sh` (NNN = next free number).
2. The agent fills the job: **definitions only.**
3. `bash runme.sh --dry-run <NNN>-<name>`: loads the job, runs every preflight check, prints the plan, records the job's
   sha256 in `dryrun.ok`, and makes `job.sh` read-only. **The agent runs only this, never a real run.**
4. Commit the job directory; hand the operator the one command (and say which job to pick).
5. Arm `bash tools/runme-watch.sh` as a **background** task. It exits on the first new event, which wakes the agent; the
   agent reads the log, acts, and re-arms it.

A job that has to be replaced is never edited after hand-over: it gets a `retired` file whose text is the reason, and
a new job is written. `--list --all` shows retired and done jobs.

## 4. The job format (data, not safety code)

```bash
# .context/runme/056-decide-t1215-go/job.sh
JOB_TITLE="Record the GO on inception T-1215 (plain bpmn:task: AEF accepts it, option a)"
JOB_TASK="T-1215"
JOB_WHY="The framework classes an inception decision as Tier 0, so it is yours to record. The independent reviewer
judged the go/no-go green ... If you disagree, do not run it; tell the agent, and it records NO-GO or DEFER instead."

RATIONALE="Reviewer green (2026-10-20). ..."

preflight() {
    check "T-1215 is an active inception"       'grep -q "^workflow_type: inception" .tasks/active/T-1215-*.md'
    check "no decision is recorded on T-1215 yet" '! grep -q "^\*\*Decision\*\*:" .tasks/active/T-1215-*.md'
    check "the reviewer verdict on T-1215 is green" 'grep "\"T-1215\"" .context/reviews/verdicts.jsonl | tail -1 | grep -q "\"verdict\": *\"green\""'
}

steps() {
    step "Record GO on T-1215 (fw inception decide)" '.agentic-framework/bin/fw inception decide T-1215 go --rationale "$RATIONALE"'
}
```

`check "<what>" '<cmd>'` and `step "<what>" '<cmd>'` only register; the launcher runs them. Helper functions are allowed
and run only inside a step. Larger jobs (a framework upgrade: doctor before/after, clone, pristine vendor commit,
divergence baseline) use the same two verbs with helpers.

## 5. The launcher's safeguards (tools/runme-launcher.sh, ~370 lines)

**Definitions-only, enforced at load.** A job that runs anything when sourced is refused: the launcher first sources it
with no usable PATH, so a definitions-only file loads silently and anything else reports "command not found".

```bash
probe=$(env -i PATH=/nonexistent HOME=/nonexistent "$BASH" --norc --noprofile -c \
    'check(){ :; }; step(){ :; }; source "$1"' _ "$f" 2>&1)
if grep -q 'command not found\|No such file' <<<"$probe"; then
    fail "$(basename "$d")/job.sh runs a command when it is loaded; a job may only define JOB_* variables and functions"
fi
```

**Rehearsal bound to the exact bytes.** The dry run records the sha256; the real run refuses a job that was never
rehearsed or changed since:

```bash
printf 'sha=%s\nat=%s\n' "$sha" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$d/dryrun.ok"; chmod a-w "$d/job.sh"   # dry run
...
[ -f "$d/dryrun.ok" ] || fail "... has not been rehearsed (no dryrun.ok). Nothing run."
[ "$sha" = "$dsha" ]  || fail "... CHANGED since its dry-run (now ${sha:0:12}, rehearsed ${dsha:0:12}). Nothing run."
```

**Answers only from the terminal, typeahead discarded.** Every prompt reads from `/dev/tty` (never stdin, so nothing
can be piped in), and drains the buffer first:

```bash
ask() {
    if [ "$TTY" = /dev/tty ]; then
        while read -r -t 0.05 -n 10000 _junk <&3 2>/dev/null; do :; done   # discard keys pressed earlier
    fi
    printf '%s ' "$1"; REPLY=""; read -r REPLY <&3 || REPLY=""
}
confirm() { ask "$1 [y/N]"; [ "$REPLY" = y ] || [ "$REPLY" = Y ]; }
```

A test-only override (`RUNME_TTY`, answers from a file) is refused on the real job directory, so no script can answer
the operator's prompts.

**Preflight re-run live** before step 1 (state may have changed since the rehearsal); any failure stops with nothing run.

**Per-step confirmation, stop on first failure,** the reason printed and logged:

```bash
for i in "${!STEP_T[@]}"; do
    say "Step $((i + 1))/$n: ${STEP_T[$i]}"; say "  runs: ${STEP_C[$i]}"
    confirm "Run step $((i + 1))/$n?" || fail "not confirmed at step $((i + 1))/$n; steps before it ran, nothing after"
    runme_signal step "$((i + 1))/$n ${STEP_T[$i]}"
    (cd "$PROJ" && eval "${STEP_C[$i]}") || fail "step $((i + 1))/$n failed (rc=$?); later steps not run"
done
printf 'at=%s\nsha=%s\nlog=%s\n' "..." "$sha" "$(basename "$LOG")" > "$d/done"
```

**Logging and the signal start BEFORE the refusals,** so even a refused run leaves a log and wakes the agent.

**The menu** reads each job's state without running it (sed, never source): `ready` / `CHANGED since dry-run` /
`NOT REHEARSED`, and the last outcome parsed from the newest log (`never run`, `completed <when>`,
`STOPPED <when>: <reason>`), the failing step's own message included.

**Identity for steps (project-specific, worth generalising):** steps sign TermLink posts with the project's key, and the
variable is exported only when the key file exists, because TermLink creates a key at a missing path:

```bash
RUNME_KEY="${RUNME_IDENTITY_KEY:-$PROJ/.context/secrets/termlink-identity.key}"
if [ -f "$RUNME_KEY" ]; then export TERMLINK_IDENTITY_FILE="$RUNME_KEY"; else unset TERMLINK_IDENTITY_FILE; fi
```

**Batch selection** parses the answer into an ordered list, refuses the whole batch up front if any job is unready,
then runs each job in its own subshell (its own run id, log, traps and `done`), stopping at the first that fails:

```bash
# typed form (type_jobs): "3, 1" -> "3,1"; x / all / * = every pending job; numbers kept in the order typed
sel=$(tr 'A-Z' 'a-z' <<<"$REPLY" | sed -E 's/[[:space:];,]+/,/g; s/^,+//; s/,+$//')
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

# picker (pick_jobs): one key at a time from the answers fd; arrows arrive as ESC [ A / ESC [ B
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
# ...space toggles the highlighted index in order=(); the screen is redrawn in place with ESC [ <n> A

# the batch: each job in its own subshell, so a job's own stop ends only that job
for d in "${chosen[@]}"; do
    ( run_one "$d" ); rc=$?
    if [ "$rc" -ne 0 ]; then stopped=$(basename "$d"); break; fi
    completed+=("$(basename "$d")")
done
```

## 6. The signal that wakes the agent (tools/runme-signal.sh, ~60 lines)

The launcher sources it. Each event is one line, `<utc> <run-id> <event> <text>` with event `started | step | done |
STOPPED`, written to two places: a local file (`.context/working/runme.events`, always) and a TermLink topic
(`runme-832`, best effort: detached, 5 s timeout, never slows or breaks the run). `done` and `STOPPED` come from traps, so
Ctrl-C, SIGTERM and a closed terminal are reported too:

```bash
runme_signal() {  # runme_signal <event> <text...>
    local ev="$1"; shift; local line="$(date -u +%Y-%m-%dT%H:%M:%SZ) $RUNME_RUN_ID $ev $*"
    { mkdir -p "$(dirname "$RUNME_EVENTS_FILE")" && printf '%s\n' "$line" >> "$RUNME_EVENTS_FILE"; } 2>/dev/null || true
    if command -v termlink >/dev/null 2>&1 && [ -f "$RUNME_SIGNAL_KEY" ]; then
        ( TERMLINK_IDENTITY_FILE="$RUNME_SIGNAL_KEY" setsid timeout 5 termlink channel post "$RUNME_SIGNAL_TOPIC" \
              --ensure-topic --msg-type runme-event --payload "$line" >/dev/null 2>&1 & ) 2>/dev/null || true
    fi
    return 0
}
runme_signal_init() {
    runme_signal started "$1${2:+ — log: $2}"
    trap '_rc=$?; if [ "$_rc" = 0 ]; then runme_signal done "rc=0"; else runme_signal STOPPED "rc=$_rc"; fi' EXIT
    trap 'runme_signal STOPPED "interrupted (Ctrl-C)"; trap - INT EXIT; kill -INT $$' INT
    trap 'runme_signal STOPPED "terminated (SIGTERM)"; trap - TERM EXIT; kill -TERM $$' TERM
    trap 'runme_signal STOPPED "terminal closed (SIGHUP)"; trap - HUP EXIT; kill -HUP $$' HUP
}
```

The events file's location comes from the script's own path, not the caller's cwd (a release run from another
directory once reached only the topic).

## 7. The watcher (tools/runme-watch.sh, ~60 lines)

The agent arms it as a background task. It notes where the events file and the topic stand, then exits printing the new
event line(s) as soon as either moves. **Its exit is what wakes the agent** (a background task's completion re-invokes
it; a message alone does not, since mail is read only at the next prompt).

```bash
f0=$(lines); t0=<current topic offset>
while [ "$LIMIT" -eq 0 ] || [ $(( $(date +%s) - start )) -lt "$LIMIT" ]; do
    f=$(lines)
    if [ "$f" -gt "$f0" ]; then echo "runme event (file):"; tail -n +"$((f0 + 1))" "$FILE"; rm -f "$WATCH"; exit 0; fi
    new=$(timeout 20 termlink channel subscribe "$TOPIC" --cursor "$t0" --limit 50 | grep -E '^\[[0-9]+\]' | grep -F " $LABEL ")
    [ -n "$new" ] && { echo "runme event (topic $TOPIC):"; echo "$new"; rm -f "$WATCH"; exit 0; }
    sleep 3
done
```

Two lessons are built in:

- **Only this project's posts count.** Another project's copy of the script, topic name baked in, posted
  `STOPPED rc=1` to our topic and woke us for a run that was not ours; TermLink labels each post with the poster's
  project, and the watcher filters on that label.
- **A watch dies with the session that armed it.** It records who armed it (`.context/working/runme.watch`: watch pid,
  claude pid); the session-start alerts print **WATCH LOST** when that session is gone, so a new session re-arms it
  before anything else.

No default time limit: a background watch already ends with its session, and an 8-hour cap only ended the watch while a
run could still come.

## 8. Tests

- `tests/test_t1055_runme_launcher.py` (26 legs; 21-25 drive the picker with the keys fed as bytes: marked order,
  `a`, Enter on an unmarked list, `t` to type, `q`/Esc/no more keys; 16-20 are the typed batch: `x` keeps the listed order, `3, 1` keeps the
  typed order, a batch stops at its failing job, a CHANGED job refuses the whole batch up front, `1,5` and `2,2`
  run nothing): refuses a job that runs a command at load; refuses no dry-run and a
  changed job; dry run records the sha and makes the job read-only; y/N per step, a "no" stops with nothing after;
  a failing step stops; `done` written and never re-run; `retired` leaves the queue; numbered choice when several are
  pending; the test-only TTY override is refused on the real job directory (found by the test on a fresh project);
  the identity key is exported only when it exists.
- `tests/test_t1003_runme_signal.sh` (11 legs): a fake job emits started/step/done and a failing one STOPPED; the
  watcher, started first, exits on the first event in both; with the hub unreachable the file path still works and the
  run is not slowed; another project's post does not wake the watcher; the events file follows the script's location.

## 9. How it relates to AEF's `fw runme`

AEF's standing rule (T-3675, "Operator Commands Ship as ONE runme.sh Line") generates `.context/runme/<name>/runme.sh`
per job, with `set -euo pipefail`, echoed commands and a timestamped `run.log`, and `fw runme watch <name>` follows the
log. 832's rule overrides it in 832's CLAUDE.md. The differences, which are what we propose for the framework:

| | AEF `fw runme` today | 832 runme queue |
|---|---|---|
| operator's command | a different `runme.sh` path per job | always the same one; a menu when several are pending |
| several jobs | one at a time, one path each | a batch in the operator's order (`x`, `3,1,2`), stops at the first failure |
| safety code | in each generated script | once, in a tested launcher; jobs are data |
| rehearsal | none | dry run required; sha-bound; job read-only after |
| per-step consent | none (runs through) | y/N per step, from the terminal, typeahead discarded |
| preflight | none | declared checks, run at rehearsal and again live |
| agent wake-up | `fw runme watch` follows a log | events file + TermLink topic; background watcher exits on the event |
| state | `run.log` exists or not | ready / CHANGED / NOT REHEARSED / done / retired / last outcome |
| interruption | `RUNME EXIT <code>` | STOPPED event from EXIT/INT/TERM/HUP traps |

## 10. Proposal for the framework

1. A `fw runme` launcher equivalent to `tools/runme-launcher.sh`, with the job dir convention
   `.context/runme/<NNN>-<name>/{job.sh, dryrun.ok, run-<ts>.log, done | retired}`, and verbs
   `fw runme new <name>`, `fw runme dry-run [name]`, `fw runme list [--all]`, and the operator's `fw runme` (or a
   one-line project `runme.sh` stub that execs it, as 832 has).
2. `fw runme watch` becomes the background watcher: events file + a per-project topic, filtered by project label,
   records its armer, and the session-start check reports WATCH LOST.
3. The signal library sourced by the launcher; the identity export only when the project key file exists.
4. The CLAUDE.md rule rewritten around it: the agent writes jobs and runs only `--dry-run`; the operator types one
   command; a changed job is retired and rewritten, never edited after hand-over.
5. The two test suites carried over.

**Further improvements we have NOT built (the operator raised the first one, 2026-10-20), for AEF to weigh:**

6. **Parallel runs.** Held back on purpose: every job asks y/N per step on the one terminal, so two jobs at once
   would interleave their prompts, and most real jobs (upgrades, releases, commits) change the same repository. A
   safe form: an opt-in `JOB_PARALLEL_SAFE=1` for jobs with no prompts and no writes outside their own job
   directory (read-only checks, reports), run concurrently only with each other, each with its own log and events,
   the batch summary waiting for all of them.
7. **Resume a stopped batch.** A batch that stops leaves the jobs it did not start pending; the operator picks them
   again. A `--resume` offering exactly the not-started remainder, in the same order, would save that step.
8. **Batch-level events.** Each job signals on its own; one `batch started` / `batch done <k> of <n>` pair would let
   the watcher wake once per batch instead of once per job.

832 is happy to send the four files and both tests as a patch against the framework tree, or to review AEF's port.
