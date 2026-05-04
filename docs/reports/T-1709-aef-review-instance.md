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
- **Agent response:** Filed inception T-1709, six grill questions before proceeding to a decision. Awaiting answers.

(Future entries: each user response → captured here, my read of it → captured, course corrections → captured.)

## Decisions

(none yet — pending grill answers)
