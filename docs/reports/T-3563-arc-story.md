# T-3563 — An arc should carry its story

Research artefact (C-001). Opened 2026-09-29.

## Dialogue Log

### Segment 1 — operator, verbatim

> Ok, additional thought and I really want you to reflect this and I want you to get
> external consultation, 3 agents. Headline mechanics for our ARC. Describe what our ARC
> is, describe what AEF is, describe how it's used for vendor projects, how we use ARC
> drivers, how we use it to container a feature or an initiative and also do the scoring
> scoping. We derive back on project objectives and goals from the ARC drivers and
> evaluation of ARC is complete and task are complete. So I really think there should be
> way more emphasis on headline of an ARC that describes what it is, what's the
> background, research decisions made, back and forth. All the context fabric that we've
> created in our, often in our inception.

## Findings

### F-1 — The story exists; the arc does not show it

Measured 2026-09-29 across all 20 arcs in `.context/arcs/`:

| | count |
|---|---|
| arcs with an `anchor_task` | 19 |
| … whose anchor is an inception | 14 |
| … whose anchor has a research report in `docs/reports/` | 14 |
| arcs with `design_doc` set | **1** |
| arcs with `decision` set | **1** |

`headline_mechanic`: median 46 words, maximum 165. `description`: median 34 words.

Example headline (continuous-run), which is typical: *"agent crosses the
context-budget threshold without operator relay -> checkpoint.sh fires self-trigger ->
handover + resume via claude-fw -> operator observes multi-cycle continuous session
whose iteration counter, directive, and bounded tier-ceiling are visible in fw resume
status"*. That is a precise demo check, and it tells a newcomer nothing about why the
arc exists or what was decided along the way.

### F-2 — Why the headline is shaped this way

G-062 (T-1667, T-1671) made `headline_mechanic` mandatory and rejects substrate-only
phrasing. Its job is to force a *user-visible, demo-able* claim, so an arc cannot close
on "the substrate is in place". It succeeded at that job. It was never designed to
explain the arc, and nothing else on the arc was either.

External review brief: `T-3563-external-review-brief.md`.

## Agent reflection (written before reading the reviews)

Recorded in chat before any review returned, as an independent fourth view: keep the
headline mechanic as a separate testable claim; put the story *beside* it; derive the
story from the anchor inception rather than retyping it; make one written **objective**
the keystone that drivers, scoring and closure L3 all read (the D-662 BVP judge today
scores tasks against the arc's `description`/`headline_mechanic`, median 34 words, never
written for that job); record evolution as short dated lines, not a log; the main risk is
a mandatory field filled with boilerplate.

## External review — synthesis (three vendors, 2026-09-29)

Verbatim: `T-3563-review-{openai,zai,anthropic}.md`. **Verdicts: amber, amber, amber.**
All three: the operator's direction is right, implemented with the changes below.

### Unanimous (and matching the agent's reflection)

1. **Keep `headline_mechanic` unchanged,** as the sharp, falsifiable demo claim. Do not
   expand it into the narrative; that would blunt G-062.
2. **A written `objective` is the keystone.** Scoped drivers, task scoring and closure L3
   are all judged against it, and it links upward to the project's objectives.
3. **A short, hand-written `purpose`:** what the arc is and why it exists.
4. **Decisions as a curated list,** each with a source link and an active/superseded
   status: pivots and reversals, not a transcript.
5. **Index, don't copy.** The arc summarises and links into the anchor inception; it does
   not absorb it.
6. **Top risk, all three: boilerplate.** Gate *substance*, not presence: word bounds,
   links that must resolve, a reviewer check that rejects template or copy-pasted prose.

### Additions worth keeping

- **OpenAI: agent-drafted text must never silently become authoritative intent.**
  Intent fields (purpose, objective, success criteria) change only with human approval.
  Derived fields flag drift from their sources; they are never auto-rewritten over
  approved content. **Pilot before enforcing.**
- **OpenAI: `success_criteria`** with stable IDs, so L3 assesses each criterion rather
  than asking "were the goals achieved?" in one breath.
- **Z.ai: `non_goals`** as an explicit scope boundary; hard word bounds (purpose ≤25,
  objective ≤40, decisions ≤20 each); `stale_since` set on pivot or scope cut, with
  re-confirmation required at closure.
- **Anthropic: `open_questions`** carried from the inception and kept current.

### Converged structure (agent's consolidation)

| field | written by | bound | job |
|---|---|---|---|
| `headline_mechanic` | human | unchanged | falsifiable demo claim (G-062, closure L4) |
| `purpose` | human (agent may draft) | ≤25 words | what and why |
| `objective` + `supports` | **human-approved** | ≤40 words | the yardstick for drivers, scoring, L3; links to project objectives |
| `success_criteria` | human-approved | stable IDs | what L3 checks, one by one |
| `non_goals` | human | short list | the scope boundary |
| `context` | derived draft, human-approved | 3–6 bullets | background, each bullet linking into the anchor inception |
| `decisions` | curated | ≤20 words each | status + source link; superseded ones kept, marked |
| `open_questions` | carried from inception | — | what is still unresolved |
| `history` | appended | one line per material change, capped | evolution without a log |
| `evidence` | links | — | research report, dialogue log, design doc, demo |

**Rules:** intent fields change only with human approval; derived fields flag
staleness and never rewrite approved text; substance gates, not presence gates; the BVP
judge and closure L3 switch from `description` to `objective`; **pilot on 2–3 arcs
before any enforcement.**

## Dialogue Log — segment 2 (operator, verbatim)

> I'm fine with it, but I don't want everything to land on the human operator. Then get
> external consultation to get it fitted context-wise. Good context, right? You can show
> it to me, but it doesn't have to be too much friction. You need to be able to continue
> independently. Show it to me if I cannot respond. Proceed progress can always correct.

**Decision recorded:** the converged structure is adopted. The reviewers' rule "intent
fields change only with human approval" is replaced, by operator ruling, with
**external-review approval**: an agent drafts, an independent external panel (never the
drafter) checks the draft against its sources, and the operator is shown the result
non-blocking and may correct it afterwards. This is T-3557's principle applied to arcs:
the human for risk, independent agent review for the rest.

**Pilot:** `continuous-run`, `readme-first-run`, `orchestrator-rethink`.

## Incoming peer proposal — 055-agentic-fleet-cockpit (relayed by the operator, 2026-09-29)

055's operator asked for the same thing independently: *"What I still miss in the arc is
arc headlines like goal, objectives, background research materials… All the
conversation we had. This should become an integral part of the arc"*, and after seeing a
first version, *"Why don't I see this on the arc page? It must be right at the top. It
must be easy to find."* 055 built it locally (their T-341, T-342) and sent a report
(their `docs/reports/T-343-aef-arc-dossier-report.md`, pickup P-005). Treated as a
proposal, not an instruction; claims verified against our code where cheap:

| 055 claim | verified here |
|---|---|
| the arc page does not render `headline_mechanic` | **TRUE.** 0 occurrences in `web/templates/arc_detail.html`. The field G-062 makes mandatory has never been shown to the operator on the arc page. |
| the arc page does not render scoped drivers' rationale | **Stale for us**: our template renders `scoped_drivers` and `rationale`. |
| `approve-driver` accepts only human-attesting flags | **Stale for us**: T-3429 added a reviewer-gated default path (`--all-reviewed`, `approved_by: reviewer:…`). |
| `render_markdown_safe` lacks the `tables` extra | not checked (no `extras` in `web/shared.py` by grep) |

**What 055 adds to T-3563's design:**
1. **A dossier document per arc** (`docs/arcs/<id>/README.md`, ten fixed sections: headline
   and goal, background, drivers, scope, decision trail, research library, operator
   dialogue log, open questions, milestones and tasks, closing). This complements our
   field structure rather than competing with it: the YAML fields are the short,
   machine-read index that drivers, scoring and closure use; the dossier is the long form.
2. **"Purpose" block first on the arc page**, above stats and task lists: headline, goal,
   objectives, drivers with rationale, and the dossier. Without this, the new fields are as
   invisible as `headline_mechanic` already is.
3. **Anti-rot:** a test that fails when a task tagged into the arc is not mentioned in its
   dossier, or when a research path is missing.
4. **Assemble, don't retype:** the decision trail from member tasks' inception decisions,
   driver approvals and status changes; the research library from members' `docs/reports`.
5. **Extend C-001's dialogue log from inceptions to arcs**, captured as the operator speaks.
6. **Close gate:** `fw arc close` requires a complete dossier, as it requires demo evidence.

**Consequence for scope.** T-3563's build is three parts, not one: (a) the arc fields from
the three-vendor review, now being piloted; (b) the dossier plus the anti-rot test; (c) the
arc page's Purpose block. Part (c) is a render surface.

## Operator's target, 2026-09-29: 055's arc-007 page

Operator, verbatim: *"http://192.168.10.107:3050/arcs/arc-007 look at this this how i want
it to be"*. Page structure, extracted 2026-09-29 (top to bottom): **Purpose** (h2:
headline as a blockquote; approved drivers table: driver, weight, what it means and how
it is measured) → **Dossier** (`<details>`, ten sections: 1 Headline and goal · 2 Background
· 3 Value drivers and gates · 4 Scope · 5 Decision trail [when, decision, record,
evidence] · 6 Research library [artifact, question it answers, round, reviews] · 7 Operator
dialogue log · 8 Open questions · 9 Milestones and tasks · 10 Closing the arc) → then BVP
signals, scoped-driver management, reports and evidence, constituent tasks, ACD check.

This settles part (c) of the build: the target is 055's layout. Our pilot fields already
supply sections 1, 2, 4, 5 and 8. Missing: the research library (6), the operator dialogue
log (7), and the page itself.
