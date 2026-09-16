# VALUE REVIEW — Confirmed Yardstick (Phase 1 output)

**Task:** T-3370 · **Date:** 2026-09-16 · **Status:** DERIVED, NOT YET HUMAN-CONFIRMED.

The operator answered `PURPOSE_SOURCE` with *"derive it and show me"* — explicitly
declining to privilege one document. This file is that derivation. It is the **only**
value criterion the JUDGE may rank against. Phase 1 of the protocol marks yardstick
confirmation as an ASK; the operator's Mandate directs autonomous progress, so the
yardstick is carried forward as **provisional** and its confirmation is folded into the
Phase 5 human gate rather than decided unilaterally. A judge finding that depends on a
contested line of this file must say so on its row.

---

## 1. Purpose, derived from four independent documents

| # | Source | Purpose statement (verbatim or close paraphrase, cited) |
|---|---|---|
| 1 | `README.md:2-4` | "A governance and continuity harness around AI coding agents. Tasks, memory, blast-radius foresight, value scoring, audit, and cross-agent coordination — wrapped around any CLI agent you already use. **Coordinates, does not execute.**" |
| 2 | `README.md:31-41` | "**The principle is traceability: nothing gets done without a task.** Everything that happens is captured … The record of all of it is the **Context Fabric**." Second mechanism: "**the Component Fabric — the map of how the pieces relate.**" |
| 3 | `README.md:22-26` | Agents are "coached — and where it matters, forced — to come back for human feedback… The framework's job is to know which moment is which, and to make sure the second kind never happens silently." |
| 4 | `FRAMEWORK.md:16` | "a governance framework for systematizing how AI agents work within engineering projects. This is **not a traditional code library** — it's a set of structural rules, patterns, and enforcement mechanisms for agentic workflows." |
| 5 | `FRAMEWORK.md:22` / `CLAUDE.md` Core Principle | "**Nothing gets done without a task.** This is enforced **structurally** by the framework, **not by agent discipline**." |
| 6 | `FRAMEWORK.md:33-37` | Authority Model: Human → SOVEREIGNTY; Framework → AUTHORITY; Agent → INITIATIVE, "never decides". |
| 7 | `policy/value-drivers.yaml` | The ranked directives below — the only machine-readable statement of what this project counts as value. |

**Derived purpose statement (the yardstick's first clause):**

> The framework exists to make an AI agent's work **traceable, reversible, and
> human-sovereign** by structural enforcement rather than agent discipline — capturing
> the full record of what happened (Context Fabric), the map of what it touches
> (Component Fabric), and forcing a human decision at exactly the moments where taste or
> consequence requires one. It **coordinates; it does not execute.**

**Four load-bearing consequences for classification:**

- **C1 — Enforcement beats documentation.** A rule that lives only in prose is, by the
  project's own words ("not by agent discipline"), not yet doing its job. Prose that
  *documents* a live gate is doing its job; prose that *substitutes* for one is a gap.
- **C2 — A silent failure is worse than a loud one.** D2 names "no silent failures"
  explicitly. A check that reports success while measuring nothing is a **negative-value**
  item, not a neutral one — it consumes the attention a real check would have earned.
- **C3 — Sovereignty is not optimisable.** Items whose only cost is "the human has to
  decide" are not inefficiencies. `## Authority Model` puts the human above the framework;
  no efficiency argument outranks it.
- **C4 — "Coordinates, does not execute"** bounds the ADD axis. Missing capability that
  would make the framework *do the engineering work* is out of scope; missing capability
  that would make it *govern the work better* is in scope.

## 2. Ranked drivers — verbatim from `policy/value-drivers.yaml` (`version: 3`)

Protected (constitutional, not removable):

| id | name | weight |
|---|---|---|
| D1 | Antifragility | **9** |
| D2 | Reliability | **7** |
| D3 | Usability | **5** |
| D4 | Portability | **3** |

Free drivers, exactly as on disk (cap is 5; five are active — at the cap):

| id | name | weight |
|---|---|---|
| F-RECALL | Recall Leverage | **6** |
| F-AUTONOMY | Autonomy / Unattended Operation | **4** |
| F3 | V_PROMPT_QUALITY | **7** |
| F1 | V_CONTEXT_FABRIC | **7** |
| F2 | V_COMPONENT_FABRIC | **6** |

Retired: `F-ORCH` / Orchestration Leverage / weight 5 — commented out 2026-07-07 (T-2511),
definition preserved in-file, marked REVERSIBLE.

**Ranking rule for the JUDGE.** Rank a finding's value by the highest-weighted driver it
serves or harms, and say which driver by id. Two findings serving the same driver break
ties on realized cost (Evidence F), never on the judge's taste. "No driver" is a valid
and important verdict — it is the strongest DELETE signal available, and the only one
that does not depend on usage data.

## 3. Contradictions between stated purpose and measured reality

Listed, **not reconciled**. Each is a fact from the evidence files; whether it is a defect
is the JUDGE's call, and whether it is acted on is the operator's.

| # | Stated | Measured | Cite |
|---|---|---|---|
| 1 | "enforced structurally … not by agent discipline" | **Four fully-built write-time gates are not wired** into `.claude/settings.json`: check-inception-recommendation (T-2205), check-task-ac-structure (T-2420), check-visual-verification (T-2128), chat-bare-path-scan/-warn (T-2183). Only T-2205's gap is acknowledged anywhere. | D §4.1 |
| 2 | "value scoring" is named in the README's own one-line description of the product | **0 confirmed BVP scores corpus-wide** against 3319 proposed. The confirm verb exists; nothing has ever passed through it. | B §19 |
| 3 | BVP exists to rank work by value | Predicted BVP carries **no usable independent signal**: ρ=0.19 vs commits, which falls to 0.05–0.10 inside body-length terciles; ρ≈0.00 vs wall-clock; ρ=−0.10 vs dispatch spend. Two vectors cover 63% of predictions. | F §6 |
| 4 | The Mandate's own selection rule is "task by BVP quadrant" | Quadrant selection **is not executable**: `fw bvp --quadrant hv-lc` reports 175/206 tasks (85%) with no known cost, whole band tied at 108/0.40/3.6. | OBS-415 |
| 5 | "auditable execution", Tier-2 bypasses are logged | `.context/working/.gate-bypass-log.yaml` — the Tier-2 audit trail — **does not parse** (not valid UTF-8). | prior run |
| 6 | Gates are the framework's primary mechanism | **Gate first-pass rate is ABSENT.** Only bypasses are logged; a gate that never fires and a gate that always passes are indistinguishable. | B §12 |
| 7 | "no silent failures" (D2) | Bus has **no out-of-band observer**; discarded posts / silent drops / crashes are a confirmed data gap. A channel cannot report its own failures. | B §26 |
| 8 | Workflow Designer models executable governance | `aef:endpoint` has **zero occurrences in the live corpus** (DESIGNED-ONLY); ratification is a **filename prefix**, not recorded state. | B §27-28, §31 |
| 9 | Per-verb governance and pruning | **No per-verb usage counter exists anywhere.** 83 of 99 verbs have no cron reference; 94 of 371 files have no test naming them. This caps every DELETE at MEDIUM by protocol rule. | B §15, D §3c |
| 10 | "Portability" (D4, weight 3) | Hardcoded host paths in governance code: integrate-go-live.sh, notify.sh, `fw deploy`, several cron commands. | D §4.7 |
| 11 | The framework "coordinates, does not execute" | Two of its headline capabilities have **no in-scope implementation at all**: vector recall (engine in `web/`) and Workflow Designer (vendored from 832 + `tools/`). Not a defect on its face — recorded because a scope-limited review would call them absent. | D §2 |
| 12 | Handover is the continuity mechanism | Handover carries the **highest RCA density of any subsystem (36.9%)** on a small base (12.1 fractional tasks). | F §TL;DR |

## 4. What the yardstick explicitly does NOT authorise

- Ranking by the judge's taste, tidiness, line count, or age.
- DELETE on absence-of-usage-data alone (protocol rule; caps at MEDIUM and must be stated).
- Weakening any test, gate, check or audit to make the picture cleaner.
- Treating a Sovereign item as a cost.

---

## 5. Operator ruling — 2026-09-16 (binding, supersedes any judge inference)

Recorded verbatim from the operator, during the run:

> "something not showing up or not working, not being used doesn't per se mean it
> doesn't have any value, right? It could also mean that we want it, but it's just
> fucked up, broken and missing."

**What this settles.** The protocol already forbids DELETE on absence-of-usage-data
alone ("no data is not zero"). The operator's ruling goes further and is stronger: it
says the *default reading* of an unused, unwired or unreferenced item is **not** "dead
weight awaiting removal". It is **an open question with three distinct answers**, and
the review must say which one it is picking and why:

| Reading | Correct axis | What distinguishes it |
|---|---|---|
| **A — Wanted, but broken** | **ADD** (repair/complete), not DELETE | The capability is in the stated purpose or serves a driver; the item is a partial or non-functioning attempt at it. Non-use is a *symptom of the breakage*, not evidence against the capability. |
| **B — Wanted, but never wired** | **ADD** (wire it) | The implementation is complete and correct; nothing invokes it. The four unwired write-time gates (D §4.1) are the type case. |
| **C — Genuinely no longer wanted** | DELETE | Requires an affirmative reason the *purpose* no longer needs it — origin found and reason no longer holds — **not** merely an absence of references or telemetry. |

**The asymmetry is deliberate and is the point.** Deleting a broken-but-wanted
capability destroys the intent along with the artefact, and the intent is the expensive
part — it took a human decision to want it. Leaving a genuinely dead item in place costs
only storage and a little attention. Under D1 (Antifragility, weight 9) the reversible
error is the one to prefer.

**Binding instruction for classification:** every DELETE row must state which of A / B / C
applies and why it is C. A DELETE row that cannot rule out A and B is an **ADD** or an
**INVESTIGATE**, never a DELETE. "No references found" is evidence for none of the three
on its own.
