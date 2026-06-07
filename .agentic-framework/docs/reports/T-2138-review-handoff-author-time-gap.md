# T-2138 — RCA: review-handoff homework pattern recurs despite T-2030 GO

**Type:** Inception research artifact (per CLAUDE.md §Inception Discipline C-001 — created BEFORE conducting research).
**Arc:** `arc-008` (`inception-review-loop`). Sibling to T-2137 (multi-option AC), T-2101 (free-text feedback), and the parent T-2030 / build slice T-2050.
**Surfaces from:** S-2026-0531 user feedback on T-2109's Human AC Steps: *"why am i not getting full links??"*
**Status:** DEFER pending operator picks among candidates A/B/C/D below.

---

## Symptom

The user opened `/review/T-2109` and saw a Human AC whose Steps said:

> Open each of these in browser (Watchtower URL from `bin/fw watchtower url`):
> - `/`
> - `/bvp`
> - `/approvals`
> - `/timeline`
> - `/search`

The reviewer cannot click — they have to (a) run a shell command in another window, (b) read its output, (c) mentally concatenate the base URL with each bare path, (d) paste into the browser. Five times. This is exactly the `[[feedback_review_concrete_links]]` violation the memory was written to prevent.

The fix (commit `fa4e49d3`, this session) replaced the homework with five curl-verified absolute URLs.

## Why this keeps happening — the 5-Whys

| # | Why? | Answer |
|---|------|--------|
| 1 | Why did T-2109's AC ship with homework instead of links? | The agent authoring T-2109 wrote what felt natural — the Watchtower URL is per-project, so "URL from `bin/fw watchtower url`" reads as portable. The memory existed but the agent didn't consult it at author time. |
| 2 | Why didn't a gate block the author? | No author-time gate exists for review handoffs. The only structural check (T-2050's `lib/review_link_validator.py`) fires at `fw task review` time, advisory-only (`\|\| true` suppresses non-zero exit), and is invoked AFTER the AC text is already committed. |
| 3 | Why didn't T-2050 catch the homework pattern at review time? | T-2050's regex `_URL_RE = re.compile(r'https?://[^\s)\\]"\'<>\`]+')` extracts URLs that are **present**. The homework pattern contains **no URL** — just an instruction to construct one. Validator finds zero URLs → reports nothing → silent pass. |
| 4 | Why did T-2030 GO'd 2026-05-25 not foresee the absence-of-URL class? | The T-2030 inception scope (`docs/reports/T-2030-review-link-generation.md`) focused on the *wrong-URL* class (e.g. `/appearance` vs `/settings/appearance`) — agents pasting paths that 404. It didn't model the *no-URL* class because the working examples at the time all had URLs that were merely wrong, not absent. The "URL from `bin/fw watchtower url`" anti-pattern is a different failure mode. |
| 5 | Why does this matter structurally? | The framework's review surface is the load-bearing handoff from agent to human. Every friction-second between "I clicked the link" and "I see the page" compounds across 134 tasks currently awaiting human review (handover S-2026-0531-1303 figure). At 5 paths × 134 tasks worst-case, the framework imposes 670 manual-paste operations that should be 670 clicks. |

## Evidence — recurrence is systemic

Grep for the homework pattern across active+completed tasks:

```
$ grep -rlE "URL from .bin/fw watchtower url|base from .bin/fw watchtower url" .tasks/active/ .tasks/completed/
.tasks/active/T-2027-arc-007-s5a--arcs-pages-semantic-colour-.md
.tasks/active/T-2013-arc-007-s6b--keyboard-shortcuts-overlay-.md
.tasks/active/T-1991-watchtower-foundation-tokens--6-palettes.md
.tasks/active/T-2012-arc-007-s6a--command-palette-core-k-jump.md
.tasks/completed/T-2118-review-handoff-palette-inception.md
.tasks/completed/T-1853-watchtower-arcs-lifecycle-filter-tabs-t-.md
.tasks/completed/T-2030-review-hand-offs-must-always-emit-concre.md
```

**7 sites** carrying the anti-pattern. The T-2030 inception artifact itself (`.tasks/completed/T-2030-*`) contains the pattern it was filed to prevent — proving the memory + the GO decision haven't propagated to author-time discipline.

Furthermore: **same session (2026-05-31), I emitted `http://192.168.10.107:3000/inbox` in my own wrap-up chat message** — a route that doesn't exist (`/inbox` 404; observation triage is CLI-only via `bin/fw note triage`). User caught it. The memory was updated *that same session* with "This rule applies to chat-message URLs too, not just task-file Steps." And then 60 minutes later, on T-2109, the agent (me) shipped a Human AC referencing "URL from `bin/fw watchtower url`" — same class, different surface.

**Self-demonstration:** the discipline-only path has now failed twice in one session, with the memory explicitly fresh on each failure.

## Root cause

**T-2030's GO decision identified the right fix (Candidate C: `app.url_map` validation) but T-2050 shipped it as the wrong shape:**

1. **Advisory, not blocking.** `lib/review.sh:169` calls the validator with `\|\| true`. Even if the validator caught a violation, it would only print a WARN that no automation reads.
2. **Review-time, not author-time.** The Steps text was authored at task-create time (commit `cb0f3a99`-ish), then sat for 1+ day before any `fw task review` invocation. The gate fires AFTER the bad pattern is already in git.
3. **Presence-of-URL, not absence-of-URL.** The regex extracts URLs that exist. It cannot flag a Step that says "construct a URL yourself" because there is no URL to validate.
4. **T-2050 status: started-work since 2026-05-25** (6 days) — the build child of the GO'd inception **never reached work-completed**. The validator code exists (`lib/review_link_validator.py`) and is wired in (`lib/review.sh:165-169`), but the task never closed, no Human AC review fired, no episodic capture, no `unlocks_inception_decision:` bookkeeping. **CTL-027 class** (started but never closed).

The mental model gap: T-2030 framed this as a *link-correctness* problem (Candidate C validates against `app.url_map`). The recurring symptom is actually a *link-presence* problem and a *link-clickability* problem, which a presence-checking validator structurally cannot detect.

## Scope question (operator dialogue required before recommendation hardens)

> **What structural remediation is needed beyond T-2050's advisory `app.url_map` validation, so the review-handoff homework pattern stops at author time rather than review time?**

Four candidate shapes (do NOT ship before operator picks direction):

### Candidate A — Author-time blocking gate (PreToolUse hook on Write|Edit to `.tasks/`)

A new hook `check-review-link-concreteness.sh` fires on Write|Edit of `.tasks/{active,completed}/T-*.md`. It greps the Steps blocks of `### Human` ACs for any of these anti-patterns:

- `URL from .bin/fw watchtower url`
- `base from .bin/fw watchtower url`
- `(Watchtower URL from`
- Bare-path-in-bulleted-list inside Steps (`-\s+\`?/\S+\`?\s*$`) without a preceding `http://` or `https://`

On match → exit 2 with a block message naming the missing absolute URL pattern + the project's current base URL (resolved from `.context/working/watchtower.url`).

- **Pros:** stops the bug at the source — author time. Pattern-specific, low false-positive risk. Symmetric with the rest of the framework's PreToolUse gate family (`check-active-task`, `check-arc-id`, `check-tier0`).
- **Cons:** hook must be careful not to false-positive on `## Verification` shell commands that *contain* `/path` (legitimate). Scope to Steps blocks under `### Human` only. Needs a bypass (`FW_ALLOW_REVIEW_LINK_HOMEWORK=1`) for migration of the 7 legacy sites.

### Candidate B — Author-time advisory + reviewer-agent finding (static_scan.py)

Add a pattern entry to `agents/audit/reviewer/static_scan.py` catalogue: `review-link-homework`. The reviewer (`fw reviewer T-XXX`) emits a CONCERN on any AC containing the homework patterns above. Pre-completion gate already runs the reviewer; CONCERN doesn't block but lands in the task's `## Reviewer Verdict` block.

- **Pros:** uses existing static-scan substrate; advisory by default; no new hook. Plugs the *catch-at-close* gap while leaving authorship flexible. Matches T-1947 (prose-quality mis-routing) shape.
- **Cons:** advisory ≠ structural. Still relies on agent reading the verdict. The verdict CAN be set to BLOCK via `[REVIEWER]` AC conversion, but that requires every task to opt in.

### Candidate C — Template prefab + author-side documentation

Rewrite `.tasks/templates/zzz-default.md` and `.tasks/templates/default.md` Human AC example to use absolute URLs. Add a CLAUDE.md §AC Format Requirements clause explicitly forbidding `URL from <command>` patterns. Update `agents/dispatch/preamble.md` for sub-agent dispatch.

- **Pros:** zero hook code; lowest blast radius. Documentation pull is closer to authorship.
- **Cons:** discipline-only — proven insufficient (this session demonstrated discipline-failure twice with the memory fresh). T-1878 found a 412:7 `[REVIEW]:[REVIEWER]` adoption gap on a similar discipline-only push.

### Candidate D — Render-time substitution at `fw task review` (lift the homework off the human)

The validator already runs at review time. Extend it: when it spots `URL from .bin/fw watchtower url` followed by bullets of bare paths, *rewrite the rendered Steps* (in-memory, for the Watchtower review page only) substituting the resolved base URL. Source task file is left intact.

- **Pros:** the human never sees homework, ever. Tolerates legacy patterns without migration. No author-time friction.
- **Cons:** the source file still carries the anti-pattern → next reader (post-completion archive readers, audit tools) still hits it. Doesn't fix the cause, only the user-facing symptom. Asymmetric: CLI-only `fw task review` output may still show the homework if it doesn't go through the same render layer.

### Candidate E — Transition-time blocking gate (refinement of A, operator-proposed 2026-05-31)

Operator pushback on A: *"this is at the start of a taks, and it should ounly be invoked when surfacing a task for reveiw or incpetion approval right"*.

That's correct. PreToolUse on Write|Edit fires at *every* save — including WIP drafts where the agent hasn't finished writing the AC yet. The gate should fire at the **handoff transition** — the moment the task crosses from agent-owned to human-owned. The three structural moments where that happens:

1. `bin/fw task review T-XXX` is invoked (agent explicitly hands over)
2. `update-task.sh --status work-completed` runs on a build task with **unchecked Human ACs** (auto-handoff to partial-complete state)
3. `update-task.sh --status work-completed` runs on an **inception task** (agent finalises body before `fw inception decide`)

At each of those moments — and ONLY at those moments — the validator runs as a **blocking** gate (not the current `|| true` advisory). Detection logic:

- Class-aware URL resolution: inception tasks (`workflow_type: inception`) expect `/inception/<id>`; partial-complete builds expect `/review/<id>`. Other paths (`/cockpit` vs `/`, `/inbox` vs none, etc.) validated against `app.url_map` regardless of class.
- Class-agnostic homework-pattern detection: any Steps section under `### Human` containing `URL from .bin/fw watchtower url`, `base from .bin/fw watchtower url`, `(Watchtower URL from`, OR a bare-path-in-bulleted-list inside Steps without a preceding `http://` or `https://` → BLOCK.
- Block message **explicitly names the review-vs-inception distinction**: "This task is being surfaced for [review/inception approval]. The expected URL pattern is `[/review or /inception]/T-XXX`. Found: [homework pattern]. Replace with: [resolved absolute URL]." The block message answers the operator's "is the differentiation clear enough?" question structurally — every block message teaches the distinction.
- Bypass: `--skip-review-link-check "rationale"` flag on `fw task review`, `FW_ALLOW_REVIEW_LINK_HOMEWORK=1` env var on update-task.sh — both log Tier-2 to `.gate-bypass-log.yaml`.

**Pros over A:**
- WIP saves are unblocked — agent can scaffold a task with TODO Steps and fix them before handoff
- Maps to a single integration point: `lib/review.sh:emit_review` (already exists, already wired at all three handoff moments) — change is upgrading `|| true` to a blocking exit + extending detection to absence-of-URL patterns
- Class-aware block message turns each violation into a teaching moment for the review-vs-inception distinction
- 7 legacy sites stay valid until they're next surfaced for handoff — natural retro-fit cadence, no upfront sweep needed

**Cons:**
- Doesn't prevent the chat-message slip (`/inbox` class) — that fires from agent prose, not from a task file edit. Need a separate detection surface (reviewer agent passive scan, or a chat-output linter — neither exists yet)
- Slightly later than author-time: an agent can write a homework Step and not discover it until handoff. Mitigated by Candidate B (reviewer static-scan as `[REVIEWER]` AC) running BEFORE handoff during normal task completion review.

### A hybrid is likely correct

The candidates aren't mutually exclusive:

- **C** (template + docs) is cheap, low-risk, and helps new tasks regardless of which structural fix lands.
- **A** (author-time hook) is the strongest structural fix but has migration cost (7 legacy sites + bypass mechanism).
- **B** (reviewer static-scan) is the cheapest structural fix but stays advisory.
- **D** (render-time rewrite) hides the symptom but doesn't fix the root cause.

The agent's tentative lean: **C + A**, with **B** as the audit backstop. Skip **D** — render-rewriting source-of-truth text is the kind of magic that makes future readers distrust the file system. But the operator should decide.

## Dialogue Log

Per CLAUDE.md §Inception Discipline C-001 extension — record questions, answers, course-corrections verbatim.

### 2026-05-31 — Session segment (verbatim)

**Operator (on opening `/review/T-2109`):**

> *"2109, why am i not getting full links ?? Steps:*
> *Open each of these in browser (Watchtower URL from bin/fw watchtower url):*
> */*
> */bvp*
> */approvals*
> */timeline*
> */search"*

**Agent action:** fixed T-2109 inline (commit `fa4e49d3`) replacing homework with 5 curl-verified absolute URLs.

**Operator follow-up:**

> *"please incpet rca why this keeps happening and what strcutural remdiation is furtehr needed"*

**Agent investigation outcome:**
- T-2030 already GO'd 2026-05-25 with Candidate C (url_map validation).
- T-2050 (Candidate C build slice) shipped the validator code but as **advisory only** at `fw task review` time, status `started-work` since 2026-05-25 (CTL-027 class — started but never closed).
- Validator regex extracts `https?://...` URLs that are **present**. Cannot flag absence-of-URL homework patterns.
- 7 active+completed tasks still carry the homework pattern.
- Same session (2026-05-31): agent emitted `/inbox` (non-existent route) in chat. User caught. Memory updated. Then 60 minutes later, agent shipped T-2109's homework Steps — same class, different surface, memory fresh.

**Open scope questions awaiting operator answer before recommendation hardens:**

1. **Candidate direction (A/B/C/D/E or hybrid).** Agent's tentative (updated 2026-05-31 post-dialogue): **E + B** — transition-time blocking gate as the structural fix, reviewer static-scan as the catch-before-handoff backstop. Skip C (discipline-only proven insufficient). Skip D (source-of-truth rewriting).
2. **T-2050 status.** Should the new structural slice supersede T-2050 (close as "superseded by T-2138 build") or layer on top? T-2050's `app.url_map` validation IS still useful for the wrong-URL class; it just doesn't catch absence-of-URL. Candidate E reuses T-2050's `lib/review_link_validator.py` integration point (`lib/review.sh:emit_review`) — strongest argument for "layer on top, not supersede".
3. **Migration of 7 legacy sites.** Candidate E's natural retro-fit cadence (gate fires only at next handoff) sidesteps the upfront sweep. Confirm operator is happy with that, OR opt for an explicit one-time sweep before enabling the gate. Bypass-flag exists either way.

### 2026-05-31 — Operator response on candidates (verbatim)

> *"not sure i want the reliable process / workflow steps oriented one. so pretoooshook sound solid on teh otherhand it also looks this is at the start of a taks, and it should ounly be invoked when surfacing a task for reveiw or incpetion approval right, not sure if there is an differientiation between reviwew and incpetion (gues there is maybe that oen is also not clear enough?)"*

**Parsed:**
- "not sure i want the reliable process / workflow steps oriented one" → **leaning away from Candidate C** (template + CLAUDE.md prose discipline).
- "pretoooshook sound solid" → **Candidate A is on the table** in principle.
- "this is at the start of a taks, and it should ounly be invoked when surfacing a task for reveiw or incpetion approval right" → **refined to handoff-transition time, not every Write|Edit**. Captured as new Candidate E above.
- "not sure if there is an differientiation between reviwew and incpetion (gues there is maybe that oen is also not clear enough?)" → **sub-question: is the review (`/review/T-XXX`) vs inception (`/inception/T-XXX`) distinction surfaced clearly enough?** Candidate E's class-aware block message turns each violation into a teaching moment for the distinction. Worth confirming the operator wants that, OR wants a separate task to clean up surface text (CLAUDE.md, AGENT.md, block messages) where the distinction is currently muddled.

**Agent confirmation requested before recommendation hardens:**

- Q1: Is Candidate **E** (transition-time blocking gate, class-aware, reusing T-2050's integration point) the right shape? Or do you want a stricter version that fires at Write|Edit too (full Candidate A)?
- Q2: Is Candidate **B** (reviewer static-scan as `[REVIEWER]` AC) a good companion for catch-before-handoff (so the agent self-corrects before E fires)? Or skip B and rely on E alone?
- Q3: On the review-vs-inception distinction — do you want it taught **inside the block message** (E's plan), in a separate CLAUDE.md clean-up task, or both?

### 2026-05-31 — Operator decision (verbatim)

> *"go with E + B, both for Q3"*

**Parsed:** Candidate E (transition-time blocking gate, class-aware, reusing T-2050's integration point) + Candidate B (reviewer static-scan companion) + Q3-both (block-message teaching + separate doc cleanup sibling task).

**Recommendation hardened from DEFER → GO.** Next action: operator records structural GO via Watchtower at http://192.168.10.107:3000/inception/T-2138 (sovereignty-gated under `$CLAUDECODE=1` — agent cannot self-record). Once recorded, agent files V1 build slice (E keystone) and parks V2 (B catalogue entry) + V3 (Q3 doc sweep) as siblings.

## Recommendation

**Recommendation:** **DEFER** — operator must pick direction + answer the three open scope questions before any build slice is filed. V-slices NOT pre-filed (T-2101 V1..V5 stalled-list is the cautionary tale — `grep -lE "T-2101-V" .tasks/` returns empty after 1 day GO'd).

**Rationale:** The recurring pattern has crossed the systemic threshold (≥3 captures: T-2027/T-2013/T-1991/T-2012/T-2118/T-1853/T-2030/T-2109 + the `/inbox` chat slip + 2× discipline failure in one session). T-2030's GO decision identified the right *direction* (structural validation at handoff) but T-2050's shipping shape (advisory WARN, review-time, presence-only) cannot catch the dominant failure mode. The remediation needs an author-time or template-side fix, and the four candidates trade off blast-radius vs strictness vs migration-cost differently — operator dialogue must validate the scope before a recommendation hardens.

**Evidence:**
- T-2030 (parent inception, GO 2026-05-25): `docs/reports/T-2030-review-link-generation.md`
- T-2050 (build slice, started-work since 2026-05-25, validator code shipped): `lib/review_link_validator.py`, `lib/review.sh:165-169`
- T-2109 recurrence (this session): commit `fa4e49d3` (fix), original Steps from commit predating
- T-2113 cockpit fix (this session, commit `cb815bae`): same class, different route
- `/inbox` chat slip (this session, no commit): same class, chat surface
- `[[feedback_review_concrete_links]]` memory: documented before T-2113, updated *during* this session, then violated 60 minutes later → discipline-only path proven insufficient.
- 7 active+completed tasks via `grep -rlE "URL from .bin/fw watchtower url"` in `.tasks/`.

**On GO:** the operator picks A/B/C/D (or hybrid), then a single first-slice build task is filed. V-slices are not enumerated here.

## Cross-references

- **Parent:** T-2030 (`docs/reports/T-2030-review-link-generation.md`)
- **Build slice (incomplete):** T-2050 (started-work since 2026-05-25 — CTL-027)
- **Sibling inceptions in arc-008:** T-2137 (multi-option AC), T-2101 (free-text feedback)
- **In-session recurrences:** T-2113 (`/cockpit` 404 fix), `/inbox` chat slip, T-2109 (this trigger)
- **Memory:** `[[feedback_review_concrete_links]]`
- **Detector class:** T-2055 (CTL-029) — completable-but-not-completed; T-2050 sits in the *active-side* mirror CTL-027
- **L-262 (T-1443):** *frictionless feedback UX is load-bearing for any system depending on a learning loop*
