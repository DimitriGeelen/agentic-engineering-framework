# T-1709: Permanent disposable AEF review instance — research artifact

**Status:** inception, exploration
**Workflow:** Design-Dialogue (T-1442/T-1443 pattern)
**Origin:** 2026-05-04, after T-1702/T-1707 shipped to human review. Reviewing each Human AC requires a human running representative shell commands against a real framework install. The agent on this project can't do that (path isolation, sovereignty). User proposes: a permanent disposable AEF instance at `/opt/ttt-AEF-Review-instance`, agent reaches into it via TermLink, instance is shred-and-reinit, dual-purposed for install/upgrade flow testing.

## Playback (agent's understanding — challenge each line)

The user wants:

1. A **second framework instance** living at `/opt/ttt-AEF-Review-instance`, structurally isolated from this framework repo.
2. The instance is **not git-tracked** — its working tree is throwaway. State that needs to persist (cron schedules, learnings, anything) lives elsewhere or is regenerated.
3. The instance is **shred-and-reinit cycled** — cleared and re-installed on demand, like a `reset --hard` for an entire framework checkout.
4. **Dual purpose:**
   - **a)** Acting as a sandbox where representative shell commands can fire to exercise human-AC scenarios (e.g., T-1702 boundary-hook trade-off curve).
   - **b)** Smoke-testing the install/upgrade flows themselves (`fw init`, `fw upgrade`, vendor sync, hook installation).
5. **Driven via TermLink** — this framework's agent (here) dispatches a session into the review instance, runs commands via PTY inject / interact, captures output. The boundary hook makes any direct file touch of `/opt/ttt-AEF-Review-instance/...` from this project illegal, so TermLink is the only channel — that's a feature, not a workaround.
6. **The agent does the legwork; the human still decides.** For T-1702-style [REVIEW] ACs, the agent runs the trade-off scenarios in the review instance, captures evidence (commands tried, blocks, passes, false positives), and posts the evidence back. The human reads the evidence and casts the GO/NO-GO vote. The agent never ticks a `### Human` AC.

## Why this might be worth doing

- **Recurring need.** T-1702, T-1707, T-1700 all have Human ACs that need representative-session evidence. The pattern repeats on every framework-internal change touching paths/hooks/install flow.
- **Closes a recurring blind spot.** Right now, "test the install flow" tasks (T-1635 fresh-machine simulation, fw upgrade flows) hand-wave on "should test in clean container" — there's no permanent rig. A disposable instance at a known path makes "fresh-machine" cheap to invoke.
- **Forces the right boundary.** Today the agent here can't even verify install flow without violating path isolation. TermLink + disposable instance is the structurally clean way to do it.
- **Real consumer for the orchestrator substrate.** G-064 says substrate has zero autonomous consumers. A permanent review-instance worker that exercises dispatch on every release is a candidate consumer #3 (alongside T-1684's daily health-check cron).

## Why this might NOT be worth doing (steelman)

- **Two use cases conflated.** "Sandbox for human-AC scenario evidence" and "test bench for install/upgrade flows" want different things from the same rig. The first wants long-lived state to evolve a session and observe. The second wants pristine clean-room every time. One instance can't optimise for both — see Grill #1.
- **TermLink session lifecycle is non-trivial.** Persistent session needs a hub on the host, survives reboots, doesn't drift. Spawn-per-test loses session state mid-evaluation. See Grill #4.
- **The human still has to look.** "Agent runs representative commands and reports evidence" sounds clean but for T-1702 the AC says *"try a representative session"* — that's intentionally human-in-the-loop because the trade-off curve is calibrated by the human's friction tolerance. An agent running 100 scripted commands and reporting "all blocked correctly" doesn't replace the human noticing "my real workflow uses `cat /usr/local/bin/something` and that just got blocked."
- **Cost of maintenance.** Another framework install to keep upgraded, another set of cron jobs, another path to monitor. Onboarding cost is real.

## Grill questions (please answer 1-by-1, or push back on the framing)

### Q1 — Scope conflation: one instance or two?

You said dual-purpose: human-AC review sandbox AND install/upgrade test bench. These pull in opposite directions:

- **Review sandbox** wants: long-lived state, accumulated session history, gradually-evolved learnings, real-feeling environment.
- **Install/upgrade test bench** wants: pristine reset on every run, deterministic starting point, no drift between runs.

Same `/opt/ttt-AEF-Review-instance` for both means a `shred-and-reinit` mid-review-cycle wipes whatever state the human was building — and conversely, accumulated review state contaminates the next install-flow test.

**Pick one:**
- **(a)** One instance, both purposes — accept that "shred" interrupts in-flight reviews; reviews must be fast-and-stateless.
- **(b)** Two instances — `/opt/ttt-AEF-Review-instance/` durable for review, `/opt/ttt-AEF-Test-instance/` ephemeral for install flows.
- **(c)** Push back — these aren't actually in tension because [your reasoning].

### Q2 — What does the agent actually do in the review instance?

When you said "you can actually do" T-1702, what are you authorising?

- **(a)** Agent runs a *fixed scripted* sweep of representative commands (cat, find, du, grep across allowlist boundaries), captures pass/fail, reports evidence; **human still ticks the AC** based on whether the script's coverage matches their mental model of "representative."
- **(b)** Agent runs an *exploratory* session — pretends to be a developer working in the review instance, picks commands organically, reports false-positives it noticed; **human still ticks the AC** but with richer evidence.
- **(c)** Agent ticks the AC itself once a script passes. (This crosses the sovereignty line we just established last turn — flagging in case you actually meant this.)

### Q3 — Lifecycle: who shreds, when?

"Shredded and reinitialized" — what triggers it?

- **(a)** Manual — you run `fw review-instance reset` when you want a clean slate.
- **(b)** Automatic — every install-flow test sequence starts with a shred. Reviews live with whatever state happens to be there.
- **(c)** Per-task — each `fw task review T-XXX` that uses the instance shreds first, runs evidence collection, leaves the result for the human, next task shreds again.

(c) couples nicely to the existing `fw task review` flow but means review state never persists.

### Q4 — TermLink session: persistent or spawn-per-task?

The agent here reaches into `/opt/ttt-AEF-Review-instance` exclusively via TermLink. Two shapes:

- **(a) Persistent session** — one named TermLink session (`aef-review`) lives inside the review instance, survives across this agent's sessions; agent here `inject`s commands into it. State survives within the session until shred.
- **(b) Spawn-per-task** — every `fw task review` that needs evidence spawns a fresh TermLink session, runs its sweep, terminates. No drift, no orphans, but no carry-over either.

(a) matches the "review sandbox" use case (Q1a/Q1b-review). (b) matches the "test bench" use case. If you pick Q1b two-instances, this becomes one each.

### Q5 — Initial install source: master, tag, or pin?

When the review instance reinitialises, what does it pull from?

- **(a)** This repo's `master` (latest unreleased) — review tracks current-tip development.
- **(b)** The latest released tag — review tests "what consumers actually get from `fw upgrade`".
- **(c)** A specific commit pinned by the calling task — for T-1702, pin to commit `0da71bafd` so the review evidence is bound to the exact code-state under review.

(c) is the most rigorous but most ceremony. (b) is what install-flow testing wants. (a) is what live-development review wants. Conflict mirrors Q1.

### Q6 — Failure mode: how do we tell "scenario triggered" from "instance is broken"?

If the agent runs `cat /etc/hosts` in the review instance and gets exit 2, is that:

- **(a)** Pattern 4 of the boundary hook firing as expected (good — that's what we're testing).
- **(b)** The hook itself crashed because the install is busted (bad — meta-failure).

How do we distinguish? Health-check probe before each scenario? Canary command (e.g., `cd /tmp` should always succeed)?

---

## Dialogue Log

### 2026-05-04 — Initial framing
- **User proposed:** Permanent disposable AEF instance at /opt/ttt-AEF-Review-instance, TermLink-driven, dual purpose (review + install testing), shred-and-reinit lifecycle.
- **User authority delegated:** "you can actually do" T-1702 review work using this pattern.
- **Agent response:** Filed inception T-1709, six grill questions before proceeding to a decision.

### 2026-05-04 — Round 1 grill answers

| Q | User answer | Agent reading |
|---|-------------|---------------|
| Q1 | **(b)** two instances | Confirmed. Review-instance durable-ish; Test-instance ephemeral. |
| Q2 | **(c) except high-impact UX + high-risk** | Agent self-ticks Agent ACs — and the previously-Human ACs that are mechanically evidenceable — for everything *except* high-impact UX changes and high-risk changes. Those still need human. **Validation channel:** TermLink agent (a separate reviewer agent in the review instance) checks the calling agent's evidence before tick. **Critical claim:** "we incepted this, GO was granted, but seems not to be wired or used." |
| Q3 | "two instances, but when relevant agent shreds" | Per-task or per-need, agent-driven. Not blanket cadence. |
| Q4 | "persistence where relevant, ephemeral where relevant" | Agent picks per use case. Likely: review = persistent named session; test = spawn-per-run. |
| Q5 | "situational relevant" | Master vs. tag vs. pinned commit picked per task. T-1702 review → pin to commit under review. Install-flow test → tagged release. Live-development review → master. |
| Q6 | **"incept that"** | Failure-mode discrimination (canary vs scenario-trigger) is its own design problem. Spinning out as separate inception. |

### 2026-05-04 — Verification of "we incepted this, GO was granted, but not wired"

**Found:**
- **T-1442** (AC Validation Default-Flip) — `work-completed`. Inception artifact at `docs/reports/T-1442-ac-validation-default-flip.md`.
- **T-1443** (Independent reviewer agent — TermLink-dispatched, evidence-gated, can auto-tick Agent ACs) — `work-completed`. Confirmed-yes locked: *"Reviewer agent (I-B) **may auto-tick Agent ACs** and only escalate Human ACs when reviewer says 'needs human.'"*

**What actually shipped:**
- `lib/reviewer/` — in-process Python reviewer. Writes a `## Reviewer Verdict` block to the task file.
- `bin/fw reviewer T-XXX` — invokes it.
- **Explicit constraint in code:** `lib/reviewer/static_scan.py` carries the comment *"Sovereignty: NEVER modifies AC checkboxes (##{2,}Human or ### Agent)"*. So the verdict-writer ships; the auto-tick half does NOT.
- `agents/reviewer/` — does not exist. The reviewer is not TermLink-dispatched; runs in-process.

**Conclusion:** User's claim is correct. The inception GO authorised both auto-tick and TermLink-dispatch; the implementation shipped neither. What was specced as friction-removal became another verdict to read. The review-instance pattern proposed in T-1709 is the wiring that closes that loop — and it surfaces a question of its own: are we **extending** `fw reviewer` (adding auto-tick + relocating it to the review instance) or **replacing** it (parallel pattern)?

## Decisions

### 2026-05-04 — Two instances locked
- **Chose:** `/opt/ttt-AEF-Review-instance/` (durable) + `/opt/ttt-AEF-Test-instance/` (ephemeral).
- **Why:** Q1 answered (b). The two purposes pull in opposite directions on persistence.
- **Rejected:** Single instance, both purposes — accumulated review state corrupts install-flow tests; shred mid-review wipes evidence.

### 2026-05-04 — Auto-tick policy: agent self-ticks except high-impact UX / high-risk
- **Chose:** Agent self-ticks Agent ACs and mechanically-evidenceable previously-Human ACs. High-impact UX and high-risk changes still require human. Termlink agent in review instance validates before tick.
- **Why:** Q2 answered (c with carve-outs). Maps onto T-1442/T-1443 GO that wasn't fully wired.
- **Open:** what counts as "high-impact UX" and "high-risk"? Boundary not yet defined — see Round 2 grill.
- **Rejected:** (a) scripted-evidence-only, human always ticks — that's the status quo, doesn't move friction needle.

## Round 2 grill — needed before GO

### Q7 — High-impact / high-risk classifier

You carved out "high-impact UX and high-risk changes" from agent-self-tick. We need a bright line so the agent doesn't drift into self-ticking things you'd want to see. Three candidate definitions:

- **(a) Tag-based:** task carries `risk:high` or `ui:visual` or similar. Agent reads the tag, escalates to human.
- **(b) Diff-shape based:** PR touches `web/templates/` (UI), or `agents/context/check-*.sh` (security boundary), or anything in `lib/inception.sh` (governance) → escalate. Static rule list.
- **(c) Reviewer-judgment:** the TermLink reviewer agent decides each AC: "this is mechanical, tick" vs "this needs human". Authority delegated to the reviewer profile.

(c) is the most flexible but moves the failure mode — now the reviewer's classifier is the thing that has to be right. (b) is rigid but auditable. (a) needs disciplined task-tagging.

### Q8 — Extend `fw reviewer` or new pattern?

The existing `lib/reviewer/static_scan.py` writes verdicts but won't touch checkboxes by design. Two options:

- **(a) Extend** — add `--auto-tick` flag to `fw reviewer`, gate by reviewer verdict + AC classification, run inside the review instance via TermLink dispatch. The "Sovereignty: NEVER modifies AC checkboxes" comment becomes "NEVER modifies AC checkboxes UNLESS the verdict says clean and the AC is mechanically classified". Same code, expanded mandate.
- **(b) New** — leave `fw reviewer` as the local static-scanner. Build a separate `agents/reviewer-instance/` profile that runs in the review instance, auto-ticks under the policy. Two reviewers with different mandates.

### Q9 — Initialisation source-of-truth

When `/opt/ttt-AEF-Review-instance` reinits to review T-1702, it needs commit `0da71bafd`. Where from?

- **(a)** Clone this repo, checkout the SHA. Risk: review instance reads dev-tip if the agent forgets to checkout.
- **(b)** Use the GitHub mirror (T-1594, mirror sync). Risk: depends on mirror lag.
- **(c)** A separate origin (not this repo, not GitHub) — review instance has its own remote. Cleanest isolation; most ceremony.

### Q10 — High-risk carveout enforcement

If you say "agent self-ticks except high-risk" and the agent self-ticks something the post-hoc human review reveals was high-risk, what's the consequence?

- **(a) Soft** — agent logs an L-class learning, refines the classifier.
- **(b) Hard** — gate fires, future self-ticks blocked until human re-confirms classifier rules.
- **(c) Human-tunable** — human reviews self-tick log periodically, marks "shouldn't have self-ticked these", classifier learns.

This determines whether self-tick is a one-way ratchet (drifts more permissive over time) or self-correcting.

---

### 2026-05-04 — Round 2 grill answers

| Q | User answer | Synthesis |
|---|-------------|-----------|
| Q7 | **(c) — but check prior work** | T-1442/T-1443 already shipped the classifier as 3-layer model: `policy/escalation-patterns.yaml` (Layer 1 mechanical) + frontmatter `risk`/`human_signoff` (Layer 2) + audit cron Pass B (Layer 3 false-negative net). `policy/anti-patterns.yaml` carries detection_confidence × lie_severity catalogue. The reviewer reads all of these and decides. **Not in dialogue — already decided.** |
| Q8 | **(a) extend — but check prior work** | T-1442 Decision #7 explicitly: *"Extension of existing controls — T-954, P-011, fw verify-acs, fw fabric, fw cron, docs/reports/ reusable; no replacement."* Confirmed. The extension is: TermLink-dispatch (relocating reviewer to review-instance) + auto-tick gated by reviewer verdict + classifier. **Not in dialogue — already decided.** |
| Q9 | **steelman/strawman vs 4 directives** | Two-instance design resolves: review-instance uses **(a)** (clone-this-repo + SHA-pin), test-instance uses **(b)** (GitHub mirror, matches consumer reality). Reject (c) — Reliability gain doesn't outweigh Antifragility/Usability cost. |
| Q10 | **balanced (a)+(b)+(c)** | Error Escalation Ladder applied to auto-tick: Level A first miss = log learning; Level B recurrence = hard gate in that class until human re-confirms; Level C periodic cron review = human-tunable feedback; Level D structural change = de-eligibility of the AC class. |

### Verification of prior-work claims

**Searched:**
- `docs/reports/T-1442-ac-validation-default-flip.md` — full inception artifact, dialogue log, decisions
- `docs/reports/T-1443-independent-reviewer-agent.md` — reviewer agent design with policy file refs
- `policy/escalation-patterns.yaml` — Layer 1 mechanical triggers (destructive-action, external-publish, etc.)
- `policy/anti-patterns.yaml` — anti-pattern catalogue (tautology, etc.) with detection_confidence × lie_severity axes

**Confirmed shipped:**
- 3-layer classifier policy files
- `lib/reviewer/static_scan.py` writing verdicts
- `bin/fw reviewer` CLI
- `bin/fw reviewer audit` daily cron Pass A/B (drift + escalation)

**Confirmed NOT shipped (the gap T-1709 closes):**
- TermLink-dispatched reviewer (lives in review instance, not in-process)
- Auto-tick when verdict says clean AND AC is mechanically classified AND classifier doesn't match Layer 1/2

## Locked design (synthesis — reads as the proposed GO)

### A. Two instances

- **`/opt/ttt-AEF-Review-instance/`** — durable-ish; agent shreds when relevant; init source = clone this repo + checkout the SHA the calling task is reviewing.
- **`/opt/ttt-AEF-Test-instance/`** — ephemeral; shred at start of every install/upgrade flow run; init source = GitHub mirror (matches what `fw upgrade` consumers see).
- Neither is git-tracked.
- Both reachable from this framework agent **only via TermLink** (PROJECT_ROOT path isolation enforced by Pattern 4 — that's the design intent, not a workaround).

### B. Reviewer extension (closes T-1442/T-1443 wiring gap)

Three deltas to existing reviewer:

1. **TermLink dispatch shape** — `bin/fw reviewer T-XXX` adds `--via-termlink-instance <name>` flag. When set, dispatches the reviewer code via `fw termlink dispatch` into the named review instance. Reviewer reads task file + evidence + policy files (synced from this repo into the instance) and emits verdict.
2. **Auto-tick** — when reviewer verdict is `CLEAN`, AND the AC is `### Agent` or `[RUBBER-STAMP]`, AND the AC's parent task does NOT match Layer 1 escalation-patterns.yaml, AND the task frontmatter does NOT carry `risk: high` or `human_signoff: required`, the reviewer ticks the AC checkbox in the task file and posts a tick-receipt to `.context/working/.auto-tick-log.jsonl`.
3. **Sovereignty preserved** — the `### Human` carve-out remains absolute for any AC that survives the gauntlet above. `[REVIEW]` Human ACs never auto-tick.

### C. Auto-tick failure handling (Q10 ladder)

- Append every auto-tick to `.context/working/.auto-tick-log.jsonl` with reviewer verdict digest, classifier inputs, AC class, timestamp.
- Weekly cron (`fw reviewer self-tick-audit`) generates Watchtower page. Human reviews log, marks "shouldn't have self-ticked." Marks feed Layer 1 catalogue tuning + classifier threshold updates.
- 2 misses in same class within 7 days → hard gate; auto-tick disabled in that class until human re-confirms classifier rules.
- Persistent failure across multiple gate-resets → Level D: that AC class moves out of mechanical-tick eligibility (back to Human-only).

### D. Implementation sequence (build tasks if GO)

1. `fw review-instance init <name> --shape review|test --source clone|mirror --sha <sha>` — creates and initialises the named instance in `/opt/ttt-AEF-<Name>-instance`. Idempotent; shreds and reinits if instance exists.
2. `fw review-instance shred <name>` — explicit teardown.
3. `fw review-instance dispatch <name> <command>` — wraps `fw termlink dispatch` with the instance's working directory.
4. Extend `bin/fw reviewer` with `--via-termlink-instance` + `--auto-tick` flags.
5. Implement classifier-gate logic in `lib/reviewer/auto_tick.py` (new file) consuming existing `policy/escalation-patterns.yaml` + `policy/anti-patterns.yaml` + frontmatter.
6. `.context/working/.auto-tick-log.jsonl` schema + weekly cron + Watchtower self-tick-audit page.
7. T-1710 (Q6 spinoff) failure-mode discrimination — canary command before each scenario; health-probe; runs before any auto-tick gate fires.

### E. Out of scope (file as separate inceptions if needed)

- Re-classifying every existing Human AC backlog (T-1442 Decision #8: "incremental, not bulk").
- Cross-machine review-instance federation.
- Replacing `fw reviewer` (T-1442 Decision #7: extension only).
- Multi-tenant review instances (one host, one instance per shape; v2+ if needed).
