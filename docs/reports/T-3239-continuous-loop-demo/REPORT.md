# arc-012 headline mechanic — what is actually proven

**Task:** T-3239 · **Arc:** continuous-run (arc-012) · **Date:** 2026-09-01
**Artefacts:** `evidence/` (raw logs and transcripts, re-readable without re-running)
**Harnesses:** `brake-truth-table.sh`, `live-fire-m1.sh`, `budget-selftrigger.sh`, `resume-injection.sh`,
`livefire-m2-termlink.sh`, `arc-focus-crossing.sh`, `livefire-budget-trip.sh`, `livefire-budget-restart.sh`

The arc's `headline_mechanic` reads:

> agent crosses the context-budget threshold without operator relay → checkpoint.sh
> fires self-trigger → handover + resume via claude-fw → operator observes multi-cycle
> continuous session whose iteration counter, directive, and bounded tier-ceiling are
> visible in `fw resume status`

`demo_evidence:` was empty, so `fw arc close` had nothing to gate on. This is that evidence.

---

## The distinction everything else depends on (L-652)

The sentence above bundles **two different mechanisms**, and they fail independently:

| | **M1 — Stop-hook turn driver** | **M2 — budget compact-resume** |
|---|---|---|
| what it does | drives another **turn** inside one session | ends the session, **restarts** it, re-injects the directive |
| entry point | `Stop` hook → `agents/context/stop-driver.sh` | budget critical → `budget-gate.sh` → `.restart-requested` → `claude-fw` |
| counter | none — advances nothing | `current_iteration`, advanced once per SessionStart |
| bounded by | halt file, `stop_hook_active` | `max_iterations`, `max_tasks`, expiry, tier ceiling |

L-652 already warned these "look like one in the ledger". Every claim below names which one it is about. **No line of evidence here is allowed to stand for both.**

---

## Verdict per link

| link | mechanism | status | evidence |
|---|---|---|---|
| Stop hook fires and decides | M1 | **PROVEN** | E1, E2 |
| every brake fires by name | M1 | **PROVEN** (11/11) | E1 |
| loop drives another turn | M1 | **PROVEN — exactly one** | E2 |
| loop drives *many* turns | M1 | **DISPROVEN** | E2 |
| budget threshold self-triggers | M2 | **PROVEN when measurable** | E3-A |
| …and when not measurable | M2 | **FAILS OPEN, silently** | E3-B/C |
| resume advances the counter | M2 | **PROVEN** | E4 |
| directive re-injected with ceiling | M2 | **PROVEN** | E4 |
| exit → wrapper relaunches a REAL claude | M2 | **PROVEN — live fire** | E5 |
| arc focus survives a restart | M2 | **PROVEN** (4/4) | E6 |
| iteration + tier ceiling survive a restart | M2 | **PROVEN** (4/4) | E6 |
| budget threshold → restart, on a real session | M2 | **PROVEN** (6/6, 3/3 runs) | E8 |
| …on a session shorter than the gauge's own dials | M2 | **DISPROVEN** | E7, E8 |

Every link is now measured. The last one to fall was the headline mechanic itself
(E8); the row beneath it is the honest qualifier — the trip fires, but only on a
session long enough for the gauge's own dials to let it look. Nothing here is
assumed from the links either side of it, which is the whole discipline this arc
exists to enforce.

---

## E1 — every brake fires, by name (11/11)

`brake-truth-table.sh` drives the real driver against a throwaway project root, one row per brake. It asserts the **stdout shape**, not the log line: T-3163 measured that `{"decision":"block"}` drives a turn while `{"ok": false}` is silently inert *and logs identically*. A harness checking only the log would certify a driver that drives nothing.

All eleven rows matched: `halt-file`, `stop_hook_active`, `continuous-mode-disabled`, `terminated[stored@…]`, `max_tasks-reached(3>=3)`, `max_iterations-reached(11>10)`, `expired-at`, `no state file`, `state-unreadable-or-empty`, plus both continue paths.

**No brake is reported as working on the strength of reading it.** T-3228's fix is visible here too: row 05 emits `terminated[stored@2026-08-26T12:50:35Z]` — one clock per line, the stored one labelled.

## E2 — the loop drives exactly ONE continuation

A real `claude -p` session, isolated sandbox, real driver. The live repo was never armed: arming it to test the loop would hand the operator's own session to the loop, which is what the driver's DISARMED-BY-DEFAULT posture exists to prevent.

```
control (disarmed): 1 assistant turn,  0 continue, 1 stop   continuous-mode-disabled
armed:              5 assistant turns, 1 continue, 1 stop
```

The armed run's log, verbatim:

```
2026-09-01T07:23:27Z decision=continue reason=iteration-1
2026-09-01T07:23:40Z decision=stop reason=stop_hook_active=true (platform runaway guard)
```

**Brake 3a is checked before every one of our own caps** (`stop-driver.sh:87-101`), and Claude Code sets `stop_hook_active` on any stop following a hook-driven continuation. So the second stop of *any* run yields there, always. Expiry, `max_tasks` and the tier ceiling are never reached inside a session.

The driver's own header states the opposite intent — *"our counter is meant to stop the loop first, leaving the vendor's cap as the backstop we did not write"*. That intent is not met, and it cannot be met, because the counter it refers to (`current_iteration`) advances only at SessionStart, which by construction never fires inside a session.

**This is not a bug to quietly fix.** Honouring `stop_hook_active` is precisely what stops a bug in our own counter from becoming an unbounded loop. Widening it is a sovereignty decision and needs a real in-session turn counter to bound it. Filed as **T-3240** (inception, owner human).

**Fixed here:** `fw continuous arm` told the operator *"Binding a Stop-hook-driven run: expiry and max tasks"*. Measured, neither can bind. `lib/continuous-mode.sh` now states the measured truth — one continuation, then the platform guard.

## E3 — the self-trigger fails open when it cannot measure

Two transcripts, **identical 400,000-token volume**, 100,000-token window. They differ in exactly one property: whether `lib/context_tokens.py` can scope the transcript to a dominant model.

| case | gauge reads | gate exit | `.restart-requested` | `.budget-status` |
|---|---|---|---|---|
| A scopeable | 400000 | **2 — blocked** | **yes** | `{"level":"critical","tokens":400000}` |
| B 1 entry | **0** | 0 | **no** | `{"level":"ok","tokens":0}` |
| C no transcript | n/a | 0 | no | *(file not written at all)* |

`context_tokens.py` returns 0 by design below two in-scope entries — *"return 0 rather than guess"* — and `budget-gate.sh` maps 0 to `ok`. So **"I could not measure this session" and "this session is fresh" produce byte-identical output.** Nothing anywhere says the measurement failed.

This **confirms review finding W1-F5**, which the T-3227 synthesis had downgraded to *plausible* for want of reproduction, and locates it one level deeper than the review did: the scoping rule, not `budget-gate`'s regex fallback. Filed as **T-3241** — the fix needs a third state (`unknown`) distinct from 0, surfaced at every consuming gauge, which is more blast radius than belongs in a demo task.

## E4 — the resume end works (4/4)

| case | `current_iteration` | outcome |
|---|---|---|
| armed, `--source resume` | 3 → **4** | directive re-injected, `## Next Directive (iteration 4/10, tier_ceiling 1)` |
| armed, `--source compact` | 3 → **1** | operator `/compact` starts a fresh run |
| disarmed | 3 → **3** | frozen — the control leg |
| expired directive | 3 → **4** | `LOOP TERMINATED`, reason recorded |

**One correction, made by measuring.** The expiry row was authored expecting **3**, reasoning that a terminated run performed no iteration — and the ceiling-breach path one line away *does* freeze the counter (`old_iter if ceiling_breach else new_iter`), so the asymmetry looked like a defect. Resuming an expired directive five times running gives `iter=4` and `reason=expires_at` every time: it advances once, on the resume that *discovers* the termination, then converges. Not a runaway. The harness expectation was corrected; no finding was filed. Recording this because the alternative — filing it — is how a review manufactures defects out of its own assumptions.

---

## E5 — live fire: the real binary, the real wrapper, watched through TermLink (6/6)

E1-E4 measure mechanism ends. `tests/unit/t3243_supervisor_restart_policy.bats` measures
the supervisor's branch arithmetic. **Both drive a stub.** A stub cannot answer whether a
real session comes back, which is the only question the arc's headline mechanic actually
asks. E5 runs `/root/.local/bin/claude` (2.1.245) under `bin/claude-fw`, inside a TermLink
PTY the operator can attach to.

The transcript, verbatim and unedited:

```
LIVEFIRE-OK

claude-fw: Re-arm #1 — claude exited (code 0) with no restart signal,
  and a continuous run is armed. Relaunching in 5 seconds.

Error: Input must be provided either through stdin or as a prompt argument when using --print

claude-fw: Re-arm #2 — claude exited (code 1) with no restart signal,
  and a continuous run is armed. Relaunching in 5 seconds.

Error: Input must be provided either through stdin or as a prompt argument when using --print

claude-fw: Continuous run is armed, but the restart budget is exhausted
  (2/2 within the last 3600s). Stopping.
```

Three real claude launches, two real re-arms, contained by the real rate limit — no
keypress, no stub, no simulated exit. It terminates on its own because a non-tty `claude`
with no arguments behaves as `--print`, finds no prompt, and exits 1; the re-arm path
drops the user's args by design (T-3166: a restart must start *fresh*), so every relaunch
is that form.

**One assertion in this harness was thrown away for being green and meaningless.** The
first version counted claude processes with a host-wide `pgrep` and reported 36 —
every claude on the machine, including the session running the harness and four other
projects'. It passed. It measured nothing. Replaced by two scoped, independent counts
that must agree: processes whose PPID is *this* wrapper (5, since claude spawns helpers),
and launches derived from what the binary printed (1 × `LIVEFIRE-OK` + 2 × `--print`
error = 3 = `MAX_RESTARTS + 1`). Using a global population to prove a local event is the
same false-green class as everything else in this report; it is recorded rather than
quietly fixed because catching it in my own harness is the only reason to trust the rest.

Harness: `livefire-m2-termlink.sh` · evidence: `evidence/E5-livefire-m2-termlink.txt`

## E6 — the arc focus crosses the boundary (4/4)

E4 proved the counter advances and the directive is re-emitted. Neither E4 nor E5 touched
the **arc**. A loop that cycles forever while forgetting which arc it is working on is not
the mechanism — it is a restart loop with amnesia, and from outside the two are identical.

The restarted session is **fresh by construction** (T-3166 empties `CLAUDE_ARGS`, so it
cannot inherit the context it restarted to escape). Everything the next iteration will
ever know about the arc must therefore be inside the SessionStart payload. That payload is
the entire boundary, and it is capturable. E6 runs the real
`agents/context/post-compact-resume.sh` through the real `bin/fw hook` dispatcher.

Verbatim, from `evidence/E6-payload-verbatim.txt`:

```
## Current Focus: T-3239

## Current Arc: continuous-run

## Next Directive (iteration 5/10, tier_ceiling 1)

Continue arc continuous-run. Emit ARCBEACON-7731 once, then take the next action.
```

`current_iteration` moved **4 → 5** in the state file. Arc, focus task, iteration counter
and tier ceiling all cross. This is the "iteration counter, directive, and bounded
tier-ceiling are visible" clause of the headline mechanic, in the payload that carries it.

| case | arc in payload | directive | counter | verdict |
|---|---|---|---|---|
| armed, `startup` + sentinel (a real restart) | yes | yes | 4 → **5** | the mechanism |
| armed, `resume` | yes | yes | 4 → **5** | same via /compact path |
| **disarmed** + sentinel | yes | **no** | 4 → 4 | control: recovery without a run |
| armed, **no sentinel** (cold start) | **no** — 0 bytes | no | 4 → 4 | control: cold start untouched |

**A second wrong assumption, caught by measuring.** Case 4 was authored expecting the arc
to appear anyway, since it is ambient project state and case 3 emits it. Measured: the
payload is **zero bytes**. `post-compact-resume.sh:48-57` exits early on `startup` without
the sentinel — `exit 0  # cold start — preserve pre-T-2376 no-op`. Explicit, commented,
and right: emitting the arc there would be the first half of hijacking a cold operator
start with a stale run, which is the T-3168 failure. The expectation was corrected and no
finding was filed. That is now twice in this report (E4's expiry counter, this) — recorded
both times, because manufacturing defects out of a demo's own assumptions is the failure
mode a demo is most prone to.

## E7 — the same trip on a real session: NOT fired (the honest negative)

E7 is E8's control, and it failed. Dial `FW_CONTEXT_WINDOW` to 4000, run a real
session that certainly burns more than 3800 tokens, and the gauge still reads
`{"level":"ok","tokens":0}`. No signal, no restart.

It is kept, unedited, because the reason it failed is the finding. A reader who
saw only E8 would conclude the budget trip fires on real sessions. It fires on
real sessions **that run long enough for the gauge to look at them**, and E7 is
what that distinction looks like from the outside: indistinguishable from a
healthy session, which is the same false-green family as E3-B.

Harness: `livefire-budget-trip.sh` · evidence: `evidence/E7-livefire-budget-trip.txt`

## E8 — the headline mechanic, live and positive (6/6, three consecutive runs)

The link every earlier section named as unproven. Real `claude` 2.1.245 under real
`bin/claude-fw`, real `fw init` sandbox, real hooks. The wrapper's own stdout:

```
claude-fw: budget-critical signal detected — ending claude to trigger auto-restart.

claude-fw: Auto-restart #1 (session: S-2026-0901-1202, tokens: 52655)
  Directive: Continue the demo arc. Reply with exactly: BEACON-E8
  Restart mode: fresh (new session, seeded from the handover)
  Handover committed. Continuing in 3 seconds...
```

and the ledger entry that survives the restart:

```
{"event": "iterate", "reason": "restart", "restart_count": 1,
 "detail": "session=S-2026-0901-1202 tokens=52655"}
```

Threshold crossed → signal written by `budget-gate` → handover generated **and
committed** → session restarted → directive re-injected → counter advanced. That
is M2 end to end, on the wire. Reproduced 3/3 at 52805 / 52805 / 52804 tokens, so
it is a property of the loop and not a lucky run.

### Four blockers stand between a short session and the gauge

None of them is a defect. Each is legitimate production tuning, and the
*composition* is the finding — with any one left at its default, a short session
cannot trip the gauge at all.

| # | blocker | why it exists | how E8 clears it |
|---|---|---|---|
| 1 | `FW_CONTEXT_WINDOW` 300000 | the budget cap is a policy dial | 4000 → critical at 3800 |
| 2 | `FW_BUDGET_STATUS_MAX_AGE` 90 | `post-compact-resume.sh:82-90` seeds `ok/0` at SessionStart (T-1087) so the slow path cannot misread a resumed JSONL's pre-compact tail; `budget-gate.sh:247` serves that seed for 90s **without opening the transcript** | 1 |
| 3 | `FW_BUDGET_RECHECK_INTERVAL` 5 | the transcript read costs ~30ms, so the gate measures only on calls 1, 6, 11… | 1 |
| 4 | the Tier-1 task gate | a fresh `fw init` sandbox has `current_task: null`, so `check-active-task.sh` refuses the very Bash calls whose tokens the measurement needs | `fw work-on`, **not** `FW_SAFE_MODE` |

Blocker 2 is why E7 failed, and it is worth stating plainly: **E7's session was
blind by construction for its entire ~32-second life.** No amount of token volume
could have tripped it. The FAIL was a property of the harness, not of the loop.

Blocker 4 was fixed by giving the sandbox a real task rather than by disabling the
gate. A sandbox that needs the framework's own governance switched off to reach
the gauge is no longer measuring the framework.

### Three harness defects, recorded rather than quietly fixed

Every one of these looked exactly like the mechanism failing. This is now the
fifth and sixth and seventh time this report has had to separate "the thing is
broken" from "my instrument is broken", after E4's expiry expectation, E5's
host-wide `pgrep`, and E6's cold-start assumption.

1. **Post-run state used to prove an intra-run event.** The assertions read
   `.budget-status` and `.budget-gate-counter` *after* the run. Both describe the
   session that came back: the resumed session re-measures the gauge, and the
   counter is cleared as a volatile file at SessionStart. So the run that proved
   the mechanism reported `level=ok` and `invocations=1` and scored itself 2/6.
   Now read from the loop ledger and the wrapper's stdout, which survive a restart.
2. **`grep -c … || echo 0`.** `grep -c` prints `0` *and* exits 1 on no-match, so
   the fallback appended a second `0` and the assertion compared `"0\n0"` as an
   integer. Counted with `awk` instead.
3. **Forcing tool USE is not forcing tool TURNS.** v1 of the prompt ended "reply
   with exactly BEACON-E8", which the model satisfied on some runs with zero Bash
   calls. v2 used four unguessable nonces; the model ran all four (4/4 echoed
   back) but **batched them into one assistant turn** — and one turn is one usage
   entry, below the two `lib/context_tokens.py:97` requires before it will trust a
   count. v3 chains the files so each names the next, which cannot be batched or
   guessed, so every link is its own turn, its own usage entry, its own gate call.

Harness: `livefire-budget-restart.sh` · evidence: `evidence/E8-livefire-budget-restart.txt`

## What is NOT proven, stated plainly

1. **The budget trip on a session left at stock dials.** E8 moved three of them.
   The mechanism is proven; the *default configuration's* ability to catch a real
   overrun before the session ends is not, and blocker 2 makes the first 90
   seconds of every session structurally unmeasurable.
2. **`stop_hook_active` on a longer chain.** Only two stops were observed. Claude
   Code's own 8-consecutive-block cap was never reached because our guard fires
   first (E2).
3. **A multi-turn M1 loop.** Not unproven — **disproven**. E2 measured exactly one
   continuation. See T-3240.

A relevant environmental fact, unchanged: **this session has
`FW_CLAUDE_FW_SUPERVISED` unset.** Per `budget-gate.sh:85-97`, the restart loop
only fires under `claude-fw`. E8's sandbox ran *under* the wrapper, which is why
it fired there; on this host, right now, a correctly-written signal still goes
nowhere.

## Bottom line

The **substrate is sound**: eleven brakes fire correctly, the resume end advances
and re-injects, the arc and tier ceiling cross the restart boundary, and — E8 —
the budget trip drives a real handover-and-restart on a real session, reproducibly.

The **headline mechanic is now demonstrated for M2** and remains **not
demonstrated for M1**: "multi-cycle continuous session" is one continuation per
session, because `stop_hook_active` is checked ahead of every cap we own (E2).
The arc's sentence bundles the two, so it is half-shipped, and the half that
ships does so only when the gauge's dials let it look (E7).

Per §ACD, substrate is not the deliverable — but M2's deliverable is now on the
wire, in `evidence/E8-livefire-budget-restart.txt`, which is what `fw arc close`
gates on. **arc-012 should stay OPEN**, on M1 rather than on M2. The two decisions
it waits on are unchanged: T-3240 (should a session drive more than one turn, and
bounded by what) and T-3241 (make "unmeasurable" distinguishable from "fine") —
and E7 is now a second, live reproduction of exactly the T-3241 class.
