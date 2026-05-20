# Approvals Batch — 2026-05-20

29 tasks on `/approvals` grouped by category, with the specific [REVIEW] AC + where to look.
Every task has an existing GO recommendation written; this digest collapses the queue into a
single scrollable surface so you can sign through in batches rather than tab-by-tab.

Watchtower index: http://192.168.10.107:3000/approvals

---

## Batch 1: Dispatch-safety arc (arc-001) — 5 tasks

**Shared context:** the paused-dispatch slice 1→5 chain. Worker hits ambiguity → emits `pause_requested`
→ operator answers via `fw pause resolve` (or Watchtower form) → retry envelope created with
`retry_of_dispatch_id` linkage. Architecture confirmed live (cross-repo joint with TermLink T-243).

| Task | [REVIEW] asks | Where to look |
|------|---------------|---------------|
| [T-1805](http://192.168.10.107:3000/review/T-1805) | Substrate change matches ADR-0004's intent (pause as terminal event class) | `lib/spawn.py` + `lib/outcome.py` diffs |
| [T-1806](http://192.168.10.107:3000/review/T-1806) | Resolver risk-policy preamble tone strikes right balance | `lib/resolver.py` `_BASELINE_RISK_PREAMBLE` string |
| [T-1807](http://192.168.10.107:3000/review/T-1807) | WARN-vs-ERROR split correct on workflow schema lint | `lib/workflow_lint.py` rule classifications |
| [T-1808](http://192.168.10.107:3000/review/T-1808) | Paused-dispatch panel renders cleanly on Watchtower | http://192.168.10.107:3000/approvals (paused panel) |
| [T-1810](http://192.168.10.107:3000/review/T-1810) | Paused-dispatch resolve form renders cleanly inside review page rhythm | any /review/T-XXX with paused dispatch |

**Closure effect:** unblocks `fw arc close dispatch-safety --demo docs/reports/dispatch-safety-arc-demo.md`
(arc-001, 11/11 tasks complete — wire-evidence captured commit `407d8bdb`).

---

## Batch 2: Orchestrator-rethink (arc-003) workers — 4 tasks

**Shared context:** the worker_kind dispatch matrix. T-1700 added litellm proxy; this batch wired
each `worker_kind` to a spawn-side driver so `fw resolver run T-XXX <task_type>` dispatches end-to-end.

| Task | [REVIEW] asks | Where to look |
|------|---------------|---------------|
| [T-1773](http://192.168.10.107:3000/review/T-1773) | End-to-end pi smoke (live dispatch optional) | `fw resolver run --dry-run T-XXX pi_task` |
| [T-1774](http://192.168.10.107:3000/review/T-1774) | End-to-end CLI smoke | same as T-1773 |
| [T-1775](http://192.168.10.107:3000/review/T-1775) | End-to-end ollama-loop smoke (T-1700 #H1+#H2 prerequisite) | live ollama dispatch via `fw resolver run` |
| [T-1797](http://192.168.10.107:3000/review/T-1797) | Live TermLink dispatch smoke (optional) | `fw termlink dispatch` confirmation |

**Closure effect:** completes 3-of-4 worker_kind routes (pi / ollama-loop / TermLink). Last route
(Task tool / Anthropic API) explicitly deferred — not in this batch.

---

## Batch 3: Orchestrator panels (arc-003) — 4 tasks

**Shared context:** web parity for `fw orchestrator status` CLI breakdowns. Before this batch,
`/orchestrator` showed learned preferences but not what the substrate actually picked.
Three sub-tables added: by_model, by_task_type, by_worker_kind. Plus outcome quality.

| Task | [REVIEW] asks | Where to look |
|------|---------------|---------------|
| [T-1792](http://192.168.10.107:3000/review/T-1792) | by_model panel renders cleanly | http://192.168.10.107:3000/orchestrator (Dispatch substrate panel) |
| [T-1794](http://192.168.10.107:3000/review/T-1794) | by_model + by_task_type stack with visual rhythm | same page |
| [T-1795](http://192.168.10.107:3000/review/T-1795) | Three sub-tables stack without overflow | same page |
| [T-1796](http://192.168.10.107:3000/review/T-1796) | Outcome quality panel sits between Dispatch and Learned routing in correct flow | same page (scroll) |

**One scroll-pass on `/orchestrator`** clears all 4. Look top-to-bottom: Dispatch substrate (3 sub-tables) → Outcome quality → Learned routing.

---

## Batch 4: Workflow coverage panel (arc-003) — 4 tasks

**Shared context:** web + audit parity for T-1798's workflow-dispatcher coverage check. Surfaces
which workflows are routable, which are missing providers, which were never fired, which are stale.

| Task | [REVIEW] asks | Where to look |
|------|---------------|---------------|
| [T-1799](http://192.168.10.107:3000/review/T-1799) | Workflow coverage panel placement (between Outcome quality and Learned routing) | http://192.168.10.107:3000/orchestrator |
| [T-1801](http://192.168.10.107:3000/review/T-1801) | `provider` column + `missing` badge visual rhythm | same page (Workflow coverage table) |
| [T-1802](http://192.168.10.107:3000/review/T-1802) | "Last dispatched" column usefulness for deprecation scanning | same column — 5 workflows show `never` (muted) |
| [T-1803](http://192.168.10.107:3000/review/T-1803) | WARN message clarity (`fw audit` output) | `fw audit -s orchestrator` output |

**One scroll-pass + one CLI run** clears all 4.

---

## Batch 5: BVP arc (arc-006) — 4 tasks

**Shared context:** Value Prioritisation arc. Quadrant scatter + arc-level rollup + canonical doc.
Approval here also flips arc-006 from `draft` → `in-progress` once you approve drivers.

| Task | [REVIEW] asks | Where to look |
|------|---------------|---------------|
| [T-1928](http://192.168.10.107:3000/review/T-1928) | Quadrant placement is intuitive across a 5-task spot-check | http://192.168.10.107:3000/bvp (static scatter) |
| [T-1929](http://192.168.10.107:3000/review/T-1929) | Slider responsiveness feels live (no janky lag on drag) | same page (sliders) |
| [T-1930](http://192.168.10.107:3000/review/T-1930) | Approval flow unambiguous, page reads cleanly | http://192.168.10.107:3000/arcs/arc-006 |
| [T-1933](http://192.168.10.107:3000/review/T-1933) | `040-ValueDrivers.md` reads accurately, matches shipped implementation | `040-ValueDrivers.md` at repo root |

**Critical:** T-1933 is **load-bearing [REVIEW]** — once approved, the doc carries weight as canonical
spec. Read it through before ticking. ~236 lines, ~10 min.

---

## Batch 6: Render-fix triad — 3 tasks

**Shared context:** T-1898 found the bug (double-render on `/arcs/arc-005` because `_wrapper.html`
already extends `base.html`); T-1899 added the structural guard; T-1900 fixed the SIGPIPE in the
error path. RCA + structural prevention shipped together.

| Task | [REVIEW] asks | Where to look |
|------|---------------|---------------|
| [T-1898](http://192.168.10.107:3000/review/T-1898) | Layout reads clean — only one Watchtower header at top | http://192.168.10.107:3000/arcs/arc-005 |
| [T-1899](http://192.168.10.107:3000/review/T-1899) | Error message reads actionably to a fresh developer | error message text in `web/shared.py` `render_page()` |
| [T-1900](http://192.168.10.107:3000/review/T-1900) | Render-surface gate error message now actually surfaces (no SIGPIPE) | `agents/task-create/update-task.sh` `check_render_surface_human_ac` |

**Cheapest batch — pure visual on one URL + two code-message reads.**

---

## Batch 7: REVIEWER classification thread — 2 tasks

**Shared context:** T-1811 introduced the `[REVIEWER]` Human-AC prefix; T-1947 added the
prose-quality mis-routing guard (necessary-but-not-sufficient rule). T-1948 followed with the
prose rewrite per your "WHAT ARE YOU TRYING TO SAY??" review.

| Task | [REVIEW] asks | Where to look |
|------|---------------|---------------|
| [T-1811](http://192.168.10.107:3000/review/T-1811) | CLAUDE.md `[REVIEWER]` section reads clearly, conversion rule unambiguous | CLAUDE.md line ~620 (AC Classification Guidance) |
| [T-1947](http://192.168.10.107:3000/review/T-1947) | CLAUDE.md `[REVIEWER]` necessary-but-not-sufficient paragraph reads cleanly | CLAUDE.md line ~654 (the rewritten 3-paragraph block T-1948 shipped) |

**Self-referential — these two tasks are each other's dogfood.**

---

## Batch 8: Singletons — 3 tasks

| Task | [REVIEW] asks | Where to look |
|------|---------------|---------------|
| [T-1818](http://192.168.10.107:3000/review/T-1818) | Cross-repo coordination correct — both halves of v2 peer-consult arc ship | docs/handouts/ + TermLink T-243 status |
| [T-1834](http://192.168.10.107:3000/review/T-1834) | Cross-repo prompt at `docs/handouts/T-1834-cross-repo-...` is actionable | that file (secret purge follow-up) |
| [T-1891](http://192.168.10.107:3000/review/T-1891) | New CLAUDE.md "Hook Bypass Contract Parity" section reads cleanly and matches surrounding rules | CLAUDE.md §Hook Bypass Contract Parity (T-1890, L-399) |

**Lightest batch — 3 short prose reads.**

---

## Suggested order

If you want to clear the most with the fewest context switches:

1. **Batch 3 + Batch 4** — single scroll on `/orchestrator` + one `fw audit -s orchestrator` run clears 8 tasks (~5 min)
2. **Batch 5** — `/bvp` scroll + `/arcs/arc-006` + the 236-line canonical doc read (~15 min, T-1933 is the most substantive)
3. **Batch 6** — one URL view + 2 code-message reads, ~3 min
4. **Batch 1** — Watchtower paused-dispatch panel + 3 code-string reads, ~5 min
5. **Batch 7 + Batch 8** — short prose reads, ~5 min
6. **Batch 2** — only if you want to run live dispatch smokes; otherwise sign on the existing evidence in each task

**Total estimate:** ~30-35 minutes for all 29 tasks if you sign on evidence; ~45-60 minutes if you re-run
each smoke yourself.

**Closure cascade after approvals:**

- arc-001 (dispatch-safety) → `fw arc close` ready (Batch 1 clears)
- arc-003 (orchestrator-rethink) → **still blocked by G-064** (zero production consumers); approvals here alone do not unblock arc close
- arc-006 (BVP) → flips draft → in-progress once drivers are approved (separate from these reviews)
- arc-004 (project-shape-resilience) → not in this batch; T-1542 already merged
- arc-005 (arc-grooming) → not in this batch; closure ready independently

---

Generated: 2026-05-20T09:30Z by Claude (session post-S-2026-0520-1106).
Source: `.tasks/active/T-1*.md` Recommendation blocks + handover S-2026-0520-1106 awaiting-action list.
