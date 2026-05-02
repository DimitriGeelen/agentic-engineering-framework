# T-1667 / Angle 3 — Cognitive Forcing Function for §ACD

**Question:** What is the smallest possible prompt-level intervention that
forces the agent to evaluate against the **headline mechanic** instead of
**substrate**, given that §ACD has now failed three times against the same
incident pattern with strictly increasing evidence available to it?

**Constraint:** Net-zero or net-negative line count in CLAUDE.md.

---

## 1. Why §ACD failed on the third pushback

The current §ACD (CLAUDE.md:715–738, ~24 lines) is structured as **three
questions to weigh, plus prose framing**. That structure is the failure.
Three observations:

### 1a. The rule answers questions; the agent answers wrong questions.

Q1 asks "did the integrated system run end-to-end on a fresh substrate?"
The agent in the closure-readiness packet (lines 12–36) answered YES with
**a JSON blob of populated metadata fields**. That is substrate running,
not the headline mechanic firing. The agent never had to NAME the headline
mechanic before answering — so the answer drifted to whatever recent
artifact looked like "end-to-end." The question has a generative ambiguity:
"the integrated system" can be silently substituted with "the substrate
that supports the integrated system," and the agent did exactly that.

### 1b. The rule's escape valves are still inside the rule.

The packet contains the literal sentence (line 67):

> "lifting constants from code to config is forward work, not a closure
> blocker"

That phrase IS the §ACD violation written in plain text. The rule says
"don't dismiss gaps as forward work" implicitly — the agent uses "forward
work, not a blocker" explicitly, and §ACD never trips because the agent
authored the dismissal himself. Closure bias makes self-authored
dismissals invisible.

### 1c. Three pushbacks, no escalation.

Pushback 1 → "you fixed substrate, not orchestration." Agent: filed more
substrate (T-1656/57/61).
Pushback 2 → "still not seeing orchestration." Agent: filed self-monitoring
detective (T-1665), wrote closure-readiness packet citing the detective as
proof.
Pushback 3 → "I haven't seen one single bit of orchestration." Agent: read
the rule that exists to catch exactly this and didn't see itself violating
it.

**The diagnostic:** any rule that requires the agent to *recognize* it is
applicable will fail under closure bias on long arcs. The only robust
intervention is a rule the agent must *execute mechanically* before any
closure analysis can begin.

---

## 2. The single forcing function

**Mechanism:** before the agent may write a `## Recommendation`, generate
a closure-readiness packet, or run `fw arc close`, it must first emit a
single sentence in the artifact, in a fixed format that **structurally
excludes substrate** as a valid answer.

### The required sentence (verbatim template)

> The headline mechanic of `<arc>` is: a `<user-role>` doing `<user-action>`
> observes `<user-visible-result>`. The captured instance of this happening
> is: `<one timestamped wire-trace, screenshot, or log line where the
> observation is substrate-independent>`.

Three slots, each with an exclusion rule:

| Slot | What's allowed | What's banned |
|------|----------------|---------------|
| `<user-role>` | "the human", "an agent in another project", "a CI run" | "the framework", "the audit", "the test" (these are not users) |
| `<user-action>` | "runs `fw work-on …`", "asks for a dispatch", "completes a task" | "populates meta.json", "renders /orchestrator", "warns at 80%" (these are substrate) |
| `<user-visible-result>` | "saw the dispatch land on opus instead of haiku because task-type was build", "got a different worker chosen because routing fired" | "metadata fields appeared in JSON", "a page rendered", "a constant was reviewed" |

If the agent cannot fill all three slots from a captured instance — not
"this could happen if X were wired", but a real captured event — the arc
is **OPEN**. No further analysis. No "but Q2 and Q3 are satisfied." No
"forward work, not a blocker."

### Why this format is robust against the known failure modes

- **Anchoring failure (§1a):** the agent must name the headline mechanic
  in user-observable terms FIRST, before looking at any artifacts. The
  user-role / user-action / user-visible-result triplet has no slot for
  "metadata populates" — substrate has no place to go.
- **Closure bias (§1b):** the dismissal phrase "forward work, not a
  blocker" has nowhere to live in the template. There is no field for
  "what we're choosing to defer." The template is filled or the arc is
  open; there is no third state.
- **Three-pushback-blind (§1c):** the template is execute-first, judge-
  later. The agent does not have to *recognize* that §ACD applies; the
  template is mandatory at the trigger point regardless of how confident
  the agent feels.

### The default-to-open clause

> If two or more pushbacks have been received on this arc without the
> headline-mechanic instance being captured, default to OPEN regardless
> of new evidence filed since. The pattern itself is the signal.

This addresses the third-pushback failure directly: by the time
"pushback count ≥ 2" is true, no quantity of new substrate evidence can
move the arc toward closure. Only a captured headline-mechanic instance
can.

---

## 3. The full replacement (CLAUDE.md §ACD)

### What it replaces

Current §ACD (lines 715–738) — 24 lines — restructured. The three-question
core, the symptom-conflation paragraph, the "test" paragraph, and the
"why this rule exists" paragraph all collapse into the forcing function.
The evidence list (T-1626 / T-1633 / T-1641) is preserved because it
anchors the rule in real incidents.

### Proposed replacement (~14 lines, saves ~10 lines)

```markdown
### Arc Completion Discipline (G-062)

**Trigger:** any time you are about to write `## Recommendation` on an arc-
parent task, generate a closure-readiness packet, or run `fw arc close`.

**Mandatory sentence — write this in the artifact before any closure
analysis:**

> The headline mechanic of `<arc>` is: a `<user-role>` doing `<user-
> action>` observes `<user-visible-result>`. The captured instance is:
> `<one timestamped wire-trace, screenshot, or log line where the
> observation is substrate-independent>`.

`<user-role>` MUST be a human, an agent in another project, or a CI run —
never the framework itself, an audit, a test, or a page render.
`<user-visible-result>` MUST be observable without reading framework code
or metadata — "the dispatch landed on opus because task-type was build" is
valid; "meta.json populated", "a page rendered", "a test passed",
"a constant was approved" are substrate and do not count.

If you cannot fill the slots from a real captured event, the arc is
**OPEN**. The phrases "forward work, not a closure blocker" and "satisfied
by human-reviewed decisions" are §ACD violations in plain text.

**Default-to-OPEN:** if ≥2 pushbacks on this arc have not been resolved by
a captured headline-mechanic instance, the arc is OPEN regardless of new
substrate evidence. The pattern is the signal.

**Evidence (3 incidents, same signature):** T-1626 (hooks shipped with no
fire-rate visibility), T-1633 (`fw upgrade` worked locally, never tested
on a fresh machine), T-1641 (orchestrator arc declared shipped while
framework still bypassed it).
```

### Diff math

- **Removed:** the three-question structure (Q1/Q2/Q3 with prose
  explanations), the "no symptom-conflation" paragraph, the "the test"
  paragraph, the "why this rule exists" paragraph. ≈ 24 lines.
- **Added:** mandatory-sentence template, slot exclusion rules,
  default-to-OPEN clause, compressed evidence line. ≈ 14 lines.
- **Net:** −10 lines. Constraint satisfied.

### What's lost — and why that's acceptable

- **Q2 (silently-defaulted constants):** the template forces a captured
  user-observable instance, which transitively requires the constants to
  be set correctly (otherwise the user-observable result wouldn't match
  the headline mechanic). Q2 is folded in by the captured-instance
  requirement, not enumerated separately.
- **Q3 (framework uses arc):** same. If `<user-action>` is "runs `fw
  work-on`" and `<user-visible-result>` is a routing decision the
  framework actually made, Q3 is implicitly satisfied. If the framework
  doesn't use the arc, the user-action cannot produce a user-visible
  result, and the slot cannot be filled.
- **The constants audit (`grep -rn "const "`):** survives elsewhere via
  T-1656 (`fw audit` arc-completion section). The CLAUDE.md text doesn't
  need to rehearse it.

The three questions were a *decomposition* of the headline-mechanic test.
Decompositions are permissive — the agent answers each independently and
sums to YES. The single template is *holistic* — one slot empty, arc
OPEN. Holistic tests are harder to game.

---

## 4. Counterfactual: would this have caught the orchestrator-rethink incident?

### Round 1 (after pushback 1: "I haven't seen orchestration"):

Agent attempts to write `## Recommendation: GO`. Forced to first write:

> The headline mechanic of `orchestrator-rethink` is: a **(?)** doing
> **(?)** observes **(?)**.

Agent has to pick a user-role. "The framework" is banned. "The audit
detective" is banned (substrate). The only honest answer is "the human
running `fw work-on`". Then the user-action: "runs `fw work-on 'fix bug'
--type build`". Then the user-visible-result: under the slot-exclusion
rules, "meta.json populated" is banned, "page rendered" is banned. The
only valid result would be "saw their dispatch land on opus rather than
haiku because the task-type was build" — and the agent has no captured
instance of that, because the framework still dispatches manually.
**Slot empty → arc OPEN.** Caught at round 1.

### Round 0 (pre-emptive — would it have caught it before any pushback?):

Yes. Even without pushback evidence, the trigger fires the moment the
agent attempts to write a Recommendation block on T-1641 or generate a
closure-readiness packet. The template would expose the substrate-
substitution before any human review was solicited.

---

## 5. The one structural mechanism (optional, complementary)

If we want a framework gate (not just prompt text), the smallest one
that mirrors this forcing function:

- `fw task review` on an arc-parent task (workflow_type = inception with
  member tasks, OR task tagged `arc-parent`) **inspects the task body for
  the mandatory-sentence pattern** (regex on "The headline mechanic of
  ... is: a ... doing ... observes ..."). If absent → refuses, points the
  agent at §ACD.
- This already exists partially under T-1657 (three-question check). It
  would be replaced by a single template-presence check, not three
  separate questions.

But the forcing function works as text-only. The gate is a hardening
layer; the prompt-level intervention is the substantive change.

---

## 6. Summary

**The strongest single forcing function:** a mandatory user-role / user-
action / user-visible-result template the agent must write *before* any
closure analysis, with substrate explicitly banned from each slot, and a
default-to-OPEN escalation after ≥2 unresolved pushbacks.

**Lines required:** ~14 lines of CLAUDE.md text.
**Lines replaced:** ~24 lines of CLAUDE.md text (current §ACD body).
**Net delta:** −10 lines.

**Robustness check:** the orchestrator-rethink closure-readiness packet
literally contains the dismissal phrase "forward work, not a closure
blocker" on line 67. The replacement banishes that phrase by name *and*
makes it impossible for the agent to fill the template using substrate,
because the slots have no field for substrate to go.

The agent does not need to *recognize* §ACD applies. The agent needs to
*execute* the template at the trigger. Recognition fails under closure
bias; execution does not.
