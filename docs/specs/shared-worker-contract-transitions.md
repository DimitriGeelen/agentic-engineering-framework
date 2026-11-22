# Shared dispatched-worker contract — transition table and conformance spec

**Status:** DRAFT v0.3.4 pending adoption (AEF operator; TermLink operator via their T-3484; ring20). v0.3.4 (three items: refusal order, dispatch closure, the `withdrawn` outcome) is proposed, not adopted: until all three adopt it, v0.3.3 is the agreed text. v0.3.3 history: v0.3.3 was for agreement by TermLink, ring20 and AEF. TermLink AGREES to v0.3.x: the six changes marked "TermLink re-agreement" in `docs/reports/T-4439-reviews/ring20-v0.2-answers.md` (v0.3) and v0.3.1 [termlink v0.3 agree]; v0.3.3 words in its hub credential carrier. ring20: SIGN-WITH-NOTES on v0.3, signing conditions N1-N3 and notes N4-N6 worded in here; v0.3.1 is the version ring20 signs; v0.3.2 is editorial only. **Task:** T-4439 (slice 1 of T-4435, GO 2026-10-20).
**Contract version field value:** `wc/0.3` (see §2; a patch revision does not change it). **Rule:** no implementation starts before this table is agreed.

## Changelog v0.3.3 → v0.3.4

Sources: **[ring20 closure]** = ring20 msgs 59742ea8, e93a0367 and 4b03810f (their mechanical runner on be.31: a
dispatch closed after a resolve-as-lost or a paused end answers a later allocate with a refusal, so CC-15 and CC-19
fail on a step the spec never asked a backend to support; and their T-2544 adapter derives `refused` before the
hand-back check); **[termlink 14d0100a]** = TermLink's implementation-side reply: no objection to either item, its
hub never closes a dispatch and already orders refusal first (`worker_contract.rs:605-628`); formal adoption is by
TermLink's operator through their T-3484. **[ring20 T-2790 3d5e1fda]** = ring20's request (their T-2790, msg 3d5e1fda,
2026-11-20, operator-requested): a submitter cannot take back a pool job that never started (9 judge jobs held 5 h on two
nodes); **[termlink ab85e88e]** = TermLink's answer from its backend (`worker_contract.rs`, `dispatch_contract.rs`):
agree, with the evidence and question-closing points, the credential rule and the start-after-T2 requirement (AEF
record: `docs/reports/T-5300-withdraw-outcome.md`). **[termlink e9015b84]** = TermLink's operator ruling on v0.3.4:
items 1 and 3 adopted as drafted, item 2 only with amendments A1-A6; **[termlink c2d29013]** = the six weaknesses
W1-W6 of item 2 as drafted, found independently by TermLink's two reviewers; **[ring20 0e5516a8]** = ring20 adopts
item 2 with A1-A6, checked against its orchestrator's commission store (AEF record:
`docs/reports/T-5318-dispatch-closure-amendments.md`). **DRAFT for adoption:** nothing here is in force until the AEF operator,
TermLink's operator and ring20 adopt it. The version field stays `wc/0.3` (§2: a patch revision does not change it):
item 1 states the order every implementation and the CC-16/CC-21 vectors already use, and item 2 adds an optional
backend behaviour of which a backend that never closes a dispatch sees only a typed refusal of close and two new
`fence_reject` reasons it must tolerate. Item 3 adds an outcome value, which every
reader of `outcome` sees; it too keeps `wc/0.3`, for the reasons given in the item.

1. **Refusal before rule 1 (§3.3 outcome derivation):** rule 1 (hand-back missing or malformed →
   `handback-malformed`) applies to a worker that ran. A run.sh or supervisor refusal yields `refused` through rule 2
   even with the hand-back absent, because a refused worker never ran and so never owed one. The rules keep their
   numbers, so every "rule N" reference (CC-16, §3.3 backend stop, CC-25) still holds. Clarification: it matches
   TermLink's `worker_contract.rs:605-628`, ring20 T-2544 and the AEF vectors CC-16 `supervisor-refusal` and CC-21
   `refused-before-start`. [ring20 closure] [termlink 14d0100a]
2. **Dispatch closure (§2, §3.3 T1, close and `fence_reject`, §4.7, §8.4, CC-15, CC-19, CC-15a/b, CC-19a/b,
   CC-30 to CC-43), amended by A1-A6:** a backend that declares `closure: supported` may close a dispatch once its
   last attempt is terminal (`done` or `lost`). A T1 on a closed dispatch is `fence_reject(dispatch_closed)`. As
   first drafted ("MAY close", CC-15/CC-19 "accept either") the item was unsafe; TermLink's two reviewers found six
   weaknesses (W1-W6) and TermLink adopts the item only with the six amendments below, which answer them in order.
   [ring20 closure] [termlink 14d0100a] [termlink e9015b84] [termlink c2d29013]
   - **A1 Close is one fenced transaction (W1).** Close is a compare-and-set on (last attempt, last state ∈ {done,
     lost}), the exact set that admits T1, checked in the same atomic step as the write. Commit order decides close
     against T1: a close that lost the race is refused `cas_mismatch` (the last attempt changed) or
     `dispatch_not_terminal` (the last attempt is not terminal). (§3.3 close, CC-30 to CC-32)
   - **A2 Closure fences T1 only (W2).** Every attempt-level transition legal before close stays legal after it:
     a late `lost → done` with evidence (T5), `done{paused}`, T8 and `done_conflict`. Finishedness is always computed
     from the attempts, never from `closed`. Close is refused while the last attempt is `unknown` or non-terminal.
     (§3.3 close, §4.7, CC-32 to CC-34)
   - **A3 Declared capability, typed answers (W3).** Each backend declares `closure: never|supported` (§2).
     `fence_reject(dispatch_closed)` is returned only when a readable close record exists, and is returned with it.
     CC-15 and CC-19 are split: with no close record, T1 MUST succeed (CC-15a, CC-19a); on a closure-supported
     backend with a readable close record, T1 is `fence_reject(dispatch_closed)` with the record (CC-15b, CC-19b). A
     `never` backend answers a close with a typed refusal, never a silent no-op. A client treats a `fence_reject`
     reason it does not know as a non-retryable typed refusal, so a new reason needs no version bump. (§2, §3.3,
     CC-35)
   - **A4 Close is authenticated (W4).** Close presents the last attempt's supervisor credential (§3.2), or runs
     under a policy the backend declares, recorded as actor `backend:<policy-id>`. The actor is derived from the
     credential or the policy, never from caller text. A failed check is `fence_reject(bad_credential)` and is
     recorded. (§3.3 close, CC-36, CC-37)
   - **A5 Closure is terminal (W5).** wc/0.3 has no reopen. Work continues only in a new dispatch with
     `retry_of_dispatch_id` = the closed id, which every backend MUST accept. Readers expose `closed`, `finished`
     and the last attempt's state and outcome as separate fields: closed + `paused` is not finished. (§4.7, §8.4,
     CC-38 to CC-40)
   - **A6 Idempotent, audited, owned (W6).** The first close wins; a repeated close returns the stored record
     unchanged with `created: false`. Every close and every `dispatch_closed` refusal appends a dispatch-level
     `history` row. Closedness is authoritative only on the dispatch's own backend (§6.4). (§2, §4.7, CC-41 to
     CC-43)

   **Adoption:** ring20, whose orchestrator is the backend that closes, checked A1-A6 against its commission store
   and adopts item 2 with them. A1 and A3 already fit; the changes on its side are: a late completion after close
   is recorded without reopening, not refused (A2); each close row records the policy id
   `backend:ring20-orch-supervisor` (A4); a re-commission carries `retry_of_dispatch_id` (A5); a repeated close
   returns the stored record with `created: false` (A6); and a commission whose attempt never launched is no longer
   closed directly, because that close is `dispatch_not_terminal` (A1, A2): the attempt is ended first (T3w
   `withdrawn` for a release, T3 `done{failed}` with the launch error for a failed launch) and the dispatch closed
   after. ring20's pool daemon stays `closure: never`; their orchestrator declares `supported`. AEF's local backend
   and TermLink's hub are `closure: never`. ring20 adopts v0.3.4 on this text with no objection to the choices
   T-5320 made. [ring20 0e5516a8] [ring20 a2e5c72b]
   **Version field stays `wc/0.3`:** every amendment is additive. A `closure: never` backend sees only two things: it
   answers a close with a typed refusal, and it tolerates the new reasons. No record becomes unreadable.
3. **The `withdrawn` outcome (§2, §3.1, §3.2, §3.3 T2, T3w, T8 and `fence_reject`, §5.5, Open questions 7, CC-26 to
   CC-29):** a submitter may take back an attempt that never started. New row **T3w**, a T3b variant: `dispatched →
   done{withdrawn}`, CAS expected-prior `dispatched`, accepted only for the current attempt with a matching
   `supervisor_gen` (or the lease, §3.2). From `running` it is `fence_reject(cas_mismatch)` (the worker started; stop
   it instead); from `done`, `lost` or `unknown` it is `fence_reject(forbidden_transition)`, except that the same
   withdrawal repeated (identical `evidence_digest`) is a T8 response. **Who:** only the holder of the attempt's
   credentials: the nonce plus the `supervisor_token` that `dispatch.allocate` returned once to its caller, on an
   Execute-scope connection (hub); other backends, the §3.2 lifecycle credential or channel. The hub's sweep never
   withdraws, and this revision has no operator path (a separate decision, like T7d; Open questions 7).
   **Evidence:** `evidence_digest` = sha256 of the reason, `result.kind: none`, no hand-back, `exit_code` null.
   **Effects:** closes the attempt's open questions and bounces its un-acked answers as any `done` does (§5.5);
   logged in `history` with actor and reason; **no** operator notice. `withdrawn` is terminal and never success: not
   counted as finished work, success or failure. **New supervisor rule (§3.3 T2):** a supervisor launches the agent
   child only after its T2 was accepted; a refused T2 means the attempt is gone and nothing is launched. With that,
   the T2/T3w race needs nothing beyond the CAS: each runs in one atomic step that checks the actual state, so exactly
   one wins and the other gets `cas_mismatch` (CC-27). **Version field stays `wc/0.3`:** the field exists so a reader
   can refuse a record it cannot read (§2); an added outcome value does not make a record unreadable, provided every
   reader treats an outcome value it does not know as terminal and not finished work, the way it treats `paused`.
   This item adds that reader rule (§2), and no backend emits `withdrawn` before all three owners adopt v0.3.4, so no
   adopted reader meets it unprepared. A bump would instead make every v0.3.3 reader refuse every record, including
   the many that never carry the value. [ring20 T-2790 3d5e1fda] [termlink ab85e88e]
   *Corrected:* CC-26 first gave the dispatched attempt an open question, which the T2 rule above makes impossible; it
   now uses one un-acked dispatcher answer with no `question_id`. [termlink 77878a68]

## Changelog v0.3.2 → v0.3.3

Source: **[termlink v0.3 agree]** = TermLink's reply msg 469e56bc (2026-10-20): it agrees to v0.3 (all six changes) and
v0.3.1, and answers open question 6 (what carries the supervisor credential on the hub). The version field stays
`wc/0.3`: v0.3 already required a hub `supervisor_token` returned at T1; this names its carrier.

1. **Status:** TermLink AGREES to v0.3.x. [termlink v0.3 agree]
2. **Hub carrier (§3.2, §4.1):** `dispatch.allocate` returns `{dispatch_id, attempt, nonce, supervisor_token}`; the
   token is 32 random bytes, returned once, stored only as its sha256. Lifecycle writes present it; worker-field
   writes present the nonce only; a wrong or missing token is `fence_reject(bad_credential)`. [termlink v0.3 agree]
3. **Open question 6 closed** for the hub; the reconciler's credential for non-hub backends stays open. [termlink v0.3 agree]
4. **§6 honest limit:** with supervisor and worker under one uid the token is a speed bump, not a boundary.
   [termlink v0.3 agree]
5. **§4.4:** a writer delivers a change plus the commission marker; who records the commit is a backend detail.
   Clarification, no semantics change. [ring20 arc-009 evidence 2] (ring20 msg 976856dd: a codex writer cannot
   commit inside its sandbox, so their supervisor records it.)

## Changelog v0.3.1 → v0.3.2

Source: **[ring20 v0.3 check]** = the full per-point check of v0.3, saved at
`docs/reports/T-4439-reviews/ring20-v0.3-full-check.txt`; these are its editorial nits that v0.3.1 did not cover.
**Editorial only: no semantics change**, nothing TermLink agreed is altered, the version field stays `wc/0.3`.

1. **T4 evidence and §3.4** are marked as the hub's two-sweep/epoch evidence, with a pointer to §3.2's hubless sweep
   writer (independent probe such as unit state, evidence read before the write). [ring20 v0.3 check, point 2 nit]
2. **§3.2 lists T8 for the reconciler**, which CC-04 already relies on. [ring20 v0.3 check, point 10 nit]
3. **T4's "`G` at least 4 × the sweep interval"** is marked hub-only; other backends set `G` per §2.
   [ring20 v0.3 check, point 11 nit]

## Changelog v0.3 → v0.3.1

Source: **[ring20 v0.3 check N#]** = ring20's check of v0.3 against the text (SIGN-WITH-NOTES, saved at
`docs/reports/T-4439-reviews/ring20-v0.3-check.txt`): N1-N3 are its signing conditions, N4-N6 its notes. The version
field stays `wc/0.3`. **Effect on what TermLink agreed:** N1 and N3 add alternatives **for external backends only**
(§6.6); the `hub` and `local` rows, writers and evidence are unchanged, so neither needs TermLink's re-agreement.
N2 adds a reporting duty for external backends only. N4, N5 and N6 make explicit what v0.3 already required (the §2
schema, outcome rule 1 and CC-16, the T7b evidence) and change no `hub` or `local` behaviour; they are listed so
TermLink can see them, not for re-agreement.

1. **Lease instead of `supervisor_gen`** (§3.2, I3, T-RECLAIM, §6.6, CC-13, CC-14): an external backend may replace
   `supervisor_gen` and the per-write lock with an exclusive single-writer lease declared in its mapping; CC-13/CC-14
   then test the lease. External backends only. [ring20 v0.3 check N1]
2. **Per-case applicability** (§6.6, §9 intro): the mapping table declares every conformance case `pass` or `n/a`
   with a reason; `n/a` only for a capability the backend does not offer, never for a case whose subject is a §3
   transition row. External backends only. [ring20 v0.3 check N2]
3. **Channel-bound evidence** (§3.2, T5, T7b, §6.5): T5/T7b evidence and §6.5 accept "or channel-bound evidence per
   §3.2" as an alternative to `exit_code` file + signed completion, for an external backend that authenticates by
   channel. `persisted_at` still binds it (S4). External backends only. T3's need for the child's real exit status is
   unchanged (ring20 to capture it, its own gap). [ring20 v0.3 check N3]
4. **`handback.commission`** equals the dispatch id, for an external backend modulo the `<backend>:` prefix; outcome
   rule 1 names the commission check. Clarification of the §2 schema. [ring20 v0.3 check N4]
5. **Stop with no hand-back** (§3.3 stop paragraph, T4 note, CC-25): a confirmed child exit with a missing or malformed
   hand-back is `done{handback-malformed}` through T3; `lost` only when there is no confirmed exit evidence. CC-25(b) now
   agrees with CC-16 and rule 1. Clarification. [ring20 v0.3 check N5]
6. **T7d evidence** (§3.3 T7d, CC-22): `--as done` with evidence requires the same bound evidence as T7b, verified by
   the backend; anything else is an attestation. Clarification. [ring20 v0.3 check N6]

## Changelog v0.2.1 → v0.3

Source: **[ring20 v0.2 review §N]** = point N of ring20's part-1 review (`docs/reports/T-4439-reviews/ring20-v0.2-part1.txt`);
**[ring20 v0.2 review §S1..S4]** = the four security points of part 2. AEF's position on each is in
`docs/reports/T-4439-reviews/ring20-v0.2-answers.md`. Items marked ◆ alter what TermLink agreed at v0.2.1.

1. **External backends** (§2, new §6.6): a supervisor with its own store is a backend; hub-only fields are optional for
   it. [ring20 v0.2 review §1]
2. **Sweep writer role** (§3.2): T4/T6/T6b/T7a/T7c are written by the backend's sweep module, which without a hub may run
   in the supervisor if the end is independently confirmed and evidence is read before the write. [ring20 v0.2 review §2]
3. ◆ **Writer authentication** (§3.2, I3): the nonce identifies the attempt and authorises worker-permitted fields only;
   lifecycle writes also need a supervisor credential or a channel the worker cannot write. [ring20 v0.2 review §3, §S1]
4. ◆ **Per-attempt fence** (§3.3 `fence_reject`, §4.3, CC-06, CC-07): a completion naming a `lost`/`unknown` attempt is
   processed as T5/T7b; `stale_attempt` covers running-path writes only. Fixes the v0.2 contradiction.
   [ring20 v0.2 review §4]
5. **State is the last accepted transition** (§3.1): rank decides acceptance, never state; T7a is the one accepted
   rank-decreasing transition. Fixes the v0.2 contradiction. [ring20 v0.2 review §5]
6. **I8**: verification, review and landing never change `outcome`. [ring20 v0.2 review §6]
7. **Id grammar and per-attempt rows** for external backends (§4.1, §8.4). [ring20 v0.2 review §7]
8. **Migration checklist** names the direct legacy-row writers (§8.3). [ring20 v0.2 review §8]
9. **Backend-initiated stop** with `cause` on the history entry (§3.3). [ring20 v0.2 review §9]
10. **Editorial:** `resolved-unknown` removed from T1; T8 is a response, not a transition (I1 now true). [ring20 v0.2 review §10]
11. **Per-backend numbers** with the invariant on `G` (§2, Open questions). [ring20 v0.2 review §11]
12. ◆ **Admissible histories** per case (§9 intro, CC-01, CC-03) and ◆ **the reconciler may write T3/T3b** (§3.2, §3.3).
    [ring20 v0.2 review §12]
13. ◆ **T7d** posts an operator notice and refuses agent sessions as a speed bump (§3.3). [ring20 v0.2 review §S2]
14. ◆ **Attested `done`** carries `result.kind: none`, `attested_by`, and is refused by consumers as finished work
    (§3.3, CC-22). [ring20 v0.2 review §S3]
15. ◆ **T5 is bound to evidence persisted before T4** via `persisted_at` (§3.3, §6.5, §7.3, CC-24).
    [ring20 v0.2 review §S4]
16. New cases CC-22 (attested done), CC-23 (nonce alone cannot complete), CC-24 (late forged T5), CC-25 (backend stop with
    cause, external backend). The version field becomes `wc/0.3`; MAJOR is unchanged.

## Changelog v0.2 → v0.2.1

Source: **[termlink v0.2 agree]** = TermLink's AGREE to v0.2 (msg b73b1cf3, 2026-10-20), three non-blocking fixes, no
new round. The contract version field stays `wc/0.2`.

1. **§3.4 gains the sweep row that produces T7c** (`unknown` → `lost`): seen alive at the current epoch, then absent
   on two consecutive sweeps at that epoch, then reconciliation, `lost` only after `G`. Before, `unknown` could only
   leave through T7a, T7b or T7d. [termlink v0.2 agree §1]
2. **`deadline_dispatched` default:** spawn timeout + `G` (120 s), stated next to `deadline_running` (§2).
   [termlink v0.2 agree §2]
3. **Open question 3 closed:** ring20 has no reconciler of its own; its supervisor submits late evidence through T5.
   [termlink v0.2 agree §3]

## Changelog v0.1 → v0.2

Sources: **[termlink v0.1 review]** = `docs/reports/T-4439-reviews/termlink-v0.1.md`; **[AEF v0.2 answers]** =
`docs/reports/T-4439-reviews/termlink-v0.2-input.md` (TermLink's four points, all four AEF answers accepted by TermLink).

1. **T4 is a hub write from state, not from an event** (§3, T4, §4.5): a 30 s sweep confirms session end by two
   consecutive absent sweeps at the same `registry_epoch`, then asks for reconciliation, then writes `lost` only after
   `G` with no fenced `done`. [termlink v0.1 review §1] [AEF v0.2 answers §1]
2. **`registry_epoch`** added to the schema and to T4/T6. [AEF v0.2 answers §1.1]
3. **New row T6b** (`dispatched` → `unknown`, `deadline_dispatched`); the old T6 is unchanged. [AEF v0.2 answers §1.3]
4. **`lost` seen alive again: no transition**, logged and an operator notice (§3 Forbidden). [AEF v0.2 answers §1.4]
5. **Worker binding** is an explicit field, unique among live sessions; the session name is a convention only (§2, §4.5).
   [termlink v0.1 review §1.2]
6. **`dispatch_id` may be caller-chosen** (well-formed `D-<ulid>`, `id_taken` when used, never substituted) (§4.1).
   [AEF v0.2 answers §2]
7. **T7d**: until a signed operator identity exists, resolve is a hub-host CLI, every call logged with its reason.
   [AEF v0.2 answers §3]
8. **`paused` is a fifth outcome** (§3 derivation rule 3b, §5.6, §8.4). [termlink v0.1 review §3.1] [AEF v0.2 answers §4]
9. **CC-08 reworded** (registry survives hub restart); `deadline_running` defaults to worker timeout + 10 min; new cases
   CC-17..CC-21. [termlink v0.1 review §1.3, §2]
10. Open questions 1 and 5 closed; 2 partly closed (§Open questions).

Source key used in every section: **[codex]**, **[claude]**, **[opencode]** = the three reviews in
`docs/reports/T-4435-reviews/`; **[§6.x]** = the synthesis in `docs/reports/T-4435-shared-worker-contract.md`;
**[C1..C6]** = the six conditions in §6.5 of that report; **[P]** = the 010-termlink proposal (§1 of that report);
**[agent]** = a choice made by the drafter, not stated by any source, and open to challenge;
**[termlink v0.1 review]**, **[AEF v0.2 answers]** = the two v0.2 inputs named in the changelog above.

---

## 1. Purpose and scope

*Sources: [C1], [C4], [§6.3 resolution], [claude Q1/Q5], [codex Q5].*

**Purpose.** One durable record per dispatched agent worker that is the single authority for *whether the worker
finished, and how*. Three implementations (TermLink hub, AEF local backend, ring20 supervisor) must give every
transition the same meaning, proven by the conformance cases in §9.

**In scope (completion authority only):**
- lifecycle states and the transitions between them (§3);
- attempt and nonce allocation, fencing (§4);
- the per-attempt answer channel (§5);
- local-file backend parity (§6), retention (§7), migration from `update_outcome_row` (§8).

**Out of scope (stated so nobody assumes it):**
- The **evaluation ledger** (`dispatch-outcomes.jsonl`, backprop at task close, the pass-rate table). It stays a
  separate append-only fact keyed by (dispatch id, attempt, result hash). [claude Q3, §6.3]
- Review verdict semantics, other than that a verdict names `(dispatch_id, attempt, result.value)`.
- The sidecar notice layer (a later push *hint*; polling the record stays the source of truth). [opencode Q4]
- Isolation of workspaces. Workers share the main checkout; the contract handles that by forbidding overlapping
  attempts (§4.3), not by isolating them. [claude 1c, codex Q1]
- Forgery resistance against a hostile process of the same OS user. The nonce defeats stale attempts, **not** forgery:
  it is visible in the worker's prompt. Lifecycle writes therefore also need a supervisor credential or a channel the
  worker cannot write (§3.2); that removes the accident and prompt-echo path, not a worker that reads its supervisor's
  environment. Same stance as the review-dispatch HMAC: fail-closed against accidents. [claude Q1] [ring20 v0.2 review §3, §S1]
- Verification, review and landing states. They are evaluation-layer facts keyed by `(dispatch_id, attempt,
  result.value)` and never change `outcome` (I8). [ring20 v0.2 review §6]

**Definitions.**
- *Dispatch*: one logical unit of work, id `dispatch_id`. *Attempt*: one numbered execution of it.
- *Supervisor*: the process that launched the agent child and outlives it by one step (AEF: `run.sh`; ring20: its
  supervisor). It writes `done`.
- *Hub*: the authoritative store for `backend: hub` records (TermLink). *Reconciler*: an AEF-side process that reads
  the worker dir and submits local evidence. *Operator*: a human via `fw worker resolve`. *External backend*: a
  supervisor with its own durable store that implements this contract in that store (§6.6). *Sweep writer*: the
  backend's module that writes T4/T6/T6b/T7a/T7c (§3.2).
- **"Worker stopped" means the agent child process exited**, not that the TermLink session ended. The supervisor
  finalises between those two events. [codex Q1]
- `done` means *stopped with evidence*, never *succeeded*. Success lives in `outcome`. [claude Q1, codex Q1, §6.2.7]

---

## 2. Record schema

*Sources: [P.1], [C1], [C5 version/retention], [§6.4], [opencode Q2 hand-back schema is contract surface].*

One record per `dispatch_id`, containing an ordered list of attempts. Shown as YAML; wire/serialisation is the
backend's business, field names and semantics are the contract.

```yaml
contract_version: wc/0.3          # required; a reader refuses an unknown MAJOR
dispatch_id: D-<ulid>             # caller-chosen (well-formed, unused) or backend-allocated; immutable once accepted (§4.1); external backends: <backend>:<id>
backend: hub | local | <external name>   # chosen at dispatch creation, immutable (§6.4); external = §6.6 [ring20 v0.2 review §1]
task_id: T-XXXX                   # optional, audit
retry_of_dispatch_id: D-<ulid>|null   # dispatch-level link, preserved verbatim (§8.4); NOT an attempt
closed: {actor, reason, ts}|null  # v0.3.4: the close record, set once by the close transaction (§3.3, §4.7); never cleared; always null on a closure: never backend
dispatch_history:                 # v0.3.4: append-only dispatch-level log, separate from the attempts' history
  - {event: close, actor, reason, ts}                          # one row per accepted close (A6)
  - {event: close_refused, reason: <fence reason>, actor, ts}  # a refused close, e.g. bad_credential (A4)
  - {event: dispatch_closed, attempt_requested, ts}            # one row per T1 refused dispatch_closed (A6)
dispatcher:                       # recorded at spawn, immutable [C5, claude Q3 cond.1]
  project_agent: <sidecar agent id>       # per project; routing doorbell only
  session: claude-master-<PID>            # the durable TermLink PTY session; the routing identity
  claude_session_id: <uuid>|null          # AUDIT ONLY: changes on `claude -c` and compaction
created_at: <ts>
attempts:                         # append-only list, index = attempt number starting at 1
  - attempt: 1
    nonce: <random>               # allocated with the attempt, never reused
    state: dispatched|running|done|lost|unknown
    outcome: succeeded|failed|refused|handback-malformed|paused|withdrawn|null   # non-null iff state == done; withdrawn only via T3w (v0.3.4)
    worker_kind: claude|ollama|pi|...
    session_binding:              # written at spawn, before the worker runs [claude 1b, §6.4]; hub fields OPTIONAL when backend is neither hub nor local
      worker_binding: D-<ulid>:1           # --worker-binding; unique among live sessions; the T4 key [termlink v0.1 review]
      session_name: tl-D-<ulid>-a1         # readable convention only; the hub never parses it
      registry_epoch_seen: <epoch>         # epoch of the sweep that last saw this attempt alive [AEF v0.2 answers]
    attempt_dispatch_ref: <id>|null  # OPTIONAL: the per-attempt row in the AEF dispatch ledger, if the backend writes one (§8.4); not an attempt
    attested: true|false          # true only for a T7d `done` with no evidence (§3.3)
    attested_by: <actor>|null
    supervisor_gen: 1             # increments on supervisor recovery (§3, T-RECLAIM); OPTIONAL for an external backend fencing by lease (§6.6) [ring20 v0.3 check N1]
    exit_code: <int>|null         # the agent child's real exit code (run.sh itself exits 0)
    result:                       # bound to THIS attempt [opencode Q1, §6.2.3]
      kind: commit_range|handback_sha256|none
      value: <sha or range or sha256>
      persisted_at: <ts>|null     # when the supervisor persisted the signed completion (§6.5); null for attested done
    handback:                     # schema is contract surface, validated by the backend [opencode Q2]
      commission: <id>            # = dispatch_id; for an external backend, equal modulo the `<backend>:` prefix (§4.1) [ring20 v0.3 check N4]
      attempt: <n>                # must equal the attempt it is written under
      nonce: <echo>               # must equal the attempt nonce
      status: complete|blocked|paused|failed   # paused + exit 0 derives outcome paused (§3.3)
      summary: <text>
      findings: [...]
    evidence_digest: <sha256 of the evidence the terminal write cited>
    history:                      # append-only transition log: (from, to, writer, ts, evidence_digest[, cause])
      - {from: null, to: dispatched, writer: hub, ts: ...}   # cause ∈ {deadline_stop, revoked, operator_stop} when a backend stopped the attempt (§3.3); a T3w entry also carries actor and reason (v0.3.4)
    answers:                      # per-attempt section; the lifecycle ignores it (§5)
      - {cmd_id, question_id, body, deadline, state: stored|received|applied|undelivered|expired, ...}
    questions: [...]              # worker-appended, same fence (§5)
    deadline_dispatched: <ts>     # spawn timeout + G (120 s) by default [termlink v0.2 agree §2]; after this with no T2 and no confirmable end -> unknown (§3 T6b)
    deadline_running: <ts>        # worker timeout + 10 min by default [termlink v0.1 review §2]; no confirmable end -> unknown (§3 T6)
```

**Per-backend parameters** [ring20 v0.2 review §11]: `G`, the sweep interval, `deadline_dispatched` and `deadline_running`
are parameters of the backend. The hub values above are TermLink's and stay. One invariant holds for all: **`G` is at
least the time for local evidence to become readable to the sweep writer.** A backend that reads the evidence *before*
it writes `lost` (ring20) may use `G = 0`; ring20's `deadline_running` is its worker `timeout_sec` + 60 s.

**Invariants (checked by the backend on every write):**
- I1. `state` changes only through a transition in §3; every transition appends to `history`. A T8 re-submission is a
  response, not a transition, and appends nothing (§3.3). [ring20 v0.2 review §10]
- I2. `outcome != null` iff `state == done`.
- I3. A write names `(dispatch_id, attempt, nonce)` and an **expected prior state**; the backend checks nonce and
  prior state in the *same atomic step* as the write. A lifecycle write (T2, T3, T3b, T3w, T-RECLAIM, T5, T7b, and T8) also
  presents the writer's credential or arrives on a channel the worker cannot write (§3.2), checked in the same step.
  For an external backend fencing by lease (§6.6), "the same step" means while holding the lease.
  [claude 1c, opencode Q1, codex Q1, §6.2.3] [ring20 v0.2 review §3] [ring20 v0.3 check N1]
- I4. `done` and `lost` are never both the *final* state: `done` outranks `lost` (§3 precedence).
- I5. `result` is written only together with `done` and is bound to its attempt.
- I6. At most one attempt of a dispatch is non-terminal at any time (§4.3).
- I7. `registry_epoch` is a hub-level value, bumped at every hub start and on any sweep whose registry listing was
  incomplete; each attempt keeps the epoch of the sweep that last saw it alive. [AEF v0.2 answers §1.1]
- I8. Verification, review and landing never change `outcome` or `state`. They are evaluation-layer facts keyed by
  `(dispatch_id, attempt, result.value)`, held outside the record. [ring20 v0.2 review §6]

**Unknown outcome values (reader rule, v0.3.4).** A reader that meets an `outcome` value it does not know treats the
attempt as terminal and **not finished work** (as `paused`): never success, never counted in a pass rate. This is what
lets an outcome value be added within `wc/0.3` (changelog v0.3.4 item 3). [termlink ab85e88e]

**Unknown `fence_reject` reasons (client rule, v0.3.4).** A client that meets a `fence_reject` reason it does not
know treats it as a typed refusal that is **not retryable**: it stops retrying that write and surfaces the reason.
It never errors out on the value and never retries it. This is what lets a reason be added within `wc/0.3`
(changelog v0.3.4 item 2, A3). [termlink e9015b84]

**Dispatch closure (v0.3.4, changelog item 2, A1-A6).** [termlink e9015b84] [ring20 0e5516a8]
- **Declaration.** Each backend declares `closure: never` or `closure: supported` in its mapping (§6.6; hub and
  local state theirs in §6). The hub and AEF's local backend are `never`. A `never` backend never writes `closed`
  and answers every close with a typed refusal (§3.3 close).
- **Close record.** `closed: {actor, reason, ts}`, written once by the close transaction (§3.3). `actor` is
  derived from the credential the close presented (the last attempt's supervisor credential, §3.2) or is
  `backend:<policy-id>` for a close the backend makes under a declared policy; never from caller text. A repeated
  close returns this record with `created: false`; the first close returned it with `created: true`.
- **Dispatch history.** `dispatch_history` gets one row for each accepted close, each refused close and each T1
  refused `dispatch_closed`. Closing appends nothing to any attempt's `history`.
- **Reader fields.** A reader of a dispatch exposes, as separate fields: `closed` (the close record or null),
  `finished` (computed from the attempts only: the last attempt is `done` with an outcome that counts as finished
  work), and the last attempt's `state` and `outcome`. `closed` never implies `finished`: a closed dispatch whose
  last attempt is `paused`, `withdrawn`, `lost` or attested is not finished work.

---

## 3. Transition table

*Sources: [§6.2.1] done/lost precedence and upgrade (all three seats); [§6.2.2] bounded unknown (all three);
[codex Q1] supervisor generation; [claude Q2] reconciler is AEF's; [claude Q1] outcome field; [agent] row numbering.*

### 3.1 States

| State | Meaning | Terminal? |
|---|---|---|
| `dispatched` | Attempt allocated, session binding written, worker not yet confirmed started (and, from v0.3.4, not yet launched: §3.3 T2) | no |
| `running` | Supervisor confirmed the agent child started | no |
| `done{outcome}` | Agent child **stopped**, fenced evidence accepted. `outcome` ∈ succeeded, failed, refused, handback-malformed, paused, withdrawn (`withdrawn`: the child was never launched, §3.3 T3w) | yes (final; see T5/T8) |
| `lost` | Hub confirmed the session ended with **no** completion evidence | terminal but **upgradable** to `done` (T5) |
| `unknown` | Bounded silence and no way to confirm (from `dispatched` or `running`); operator-visible; never decays on its own | no (must be resolved) |

Rank used for precedence: `done`(4) > `lost`(3) > `unknown`(2) > `running`(1) > `dispatched`(0). **State is the `to` of
the last accepted transition in `history`.** Rank is applied when a transition is *proposed*: it is accepted only if
its CAS holds and its target rank is not lower than the current rank; T7a (`unknown` → `running`, the heal path) is the
one named exception. Rank is never used to re-derive state from history. [opencode Q1, direct.py HANDED_OVER >
ESCALATED rule] [ring20 v0.2 review §5]

### 3.2 Writers

| Writer | Who | May write |
|---|---|---|
| `supervisor` | `run.sh` / ring20 supervisor holding the attempt nonce, the supervisor credential **and** current `supervisor_gen` (an external backend: or the single-writer lease, see below) | T2, T3, T3b, T-RECLAIM, T8 |
| `hub` (the *sweep writer*) | the backend's sweep module: the TermLink hub; for `backend: local`, the local backend module; for an external backend, its own sweep module. T4/T6/T6b/T7a/T7c are written from the state sweep (§3.4) | T1, T4, T6, T6b, T7a, T7c |
| `reconciler` | AEF reader of the worker dir; submits *local evidence*, never a verdict of its own; a supervisor that died is replaced by it for the completion write | T3, T3b, T5, T7b, T8 |
| `operator` | human, `fw worker resolve`, a hub-host CLI until a signed operator identity exists | T7d |
| `submitter` | the holder of the attempt's credentials: the nonce plus the `supervisor_token` that `dispatch.allocate` returned once to its caller, on an Execute-scope connection (hub); on other backends, the §3.2 lifecycle credential or channel. Usually the dispatcher; a supervisor holding the same credentials qualifies (v0.3.4) | T3w, and its T8 repeat |

The **sweep writer never withdraws**, and no operator path to T3w exists in this revision (Open questions 7). [termlink ab85e88e]

The worker (the agent) **never writes lifecycle fields**. It may append `questions` and ack `answers` only (§5).
[P.2, codex Q3 cond.2 field-level permissions]

**Without a hub, the sweep writer may run inside the supervisor** on two conditions: the session or unit end is
confirmed by an independent probe (a service manager's unit state counts, §6.3), and the local evidence is read
*before* the write. A supervisor's own say-so that the worker is gone is not a probe. [ring20 v0.2 review §2]

**Writer authentication.** The nonce identifies the attempt and authorises only the worker-permitted fields
(`questions`, answer acks). A lifecycle write also needs a **supervisor credential the worker never sees** (hub: a
`supervisor_token` returned with `(attempt, nonce)` at T1, stored hashed, kept out of the agent child's environment
and prompt), **or** a channel the worker cannot write (ring20: root-owned stdout; the nonce there is an echo). Each
backend states which it uses. A write that carries a valid nonce but no credential or channel proof is rejected
`bad_credential`. **Hub carrier:** the `supervisor_token` (§4.1) is 32 random bytes, returned once by
`dispatch.allocate`, and the hub keeps only its sha256 (as for the nonce). Every lifecycle write presents it: the
supervisor's T2, T3, T3b, T-RECLAIM, T8 and the reconciler's T3, T3b, T5, T7b (and T8). Worker-field writes
(`questions`, answer acks) present the nonce only. A wrong or missing token is `fence_reject(bad_credential)`.
[termlink v0.3 agree] Evidence for T3/T3b/T5/T7b is the signed completion of §6.5, so a reconciler cannot assert more
than the supervisor persisted. Residual: a hostile same-user process can read its supervisor's environment; this
removes the accident and prompt-echo path, not that one. [ring20 v0.2 review §3, §S1]

**Channel-bound evidence (external backends only).** A backend that authenticates by channel may present, instead of
the signed completion, *channel-bound evidence*: the hand-back and the agent child's exit status as read by the
supervisor from the channel the worker cannot write, persisted by the supervisor in the backend's store under the
attempt's `(dispatch_id, attempt, nonce)`, with `persisted_at` set to that store write. It is evidence of the same
strength for that backend and is accepted wherever this spec says "or channel-bound evidence per §3.2". `hub` and
`local` use the signed completion. [ring20 v0.3 check N3]

**Lease instead of `supervisor_gen` (external backends only).** An external backend may replace `supervisor_gen` and
the per-write lock (§6.2) with an **exclusive single-writer lease**: at most one supervisor holds the lease for a
dispatch at any time, every lifecycle write is validated and applied while the lease is held, and a writer that does
not hold the current lease is rejected `fence_reject(stale_gen)` (the reason names the fencing token, whichever its
form). T-RECLAIM is then the lease takeover: a restarted supervisor that acquires the lease is the current writer and
the previous holder's later writes are refused. The backend declares the lease, its holder identity, its expiry and
its takeover rule in its mapping (§6.6). [ring20 v0.3 check N1]

### 3.3 Transitions

CAS = the write is applied only if the current state equals *expected prior* and the nonce matches; otherwise it is
rejected (never merged). `fence_reject` is defined after the table.

| # | From → To | Writer | Required evidence | CAS expected-prior | Precedence / notes |
|---|---|---|---|---|---|
| T1 | ∅ → `dispatched` | hub | dispatcher identity; prior attempt (if any) is terminal; backend allocates `attempt` and `nonce` atomically | no attempt exists, or last attempt state ∈ {done, lost} (an operator-resolved `unknown` is `lost` or `done` after T7d); and the dispatch is not closed (§4.7) | allocation is the only place attempts are minted (§4). On a dispatch with a readable close record: `fence_reject(dispatch_closed)`, returned with the record, and a `dispatch_history` row; with no close record T1 is decided by the CAS alone. T1 and close race only through their CAS (close, below) [v0.3.4, A1, A3] |
| T2 | `dispatched` → `running` | supervisor | echo of `nonce`; session binding confirmed; `supervisor_gen` claimed | `dispatched` | sets `deadline_running`. **v0.3.4:** the supervisor launches the agent child only **after** its T2 was accepted; a refused T2 (`cas_mismatch`: the attempt was withdrawn) means it launches nothing and ends. A supervisor that launches first and records T2 afterwards can run a withdrawn job and is non-conforming [termlink ab85e88e]. If the launch fails after T2 was accepted, the supervisor ends the attempt through T3 with the launch error as evidence; the outcome is `failed` (rule 3: the agent child never ran, so no hand-back is owed under rule 1). It is never ended by a withdrawal: T3w applies only to `dispatched` [ring20 4c9335d8] |
| T3 | `running` → `done{outcome}` | supervisor, or reconciler when the supervisor is gone | agent child exited; `exit_code` read **after** exit; hand-back parsed and hash computed; `evidence_digest` | `running` | the single normal completion path; `outcome` derived by rule below. A reconciler submits the same fenced local evidence when the supervisor died, for instance inside `G`; so `running → done` is a valid history [ring20 v0.2 review §12] |
| T3b | `dispatched` → `done{outcome}` | supervisor, or reconciler when the supervisor is gone | as T3 (worker died/refused before T2 landed, e.g. run.sh `exit 3`) | `dispatched` | covers fast-fail without a spurious `lost` |
| T3w | `dispatched` → `done{withdrawn}` | submitter (§3.2) | a withdrawal request with `actor` and `reason`, for the **current** attempt, presenting its nonce and credential and a matching `supervisor_gen` (an external backend fencing by lease: the lease, §3.2). `evidence_digest` = sha256 of the reason (UTF-8); `result.kind: none`, no `result.value`, no hand-back, `exit_code` null, `attested: false` | `dispatched` | a T3b variant (v0.3.4). `outcome: withdrawn` is written, never derived. From `running`: `fence_reject(cas_mismatch)` (stop the worker instead, §3.3 backend stop). From `done`, `lost`, `unknown`: `fence_reject(forbidden_transition)`, except a repeat of the same withdrawal (identical `evidence_digest`), which is T8. The `history` entry carries `actor` and `reason`; **no** operator notice. Closes the attempt's open questions and bounces its un-acked answers as any `done` (§5.5). T2 and T3w race only through the CAS: exactly one is accepted (CC-27). `withdrawn` is terminal and not finished work; a later T1 may allocate A2 (§4.3) [ring20 T-2790 3d5e1fda] [termlink ab85e88e] |
| T-RECLAIM | `running` → `running` | supervisor | restarted supervisor presents nonce + local worker dir + `supervisor_gen = prev + 1` | `running` and `supervisor_gen == prev` | fences a stale supervisor: its later writes carry the old gen and are `fence_reject`ed [codex Q1]. An external backend fencing by lease: lease takeover, expected-prior `running` and the lease held (§3.2) [ring20 v0.3 check N1] |
| T4 | `running`/`dispatched` → `lost` | hub | session end **confirmed from state** (§3.4). The hub's evidence: the attempt was seen alive, then absent on two consecutive sweeps at the epoch of the sweep that last saw it alive; then reconciliation requested; and no fenced `done` evidence within `G`. Without a hub, the sweep writer's evidence is §3.2's: an independent probe (unit state) confirms the end, and local evidence is read *before* the write [ring20 v0.3 check] | `running` or `dispatched` | never on a missed heartbeat and never from an event. `G` (hub: default 120 s, at least 4 × the sweep interval; other backends set their own `G` per §2) lets local evidence win; earliest `lost` ≈ 60 s + `G` after the end [codex Q1] [termlink v0.1 review §1.1, §2.1] [AEF v0.2 answers §1.2]. A confirmed exit of the agent child (its real exit status is known) is completion evidence even with no hand-back: it ends through T3 as `handback-malformed`, not T4 [ring20 v0.3 check N5] |
| T5 | `lost` → `done{outcome}` | reconciler (or supervisor, late) | fenced local evidence: `exit_code` + signed completion + hand-back hash, or channel-bound evidence per §3.2 (external backends), matching `(dispatch_id, attempt, nonce)` [ring20 v0.3 check N3] | `lost` | **idempotent upgrade**; `done` outranks `lost`. Appends history, keeps the `lost` row for audit [§6.2.1]. Accepted only if the evidence's `persisted_at` is not later than the `lost` history entry (the evidence existed when the end was confirmed); otherwise `forbidden_transition`, logged, operator notice. A T3/T3b naming a `lost` attempt is processed as T5 [ring20 v0.2 review §4, §S4] |
| T6 | `running` → `unknown` | hub | `deadline_running` passed, session end neither confirmed nor refuted: still alive past the deadline, absence seen only at another epoch (registry rebuilt or incomplete), partition, worker on another hub, reused pid | `running` | operator-visible; raises one operator notice; **never** triggers a new attempt by itself [§6.2.2] [AEF v0.2 answers §1] |
| T6b | `dispatched` → `unknown` | hub | `deadline_dispatched` passed and the session was never seen alive (so no T2 and no T4 basis) | `dispatched` | same notice rule as T6; a worker that refused or died before T2 still ends through T3b from supervisor evidence [AEF v0.2 answers §1.3] |
| T7a | `unknown` → `running` | hub | session confirmed alive again | `unknown` | heal path |
| T7b | `unknown` → `done{outcome}` | reconciler | same evidence as T5, including channel-bound evidence per §3.2 (no `persisted_at` bound: `unknown` has no confirmed end) | `unknown` | `done` outranks. A T3/T3b naming an `unknown` attempt is processed as T7b |
| T7c | `unknown` → `lost` | hub | confirmed session end, no evidence | `unknown` | |
| T7d | `unknown` → `lost` \| `done{outcome}` | operator | explicit `fw worker resolve <id> <attempt> --as lost\|done --reason "…"`, run on the hub host; `done` additionally needs evidence **or** an operator-attested `outcome`, which writes `attested: true`, `attested_by`, `result.kind: none` and no `evidence_digest`. "Evidence" here is exactly T7b's: a signed completion, or channel-bound evidence per §3.2 for an external backend, bound to `(dispatch_id, attempt, nonce)` and verified by the backend in the same step as the write; the outcome is then derived by the rule below, never chosen by the operator. Anything the operator supplies that is not so bound (a pasted log, a description, a hash with no signed completion) is not evidence: the write is an attestation and records `attested: true` [ring20 v0.3 check N6] | `unknown` | the only way out of `unknown` without hub/reconciler evidence; every resolve is logged with actor and reason. Until a signed operator identity exists this is a hub-host CLI, not an RPC, because scope alone cannot tell an operator from an agent holding control scope [AEF v0.2 answers §3]. **Detective control:** every resolve posts a notice to the operator's channel with dispatch, attempt, outcome, reason, actor and host. **Speed bump:** the CLI refuses an agent session (agent-environment markers present) without an explicit, recorded override; this is stated as a speed bump, not identity [ring20 v0.2 review §S2]. An attested `done` is **not finished work**: consumers (review verdicts, pass-rate, landing) refuse it as they refuse `paused` [ring20 v0.2 review §S3] |

**T8 (duplicate finalisation) is a response, not a transition.** Re-submitting a `done` with an identical
`evidence_digest` returns the stored record, appends nothing and changes nothing. [ring20 v0.2 review §10] This
covers a repeated withdrawal: a T3w naming a `done{withdrawn}` attempt with the same `evidence_digest` (the same
reason) is deduplicated; with a different reason it is `forbidden_transition`. A completion (T3/T3b) naming a
`done{withdrawn}` attempt carries different evidence and is `done_conflict`, as for any `done` (v0.3.4).
[termlink ab85e88e]

**Close (v0.3.4, A1-A4, A6) is a dispatch-level write, not an attempt transition.** It is one fenced
transaction: a compare-and-set on (last attempt number, last attempt's state ∈ {done, lost}), the exact condition
that admits T1, checked in the same atomic step as the write (I3; an external backend fencing by lease: while
holding the lease). So commit order alone decides a close against a T1. [termlink e9015b84] [termlink c2d29013]
- **Request:** `close(dispatch_id, expected_attempt, reason)` with the credential of `expected_attempt`'s
  supervisor (§3.2), or under a backend policy the backend declares in its mapping (§6.6).
- **Accepted** when no close record exists, `expected_attempt` is still the last attempt and its state is `done`
  or `lost`. It writes `closed: {actor, reason, ts}` with `actor` derived from the credential, or
  `backend:<policy-id>` for a policy close (A4); appends one `dispatch_history` row; changes no attempt; and
  returns the record with `created: true`.
- **Refused; `closed` and every attempt stay unchanged:**
  - `fence_reject(cas_mismatch)`: `expected_attempt` is no longer the last attempt (a T1 committed first).
  - `fence_reject(dispatch_not_terminal)`: the last attempt is `dispatched`, `running` or `unknown`. An `unknown`
    attempt is resolved through T7d first. (A2)
  - `fence_reject(bad_credential)`: the credential is missing or wrong, or names no declared policy. The refusal
    is recorded as a `close_refused` row in `dispatch_history`. (A4)
- **Repeated close:** when a close record exists, any later close returns the stored record unchanged with
  `created: false` and appends nothing. The first close wins. (A6)
- **A `closure: never` backend** answers every close with the typed refusal `closure_not_supported`. It never
  accepts a close silently and never answers with a no-op success. (A3)
- **Closure fences T1 only.** Every attempt-level write that was legal before the close stays legal after it,
  with the same rules: T5 (a late `lost → done` with evidence, including one that derives `paused`), T8, and
  `done_conflict`. They change the attempt, never `closed`. Finishedness is always computed from the attempts. (A2)

**A backend may stop an attempt** (worker deadline, revocation, operator request). The stop is an action, not a state:
the confirmed end follows T3 when the agent child's exit is confirmed (its real exit status is known), whether the
hand-back is valid, malformed or absent (rule 1 gives `handback-malformed` for the last two), or T4 when there is no
confirmed exit evidence at all (the supervisor died with the child, the exit status was never captured). The rule is
the same with or without a stop: **a missing or malformed hand-back from a confirmed exit is
`done{handback-malformed}`; `lost` means no confirmed end of the child.** The `history` entry carries `cause ∈
{deadline_stop, revoked, operator_stop}`. T6 itself stops nothing. [ring20 v0.2 review §9] [ring20 v0.3 check N5]

**A `lost` attempt seen alive again** (sweep observes a live registration for its binding): **no transition.**
`lost → running` stays forbidden. The hub logs the observation and raises an operator notice, as for `done_conflict`;
late evidence can still upgrade the attempt through T5. [AEF v0.2 answers §1.4]

**Forbidden (all rejected):** `done → lost`, `done → running`, `lost → running`, `lost → unknown`, any write that
changes `outcome`/`result` of a `done` attempt (a `done` with a *different* `evidence_digest` is rejected with
`done_conflict`, logged, and surfaced to the operator — it is evidence of a bug or forgery, not a race).

**`outcome` derivation (T3/T3b/T5/T7b/T7d), evaluated in order** [claude Q1, codex Q1, §6.2.7]:
1. for a worker that ran: hand-back missing/unparseable/`commission`≠ (the dispatch id; for an external backend
   equal modulo the `<backend>:` prefix), `attempt`≠, `nonce`≠, or hash cannot be bound → `handback-malformed`
   [ring20 v0.3 check N4];
2. run.sh or supervisor refusal path (e.g. `exit 3`) → `refused`, even with the hand-back absent: a refused worker
   never ran, so rule 1 does not apply to it [v0.3.4];
3. `exit_code != 0` or hand-back `status: failed` → `failed`;
3b. hand-back `status: paused` with `exit_code == 0` → `paused`;
4. otherwise → `succeeded`.

`withdrawn` is never derived by these rules: only T3w writes it, and T3w applies none of them (v0.3.4).

`paused` is a terminal `done` for that attempt, **never a success**: a review verdict or pass-rate consumer must not
count it as finished work. The dispatch continues through attempt N+1 or a re-dispatch naming it in
`retry_of_dispatch_id` (§5.6, §8.4). [termlink v0.1 review §3.1] [AEF v0.2 answers §4]

**`fence_reject`.** Not a state. A response (and an appended `history` entry on the *current* attempt, outside the
lifecycle; for `dispatch_closed` and a refused close, a `dispatch_history` row instead, v0.3.4) returned for any write where: the write is a running-path write (T2, T-RECLAIM, a `questions` append or
an answer ack) naming an attempt that is not the current attempt; the nonce does not match; the credential is
missing or wrong; the `supervisor_gen` is stale; or the expected prior state does not match. It carries `reason ∈
{stale_attempt, bad_nonce, bad_credential, stale_gen, cas_mismatch, forbidden_transition, done_conflict,
dispatch_closed, dispatch_not_terminal}`. `dispatch_closed` (v0.3.4) is the answer to a T1 on a dispatch the backend
has closed (§4.7). It is returned **only** when a readable close record exists, and it is returned **with** that
record; a backend that cannot read the record answers as for an open dispatch, by the CAS. A `closure: never`
backend never returns it. Unlike `cas_mismatch` it is final: no later state of the dispatch admits a T1.
`dispatch_not_terminal` (v0.3.4) refuses a close while the last attempt is not `done` or `lost` (close, above).
A client treats any reason not on this list as a non-retryable typed refusal (§2 client rule), so a later revision
may add a reason without a version bump. [termlink e9015b84]
**The fence is per attempt, not per dispatch** [ring20 v0.2 review §4]: a write is checked against *its own
attempt's* nonce and state. Therefore (a) a completion (T3/T3b) naming an attempt that is `lost` or `unknown` is
processed as T5/T7b, and the CAS check applies to the transition actually taken, not to `running`; (b) T5, T7b and T8 on
a non-current attempt, carrying that attempt's own nonce and proof, are **not** `stale_attempt`. A rejected write changes nothing. The
rejected attempt's *effects in the world* (commits already in the repo) are not undone; their disposition is the
dispatcher's decision and is recorded by naming `(attempt, result)` in any review verdict. [opencode Q1, claude 1c]

**Precedence rule, stated once.** Fenced completion evidence outranks `lost`. A `lost` row is therefore *provisional*
until the retention window closes (§7). Consumers (`worker wait`) must treat `lost` as "not done *yet*" only for
the grace window `G` after T4; after `G` they return `lost` but remain upgradable. [§6.2.1, codex Q1]

### 3.4 State sweep (how T4, T6, T6b, T7a, T7c are produced)

*Sources: [termlink v0.1 review §1.1, §1.3, §2] [AEF v0.2 answers §1].*

Every sweep interval (TermLink: 30 s) the hub checks each `dispatched` or `running` attempt for a live registration
carrying its `worker_binding`. Registrations and records are both durable, so the sweep survives hub restarts and also
covers clean exits, which emit no event. The `session.exited` event is a hint and is never an input to T4.

This section is the **hub's** evidence (two sweeps, `registry_epoch`). A sweep writer without a hub (§3.2) confirms
the end by an independent probe, such as the unit state (§6.3), and reads the local evidence *before* it writes; the
epoch rows below do not apply to it. [ring20 v0.3 check]

| Observation | Transition |
|---|---|
| Seen alive, then absent on two consecutive sweeps, both at the epoch of the sweep that last saw it alive | reconciliation requested; `lost` (T4) only after `G` with no fenced `done` |
| Absent, but a sweep in between ran at a different `registry_epoch` | not counted toward T4; only the deadlines act (T6/T6b) |
| Never seen, `deadline_dispatched` passed | T6b `unknown` |
| Still alive after `deadline_running` | T6 `unknown` |
| Alive again while `unknown` | T7a |
| `unknown`, then seen alive at the current `registry_epoch`, then absent on two consecutive sweeps at that epoch | reconciliation requested; `lost` (T7c) only after `G` with no fenced `done` [termlink v0.2 agree §1] |
| Alive again while `lost` | no transition; logged + operator notice |

Requirements: the record's hub is the hub the worker registers with (hubs do not federate), and `worker_binding` is
refused for a second live registration. Epoch rule: `registry_epoch` is bumped at every hub start and on any sweep
whose listing was incomplete.

---

## 4. Attempt and nonce allocation; no overlap

*Sources: [§6.2.3] hub-allocated, atomic, no overlap; [claude Q2] TermLink is CAS owner; [opencode Q1] TOCTOU.*

4.1 **Allocation is the backend's, atomically (T1).** A dispatcher asks `allocate(dispatch_id, dispatcher)`; the
backend returns `(attempt, nonce)`. A client never numbers an attempt or mints a nonce. **Hub:** `dispatch.allocate`
returns `{dispatch_id, attempt, nonce, supervisor_token}`; the token is 32 random bytes, returned once and never again,
and stored only as its sha256, like the nonce (§3.2 writer authentication). [termlink v0.3 agree]
**`dispatch_id`:** a caller may choose the id. It must be a well-formed `D-<ulid>` and unused; if taken, the backend
fails with its own error `id_taken` and **never substitutes another id** (a caller holding a different key than the
record is the worst failure in shadow mode). With no id given the backend allocates one. The id is immutable once
accepted. [AEF v0.2 answers §2] For `hub` and `local` the grammar is `D-<ulid>`; an external backend declares its own
in its mapping table (§6.6) and its ids are namespaced `<backend>:<id>`, so they cannot collide with hub or local ids;
`id_taken` applies per backend. [ring20 v0.2 review §7] Two concurrent allocations
for the same dispatch: exactly one succeeds, the other receives `cas_mismatch` (it is not given a second attempt).

4.2 **Nonce checked atomically with the write (I3).** Validation and mutation happen under one lock/transaction.
An echo check separated from the write is a TOCTOU and is non-conforming. [opencode Q1]

4.3 **No overlapping attempts.** Attempt N+1 may be allocated only when attempt N is in `done` or `lost` (an `unknown`
becomes one of the two through T7d first). Rationale: all workers share the main checkout; a stale attempt's commits remain
in the repo, so an overlapping retry makes the result ambiguous. `lost` is allowed as a predecessor because the
hub confirmed the session ended. If attempt N later upgrades `lost → done` (T5) after N+1 started, N's `done` is
recorded (the fence is per attempt, so this is not a `stale_attempt`, §3.3) but N+1 proceeds and N's write never
touches N+1's fields; the dispatcher is notified of the double result. [claude Q1c, codex Q1]
*Timeout alone never authorises a new attempt* (an `unknown` blocks T1 until resolved). [codex Q1]

4.4 **Result binding.** `result` is written only with `done` (I5) and is keyed `(dispatch_id, attempt)`. A review
verdict names `(dispatch_id, attempt, result.value)`. A multi-commit worker records a `commit_range`; a worker with
no commits records `handback_sha256`; neither → `kind: none`. [claude Q1 "several commits or none", §6.2.3]
A writer delivers a change plus the commission marker; whether the worker or its supervisor records the commit is a
backend detail (some harnesses cannot commit inside their sandbox). [ring20 arc-009 evidence 2]

4.5 **Session ↔ attempt binding at spawn.** AEF passes `--worker-binding <dispatch_id>:<attempt>` to the spawn or
register call; the backend persists it in the same step as T1, returns it from discovery, and refuses a second **live**
registration carrying the same binding, so it is unique where a name is not. This is what lets the hub map a session
end to exactly one `(dispatch, attempt)` for T4. The name `tl-<dispatch_id>-a<attempt>` may stay as a readable
convention; the hub never parses it. [claude 1b, §6.4] [termlink v0.1 review §1.2]

4.6 **Dispatcher identity.** `dispatcher.session` is the TermLink PTY session (`claude-master-<PID>`), which persists
across `claude -c`. It is the **routing** identity. `claude_session_id` is audit only. If the parent session
disappears, dispatcher ownership transfers to the named successor recorded by `fw worker adopt <dispatch_id>
--to <session>`; until adopted, questions and bounces surface in the project operator queue. [C5, claude Q3 cond.1,
codex Q3 cond.1]

4.7 **Dispatch closure (optional, v0.3.4, A1-A6).** A backend that declares `closure: supported` (§2) may close a
dispatch once its last attempt is terminal (`done` or `lost`; an `unknown` is resolved through T7d first). Closing
is the fenced close transaction of §3.3: it sets `closed: {actor, reason, ts}` once, appends a `dispatch_history`
row, appends nothing to any attempt's `history` and changes no attempt's `state`, `outcome` or `result`.
- **Fences T1 only.** After it, a T1 is `fence_reject(dispatch_closed)` with the close record. T5, T7b, T8 and
  `done_conflict` on an existing attempt are unaffected (closure is not a fence on late evidence, §3.3
  precedence). (A2)
- **Terminal.** wc/0.3 has no reopen; a close is never undone. (A5)
- **Recovery.** Work on a closed dispatch continues only in a new dispatch with `retry_of_dispatch_id` = the
  closed id. Every backend MUST accept such a dispatch, whichever backend closed the original and whatever its own
  `closure` declaration. The new dispatch resolves the closed one (§8.4). (A5)
- **Ownership.** Closedness is authoritative only on the dispatch's own backend (§6.4: the backend is fixed at
  creation). Another backend neither reads nor enforces it: a write about the dispatch addressed to another backend
  is refused there as `backend_fixed`, as before, and a new dispatch there naming it in `retry_of_dispatch_id` is
  accepted. (A6)
- **A backend that declares `closure: never`** (the hub, AEF's local backend) never closes a dispatch and answers a
  close with the typed refusal `closure_not_supported` (§3.3). For it, CC-15a and CC-19a are the whole of CC-15 and
  CC-19; the closure cases (CC-15b, CC-19b, CC-30 to CC-34, CC-36 to CC-43) are n/a, and CC-35 applies.
[ring20 closure] [termlink 14d0100a] [termlink e9015b84] [ring20 0e5516a8]

---

## 5. Answer path

*Sources: [C2], [§6.2.4], [claude Q4], [codex Q4], [opencode Q4]. Constraints: T-4423 (no worker receiver),
T-4418 (no orphan inbox), retry ladder (rungs outlive workers).*

5.1 **The record is the channel in both directions.** No inbox topic, circuit or receiver is ever created for a
worker. This excludes the orphan-inbox class (T-4418) and leaves T-4423 intact **by construction**. [opencode Q4]

5.2 **Questions (worker → dispatcher).** The worker appends `question{question_id, body}` to its own attempt
(fenced write; allowed field). A sidecar notice to `dispatcher.project_agent` carries **only** `dispatch_id` as a
doorbell — no body, so nothing worth retrying. The dispatcher session (`dispatcher.session`) reads the record.
[claude Q4]

5.3 **Answers (dispatcher → worker).** The dispatcher CAS-appends `answer{cmd_id, question_id, body, deadline}` to
the attempt's `answers`. Field permissions: dispatcher appends answers; worker acks; lifecycle fields are untouched
by both. [codex Q3 cond.2]

5.4 **Consumption and ack.** The worker obtains answers through a **blocking, bounded verb**
(`fw worker ask --wait <dur>` and `fw worker poll`), which marks `received` on read and `applied` when the worker
reports it acted on it — an ack **per `cmd_id`** written as a **read-marker under the same fence**. Stored,
received and applied are separate states. Dedupe by `cmd_id` is built in. [claude Q4, codex Q4, opencode Q3 cond.2]

5.5 **TTL and bounce — never the retry ladder.** An answer's `deadline` ≤ min(attempt remaining life,
`ANSWER_TTL`, default 10 min). On expiry or when the attempt goes terminal with the answer un-acked:
state → `undelivered`/`expired` and it **bounces** to the dispatcher (a circuit that is read) or dead-letters naming
the dispatch id. It is never escalated and never re-posted past the worker's death. [opencode Q4, §6.2.4]
Old-attempt answers are **never** replayed into a replacement attempt automatically. [codex Q4]
"Terminal" includes `done{withdrawn}` (T3w): a withdrawal closes the attempt's open questions and bounces its un-acked
answers exactly as any `done` does (v0.3.4). [termlink ab85e88e]

5.6 **Default: pause-and-redispatch; in-run polling is the fast path.** A `claude -p` worker cannot reliably wait
long mid-turn, and a prompt saying "poll" is not evidence a running agent consumes an answer. Until in-run consumption
is **demonstrated against a real running worker** (conformance case CC-11), the supported path is: the bounded wait
expires, the worker ends with hand-back `status: paused` and exit 0, which derives `outcome: paused` (§3.3), and the
answer rides in attempt N+1's instruction (the T-1809 pause mechanism). [claude Q4, codex Q4/Q5, §6.4]

---

## 6. Local backend semantics

*Sources: [C3], [§6.2.5], [claude Q3 cond.3], [opencode Q3 cond.3], [codex Q3 cond.3].*

6.1 **Same semantics, not just the same shape.** The local backend implements every row of §3 with identical CAS
and fencing; the same conformance suite (§9) runs against both. A file without CAS reintroduces T-3960 finding 1c.

6.2 **Mechanism.** One file per dispatch, `.context/dispatch-records/<dispatch_id>.json`.
Every write: take an exclusive `flock` on `<dispatch_id>.lock` (taken by the writer, not delegated to a util),
read, check nonce + `supervisor_gen` + expected prior state, apply, write to a temp file, `fsync`, `rename`
over the record, `fsync` the directory, release. Crash-atomic **and** concurrency-safe (the T-3042 lesson: atomic
rename alone is not concurrency-safe; the lock is part of the contract). The lock times out (default 10 s) and
the write fails closed (`cas_mismatch`-class refusal), never proceeds unlocked.

6.3 **Local `lost` source.** With no hub there is no confirmed-session-end event. The local backend module (the
"hub" writer for `backend: local`) derives `lost` from a local liveness probe of the supervisor/worker process
(`_runtime_alive`-style: pid + start-time identity, not pid alone) **plus** absence of completion evidence in the
worker dir, evaluated by a sweep and after grace `G`. A service manager's unit state (ring20: the unit confirmed
inactive) is an accepted probe. A probe that cannot decide yields `unknown` (T6), never `lost`.
pi and ollama workers, which never touch the hub, use this backend so the ledger does not fork by worker kind.
[claude Q3, §6.4]

6.4 **Backend is chosen at dispatch creation and never switched mid-flight.** It is recorded in the record and in
`dispatches.jsonl`. A hub outage during a `backend: hub` dispatch does **not** redirect writes to local files: the
supervisor keeps the durable local worker-dir evidence (already written before exit, T-4152), and the reconciler
submits it (T5/T7b) when the hub returns. Switching authority mid-flight would be split-brain and would need an
explicit authority-transfer protocol that is **not** part of v0.2. [codex Q3 cond.3, §6.2.5]

6.5 **Durable local evidence, both backends.** Before any terminal write the supervisor persists
`exit_code`, the hand-back and a signed completion in the worker dir, and stamps the completion with `persisted_at`.
This is the evidence the reconciler reads; it is why T5 is possible, why T5 can be bound to evidence that existed before
the `lost` entry (§3.3), and why `_worker_done()`'s existing finalisation checks must be preserved.
An external backend that authenticates by channel may persist, instead of the `exit_code` file and the signed
completion, **channel-bound evidence per §3.2** in its own store, stamped with `persisted_at`; the S4 bound applies to it
unchanged. [codex Q5, claude Q2] [ring20 v0.2 review §S4] [ring20 v0.3 check N3]
**Honest limit:** when supervisor and worker run as the same uid (AEF local today), a `supervisor_token` on disk is a
speed bump, not a boundary; real separation needs a different uid or a container (TermLink T-3477). [termlink v0.3 agree]

6.5a **Attempt credentials at rest (local backend; AEF T-5328, risk R-NEW-5).** The record keeps only the sha256 of the
attempt nonce and of the `supervisor_token`, as the hub does (§3.2). Record files are written through a temp file
created mode 0600 and lock files are opened mode 0600, so neither is readable beyond the owning uid. A holder of the
plain values (the submitter or supervisor that received them at T1) keeps them in process memory or in a file of mode
0600 owned by its own uid, and never in a log, `dispatches.jsonl`, the agent child's environment or its prompt. Today
no AEF process holds them: `fw termlink dispatch` and `run.sh` do not write these records yet; the wiring that does
inherits this rule. The same-uid limit of 6.5 applies unchanged. Pinned by `tests/unit/test_t5328_credentials_at_rest.py`.

6.5b **Attempt credentials at rest (hub, as TermLink states it).** TermLink hub: stores sha256(nonce) and
sha256(supervisor_token) only; the plain values leave the hub once, in the allocate reply; no hub log records RPC
params (digest only); the holder after allocate is the caller, under the caller's own rule. TermLink pins the
hash-only store with a test (`crates/termlink-bus/src/worker_contract.rs`) and has no client of its own that calls
`dispatch.allocate`. [termlink 4eb7d06d] An external backend states its own holder rule as a row of its §6.6 mapping
(ring20 `poold`: see 6.5c).

6.5c **Attempt credentials at rest (ring20, as ring20 measured it; compliant since ring20 T-2840, 2026-11-22).** The
dispatch store holds sha256(nonce) and sha256(supervisor_token) only. `poold`, the supervisor, keeps the plain nonce and
supervisor_token only in a dedicated secrets file, mode 0600 root, written atomically and pruned when attempts are
compacted away, because it needs them to call start/complete after a restart. Its state ledger carries sha256 only;
earlier rows and every ledger archive were migrated and are 0600. Verified on all 7 pool nodes by key, values never
printed: no plain field left. The values were never in the systemd journal, the published pool feed or any hub topic.
[ring20 af48b39a, b91e4d07, cb06acc3] Before T-2840 the plain values sat in the retained state ledger (root-only, 0644 in
a 0700 directory). Separate and lower risk: ring20's older orch-supervisor commission ledger holds plain nonces, no
tokens, of commissions closed by 2026-10-20 (a nonce alone cannot complete an attempt); ring20 T-2841 hashes them going
forward.

### 6.6 External backends

*Sources: [ring20 v0.2 review §1, §2, §7, §11].*

A supervisor with its own durable store is a backend. Its `backend` value is a registered name other than `hub` and
`local` (ring20: `ring20`). It MUST implement every row of §3 with the §6.1 semantics in its own store, MUST pass §9
through an adapter, and MUST publish a mapping from its states and functions to §3.1/§3.3 (its id grammar, writer
authentication per §3.2, and its parameters per §2 included). It writes no hub or local record. `worker_binding`,
`registry_epoch_seen` and `dispatcher.session` are OPTIONAL for it. Its sweep writer may run in its supervisor under
the conditions of §3.2. §6.4 applies unchanged: the backend is chosen at creation and never switched mid-flight.

**What an external backend may substitute, and must declare** (each choice is a row of its mapping):
- **Fencing:** `supervisor_gen` + the §6.2 per-write lock, **or** an exclusive single-writer lease (§3.2), with its
  holder identity, expiry and takeover rule. With a lease, CC-13 and CC-14 test the lease (see those cases).
  [ring20 v0.3 check N1]
- **Writer authentication:** a supervisor credential or a channel the worker cannot write (§3.2).
- **Completion evidence:** the §6.5 signed completion, **or** channel-bound evidence per §3.2. [ring20 v0.3 check N3]
- **Ids:** its id grammar and `<backend>:` prefix (§4.1); `handback.commission` is compared modulo that prefix.
  [ring20 v0.3 check N4]

**Per-case applicability.** The mapping table lists **every** §9 case with `pass` or `n/a` and a one-line reason.
`n/a` is allowed only when the case's subject is a capability the backend does not offer: the answer channel (§5),
`registry_epoch` (I7), caller-chosen `D-<ulid>` ids (§4.1). `n/a` is never allowed for a case whose subject is a §3
transition row (including a forbidden transition, a `fence_reject` reason and T8); where such a case is phrased in
terms of a capability the backend lacks (CC-08 is phrased as a hub restart but tests T6/T7a), the backend runs it
with its own equivalent (its own restart, its probe) and names the equivalent in the reason. Cases whose subject is
the absent capability itself (CC-11/CC-12 answer channel, CC-17 epochs, CC-18 caller-chosen ids) may be `n/a`. A case missing from the table, or `n/a`
outside these limits, means the backend does not conform. [ring20 v0.3 check N2]

---

## 7. Retention

*Sources: [§6.4] "retention is not optional"; [claude Q1 smaller gaps]; [P] left it open.*

7.1 **Fencing needs history.** Rejecting an old attempt requires knowing it existed. Attempts are therefore never
deleted while the dispatch has any non-terminal attempt, and `unknown` attempts are never garbage-collected.

7.2 **Tombstone.** For every attempt ever allocated the backend retains at minimum `(dispatch_id, attempt,
sha256(nonce), final state, outcome, result, evidence_digest, history)` for **at least** the retention window
below. The nonce itself may be dropped once terminal; its hash is kept so a late stale write is still
recognised as `bad_nonce` rather than "unknown attempt".

7.3 **Window.** `lost` stays upgradable (T5) for `RETENTION_LOST_UPGRADE` (proposal: 30 days) after T4, and only with
evidence persisted before the `lost` entry (§3.3), so the window length does not let a late forgery with a stolen nonce
flip the decision; after the window a reconciler submission is rejected as `forbidden_transition` and routed to the
operator. [ring20 v0.2 review §S4] Full records of terminal
dispatches are retained `RETENTION_RECORD` (proposal: 180 days) then archived, never silently dropped.
*Numbers are [agent] proposals; the principle (retain ≥ the longest time a late write can legitimately arrive) is
sourced.*

7.4 **Answer bodies** follow the attempt's retention. `result.value` hashes identify bytes but do not make them
retrievable or prove success (a hash is a pointer); storage of the hashed artefact is the dispatcher's, recorded by
`result.kind`. [codex Q3 missing conditions]

---

## 8. Migration

*Sources: [C4], [§6.3] (resolution reconciling three positions), [claude Q5 shadow mode], [opencode Q3 cond.4],
[codex Q3 cond.4]. Origin finding: T-3960 1c (`update_outcome_row`, lib/spawn.py:218-272, last-writer-wins by
`dispatch_id` only).*

8.1 **Authority.** The shared record becomes the single **completion authority**. The evaluation ledger
(`dispatch-outcomes.jsonl`) is untouched and stays append-only. `dispatches.jsonl.outcome` becomes a **derived
projection**, then is removed.

8.2 **Phase A — shadow.** `update_outcome_row` keeps deciding. In parallel the supervisor/dispatcher also drive
the record (T1–T3). A comparator writes one line per dispatch to `.context/working/shadow-diff.jsonl` comparing
the record's `{state, outcome, exit_code}` with the legacy row. Nothing reads the record to make a decision.

8.3 **Phase B — switch.** Criterion (proposal, [agent]): ≥ 50 real dispatches across ≥ 7 days, covering at least one
each of `refused`, `failed`, a `lost → done` upgrade, and a retry, with **zero unexplained disagreements** (every
diff is attributed to a known legacy bug). On switch: `update_outcome_row` is rewritten to project from the record;
`fw termlink wait/status` read the record; the `record-outcome` route learning
(termlink.sh:1677-1685) and every `dispatch-outcomes.jsonl` reader that decides anything move to the record.
Consumers enumerated and checked off in the build task. [opencode Q3 cond.4] The checklist includes every writer of
the legacy row outside AEF: ring20's `_aef_terminal` calls `update_outcome_row` directly. It switches to the projection
or stops writing the row, and its projection treats `lost` as provisional and re-derives on T5; mapping `lost` to a
final `error` that can later become `counted` is non-conforming. [ring20 v0.2 review §8]

8.4 **`retry_of_dispatch_id` is preserved.** It stays a **dispatch-level** field (a re-dispatch after a pause
*resolves* the paused dispatch in the pause queue; T-3960 2a). An `attempt` is a retry *within* a dispatch. An attempt
ending `outcome: paused` is continued by attempt N+1 or by a re-dispatch naming it in `retry_of_dispatch_id`.
Conflating the two would silently deflate the pause queue. [claude Q3, opencode Q3] Closing a dispatch (§4.7) is
neither: a closed dispatch whose last attempt is `paused` is **never counted as resolved work**. It stays in the pause
queue until a re-dispatch names it, and consumers refuse its `paused` attempt as not finished work, as before. [v0.3.4]
Closure is terminal in wc/0.3 (no reopen), so a re-dispatch naming the closed id in `retry_of_dispatch_id` is the
only recovery, and every backend MUST accept it (§4.7, CC-39). Whether the closed dispatch was finished is read from
its attempts, never from `closed` (§2 reader fields). [v0.3.4, A5] [termlink e9015b84] A backend that also writes a
per-attempt row in the AEF dispatch ledger (ring20: `parent_dispatch_id` = the commission id) may keep doing so after
Phase B or stop; either is conforming. Such a row is a dispatch in the ledger, linked by `attempt_dispatch_ref`, not a
contract attempt. [ring20 v0.2 review §7]

8.5 **ring20.** ring20 does not become a third free implementation: it is an external backend (§6.6) that conforms by
running the §9 vectors against its own store, and maps its T-2281 deliverables against this contract **before** T-2281
is declared absorbed. [claude Q2, codex Q2, C6] [ring20 v0.2 review §1]

8.6 **Back-out.** During Phase A, disabling the record write leaves legacy behaviour unchanged. After Phase B,
back-out is re-enabling the legacy writer as primary; the record continues as shadow.

---

## 9. Conformance cases

*Sources: the seven cases named by [codex Q5] and [task T-4439], plus those implied by [§6.2], [claude Q1], [opencode Q1].*

Every case runs against **both** backends (`hub` and `local`) and against any external backend (§6.6) claiming
conformance. Notation: `A1` = attempt 1. Time is injected, not slept. A case passes only if the final record matches
exactly **and** the `history` equals one of the *admissible histories* the case lists (a case that lists none has
exactly one). An implementation that reaches the same final record by a listed shorter path passes.
[ring20 v0.2 review §12] An external backend reports each case `pass` or `n/a` with a reason in its mapping, under the
limits of §6.6: `n/a` only for a capability it does not offer, never for a §3 transition row. [ring20 v0.3 check N2]

### CC-01 Completion racing session end
- **Given** A1 `running`; run.sh has written local `exit_code=0` + hand-back and is about to submit T3.
- **When** the session end is confirmed and the hub processes T4 *before* T3 arrives.
- **Then** after grace `G` the state is `lost`; the later fenced T3 (or the reconciler's T5) upgrades it to
  `done{succeeded}`; no write is lost or reordered into `lost` over `done`. **Admissible histories:**
  `running→lost→done`, or `running→done` when the evidence is readable at the first evaluation (§3.3 T3, reconciler).

### CC-02 Same race, opposite order
- **Given** as CC-01.
- **When** T3 lands first, then the hub receives the session-end event.
- **Then** the state is `done`; the T4 attempt is rejected `forbidden_transition` (`done → lost`); final state `done`.

### CC-03 Supervisor crash before commit
- **Given** A1 `running`; supervisor dies after the agent child exits but before any T3 write.
- **When** the session end is confirmed (T4) and the reconciler later finds `exit_code` + hand-back in the worker dir.
- **Then** `done{outcome}` with **admissible histories** `running→lost→done` (T4 then T5) or `running→done` (a
  recovering supervisor, or the reconciler, reads the evidence before `lost` is written, T3); if no evidence exists the
  record stays `lost`. [ring20 v0.2 review §12]

### CC-04 Supervisor crash after commit
- **Given** T3 committed (`done{succeeded}`), supervisor dies before reporting back to its caller.
- **When** a restarted supervisor/reconciler re-submits the same evidence.
- **Then** T8 returns the stored record unchanged; history length is unchanged; no second `done`.

### CC-05 Duplicate finalisation
- **Given** A1 `done` with `evidence_digest = X`.
- **When** (a) the same evidence X is submitted again; (b) different evidence Y is submitted.
- **Then** (a) idempotent success, no history entry; (b) rejected `done_conflict`, record unchanged, operator
  notified.

### CC-06 Retry while the old worker survives
- **Given** A1 `running`, session still alive.
- **When** a dispatcher requests attempt 2.
- **Then** T1 is refused (`cas_mismatch`, "attempt 1 not terminal"); no A2 exists. After A1 is `lost`, T1 yields
  A2 with a fresh nonce; a late **running-path write** from A1 (a T-RECLAIM or a `questions` append carrying the A1
  nonce) is `fence_reject(stale_attempt)` and does not alter A2. A late *completion* from A1 is not this case: it is
  the T5 upgrade of A1 (CC-07). [ring20 v0.2 review §4]

### CC-07 Stale-attempt write rejected
- **Given** A1 `lost`, A2 `running` (nonce n2).
- **When** a zombie A1 supervisor submits T3 with nonce n1 as a *new completion of A2*, then with nonce n1 for A1.
- **Then** the first is `fence_reject(bad_nonce)`; the second is accepted only as the T5 upgrade of A1 (if its
  evidence is valid and persisted before A1's `lost` entry) and never touches A2's fields; it is not
  `stale_attempt` because the fence is per attempt (§3.3). [ring20 v0.2 review §4]

### CC-08 Hub restart
- **Given** A1 `running`; registrations and records are durable on disk.
- **When** the hub restarts (`registry_epoch` is bumped). After the restart the sweep either finds the session
  alive, or finds it absent.
- **Then** alive: A1 stays `running` (no transition). Absent: the absence does not count toward T4 across the epoch
  change; two further absent sweeps at the new epoch, then `G`, give `lost`. If neither can be confirmed before
  `deadline_running` (worker on another hub, partition, reused pid): `running → unknown` (T6), one operator notice,
  `worker wait` returns `unknown` after the bound, never hangs. Later confirmed alive: `unknown → running` (T7a).
  [termlink v0.1 review §1.3]

### CC-09 Partition
- **Given** A1 `running` on a worker host partitioned from the hub; the worker finishes and writes local evidence.
- **When** the partition heals and the reconciler submits.
- **Then** if state was `unknown`: `unknown → done` (T7b); if `lost`: `lost → done` (T5). A write made *during*
  the partition on any other path (e.g. to a different backend) is refused by §6.4 — no split brain.

### CC-10 Parent-session loss
- **Given** A1 `running`; `dispatcher.session` disappears.
- **When** the worker appends a question and later finishes.
- **Then** the question surfaces in the project operator queue (not an orphan inbox); the lifecycle is unaffected
  (`done` by the supervisor); `fw worker adopt` re-points the dispatcher and the answer path resumes. No topic is
  created for the worker at any point.

### CC-11 Answer delivered and acked
- **Given** A1 `running`, a real running worker blocked in `fw worker ask --wait 10m`.
- **When** the dispatcher appends `answer{cmd_id=c1}`.
- **Then** the worker's blocking call returns it; `state` goes `stored → received → applied` via per-`cmd_id`
  read-markers under the fence; a second read does not re-deliver c1. **This case must run against a real
  `claude -p` worker, not a mock, before in-run polling may be declared supported.** [codex Q4/Q5]

### CC-12 Answer TTL expiry bounces
- **Given** A1 `running`, answer `c2` with deadline now+10 min, worker never acks.
- **When** the deadline passes, and separately when A1 goes terminal with `c2` un-acked.
- **Then** `c2` → `expired`/`undelivered`, surfaced to `dispatcher.session`; **no** retry-ladder entry exists for it;
  it is not replayed into A2.

### CC-13 Local backend parity
- **Given** the full suite CC-01..CC-12 plus the concurrency case: 8 concurrent writers racing T3 on one
  attempt.
- **When** run on `backend: local` (flock+CAS) and on `backend: hub`.
- **Then** both produce identical final records and identical `history` (modulo timestamps); exactly one writer
  wins, the others receive `cas_mismatch` or idempotent T8; the lock-timeout path fails closed.
- **External backend fencing by lease** (§3.2, §6.6): the 8 writers race for the lease instead of the lock; exactly
  one holds it and writes T3, a writer that never acquired it is `fence_reject(stale_gen)` or waits and then receives
  `cas_mismatch`/T8; a lease that cannot be acquired within the backend's declared bound fails closed, never writes
  unleased. [ring20 v0.3 check N1]

### CC-14 Stale supervisor generation
- **Given** A1 `running`, `supervisor_gen=1`; supervisor restarts and claims T-RECLAIM → `supervisor_gen=2`.
- **When** the old supervisor (gen 1) submits T3.
- **Then** `fence_reject(stale_gen)`; the gen-2 supervisor's T3 is accepted.
- **External backend fencing by lease:** supervisor S1 holds the lease; S2 takes it over (T-RECLAIM as lease
  takeover); S1, no longer holding it, submits T3 → `fence_reject(stale_gen)`, record unchanged; S2's T3 is accepted.
  [ring20 v0.3 check N1]

### CC-15 Unknown resolution by operator
- **Given** A1 `unknown`, no evidence, no confirmation.
- **When** `fw worker resolve D A1 --as lost --reason "host reimaged"` is run on the hub host.
- **Then** `unknown → lost` (T7d), logged with actor and reason; only then may T1 allocate A2. The allocate after
  the resolve is split by whether a close record exists (v0.3.4, A3): with no close record, T1 MUST succeed
  (CC-15a); on a closure-supported backend that has closed the dispatch, T1 is `fence_reject(dispatch_closed)`
  with the record and no A2 exists (CC-15b). A backend that refuses T1 with no readable close record fails. The same call from an
  agent session via a remote RPC is not available (no signed operator identity); from an agent session on the hub host
  it is refused without an explicit recorded override (speed bump); every resolve posts the operator notice. [ring20 v0.2 review §S2]

### CC-15a Resolved, no close record: next attempt allocated (v0.3.4)
- **Given** A1 `unknown`; the operator resolves it `--as lost` (T7d) as in CC-15; no close record (any backend; on
  a closure-supported backend nobody has closed D).
- **When** the dispatcher allocates.
- **Then** T1 is accepted and A2 is `dispatched` with a fresh nonce; A1 stays `lost`. A `fence_reject` of any
  reason fails the case. [termlink e9015b84]

### CC-15b Resolved, closed: allocate refused with the record (v0.3.4)
- **Given** a closure-supported backend; A1 `unknown`, resolved `--as lost` (T7d); then D closed under the
  backend's declared policy, reason `r`.
- **When** the dispatcher allocates.
- **Then** `fence_reject(dispatch_closed)` returned with the close record (`actor: backend:<policy-id>`,
  `reason: r`, `ts`); no A2; A1 unchanged; one `dispatch_closed` row in `dispatch_history`. [termlink e9015b84]

### CC-16 Outcome derivation
- **Given** five fixtures (plus the paused fixture below): clean exit + valid hand-back; exit 1; run.sh `exit 3`; valid exit but hand-back with
  wrong nonce; valid exit, hand-back absent.
- **When** each is finalised through T3.
- **Then** outcomes are respectively `succeeded`, `failed`, `refused`, `handback-malformed`, `handback-malformed`;
  a sixth fixture, valid exit 0 with hand-back `status: paused`, gives `paused`;
  `done` in every case; `exit_code` stored as the child's real code even though run.sh itself exits 0.

### CC-17 Absence across a registry epoch
- **Given** A1 `running`, last seen alive at epoch E1.
- **When** the hub restarts (epoch E2) and the next two sweeps find A1 absent; separately, when both absent sweeps
  are at E1.
- **Then** at E2 the absences do not count toward T4 and only the deadlines act; at E1 the second absent sweep
  requests reconciliation and `lost` is written only after `G` with no fenced `done`. A fenced T3 inside `G` wins.

### CC-18 Caller-chosen dispatch id
- **Given** `D-X` is unused, then used.
- **When** a caller allocates with id `D-X` twice, with a malformed id, and with no id.
- **Then** first call accepted with `D-X`; second fails `id_taken` and no other id is substituted; malformed is
  refused; no id yields a backend-allocated id.

### CC-19 Paused is terminal, not success
- **Given** A1 `running`, hand-back `status: paused`, exit 0.
- **When** T3 finalises it.
- **Then** `done{paused}`; a review verdict naming `(D, A1, result)` is refused as not finished work; A2 may be
  allocated (T1) or a re-dispatch naming `retry_of_dispatch_id = D`. The allocate is split by whether a close
  record exists (v0.3.4, A3): with no close record, T1 MUST succeed (CC-19a); on a closure-supported backend that
  has closed the dispatch, T1 is `fence_reject(dispatch_closed)` with the record and no A2 exists (CC-19b). The
  re-dispatch is accepted either way, and a closed paused dispatch is not counted as resolved or finished work
  (§8.4).

### CC-19a Paused, no close record: next attempt allocated (v0.3.4)
- **Given** A1 `done{paused}` (as CC-19); no close record (any backend; on a closure-supported backend nobody has
  closed D).
- **When** the dispatcher allocates.
- **Then** T1 is accepted and A2 is `dispatched` with a fresh nonce; A1 unchanged. A `fence_reject` of any reason
  fails the case. [termlink e9015b84]

### CC-19b Paused, closed: allocate refused with the record (v0.3.4)
- **Given** a closure-supported backend; A1 `done{paused}`; D closed by A1's supervisor credential, reason `r`.
- **When** the dispatcher allocates; then a reader reads D.
- **Then** `fence_reject(dispatch_closed)` returned with the close record (`actor`, `reason: r`, `ts`); no A2;
  one `dispatch_closed` row in `dispatch_history`. The reader shows `closed` set, `finished: false`, last state
  `done`, outcome `paused`. A re-dispatch naming `retry_of_dispatch_id = D` is accepted. [termlink e9015b84]

### CC-20 Lost attempt seen alive
- **Given** A1 `lost`.
- **When** the sweep observes a live registration for A1's binding.
- **Then** no transition (`lost → running` rejected `forbidden_transition`), observation logged, one operator
  notice; later valid evidence still upgrades A1 via T5.

### CC-21 Dispatched never seen
- **Given** A1 `dispatched`, the worker never registers.
- **When** `deadline_dispatched` passes.
- **Then** `dispatched → unknown` (T6b), one operator notice; a supervisor T3b from a worker that refused before
  T2 instead ends `done{refused}` with no `unknown`.

---

### CC-22 Attested done is not finished work
- **Given** A1 `unknown`, no evidence.
- **When** an operator runs `fw worker resolve D A1 --as done --reason "…"` with no evidence.
- **Then** `unknown → done` (T7d) with `attested: true`, `attested_by` set, `result.kind: none`, no `evidence_digest`;
  the operator notice is posted; a review verdict or pass-rate consumer naming `(D, A1, result)` is refused as not
  finished work, as in CC-19. [ring20 v0.2 review §S3]
- **And** the same call with operator-supplied material that is not bound evidence (a pasted log, a bare hash) is
  still an attestation (`attested: true`); the same call with a signed completion (or channel-bound evidence per §3.2)
  for `(D, A1, nonce)` gives an evidenced `done` whose `outcome` is derived by rule, with `attested: false`.
  [ring20 v0.3 check N6]

### CC-23 The nonce alone cannot complete
- **Given** A1 `running`, nonce n1, supervisor credential c1 (or a channel the worker cannot write).
- **When** a writer presents n1 with no credential or channel proof and asks for T3 `done{succeeded}`; separately the
  same writer appends a `questions` entry with n1.
- **Then** the T3 is `fence_reject(bad_credential)` and A1 stays `running`; the `questions` append is accepted (a
  worker-permitted field). A T3 with n1 and c1 is accepted. [ring20 v0.2 review §3, §S1]

### CC-24 Late T5 whose evidence postdates the lost entry
- **Given** A1 `lost` with its `lost` history entry at time t; within the retention window.
- **When** a reconciler submits (a) valid signed evidence with `persisted_at` ≤ t, and separately (b) otherwise valid
  evidence with `persisted_at` > t.
- **Then** (a) upgrades `lost → done` (T5); (b) is `forbidden_transition`, logged, one operator notice, record
  unchanged. [ring20 v0.2 review §S4]

### CC-25 Backend-initiated stop
- **Given** A1 `running`, an external backend whose worker passes its deadline.
- **When** the backend stops the worker, then (a) the child's exit is confirmed and a valid hand-back is readable,
  (b) the child's exit is confirmed and the hand-back is absent or malformed, or (c) there is no confirmed exit
  evidence (no exit status was captured).
- **Then** (a) `done{outcome}` through T3; (b) `done{handback-malformed}` through T3, as in CC-16 and rule 1, never
  `lost`; (c) `lost` through the backend's sweep writer once the end is confirmed by its probe. In every case the
  `history` entry carries `cause: deadline_stop`; no new attempt is allocated by the stop. Revocation
  (`cause: revoked`) behaves the same. [ring20 v0.2 review §9] [ring20 v0.3 check N5]

### CC-26 Withdraw from dispatched (v0.3.4)
- **Given** A1 `dispatched`, nonce n1, supervisor credential c1, `supervisor_gen` g1; one un-acked dispatcher answer
  that names no `question_id` (deadline clock + `ANSWER_TTL`, or none). No question: no worker exists before T2 (§3.3),
  so nobody can ask while A1 is `dispatched`.
- **When** the submitter presents n1, c1 and g1 and withdraws A1 with actor `a` and reason `r`.
- **Then** `dispatched → done{withdrawn}` (T3w); `evidence_digest = sha256(r)`, `result.kind: none`, `exit_code` null;
  the `history` entry carries actor `a` and reason `r`; no operator notice; the answer bounces (§5.5). The same request without c1 is `fence_reject(bad_credential)` and A1 stays `dispatched`; a request
  from the sweep writer is refused, A1 unchanged. A consumer counting finished work, success or failure refuses
  `(D, A1)`. A later T1 may allocate A2. [ring20 T-2790 3d5e1fda] [termlink ab85e88e]

### CC-27 Withdraw races the start (v0.3.4)
- **Given** A1 `dispatched`; the supervisor is about to write T2, the submitter is about to withdraw.
- **When** both writes arrive.
- **Then** exactly one is accepted and the other is `fence_reject(cas_mismatch)`. **Admissible histories:**
  `dispatched→done` (T3w wins; the supervisor's T2 is refused and it launches nothing) or `dispatched→running` (T2
  wins; the withdrawal is refused and the worker runs). A supervisor that launched the agent child before its T2 was
  accepted fails this case. [termlink ab85e88e]

### CC-28 Withdraw from running (v0.3.4)
- **Given** A1 `running`.
- **When** the submitter withdraws A1 with valid credentials.
- **Then** `fence_reject(cas_mismatch)`; A1 stays `running`, record unchanged. Likewise A1 `lost` or `unknown`:
  `fence_reject(forbidden_transition)`, record unchanged. [termlink ab85e88e]

### CC-29 Repeated withdrawal (v0.3.4)
- **Given** A1 `done{withdrawn}` with `evidence_digest = sha256(r)`.
- **When** (a) the same withdrawal (reason `r`) is submitted again; (b) a withdrawal with reason `r2 ≠ r`; (c) a
  supervisor T3b with a hand-back.
- **Then** (a) T8: the stored record is returned, no history entry; (b) `fence_reject(forbidden_transition)`, record
  unchanged; (c) `done_conflict`, logged, operator notice, record unchanged. [termlink ab85e88e]

Cases CC-30 to CC-43 (v0.3.4, changelog item 2, A1-A6) run on a backend that declares `closure: supported`; on a
`closure: never` backend they are n/a, except CC-35 (which applies only to it) and CC-39's `foreign-closed` branch
(which applies to every backend). Groups as TermLink named them [termlink e9015b84]: CC-30 to CC-32 close against
T1; CC-33 and CC-34 attempt writes after close; CC-35 capability; CC-36 and CC-37 credentials; CC-38 to CC-40
terminality and recovery; CC-41 to CC-43 idempotency, history and ownership.

### CC-30 Close wins the race with T1 (v0.3.4)
- **Given** a closure-supported backend; A1 `lost`; a closer holds A1's supervisor credential c1.
- **When** the close `close(D, expected_attempt: 1, reason r)` commits, then a T1 arrives.
- **Then** the close is accepted (`created: true`, `actor` derived from c1); the T1 is
  `fence_reject(dispatch_closed)` with the record; no A2. [termlink c2d29013 W1]

### CC-31 T1 wins the race, so close is refused (v0.3.4)
- **Given** as CC-30.
- **When** a T1 commits first (A2 `dispatched`), then the close naming `expected_attempt: 1` arrives.
- **Then** the close is `fence_reject(cas_mismatch)`; `closed` stays null; A2 is unchanged and stays the current
  attempt. A backend that closes D with A2 live fails the case. [termlink c2d29013 W1]

### CC-32 Close refused while the last attempt is not terminal (v0.3.4)
- **Given** a closure-supported backend; A1 in turn `dispatched`, `running`, `unknown`.
- **When** a close naming A1 with c1 is made in each state.
- **Then** each is `fence_reject(dispatch_not_terminal)`; `closed` stays null; A1 unchanged; a later T1 (once A1
  is terminal) is decided by the CAS alone. [termlink e9015b84 A1, A2]

### CC-33 Late completion after close is accepted (v0.3.4)
- **Given** a closure-supported backend; A1 `lost` (its `lost` entry at time t); D closed; signed evidence E1 for A1
  with `persisted_at` ≤ t.
- **When** a reconciler submits E1.
- **Then** `lost → done{succeeded}` (T5), as on an open dispatch; `closed` unchanged; the reader shows `closed`
  set and `finished: true`, computed from A1. A backend that refuses the completion because D is closed fails.
  [termlink c2d29013 W2] [ring20 0e5516a8]

### CC-34 Other attempt writes after close stay legal (v0.3.4)
- **Given** a closure-supported backend; D closed; (a) A1 `lost` with evidence whose hand-back says `paused`;
  (b) A1 `done{succeeded}` with `evidence_digest = X`.
- **When** (a) the reconciler submits the paused evidence; (b) the same evidence X is submitted again, then
  different evidence Y.
- **Then** (a) `lost → done{paused}` (T5), `finished: false`; (b) T8 returns the stored record, then
  `done_conflict`, logged, operator notice. `closed` is unchanged in every branch; no `dispatch_closed` answer.
  [termlink e9015b84 A2]

### CC-35 A closure: never backend refuses close; clients tolerate unknown reasons (v0.3.4)
- **Given** a backend that declares `closure: never`; A1 `done{succeeded}`.
- **When** (a) a close naming A1 with c1 is made; (b) a client receives a `fence_reject` whose reason is not on
  the §3.3 list.
- **Then** (a) the typed refusal `closure_not_supported`; `closed` stays null; nothing is appended; a later T1
  is accepted. A silent no-op or a success fails the case. (b) The client stops retrying that write and reports a
  non-retryable typed refusal naming the reason; it does not error out and does not retry. [termlink e9015b84 A3]

### CC-36 Close by an authorised credential (v0.3.4)
- **Given** a closure-supported backend; A1 `done{succeeded}`; A1's supervisor credential c1; a declared backend
  policy `p`.
- **When** (a) a close presents c1 with caller-supplied text `actor: someone-else`; (b) separately, the backend
  closes under policy `p`.
- **Then** (a) accepted; `actor` is the identity derived from c1, not the caller text; (b) accepted; `actor` is
  `backend:p`. Each appends one `close` row. [termlink c2d29013 W4] [ring20 0e5516a8]

### CC-37 Close with a wrong credential is refused and recorded (v0.3.4)
- **Given** as CC-36.
- **When** a close presents no credential, then a credential that is not c1 (for instance an earlier attempt's),
  then names an undeclared policy.
- **Then** each is `fence_reject(bad_credential)`; `closed` stays null; each appends one `close_refused` row to
  `dispatch_history` with the reason. A later close with c1 is accepted. [termlink e9015b84 A4]

### CC-38 No reopen (v0.3.4)
- **Given** a closure-supported backend; D closed.
- **When** a write tries to clear or replace `closed` (a reopen, or a close carrying another actor or reason).
- **Then** no reopen exists: `closed` keeps the first record; a later close returns it with `created: false`
  (CC-41); a T1 is still `fence_reject(dispatch_closed)`. [termlink c2d29013 W5]

### CC-39 Recovery by a new dispatch naming the closed one (v0.3.4)
- **Given** (`own-closed`) a closure-supported backend with D closed, A1 `done{paused}`; (`foreign-closed`) any
  backend, and a dispatch id closed on another backend.
- **When** the dispatcher creates a new dispatch with `retry_of_dispatch_id` = that id.
- **Then** accepted (T1); the new dispatch carries the link verbatim; D stays closed and unchanged. A backend that
  refuses the link because the named dispatch is closed, or is not its own, fails. [termlink e9015b84 A5]

### CC-40 Reader keeps closed, finished and last state apart (v0.3.4)
- **Given** a closure-supported backend; D closed with A1 `done{paused}`.
- **When** a reader reads D, and a consumer counting finished work names `(D, A1)`.
- **Then** the reader exposes `closed` set, `finished: false`, last attempt state `done` and outcome `paused` as
  separate fields; the consumer refuses `(D, A1)` as not finished work. Closed is never read as finished.
  [termlink c2d29013 W5]

### CC-41 Repeated close returns the stored record (v0.3.4)
- **Given** a closure-supported backend; A1 `lost`; c1.
- **When** a close with reason `r` is made, then again with reason `r`, then with reason `r2`.
- **Then** the first is accepted with `created: true`; the second and third return the first record unchanged
  (`reason: r`) with `created: false` and append nothing. [termlink e9015b84 A6]

### CC-42 Every close and every dispatch_closed refusal is a history row (v0.3.4)
- **Given** a closure-supported backend; A1 `lost`; c1.
- **When** D is closed, then two T1s are made.
- **Then** `dispatch_history` holds exactly three rows in order: `close`, `dispatch_closed`, `dispatch_closed`.
  No attempt's `history` changes. [termlink c2d29013 W6]

### CC-43 Closedness is authoritative only on the dispatch's own backend (v0.3.4)
- **Given** a closure-supported backend X; D created on X and closed there.
- **When** a T1 for D is addressed to another backend Y; then a new dispatch is created on Y naming
  `retry_of_dispatch_id = D`.
- **Then** the T1 at Y is refused `backend_fixed` (§6.4), not `dispatch_closed`, and creates nothing; the
  dispatch at Y is accepted; on X, D stays closed and unchanged. [termlink c2d29013 W6]

---

## Open questions

Closed in v0.2: **1** (`paused` is a fifth outcome, §3.3) [termlink v0.1 review §3.1] [AEF v0.2 answers §4];
**5** (binding is an explicit `--worker-binding` field; the name is a convention, §4.5) [termlink v0.1 review §1.2].
**2** is partly closed: `G` = 120 s (at least 4 × sweep interval), `ANSWER_TTL` = 10 min, retention 30/180 days and the
shadow switch criterion are agreed by TermLink; `deadline_running` = worker timeout + 10 min. [termlink v0.1 review §2]
Still open:

2. **Per-backend agreement of the numbers.** `G`, `deadline_running`, `ANSWER_TTL` and retention are agreed with
   TermLink (hub backend). They are per-backend parameters under the §2 invariant. ring20 states `G = 0` (evidence read
   before `lost`) and `deadline_running` = `timeout_sec` + 60 s [ring20 v0.2 review §11]; the local backend and ring20's
   `ANSWER_TTL` and retention still need confirming.
6. ~~**Supervisor credential carrier for the hub** (§3.2)~~ **Closed in v0.3.3:** `dispatch.allocate` returns a
   `supervisor_token`, stored hashed (§3.2, §4.1). [termlink v0.3 agree] **Still open for non-hub backends:** how a
   reconciler that replaces a dead supervisor holds the credential "the worker never sees" (local backend; external
   backends declare it in their §6.6 mapping). [ring20 v0.2 review §3]
3. ~~**Who runs the reconciler on a hub host that has no AEF** (ring20 workers)?~~ **Closed in v0.2.1:** ring20 has no
   reconciler of its own; its supervisor submits late evidence through T5 (ring20 msg b193272e, relayed by TermLink).
   [termlink v0.2 agree §3]
4. **Authority transfer on prolonged hub outage** is out of scope (§6.4); if the operator wants local
   fallback *during* a hub outage it needs its own protocol.
5. **Signed operator identity** for T7d: until it exists resolve is a hub-host CLI; the identity mechanism is not
   specified. [AEF v0.2 answers §3]
7. **Operator withdrawal** (v0.3.4): T3w is open only to the holder of the attempt's credentials. Whether an operator
   may withdraw an attempt whose submitter is gone is a separate decision; if wanted, it would be its own operator
   command, like T7d. [termlink ab85e88e]
