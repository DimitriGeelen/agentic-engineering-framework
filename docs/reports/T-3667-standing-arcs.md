# T-3667: Standing arcs (inception research artifact)

## The proposal (operator, 2026-10-01, verbatim in substance)
"We are going to take this the same as for tasks. We need to have FW arcs that are standing arcs where new tasks can come in all the time. Such an arc would be FW001 audit findings. That should be standing arcs where tasks come in. They accumulate there. They get scored. Low scores… low value findings will move there… That tackles a large thing we had about audit warnings. We just parked them there. And if they accumulate there, then we can action them. And we can bundle them in one. Or we can get learnings from it and derive patterns from it… In the same way we also will have a FW002 arc for the inception review loop."

## Why it fits (agent assessment)
- **Arcs are built to finish:** a headline mechanic, a §ACD demo gate to close, a stale WARN. Continuous work therefore has no home, and it piles up undrained:
  - 373 pending observations;
  - audit WARNs everyone ignores (L-670);
  - 114 baselined test reds (T-3621);
  - 055's unread backlog (T-3639).
- **Low value becomes a place, not a guilty pile:** findings scored on intake and parked when low are "declinable" (O-3, T-3535).
- **Accumulation becomes a signal:** grouped items can be bundled, promoted, or mined for patterns and learnings (Level D reflection).
- **FW-002 replaces the arc-008 re-scope question:** the operator side of escalated inceptions under IW-2 (T-3557) is a continuous loop, not a deliverable.

## Proposed answers (agent, 2026-10-01; operator agreed with the framing, then asked for a 3-model review)

1. **Lifecycle:**
   - a new arc status `standing`, with an `FW-NNN` id; it never closes;
   - exempt from the §ACD demo/close gate and the 30-day stale WARN;
   - health checks in their place, in audit and on the arc page:
     - **flow:** items in versus out per week, WARN if the backlog grows 4 weeks running;
     - **age:** the oldest open item, WARN past 30 days unless explicitly parked with a reason;
     - **score spread:** items per score band.
2. **Intake:**
   - **automatic for repeat signals only:** an audit WARN seen on 7 consecutive days becomes ONE task in FW-001, deduplicated by check name; an escalated inception goes to FW-002;
   - **manual for the rest:** observations, peer findings and red tests go in at triage; `fw arc assign` puts any task into a standing arc;
   - automatic intake starts small, so FW-001 does not fill with noise.
3. **Drain:**
   - a weekly sweep (a dispatched worker per standing arc) clusters similar items, bundles each cluster into one task or closes duplicates, and writes a learning/pattern when 3+ items share a cause;
   - forced action at 25 open items or any item 60 days old: the sweep must bundle, promote or close;
   - an item leaves only by *promote* (to a delivery arc or horizon now, when its score rises) or *won't-fix* (closed with a recorded reason). Never silent dropping.
4. **Scoring:**
   - BVP score on intake: below the threshold it stays parked, above it is promoted out at intake;
   - the threshold is per arc, starting at the median of current task scores;
   - standing arcs are exempt from T-3637's "supports nothing AND stale" rail.
5. **Naming and the first set:**
   - **FW-001** audit findings;
   - **FW-002** inception review loop: escalated inceptions plus operator feedback. It absorbs arc-008's 11 done tasks and T-2137;
   - **FW-003** test health: the T-3621 baseline reds and future red suites, kept separate because of their own expiry clock;
   - peer-agent findings go into FW-001 until volume justifies their own arc.

**Objective mapping** (.context/project/objectives.yaml):
- **FW-001 → objectives 1 and 3:**
  - objective 1 (governance traceable, gates not bypassed): audit findings are mostly governance drift;
  - objective 3 (operator queue only what needs a human; low value declinable): parking low-value findings.
  - Arguably also objective 2, through pattern mining.
- **FW-002 → objectives 3 and 2:**
  - objective 3: escalated inceptions are exactly what should reach the operator;
  - objective 2 (lessons survive sessions): operator feedback is read in the next session.
- **FW-003 maps weakly:** it fits Directive D2 (reliability) more than any objective, which hints it may belong in FW-001.

## Three-model review (2026-10-01): all three GO-WITH-CHANGES
Reviews: `T-3667-review-anthropic.md`, `-openai.md` (codex), `-zai.md` (GLM-5.2). All internal-class, cost logged.

### Consensus changes (all three, or two with no dissent) → adopted into v2
1. **Drain is measured by RESOLVED items** (fixed, verified, or won't-fix with a reason). Bundling is NOT an exit and does not reduce the counts the health checks read; the same cluster cannot satisfy forced action twice. *All three: the main new failure mode is "laundering", where re-bundling looks like progress.*
2. **No median threshold.** Intake promotion uses the existing auto-promote band (T-1931: bvp_norm ≥ 0.85, known cost ≤ 1, concurrency cap). One promote path, and parking is the default. *All three: a median is self-referential and ratchets down.*
3. **FW-003 is merged into FW-001** as a tagged test-health cluster. The T-3621 baseline stays the source of truth; only entries that EXPIRE unfixed flow into FW-001, reusing their owning triage tasks. *All three.*
4. **Arc-008 is NOT absorbed.** Its headline (two-click decide plus feedback) is a deliverable: close it through §ACD with a demo. FW-002 holds only future escalations, and T-3618 is reconciled with it. *All three.*
5. **The age clock cannot be cleared by parking.** Parking is the normal state, so "parked with a reason" must not silence the age WARN. Only a resolution clears it, and parking carries a revisit date. *Anthropic, Z.ai; OpenAI likewise wants expiring parking decisions.*
6. **Intake counts audit RUNS, not calendar days** (for example "seen in 5 of the last 7 runs", which catches flapping). Dedup by check plus affected entity/scope. Link an existing task before creating one. A won't-fix writes a suppression record, so the same WARN does not come back in. Health WARNs about standing arcs must never auto-file tasks (no recursion). *All three.*
7. **T-3637 is not blanket-exempted.** Standing arcs declare `supports:`; only the stale half of the rail is exempt, so a standing arc can never go without an objective. *All three.*
8. **The weekly sweep is recurring spend under objective 6:** cost logged, a budget per sweep, and failure and missed-sweep detection. *All three.*
9. **The §ACD create gate is kept:** a standing arc still needs a headline mechanic (for example "operator sees FW-001 flow and age, and every exit has a reason"). It is exempt only from close and stale. A human-only retire verb. *Anthropic, Z.ai; OpenAI: "standing" as an arc KIND, separate from status, with retirement.*
10. **A won't-fix needs an independent reviewer verdict** (Anthropic), with a reason taxonomy visible to the operator (Z.ai).

### Split, for the operator to decide
- **The forced-action age clock:** Anthropic says one 60-day clock; Z.ai says 30 days, to match the delivery stale WARN; OpenAI says the thresholds are uncalibrated, so measure today's intake first and use them as review triggers rather than compulsory disposal.

### Missing (to specify in the build)
- the parked item's task state (status, horizon, WIP, focus, handover, work-on);
- FW-NNN coexisting with arc-NNN and slugs, and the `arc_id` hook accepting FW ids;
- a resolved-per-week metric;
- sweep failure and cost-ceiling behaviour;
- migration of the existing WARN backlog, the ~381-item inbox and the 114 reds;
- Watchtower surfaces (the flow/age chart, the won't-fix review);
- excluding standing arcs from /approvals close-ready and the completion badges;
- a won't-fix reason taxonomy;
- whether standing arcs get scoped drivers.
- **Verify** `fw note triage` exists (Anthropic could not find it; the handover prints it).

## Risks
The main risk is a graveyard: items parked and never drained. It needs drain rules (IW-3) and health rails (IW-1) that make an undrained standing arc as visible as a stale delivery arc is today.

## Dialogue Log
- 2026-10-01, operator asked what arc-008's scope is and why re-scope. Agent: the headline is a two-click decide plus feedback the agent reads next session; under IW-2 the operator still decides escalated inceptions, so re-scope rather than abandon.
- 2026-10-01, operator proposed standing arcs (above). Agent agreed, named the needed lifecycle, intake, drain and scoring rules, and filed this inception (recommendation GO) with IW-1..IW-5.
