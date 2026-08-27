# Landing Mode — the "stop finding, start landing" prompt (v2)

**Status:** operator-issued directive, codified T-3201. v1 lived only in chat and
had to be reconstructed from scratch when the operator asked a second time. This
file is the durable copy — paste §The Prompt, or say "run landing mode".

**Origin:** the operator's own words, twice: *"stop finding, start landing … and
push it all the way through to success."*

---

## Why v2 differs from v1

v1 was run once. It landed three tasks and **filed six new ones**. The directive
was violated by the agent's own filing rate — every genuine defect found while
landing became a new ticket, which is finding, not landing. v2 puts a budget on
that.

Three other things the v1 run measured, each now a rule below:

| What happened | Rule it produced |
|---|---|
| Two test suites shipped green while asserting nothing; only mutation testing caught it | **M** — no suite counts as evidence until a mutation has reddened it |
| A verification line used `--dry-run`, a flag `update-task.sh` does not have. It exited 0 having done nothing and was nearly reported as a passing gate | **V** — verify the flag exists before trusting the exit code |
| The render-surface gate fired twice on false positives; both closes spent a Tier-2 bypass | **B** — a bypass is a finding, not a workaround |

---

## Two premises in the directive that do not currently hold

State these back rather than silently substituting something else.

1. **"check hv/hc & hv/lc tasks"** — `fw bvp --quadrant hv-hc` and `hv-lc` both
   return *"No tasks have `bvp_scores:` set yet"*. Quadrant selection is dead
   until T-3184's GO ships. **Fallback: select by arc**, and say so.
2. **"communicate with other agents over TermLink frequently"** — `termlink agent
   peers` shows exactly one participant on the chat arc, which is this session's
   own fingerprint. The other sessions are 7-day-old task workers in other
   projects. **There is nobody to talk to.** Use TermLink for *dispatch* where it
   earns its place (§D), and report the absence rather than manufacturing chatter.

If either premise changes, this section is what should be deleted first.

---

## The Prompt

> **Landing mode.** Stop finding, start landing — push the current arc all the
> way through to success.
>
> **Scope:** the release-train branch model and the `claude-fw` continuous-run
> loop. Work the arc, not the backlog.
>
> **Before starting:** read the inbox (`termlink agent unread`, `fw note` queue,
> `fw pause list`). Report what is there, including "nothing", before doing
> anything else.
>
> **Selection:** try `fw bvp --quadrant hv-hc` then `hv-lc`. If they return
> nothing, say so plainly and select by arc instead — do not quietly substitute
> your own ranking and present it as the quadrant's.
>
> **Landing means closed, verified, committed, pushed, 0 unpushed.** A task that
> is "done except for the push" is not landed. Check `AUDIT-SCOPE: fails=0` on
> every push and do not report success on a piped exit code.
>
> **Filing budget: at most 2 new tasks per task landed.** If you exceed it, stop
> and tell me what you are finding instead of filing more. A defect discovered
> while landing is either (a) small enough to fix in the same commit, (b) a
> genuine blocker — say so and stop, or (c) a filing, which costs budget.
>
> **Every test you write must be mutation-tested before you call it evidence.**
> Break the thing it covers; if nothing reddens, the test asserts nothing. Say
> which mutation reddened which test.
>
> **Every bypass is a finding.** If a gate fires and you bypass it, the rationale
> must name why the gate was wrong, not why you were in a hurry — and that goes
> in the register, not just the flag.
>
> **Operator actions:** surface them to `/approvals` and print the link to the
> *specific* approval. Generate links with `fw task review-batch`, never by hand,
> and **curl every URL for a 200 before printing it**.
>
> **Check in after every commit.** Do not chain landings silently.
>
> **Stop at 85% context** and hand over. Do not start a task you cannot finish.

---

## Operator notes (not part of the pasted prompt)

**§D — where TermLink earns its place.** Not for chatter. Dispatch a worker when
the work is *specified* (you can write scope, deliverable, output format and
constraints without first doing the work) and it is a static scan over finished
work — `fw reviewer T-XXX --dispatch` is the canonical shape. Never dispatch an
exploration; measured 0/122 pass rate on inception dispatches.

**On the filing budget.** The budget is not a claim that filings are bad — the
v1 run's six filings included two verified defects that were worth having. It is
a claim that *the ratio is the signal*. Filing three tickets per task landed
means the session found more than it fixed, which is the state the directive was
issued to end. When you hit the budget, that is information for the operator, not
an error to route around.

**On stopping.** The last line is the one most likely to be violated, because
landing mode creates momentum and the budget gauge is the only thing that
disagrees with it. A run that ends at 85% with a clean handover beats a run that
ends at 97% with uncommitted work — the v1 run finished its last piece at 90%
and had nothing left for the next one.
