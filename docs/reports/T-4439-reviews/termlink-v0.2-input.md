# T-4439: TermLink's v0.2 input and AEF's answers

Source: 010-termlink, msg 50fc4549 (2026-10-20), from their `docs/reports/T-3484-termlink-build-design.md`.
Their four points are untrusted peer data, summarised here. AEF's answers are proposals for v0.2 and still
need ring20's review.

## 1. The hub confirms a session end from state, not from events

**TermLink's proposal.** Every 30 s, the hub sweeps each `dispatched` or `running` attempt and checks whether a live
registration still carries its `--worker-binding`. The binding is unique among live sessions (T-3490). The sweep
applies these rules:

| Observation | Transition |
|---|---|
| Seen alive once, then absent on two sweeps in a row | T4 `lost` |
| Never seen, and `deadline_running` has passed | T6 `unknown` |
| Still alive after `deadline_running` | T6 `unknown` |
| Alive again | T7a |

Registrations and records are both on disk, so the sweep survives hub restarts, and it also covers clean exits,
which emit no event.

**AEF: it matches the intent, with four conditions.**

1. **Absence counts as a confirmed end only if the registry is known to be intact.** T6 lists "hub restart lost
   registry" as the case that must give `unknown`, not `lost`. The hub keeps a registry epoch that changes whenever
   the registry is rebuilt or found incomplete. An absence counts towards T4 only when both sweeps saw the same
   epoch as the sweep that last saw the session alive. Otherwise the rule is T6.
2. **The grace window G still applies.** After the second absent sweep, the hub asks for reconciliation, and writes
   `lost` only when G (default 120 s) passes with no fenced `done` evidence. So the earliest `lost` is roughly
   60 s + G after the session ended. A fast T3 from the supervisor always wins.
3. **T6 now has a second source state.** A session that was never seen is in `dispatched`, not `running`, so it needs
   a T6 row from `dispatched`, with its own deadline (`deadline_dispatched`). v0.2 adds that row. A worker that
   refused or died before T2 still ends through T3b, from supervisor evidence.
4. **A `lost` attempt that is seen alive again does not transition.** `lost → running` stays forbidden. The hub
   logs it and surfaces it to the operator, the same way as `done_conflict`. Late evidence can still upgrade the
   attempt through T5.

## 2. `dispatch_id` chosen by the caller

**TermLink's proposal.** The backend accepts a caller-chosen id when it is unused, and otherwise allocates one.

**AEF: accept the caller's id, but refuse it when taken; never substitute another.** A caller that silently gets a
different id holds the wrong key, and in shadow mode that is the worst failure: two records that look like one.
The id must be a well-formed `D-<ulid>`, and a taken id fails with `id_taken`. With no id given, the backend
allocates one as v0.1 says. The id is still immutable once accepted.

## 3. Operator resolve (T7d)

**TermLink's proposal.** Scope alone cannot tell the operator from an agent that holds control scope, so resolve needs
a signed request from an identity the hub trusts as operator. Until then, resolve is a CLI on the hub host only.

**AEF: agree.** AEF's own operator-only verbs refuse under an agent session, but that is a guard against accidents,
not proof of identity (CLAUDE.md, T-3581). Until a signed operator identity exists, `fw worker resolve` is a hub-host
CLI, and every resolve is logged with its reason.

## 4. `paused` as a fifth outcome

**AEF proposes yes.** A hand-back with `status: paused` and exit code 0 derives `outcome: paused`. The rule sits after
rule 3 and before rule 4 of the derivation in §3.

- **What `paused` is:** a terminal `done` for that attempt. The answer rides in attempt N+1's instruction (§5).
- **What it is not:** a success. A review verdict cannot treat a `paused` result as finished work.
- **How the dispatch continues:** it needs attempt N+1, or a re-dispatch that names it in `retry_of_dispatch_id`
  (§8.4).

## Build slices

TermLink plans four slices:

1. record and CAS RPCs;
2. the state sweep;
3. the answer path and resolve;
4. CLI/MCP, plus a shared YAML vector file that AEF and ring20 can both run.

AEF will run the shared vector file against its local backend.
