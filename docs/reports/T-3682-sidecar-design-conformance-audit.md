# T-3682 — Sidecar design-conformance audit (2026-10-02)

**Asked by the operator:** open the arc, open every task, and check whether the build
followed the design. **Answer: it did not.** The sending half was built faithfully and
tested. The receiving half (the part that makes a message *arrive* in a working session)
was deferred by every slice, and no task ever owned it. Every status surface measured the
sending half, so the gap read as "done".

## The binding spec
- `docs/reports/T-3396-peer-consult-sidecar-inception.md`: GO 2026-09-20, Amendments 1-5.
- `.tasks/completed/T-3397-…md` §Findings (2026-09-21): resolves IW-1..IW-6, "GO, design
  resolved and ready for build".
- The operator's own requirement, T-3396 Dialogue Log: an always-on listener; a flag is
  raised; a cron job monitors the flag and looks for the active session; a prioritised
  queue; PTY inject when the cursor is silent; urgent messages may interrupt.

## Requirement-by-requirement

| # | Spec requirement (source) | Built? | Evidence |
|---|---|---|---|
| R1 | Push API: message file, then atomic flag file; `STORED` ack on return (T-3397, Amendment 5 IW-3) | **YES** | `lib/sidecar/outbox.py` (T-3402) |
| R2 | **Write-time fast path: if the receiver is ready, inject into it now** (T-3397 §Consumption) | **NO** | No code injects into a receiving session. `INJECTED_NOW` is recorded when the HUB accepts the post (`delivery.py:142`); the docstring redefines it as "the hub took it". The spec meaning was injected into the receiver. |
| R3 | **Cron tick, default 30 s, configurable: the guaranteed-delivery fallback that injects when ready** (T-3397 §Consumption; Amendment 5 IW-2) | **NO** | No 30 s job exists. `sidecar-sweep-5m` (T-3418) is a different job: a 5-minute ledger sweep (expire to `UNKNOWN`, later retry/nudge). It injects nothing. T-3418 never claimed to be the 30 s tick, and nothing else does either. |
| R4 | **Ready flag: Stop hook writes `ready-for-input: true`; UserPromptSubmit clears it at once** (T-3397 §Consumption) | **NO** | `grep ready-for-input` returns zero hits in lib/, agents/, bin/ and settings. The Stop hook is only `stop-driver.sh` (continuous-run). |
| R5 | **Urgent bypass: urgent messages inject immediately regardless of state** (operator decision 2026-09-21, T-3397 IW-1) | **NO** | `urgent` is stored in the message file (`outbox.py:85,102`) and read by nothing. |
| R6 | Bidirectional ack: sender sees stored / injected-now / injected-later (T-3397) | **PARTIAL, misleading** | The states exist, but "injected" means hub-accepted (see R2). This is the "delivered:true measures transport, not reading" defect 832 reported. |
| R7 | **Liveness: `.context/sidecar/liveness.yaml` {identity, seq, last_probe_at, last_probe_ok, latency}; loopback self-probe every 30 s tick; not-live if seq stalls for 2 ticks OR probe fails** (Amendment 5 IW-2) | **NO** | No liveness.yaml exists (`ls .context/sidecar/`), and there is no self-probe or loop. |
| R8 | Per-hub capability probe + version floor before send (Amendment 5) | **YES** | `termlink_transport.probe_hub`, `VERSION_FLOOR` (T-3405) |
| R9 | Receive-side dedupe on `client_msg_id` (Amendment 5 IW-3) | **YES** | `lib/sidecar/inbox.py:216` (T-3406) |
| R10 | `awaiting-ack.jsonl` with deadline; past deadline → `UNKNOWN` (Amendment 5) | **YES** | `outbox.resolve_expired`, sweep (T-3418) |
| R11 | `conversation_id` mandatory, never a bare offset (Amendment 1/IW-3) | **YES** | message schema |
| R12 | Cross-host direct cross-post, credentials refused loudly (Amendments 3/4) | **PARTIAL** | Same-host only verified; cross-host fenced out of every slice |
| R13 | Sidecar-owned retry (Amendment 4) | **YES (later)** | T-3434 retry ladder |
| R14 | **Every agent runs a sidecar (symmetric)** (T-3397 IW-5) | **NO** | No AEF sidecar process exists. The three running `notify-sidecar.sh` processes are TermLink's, for its own three agents (832's D5). |
| R15 | **Always-on listener per agent session** (T-3396 title) | **NO** | Same as R14. Inbound is a pull at prompt time (`fw hook sidecar-inbox`, T-3407). |

**Score: 6 built, 2 partial, 7 not built.** All 7 unbuilt items are on the receive or
liveness side, and those are the parts the operator asked for.

## How it happened (per slice)
Every slice fenced the same items out of its own scope and named no owner:

| Slice | Fenced out |
|---|---|
| T-3402 (1) | "liveness self-probe daemon, Stop/UserPromptSubmit hook wiring" |
| T-3404 (2) | "the liveness self-probe" |
| T-3405 (3) | "liveness self-probe daemon, and Stop/UserPromptSubmit hook wiring" |
| T-3406 (4) | "liveness self-probe daemon" |
| T-3407 (5) | "the `Stop` hook (arc-012 coupling), the liveness self-probe daemon" — then built the UserPromptSubmit *peek*, without the ready-flag half |
| T-3418 (7) | "Amendment 5's liveness self-probe daemon is a separate, larger slice" — cadence set to 5 min for a ledger sweep |

No task was ever filed for the deferred items: a `grep` for `self-probe|ready-for-input`
across `.tasks/` returns only the slices that deferred them, plus captured T-3518. T-3397
closed GO because "slice 1 landed". The arc stayed in-progress with no checklist of the
spec's requirements, so each closed slice looked like progress toward a whole that nobody
was tracking.

**Two further deviations:**
1. **The operator's design was narrowed in dialogue.** The T-3396 dialogue log shows the
   operator asking for a cron job that finds the active session and PTY-injects when idle,
   with an urgent override. The agent steered away from injecting into an idle terminal,
   citing arc-011, and replaced it with the harness-asserted ready flag (T-3397). That
   replacement was then never built either.
2. **Sub-minute cadence.** The 30 s tick cannot come from a plain cron line, which has
   1-minute resolution. It needs a loop, a systemd timer or the per-agent sidecar process.
   No slice raised this.

## Why nothing flagged it
- `fw sidecar status`, `fw sidecar e2e` and the audit rail `check_sidecar_ledger` all
  measure transport and ledger states. A message "INJECTED_NOW" into a session nobody
  reads looks fully healthy.
- The receive surface that does exist (the prompt hook) fails silently: E2BIG on a
  >128 KB inbox (T-3681), dict-vs-list before that (T-3559).
- Slice closes checked their own fenced ACs. Nothing checked the slices against the spec.

## What it takes to conform (proposed, operator to rule)
1. **R4 + R2/R3:** a Stop-hook ready flag plus a 30 s inject tick (systemd timer or
   per-agent loop) that injects one line into the project's registered idle Claude
   session. The UserPromptSubmit hook clears the flag and surfaces the messages.
2. **R5:** urgent bypass, injected immediately.
3. **R7, R14/R15:** a per-agent sidecar process with liveness.yaml (seq + loopback
   self-probe); `fw doctor`/audit FAIL when it is stale.
4. **R6:** split the ack states into `HUB_ACCEPTED` and `INJECTED` (into the receiver), so
   the sender's view stops lying.
5. **Structural counter:** a spec-conformance checklist on the arc (one row per
   requirement R1-R15, each pointing at its owning task) and an audit rule that refuses
   to close a slice whose scope fence defers a spec requirement without naming the owner
   task.
