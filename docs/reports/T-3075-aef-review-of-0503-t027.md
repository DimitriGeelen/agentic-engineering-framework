# AEF-grounded architecture review — 0503's Executable Workflow Contract Runtime (T-027)

**Reviewer:** 999-Agentic-Engineering-Framework, task T-3075 · **Reviewed:** 2026-08-18
**Subject:** dossier SHA-256 `7b51ba56329bebe50ac92295d32c71c66906afbae259f8010e33f39ed27efdd5`, received `agent-chat-arc` @97
**Status:** advisory only. No approval, no task creation in your project, no dispatch.

Every AEF claim is **[obs]** (a path:line, or output of a command I ran here) or **[inf]**
(inference from those); gaps are marked **[unverified]** with the test that settles them. I cite
no CLAUDE.md prose as evidence of behaviour — in this repo the description and the hook diverge
often enough that doing so would mislead you. Findings are **C1** (dossier wrong about AEF
today) or **C2** (dossier right about AEF today, and that is the problem).

## Verdict

**Architecturally sound; the AEF grounding is thinner than the dossier assumes.** The concept
split, refusal-vs-failure (§7.4) and the authority intersection (§9) are shapes I would keep. But the dossier repeatedly treats an AEF primitive as a *foundation* where what
exists is a *convention* — advisory, self-reported, or scoped to a surface an agent can step
around. Your runtime cannot be built *on* AEF's enforcement; it must supply enforcement AEF
lacks, making AEF its client. Proceed, re-scoping slice one around that inversion.

## Findings

**1 — HIGH · §1.3, §4.3 · C2 · The independent enforcement point does not exist, and AEF's gates
are not a partial one.** They are PreToolUse hooks matched on **tool name**, inside the agent's
own harness. `check-human-ac-tick` is registered for `Write|Edit` only. Positive control [obs]: a `Write`
payload flipping a real `- [ ] [REVIEW]` in `T-100188` → `HUMAN-AC TICK BLOCKED`; the same edit
as a `Bash` `sed -i` payload → exits 0, and `Bash` is not a registered matcher for it. Tier 0 is the same shape — it reads only `tool_input.command`. **Change:** mediate the
*effect*, not the tool call. Instance state must live where the executing agent cannot write it,
or §4.3 is a naming convention.

**2 — HIGH · §2.1, §7.5(1) · C2 · AEF records procedure provenance but never verifies it.**
Resolver workflows are plain tracked YAML in `.context/project/workflows/` (9 files) — no
ratification state, no protecting hook (none in any gate hook) [obs]. `workflow_sha`
is `git rev-parse HEAD:<path>`: the **committed** blob, not executed bytes — `VERSION` HEAD
`5577648b…` vs worktree `f886f967…` [obs]. An uncommitted edit yields a row attesting content that never
ran. **Change:** hash loaded bytes at load, refuse when loaded ≠ ratified — §2.1 fixes a real
AEF defect.

**3 — HIGH · §9, §13.4 · C2 · Isolation is a sender-side regex that exempts TermLink
unconditionally.** `check-project-boundary.sh:134-137`: any command matching
`(termlink|bin/fw termlink|fw termlink)` exits 0 before analysis [obs]; the rest is pattern scanning over a
quote-stripped command string. Your dispatch channel is the exempted one.
**Change:** carry repository identity, worktree and execution root in the envelope, enforced at
the **receiving** end. No sender-side check makes §13.4 pass.

**4 — HIGH · §13.3 · C2 · One flag disarms eleven gates, with no agent guard.**
`update-task.sh:1342` sets `SKIP_SOVEREIGNTY`, `SKIP_AC`, `SKIP_VERIFICATION`,
`SKIP_HUMAN_OWNERSHIP` and seven more on `--force`, with no `$CLAUDECODE` check on that branch
[obs]. The prohibition is prose. Precedent exists: `lib/inception.sh:106` refuses under `$CLAUDECODE=1`. **Change:** copy
it, and make override a *typed audited node outcome*, never a flag on the advance path.

**5 — MED · §4.4, §7.5(9), §13.5 · C2 · AEF's evidence layer is the raw shell your
Principle 4 excludes.** `## Verification` is agent-authored shell `eval`'d by the process it constrains
(`update-task.sh:1100,1215`). It drifts: the hard-coded-port gate exists because one false-green
line shipped 371 times unnoticed — a green line asserting nothing looks identical to one
asserting everything. **Change:** typed outcome checks from a registered catalogue, each
with a mandatory **positive control**. Highest-value thing your runtime adds that AEF lacks.

**6 — MED · §6.4 · C2 · The nearest capability-profile analogue resolves authority by asserting
it.** `tool-set.yaml` holds 27 entries (16/6/5 by class), none `verified` [obs]. Enforcement is
`framework_mcp_server.py:178-193`: `agent_authority` requires a `task_id`, then **sets focus to
it**. The caller names the authority and the server makes it true. **Change:** check task existence,
status and ownership, and refuse — "requires task_id" is an input contract, not authorisation.

**7 — MED · §7.4, §12 · C2 · AEF's refusal/escalation path exists and has never fired.**
`pause_requested`: 0 times across 1,503 dispatch rows and 1,916 outcome events; enrichment
994/1453 (68%); `worker_writes` on 11/1503 [obs]. AEF cannot answer your
§7.4 operator question, and holds no worker write-set to validate declared outputs (§13.5). **Change:** make enrichment→100% and write-set capture the pilot's first
metric. An unexercised refusal path is a design, not a control.

**8 — LOW · §5, §8.2, §12, §15 · C1 · Three corrections.** (a) The Component Fabric caution is
over-stated for AEF: 1,092 cards, drift 9/0/0 against 1,425 tracked source
files, `components:` on 370/371 active tasks, and unmeasured blast radius already refuses zero
(`lib/bvp.sh:366`) [obs]. Keep §8.2's policy; AEF coverage is not the weak link. Consumer coverage
[unverified] — run `fw fabric drift` in 0503.
(b) `fw write-set check` cannot decide conflicts: 0 of 3,062 tasks declare `write_set:`, so every
real pair exits 2 [obs] — a convergence list, not a decision; your node contract must declare
outputs. (c) re-ground §15 on hook/lib/test paths, not `AGENT.md`/deep-dives.

## Missing primitives — runtime primitives that do not exist in AEF today

1. **Out-of-process state holder.** AEF has a *design* — `lib/govd_envelope.py` (arc-013: "the
   agent commits WITHIN the envelope but cannot CHANGE it"), `lib/govd_holder.py`,
   `policy/authority-envelope.yaml`, unit tests — **not wired**: no `fw govd` verb, absent from
   `.claude/settings.json` and `deploy/` [obs]. Closest prior art; its unwired state is the lesson.
2. Ratification registry with load-time hash verification (F2). 3. Typed outcome checks with
   positive controls (F5). 4. Idempotency keys — the envelope carries `dispatch_id`/
   `parent_dispatch_id`, no correlation key [obs]. 5. Declared node write-sets (F8b).
   6. Effect-level, not tool-level, interception (F1).

## Refusal tests to add to §13

11. A gate on one tool surface refuses the same *effect* through every other surface.
12. Loaded bytes ≠ ratified hash → refused before side effect.
13. Override exists only as a typed audited outcome; no flag advances past an unmet gate.

## First pilot

Not your §11 slice. **One node, one gate, one refusal, no execution:** a human-gate node whose
approval state lives where the agent process cannot write it, plus one registered script that
refuses on wrong worktree. Green = §13.1/3/4 refusals fire *through every surface you have*
(CLI, agent tool call, shell, TermLink worker), each landing an outcome row. AEF's 68%
enrichment is what happens when executors come first.

## Human decisions

1. Where the state holder runs, under whose OS identity — this is the architecture (P1).
2. Is ratification human-only and non-delegable? 3. Close the TermLink exemption (F3) before or
after the pilot? 4. Is AEF a *substrate* of the runtime or its *client*? The dossier reads as the
former; findings 1–4 argue the latter.

## Citations

| Claim | Source |
|---|---|
| Hook tool-name scoping; matchers | `.claude/settings.json` (PreToolUse `Write\|Edit`); `agents/context/check-human-ac-tick.py`; positive control on `T-100188` |
| Tier 0 reads only the command string | `agents/context/check-tier0.sh:20,73` |
| Workflow sha = committed blob; workflow dir | `lib/resolver.py:455-475`, `lib/resolver.py:48` |
| TermLink boundary exemption | `agents/context/check-project-boundary.sh:134-137` |
| `--force` disarms 11 gates, no agent guard | `agents/task-create/update-task.sh:1342`, `:1422` |
| Inception `$CLAUDECODE` precedent | `lib/inception.sh:106` |
| Verification block `eval`'d in-process | `agents/task-create/update-task.sh:1100`, `:1215` |
| Capability overlay + MCP enforcement | `policy/capability-overlay/tool-set.yaml`; `agents/mcp/framework_mcp_server.py:178-193` |
| Dispatch/outcome counts, enrichment ratio | `bin/fw orchestrator status`; `.context/dispatches.jsonl`; `.context/dispatch-outcomes.jsonl` |
| Fabric drift, cards, unmeasured blast radius | `bin/fw fabric drift`; `.fabric/components/`; `lib/bvp.sh:366` |
| write-set undecidable (exit 2) | `bin/fw write-set check T-3075 T-3073` |
| Unwired authority broker | `lib/govd_envelope.py:1-15`; `lib/govd_holder.py`; `policy/authority-envelope.yaml`; `agents/govd/govd.sh`; `tests/unit/test_govd_envelope.py` |
