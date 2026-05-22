# T-1987 Review A5 — Adversarial Scope Review (red team)

**Reviewer:** isolated TermLink worker `reviewer-A5-adversarial`
**Date:** 2026-05-22
**Subject:** arc-007 watchtower-redesign inception (T-1987) + 7 child slices (T-1988–T-1994)
**Mandate:** find what the inception got wrong; propose a smaller scope if warranted; commit to ONE verdict.

> The parent agent is bullish and wrote a GO. This review exists to find the holes. It does **not** transition any task.

---

## 0. Headline finding (read this first)

The design bundle is real, high-quality, and the user genuinely wants the work. **But the arc as filed has five structural defects that the framework's own rules predict will produce another open-forever umbrella arc:**

1. **It is an umbrella inception** — exactly the shape CLAUDE.md §Task Sizing forbids ("One inception = one question … umbrella inceptions create all-or-nothing decisions").
2. **S0 (the mandated first slice) delivers zero user-visible value** and is on the critical path of everything.
3. **`inception_decisions:` is absent** — the G-066 prevention mechanism, built precisely for multi-deliverable GOs, is not used on a 7-deliverable GO.
4. **S4 and S6 are each 6 and 4 tasks wearing one task's clothing.**
5. **The stated justification (drains the 75+ approvals queue) is causally unsupported** and arc-006 (value-prioritisation) already owns that bottleneck.

Verdict: **GO-with-adjustments** (§10). The adjustments are not cosmetic — without them this arc joins a cohort with a **0% close rate** (§7).

---

## 1. Does the inception capture the user's real intent?

### What the user actually said (verbatim, `chats/chat1.md`)

- Brief (L9): *"i want to greatly improve the visual aesthetic, the user interactions, navigation structure and consitent display of this tool."*
- Density (L52): *"Compact — maximize info per screen, small type, tight rows."* **One** density.
- Tweaks (L59): *"A few essentials (theme, accent, density)."* **A few.**
- Pain point (L60): *"menu navigation."* (Two words. No elaboration.)
- The pivot (L151): *"idea can the styles, colors, navigation pattern be selectable?"*
- Discoverability (L243, L288): *"why am i not sseing teh preview anymore" / "it not rendeing."*

### Where the inception is faithful

The interaction inventory (L57) maps cleanly onto the slices — inline edit, bulk actions, ?-overlay, drag-reorder, side-panel detail (movable to sides/bottom), filter chips, ⌘K, inline approve/reject all appear in S3/S4/S6. The pivot to a runtime-pickable Appearance screen is correctly identified as load-bearing. **This part is good work.**

### Where it OVER-builds (proposes things the user did not ask for)

| Inception ships | What the user actually said | Verdict |
|---|---|---|
| **3 density tiers** (compact/cozy/comfortable) as a font-size + spacing scale system (S0) | *"Compact"* — a single density | **Fabricated axis.** The user picked one density. The 3-tier system is invented by the inception. **Worse: the design source has no density-tier spec at all** — `foundations.jsx` hardcodes `fontSize: 13 / 36 / 10` etc. There is no compact/cozy/comfortable scale anywhere in the 488 KB bundle. S0 promises to build a system that was never designed. |
| **6 palettes × 6 type pairings × 3 nav × 3 density**, all independently selectable | *"A few essentials (theme, accent, density)"* + later *"can styles/colors/nav be selectable?"* | **Partial over-build.** The pivot justifies *presets* + a *picker*. It does not justify full independent-axis combinatorics. The user's mental model is "click a preset, tweak a couple of things" — not a 648-cell parameter space (§6). |
| **Live activity ticker via SSE or polling** (S6) | *"Live activity feed (subtle animations on updates)"* in a 10-item interaction wishlist; ambient strip = *"Decide for me"* | **Heaviest over-build.** This is a one-line wish that the designer **never mocked** — `grep` across the entire bundle finds zero `live-activity / ticker / SSE / EventSource`. S6 proposes a real-time push subsystem from a wish with no design, no spec, no acceptance shape. |

### Where it UNDER-delivers (user asked, slice is thin or silent)

- **"Inline approve/reject without leaving Tasks page"** (L57) — the user explicitly wanted approve/reject **on the Tasks page**. S3 puts inline approve/reject on `/approvals`, S4 redesigns `/tasks`, but no slice wires approve/reject *into the tasks surface*. The exact phrasing the user used is split across two slices and the cross-page action is lost.
- **"Breadcrumbs everywhere"** (L52) — named once in S2's description, no AC, no spec for what the breadcrumb trail computes on dynamic routes.
- **"Pinned/favorited pages"** (L52) — S2 says "user can star pages" in one clause; persistence shape, where stars live (the per-user YAML?), and cross-page surfacing are unspecified.

**Bottom line:** the inception is faithful on interactions, over-builds on the foundation axes (density tiers especially — a system with no design source), and under-specifies three things the user named explicitly.

---

## 2. Is S0 the right starting slice?

**No. S0 is the wrong first slice on value-delivery grounds, and the inception even admits it is value-less.**

S0 (T-1991) is "CSS custom properties + import, no page-level edits in this slice" (T-1991 description, L13). By construction it changes **nothing the user can see**. The slice rationale table grades S0 risk "Low — purely additive CSS" — which is another way of saying "delivers nothing observable."

The arc's own `headline_mechanic` is: *user opens /settings/appearance → picks a preset → re-themes instantly → persists → re-loads another page and sees it applied.* That mechanic cannot fire until **S0 + S1 + (at least one themed page)** all exist. So under the filed plan, the **first user-perceivable value lands after three slices** — and in a framework where arcs sit open for 18–21 days (§7), "value after slice 3" is a structural risk, not a sequencing detail.

**Argument for re-ordering — collapse S0+S1 into one thin vertical slice:**

A walking skeleton — *one* palette fully tokenised + the Appearance picker with the 6 presets + the cockpit (only) re-theming live — would:

1. Fire the headline mechanic at the **end of slice 1**, not slice 3.
2. Validate **A3** (CSS-var swap performance) *in the context that matters* (a real re-theme triggered by the picker), instead of an abstract `:root` toggle with no consumer.
3. Give the human something to react to before 5 more slices are committed — directly de-risking **A4** ("presets may be wrong-shaped").

S0-as-infra-first optimises for "tokens are clean before anyone uses them." That is engineer-comfort ordering, not value ordering. **The thin vertical slice is strictly better for an arc whose whole point is a user-facing re-theme.**

---

## 3. Slice independence audit

The dependency graph (research artifact L104–117) claims `S0 → S1,S2,S3,S4,S5,S6`. **Two of these edges are constructed, not real.**

### S1 is not downstream of being a prerequisite — it is the headline, mis-drawn as a hub

Every page slice (S3/S4/S5) lists "Depends on S0+S1+S2." **S1 (the picker) is not a hard dependency of a page redesign.** A page can adopt foundation tokens (S0) and render under a *fixed default* theme with no picker in existence. The picker only lets the user *change* the theme; it is not required for a page to *use* tokens. So the true critical path is **S0 → {pages, nav}**, with **S1 running in parallel**. The graph inflates the headline deliverable into a blocking hub, which makes the arc look more serial (and longer) than it is.

### S5 (Fabric + Arcs) is largely parallel-shippable

S5's structural work — `/arcs` filter chips, subsystem rail on `/fabric`, node-detail panel — does **not** need S0. The /arcs page is custom templates; restructuring it is independent of the token layer. Only Fabric's *Cytoscape theming* depends on S0 (and on A6 being verified). So S5 splits into:
- **S5-structure** (rail + node panel + arcs chips) — parallel to S0, ship anytime.
- **S5-theming** (Cytoscape reads `--wt-*`) — depends on S0 + A6.

If S5-structure keeps its current inline styles, it is **off the critical path entirely**. The inception treats S5 as a leaf waiting on S0; half of it is a root.

**Consequence:** the real critical path is shorter and wider than drawn. That is good news the inception didn't claim — and it strengthens the case for parallelising rather than the strict S0-first serialisation.

---

## 4. Slice size audit

### S4 (T-1992) is six tasks

The description lists: (1) side-panel detail, (2) dock controls (left/bottom/fullscreen/close = 4 positions), (3) drag-to-reorder kanban, (4) inline edit on status/owner/horizon, (5) saved-view filter chips, (6) bulk-action floating bar. The research artifact *itself* grades S4 "Larger than any other page slice" and pre-emptively defers drag-reorder (risk table, L145). **When the plan already contains a contingency to drop a feature from a slice, the slice is too big.** Split:
- **S4a** — side-panel detail (with dock controls) + inline edit. (The high-value, self-contained core.)
- **S4b** — drag-reorder + bulk-action bar + saved-view chips. (The riskier, Sortable.js-dependent layer.)

### S6 (T-1993) is four cross-cutting systems

(1) ⌘K palette spanning all entities with fuzzy match, (2) ?-shortcuts overlay, (3) bulk-action contract via `data-bulk-target`, (4) live activity ticker via SSE/polling. These share nothing but the word "interaction." ⌘K alone (a global keyboard layer + cross-entity fuzzy index — "first time the framework has a global keyboard layer," per the slice rationale) is a multi-session task. The live ticker is **infra of a different kind** (server push, connection lifecycle, reconnect). Split:
- **S6a** — ⌘K + ?-overlay (the keyboard layer; highest user value).
- **S6b** — bulk-action contract (cross-cutting; coordinates with S3/S4b).
- **S6c** — live activity ticker — **or defer entirely** (§6).

Bundling ⌘K (high value) with the ticker (low value, undesigned) means the ticker's infra risk can sink the slice that contains the single most-requested interaction.

---

## 5. What's missing entirely

Cross-checking the chat's interaction inventory and standard control-plane expectations against S0–S6:

| Gap | Status in inception | Severity |
|---|---|---|
| **Density font-size table** — the actual numbers | S0 promises "font-size + spacing scale multipliers"; **no values exist in design source or task** | High — the user's *primary* stated preference (compact) has no concrete spec |
| **`prefers-reduced-motion`** | Not mentioned anywhere | High — the arc adds a live ticker + "subtle animations"; shipping motion with no reduced-motion path is an accessibility regression |
| **Accessibility generally** (contrast ratios across 6 palettes × dark, focus rings, keyboard-nav order) | Zero mention | High — 6 palettes × 2 modes = 12 colour systems with no contrast budget; ⌘K/keyboard layer with no a11y spec |
| **Quiet mode** (disable the live ticker) | Not mentioned | Medium — a control plane must let the operator silence ambient motion; without it the ticker is a liability |
| **Saved-view shareable URLs** | "Saved-view chips" yes; shareable/bookmarkable URL no | Medium — the design's Appearance footer has "Share preset"; the chat implies shareable views; not specified |
| **Breakpoint behaviour** | Mobile "out of scope" — but what happens when a desktop window narrows? | Medium — "out of scope" ≠ "defined degradation"; undefined reflow is a real bug surface |
| **Print stylesheet** | Not mentioned | Low — minor for a control plane |

The accessibility omission is the serious one: this is a **net-new design system** (12 colour systems, a global keyboard layer, motion). Retrofitting a11y after 6 slices ship is the expensive path.

---

## 6. What's over-scoped

### Live activity ticker — heaviest over-scope

A real-time push system (SSE or polling, per T-1993) for a tool the human reviews on their own cadence. It is **undesigned** (zero bundle references), built from a one-line wish, and the user said *"Decide for me"* on the ambient strip — i.e., explicitly delegated, not demanded. **Recommend: cut to S6c and defer, or downgrade to a dead-simple "N changes since you loaded" badge (polling on navigation, no push).**

### Combinatorial testing surface is intractable

6 palettes × 2 modes × 6 type pairings × 3 nav × 3 density = **648 combinations** (324 if you ignore light/dark). Every child slice touches a render surface and so carries a `[REVIEW]` Human AC (T-1766). **No human can visually verify 324–648 combinations.** The only combinations that *need* human verification are the **6 presets** (the curated, named entry points). Recommendation: the [REVIEW] ACs must scope to "the 6 presets render correctly on light+dark"; arbitrary off-preset axis combinations are best-effort/contract-tested, not human-reviewed. Without this, the render-surface gate is either rubber-stamped (defeating its purpose) or blocks forever.

### Bulk-action contract is cross-cutting infra

"Pages opt in via `data-bulk-target`" (T-1993) is an infrastructure change consumed by S3 (approvals) and S4b (tasks). It is correctly cross-cutting, but it should be **its own task (S6b) sequenced before its consumers**, not buried in the interactions grab-bag — otherwise S3 and S4 each invent their own bulk pattern and the "contract" is retrofitted.

### 3 density tiers (repeat from §1)

The user asked for one density (compact). The 3-tier system has no design source. Over-build. Ship compact; add cozy/comfortable only if a user asks.

---

## 7. Pattern match against past failures

### G-062 (framework-blindness — "shipped" before fresh-substrate behavioural verification)

G-062 status `watching`; signature is *"code-complete, behaviorally unverified, policy unconsulted,"* observed across **three independent arcs over five weeks**. Which T-1987 ACs would catch G-062-class drift on *this* arc?

- **Arc level: defended.** `fw arc close` requires `--demo` (G-062 mitigation, §ACD). The arc's `headline_mechanic` is concrete and behaviourally observable ("picks a preset → re-themes → re-load another page → same theme applied"). Good.
- **Slice level: NOT defended.** Every child slice currently has **placeholder ACs** (`- [ ] [First criterion]` / `[Second criterion]` — confirmed in all 7 of T-1988…T-1994) and **empty `## Context`**. The only slice-close gate is the render-surface `[REVIEW]` requirement, and those ACs aren't written yet. **G-062 prevention at slice level depends entirely on future AC authoring that has not happened.** A slice can be marked done on a `cargo`/`curl` green + a rubber-stamped [REVIEW] without anyone observing the re-theme on a fresh server. That is the exact G-062 signature.

**This is also a G-020 echo:** seven child build tasks were pre-filed with placeholder ACs. G-020 (pickup-messages-bypass, `mitigated`) is precisely "build task created with placeholder ACs." The build-readiness gate (G-020) will (correctly) block these slices until real ACs replace the placeholders — so the slices are not yet workable, only sketched. That's acceptable for *captured/later* stubs, but it means the inception's claim that "slice decomposition is reviewable as concrete tasks" (GO criterion) is **half-true**: the tasks exist, the *decomposition* is reviewable, but the slices are not yet build-ready.

### G-066 (GO-scope partially shipped — substrate-vs-deliverable conflation at task level)

**This is the most important pattern match, and the inception walks straight into it.**

G-066: T-1442 (inception GO on **3 deliverables**) → T-1443 (work-completed) → only **1 of 3 deliverables shipped**, two silently dropped. The framework's response was the `inception_decisions:` / `unlocks_inception_decision:` machinery (CLAUDE.md §Task System) — making each GO deliverable a machine-readable `{id, text, ships_in}` entry, gate-enforced at close.

**T-1987 has a GO on 7 deliverables (S0–S6) and `inception_decisions:` is ABSENT** (confirmed: `grep -c inception_decisions T-1987 → 0`). The single most relevant prevention mechanism the framework owns — built in direct response to the *identical* failure shape — **is not used on the arc most exposed to it.** Nothing structurally prevents this arc from closing with, say, S5 and S6c silently dropped, declared "shipped." That is G-066, verbatim, at arc scale.

**This is the #1 required adjustment** (§11).

### Umbrella-inception rule (CLAUDE.md §Task Sizing)

> "One inception = one question … 'Umbrella inceptions' that bundle independent explorations create all-or-nothing decisions and coarse progress tracking."

T-1987's title is *"foundations + /settings/appearance + nav restructure + per-page redesigns + interactions"* — five bundled domains. This is the textbook umbrella the rule forbids. The mitigating fact: the *exploration* is already done (the Claude Design bundle), and the inception admits "this inception's role is to anchor the arc" (Exploration Plan, L69). So T-1987 is an **arc-anchor masquerading as an inception** — its real GO question is narrow ("do we adopt the runtime-pickable model?") but it's dressed as a 7-slice all-or-nothing decision. The fix is not to re-explore; it's to **narrow the GO question** (§11).

---

## 8. The DEFER case (strongest form)

**The arc's own justification is its weakest link.** The inception (Problem Statement, L53; DEFER criterion, L149) leans on: *"75+ unrelated tasks are queueing in /approvals — a coherent redesign helps human review throughput, which is currently the bottleneck."*

This causal claim is **unsupported and probably wrong:**

1. The queue is 75+ because **75+ things need decisions**, not because the Approvals page is ugly. Decision *volume* and human *availability* are the bottleneck, not pixel friction. A prettier page with inline approve/reject shaves seconds per decision; it does not reduce the count.
2. **arc-006 (value-prioritisation) already owns this bottleneck** — BVP scoring, `fw bvp rank`, auto-promote (T-1931). The right lever for "75+ queue" is triage/ranking/batch-approve, which is *already an open arc*. A UI redesign is a duplicative, indirect intervention on a problem another arc is purpose-built for.
3. If inline approve/reject genuinely helps, that is a **one-task hypothesis test** on the existing page — not a 7-slice arc. Test the cheap version first.

**Therefore the strongest DEFER:** defer the umbrella arc; spend one task testing whether inline approve/reject on the *current* Approvals page measurably speeds review. If yes, the redesign's throughput claim gains evidence. If no, the justification collapses and the arc is a pure aesthetics want (legitimate, but it must be ranked as such, not smuggled in as bottleneck relief).

**Second DEFER angle:** A4 ("presets may be wrong-shaped") is explicitly unvalidated and there is **no user-research evidence the 6-preset model is right.** The human was *offered* the foundation-only path (Q1 option 2: S0+S1) and *declined* it for full-scope. The adversarial read is that the human over-committed before seeing a single preset re-theme a real page. A thin S0+S1 walking skeleton (§2) validates A3/A4/A6/A7 *and* the preset model for ~⅓ the surface, then the human re-decides the remaining 5 slices with evidence in hand. **DEFER-to-thin-slice is the disciplined path; full-scope-now is the momentum path.**

**Third DEFER angle (risk-loading):** A7 (Pico coexistence) is "Untested" and a NO-GO trigger. If A7 fails, the NO-GO criterion says it forks a Pico-removal arc — and Pico is imported across **30+ templates**, so that fork's blast radius is the entire UI. Committing the full 7-slice plan *before* A7 is verified loads risk onto an unverified assumption. The S0 spike is supposed to check this, which is the right instinct — but it argues for **"spike, then commit the rest,"** i.e., DEFER the downstream commitment until the spike clears.

---

## 9. The NO-GO case (do nothing)

A pure NO-GO is **weak** — the user's brief is genuine and a better-looking, more navigable control plane is a real quality-of-life gain. "Do nothing" ignores a legitimate want.

But a **narrow NO-GO on the arc *shape*** is defensible, and the evidence is the arc base rate:

| Arc | Created | Status (2026-05-22) | Age | Constituents |
|---|---|---|---|---|
| arc-001 dispatch-safety | 05-13 | **closed** 05-20 | 7d | 0 (small) |
| arc-002 embeddings-strategy | 05-04 | in-progress | **18d** | 3 |
| arc-003 orchestrator-rethink | 05-01 | in-progress | **21d** | 31 |
| arc-004 project-shape-resilience | 05-02 | in-progress | **20d** | 6 |
| arc-005 arc-grooming | 05-15 | in-progress | 7d | (tracked via arc_id) |
| arc-006 value-prioritisation | 05-18 | in-progress | 4d | 0 |
| **arc-007 watchtower-redesign** | 05-22 | draft | 0d | 1 |

**Of the arcs with real multi-task constituents (orchestrator n=31, project-shape n=6, embeddings n=3), the close rate is 0%.** The only closed arc (dispatch-safety) had zero constituent tasks tracked. orchestrator-rethink (the closest analogue: a big, multi-slice arc) is 21 days open, has an *agent auto-close attempt that was reverted*, and ≥2 human pushbacks (Default-to-OPEN). **A 7-child render-surface arc is statistically destined to join the open-forever cohort.**

The narrow-NO-GO reading: *don't create another umbrella arc.* Do the two genuinely high-value pieces (S0 tokens + Appearance picker re-theming the cockpit) as **standalone tasks without the arc ceremony**, ship them, and let the human pull the next page redesign when they feel the pain — instead of pre-committing to a 7-slice structure that the base rate says won't close.

I do not adopt full NO-GO (it discards real user value), but the base-rate evidence is the single strongest argument in this review and it directly shapes the adjustments in §10–11.

---

## 10. Final adversarial verdict

# GO-with-adjustments

The design work is real, the headline mechanic is sound and §ACD-compliant, the user wants it, and the interaction inventory is faithfully captured. **But the arc as filed reproduces the exact failure shapes the framework has already paid for (G-066 unguarded, umbrella inception, value-less critical-path-first slice, oversized S4/S6), and its headline justification (drains the approvals queue) is causally unsupported and duplicates arc-006.**

This is not "ship it." It is "ship it after the parent agent makes the §11 changes, and after the human decides with the base-rate and the thin-slice option explicitly in front of them." The thin-slice / DEFER path (§8) is a legitimate alternative I'd put to the human alongside GO — but if the human reaffirms full-scope, the §11 adjustments make the difference between a healthy arc and arc-003 #2.

---

## 11. Concrete actionable list (parent agent: do these before the human decides)

Ordered by severity. Top concerns only.

1. **Add `inception_decisions:` to T-1987 frontmatter — non-negotiable.** Seven `{id, text, ships_in: T-XXXX}` entries, one per slice (S0→T-1991 … S6→T-1993). This is the G-066 prevention mechanism (CLAUDE.md §Task System) and its absence on a 7-deliverable GO is the single biggest structural defect. Without it, slices can be silently dropped and the arc closed anyway — G-066 verbatim.

2. **Re-order to a thin vertical first slice (S0+S1 walking skeleton).** Replace "S0 tokens → S1 picker → page" with: *one* palette tokenised + the 6-preset picker + the cockpit re-theming live. This fires the `headline_mechanic` at the end of slice 1, validates A3/A4 in the real re-theme path, and gives the human something to react to before the other 5 slices commit. Present this to the human as the recommended path *next to* full-scope.

3. **Split S4 and S6.** S4 → S4a (side-panel + inline edit) / S4b (drag + bulk + chips). S6 → S6a (⌘K + ?-overlay) / S6b (bulk-action contract, sequenced *before* S3/S4b) / S6c (live ticker). A slice whose plan already contains "defer this feature if it's big" (S4 drag-reorder) is two slices.

4. **Cut or downgrade the live activity ticker (S6c).** It is undesigned (zero bundle references), built from a one-line "decide for me" wish, and a real-time push system is heavy for a self-paced control plane. Default to deferring it; if kept, downgrade to a poll-on-navigation "N changes since load" badge with a quiet-mode off switch.

5. **Fix the approvals-throughput justification.** Either (a) cite arc-006 (value-prioritisation) as the real owner of the queue bottleneck and re-justify this arc on *aesthetics + navigation* (the genuine, defensible wins), or (b) add a one-task cheap hypothesis test (inline approve/reject on the *current* page) and gate the throughput claim on its result. Do not let "drains the 75+ queue" stand unsupported as the headline reason.

6. **Scope the render-surface `[REVIEW]` ACs to the 6 presets, not the 648-cell space.** When the slices get real ACs, the Human [REVIEW] criteria must say "the 6 named presets render correctly on light+dark" — not "all combinations." Off-preset axis combinations are contract-tested, not human-reviewed. Otherwise the T-1766 gate is unsatisfiable and gets rubber-stamped.

7. **Spec the missing primitives the user actually named:** the **compact density font-size table** (the user's primary density preference currently has zero concrete values and no design source), `prefers-reduced-motion` handling (mandatory once a ticker + animations exist), and per-palette contrast budgets across the 12 colour systems. These are cheap to write now and expensive to retrofit after 6 slices.

---

*No source files, task bodies, or arc YAML were modified by this review. Recommendations only.*
