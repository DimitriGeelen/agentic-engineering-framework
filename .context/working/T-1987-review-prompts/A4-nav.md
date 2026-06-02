# T-1987 review-A4 — navigation restructure reviewer

You are an isolated TermLink-dispatched worker reviewing the navigation restructure dimension of arc-007 (watchtower-redesign) inception T-1987. You produce ONE review artifact and post a fw bus summary. You do NOT transition T-1987 or any child task.

## Setup (run first, in order)

1. Confirm `pwd` is `/opt/999-Agentic-Engineering-Framework`.
2. Read inception body + research artifact.
3. Read nav design source: `docs/design/watchtower-redesign-2026-05-13/project/nav-patterns.jsx`.
4. Audit the CURRENT Watchtower navigation:
   - Read `web/templates/base.html` and any included nav fragment.
   - Read `web/app.py` and `web/blueprints/` to enumerate every registered route.
   - List every page in the current nav, by group. The "Govern" group is the stated 16-item pain point — count it precisely.
5. Read three nav layouts in the design: top-bar + sub-nav, persistent sidebar, slim icon rail + ⌘K-primary.

## Your dimension: navigation restructure (S2 / T-1989)

You audit the current 4-group nav, propose the concrete restructure, and challenge whether 3 selectable layouts is the right answer.

## Deliverable

Write to `docs/reports/T-1987-reviews/A4-nav-restructure.md`.

Required sections:

1. **Current nav inventory** — Exhaustive list of every page in the current top-level nav, grouped exactly as shipped. Mark which "Govern" items are duplicates of other groups, which are dead/unused (look at recent commits to templates), which are core. Count items per group.
2. **Information architecture proposal** — Given the inventory, propose a new IA. Should the 4 groups become 3? 5? Should "Govern" split into Approvals + Knowledge + Audit? Show the proposed tree concretely.
3. **Top-bar + contextual sub-nav** — Concrete layout. What's in the primary top bar? Where does sub-nav appear (under top bar? as a sticky in-page section?)? When does it change (per primary item or per breadcrumb)?
4. **Persistent sidebar** — Concrete groups, item ordering, pinned-favourites position (top? bottom? above groups?), collapse behaviour. What does "pinned" actually persist (per-user — link to A2)?
5. **Slim icon rail + ⌘K-primary** — How discoverable is this for the user who hasn't memorised ⌘K? What goes on the rail (4-6 icons)? What's the icon library (Lucide, Heroicons, custom)?
6. **Breadcrumb resolver** — Some pages (e.g., `/tasks/T-1987`, `/arcs/watchtower-redesign/close`, `/learnings/L-419`) need a breadcrumb back to a meaningful parent. Spec a resolver: given a Flask `request`, output `[(label, url), ...]`. Cover at least: Tasks index → task detail; Arcs index → arc detail → arc close; Knowledge index → learning/decision/pattern detail.
7. **Pinned-pages model** — Concrete API: persist what data? `[{path, label}]`? Limit count? Order (drag-reorder)? Where is the "star" UI located on each page?
8. **Migration risk** — Replacing the nav touches every `base.html` `include` site. List which template files are affected. Estimate blast radius (probably 30+ templates). Should there be a feature flag for incremental rollout?
9. **Challenge: do we need 3 layouts?** — Is the matrix of (3 layouts × 6 palettes × 6 type pairings × 3 densities) too much? Should the inception scope down to 1 layout (e.g., top-bar + sub-nav is the chat's stated structure)? Argue for or against.
10. **Recommendation** — KEEP / ADJUST / CHALLENGE the S2 scope. Be specific about what should ADJUST if anything.

## Constraints

- **No source edits.**
- **Do not edit T-1987 or T-1988-T-1994 task bodies.**
- **Path isolation.**
- **Banned tools.**

## Reporting

1. Commit: `git add docs/reports/T-1987-reviews/A4-nav-restructure.md && bin/fw git commit -m "T-1987: review-A4 nav restructure"`.
2. Post: `bin/fw bus post --task T-1987 --agent reviewer-A4-nav --summary "..." --blob docs/reports/T-1987-reviews/A4-nav-restructure.md`
3. Final ≤ 5 lines: DONE | path | verdict | current "Govern" item count | one biggest IA call

Begin.
