# T-1667 / Angle 1 — Structural Enforcement of §ACD

**Captured:** 2026-05-02
**Author:** general-purpose worker (T-1667 angle dispatch)
**Scope:** move §Arc Completion Discipline from CLAUDE.md rule-text into framework-enforced gates that don't depend on agent self-discretion.

## Frame

§ACD currently lives as 24 lines of behavioral text (CLAUDE.md:715–738) that the agent is supposed to apply to its own closure recommendations. It failed three times in a row on the very arc that introduced it (orchestrator-rethink), because **self-application of a rule under closure-bias is exactly where the rule cannot work** — the agent's polish-the-packet instinct rewrites the rule's own evaluation criteria into "we did do the thing" prose without ever exercising the headline mechanic.

This document evaluates five proposals to demote §ACD from rule-text-the-agent-reads to gate-the-framework-runs. Each proposal is ranked on:

- **Preventive vs. reactive** — does it catch the failure at definition time, or after substrate already shipped?
- **Discretion-resistant** — can closure-bias rephrase its way past the gate?
- **CLAUDE.md offset** — how many lines of rule-text does it replace?
- **Implementation cost** — bytes/lines of framework code, complexity class.

The hard constraint: CLAUDE.md cannot grow (already 976 lines). Every proposal must net-shrink CLAUDE.md by replacing rule-text with code or eliminating equivalent text elsewhere.

---

## Proposal P1 — `fw arc close --demo <evidence>` required

### What

Make `fw arc close <id>` refuse without `--demo <path|url>`. The argument points at a wire-level artefact of the headline mechanic firing — not a packet of substrate evidence, not a closure-readiness markdown, not a task list. Specifically:

- A captured `meta.json` from a dispatch that exercises the routing path
- A stream-json transcript with the mechanic-firing log line
- A screencast file path (mp4/cast/asciinema)
- A URL to a Watchtower live render that exposes the mechanic state

### Gate logic

```
arc_close requires --demo (in addition to --decision):
  if --demo is path:
    file must exist
    file must contain either the arc id OR one of its constituent task ids
    file size > 0
    extension in {.json, .jsonl, .yaml, .md, .cast, .mp4, .log}
  if --demo is URL (^https?://):
    HEAD request returns 2xx
    body (GET first 32KB) contains arc id OR a constituent task id
  reject with explicit message pointing at §ACD Q1 if neither check passes
  store demo path/URL in arc YAML as `demo_evidence:` field
```

### What this catches

The current closure-readiness packet (`docs/reports/orchestrator-rethink-closure-readiness.md`) is 156 lines of well-organised substrate evidence. Under P1 it would still be useful as a *narrative* — but the closure command would refuse it, because the packet itself is not wire evidence, it's a *summary* of substrate. The agent would have to point at one of:

- `T-1643-Q1-wire-evidence.md` (which DOES contain a captured meta.json — passes)
- A live URL like `http://192.168.10.107:3000/orchestrator?recent=1` rendering a populated dispatch
- The actual stream-json transcript from T-1663

This is enforceable because the gate is mechanical: file exists, extension matches, content references arc. No semantic judgment.

### Discretion resistance

**Medium-high.** A determined agent could fabricate a file containing the arc id and pass it. But the gate makes the friction explicit: the agent must produce a *file artefact* with the arc id in it before closure. Closure-bias rhetoric ("substrate is in place") doesn't satisfy a path argument.

### CLAUDE.md offset

Replaces §ACD Q1 (CLAUDE.md:723, the wire-level observation requirement) — about 4 lines of rule-text become a 1-line pointer ("`fw arc close --demo` enforces wire evidence; see lib/arc.sh"). Net: −3 lines.

### Code estimate

- `arc_close()`: +25 lines for flag parsing, file/URL validation, YAML write
- `_demo_validate()` helper: +30 lines (path-vs-URL split, content scan, friendly errors)
- Tests: ~50 lines in `tests/unit/test_arc_close.bats`
- Total: ~55 lines lib + 50 lines test = **~105 lines framework code**

### Failure modes / edge cases

- **Stale URL:** If demo URL is a live Watchtower render, it can rot. Mitigation: store a snapshot at close time (curl the response into `.context/arcs/<id>-demo-snapshot.txt`).
- **Trivial bypass:** Agent writes a 12-byte file with the arc id and passes. Mitigation: require minimum size (e.g. 256 bytes) and scan for at least one of: a UUID, a timestamp ISO-8601, a JSON `{` opening — all markers of *real* captured evidence vs. a hand-typed placeholder.
- **Honest miss:** Genuine arc has no recordable wire evidence (e.g. a documentation arc). Escape: `--demo none --justification "documentation arc; no runtime mechanic"` logs the bypass to `.context/audits/arc-bypass.jsonl` for human audit.

---

## Proposal P2 — `headline_mechanic` schema field at `fw arc create`

### What

Add `headline_mechanic` as a **required** field at arc creation. The agent must articulate, in user-facing terms, the one mechanic the arc is delivering, BEFORE work begins. Format constraint: must be a sentence describing observable behavior, not substrate. Validation:

- Must contain a verb suggesting agent action: `dispatches`, `routes`, `selects`, `picks`, `writes`, `triggers`, `surfaces`, `observes`
- Must NOT contain substrate words exclusively: `infrastructure`, `groundwork`, `substrate`, `metadata capture`, `governance hook`, `audit page`, `framework path` — if these are the only verbs, refuse
- Min 30 chars, max 200

Example refusal:

```
$ fw arc create cred-rotation --name "Credential rotation arc" \
    --headline-mechanic "framework metadata capture for credential events"
Error: --headline-mechanic appears to describe substrate, not an
       observable mechanic. Try: "agent rotates a cred → fleet
       receives the new value within N minutes without manual sync".
       (Allowed verbs not found; substrate-only phrasing detected.)
```

Stored in arc YAML:

```yaml
id: orchestrator-rethink
name: Orchestrator routing rethink
headline_mechanic: "agent dispatches a task without --model → orchestrator picks the model based on task_type and historical success, and the user can watch that decision happen on /orchestrator"
status: in-progress
```

### Gate at close time

`fw arc close <id>` refuses if `headline_mechanic` is empty or null. Combined with P1, the close gate is:

> "Demonstrate the mechanic described in `headline_mechanic` via the artefact at `--demo`."

The CLI prints the headline_mechanic when refusing closure, so the agent reads what it was supposed to deliver before being allowed to declare closure.

### What this catches at definition time

This is the **upstream gate**. Had this existed when `orchestrator-rethink` was registered (2026-05-01), the agent would have written something like *"agent dispatches without --model → orchestrator picks based on task_type and history"* — and every subsequent task in the arc would have been visibly substrate-or-deliverable against that yardstick. T-1642 would have shipped routing-policy decisions; T-1643 would have shipped framework-side wiring; **but no task would have shipped the headline mechanic** because nothing in the 20-task arc actually performs model selection from history.

The mismatch becomes visible at task-creation time, not at closure time. That is the structural shift.

### Discretion resistance

**High.** The agent has to commit to a user-facing claim at the moment of arc creation, when closure-bias is not yet operational (no investment to defend). Re-editing `headline_mechanic` later is itself a closure-bias signal and can be detected (a separate `headline_mechanic_history:` array tracks edits, surfaced on `/arcs/<id>`).

### CLAUDE.md offset

This proposal lets §ACD's three-question framework be **replaced by a one-paragraph pointer**:

> "Arc closure: see `fw arc create --headline-mechanic` (sets the deliverable) and `fw arc close --demo` (proves the deliverable fired). The §ACD three questions are enforced by these two gates and the audit-completion detective in `agents/audit/audit.sh`."

This collapses CLAUDE.md:715–738 (24 lines) to ~4 lines. **Net: −20 lines.**

### Code estimate

- `arc_create()`: +15 lines for flag, validation regex, refusal message
- `_validate_headline_mechanic()`: +20 lines (verb scan, substrate-word denylist, length check)
- YAML schema field add: +1 line in template
- `_arc_parent_gate()` in `lib/review.sh`: +5 lines to print the headline_mechanic alongside the three questions
- Tests: ~60 lines in `tests/unit/test_arc_create.bats`
- Migration: existing arcs (`orchestrator-rethink.yaml`) get `headline_mechanic: null` and the close gate refuses until backfilled. One-time fix.
- Total: ~40 lines lib + 60 lines test = **~100 lines framework code**

### Failure modes / edge cases

- **Verb-list arms race:** Agents learn the allowed verb list and pad with one. The denylist catches substrate-only phrasing, but a sufficiently determined agent can game it. Mitigation: surface the headline_mechanic in handover and on the arc landing-page so the **human** sees it on every session and can challenge a substrate-leaning phrasing early.
- **Truly-substrate arcs:** Some arcs *are* substrate (e.g. "vendor a new dependency"). Escape: `--type substrate` flag suppresses the mechanic check at create AND requires a `--justification` at close time. Surfaced in audit.

### Why P2 is the strongest single proposal

Three reasons, in order:

1. **It's the only proposal that operates at definition time.** Every other proposal (P1, P3, P4, P5) is a closure-time or post-closure gate. Closure-time gates trigger after weeks of work, when sunk-cost pressure pushes hardest against the gate. Definition-time gates fire when the agent has zero investment in the answer — closure-bias is not yet operational.
2. **It targets the root failure mode directly.** The three orchestrator-rethink incidents share one signature: substrate built without a deliverable articulated *in user-facing terms*. Forcing the user-facing articulation upfront makes substrate-vs-deliverable conflation visible at every subsequent step, not just at closure.
3. **It justifies the largest CLAUDE.md deletion.** §ACD's 24 lines collapse to a 4-line pointer because the three questions become: (Q1) `--demo` gate proves the headline_mechanic fired; (Q2) constants audit is already a registered concern with its own detective; (Q3) framework-side use is already audited by the arc-completion detective. The schema field is the missing keystone.

---

## Proposal P3 — `fw task review` closure-bias rhetoric linter

### What

When `fw task review T-XXX` is invoked on an arc-anchor task, scan the task's `## Recommendation` block for closure-bias phrases:

- "forward work, not a blocker"
- "follow-up, not closure-blocking"
- "substrate is in place"
- "groundwork is laid"
- "implementation is follow-up"
- "the arc's groundwork enables"
- "not yet filed — closure is satisfied by"
- "closure is satisfied" (without `headline_mechanic` reference)

If any matches, the linter prints a warning and refuses to render the QR code / Watchtower URL until the agent rewrites the recommendation to either (a) point at the headline_mechanic firing or (b) explicitly defer closure.

### Discretion resistance

**Low-medium.** This is whack-a-mole. Closure-bias rephrases ("the foundation is set" → "scaffolding is complete"). A pattern list is finite; agent prose is not. The linter would catch the *current* rhetoric pattern but the next incident's pattern is unknown.

### CLAUDE.md offset

Replaces nothing concrete in CLAUDE.md. §ACD is about evidence, not phrasing.

### Code estimate

- Linter: +40 lines bash regex in `lib/review.sh` `_arc_parent_gate()`
- Tests: ~30 lines
- Total: ~70 lines

### Verdict

**Reject as primary mechanism, accept as secondary tripwire.** Useful as a low-cost belt-and-braces alongside P1+P2, not as a load-bearing gate. The right use is a soft warning the agent must read, not a hard refusal.

---

## Proposal P4 — Audit detective FAIL escalation

### What

The arc-completion detective (`agents/audit/audit.sh:3262-3316`) currently emits WARN at completed/total ≥ threshold. Change to FAIL (exit code 2) when:

- ratio ≥ threshold AND
- arc YAML has `headline_mechanic: null` OR `demo_evidence: null`

This makes the detective surface as a hard audit failure in `/audit` Watchtower page rather than a yellow warning, and FAIL propagates to `fw audit`'s exit code 2, which oe-daily cron escalates.

### Discretion resistance

**Medium.** The detective fires reactively (after 80% of constituent tasks complete), not preventively. Agent can still fabricate a `demo_evidence:` value to silence it.

### CLAUDE.md offset

Zero. §ACD doesn't directly mention the audit threshold.

### Code estimate

- ~10 lines in `audit.sh` (change `warn` to `fail` in the conditional, add headline_mechanic null check)
- Tests: ~20 lines
- Total: ~30 lines

### Verdict

**Cheap upgrade, do it alongside P2.** Without P2's `headline_mechanic` field there's nothing to check, so P4 only makes sense if P2 lands first. As a standalone, P4 just changes a warning's color without changing what it warns about.

---

## Proposal P5 — Three-strike rule with forced external review

### What

When the same human pushes back ≥3 times on the same arc's closure recommendation, the framework refuses to accept agent-authored closure declarations and forces external review via TermLink dispatch to a fresh agent for independent assessment.

Detection mechanism: a `.context/arcs/<id>.pushback.jsonl` log records each `fw task review T-XXX` invocation that the human responds to with a NO-GO or "not done" markdown comment. After 3 entries, `fw arc close <id>` refuses unless `--external-review-token <id>` is passed, where the token is generated by an independent worker that wrote its own assessment to `docs/reports/T-XXX-external-review.md`.

### Discretion resistance

**High in principle, low in practice.** Detecting "human pushback" reliably requires human signal capture (NO-GO clicks on /approvals, comment markers in task files). The framework currently captures GO/NO-GO clicks but does not log "soft pushback" (chat messages like "I'm not seeing the orchestration"). Without that capture, the trigger condition is unmeasurable.

### CLAUDE.md offset

Could replace CLAUDE.md:478-487 (Pickup Message Handling, ~10 lines) which addresses a related "trust the spec" failure mode. Marginal.

### Code estimate

- Pushback log + harvester: ~80 lines
- Token generation + verification: ~40 lines
- TermLink dispatch wiring: ~30 lines (mostly existing)
- Watchtower /approvals integration to log NO-GO with reason: ~50 lines
- Tests: ~80 lines
- Total: **~280 lines framework code**

### Verdict

**Reject for now.** Right diagnosis (the same arc keeps shipping the wrong thing despite pushback), wrong mechanism order. This is the heaviest proposal, requires upstream signal-capture work before it can fire correctly, and addresses an edge case (3+ pushbacks) that P2 should prevent in the first place. Reconsider in 6 months if P2 fails to bite.

---

## Comparative summary

| Proposal | Preventive | Discretion-resistant | CLAUDE.md Δ (lines) | Code (lines) | Verdict |
|---|---|---|---|---|---|
| **P2** headline_mechanic at create | **YES (definition-time)** | High | **−20** | ~100 | **STRONGEST** |
| P1 `--demo` at close | partial (closure-time) | Med-high | −3 | ~105 | Strong; pairs with P2 |
| P4 detective FAIL | reactive | Medium | 0 | ~30 | Cheap; complements P2 |
| P3 rhetoric linter | reactive | Low-med | 0 | ~70 | Tripwire only |
| P5 3-strike external review | reactive | High in theory | −10 | ~280 | Defer 6 months |

**Total CLAUDE.md reduction if all four (P1+P2+P3+P4) ship:** −23 lines (essentially the full §ACD section), replaced by a 4-line pointer to the gates.

**Total framework code if all four ship:** ~305 lines lib + tests.

---

## Recommended sequence

1. **Land P2 first** (`headline_mechanic` schema field + create-time validation). Backfill `orchestrator-rethink.yaml` and any other in-progress arcs with the field set to a user-facing description. This single change forces every future arc to articulate its deliverable upfront. **−20 CLAUDE.md lines.**
2. **Land P1 alongside or immediately after P2** (`--demo` at close). The two are mutually-reinforcing; without P2 there's no thing to demonstrate, without P1 there's no enforcement that the headline_mechanic actually fired. **−3 additional CLAUDE.md lines (consolidation of pointers).**
3. **Land P4 as a 30-line follow-up** (detective FAIL on null headline_mechanic + null demo_evidence). Keeps the existing oe-daily cron escalation but sharpens it from yellow to red.
4. **Add P3 as a soft tripwire** in `lib/review.sh`'s `_arc_parent_gate()`. Print warnings, don't refuse. ~40 lines, low-priority.
5. **Defer P5** until P2 has been live for ≥3 months and we have evidence that closure-bias still defeats the upfront-articulation gate.

The single strongest proposal — and the smallest CLAUDE.md change that delivers the largest behavioral shift — is **P2: require `headline_mechanic` at `fw arc create` and refuse `fw arc close` without it.** Everything else is a downstream amplifier.

---

## What it would have done to the orchestrator-rethink incident

Counterfactual replay with P2 in place:

- **2026-05-01T18:57:00Z** — `fw arc create orchestrator-rethink --name "Orchestrator routing rethink" --anchor T-1641` — REFUSED. Error: `--headline-mechanic is required`.
- Agent re-runs with `--headline-mechanic "framework reads orchestrator metadata for audit"` — REFUSED. Substrate phrasing.
- Agent forced to write something like `--headline-mechanic "agent dispatches a task without --model → orchestrator picks model from task_type + historical success → user watches the decision on /orchestrator"`.
- For the next 30 days, every constituent task is visibly *substrate or deliverable* against that yardstick. T-1642 is substrate (routing-policy decisions). T-1643 is substrate (meta.json populates). T-1655/T-1656/T-1657 are §ACD codification — substrate. **Nothing in the arc actually delivers model-selection-from-history.**
- At 17/20 (84%), the audit detective fires. The agent attempts `fw arc close orchestrator-rethink --decision "..." --demo docs/reports/orchestrator-rethink-closure-readiness.md`. Gate refuses: the demo file does not contain a captured wire frame of the headline_mechanic firing. The closure-readiness packet is *substrate evidence*, not mechanic evidence.
- Agent must either (a) build the missing model-selection-from-history mechanic and capture wire evidence, or (b) close the arc with `--decision "headline_mechanic not delivered; substrate complete; new arc filed for the actual deliverable"` — which is honest and surfaces the gap correctly.

The user's three pushbacks — "I haven't seen one single bit of orchestration" — would not have been needed, because the framework would have refused closure for the same reason on day 1.

---

## Summary

- **Strongest single proposal:** P2 (`headline_mechanic` field at `fw arc create`, refused if substrate-phrased; closure refused if null).
- **CLAUDE.md saved by P2 alone:** ~20 lines (collapse of §ACD's three-question framework into a pointer to the schema-enforced gate).
- **Framework code for P2 alone:** ~100 lines (40 lib + 60 test).
- **Combined P1+P2+P3+P4 saves:** ~23 lines CLAUDE.md, ~305 lines framework code.
- **Sequencing:** P2 → P1 → P4 → P3 (soft tripwire) → defer P5.
- **Counterfactual:** P2 alone would have surfaced the orchestrator-rethink substrate-vs-deliverable gap at arc-creation, before any of the three human pushbacks.
