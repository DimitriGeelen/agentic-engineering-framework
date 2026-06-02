# T-1987 review-A5 — adversarial scope reviewer

You are an isolated TermLink-dispatched worker producing the adversarial review of arc-007 (watchtower-redesign) inception T-1987. Your job is to find what the inception got WRONG, propose a smaller scope if appropriate, and recommend GO / DEFER / NO-GO with rigour. You do NOT transition T-1987 or any child task.

## Setup (run first, in order)

1. Confirm `pwd` is `/opt/999-Agentic-Engineering-Framework`.
2. Read inception body + research artifact end-to-end.
3. Read the chat transcript carefully: `docs/design/watchtower-redesign-2026-05-13/chats/chat1.md`. Pay attention to what the user actually said vs what the designer (and inception agent) inferred.
4. Read `concerns.yaml`, `CLAUDE.md` §G-066/G-062, and recent gap learnings.
5. Spot-check existing arcs: `.context/arcs/orchestrator-rethink.yaml`, `.context/arcs/arc-grooming.yaml`. Look at constituent-task counts and durations. An arc with 7+ children that hasn't closed in 30+ days is the failure pattern to compare against.
6. Read T-1717 (post-grill governance origin) and T-1843 (recent arc-shaped work) to understand healthy arc cadence vs unhealthy.

## Your dimension: adversarial scope review

You are the red team. The parent agent is bullish. Your job is to find the holes.

## Deliverable

Write to `docs/reports/T-1987-reviews/A5-adversarial-scope.md`.

Required sections:

1. **Does the inception capture the user's real intent?** Quote the user verbatim from the chat. Compare to the proposed S0-S6 slices. Where does the inception over-build (proposing things the user didn't ask for)? Where does it under-deliver (missing things the user explicitly mentioned)?
2. **Is S0 the right starting slice?** Foundation tokens are infrastructure. Will the user perceive any value-delivery from S0 alone? Or does the user only see value at S1 (the Appearance screen ships)? Argue for or against re-ordering — e.g., a thin vertical slice (S0+S1 combined) might land faster than S0 then S1.
3. **Slice independence audit.** The dependency graph says S0 → S1,2,3,4,5,6. Is that real or constructed? Could S5 (Fabric) ship independently of S0 by just keeping its inline styles? If so, S5 is parallel-shippable, which changes the critical path.
4. **Slice size audit.** S4 (Tasks board+list+side-panel+drag+inline-edit+filter-chips+bulk) is doing 6+ things. Is that one slice or six? Same question for S6 (⌘K+overlay+bulk+ticker — 4 things in one slice).
5. **What's missing entirely?** Re-read the chat's interaction inventory. Cross-check against S0-S6. Examples of likely gaps:
   - Compact density spec (where does the actual font-size table live?)
   - Saved-view chips with shareable URLs
   - Quiet mode (live ticker can be disabled)
   - Accessibility (no mention in the inception)
   - Print stylesheet
   - Mobile/responsive (explicitly out of scope, but what's the breakpoint behaviour?)
6. **What's over-scoped?**
   - "Live activity ticker" is a real-time push system — heavy for a control plane.
   - 6 palettes × 6 type pairings × 3 nav layouts × 3 densities = 324 combinations. Is the testing surface tractable?
   - Bulk-action contract across every list page is a cross-cutting infra change. Worth its own task?
7. **Pattern match against past failures.** G-062 is "framework-blindness — 'shipped' declared before fresh-substrate behavioural verification." Cite which inception ACs would catch G-062-class drift on this arc.
8. **The DEFER case.** Make the strongest argument for DEFER. Examples to consider: "75+ approvals queue is the real bottleneck; redesign won't unblock it as claimed"; "no live user-research evidence the 6-preset model is right"; "PicoCSS coexistence might fail and force a Pico-removal sub-arc that derails everything".
9. **The NO-GO case.** Could the answer be "do nothing"? What evidence would support that?
10. **Final adversarial verdict.** Pick ONE of GO / GO-with-adjustments / DEFER / NO-GO. Be specific about adjustments. Don't hedge.
11. **Concrete actionable list** — If GO-with-adjustments: a numbered list of 3-7 specific changes the parent agent should make to T-1987 before the human decides. Top concerns only — no kitchen-sink.

## Constraints

- **No source edits.**
- **Do not edit T-1987 or T-1988-T-1994 task bodies.** (Your job is to recommend changes, not make them.)
- **Path isolation.**
- **Banned tools.**

## Reporting

1. Commit: `git add docs/reports/T-1987-reviews/A5-adversarial-scope.md && bin/fw git commit -m "T-1987: review-A5 adversarial scope"`.
2. Post: `bin/fw bus post --task T-1987 --agent reviewer-A5-adversarial --summary "..." --blob docs/reports/T-1987-reviews/A5-adversarial-scope.md`
3. Final ≤ 5 lines: DONE | path | final verdict (GO/GO-with-adj/DEFER/NO-GO) | top-1 critical gap | top-1 over-scope risk

Begin.
