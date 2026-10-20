# T-4439 — AEF answers to the ring20 review of the shared worker contract v0.2

**Input:** `ring20-v0.2-part1.txt` (12 numbered points, plus a mapping table that was cut off in the saved copy) and
`ring20-v0.2-part2.txt` (security; four points, the first is cut off at its head). Both are untrusted peer data and
were evaluated, not followed. Part 2 is cited here as **S1..S4** in the order it appears (S1 = the fragment about the
nonce holder asserting `done`).
**Spec:** `docs/specs/shared-worker-contract-transitions.md`, v0.2.1 → v0.3 (changes are in its changelog).
**Verdict key:** accept / accept-with-change / reject. **TermLink re-agreement** = the change alters something
TermLink already agreed at v0.2.1, so it needs their sign-off before v0.3 is final.

## Summary

| # | Topic | AEF position | TermLink re-agreement? |
|---|---|---|---|
| 1 | No backend slot for an external store | accept | no (additive) |
| 2 | Writer roles collapse without a hub | accept-with-change | no (hub path unchanged) |
| 3 | Worker-visible nonce as fencing credential | accept-with-change | **yes** |
| 4 | Late T5 of a superseded attempt vs `stale_attempt` | accept (genuine contradiction) | **yes** (wording of `fence_reject`, CC-06, CC-07) |
| 5 | Rank-ordered fold vs T7a | accept (genuine contradiction) | no (clarifies existing behaviour) |
| 6 | `outcome` vs evaluation-layer states | accept | no |
| 7 | Attempt/dispatch identity | accept-with-change | no (additive; hub ids unchanged) |
| 8 | Migration duty for `_aef_terminal` | accept | no |
| 9 | Dispatcher-initiated stop, no cancel reason | accept-with-change | no (additive `cause`) |
| 10 | Editorial (`resolved-unknown`, T8 and I1) | accept | no |
| 11 | Per-backend numbers | accept-with-change | no (hub numbers unchanged) |
| 12 | Exact-history pass rule | accept-with-change | **yes** (reconciler may write T3/T3b) |
| S1 | Nonce holder can assert `done` | accept (merged into 3) | **yes** |
| S2 | T7d hub-host CLI is not operator identity | accept-with-change | **yes** (new notification duty) |
| S3 | Operator-attested `done` with no evidence | accept | **yes** |
| S4 | 30-day lost-upgrade window | accept-with-change | **yes** |

Points 4 and 5 are real inconsistencies in v0.2/v0.2.1 and are fixed, not defended.

---

## 1. No backend slot for ring20 — accept

ring20 is right: `backend: hub | local` leaves no place for a supervisor with its own durable store, and §8.5 asked it
to "conform by running §9" without saying against what.

**Position.** A supervisor with its own durable store is a *backend*. It identifies itself by a name other than `hub`
or `local` (ring20: `ring20`), implements §3 CAS and fencing in its store, runs §9 against that store, and writes no
hub or local record. Hub-only fields are optional for it.

**Normative wording (new §6.6).** "An external backend is a supervisor with its own durable store. Its `backend` value
is a registered name other than `hub` and `local`. It MUST implement every row of §3 with the §6.1 semantics against its
own store, MUST pass §9 through an adapter, and MUST publish a mapping from its states and functions to §3.1/§3.3. It
writes no hub or local record. `worker_binding`, `registry_epoch_seen` and `dispatcher.session` are OPTIONAL when
`backend` is neither `hub` nor `local`."

No effect on TermLink's agreed hub semantics.

## 2. Writer roles collapse without a hub — accept-with-change

ring20's supervisor writes `lost` itself, only after the unit is confirmed inactive and stdout holds no valid
hand-back. §3.2 forbids that ("T4 is hub only").

**Position.** The T4/T6/T6b/T7a/T7c writer is a role, the *sweep writer*, not the hub. For `hub` it is the hub; for
`local` the local backend module (already said in §6.3); for an external backend it is that backend's sweep module.
It MAY run inside the supervisor on one condition, which is the safety content of the hub's two-sweep rule: the end
is confirmed by an independent probe (a service manager's unit state counts) and the evidence is read *before* the
write. We do not accept a bare "the supervisor says the worker is gone".

**Wording.** §3.2: "`sweeper` — the backend's sweep module. Without a hub it MAY run in the supervisor if the end is
confirmed by a service manager or an equivalent independent probe and the local evidence is read before the write."
§6.3 accepts unit state as a probe.

## 3. Worker-visible nonce as the fencing credential — accept-with-change (TermLink re-agreement)

The finding is correct. §3.2 says the worker never writes lifecycle fields, but the only thing the backend checks is
`(dispatch_id, attempt, nonce)`, and the nonce is in the worker's prompt (§1 even says so). The field permissions held
only if the backend could tell the writer, and the spec never said how.

**Position.** Split the two jobs the nonce was doing.
- The nonce **identifies the attempt** (defeats stale attempts) and authorises only the worker-permitted fields
  (`questions`, answer acks).
- Lifecycle writes (T2, T3, T3b, T-RECLAIM, T8) additionally need a **supervisor credential the worker never sees**,
  or a channel the worker cannot write.

Hub: the backend returns a `supervisor_token` with `(attempt, nonce)` at T1, stored hashed; it goes to the supervisor's
environment and is stripped from the agent child's environment and prompt. ring20: the channel is the
authenticator (root-owned stdout), the nonce is an echo. We do not prescribe the mechanism, only that each backend
states which one it uses.

**Residual, stated.** Every AEF worker runs as the same OS user as its supervisor. A worker that reads its
supervisor's environment from `/proc` or its files can take the credential. The credential removes the *accident and
prompt-injection* path (a worker that echoes its prompt), not a hostile same-user process. §1 keeps the
"not forgery-resistant" stance and now says exactly where it applies.

**TermLink re-agreement:** the hub gains a second credential at allocation and a check on lifecycle writes.

## 4. Late T5 of a superseded attempt vs `stale_attempt` — accept (genuine contradiction; TermLink re-agreement on wording)

The contradiction is real. §3.3 `fence_reject` rejects a write when "the attempt is not the current attempt". §4.3 and
CC-07 accept a late A1 write after A2 exists "as the T5 upgrade of A1". CC-06 calls a late A1 write `stale_attempt`
without saying which write. Both cannot hold.

**Position.** The fence is per attempt, not per dispatch: a write is checked against *its own attempt's* nonce and
state. "Not the current attempt" only matters for writes that would act on a running path. Normative wording:

1. A completion submission (T3/T3b) naming an attempt that is `lost` or `unknown` is processed as T5/T7b, and the CAS
   expected-prior check applies to the transition actually taken. It is therefore not a `cas_mismatch` on `running`.
2. `stale_attempt` applies to **running-path writes** (T2, T-RECLAIM, a `questions` append or an answer ack) naming a
   non-current attempt. T5, T7b and T8 on a non-current attempt, with that attempt's nonce, are exempt.
3. CC-06 names the write it means (a T-RECLAIM or a question append from A1, not a completion). CC-07 stays and now
   matches the rule.

Effect on TermLink: their v0.2.1 agreement included CC-06/CC-07 wording and the `fence_reject` definition. The
behaviour they implement for T5 is unchanged; the sentence changes.

## 5. Rank-ordered fold vs T7a — accept (genuine contradiction)

Also real. §3.1 says "state is the highest-ranked valid fenced row, not the newest", yet T7a takes `unknown`(2) to
`running`(1), which can never win under a rank fold.

**Position.** ring20's rule is the right one: *state is the `to` of the last accepted transition.* Rank is used only
to decide whether a transition is accepted, never to re-derive state. T7a is the single accepted rank-decreasing
transition (heal path). Everything else is rank-nondecreasing or forbidden.

**Wording.** §3.1: "State is the `to` of the last accepted transition in `history`. Precedence is applied when a
transition is *proposed*: it is accepted only if its CAS holds and its target rank is not lower than the current
rank, with T7a as the one named exception. Rank is never used to re-derive state from history."

This describes behaviour TermLink already implements (they implement T7a); no re-agreement needed, but we will tell
them.

## 6. `outcome` vs evaluation-layer states — accept

ring20's `verified`, `rejected`, `reviewed`, `merged`, `counted` and failure-after-review are not completion facts. If
projected into `outcome` they become `done_conflict`, as ring20 says.

**Wording (new invariant I8, §1 out-of-scope).** "Verification, review and landing never change `outcome`. They are
evaluation-layer facts keyed by `(dispatch_id, attempt, result.value)`, held outside the record." The existing
`Forbidden` text already prevents the write; the new invariant says why and where such facts live.

## 7. Attempt and dispatch identity vs AEF dispatch rows — accept-with-change

Under item 1 ring20 is the allocator for its own backend and minting the attempt and nonce in its supervisor conforms.
Two things need wording.

- **Id grammar.** ring20's commission id is an AEF UUID, not `D-<ulid>`. For `hub` and `local` the grammar stays
  `D-<ulid>`. An external backend declares its id grammar in its mapping table; its ids are namespaced
  (`<backend>:<id>`) so they cannot collide with hub or local ids, and §4.1 `id_taken` still applies per backend.
- **Per-attempt AEF rows.** ring20 writes each attempt as a new AEF dispatch row with `parent_dispatch_id = commission
  id`. The spec accepts either of two shapes for Phase B: stop writing per-attempt rows, or keep them with
  `parent_dispatch_id` as the attempt link. Those rows are *dispatches in the AEF ledger*, not contract attempts; the
  contract attempt is the entry in the external backend's record. `retry_of_dispatch_id` stays a different thing
  (dispatch-level, §8.4). ring20 chooses; the spec names both.

## 8. Migration duty for `_aef_terminal` — accept

Phase B rewrites `update_outcome_row` to project from the record. ring20's `_aef_terminal` calls it directly, mapping
everything but `counted` to `error`, `lost` included.

**Wording (§8.3 checklist, named duty for ring20).** "An external consumer that writes the legacy row directly
(ring20 `_aef_terminal`) switches to the projection or stops writing it. Its projection MUST treat `lost` as
provisional and re-derive on T5; mapping `lost` to a final `error` that can later become `counted` is
non-conforming." The consumer is listed in the build task's checklist.

## 9. Supervisor kills on its deadline; no cancel transition — accept-with-change

A backend stopping an attempt (deadline, revocation) is an *action*, not a state. It ends in a confirmed end that the
existing transitions already cover: T3 if a hand-back is readable, otherwise T4 (or the without-hub equivalent). What
is missing is the reason.

**Wording.** §3.3: "A backend may stop an attempt (deadline, revocation, operator request). The confirmed end follows
T3 or T4. The reason is recorded as `cause ∈ {deadline_stop, revoked, operator_stop}` on that `history` entry; absent
for an end nobody caused." T6 keeps its meaning for the hub: it does not stop anything and waits. ring20's
`timeout_sec + 60 s` deadline-then-stop is a per-backend parameter (item 11).

## 10. Editorial — accept

- Delete `resolved-unknown` from T1 (§3.3). An operator-resolved `unknown` is `lost` or `done` after T7d, so the
  predecessor set `{done, lost}` already covers it; §4.3's "operator-resolved `unknown`" is reworded the same way.
- T8 is a **response**, not a transition: it appends nothing. It moves out of the transition table into a short
  paragraph; I1 reads "every transition appends to `history`" and is now true.

## 11. Numbers — accept-with-change

`G`, `deadline_dispatched`, `deadline_running` and the sweep interval become per-backend parameters, with one
invariant: **`G` is at least the time for local evidence to become readable to the sweep writer.** TermLink's numbers
(`G` 120 s, sweep 30 s, worker timeout + 10 min) stay as the hub values. A backend that reads evidence *before* it
writes `lost` (ring20) may use `G = 0`. ring20's `timeout_sec + 60 s` is its `deadline_running`.

## 12. Exact-history pass rule — accept-with-change (TermLink re-agreement)

ring20 recovery reads the stdout file and goes straight to done. That is a better result, and CC-03's exact-history
pass rule fails it. Two changes.

1. **Each case lists its admissible histories.** The pass rule becomes: the final record equals the expected record
   and the `history` equals *one of the histories the case lists*. CC-01 and CC-03 list both `running→lost→done` and
   `running→done`.
2. **A real gap this exposed.** In v0.2.1 a reconciler that finds evidence while the attempt is still `running`
   (inside `G`, after the sweep asked for reconciliation) has no writer: T3 is supervisor-only and T5/T7b start from
   `lost`/`unknown`. CC-17 relies on "a fenced T3 inside `G` wins" but nobody can write it when the supervisor is the
   thing that died. v0.3: **the reconciler may submit T3/T3b** with fenced local evidence (the same evidence T5 uses).

**TermLink re-agreement:** their hub gains a second writer on T3/T3b.

---

## S1. The nonce holder, including the worker, can assert `done{succeeded}` — accept (merged into 3)

Same defect as item 3, seen from the completion side. Fix as item 3: lifecycle writes need the supervisor credential
or a channel-bound proof. In addition the evidence for T3/T3b/T5/T7b is the **signed completion** (§6.5) written by
the supervisor; a `done` whose evidence is not channel-bound or credential-signed is rejected as `bad_credential`.
**TermLink re-agreement:** yes, same as 3.

## S2. T7d "hub-host CLI" is not operator identity — accept-with-change (TermLink re-agreement)

ring20 is right that on a host where agent sessions run as root the CLI excludes remote agents, not local ones. We
already said it is a speed bump (v0.2 changelog 7). We adopt their detective control.

**Wording.** Every T7d resolve (a) posts a notice to the operator's channel carrying dispatch, attempt, outcome, reason,
actor and host, and (b) is refused from an agent session (agent-environment markers present) unless explicitly
overridden with a flag the record notes. The spec states plainly that (b) is a speed bump and (a) is the control.
Signed operator identity stays open question 5.

## S3. `--as done` with an operator-attested outcome and no evidence — accept (TermLink re-agreement)

Without a rule, a human or an agent with CLI access can mint a countable `done{succeeded}`.

**Wording.** T7d `--as done` writes `result.kind: none` and `attested_by: <actor>`, sets `attested: true`, and its
`outcome` is whatever the operator names. Consumers (review verdicts, pass-rate, `counted`) refuse an attempt with
`attested: true` and `result.kind: none` as finished work, exactly as they refuse `paused` (CC-19). New case CC-22.

## S4. The 30-day `lost` upgrade window — accept-with-change (TermLink re-agreement)

A forged late T5 could flip a decision a month later, because the window length makes the nonce the only gate.

**Position.** Keep the 30-day window (TermLink agreed the number) but **bind T5 to evidence persisted before T4.**
The signed completion carries `persisted_at`, written by the supervisor before any terminal write (§6.5). T5 is
accepted only if `persisted_at` is not later than the `lost` history entry. A T5 that fails this is
`forbidden_transition`, logged and routed to the operator (T7d does not apply, since the attempt is `lost`, not
`unknown`; the operator route is a notice and a recorded decision). New case CC-24. Legitimate late evidence is
unaffected: the evidence existed before the end was confirmed, since T4 itself requires a confirmed end.

**Residual, stated.** Whoever holds the signing credential can still forge `persisted_at`; the bound closes the
nonce-only forgery path and makes the forgery need the supervisor credential from item 3.

---

## Changes TermLink must re-agree before v0.3 is final

1. Lifecycle writes need a supervisor credential distinct from the nonce (items 3, S1).
2. `fence_reject` definition and CC-06/CC-07 wording; completion on a `lost`/`unknown` attempt is processed as T5/T7b (item 4).
3. The reconciler may write T3/T3b (item 12).
4. T7d posts an operator notice and refuses agent sessions as a speed bump (S2).
5. T7d `done` is `attested`, `result.kind: none`, refused by consumers as finished work (S3).
6. T5 requires `persisted_at` ≤ the `lost` entry (S4).

Additive and not needing re-agreement (TermLink to be told): external backends (1, 7), sweep-writer role (2), rank
rule wording (5), I8 (6), `cause` on history (9), editorial (10), per-backend numbers (11), migration checklist (8).

## Version field

Semantics change (items 1, 3, 4, 12 and S1-S4), so the field value becomes `wc/0.3`. MAJOR stays 0; a reader that
refuses an unknown MAJOR still reads v0.3. TermLink's hub keeps accepting `wc/0.2` records until it has re-agreed.
