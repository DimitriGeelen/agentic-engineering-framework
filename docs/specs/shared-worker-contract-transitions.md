# Shared dispatched-worker contract — transition table and conformance spec

**Status:** DRAFT v0.3 for agreement by TermLink, ring20 and AEF. TermLink agreed v0.2.1; the six changes marked "TermLink re-agreement" in `docs/reports/T-4439-reviews/ring20-v0.2-answers.md` need their sign-off. ring20: AGREE-WITH-COMMENTS on v0.2, comments folded here. **Task:** T-4439 (slice 1 of T-4435, GO 2026-10-20).
**Contract version field value:** `wc/0.3` (see §2). **Rule:** no implementation starts before this table is agreed.

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
dispatcher:                       # recorded at spawn, immutable [C5, claude Q3 cond.1]
  project_agent: <sidecar agent id>       # per project; routing doorbell only
  session: claude-master-<PID>            # the durable TermLink PTY session; the routing identity
  claude_session_id: <uuid>|null          # AUDIT ONLY: changes on `claude -c` and compaction
created_at: <ts>
attempts:                         # append-only list, index = attempt number starting at 1
  - attempt: 1
    nonce: <random>               # allocated with the attempt, never reused
    state: dispatched|running|done|lost|unknown
    outcome: succeeded|failed|refused|handback-malformed|paused|null   # non-null iff state == done
    worker_kind: claude|ollama|pi|...
    session_binding:              # written at spawn, before the worker runs [claude 1b, §6.4]; hub fields OPTIONAL when backend is neither hub nor local
      worker_binding: D-<ulid>:1           # --worker-binding; unique among live sessions; the T4 key [termlink v0.1 review]
      session_name: tl-D-<ulid>-a1         # readable convention only; the hub never parses it
      registry_epoch_seen: <epoch>         # epoch of the sweep that last saw this attempt alive [AEF v0.2 answers]
    attempt_dispatch_ref: <id>|null  # OPTIONAL: the per-attempt row in the AEF dispatch ledger, if the backend writes one (§8.4); not an attempt
    attested: true|false          # true only for a T7d `done` with no evidence (§3.3)
    attested_by: <actor>|null
    supervisor_gen: 1             # increments on supervisor recovery (§3, T-RECLAIM)
    exit_code: <int>|null         # the agent child's real exit code (run.sh itself exits 0)
    result:                       # bound to THIS attempt [opencode Q1, §6.2.3]
      kind: commit_range|handback_sha256|none
      value: <sha or range or sha256>
      persisted_at: <ts>|null     # when the supervisor persisted the signed completion (§6.5); null for attested done
    handback:                     # schema is contract surface, validated by the backend [opencode Q2]
      commission: <id>            # = dispatch_id
      attempt: <n>                # must equal the attempt it is written under
      nonce: <echo>               # must equal the attempt nonce
      status: complete|blocked|paused|failed   # paused + exit 0 derives outcome paused (§3.3)
      summary: <text>
      findings: [...]
    evidence_digest: <sha256 of the evidence the terminal write cited>
    history:                      # append-only transition log: (from, to, writer, ts, evidence_digest[, cause])
      - {from: null, to: dispatched, writer: hub, ts: ...}   # cause ∈ {deadline_stop, revoked, operator_stop} when a backend stopped the attempt (§3.3)
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
  prior state in the *same atomic step* as the write. A lifecycle write (T2, T3, T3b, T-RECLAIM, T5, T7b, and T8) also
  presents the writer's credential or arrives on a channel the worker cannot write (§3.2), checked in the same step.
  [claude 1c, opencode Q1, codex Q1, §6.2.3] [ring20 v0.2 review §3]
- I4. `done` and `lost` are never both the *final* state: `done` outranks `lost` (§3 precedence).
- I5. `result` is written only together with `done` and is bound to its attempt.
- I6. At most one attempt of a dispatch is non-terminal at any time (§4.3).
- I7. `registry_epoch` is a hub-level value, bumped at every hub start and on any sweep whose registry listing was
  incomplete; each attempt keeps the epoch of the sweep that last saw it alive. [AEF v0.2 answers §1.1]
- I8. Verification, review and landing never change `outcome` or `state`. They are evaluation-layer facts keyed by
  `(dispatch_id, attempt, result.value)`, held outside the record. [ring20 v0.2 review §6]

---

## 3. Transition table

*Sources: [§6.2.1] done/lost precedence and upgrade (all three seats); [§6.2.2] bounded unknown (all three);
[codex Q1] supervisor generation; [claude Q2] reconciler is AEF's; [claude Q1] outcome field; [agent] row numbering.*

### 3.1 States

| State | Meaning | Terminal? |
|---|---|---|
| `dispatched` | Attempt allocated, session binding written, worker not yet confirmed started | no |
| `running` | Supervisor confirmed the agent child started | no |
| `done{outcome}` | Agent child **stopped**, fenced evidence accepted. `outcome` ∈ succeeded, failed, refused, handback-malformed, paused | yes (final; see T5/T8) |
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
| `supervisor` | `run.sh` / ring20 supervisor holding the attempt nonce, the supervisor credential **and** current `supervisor_gen` | T2, T3, T3b, T-RECLAIM, T8 |
| `hub` (the *sweep writer*) | the backend's sweep module: the TermLink hub; for `backend: local`, the local backend module; for an external backend, its own sweep module. T4/T6/T6b/T7a/T7c are written from the state sweep (§3.4) | T1, T4, T6, T6b, T7a, T7c |
| `reconciler` | AEF reader of the worker dir; submits *local evidence*, never a verdict of its own; a supervisor that died is replaced by it for the completion write | T3, T3b, T5, T7b |
| `operator` | human, `fw worker resolve`, a hub-host CLI until a signed operator identity exists | T7d |

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
`bad_credential`. Evidence for T3/T3b/T5/T7b is the signed completion of §6.5, so a reconciler cannot assert more
than the supervisor persisted. Residual: a hostile same-user process can read its supervisor's environment; this
removes the accident and prompt-echo path, not that one. [ring20 v0.2 review §3, §S1]

### 3.3 Transitions

CAS = the write is applied only if the current state equals *expected prior* and the nonce matches; otherwise it is
rejected (never merged). `fence_reject` is defined after the table.

| # | From → To | Writer | Required evidence | CAS expected-prior | Precedence / notes |
|---|---|---|---|---|---|
| T1 | ∅ → `dispatched` | hub | dispatcher identity; prior attempt (if any) is terminal; backend allocates `attempt` and `nonce` atomically | no attempt exists, or last attempt state ∈ {done, lost} (an operator-resolved `unknown` is `lost` or `done` after T7d) | allocation is the only place attempts are minted (§4) |
| T2 | `dispatched` → `running` | supervisor | echo of `nonce`; session binding confirmed; `supervisor_gen` claimed | `dispatched` | sets `deadline_running` |
| T3 | `running` → `done{outcome}` | supervisor, or reconciler when the supervisor is gone | agent child exited; `exit_code` read **after** exit; hand-back parsed and hash computed; `evidence_digest` | `running` | the single normal completion path; `outcome` derived by rule below. A reconciler submits the same fenced local evidence when the supervisor died, for instance inside `G`; so `running → done` is a valid history [ring20 v0.2 review §12] |
| T3b | `dispatched` → `done{outcome}` | supervisor, or reconciler when the supervisor is gone | as T3 (worker died/refused before T2 landed, e.g. run.sh `exit 3`) | `dispatched` | covers fast-fail without a spurious `lost` |
| T-RECLAIM | `running` → `running` | supervisor | restarted supervisor presents nonce + local worker dir + `supervisor_gen = prev + 1` | `running` and `supervisor_gen == prev` | fences a stale supervisor: its later writes carry the old gen and are `fence_reject`ed [codex Q1] |
| T4 | `running`/`dispatched` → `lost` | hub | session end **confirmed from state** (§3.4): the attempt was seen alive, then absent on two consecutive sweeps at the epoch of the sweep that last saw it alive; then reconciliation requested; and no fenced `done` evidence within `G` | `running` or `dispatched` | never on a missed heartbeat and never from an event. `G` (default 120 s, at least 4 × the sweep interval) lets local evidence win; earliest `lost` ≈ 60 s + `G` after the end [codex Q1] [termlink v0.1 review §1.1, §2.1] [AEF v0.2 answers §1.2] |
| T5 | `lost` → `done{outcome}` | reconciler (or supervisor, late) | fenced local evidence: `exit_code` + signed completion + hand-back hash, matching `(dispatch_id, attempt, nonce)` | `lost` | **idempotent upgrade**; `done` outranks `lost`. Appends history, keeps the `lost` row for audit [§6.2.1]. Accepted only if the evidence's `persisted_at` is not later than the `lost` history entry (the evidence existed when the end was confirmed); otherwise `forbidden_transition`, logged, operator notice. A T3/T3b naming a `lost` attempt is processed as T5 [ring20 v0.2 review §4, §S4] |
| T6 | `running` → `unknown` | hub | `deadline_running` passed, session end neither confirmed nor refuted: still alive past the deadline, absence seen only at another epoch (registry rebuilt or incomplete), partition, worker on another hub, reused pid | `running` | operator-visible; raises one operator notice; **never** triggers a new attempt by itself [§6.2.2] [AEF v0.2 answers §1] |
| T6b | `dispatched` → `unknown` | hub | `deadline_dispatched` passed and the session was never seen alive (so no T2 and no T4 basis) | `dispatched` | same notice rule as T6; a worker that refused or died before T2 still ends through T3b from supervisor evidence [AEF v0.2 answers §1.3] |
| T7a | `unknown` → `running` | hub | session confirmed alive again | `unknown` | heal path |
| T7b | `unknown` → `done{outcome}` | reconciler | same evidence as T5 (no `persisted_at` bound: `unknown` has no confirmed end) | `unknown` | `done` outranks. A T3/T3b naming an `unknown` attempt is processed as T7b |
| T7c | `unknown` → `lost` | hub | confirmed session end, no evidence | `unknown` | |
| T7d | `unknown` → `lost` \| `done{outcome}` | operator | explicit `fw worker resolve <id> <attempt> --as lost\|done --reason "…"`, run on the hub host; `done` additionally needs evidence **or** an operator-attested `outcome`, which writes `attested: true`, `attested_by`, `result.kind: none` and no `evidence_digest` | `unknown` | the only way out of `unknown` without hub/reconciler evidence; every resolve is logged with actor and reason. Until a signed operator identity exists this is a hub-host CLI, not an RPC, because scope alone cannot tell an operator from an agent holding control scope [AEF v0.2 answers §3]. **Detective control:** every resolve posts a notice to the operator's channel with dispatch, attempt, outcome, reason, actor and host. **Speed bump:** the CLI refuses an agent session (agent-environment markers present) without an explicit, recorded override; this is stated as a speed bump, not identity [ring20 v0.2 review §S2]. An attested `done` is **not finished work**: consumers (review verdicts, pass-rate, landing) refuse it as they refuse `paused` [ring20 v0.2 review §S3] |

**T8 (duplicate finalisation) is a response, not a transition.** Re-submitting a `done` with an identical
`evidence_digest` returns the stored record, appends nothing and changes nothing. [ring20 v0.2 review §10]

**A backend may stop an attempt** (worker deadline, revocation, operator request). The stop is an action, not a state:
the confirmed end follows T3 (a hand-back is readable) or T4 (none), and the `history` entry carries `cause ∈
{deadline_stop, revoked, operator_stop}`. T6 itself stops nothing. [ring20 v0.2 review §9]

**A `lost` attempt seen alive again** (sweep observes a live registration for its binding): **no transition.**
`lost → running` stays forbidden. The hub logs the observation and raises an operator notice, as for `done_conflict`;
late evidence can still upgrade the attempt through T5. [AEF v0.2 answers §1.4]

**Forbidden (all rejected):** `done → lost`, `done → running`, `lost → running`, `lost → unknown`, any write that
changes `outcome`/`result` of a `done` attempt (a `done` with a *different* `evidence_digest` is rejected with
`done_conflict`, logged, and surfaced to the operator — it is evidence of a bug or forgery, not a race).

**`outcome` derivation (T3/T3b/T5/T7b/T7d), evaluated in order** [claude Q1, codex Q1, §6.2.7]:
1. hand-back missing/unparseable/`attempt`≠, `nonce`≠, or hash cannot be bound → `handback-malformed`;
2. run.sh refusal path (e.g. `exit 3`) → `refused`;
3. `exit_code != 0` or hand-back `status: failed` → `failed`;
3b. hand-back `status: paused` with `exit_code == 0` → `paused`;
4. otherwise → `succeeded`.

`paused` is a terminal `done` for that attempt, **never a success**: a review verdict or pass-rate consumer must not
count it as finished work. The dispatch continues through attempt N+1 or a re-dispatch naming it in
`retry_of_dispatch_id` (§5.6, §8.4). [termlink v0.1 review §3.1] [AEF v0.2 answers §4]

**`fence_reject`.** Not a state. A response (and an appended `history` entry on the *current* attempt, outside the
lifecycle) returned for any write where: the write is a running-path write (T2, T-RECLAIM, a `questions` append or
an answer ack) naming an attempt that is not the current attempt; the nonce does not match; the credential is
missing or wrong; the `supervisor_gen` is stale; or the expected prior state does not match. It carries `reason ∈
{stale_attempt, bad_nonce, bad_credential, stale_gen, cas_mismatch, forbidden_transition, done_conflict}`.
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
backend returns `(attempt, nonce)`. A client never numbers an attempt or mints a nonce.
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
[codex Q5, claude Q2] [ring20 v0.2 review §S4]

### 6.6 External backends

*Sources: [ring20 v0.2 review §1, §2, §7, §11].*

A supervisor with its own durable store is a backend. Its `backend` value is a registered name other than `hub` and
`local` (ring20: `ring20`). It MUST implement every row of §3 with the §6.1 semantics in its own store, MUST pass §9
through an adapter, and MUST publish a mapping from its states and functions to §3.1/§3.3 (its id grammar, writer
authentication per §3.2, and its parameters per §2 included). It writes no hub or local record. `worker_binding`,
`registry_epoch_seen` and `dispatcher.session` are OPTIONAL for it. Its sweep writer may run in its supervisor under
the conditions of §3.2. §6.4 applies unchanged: the backend is chosen at creation and never switched mid-flight.

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
Conflating the two would silently deflate the pause queue. [claude Q3, opencode Q3] A backend that also writes a
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
[ring20 v0.2 review §12]

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

### CC-14 Stale supervisor generation
- **Given** A1 `running`, `supervisor_gen=1`; supervisor restarts and claims T-RECLAIM → `supervisor_gen=2`.
- **When** the old supervisor (gen 1) submits T3.
- **Then** `fence_reject(stale_gen)`; the gen-2 supervisor's T3 is accepted.

### CC-15 Unknown resolution by operator
- **Given** A1 `unknown`, no evidence, no confirmation.
- **When** `fw worker resolve D A1 --as lost --reason "host reimaged"` is run on the hub host.
- **Then** `unknown → lost` (T7d), logged with actor and reason; only then may T1 allocate A2. The same call from an
  agent session via a remote RPC is not available (no signed operator identity); from an agent session on the hub host
  it is refused without an explicit recorded override (speed bump); every resolve posts the operator notice. [ring20 v0.2 review §S2]

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
  allocated (T1) or a re-dispatch naming `retry_of_dispatch_id = D`.

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
- **When** the backend stops the worker, then (a) a valid hand-back is readable, or (b) none is.
- **Then** (a) `done{outcome}` through T3, (b) `lost` through the backend's sweep writer once the end is confirmed by
  its probe; in both cases the `history` entry carries `cause: deadline_stop`; no new attempt is allocated by the stop.
  Revocation (`cause: revoked`) behaves the same. [ring20 v0.2 review §9]

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
6. **Supervisor credential mechanism for the hub** (§3.2) is not specified beyond "a credential the worker never sees";
   TermLink to propose the carrier. [ring20 v0.2 review §3]
3. ~~**Who runs the reconciler on a hub host that has no AEF** (ring20 workers)?~~ **Closed in v0.2.1:** ring20 has no
   reconciler of its own; its supervisor submits late evidence through T5 (ring20 msg b193272e, relayed by TermLink).
   [termlink v0.2 agree §3]
4. **Authority transfer on prolonged hub outage** is out of scope (§6.4); if the operator wants local
   fallback *during* a hub outage it needs its own protocol.
5. **Signed operator identity** for T7d: until it exists resolve is a hub-host CLI; the identity mechanism is not
   specified. [AEF v0.2 answers §3]
