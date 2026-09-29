# T-3564 render review (independent agent reviewer)

**VERDICT: AMBER.** The page is acceptable and does what the operator asked. The quick links are at the top, the task overview is second, and the Purpose block and story sections read as a dossier. Five concrete issues should be fixed before this is called done. None of them is a blocker.

## WHAT I CHECKED

- Spec: T-3564 `## Context` and `### Agent` criteria. Builder notes: `docs/reports/T-3564-build-notes.md`.
- Code: `web/templates/arc_detail.html` (lines 38-128, the section wrappers and headings), `web/blueprints/arcs.py` (`_source_ref` :738, `_task_overview` :795, `_arc_sections` :814).
- Screenshots: `arc-readme-top.png`, `arc-readme-decisions.png`, `arc-readme-bvp.png`, and the reference `ref-055-arc007-top.png`.
- Live no-story arc: `curl /arcs/arc-grooming`. Its section ids are `task-overview`, `bvp-signals`, `constituent-tasks` and `completion-check`. Its quick links point at exactly those four ids. There is no Purpose section and no empty story headings. **The no-story case renders cleanly.**

### Judgements against the five questions

1. **Quick-link bar.** It sits directly under the title, as the operator asked ("absolute tops"). It has one link per section, 13 links, none dead. It works for jumping, and `scroll-margin` keeps headings visible after a jump (see the decisions screenshot). Two weaknesses:
   - The bar is visually weak. Its background, `--pico-card-sectioning-background-color`, is nearly the card colour, so it reads as a row of underlined words and not as a navigation bar.
   - It is not sticky and there is no way back to the top. The page is long (the readme arc is about 4 screens), so after one jump the bar is gone.
2. **Task overview.** It sits right after Purpose and before any BVP or report section, which is correct. On readme-first-run it is compact: 2/2, "No open tasks". On arc-grooming it **misleads**. The badges read "41 done · 11 work-completed" and then "Open tasks (11)", and all 11 are `work-completed`. To a reader with no background, "done" and "work-completed" mean the same thing, and calling finished work "open" looks like a bug. Those 11 are partial-completes waiting for human review. That is a real and useful signal, but the label is wrong. The list also has no cap: an arc with 40 unstarted tasks would push the story sections a screen down, which is the "wall" the operator did not want.
3. **Purpose and story order compared with 055.** In spirit this works. The order is Purpose, then Task overview, then success criteria, context, decisions (with status and date), open questions, non-goals, history and evidence, then BVP, tasks and the §ACD check. A reader who knows nothing about the arc can follow it, and it avoids 055's two flaws: tasks sit at the bottom there and it has no quick links. 055 does one thing better: its purpose is a highlighted headline sentence, with the plain-words goal below it. Ours gives the purpose the same weight as the objective. Acceptable.
4. **Broken, duplicated or confusing parts.**
   - (a) The label problem in item 2.
   - (b) Source references are inconsistent. `T-2719` and `docs/...` render as links, but `.tasks/completed/T-2719-...md#context` renders as plain code. That is the same task, sometimes clickable and sometimes not, sometimes in the same list. The cause is `_source_ref`, which only links bare `T-\d+` and `docs/`.
   - (c) AC 5 claims that "scoped drivers" gets its own anchor in the quick-link bar. In fact it is an `<h3>` inside `#bvp-signals` (template line 289) with no id and no quick link. The AC is ticked but not met as written.
   - (d) Not a problem: "Full task table ↓" duplicates the `#constituent-tasks` link, but it is contextual and fine.
   - (e) These predate this task and are out of scope: in the constituent table the ID column wraps "T-/2719", and the Arc column is empty.
5. **An arc with no story fields.** It renders sensibly. See WHAT I CHECKED.

## GUIDANCE

1. **Relabel partial-complete tasks in the task overview** (`arcs.py:_task_overview`). Map status `work-completed` (in `active/`) to the label `awaiting review` and put those tasks in their own list, "Awaiting human review (N)", separate from "Open tasks". Open tasks should then cover only `captured`, `started-work` and `issues`, sorted with issues first, then started-work, then captured. Add `awaiting review` to `order` after `done` and give it `badge-warn`. Add a test: an arc with one active work-completed constituent shows "awaiting review", and the task does not appear under "Open tasks".
2. **Cap the open-task list.** In the template, render `open_tasks[:10]`. If there are more, add `<li class="muted">… +{{ n-10 }} more — <a href="#constituent-tasks">full table</a></li>`. Apply the same cap to the awaiting-review list.
3. **Make the quick-link bar findable after a jump.** Pick one of these:
   - (a) Give `.arc-quicklinks` the rules `position: sticky; top: 0; z-index: 5; background: var(--pico-background-color); border-bottom: 1px solid var(--pico-muted-border-color);`. If you do this, raise `section[id]{scroll-margin-top}` by the bar's height so headings do not land under it.
   - (b) Add a small `<a href="#top" class="arc-src">↑ sections</a>` link to each `<h2>` and put `id="top"` on the arc `<article>`.

   Also give the bar a visible style: a leading muted label "Jump to:" and a background that contrasts with the card.
4. **Linkify task-file source references** (`arcs.py:_source_ref`). Before the `docs/` branch, match `r"\.tasks/(?:active|completed)/(T-\d+)-"` and return `href=/tasks/<id>`, keeping any `#fragment` in the displayed text. Leave `.context/` and `tests/` paths as plain code, since they have no page. Add one test for the `.tasks/completed/T-2719-…md#context` case.
5. **Close the gap on AC 5 about scoped drivers.** Either add `id="scoped-drivers"` to the `<h3>` at template line 289, plus a quick-link entry in `_arc_sections` when `bvp_info.scoped_drivers` is non-empty, or edit AC 5 so it no longer claims that anchor. The first is better: it is two lines, and the arcs that have scoped drivers are the ones where an operator adjusts weights and needs to jump there.
6. (Optional) **Promote the purpose line the way 055 does.** Render `story.purpose` as a `<blockquote><strong>` headline, with the objective below it as normal text.

Once items 1 to 5 are done this is GREEN. Item 1 is the only fix that changes what a reader understands; the others are polish.
