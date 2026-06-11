# T-2143 — Routing-Recursion RCA

> **Status:** Inception, exploration in progress. Recommendation pending evidence walk-through.
> **Filed:** 2026-05-31, mid-session
> **Trigger:** operator pushback after 4 rounds of routing failure in a single chat thread on T-2139's Human AC.
> **Parent arc:** `inception-review-loop` (T-2138 V1 keystone arc).

## TL;DR

In a single conversation thread on T-2139 (the T-2138 V1 keystone task), I authored, restructured, rewrote, and trimmed the same Human AC **four times**, walking into a progressively deeper version of the same routing trap each round. The structural gates that exist for this class (T-1878 default-bias, T-1947 prose-mismatch detector, T-2139's own at-handoff blocking gate) all fired correctly at structural surfaces — but none of them looked at **audience**. The agent reflexively routes "subjective judgment" → `[REVIEW]` (Human AC) without first checking *who the AC's question is being asked about*. When the audience is itself another agent, asking the operator is structurally wrong, and yet `[REVIEW]` is exactly the prefix the agent reaches for.

This RCA sits inside the larger T-2138 → T-2140 → T-2141 arc and adds a **fifth class** of homework-like routing failure to the catalogue.

## The 4 Rounds (Evidence)

The recursion happened in one continuous chat session, after a `/resume`. All four rounds were on **T-2139's Human AC** — the keystone task that itself ships the framework's enforcement gate against the parent class. Sources in `.tasks/completed/T-2139-transition-time-blocking-gate--review-li.md` revision history (commits `8880e0ab`, `10299add`, `cd4d321a`, `069f64d4`, `37416f84`).

### Round 1 — bundled `[REVIEW]` with 5 sub-clauses
Original AC bundled five tick-clauses under one `[REVIEW]` checkbox: class name present, URL pattern correct, env-var bypass named, CLI-flag bypass named, **tone reads coaching**. The first four are deterministic structural checks (`[REVIEWER]`-class or Agent-AC-class). The fifth is genuine human taste.

- **Surfacing event:** operator after `/resume`: *"are these really operator reviews?"*
- **Detection by:** human noticing the routing mismatch directly. No gate fired.
- **Fix:** T-2142 — decompose into 4 Agent ACs + 1 Human AC (tone only).

### Round 2 — tone-only but jargon-y
After decomposition the AC was correctly scoped to tone, but the prose assumed framework-internal vocabulary the operator didn't have ("AC8-AC11 already pre-verified", "judge rhythm/voice", code-fenced stderr without captions).

- **Surfacing event:** operator: *"not exactly understand what and where i need to review"* (this was actually round 1.5 on a prior session — round 2 here is the rewrite).
- **Detection by:** human pushback on clarity, not on routing.
- **Fix:** rewrite as self-contained 4-section brief.

### Round 3 — self-contained but excessive
The 4-section brief (Context → What you're looking at → How to evaluate → What happens after) was self-explanatory but ~50 lines of Steps for a single-judgment AC.

- **Surfacing event:** operator: *"ok waaaaay to much text in human AC"*.
- **Detection by:** human noticing volume mismatch (judgment is binary, prose was essay).
- **Fix:** trim to ~8 lines + captioned renderings.

### Round 4 — audience disqualifies Human verification entirely
The trimmed AC reads: *"The validator's error block reads well enough that an agent who trips it fixes the task instead of fighting the gate."*

The **audience of the error block is agents**. Agents trip the gate, agents read stderr, agents either fix or fight. The operator has no operational context for what reading framework stderr feels like mid-handoff. Asking the operator to evaluate prose-targeted-at-agents is the routing trap one level deeper: it's not just "subjective" but **subjective from the wrong perspective**.

- **Surfacing event:** operator: *"is this meant to surface to operator at all ??!!! are we back to our routing logic ???"*
- **Detection by:** human, again, by reading the AC text and noticing the audience mismatch.
- **Fix:** **pending this RCA**.

## 5-Whys

1. **Why did the AC end up audience-mismatched?**
   Because I framed the tone question as "does an agent fix or fight" — which makes agents the implicit subject — yet routed the judgment to `[REVIEW]` (Human).

2. **Why did I route an agent-audience question to Human?**
   Because the routing heuristic I applied is single-axis: *is the answer subjective? → Human*. Tone judgment is subjective, ergo `[REVIEW]`. The axis "*who is the answer for?*" was never checked.

3. **Why is the routing heuristic single-axis?**
   Because CLAUDE.md's *AC Classification Guidance* and the T-1878 default-bias rule both phrase the question as "Is the Expected clause grep-able / file-exists / structural?" — a property of the **check**, not the **audience**. The agent inherits that frame and applies it transitively. The Three Human-AC prefixes table (T-1811) adds a second axis (*who can verify?*) but only across `[RUBBER-STAMP]` / `[REVIEWER]` / `[REVIEW]` — not "is the audience for this question even the human?".

4. **Why didn't T-1947's prose-mismatch detector catch round 4?**
   T-1947 scans for signal vocabulary (*"reads clearly, tone, voice, rhythm"*) to flag `[REVIEWER]` ACs that smuggle in prose judgment — its inverse-direction gate. Round 4 is the *correct* direction of routing for prose-tone — except the audience disqualifies it. T-1947 doesn't read the AC's *subject* (the validator's error block is "for agents"); it only reads the *predicate* (does the AC's Expected demand human taste).

5. **Why didn't T-2139's own gate catch this?**
   T-2139 ships the blocking gate against review-link homework (vague URLs). It catches handoff-link mis-construction — a surface-level routing failure. The class above it (which AC should the routing target) isn't homework about URLs — it's homework about audiences. Different layer, no gate covers it.

## Bigger-Picture Context (where this fits in the arc)

`inception-review-loop` arc tracks the recurring inception/review handoff failures:

| Slice | Class caught | Surface |
|---|---|---|
| T-2030 | wrong URL CLASS (review vs inception confusion) | renderer-side 302 forgiveness |
| T-2050 | review-link homework (advisory WARN) | static validator (pre-gate) |
| T-2138 V1 = T-2139 | review-link homework (at-handoff BLOCK) | `lib/review.sh:emit_review` |
| T-2138 V2 = T-2140 | review-link homework (catch-before-handoff) | reviewer static-scan catalogue |
| T-2138 V3 = T-2141 | review-link homework (doc surface) | CLAUDE.md/AGENT.md sweep |
| **T-2143 (new)** | **AC routing audience-mismatch** | **author-time check, not yet shipped** |

T-2143 is the **5th class** in this arc. It's not about *which URL* the handoff names — it's about *whether the AC should exist at all* (and if so, in which section). Same family (handoff-quality), different axis (audience routing vs link construction).

The parent arc's T-2138 GO chose *Candidate E + B + Q3-both*: transition-time gate + reviewer catalogue + doc sweep. T-2143 surfaces a **gap in Candidate E's scope** — E targets review-link homework specifically; it doesn't generalise to "audience-mismatched AC". The structural remediation for T-2143 needs its own decision.

## Candidate Remediations

### A. Delete the offending AC class; close T-2139 on agent side
**What:** Remove T-2139's Human AC entirely. AC8-AC11 (structural) plus T-2140 (V2 reviewer catalogue entry, already filed) cover the class. Agent self-tests the prose; if it reads wrong, agent reworks before handoff.

- **Pros:** Eliminates the routing question for THIS task immediately. Zero new gates. Honours the principle that agent-audience prose is agent self-eval work.
- **Cons:** Doesn't prevent the *next* author-time recurrence. Doesn't add a structural rail.
- **Effort:** ~2 minutes (delete + commit).
- **Coverage:** local to T-2139.

### B. Author-time audience check at AC creation
**What:** Extend the AC author-time guidance in CLAUDE.md and/or add a static-scan rule: "If the AC text uses agent-as-subject phrasing (`agent who…`, `agent reads…`, `agent trips…`) AND is prefixed `[REVIEW]`, surface a CONCERN at task close." The reviewer catalogue (T-2140 territory) is the natural home.

- **Pros:** Catches the class for future tasks, not just T-2139. Pattern-based — fits the existing T-1947 / T-1878 family.
- **Cons:** Requires designing the heuristic (false-positive risk: not all "agent who…" phrasings are audience mismatches — some are talking ABOUT the system to the operator). Needs corpus walk-through.
- **Effort:** small spike to design heuristic + bats fixture; ~2-3h to ship.
- **Coverage:** future authoring across all tasks.

### C. Extend the Three-Prefix table to include an "Audience" column
**What:** Update CLAUDE.md's `[RUBBER-STAMP]` / `[REVIEWER]` / `[REVIEW]` table to add a fourth axis question: *"Is the answer being asked **about** the human's experience, or about an agent's experience?"* If agent-audience → not Human.

- **Pros:** Documents the missing axis explicitly. Catches the class at the moment the human reads the rule (T-1878-style author-time default-bias).
- **Cons:** Documentation only; no structural gate. Agents that don't re-read CLAUDE.md miss it. Effective only as a co-fix with B.
- **Effort:** ~30 minutes doc edit + 1-2 worked examples.
- **Coverage:** awareness/governance layer.

### D. Combination: A + B + C
Delete T-2139's Human AC now (A), file a small build task for the static-scan rule (B), update CLAUDE.md (C). Same shape as T-2138's GO (Candidate E + B + Q3-both).

- **Pros:** Closes the immediate symptom AND the class. Mirrors the proven arc closure pattern.
- **Cons:** Adds a build task to the queue. ~3-4h total.
- **Coverage:** local fix + future prevention + governance.

## Recommendation

**DEFER** — pending operator preference between A/B/C/D. The structural decision (how aggressively to gate this class) is an operator call, not an agent call. **D** is the analogue of T-2138's GO, but **A** alone is defensible if the operator judges the class rare enough not to warrant another structural rail.

If operator picks D, this inception decides GO with three child tasks (one per A, B, C). If operator picks A only, this inception decides GO with one child task (the AC deletion) and notes B/C as deferred. If operator picks NO-GO, T-2139's Human AC stays — but then the routing question is settled by operator sovereignty, not by structural enforcement.

## Dialogue Log

### 2026-05-31 — verbatim operator pushback

> *"are these really operator reviews ?"* — round 1 surfacing
>
> *"not exactly understand what and where i need to review"* — round 2 (prior session)
>
> *"ok waaaaay to much text in human AC, and blocvk now is [Reviewer CONCERN screenshot]"* — round 3
>
> *"ok notice something !!!! :: The validator's error block reads well enough that an agent who trips it fixes the task instead of fighting the gate. --> is this meant to surface to operator at all ??!!! are we back to our routing logic ???"* — round 4
>
> *"PLease incept RCA on why this heppendf and how it with in the bigger picture we are remediationg now"* — this inception.

### Agent self-reflection

Each round I claimed to have fixed the routing — and each round the human had to identify a new dimension I'd missed. The pattern is the agent applying a routing heuristic that's **narrower than the routing problem**: I check whether the check is structural (T-1878), whether the prose reads jargon-y (T-1947), whether the volume matches the judgment (round 3) — but the heuristic never asked *"is the question even directed at the human?"*. This is the kind of gap that an inception is designed to surface, because the local fix (trim, rewrite, restructure) doesn't address the structural framing.

## Open Questions

1. Is the audience-routing axis general enough to warrant a permanent rule, or is T-2139 (a meta-task whose subject is agents) a special case?
2. If we ship Candidate B (static-scan), what's the corpus of "agent-audience" phrasings? Spike on `.tasks/{active,completed}/T-*.md` would tell us.
3. Should this be a sibling of T-2140 (V2 catalogue entry) or its own build task? Sibling is cheaper (one catalogue entry for two pattern classes) but conflates two routing-failure dimensions.
