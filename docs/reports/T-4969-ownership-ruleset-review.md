# T-4969 — ownership hand-over and the ownership ruleset: external review

**Date:** 2026-11-01
**Asked by:** the operator ("Get external review on this").
**Seats:** codex (`consult-t4969-codex-54c28e9f4bf0`) and opencode (`consult-t4969-opencode-084272d0ff98`). Both are internal-cost subscriptions; cost is logged. They ran as read-only review dispatches with the same brief. The brief gave no host detail.

## What was put to them

- **Current rules:**
  - the operator may change ownership in any direction (intended, but broken today);
  - an agent may move a task agent → human freely;
  - an agent may not move it human → agent (R-033, bypass `--skip-human-ownership`, logged);
  - the verdict ledger moves it human → agent on independent review (D-626);
  - task creation sets promoted tasks to `human`; a risk-assessed owner is pending in T-4371.
- **The bug:** the Watchtower owner field and the printed promote hint are refused by R-033.
- **Proposal:**
  1. The owner change accepts `--from-watchtower` / `--i-am-human`, like the other operator-only actions, and every hand-over is logged.
  2. One rule table for every ownership change, with evidence per row.

## codex

- **(a) Step 1** is sound as a usability repair within the threat model. An agent can already type today's bypass, so the new flags do not materially widen anything. But neither flag *authenticates* an operator: both are assertions the same OS user can make. Log "claimed operator authority via flag" distinctly from a verified operator action, and do not treat the convention as stronger than it is.
- **(b) Table:**
  - Operator either way: explicit intent; record channel, old/new value and identity (asserted or verified).
  - Agent → human: free, with actor and reason.
  - Human → agent: only on independent review covering every applicable human criterion, with provenance and evidence bound to the task revision.
  - The ledger: the same requirement, with the executing service named apart from the reviewers.
  - Creation: record the rule, its inputs and the policy version; promoted tasks stay human unless explicitly superseded.
  - Overrides: a separately classified exception with a rationale.
  - The agent's own tests or confidence never discharge a human obligation; any alternative must be an explicit operator delegation.
  - Escalation (agent → human) stays unconditional; monitor repeats without blocking them.
- **(c) Audit:**
  - Every owner change, including direct edits, creation, deletion/recreation, renames and changes bundled with a close.
  - Rebuild prior state and evaluate the recorded rule against the policy in force then.
  - Check evidence, independence, provenance and revision binding, and that the change came before closure.
  - Git history cannot reveal forgery by someone who can rewrite history and evidence; stronger detection needs a protected event store or external checkpoints. Say so.
- **(d) Biggest weakness:** independent *agent* review can discharge ownership that reads as requiring *operator* verification. Decide whether `human` means mandatory human sign-off or a review gate with delegated alternatives, and encode that explicitly. Then fix the misleading operator attribution and fold the existing bypass into the same auditable override rule. The creation-time assessment must not become a route around mandatory human review.

## opencode

- **(a) Step 1** is sound and no wider than today: any caller can pass the bypass now and is merely logged. Step 1 refuses agent contexts and records a named assertion, which is strictly better attribution. Conditions:
  - deprecate `--skip-human-ownership`, or make it log identically, so one gate remains;
  - when agent environment variables are set, require an interactive (tty) confirmation for `--i-am-human`, so non-interactive agents fail;
  - `--from-watchtower` differs from `--i-am-human` only if it is verifiable: the web path has CSRF and a server-side record, so check the claim against Watchtower's own log, and refuse it on the CLI outside a verified Watchtower origin.
- **(b) Table:**
  - Rows: operator either way; agent → human; agent human → agent; ledger; creation/promotion.
  - Human → agent only on independent review ("anything weaker lets an agent grade its own homework"). Bind each verdict to the task version it reviewed, so it cannot be replayed after later edits, and require signer ≠ actor.
  - The creation-time assessment is acceptable only because no human oversight exists yet, and it must default to human on ambiguity.
  - Agent → human stays unconditional but needs a reason, so the audit can tell escalation from offloading.
- **(c) Audit:** reconcile every `owner` diff in git with a log line (actor, mechanism) and the rule that allowed it. For human → agent, also require a green verdict whose provenance verifies and whose reviewed commit has no later task-touching commit without a newer verdict. Flag:
  - owner diffs with no matching log event (direct-edit forgery);
  - closures of human-owned tasks with no operator or hand-over record;
  - stale or reused verdicts;
  - `--from-watchtower` claims absent from Watchtower's own log;
  - `--i-am-human` from contexts carrying agent environment variables.
- **(d) Fix first:** the broken operator path. It pushes operators through the agent bypass, which normalizes bypass use and destroys attribution. Then: the stale-verdict replay risk, the failing printed hint, and the creation-time assessment, which is gameable at birth (use independent inputs, default to human).

## Synthesis

**Agreement:**
- Step 1 is sound and should come first.
- The flags are *claims*, not proof, and the log must say so.
- Human → agent only on independent review, bound to the reviewed version.
- Agent → human stays unconditional, with a reason.
- The audit must reconcile every `owner` change in git history with a log line and the rule that allowed it.

**Refinements to step 1 that both support:**
1. **One gate:** `--skip-human-ownership` either goes, or logs exactly like the new path, so there are not two doors.
2. **Watchtower's claim checked:** Watchtower writes its own server-side record of the change, and the CLI refuses `--from-watchtower` unless that record exists (opencode). Otherwise the flag is `--i-am-human` in disguise.
3. **`--i-am-human` under an agent environment** needs an interactive confirmation, so a non-interactive agent fails (opencode).
4. **Log wording:** "operator asserted via flag" versus "operator via Watchtower session (verified)" (codex).

**Points for the operator (step 2):**
- codex's question (d): does `owner: human` mean *mandatory human sign-off*, or *a review gate that independent review may discharge*? D-626 (operator ruling 2026-09-23) already chose the second for reviewer-judged criteria, while tier-0, act-in-the-world and sovereignty criteria stay human (T-3557). The rule table should state that split explicitly.
- Revision binding (opencode): the ledger already ties a verdict to the criterion's digest and revalidates it at every close. Whether it also ties it to the task revision is to be checked in step 2, not assumed.
- Creation-time ownership (T-4371): both seats require independent inputs and a default of human.

## Code review of the built change (operator: "test cases and an external review")

Both seats got the diff (`0e701b394`, without author detail) and were asked for agent attack cases, which of them the change stops, and defects. Dispatches: `codereview-t4969-codex-e32842382101`, `codereview-t4969-opencode-873fc5079392`.

**Agreed findings, all fixed:**
1. **The log overclaimed.** "watchtower (record verified)" and "confirmed interactively" are forgeable by the same OS user: write the record, or drive a pty with `script`/`expect`. Both now read "... claimed" (`watchtower (record present, claimed)`, `operator CLI (--i-am-human, tty confirmation in an agent environment, claimed)`).
2. **A symlinked record was followed.** It is now refused, and Watchtower writes its record through a temp file and `os.replace`, so a planted link is replaced, never followed.
3. **Validate-then-delete was not atomic**, so two consumers could both pass. The record is now claimed with an atomic rename before it is read.
4. **A failed log append was ignored**, yet the output still said "logged". The hand-over is now refused, owner unchanged, when the line cannot be written.
5. **No task-id guard** before the id was used in a path in `update-task.sh`. The gate now requires `^T-[0-9]+$` first.
6. The record's `by: watchtower` field is now checked, and non-finite or future timestamps are refused.

**Not a defect:** both seats flagged `_escape` as undefined; it is defined at `web/blueprints/tasks.py:34` (T-2222).

**Limits that remain, by design, and are logged honestly:** an agent that writes the record itself, unsets `CLAUDECODE`, or drives a pty gets through, and the log says "claimed". That is the stated threat model: stopping accidents and unsophisticated attempts, plus honest logging, not forgery resistance. It is the same residual T-3581 names for the verdict ledger. The general rule table and its after-the-fact audit (reconcile every owner diff in git with a log line) are T-4371 IW-4.

**Attack cases now pinned in `tests/unit/t4969_owner_handover.bats`** (16 tests):
- an agent-written record (logged as claimed, never "verified");
- a symlinked record (refused, link target survives);
- malformed records (`[]`, `null`, broken JSON, NaN, Infinity, future ts, missing `by`, wrong-case owner);
- piped confirmation (refused);
- pty-driven confirmation (logged as claimed);
- two concurrent consumers (consumed once);
- unwritable log (refused, owner unchanged);
- the task-id guard.
