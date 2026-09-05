# T-3278: Restart-based M2 transport — cron-watched flag launches claude-fw; directive injected at SessionStart

**Status:** exploration in progress
**Filed:** 2026-09-05
**Origin:** Operator suggestion, mid-session 2026-09-05 (see Dialogue Log)
**Arc context:** arc-012 (continuous-run)

## The Question

Should the M2 continuous loop's cross-session continuation run on a
**restart-based transport** — a cron-type watcher sees a flag, launches
`claude-fw`, and the next directive reaches the new session through the
SessionStart context-injection path — instead of (or alongside) the
**live-injection transport** (`continuous-driver.sh` pushing keystrokes into a
running TUI via termlink/tmux)?

## What Exists Today (the look-back)

arc-012 has **three continuation channels**. Only one of them is the fragile one.

| # | Channel | Mechanism | State |
|---|---------|-----------|-------|
| 1 | **Stop hook** (in-session) | `agents/context/stop-driver.sh` — blocks the stop, drives another turn in the SAME session | Shipped (T-3164). Capped at ONE continuation by `stop_hook_active` (T-3240 inception open). |
| 2 | **Restart leg** (cross-session) | `bin/claude-fw` wrapper: budget-critical → auto-handover → `.context/working/.restart-requested` → wrapper detects on claude exit → preflight via `agents/context/inject-next-directive.py` → exports `FW_NEXT_DIRECTIVE` → fresh session (T-3166: NOT `claude -c`) → SessionStart hook injects the directive as context | Shipped (T-179 substrate + T-2364/T-2365 injector + T-3166). Fires only on *restart after exit*. |
| 3 | **Live injection** (push into running TUI) | `agents/context/continuous-driver.sh` (cron-driven): discover session → busy check → `termlink inject` / `tmux send-keys` → delivery confirmation | Shipped (T-3239/T-3254/T-3275/T-3277). Works, but carries the heaviest defensive machinery in the arc. |

**The operator's proposal is essentially: promote channel 2's injection
mechanism to be drivable by a cron watcher, and stop depending on channel 3.**

### Why channel 3 is expensive to keep honest

Every defect class below required its own build-out, because pushing keystrokes
into a raw-mode TUI is keystroke *emulation*, not a delivery contract:

- **G-097** — `termlink inject` exits 0 and delivers NOTHING into an ink-based
  raw-mode TUI. Measured three ways; upstream fix homed at TermLink (T-3256,
  no response yet).
- **T-3275** — delivery confirmation: transport exit 0 is not delivery; must
  find the directive's own text in the pane, whitespace-squashed (TUI wraps
  mid-word), no pipe into grep (L-387 SIGPIPE), fail closed.
- **Busy detection** — two snapshots compare unequal forever because a spinner
  glyph advances; fixed by folding non-ASCII to '.' before compare.
  Residual bias documented and accepted.
- **T-3277** — a whole second wire (tmux) because the first wire can't reach
  TUI targets; pane-vs-session target resolution; per-wire snapshot verbs.
- **Cross-repo verify** — L-477: injection without poll-back is a silent-fail.

None of these classes exists on channel 2, because SessionStart
`additionalContext` is a **first-party Claude Code contract** — the harness
puts the text in the model's context; there is no pane, no keystroke, no
busy-race, no delivery question.

### What channel 2 already has that the proposal needs

- **The flag exists:** `.context/working/.next-directive.yaml` IS the flag —
  filed by operator or prior auto-handover, read by the injector.
- **The injector exists:** `inject-next-directive.py` — gated on
  `.continuous-mode.yaml` `enabled:`, advances the iteration counter, enforces
  max_iterations / expires_at / tier ceiling (preflight in the wrapper,
  E10/T-3250 proved the brake).
- **The launcher exists:** `claude-fw` already evaluates the preflight and
  exports `FW_NEXT_DIRECTIVE` before restart.

### What is genuinely missing (the build delta on GO)

1. **A cron leg** — something that, on a schedule, checks: directive flag
   present AND continuous-mode enabled AND caps unspent AND **no session
   currently running for this project** → launch `claude-fw` (headless or in a
   tmux pane) → exit. Today the wrapper only restarts *its own child* after
   exit; nothing cold-starts a session.
2. **Session-exit semantics** — the Stop hook *yields to the prompt*; the
   session does not exit. A restart-based loop needs sessions that END when
   their work is done (or the cron leg must refuse while one runs — which is
   the same busy-question as channel 3, but answerable by process table
   instead of pane forensics: pidfile/pgrep, not capture-pane diffing).
3. **Gating parity (L-652)** — the wrapper's AUTO_RESTART already fires
   UNGATED on `enabled:` (it restarts even when continuous-mode is off; only
   the counter is gated). A cron leg MUST be gated on the full brake set
   (halt file, enabled, caps, tier ceiling) at launch time — the L-652
   asymmetry must not be copied.

## Comparative Analysis

| Dimension | Live injection (ch. 3) | Restart-based (proposal) |
|---|---|---|
| Delivery contract | Keystroke emulation; needs text-in-pane confirmation | First-party SessionStart context injection; delivery is the harness's job |
| G-097 exposure | Entire class | None |
| Busy detection | Pane-diff + animation folding | Process-level: is a session running? (pidfile/pgrep) |
| Latency | Seconds (cron tick + settle) | Cron tick + full session cold-start |
| Session continuity | Preserves live session's context window | Fresh window each hop (handover carries state — this is arc-012's design anyway) |
| Operator-attended TUI | Can drive the operator's own session | Cannot (must not cold-start over a live attended session) |
| Token cost | Cheap per hop | Session startup + context re-read per hop |
| Brakes | continuous-driver enforces full brake set (T-3254, 21 tests) | Injector preflight enforces same set; cron leg must add launch-time gate |

**The two channels serve different targets.** Live injection is the only way to
hand a turn to an *attended, already-running* session. Restart-based is the
natural shape for *unattended autonomous* runs — which is what M2/arc-012 is
actually for. The proposal is not "delete channel 3"; it is "make channel 2
cron-drivable and prefer it for unattended loops."

## Open Questions

Mirrored in the task file (gate-tracked there); reasoning here.

- **IW-1: Who ends the session?** Options: (a) agent exits when the directive
  is complete; (b) budget-critical path already exits; (c) Stop hook yields
  and the session idles — the cron leg must then treat "a session exists" as
  busy and skip. Note (c) is the cheap, safe default: skip-while-running
  makes the cron leg idempotent and needs only a pidfile check.
- **IW-2: Cron granularity** — is >=60s hop latency acceptable for M2? Prior
  evidence says yes: the continuous-driver cron already runs on minute ticks.
- **IW-3: Headless vs pane** — Session Launch Policy (2026-09-03) mandates
  TermLink wrapping for observable framework work; `claude-fw --termlink`
  exists. Launching inside tmux+termlink keeps the session attachable.
- **IW-4: Flag schema** — does `.next-directive.yaml` suffice, or does
  launch-arming need a separate file so "directive present" and "cron may
  launch" are independently controllable? (Compare: halt file is already a
  separate, out-of-band brake.)
- **IW-5: T-3240 interaction** — if restart hops are the loop, the Stop-hook
  one-continuation cap may stop mattering: each session takes its turns and
  exits; the LOOP is the restart chain, bounded by the iteration counter.

## Dialogue Log

**2026-09-05, operator (voice, Dutch):** In plaats van live injecting — in de
M2 loop kunnen we een cron-job-achtig mechanisme gebruiken dat een flag
bekijkt; het voert `claude-fw` uit, dat start en injecteert de
context-injectie — de volgende command die we hebben. Kijk terug wat dat is.
Deep reflect. This is worth an inception.

**Agent's reading:** the "context injection" referred to is the
`FW_NEXT_DIRECTIVE` / SessionStart `additionalContext` path
(`inject-next-directive.py`, T-2364/T-2365), which the `claude-fw` wrapper
already drives on restart. The proposal generalises it from
"restart-after-exit" to "cron-launched cold start on flag".

**Course correction captured:** this arrived while T-3277 (tmux leg of live
injection) was being closed out — the operator is steering the arc away from
further investment in keystroke-emulation transports, not asking for T-3277 to
be reverted (it is built and green, 7/7 + 21/21 + 6/6).

## Recommendation (preliminary — human decides)

**Recommendation:** GO

**Rationale:** The proposal replaces the arc's most defect-dense subsystem
(keystroke emulation into raw-mode TUIs: G-097, T-3275, spinner-folding,
two wires) with a first-party delivery channel that is already 80% built —
flag file, injector, preflight, and launcher all exist and are tested. The
build delta is one cron leg plus a session-exit contract. Live injection
remains for the one case restart cannot serve (attended sessions). The main
risks are scoped and named (IW-1 exit semantics, L-652 gating parity) and are
design decisions, not unknowns requiring spikes.

**Evidence:**
- G-097 + T-3275 + T-3277: three tasks of defensive machinery, all specific to keystroke emulation; none applies to SessionStart injection.
- `inject-next-directive.py` + `FW_NEXT_DIRECTIVE` + `.next-directive.yaml`: delivery path shipped and tested (T-2364/T-2365, E10/T-3250 brake proof).
- L-652: gating asymmetry in the existing wrapper — a named, avoidable defect the cron leg must not copy.
- T-3255 measurement: the reason channel 3 needed a second wire at all was that the first-party channel wasn't reachable mid-session; a cold start makes it reachable every hop.
