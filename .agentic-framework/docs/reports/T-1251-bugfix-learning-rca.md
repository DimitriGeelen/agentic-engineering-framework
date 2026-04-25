# T-1251 — RCA: Bugfix-learning coverage stuck at 0%

**Task:** T-1251
**Type:** Inception (research artifact per C-001)
**Created:** 2026-04-14

## Problem

Audit reports `[FAIL] Bugfix-learning coverage: 0% (1/242)`. T-1178 (inception) and
T-1192 (build, shipped as enhanced bugfix-learning prompt + audit escalation) did not
move the needle. Why?

## Context from prior work

- T-1178: inception — structural bugfix-learning enforcement
- T-1192: build — enhanced bugfix-learning prompt + audit escalation (G-016)
- CLAUDE.md "Bug-Fix Learning Checkpoint": defines *field-discovered* as trigger
- audit.sh:952-990: `fix|bugfix|hotfix|RCA|G-[0-9]` regex against all completed task names

## Spikes

### Spike A — T-1178/T-1192 remediation reconstruction — DONE

T-1192 shipped (per `.context/episodic/T-1192.yaml`):
1. **Enhanced learning prompt** in `agents/task-create/update-task.sh:880-887`:
   bordered yellow box, pre-filled `fw fix-learned` command, guidance questions
2. **Audit FAIL escalation** when coverage < 10% (`agents/audit/audit.sh:982-986`)

Both remediations are **advisory** — they display text but don't block completion.
Agents can ignore them with zero consequence.

### Spike B — Sample classification — DONE (via T-1252 data)

T-1252's bulk classifier showed 66% of 242 "fix" tasks are dev-discovered, not
field bugs. So ~80 tasks legitimately skip learning capture, inflating FAIL.

For the other 34% (~83 field bugs), only 1 has a learning. That's the real
capture gap: **~82 field bugs without learnings**.

### Spike C — Prompt behavior — DONE

The prompt at `update-task.sh:862-889`:
1. Detects bugfix via same broad regex (`fix|bugfix|hotfix|RCA|G-[0-9]`)
2. Checks if learnings.yaml references the task ID
3. Prints yellow boxed advisory — no blocking, no retry, no enforcement

Observed in this session: prompt fired after T-1250 completion, agent (me)
happened to run `fw fix-learned` because autonomous discipline was primed.
In typical sessions under time pressure, the prompt is visually noisy but
easy to ignore.

### Spike D — False-positive rate — DONE (via T-1252 data)

See T-1252: denominator is inflated 2-3x by dev-discovered matches. True
field-bug denominator is ~83.

## Findings

1. **Prior remediation was purely advisory** — T-1192 added visual polish but
   no structural enforcement. Agents remain free to ignore the prompt.
2. **Coverage problem is real** even after narrowing denominator (~1/83 = 1.2%)
3. **Capture cost is high**: agent must synthesize a one-sentence learning,
   choose source code (P-001/D1/etc.), and remember the command syntax
4. **No auto-draft support**: the commit message often contains the learning
   already ("fixed X because Y") but nothing extracts it
5. **No opt-out mechanism**: there's no way to say "this is not learning-worthy";
   the audit always counts these as missing

## Recommendation

**Recommendation:** GO — two-part structural fix

**Rationale:** Advisory prompts proven insufficient. Need (a) auto-draft to reduce
capture cost and (b) explicit opt-out so the audit can distinguish "skipped" from
"not applicable".

**Proposed structural changes:**
1. **Auto-draft learning on completion**: parse the latest commit message for the
   task, propose a learning draft, agent confirms or edits
2. **Explicit opt-out flag**: `fw task update T-XXX --status work-completed --no-learning --reason "dev cleanup"` — logged, exempts task from coverage denominator
3. **Narrow the denominator** (see T-1252 — parallel inception)

**Evidence:**
- T-1192 episodic confirms advisory-only shipping
- Visible friction: `fw fix-learned` requires synthesizing one-sentence learning
- Opt-out mechanism exists for other gates (--force, --skip-acceptance-criteria)

**Next step if GO:** Create `T-1256-build: auto-draft bugfix learning + --no-learning opt-out flag`

**Complementary to:** T-1252 (detection quality — narrow denominator)
## Dialogue Log

### 2026-04-14 — Triage context

User asked for bugfix inception tasks after audit showed `[FAIL] Bugfix-learning
coverage: 0% (1/242)`. Two separate inceptions created per "one inception = one
question": T-1251 (capture-side — why agents skip) and T-1252 (detection-side —
why denominator is wrong). This is T-1251.


## Dialogue Log

<!-- Human-agent conversation notes. Capture WHY decisions evolved, not just WHAT. -->
