# T-3896 RCA: the approvals queue offered a GO that was certain to be refused

**Date:** 2026-10-05 · **Reported by:** operator (T-3659 GO refused in Watchtower) · **Concern:** G-108 (high)

## What happened

The operator opened the approvals queue, saw T-3659 ("P-01 Zero-to-running AEF") with **Recommendation: GO**, and clicked GO. The refusal came back:

> Cannot record GO — 4 Open Question(s) not yet disposed … Resolve the issue above, then reload to retry.

Nothing was recorded. The operator spent attention on a decision the system could never accept, and the closing line told them to fix work that is the **agent's**.

## Measured scope

On 2026-10-05, of the pending inceptions on /approvals, **6 carried a GO/NO-GO/DEFER they could not pass**: T-2899, T-3501, T-3659, T-3670, T-3731, T-3752. Together they have **24 Open Questions with no disposition**.

Origins: T-3659 is an external proposal (P-01) the operator pasted. T-3752 is from 010/832, and T-3501 from cross-agent proposals. Origin is recorded nowhere structurally, only in prose.

## Five whys

1. **Why was the GO refused?** The decide gate (`update-task.sh check_disposition_gate`, T-2190) requires every IW-N to carry `disposition:` plus a rationale. T-3659's four had neither.
2. **Why was it offered at all?** `/approvals` (`_load_pending_go_decisions`) lists a pending inception when its `## Recommendation` section is ≥20 characters. The empty template lines `**Recommendation:** GO / **Rationale:** / **Evidence:**` already pass. The same goes for the `/inception/<id>` decide form, which renders the GO button without asking.
3. **Why don't those surfaces ask the gate's question?**
   - T-3279 (G-102, 2026-09-05) already found exactly this and moved the predicate into one shared file, `lib/inception-readiness.sh`.
   - It wrote the rule down: *"a completion-gate predicate lives in ONE shared implementation, and every surface that invites the completion calls it"*.
   - It wired the CLI decide preflight and `fw task review`, but not the two Watchtower surfaces.
   - No test asserts that what a page *offers* would pass what the gate *records*.
4. **Why did the miss survive?** Each later incident on these pages was fixed at the **refusal** end:
   - T-2051: the error became visible;
   - T-3539: a silent CLI failure got named;
   - T-3540: the message is no longer clipped.

   Three improvements to the message after the click, none to the invitation before it. Polishing the failure made it more tolerable, and so less likely to be traced to its source.
5. **Why did the inceptions reach the queue unready in the first place?** The authoring agent (a session of this framework, 2026-10-01) wrote a recommended answer under each question but left `disposition:` and `rationale:` empty. It treated "I recommended an answer" as "the question is disposed". Nothing at filing time says "this inception is not decision-ready". The handoff check exists, but the inception was never handed off. It surfaced through the queue instead.

## The recurring class (four instances on one day)

| Task | Surface that invites | Gate that enforces | Divergence |
|---|---|---|---|
| T-3896 | /approvals, /inception GO | decide disposition gate | page uses a weaker predicate |
| T-3872 | sidecar injector ("N messages waiting") | prompt hook (what is shown) | injector ignored "answered" |
| T-3881 | upgrade expected-hooks list | init settings template | two hook lists |
| T-3876 | watchtower `start` | watchtower `restart` | two port rules |

**One fact, two consumers, two predicates.** The framework already knows the cure (T-3279: one implementation, every caller uses it), but it is applied case by case after each failure. Nothing detects the next instance.

## Scored against the directives

- **Reliability — failed.** The queue claims an item is decision-ready when it is not. That is a false green aimed at the operator.
- **Usability — failed.** The operator is interrupted after acting, and told to repair agent work.
- **Antifragility — partial.** The class was learned once (G-102) and not generalised. Today's fix must also leave a detector.
- **Sovereignty / Authority model.** A decision surface the human cannot trust erodes the one control that is theirs.

## What we do

1. **Fix the surfaces (T-3896).** `/approvals` and `/inception/<id>` call the shared `inception_handoff_blockers`.
   - A not-ready inception shows "Not ready for your decision — the agent still owes: …" and **no GO button**.
   - The post-click refusal (still possible in a race) says this is the agent's work, not "resolve the issue above".
2. **Repair the queue (T-3896).** Write the dispositions for the 6 inceptions, so they are genuinely decision-ready. These are agent judgements about the open questions, recorded so the operator's GO or NO-GO decides on them explicitly.
3. **Tag origin (T-3897, operator's proposal).**
   - Every approval carries `origin:` (operator | agent | pickup:<project> | peer:<project> | proposal:<source>), set at filing.
   - It is shown as a badge, so a decision born from a peer request or an external proposal is visibly so.
   - Such items deserve the most scrutiny, as T-3659 shows (an unratified proposal, ingested and queued looking ready).
4. **Detect the class.**
   - Add a test that renders every pending inception and asserts listed-with-GO ⇒ blockers empty.
   - Add a doctor/audit WARN for any pending inception that is shown as decidable but has blockers. That catches the next unready filing before the operator does.

## What the agent does differently

An inception is not handed to the operator until `inception_handoff_blockers` is empty. Recommending an answer is not disposing a question. If a question is truly the operator's to answer, its disposition says so explicitly (`deferred` to the operator, with what is needed). It is never left blank in a queue that looks ready.
