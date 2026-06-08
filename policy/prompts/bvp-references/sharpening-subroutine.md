# Sharpening Subroutine

The shared subroutine that Workflows B (suggest) and C (create) converge on after the operator picks a candidate (or names one). Workflow A (batch-propose) does NOT run sharpening — its output is candidates with one-line rationales only.

Sharpening covers six dimensions. Two are **required** (R1, R2). Four are **optional** (O1, O2, O3, O4) and only get drilled when the operator engages.

The whole subroutine is **skip-when-stuck**: if any dimension produces three rounds of dialogue without convergence, ship what you have and surface the open question. Driver sessions are proposals, not gates.

## R1 — Differentiation (required)

**The question:** "What does this driver distinguish that the existing drivers do not?"

**Why it's required:** If you cannot articulate one sentence answering this question, the candidate is not a real driver — it overlaps with something already in scope. The four constitutional directives (D1 Antifragility, D2 Reliability, D3 Usability, D4 Portability) are wide; a meaningful free or arc-scoped driver carves a slice they don't address.

**Prompt shape:**

```
Agent: "What does <driver-name> capture that D1–D4 (or existing free drivers, or this arc's existing scoped drivers) don't?"
Operator: <answer>
Agent: <test the answer — propose a borderline example and ask "does <driver> dominate here, or does <existing> dominate?">
```

**Convergence test:** the operator names a kind of work that this driver scores high on AND that an existing driver would NOT distinguish. If they can't, R1 hasn't converged. Skip-after-three.

**Common failure:** operator names a driver that's really "more X" of an existing dimension. e.g. "robustness" vs D1 Antifragility — usually the same thing said differently. Surface the overlap and ask the operator to either kill the candidate or sharpen the distinction. Don't ship overlapping drivers.

**Worked failure pattern:** if R1's answer is "this is about reliability" → D2 already does that. Kill the candidate. See `discipline-failure-modes.md` "overlap with directives".

## R2 — Weight Calibration (required)

**The question:** "Where on the weight scale does this sit, and why?"

**Scale:** 1–9 for global free drivers, 1–6 for arc-scoped drivers.

**Anchoring rule:** always anchor to an existing driver. "Heavier than D3 because <X>; lighter than D1 because <Y>." Bare numerical weights without anchors are anchoring failures — the operator picks a comfortable number and the driver doesn't actually reflect priority.

**Prompt shape:**

```
Agent: "Where on 1–9 (or 1–6) does <driver> sit? Anchor to an existing driver."
Operator: <answer with anchor>
Agent: <if no anchor: re-ask with anchor. if anchor exists: test it — propose a task this driver would score 5 on, and ask whether it should rank above or below tasks dominated by the anchor>
```

**Convergence test:** the operator's weight is anchored, AND the operator can predict the relative ranking of a sample 5-task pair (one dominated by the new driver, one by the anchor). Skip-after-three.

**Common failure:** operator gives a round number (5, 6, 7) without anchor. Re-ask once. If still anchorless, accept the number and surface it as an `[OPEN]` for future calibration — don't manufacture an anchor.

**Asymmetry note:** arc-scoped drivers cap at 6, not 9. The cap is structural — 6 is the maximum weight an arc-scoped driver can carry. Don't propose weights above 6 in arc-scoped context; the handler will reject.

## O1 — Edge Cases (optional, drill when engaged)

**The question:** "What's a 0? What's a 5? What's a 2 that could be argued as a 3?"

**Why optional:** edge cases sharpen the rubric. If the operator engages, drill — the artefact's scoring rubric (the 0–5 lines per level) lands directly from this dialogue.

**Prompt shape:**

```
Agent: "Give me a concrete task that would score 0 on <driver>."
Operator: <example>
Agent: "And one that would score 5."
Operator: <example>
Agent: "Now a 2 — and tell me what would have to change to make it a 3."
Operator: <example>
```

**Convergence test:** the operator can name examples at each end of the scale AND can articulate the 2→3 boundary. If they can't articulate the boundary, the rubric isn't ready — write what they gave you and mark the boundary `[OPEN]`.

**Skip cue:** operator says "I don't know, just put something reasonable." Take that at face value — write a plausible rubric, mark it `[OPEN]` for future iteration.

## O2 — Scope Test (optional)

**The question:** "What kinds of work would this driver dominate? What would it correctly leave alone?"

**Why useful:** scope-tests catch drivers that are too broad (dominate everything → low signal) or too narrow (dominate nothing → noise). A good driver dominates a clearly-shaped subset of work.

**Prompt shape:**

```
Agent: "Walk me through 3 recent tasks. Which would this driver dominate?"
Operator: <walks through>
Agent: <if all 3 dominated: too broad, sharpen. If 0 of 3 dominated: too narrow, sharpen. If 1–2 of 3: good.>
```

**Convergence test:** 1–2 of 3 recent tasks dominated. Skip-when-stuck if recent tasks don't have BVP scores yet (likely on a fresh `fw bvp driver --init`).

## O3 — Overlap Test (optional)

**The question:** "Pick the existing driver closest in spirit. How does <new driver> differ?"

**Why useful:** sharpens R1. The overlap test forces the operator to engage with the existing driver vocabulary, which catches "this is really just X said differently".

**Prompt shape:**

```
Agent: "Of D1–D4 (and any existing free drivers), which one is closest in spirit to <new driver>?"
Operator: <picks>
Agent: "Now articulate the difference. If a future task scores high on both, what does that mean operationally?"
Operator: <articulates>
```

**Convergence test:** the operator articulates a meaningful operational consequence of the difference. If "high on both means roughly the same thing" → overlap is too tight; circle back to R1.

## O4 — 0–5 Scoring Rubric (optional for arc-scoped, required for global)

**The question:** "One sentence per level (0, 1, 2, 3, 4, 5). What does each look like?"

**Why required for global:** global free drivers persist across the project; tasks score against them indefinitely. A rubric makes scoring repeatable across agents and time. Without it, scoring drifts.

**Why optional for arc-scoped:** arc-scoped drivers are local and short-lived (arc duration). Rubric overhead may exceed value. Drill if the operator wants; skip if they don't.

**Prompt shape:**

```
Agent: "Walk me through 0 to 5. What's a 0? A 1? A 2? A 3? A 4? A 5?"
Operator: <walks through>
Agent: <if any level is identical to the next: ask "what would have to change to bump that from N to N+1?">
```

**Convergence test:** every adjacent pair (0↔1, 1↔2, …, 4↔5) has a distinguishing criterion. If two adjacent levels collapse, the rubric has fewer than 6 effective levels — write what you have and mark the collapsed pair `[OPEN]`.

**Output format** (written into the driver YAML):

```yaml
scoring_rubric:
  "0": <one sentence>
  "1": <one sentence>
  "2": <one sentence>
  "3": <one sentence>
  "4": <one sentence>
  "5": <one sentence>
```

## Dimension ordering

Always run in order: R1, R2, O1, O2, O3, O4. Don't reorder.

Reason: R1 (differentiation) gates everything else. If R1 fails, the candidate dies — no point drilling O1–O4 on a candidate that'll be killed. R2 (weight) is meaningful only if R1 converged. The Os refine; they don't gate.

## Skip-when-stuck mechanics

For each dimension:

1. Ask the dimension's primary question
2. If the operator's answer doesn't converge: drill once with a test prompt (the "test the answer" step shown above)
3. If still no convergence: drill once more with a borderline example
4. After three total rounds: write what you have, mark `[OPEN]`, move on

Don't death-march. Driver sessions are proposals. The operator can iterate via `fw bvp driver edit` later. Sharpening that drags past three rounds destroys the operator's interpretive bandwidth — the cost of "perfect" sharpening exceeds the value.

## Tactical moves

See `sharpening-tactics.md` for the conversational moves used inside each dimension:

- How to surface unstated assumptions
- How to drill scope without leading
- How to elicit weight calibration without anchoring on a number first
- How to recover from operator frustration ("just put something")
- How to recognise when the operator has converged but doesn't realise it

## What this subroutine does NOT do

- **Does not propose candidates.** Workflows B and C handle that.
- **Does not write YAML.** The handler does that after the session.
- **Does not enforce dimensions.** Skip-when-stuck respects operator bandwidth. The artefact reflects whatever was actually drilled.
- **Does not validate that the operator's answers are "correct".** Operator sovereignty applies — if the operator says "weight is 7 because reasons", that's the weight. Surface concerns honestly but don't refuse to write what they asked for.
