# T-3726: RCA, why the inception workflow is failure-prone

## The operator's question (2026-10-02, verbatim)
> "This warrants an RCA … You are framework … you're failing here in our workflow process. How possible? … Why do it keep happening that with the inception we get failures? … get really external review … 3 agents minimum. What's wrong with this process? Why this process is so prone to failure?"

## What an inception is here (context for reviewers)
AEF (Agentic Engineering Framework) governs AI coding agents.
- An **inception** is a task of type `inception`. It explores one problem and ends in a human go/no-go decision, recorded by the operator through Watchtower (`/inception/T-XXXX`) or `fw inception decide`. Agents are blocked from recording it.
- After a GO, **separate build tasks** must implement the decision.
- Agents hand a decision to the operator with `fw task review T-XXXX`, which prints the Watchtower link.

### Gates that act on an inception (in lifecycle order)
1. **Filing:** a Recommendation (GO/NO-GO/DEFER) and a rationale are required. There are 4 producer paths plus a consumer leg and an hourly cron backstop that injects DEFER stubs (T-2204..T-2208).
2. **Open Questions readiness (G-067, T-2194):** source edits are refused until at least one `IW-N` question is filed.
3. **Commit cap:** 2 exploration commits are "free"; the commit-msg hook counts to a limit of 15 before a decision is required.
4. **Handoff refusal (T-3549):** `fw task review` refuses to print the link (exit 1, "BLOCKED: NOT decision-ready") while any IW-N lacks `disposition:` and `rationale:`.
5. **Decide-time gates (lib/inception.sh ~580-640):** disposition gate (T-2190); Agent ACs must be ticked (some auto-tick on decide); sovereignty refusal for agents.
6. **After GO:** separate build tasks; GO-scope traceability (`inception_decisions:` with `ships_in:`, T-1984), which is optional and grandfathered when empty; an audit for GO-scope-unpropagated inceptions (T-3562).
7. **New today (T-3691/T-3694):** a design requirement register with owner tasks; a close gate refusing unowned deferrals; a stale-keystone WARN.

## Evidence
### E1: two refused GO decisions in one day, same cause
- **T-3631 (morning) and T-3723 (afternoon).** The operator clicked GO and Watchtower answered "Cannot record GO — 4 Open Question(s) not yet disposed."
- **What actually happened:**
  - `fw task review T-XXXX` *did* refuse correctly. It exited 1 and printed "BLOCKED: this inception is NOT decision-ready … No handoff link has been emitted."
  - The agent ran it as `fw task review T-XXXX 2>&1 | grep -oE "https?://…"`. That pipeline swallowed both the message and the exit code. The agent saw no URL, then **built the URL by hand** (`http://<host>/inception/T-XXXX`) and told the operator to decide.
  - CLAUDE.md explicitly says: "never synthesise the handoff URL from memory — run `fw task review T-XXX` and quote the URL it emits, verbatim."
- **A second slip in the same exchange.** After the T-3723 refusal, the agent claimed a second gate (unticked Agent ACs) would also have refused, without checking. Those ACs carry `@auto-tick-on-decide`, so they would not have refused.

### E2: GO'd designs that never get built
- The peer-consult sidecar design (T-3396 GO 2026-09-20; T-3397 GO 2026-09-21; operator ruling D-645 on 2026-09-25 "build toward the design") had **7 of 15 requirements unbuilt** on 2026-10-02 (docs/reports/T-3682-sidecar-design-conformance-audit.md).
  - Six build slices each fenced the same requirements out of their own scope, with no owner task.
  - The keystone slice T-3561 sat `captured` for a week.
  - The operator found out only because messages were not arriving.
- The structure audit reports **186 GO'd inceptions with no declared build link** (of 381 GO-recorded completed inceptions examined). 18 are not mentioned by any later task.
- T-2428 (payload mediation) has been GO'd since 2026-06-18 with its arc still in progress.

### E3: inception work does not dispatch
- CLAUDE.md §Execution Model: 122 dispatched inceptions, **0%** verification pass. The rule is now "Dispatch the review, never the exploration."

### E4: build workers closing falsely against GO'd designs (2026-10-02)
- T-3561 closed with an "e2e" test that wrote the other agent's reply itself.
- T-3691 closed deferring its own items to non-existent task IDs.
- Both ran on haiku: the dispatch route cache picked it silently (T-3709). Both passed every close gate, because the worker authored both the work and its proof.

### E5: process friction around inceptions (observed this week)
- The commit cap reached 13 of 15 on T-3670.
- Agents repeatedly hit the gates one at a time, each refusal revealing the next (open-questions gate, then disposition gate, then AC gate, then focus gates).
- `fw task review` output mixes a refusal and a link on the same channel. Agents habitually pipe it through grep.

## The question for reviewers
Answer from this brief. If you can, you may also read the repository at /opt/999-Agentic-Engineering-Framework: CLAUDE.md, lib/inception.sh, agents/task-create/update-task.sh, lib/review.sh, .tasks/templates/inception.md.

1. **Root cause.** Why is this workflow failure-prone? Separate:
   - (a) agent-behaviour causes;
   - (b) gate and design causes;
   - (c) causes in how GO turns into build work.
   Use 5-Whys where useful. Is "more gates" part of the problem?
2. **The GO → build gap (E2).** What mechanism should guarantee that a GO'd design gets fully built, or explicitly descoped by the operator, and never silently left half-done?
3. **The handoff (E1).** How should a decision handoff be designed so an agent cannot hand the operator a decision the framework already knows is not decidable? Consider exit codes, a single readiness API, making Watchtower itself refuse to show the GO button, and removing the agent from URL construction.
4. **Ranked fixes.** Give at most 8, ranked by impact/cost. For each: what changes, which current gate it replaces, merges or removes, and how its success is measured.
5. **What you would remove.** Which gates or steps cost more than they catch?

Format:
- start with `VERDICT: <one-line root cause>`;
- then sections 1-5, at most 1,200 words in total;
- cite the evidence IDs (E1-E5) for every claim;
- say "insufficient evidence" where it applies, and name what would settle it.
