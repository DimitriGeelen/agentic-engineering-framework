# T-2137 — Multi-option AC pattern: choice spawns child inception

**Type:** Inception research artifact (per CLAUDE.md §Inception Discipline C-001 — created BEFORE conducting research).
**Arc:** `arc-008` (`inception-review-loop`). Sibling to T-2101 (operator-feedback channel, GO'd 2026-05-30, V-slices stalled), Q1 (template philosophy), Q2 (frictionless instructions), Q3 (reviewer pre-flight).
**Surfaces from:** T-1776 close on 2026-05-31 (commits `625557f1` + `9f08aa42`).
**Status:** DEFER pending operator dialogue. Recommendation will be refined once the scope question below is answered.

---

## Why this artifact exists

T-1776 (`fallback-workflow contract gap`) shipped 2026-05-09 with a single `[REVIEW]` Human AC:

> **#H1: Choose resolution direction.** Steps:
> 1. Read `docs/reports/T-1776-default-workflow-termlink-gap.md`
> 2. **Pick one of three options:** A) Build TermLink Python primitive; B) Add shell adapter; C) Change `default.yaml` worker_kind.
> 3. File a follow-up build task for the chosen direction; close this one as DEFER if option C is picked.

What actually happened over the next 22 days:

| When | What | Where it landed |
|------|------|-----------------|
| 2026-05-09 | T-1776 filed with A/B/C Human AC | `.tasks/active/T-1776-*` |
| ~2026-05-09…05-12 | Operator picked **option A** | Chat-only, never structurally captured |
| 2026-05-12 | T-1797 shipped TermLink Python primitive | Commit `df468c2f` references T-1776 in commit text |
| 2026-05-27 | T-1798 added audit-time prevention | Commit `cf480359` |
| 2026-05-09 → 2026-05-31 | T-1776 sat `started-work` with #H1 unticked | CTL-029 class (T-2055 detector) |
| 2026-05-31 | T-1776 closed by event (this session) | `625557f1` + `9f08aa42` |

**The pattern:** any `[REVIEW]` AC of the form *"Pick one of A/B/C, then file a follow-up"* is doing the work of an inception inside a single checkbox. The structural cost:

1. The pick is invisible — operator's choice only appears in chat or in commit-message text, not in the parent task's frontmatter or body.
2. The pick is not addressable — no follow-up task ID auto-links to the parent AC.
3. CTL-029 inevitable — parent sits completable-but-not-completed until someone manually closes it because the AC's wording ("File a follow-up build task for the chosen direction") expects a structured action the checkbox can't capture.
4. The "by event" close loses provenance — agent later reads commit messages, infers the choice. That works ~once but doesn't scale; it's how T-1776 was closed today and the agent had to write 30 lines of Evolution + Recommendation reconstruction to make the close legible.

## Problem Statement

When a `[REVIEW]` Human AC presents multi-option choices that each imply a different follow-up task, the framework has no structured way to (a) capture the operator's pick, (b) auto-spawn the chosen option's follow-up, (c) link the spawned task back to the parent AC. The current shape forces the choice into prose-and-chat, producing CTL-029 partial-completes and lost provenance.

## Scope question (operator dialogue required before recommendation)

This is the question we are exploring — not yet decided:

> **Should the framework support a structured "multi-option AC → spawned inception/build" pattern, distinct from the existing `[REVIEW]` checkbox?**

Three candidate shapes to evaluate (do **not** ship before operator picks direction):

### Candidate A — New AC kind: `[CHOICE]` with embedded options

```markdown
- [ ] [CHOICE] Resolution direction for the default-workflow contract gap
  **Options:**
  - **A: Build TermLink Python primitive** → spawns inception/build
  - **B: Add shell adapter** → spawns inception/build
  - **C: Change default.yaml** → spawns workflow-edit build
  **Steps:** review docs/reports/T-1776-*.md
  **On pick:** parent AC ticks; `fw spawn-from-choice T-XXX --pick A --type inception|build` files the child and writes `unlocks_choice: T-XXX:H1:A` on the child's frontmatter.
```

- **Pros:** explicit; spawn provenance survives in frontmatter; reviewer-agent can statically validate the shape; works equally on Watchtower and CLI.
- **Cons:** new AC kind requires parser updates (`agents/task-create/update-task.sh`, `lib/inception.sh`, render templates), gate updates (P-010 doesn't count `[CHOICE]` against AC completion until a child is filed), and template-doc updates. Wide blast radius.

### Candidate B — Watchtower-only choice form (no new AC kind)

The `[REVIEW]` AC stays as today, but the Watchtower review form gains a special "I picked option A/B/C" textarea-with-buttons that POSTs a `fw spawn-from-choice` call. CLI parity via a new `fw inception decide --picked A "rationale"` flag.

- **Pros:** smaller surface; CLI/web parity follows the T-1259/T-1671 precedent; doesn't touch the AC parser.
- **Cons:** the AC's prose-encoded options have to be parsed at form-render time (regex on the AC body) — fragile, same parser gap that motivates Candidate A.

### Candidate C — Convention only, no code

Operator writes `[REVIEW] Choose A/B/C` ACs the same as today, but the framework documents that each Choose-AC should ship paired with a `proposed_followups:` frontmatter list, and the spawn is manual. Agent reviewers static-scan for `proposed_followups:` consistency.

- **Pros:** zero code change; matches the T-1925 D5 pattern (proposed → approve via dedicated verb).
- **Cons:** discipline alone — recurrence likely. Doesn't close the CTL-029 trap because manual filing is the same friction T-1776 just demonstrated stalls for 22 days.

### Candidate D — Status quo

Keep `[REVIEW]` with prose-options as today. Cite T-1776 as the antifragile origin: the close-by-event pattern works, just write better Evolution sections at close time.

- **Pros:** zero work; the operator can still pick informally and the agent can still close by event.
- **Cons:** the bug being filed. Doesn't address the CTL-029 trap or the loss-of-provenance.

## Relationship to T-2101 (already-GO'd sibling)

T-2101 added a `--feedback <text>` channel — "what should be altered" prose. **This inception is the structured-pick complement** of that prose-feedback channel:

| Dimension | T-2101 channel | T-2137 (this) |
|-----------|----------------|----------------|
| Shape | Free-text prose | Discrete pick from N options |
| Use case | "Re-word X / I want to alter Y" | "Pick A or B or C and spawn the followup" |
| Spawn? | No — feedback stays on task body | Yes — pick spawns a child task |
| Surface | Watchtower review form + `--feedback` flag | Watchtower review form button-set + `--picked` flag |

The two ship together cleanly if the operator picks one of A/B for both — the same form gains a `--feedback` textarea and a `--picked` button-set.

## Dialogue Log

Per CLAUDE.md §Inception Discipline C-001 extension — record questions, answers, and course-corrections verbatim.

### 2026-05-31 — Session opening (verbatim)

**Operator (after T-1776 close commits 625557f1 + 9f08aa42 landed):**

> *"ok on 1776, surfaces a request / enhancement we already recorded but maybe dropepd or not yet started, we want an inline method to provide feedback for teh review, maybe we see soemthing that is not ok, needs to be altered, or in this case we just need to give an option a,b,c which actually shoudl surtface with and incpetion"*

**Agent search outcome:**
- Found T-2101 (operator-feedback channel) — recorded, GO'd 2026-05-30, V-slices V1..V5 listed in Recommendation never filed. That's the "recorded but dropped".
- Did NOT find a recorded inception for the multi-option-AC → spawn pattern. Closest neighbour: arc-008's Q1/Q2/Q3 questions, all currently un-anchored.
- T-1810 (`Watchtower paused-dispatch resolve form on /review/T-XXX`) is the closest pattern precedent — a structured form on the review surface — but its scope is paused dispatches, not multi-option ACs.

**Operator selection (AskUserQuestion 2026-05-31):**
*"File new arc-008 sibling inception for multi-option-AC → inception spawn"* (not the T-2101-V slices).

**Open scope questions awaiting operator answer before recommendation hardens:**

1. **A vs B vs C vs D** — which direction does the operator lean? The agent's tentative lean is **B** (Watchtower form with CLI parity) because it has the smaller blast radius and follows the T-1259/T-1671 precedent — but the agent has not yet thought through the AC-text parser fragility carefully; if that's a deal-breaker, A is forced.
2. **Spawn type** — should the spawn always be an inception (operator validates the choice mattered), or can it directly file a build when the picked option is itself a known shipping plan?
3. **Backwards compat** — should existing `[REVIEW] Choose A/B/C` ACs be retro-fitted, or only new ones?

## Recommendation

**Recommendation:** **DEFER** — dialogue must validate the scope before a recommendation hardens. Inception filed to capture the concept (the request was "already recorded but maybe dropped"; this is the formal recording).

**Rationale:** The operator's verbatim ask leans hard on the *inline-feedback* concept (which is T-2101 territory and already GO'd) and on the *option-A/B/C → inception* concept (which is what this inception captures). Until the operator picks a direction from A/B/C/D above, the agent can't responsibly write a single recommendation. The three open scope questions need answers. Filing this inception with DEFER is the structurally correct way to surface the dialogue without forcing a premature design call.

**Evidence:**
- T-1776 close-by-event proof point — commits `703f3d34` (filing), `df468c2f` (T-1797 ships option A by inference), `cf480359` (T-1798 prevention), `625557f1`+`9f08aa42` (this session's close). 22-day CTL-029 latency.
- T-2055 (CTL-029 detector) was filed for exactly this class.
- T-2101 sibling already exists for the free-text feedback complement.
- T-1810 (paused-dispatch resolve form) is the precedent for a structured Watchtower review form.

**On GO:** the next slice should be the operator's picked candidate. Each candidate's V-slices are NOT pre-filed here (don't accumulate stalled V-slices; T-2101 V1..V5 are the cautionary tale).

## Cross-references

- T-1776 (origin) — `docs/reports/T-1776-default-workflow-termlink-gap.md`
- T-2101 (free-text complement) — `docs/reports/T-2101-inception-feedback-field.md`
- T-2055 (CTL-029 detector) — completable-but-not-completed catch
- arc-008 — `inception-review-loop`
- L-262 (T-1443) — *frictionless feedback UX is load-bearing for any system depending on a learning loop*
- L-016 (T-1324) — *inception decide must tick its own authorizing Human AC*
