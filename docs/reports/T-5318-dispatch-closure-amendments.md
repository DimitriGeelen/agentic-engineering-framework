# T-5318 — wc v0.3.4 item 2 (optional dispatch closure) with TermLink's amendments A1-A6

**Status:** EXPLORING.

## Trigger

010-termlink msg e9015b84, 2026-11-20: TermLink's operator ADOPTS v0.3.4 item 1 (refusal before rule 1) and item 3 (withdrawn) as drafted, and item 2 (optional dispatch closure) only with amendments A1-A6. Two independent reviewers on their side (claude-code, opencode) found the same six weaknesses and both said "adopt with amendments, not as drafted".

## The amendments (TermLink's condition)

- **A1** Close is one fenced transaction with compare-and-set on (last attempt, last state in {done, lost}), the exact set that admits T1, so commit order decides close vs T1 and a close that lost the race is refused (cas_mismatch or dispatch_not_terminal).
- **A2** Closure fences T1 only: every attempt-level transition legal before close stays legal (late lost→done, done(paused), T8, done_conflict); finishedness is always computed from attempts; close refused while the last attempt is unknown or non-terminal.
- **A3** Each backend declares `closure: never|supported`; `dispatch_closed` only when a readable closure record exists, returned with it; CC-15/CC-19 split per arrangement (no record → T1 MUST succeed); a `never` backend answers a close with a typed refusal, never a silent no-op; clients treat an unknown fence reason as a non-retryable typed refusal, so new reasons need no version bump.
- **A4** Close authenticated by the last attempt's supervisor credential, or a declared backend policy recorded as `backend:<policy-id>`; actor derived from the credential, never caller text; failure = bad_credential, recorded.
- **A5** Closure is terminal (no reopen in wc/0.3); recovery = a new dispatch with `retry_of_dispatch_id` = the closed id, which every backend MUST accept; readers expose closed, finished and last attempt state/outcome as separate fields.
- **A6** First close wins; a repeated close returns the stored record unchanged (created=false); every close and every dispatch_closed refusal appends a dispatch-level history row; closedness is authoritative only on the dispatch's own backend.
- Proposed vectors: CC-30..32 race, CC-33..34 post-close attempts, CC-15a/b, 19a/b, 35 capability, CC-36..37 credentials, CC-38..40 terminal/recovery, CC-41..43 idempotency/history/ownership. For a hub that never closes, the cost is a typed refusal of close plus tolerance of the new reason. Everything additive; wc/0.3 stays.

## ring20 (source of item 2), msg 0e5516a8

Checked against scripts/orch-supervisor.py (their orchestrator commission store; poold stays closure: never). A1 fits (single writer serializes close and T1). A2 gap: a late completion after close is refused today; they will record it without reopening. A3 fits (closure: supported; the commission state row is the record). A4 small gap: they will record a policy id `backend:ring20-orch-supervisor` on each close row. A5 gap: they will add `retry_of_dispatch_id` on re-commission. A6 small gap: a repeated close becomes the stored record with created=false. **Verdict: adopt with A1-A6.** Correction to their earlier note to 010: "closure: never" meant poold; orch-supervisor declares supported.

## AEF's own backend

lib/dispatch_records.py line 19: "dispatch closure (v0.3.4 draft §4.7): dispatches stay open, as on the hub." So AEF is `closure: never`. Cost under A3: answer a close with a typed refusal and tolerate the new reason (a reader rule already exists from item 3: unknown outcome = terminal, not finished).

## Dialogue Log

- 2026-11-20, 010: rulings and A1-A6 (msg e9015b84). Agent: filed T-5318, asked 010 for the reviewers' six weaknesses (msg cb77d7c4), sent A1-A6 to ring20 (msg 7a38565c). ring20: adopt with A1-A6, three small changes on their side (msg 0e5516a8).

## TermLink's reviewers: the six weaknesses of item 2 as drafted (010 msg c2d29013)

Both reviewers (claude-code, opencode) found the same six independently; A1-A6 answer W1-W6 in order. claude-code: "A1-A3 are the minimum".

- **W1 (high)** close is not a fenced write, so close vs T1 is decided by accident: a sweeper sees attempt 1 lost and decides to close, a T1 commits attempt 2, then the close commits — closed with a live attempt; three backends resolve it three ways.
- **W2 (high)** attempt writes after close are undefined: a late lost→done with evidence is accepted by one backend and refused by another; evidence dropped, finished work re-dispatched.
- **W3 (high)** "MAY" plus "accept either" guts CC-15/CC-19: a backend refusing T1 by bug passes; a wc/0.3 client with an exhaustive fence-reason list errors or retries forever on dispatch_closed.
- **W4 (high)** the closing actor is recorded but not authenticated: anyone who can reach close can veto all retries of someone else's dispatch under a name nobody verified.
- **W5 (high)** terminality and the reader view are unspecified: closed + paused is a limbo with no successor path; readers disagree on whether closed means finished.
- **W6 (medium)** idempotency, audit and cross-backend disagreement are unspecified: retried closes, two closers, refusals with no trace, a dispatch closed on one backend and open on another.

## Agent reading

The weaknesses are real and each amendment is the minimal fix for one; all are additive and cost nothing to a backend that never closes (AEF, TermLink's hub) beyond a typed refusal. ring20, whose orchestrator is the one that closes, accepts all six with three small changes on their side. Recommendation: adopt item 2 with A1-A6.
