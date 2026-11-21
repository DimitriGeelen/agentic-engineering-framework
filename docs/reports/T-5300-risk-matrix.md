# Risk matrix — submitter withdraws a never-started pool job (T-5300)

<!-- Drafted under T-5316 (T-5310 practice, slice 4) from .tasks/templates/risk-matrix.md.
     The drafting agent scored it; an independent reviewer judges the scores; the operator
     decides only the acceptances the machine check lists. -->

## Header

- **Change:** shared worker contract v0.3.4 item 3 adds T3w `dispatched → done{withdrawn}`: the holder of an attempt's credentials (its nonce plus the `supervisor_token` that `dispatch.allocate` returns once, with a matching `supervisor_gen`) may end an attempt that never started. Allowed only from `dispatched` for the current attempt; `running` → `cas_mismatch`; `done`/`lost`/`unknown` → `forbidden_transition`; an identical repeat is T8; logged in `history` with actor and reason; **no** operator notice; the sweep writer never withdraws and there is no operator path. A supervisor must launch only after its T2 was accepted. AEF implements it as `Store.withdraw` in lib/dispatch_records.py (T-5312); TermLink and ring20 implement it in their own backends (ring20's poold on a `ring20.pool.withdraw/1` request). Specified in docs/specs/shared-worker-contract-transitions.md (T-5311), conformance vectors CC-26..CC-29 (T-5317).
- **Baseline:** wc/0.3.3, no withdraw: a `dispatched` attempt ends only by start and complete, or moves to `unknown` past `deadline_dispatched` and raises an operator-resolve notice. A job the submitter no longer wants holds its node until it runs or times out (ring20: 9 judge jobs held 5 h on two nodes).
- **Task:** T-5300 (spec T-5311, AEF backend T-5312)

## Scales

| Value | Likelihood | Impact |
|------:|------------|--------|
| 1 | rare | negligible |
| 2 | unlikely | minor |
| 3 | possible | moderate (one job or result wrong) |
| 4 | likely | major (token stolen or data leaked, contained) |
| 5 | almost certain | severe (node or network compromised, accounts lost) |

**Score** = likelihood × impact, 1-25. **Bands:** low 1-5, medium 6-12, high 15-25.

## Summary

| # | Risk | Domain | How to detect the door is open | How to detect it happening | Impact | Likelihood | Exists anyway (baseline)? | Introduced by the change? | Key mitigation |
|---|------|--------|--------------------------------|----------------------------|-------:|-----------:|---------------------------|---------------------------|----------------|
| 1 | Forged withdrawal denies service to someone else's job | availability | a party other than the submitter holds an attempt's nonce and supervisor token | a `T3w` history entry whose actor is not the job's submitter | 3 | 2 | yes, for a party that controls the submitter's host (it could already write T2 then T3 `failed` with the supervisor's means, or stop the supervisor) | PARTLY NEW: a party holding only the nonce and token, without host control or the supervisor's signing means, can now end a never-started job by T3w; before, it could not necessarily do T3 `failed` or stop the supervisor | per-attempt nonce and token, returned once, stored by the hub only as sha256; Execute-scope connection; `supervisor_gen` fence |
| 2 | The submitter withdraws the wrong job or too many, unseen | availability / observability | any caller of `Store.withdraw` or `ring20.pool.withdraw/1` | `T3w` entries in `history`; no operator notice is raised | 3 | 2 | no (in the baseline an unwanted job ran or timed out to `unknown` with a notice) | NEW (a silent terminal path) | only the attempt's own credentials work, so only the submitter's own jobs; `withdrawn` is never success and a later T1 may allocate A2; actor and reason logged |
| 3 | Race between withdrawal and launch: a withdrawn job runs anyway | correctness / cost | a supervisor that launches the agent child before its T2 is accepted | a `done_conflict` on a late completion of a `done{withdrawn}` attempt | 3 | 2 | no (no withdrawal to race with) | NEW (the race exists only once T3w does) | T2 and T3w each run as one CAS under the dispatch lock, exactly one wins (CC-27, threaded test in T-5312); the late completion is refused as `done_conflict` in the dispatch store, but a run that goes ahead can still write elsewhere on its own (impact not lowered) |
| 4 | The attempt credential is kept longer and carried on a new request path | credential | a withdraw request that carries nonce and token over a channel other than the Execute-scope connection, or a submitter that persists them to honour later withdrawals | the token appears in a bus message, log or `reason` field | 4 | 2 | yes (the supervisor already holds the same credential for the attempt's life) | PARTLY NEW (the submitter must keep it until the job starts, and ring20's poold receives it in withdraw requests) | the spec requires the Execute-scope connection; the hub keeps only sha256; credentials are per attempt and die with it |
| 5 | A reader that does not know `withdrawn` misreads it | correctness | a backend emits `withdrawn` before all three owners adopt v0.3.4, or a reader that predates the §2 reader rule | a withdrawn attempt shown as finished work, or a reader that refuses the record | 3 | 2 | no (the value did not exist) | NEW (a new outcome value under the unchanged `wc/0.3` version field) | §2 reader rule (an unknown outcome is terminal and not finished work, like `paused`); no backend emits it before adoption; AEF has no caller of `Store.withdraw` outside tests |
| 6 | An abandoned job holds a node until it runs or times out | availability | a submitter that no longer wants a `dispatched` job | a node busy with jobs nobody waits for; `unknown` notices to the operator | 2 | 4 | yes (ring20's 9 jobs held 5 h) | reduced (the submitter can now release the job) | T3w itself |

## Actor split (one table per risk)

Actors (fixed list): `own-agent-unintentional`, `human-unintentional`, `outsider-intentional`, `provider-host`, `intruder`.

### Risk 1 — Forged withdrawal denies service to someone else's job

| # | Actor | How | L | I | Score | Mitigated L × I | Mitigated score |
|---|-------|-----|--:|--:|------:|-----------------|----------------:|
| 1.1 | own-agent-unintentional | an agent cannot withdraw another submitter's job: it needs that attempt's nonce and token, which only the allocating caller received | 1 | 3 | 3 | | |
| 1.2 | human-unintentional | the human has no path to T3w (no operator path in this revision) | 1 | 1 | 1 | | |
| 1.3 | outsider-intentional | an outsider who has obtained the nonce and token of one attempt (credential theft only, no host control) can now withdraw that never-started job; this capability is new with T3w. Obtaining them is hard: they are returned once, the hub stores only their sha256, and the request needs an Execute-scope connection | 1 | 3 | 3 | | |
| 1.4 | provider-host | the hub host receives the token in transit (row 4.4) but holds the store itself, so T3w adds nothing for it; a host running the submitter has full host control, so it could already end the job by stopping the supervisor; T3w adds nothing for it (exists anyway) | 1 | 3 | 3 | | |
| 1.5 | intruder | an intruder with control of the submitter's host reads the credentials and withdraws its jobs; with that host control it could already kill the supervisor or end the jobs, so this row exists anyway (full host compromise, not credential theft alone, which is row 1.3) | 2 | 3 | 6 | | |

### Risk 2 — The submitter withdraws the wrong job or too many, unseen

| # | Actor | How | L | I | Score | Mitigated L × I | Mitigated score |
|---|-------|-----|--:|--:|------:|-----------------|----------------:|
| 2.1 | own-agent-unintentional | a cleanup loop in a submitter (for example poold handling a batch withdraw) withdraws jobs still wanted; nothing tells the operator. Mitigated impact stays 3: no detection-and-recovery control exists yet that would make the loss a delay only (T-5329 would add the count) | 2 | 3 | 6 | 2 × 3 | 6 |
| 2.2 | human-unintentional | the operator asks ring20 to withdraw "the stuck jobs" and a wanted one is among them (the same lost job as 2.1, so the same impact) | 2 | 3 | 6 | | |
| 2.3 | outsider-intentional | needs the attempt credentials (risk 1) | 1 | 1 | 1 | | |
| 2.4 | provider-host | not involved: the decision is the submitter's | 1 | 1 | 1 | | |
| 2.5 | intruder | covered by risk 1.5 | 1 | 1 | 1 | | |

Mitigation for 2.1: `withdrawn` is terminal and not finished work, so the job is not reported as done; a new T1 can allocate a fresh attempt (A2) and the history entry names actor and reason. These lower nothing yet: until a detection control exists (T-5329 counts withdrawals per submitter), a wanted job lost this way is still a moderate harm (impact 3), so 2.1 stays at 2 × 3 = 6.

### Risk 3 — Race between withdrawal and launch: a withdrawn job runs anyway

| # | Actor | How | L | I | Score | Mitigated L × I | Mitigated score |
|---|-------|-----|--:|--:|------:|-----------------|----------------:|
| 3.1 | own-agent-unintentional | an agent writing a supervisor (AEF, TermLink or ring20) launches the agent child before its T2 is accepted; the job is withdrawn in between and runs anyway, spending a subscription seat; the run can still act on its own (an AEF judge seat records its verdict rows itself, and the verdict ledger does not consult dispatch records), so impact stays 3 | 2 | 3 | 6 | 2 × 3 | 6 |
| 3.2 | human-unintentional | the human does not write T2 or T3w | 1 | 1 | 1 | | |
| 3.3 | outsider-intentional | an outsider cannot time a T2 without the attempt credentials | 1 | 1 | 1 | | |
| 3.4 | provider-host | a backend store that does not run T2 and T3w as one atomic compare-and-set lets both succeed | 1 | 3 | 3 | 1 × 3 | 3 |
| 3.5 | intruder | no gain over ending the job directly (risk 1.5) | 1 | 1 | 1 | | |

Mitigation for 3.1 and 3.4: in AEF's store both writes run under the dispatch lock and CAS on `dispatched`, exactly one wins (CC-27; 20-round threaded race test, T-5312); CC-26..CC-29 are in the conformance vectors (T-5317), so a backend store that breaks the CAS fails them. A late completion of a withdrawn attempt is `done_conflict` in the dispatch store, but a run that goes ahead can still write elsewhere on its own (an AEF judge seat records verdict rows itself), so the impact of 3.1 is not lowered. The vectors test the store, not a supervisor's launch order, so 3.1 stays at likelihood 2: 2 × 3 = 6 until a supervisor launch-after-T2 case exists (T-5330).

### Risk 4 — The attempt credential is kept longer and carried on a new request path

| # | Actor | How | L | I | Score | Mitigated L × I | Mitigated score |
|---|-------|-----|--:|--:|------:|-----------------|----------------:|
| 4.1 | own-agent-unintentional | an agent building the withdraw request path sends nonce and token in a bus or chat message, logs them, or persists them in a readable file so a later withdraw can be honoured (the spec rule that keeps the credential on the Execute-scope connection binds only the hub route; other backends such as ring20's pool use their own channel, and nothing yet forbids logging or persisting it) | 2 | 4 | 8 | 2 × 4 | 8 |
| 4.2 | human-unintentional | the operator pastes a withdraw command, with its credential, into a shared channel | 1 | 4 | 4 | | |
| 4.3 | outsider-intentional | an outsider reading a channel the credential was sent on can withdraw that never-started attempt; completing it (T3) also needs the signed completion of spec §6.5, which a channel reader cannot produce (the generation travels with the T3w request and is no barrier) | 1 | 4 | 4 | | |
| 4.4 | provider-host | the hub host sees the credential in transit on the Execute-scope connection, as it already does for allocate and T2 | 1 | 4 | 4 | | |
| 4.5 | intruder | an intruder reads a persisted credential and withdraws or completes that attempt (same stolen credential as 4.1, so the same impact); the supervisor's copy was already readable on that host | 2 | 4 | 8 | | |

Mitigation for 4.1: the spec names the Execute-scope connection as the only hub route for the credential; the hub stores only sha256; the credential is valid for one attempt, so a leak is contained to that attempt (it can end or complete only that job).

### Risk 5 — A reader that does not know `withdrawn` misreads it

| # | Actor | How | L | I | Score | Mitigated L × I | Mitigated score |
|---|-------|-----|--:|--:|------:|-----------------|----------------:|
| 5.1 | own-agent-unintentional | an agent wires a caller of `Store.withdraw` before v0.3.4 is adopted, or writes a reader that counts any `done` as finished work, so a withdrawn job shows as done | 2 | 3 | 6 | 1 × 3 | 3 |
| 5.2 | human-unintentional | the operator reads a status view that lists `done` without its outcome | 1 | 2 | 2 | | |
| 5.3 | outsider-intentional | not reachable without the credentials | 1 | 1 | 1 | | |
| 5.4 | provider-host | a peer backend (TermLink, ring20) emits `withdrawn` before AEF's readers are ready | 1 | 3 | 3 | | |
| 5.5 | intruder | no gain | 1 | 1 | 1 | | |

Mitigation for 5.1: the §2 reader rule (an unknown outcome is terminal and not finished work); the spec forbids emitting `withdrawn` before all three owners adopt v0.3.4; in AEF only tests call `Store.withdraw`.

### Risk 6 — An abandoned job holds a node until it runs or times out

| # | Actor | How | L | I | Score | Mitigated L × I | Mitigated score |
|---|-------|-----|--:|--:|------:|-----------------|----------------:|
| 6.1 | own-agent-unintentional | a submitting agent no longer needs its jobs (a judge run superseded) and they stay `dispatched` for hours | 4 | 2 | 8 | 2 × 2 | 4 |
| 6.2 | human-unintentional | the operator cancels the work upstream but cannot release the pool jobs | 2 | 2 | 4 | 1 × 2 | 2 |
| 6.3 | outsider-intentional | not involved | 1 | 1 | 1 | | |
| 6.4 | provider-host | not involved | 1 | 1 | 1 | | |
| 6.5 | intruder | not involved | 1 | 1 | 1 | | |

Mitigation for 6.1 and 6.2: T3w itself; the submitter releases the job and the node is free.

## Net

**Adds:** a new, silent terminal path (risk 2), a race that a non-conforming supervisor can lose (risk 3), a new outcome value under an unchanged version field (risk 5), and a second holder and route for the attempt credential (risk 4, PARTLY NEW). Each is contained to one attempt or one job, and each has a control in the spec or the code: per-attempt credentials, CAS plus `done_conflict`, the reader rule, the Execute-scope route.

**Reduces:** abandoned jobs holding nodes for hours, and the `unknown` operator notices that came with them (risk 6).

**Does not change:** a holder of an attempt's credentials, or an intruder on the submitter's host, could already end that job (risk 1).

**Controls it needs:** (a) a supervisor conformance check that the agent child is launched only after T2 is accepted (the vectors test the store, not the supervisor); (b) withdraw requests that carry the credential only on the Execute-scope connection, never on a bus topic or in a log, checked when ring20 and TermLink build their paths; (c) an audit or status line that counts `withdrawn` per submitter, so a mass withdrawal is visible without an operator notice.

**Needs operator acceptance:** risk 1 (forged withdrawal of someone else's job), PARTLY NEW: its 6 comes from row 1.5 (full host compromise, which exists anyway); the part T3w adds, withdrawal by a party holding only the credential, scores 3 (row 1.3); mitigation T-5328 keeps the credential out of readable files; risk 2 (a wanted job withdrawn unseen), NEW and still 6 after mitigation: no detection-and-recovery control exists yet (T-5329 adds the count); risk 3 (a withdrawn job runs anyway), NEW and still 6: the run can act on its own and no supervisor launch-order case exists yet (T-5330); and risk 4 (attempt credential kept longer and carried on a new request path), PARTLY NEW and still 8 after mitigation: row 4.1 (an agent logs or persists the credential; the Execute-scope rule binds only the hub route, and control (b) is not built) and row 4.5 (an intruder on the submitter's host reads a persisted credential). That row mostly exists anyway, since the allocating caller already received the credential in the baseline; what is new is that it must now be kept until the job starts. It drops below 6 only when control (b) is built on every backend's withdraw path and the R-NEW-5 file-mode check ships. No risk reaches 15.

## Register entries to file

Risks with any actor at 6 or more (unmitigated): 1, 2, 3, 4, 5, 6. The parent files these in
`.context/project/concerns.yaml`; ids are placeholders.

```yaml
- id: R-NEW-5
  type: risk
  title: "Forged withdrawal of another submitter's pool job"
  description: "T3w ends a dispatched attempt for whoever presents its nonce, supervisor token and supervisor_gen. An intruder controlling the submitter's host can withdraw its jobs (it could already stop them with that host control); a party holding only the credential can now withdraw a never-started job, which is new with T3w."
  status: watching
  likelihood: 2
  impact: 3
  score: 6
  ranking: medium
  actors:
  - actor: intruder
    how: "reads the credentials from the dispatcher on the submitter's host and withdraws its jobs"
    likelihood: 2
    impact: 3
  exists_anyway: true
  introduced_by: T-5300       # PARTLY NEW: credential-only withdrawal
  mitigation_task: T-YYYY
  created: 2026-11-21
- id: R-NEW-6
  type: risk
  title: "Submitter withdraws a wanted job, unseen"
  description: "T3w raises no operator notice; a cleanup loop or a batch withdraw can end jobs still wanted, visible only in history."
  status: watching
  likelihood: 2
  impact: 3
  score: 6
  ranking: medium
  actors:
  - actor: own-agent-unintentional
    how: "a submitter's cleanup loop withdraws jobs still wanted"
    likelihood: 2
    impact: 3
    mitigated_likelihood: 2
    mitigated_impact: 3
  introduced_by: T-5300
  exists_anyway: false
  mitigation_task: T-YYYY
  created: 2026-11-21
- id: R-NEW-7
  type: risk
  title: "Withdrawn job runs anyway (supervisor launches before T2)"
  description: "The T2/T3w race is safe only if a supervisor launches after its T2 is accepted. A non-conforming supervisor runs a withdrawn job; its completion is refused as done_conflict, so the run is wasted."
  status: watching
  likelihood: 2
  impact: 3
  score: 6
  ranking: medium
  actors:
  - actor: own-agent-unintentional
    how: "a supervisor implementation launches the agent child before its T2 is accepted"
    likelihood: 2
    impact: 3
    mitigated_likelihood: 2
    mitigated_impact: 3
  - actor: provider-host
    how: "a backend store does not run T2 and T3w as one atomic CAS"
    likelihood: 1
    impact: 3
    mitigated_likelihood: 1
    mitigated_impact: 3
  introduced_by: T-5300
  exists_anyway: false
  mitigation_task: T-YYYY
  created: 2026-11-21
- id: R-NEW-8
  type: risk
  title: "Attempt credential kept by the submitter and carried in withdraw requests"
  description: "To withdraw, the submitter must keep nonce and supervisor token until the job starts and send them with the request (ring20.pool.withdraw/1). A request sent on a bus topic, logged or persisted readable leaks the attempt's credential."
  status: watching
  likelihood: 2
  impact: 4
  score: 8
  ranking: medium
  actors:
  - actor: own-agent-unintentional
    how: "withdraw request path sends or logs the credential outside the Execute-scope connection"
    likelihood: 2
    impact: 4
  - actor: intruder
    how: "reads a persisted credential on the submitter's host"
    likelihood: 2
    impact: 4
  introduced_by: T-5300
  exists_anyway: true
  mitigation_task: T-YYYY
  created: 2026-11-21
- id: R-NEW-9
  type: risk
  title: "Reader misreads the new withdrawn outcome"
  description: "withdrawn is added under the unchanged wc/0.3 version field. A caller wired before adoption, or a reader that counts any done as finished work, shows a withdrawn job as done."
  status: watching
  likelihood: 2
  impact: 3
  score: 6
  ranking: medium
  actors:
  - actor: own-agent-unintentional
    how: "caller of Store.withdraw wired before v0.3.4 adoption, or reader counts any done as finished"
    likelihood: 2
    impact: 3
    mitigated_likelihood: 1
    mitigated_impact: 3
  introduced_by: T-5300
  exists_anyway: false
  mitigation_task: T-YYYY
  created: 2026-11-21
- id: R-NEW-10
  type: risk
  title: "Abandoned pool job holds a node until it runs or times out"
  description: "Baseline risk the change reduces: before T3w a dispatched job nobody wanted held its node for hours (ring20: 9 jobs, 5 h) and ended as unknown with an operator notice."
  status: mitigated
  likelihood: 4
  impact: 2
  score: 8
  ranking: medium
  actors:
  - actor: own-agent-unintentional
    how: "submitting agent's superseded jobs stay dispatched for hours"
    likelihood: 4
    impact: 2
    mitigated_likelihood: 2
    mitigated_impact: 2
  exists_anyway: true
  mitigation_task: T-5312   # the change itself is the mitigation
  created: 2026-11-21
```

Mitigation task proposals (arc `risk`):

- R-NEW-5 — **"Keep attempt credentials out of readable files on the submitter host"**: check where AEF's dispatcher and ring20's poold hold nonce and token, and require mode 0600 or memory only; record the result in the spec's §3.2.
- R-NEW-6 — **"Count withdrawals in status and audit"**: `fw worker status` and `fw audit` report `withdrawn` per submitter and per day, and WARN above a threshold, so a mass withdrawal is seen without an operator notice.
- R-NEW-7 — **"Supervisor launch-after-T2 conformance case"**: add a vector or test that drives a supervisor (not just the store) through a withdraw-before-T2 and asserts nothing is launched; ask TermLink and ring20 to run it.
- R-NEW-8 — **"Withdraw request carries the credential only on the Execute-scope connection"**: state it as a MUST in v0.3.4 §3.2 and check ring20's `ring20.pool.withdraw/1` and TermLink's handler against it before they ship.
- R-NEW-9 — **"Reader rule for unknown outcomes in AEF's readers"**: grep AEF's dispatch-record readers for `state == "done"` used as finished work and make each honour the §2 rule; add a test with an unknown outcome value.
- R-NEW-10 — no new task: T-5312 is the mitigation; file with status `mitigated`.
