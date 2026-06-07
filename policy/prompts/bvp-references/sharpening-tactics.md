# Sharpening Tactics

Tactical conversation moves used inside the sharpening subroutine. The subroutine (`sharpening-subroutine.md`) defines *what* to ask (R1, R2, O1–O4); this file documents *how* to ask in ways that produce useful answers.

These are tactics, not scripts — pick what fits the operator's current state.

## Surfacing unstated assumptions

**When to use:** the operator's answer is short or generic, and you suspect they're carrying context you don't have.

**Move:** propose a borderline example and ask which way it goes.

```
Operator: "Weight should be 5, this is moderately important."
Agent: "Take T-XXXX (something the operator recently worked on). Would this driver score it higher than D3 Usability scores it?"
Operator: "Hmm, no actually — D3 should still rank it higher because <reason>."
Agent: "Then this driver's weight should be < D3's weight. D3 is 5, so this should be <5. Where on 1-4?"
```

The borderline example forces the operator to engage with the consequence of the weight, not just the number.

**Why this works:** weight calibration without anchors is anchoring on cognitive availability. The borderline example replaces availability with concrete consequence.

## Drilling scope without leading

**When to use:** O2 (scope test). The operator gives a generic scope answer ("dev tooling work") that could mean anything.

**Move:** ask for 3 recent tasks and walk through them one at a time.

```
Agent: "Pick the 3 most recent tasks from `fw task list`. Walk me through them — for each one, would this driver dominate the BVP score?"
Operator: "T-A would. T-B wouldn't. T-C... maybe?"
Agent: "For T-C: what feature of T-C makes it ambiguous?"
```

The 3-task walk-through grounds the scope discussion in concrete evidence the operator can point at, instead of abstract category-defining.

**Anti-pattern to avoid:** asking the operator to invent hypothetical tasks. They'll invent tasks that fit whatever scope they're currently advocating. Real tasks they didn't pick force honest answers.

## Eliciting weight without anchoring

**When to use:** R2 (weight calibration). The operator hasn't engaged with the weight scale yet, and you're about to ask "what weight should this be?". That phrasing produces round numbers without anchors.

**Move:** ask the comparison first, derive the weight second.

```
Bad: "What weight should <name> have on 1-9?"
Better: "Compared to D2 Reliability (weight 7) and D3 Usability (weight 5), is <name> higher than D3, between D2 and D3, or higher than D2?"
```

The first form anchors on numbers; the second anchors on rivals. Rival-anchoring produces honest weight answers because the operator has to defend ranking, not pick a comfortable digit.

After the operator picks a band, you can ask "where in that band — closer to D3 or closer to D2?" to get the integer.

## Recovering from operator frustration

**When to use:** the operator has stopped engaging, gives one-word answers, or says "just put something reasonable / I don't care / ship it".

**Move:** acknowledge the bandwidth limit, write the spec with what you have, mark `[OPEN]` where you skipped.

```
Agent: "OK — I'll ship the spec with R1 and R2 only; O3 and O4 marked OPEN. You can iterate later via `fw bvp driver edit`. Confirm?"
Operator: "Yes."
```

Do NOT push through frustration. The subroutine's skip-when-stuck rule exists exactly for this. Driver sessions are not gates; the operator's bandwidth IS the budget.

**Anti-pattern to avoid:** "just one more question" — that's how you turn a 3-round sharpening into a 7-round session and burn the operator's trust in the discipline.

## Recognising convergence the operator hasn't named

**When to use:** the operator's answers across 2–3 turns have been consistent on a dimension, but they haven't explicitly said "yes, that's it". You're about to keep drilling and produce friction.

**Move:** name the convergence yourself and ask for confirmation.

```
Agent: "I think we've converged on R1: <name> distinguishes work where <X> matters, which D1–D4 don't isolate. Confirm and move to R2?"
Operator: "Yes, move on."
```

The named convergence is a tiny commitment cost (one "yes") vs. continued drilling (multi-turn engagement). It accelerates the session without bypassing operator sovereignty.

**Anti-pattern to avoid:** silently moving on without confirmation. The operator may have been on autopilot; surface the move so they can correct if needed.

## Catching the "this is really just Y" pattern

**When to use:** R1 (differentiation) — early in the dimension. You suspect the candidate is just a renaming of an existing driver, but you can't put your finger on it yet.

**Move:** name the suspected overlap explicitly.

```
Agent: "Quick check before we drill — <name> sounds close to D2 Reliability. The distinction I see is <X>. Does that match how you think about it, or is there a different distinction I'm missing?"
```

The named-suspicion move gives the operator an off-ramp ("you're right, it's just D2" → kill candidate) without forcing them to admit a mistake unprompted.

**Worked example from `INGESTION-bvp-driver-prompt-bundle-2026-06-06.md` §6.4.5 (paraphrased):**

> Agent named that the v1 skill format was the wrong shape — batch-propose only, missing the interactive single-driver case. The named-suspicion let the operator confirm and move forward without litigating whether v1 was a mistake.

## Drilling examples without leading

**When to use:** O1 (edge cases). You want concrete examples the operator hasn't pre-thought, not examples that fit a scheme.

**Move:** ask for the boundary case, not the prototype case.

```
Bad: "Give me a task that would score 0 on <name>."
Better: "Give me a task that almost scores 0 — what's the smallest reason it isn't 0?"
```

Boundary-case asking surfaces the actual scoring criterion. Prototype asking just gets the operator's canonical mental image of the driver.

**Why this works:** rubric quality is determined by boundary clarity, not by prototype clarity. Operators usually have a clear prototype but a vague boundary — the boundary is where calibration drifts across agents and time.

## Eliciting the retire_when condition

**When to use:** end of session, before writing the spec. The `retire_when:` field captures the condition under which this driver becomes obsolete.

**Move:** ask "what would make this driver irrelevant?"

```
Agent: "Last question for the spec. What's the condition that, if it became true, would mean we no longer need <name> as a driver?"
Operator: "If <X> were universally true across the project, we wouldn't need to track it separately."
Agent: "Recording retire_when as 'when <X> is universally true across the project'."
```

If the operator can't answer (genuinely doesn't know what would retire the driver), record `retire_when: undefined`. That's honest. A driver with no foreseeable retirement condition is a long-lived driver; that's a valid state. Inventing a retirement condition to fill the field is worse than honest emptiness.

## Naming the moment to skip O3 (overlap test)

**When to use:** R1 already converged strongly, O2 already converged. O3 (overlap test) is starting to feel redundant.

**Move:** name it and skip.

```
Agent: "O3 would test overlap with existing drivers, but R1 already showed <name> distinguishes <X> from D2. Skipping O3 — confirm?"
Operator: "Yes."
```

Drilling O3 after R1 already converged is the most common death-march path. The dimensions are designed to skip when their answer is already established. Skip honestly.

## Handling "all of D1-D4" answers

**When to use:** R1. The operator says "<name> is about being antifragile, reliable, usable, and portable all at once".

**Move:** decompose and challenge.

```
Agent: "If it's about all four, then any task scoring high on <name> would also score high on D1+D2+D3+D4. Take a recent task — does scoring it on <name> change its ranking, or does the D1-D4 sum already capture it?"
Operator: "It would change ranking because... actually no, you're right, D1-D4 already captures it."
Agent: "Then <name> doesn't add ranking signal. Kill the candidate?"
```

"All of D1-D4" candidates dilute scoring. Decompose, test ranking impact, kill if no signal.

**Why this works:** the BVP composite already covers D1-D4. Adding a driver that's "all of them" is double-counting that destroys differentiation between tasks.

## Capturing a `[REJECTED]` cleanly

**When to use:** mid-dialogue, an approach is considered and explicitly killed (vs. silently dropped).

**Move:** name the rejection, name the reason, move on.

```
Agent: "OK so we're rejecting weight: 7 because it would put <name> heavier than D2 Reliability (also 7) — which doesn't match the consequence walkthrough we just did. Moving to weight: 5, anchored against D3."
```

The named-rejection captures content for §6 (Rejected Paths) and prevents future sessions from re-litigating the same point.

**Anti-pattern to avoid:** silently abandoning options. Future readers can't tell whether an option was considered-and-killed vs. never-thought-of. The artefact's §6 distinguishes them.

## What these tactics do NOT replace

- **The subroutine's structure.** Tactics adapt how you ask within the R1/R2/O1-O4 frame; they don't replace the frame.
- **Operator sovereignty.** Tactics improve elicitation, not authority. The operator's "do X" overrides any tactical preference.
- **The skip-when-stuck rule.** Tactics are for productive engagement, not for force-feeding dimensions that aren't producing signal.
- **The artefact's honesty.** Tactics that produce cleaner-looking dialogue at the cost of preserving the seams are anti-patterns. Capture what actually happened.
