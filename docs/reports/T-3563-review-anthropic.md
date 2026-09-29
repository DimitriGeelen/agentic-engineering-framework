# T-3563 external review — anthropic

Reviewer: Anthropic Claude Sonnet 5 (claude -p, tools disabled; same vendor as the builder). Run 2026-09-29, isolated, input `T-3563-external-review-brief.md` only. Verbatim.

---

# External review — arc self-explanation (T-3563)

## 1. What an arc should carry

Add a small `story` block to the YAML, distinct from the scoring/closure fields:

- **`purpose`** (2–4 sentences, hand-written): why this arc exists, in the operator's terms — the problem, not the mechanism. This is what `description` currently tries and fails to be at 34 words.
- **`context_summary`** (~150 words, derived): what was researched and decided before work started — pulled from the anchor inception's research report and dispositions, not re-argued.
- **`key_decisions`** (list of `{decision, rationale, date, source}` — pointers, not prose): the handful of choices that shaped the arc's shape, each linking back to a decision record or inception disposition. Not a transcript.
- **`open_questions`** (carried from inception, updated as resolved): what's still unresolved, so a cold reader knows what's deliberately unfinished vs. forgotten.
- **`objective`** (one sentence, written): the goal the scoped drivers and closure L3 are judged against — see Q4.
- Keep `headline_mechanic` exactly as is.

**What should not be on it:** the dialogue log verbatim, the full research report, a narrative essay, or anything that duplicates the inception rather than pointing to it. The arc is an index into the story, not the story itself. If `purpose` and `context_summary` together exceed ~250 words, that's a smell — it means someone is pasting the inception instead of summarizing it.

## 2. Headline versus story

Keep them separate. The headline is a falsifiable, demo-able claim — it exists precisely to stop arcs closing on vibes (G-062's whole point). Folding narrative into it would soften that sharpness back into the "substrate is in place" failure mode it was built to prevent. The story fields answer "why/what was decided"; the headline answers "does it work." Losing the split loses the enforcement teeth on one side or the readability on the other — keep both, small and adjacent.

## 3. Derived or written?

Both, with a clear division of labor, not a blend:

- **`context_summary`: derived**, generated from the anchor inception at arc-creation time (and re-generatable on demand, not silently auto-refreshed — regeneration should be an explicit action logged like any other edit). Staleness is contained because it's explicitly a snapshot of *origin*, not of current state — it doesn't need to track scope changes, only explain why the arc started as it did.
- **`purpose` and `objective`: written by hand**, because compressing "why does this matter" into one sentence a human stands behind is exactly the judgment a summarizer shouldn't be trusted with — it's also the thing closure L3 depends on, so it needs an accountable author.
- **`key_decisions`: written, but each entry must carry a `source` pointer** (task id / decision record) that a gate can verify resolves to something real. This stops boilerplate decisions with no backing evidence — an automated check can reject a `key_decisions` entry whose source field is empty or points nowhere.

Drift is handled by scope, not by process: derived content is allowed to age because it describes origin; written content is small enough (one sentence + a handful of decision pointers) that drift is cheap to spot on review rather than needing machinery to detect it.

## 4. Goals and drivers

Add `objective` (one sentence, written, mandatory) sitting between project objectives and the arc. Require:
- Each `scoped_driver`'s rationale to reference the `objective` explicitly (a reviewer check: does the rationale text relate to the stated objective, not just exist).
- Closure L3 to quote `objective` verbatim in its pass/fail, not a paraphrase — this makes "goals achieved" checkable against a fixed target instead of whatever the anchor's recommendation happened to say.
- `objective` to itself reference which project objective it serves (a project-objectives file/id, even if informal) — this is the one place true upward traceability needs to be forced, since today nothing connects arc to project level at all.

## 5. Evolution

Don't log every change. Append to `key_decisions` only for reversals/pivots that change scope or approach — i.e., the same bar as "would a cold reader be confused without this." Add one field: `superseded` (boolean/date) on any `key_decisions` entry that a later one overrides, so the list stays a small ordered set of "what we believed when" rather than growing monotonically. Don't build a changelog; git history on the YAML file already is one, and `fw` tooling can diff it if someone needs the raw history.

## 6. For agents specifically

An agent with a limited context budget needs the whole story block to fit in a few hundred tokens and be structurally predictable (fixed keys, not prose paragraphs it has to parse). Practically: `purpose` + `objective` + `headline_mechanic` should be readable as a 4–6 line block an agent can load without touching the inception at all; `context_summary` and `key_decisions` are the next tier, read only when the agent needs deeper background (e.g., before proposing a scoped driver or judging closure). Structure it so partial reads are safe — an agent that only reads `purpose`/`objective`/`headline` should still get a coherent, non-misleading picture, not a fragment that implies something false.

## 7. Failure mode

The obvious one: `purpose` and `objective` become one-sentence boilerplate ("improve reliability of X") filled in to pass a gate, exactly like `description` today (median 34 words, evidently already not doing its job). Mitigate by making the gate check *relationship* rather than *presence* — e.g., reject if `objective` text also appears verbatim as a global driver rationale elsewhere (a sign of copy-paste), or spot-check by requiring `key_decisions` to have at least one entry with a real `source` before an arc can leave "draft" status. A field nobody can fail is a field nobody thinks about — the check has to occasionally bite.

---

```
VERDICT: amber
GUIDANCE: (1) Split "story" into derived-vs-written fields per Q3 rather than one generic "narrative" field — undifferentiated prose is what will rot. (2) Make `objective` mandatory and wire it explicitly into scoped-driver rationale and closure L3, since that's the concrete mechanism the operator is actually complaining is missing. (3) Cap size — story fields must summarize, not absorb, the inception; add a reviewer check that rejects arcs where written fields look copy-pasted from the anchor. (4) Do not merge the headline into the narrative — keep the sharp, testable claim intact.
PROPOSED STRUCTURE:
  - headline_mechanic (unchanged) — the falsifiable demo claim
  - purpose (written, 2–4 sentences) — why this arc exists, human-authored
  - objective (written, 1 sentence) — the goal drivers/scoring/closure are judged against, links to a project objective
  - context_summary (derived from anchor inception, regenerated explicitly) — why it started, condensed
  - key_decisions (written list, each with source pointer + optional superseded flag) — pivots and reversals only
  - open_questions (carried from inception, updated) — known unresolved items
  - anchor_task, scoped_drivers, demo_evidence, design_doc, decision (unchanged)
TOP RISK: the new fields become boilerplate exactly like `description` is today, unless at least one of them is gated by a check that verifies substance (a real source link, a match to the stated objective) rather than mere presence.
```
