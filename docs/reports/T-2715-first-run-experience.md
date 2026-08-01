# T-2715 — First-run experience: why four green install surfaces missed a blocked user

**Status:** exploration in progress (grill round 2 open)
**Started:** 2026-08-01
**Trigger:** first external user (Mehdi, `/home/mehdi/2026-AEF-demo`) blocked during install;
four framework self-test surfaces green throughout.

---

## 1. Problem statement

The framework already has four surfaces that claim to verify installation and onboarding:

| Surface | Scope | Origin |
|---|---|---|
| `tests/unit/upgrade_fresh_machine_simulation.bats` | 7 tests, synthetic consumer under `env -i` | T-1633/T-1635 |
| `fw test-onboarding` | 8 checkpoints, end-to-end onboarding flow | — |
| `tests/e2e/onboarding-test.sh` | e2e onboarding | — |
| `fw self-test onboarding` | phase in the self-test ladder | — |

All four were green while a real user was blocked, and while four install/upgrade defects
shipped and were fixed in a single session (T-2710 regenerate wiping hooks, T-2711 self-vendor
not syncing `bin/*.sh`, T-2712 re-seeding task IDs over used ones, T-2713 fabricated version
relation on 23 of 27 consumers).

**The question this exploration must answer is not "should we test installation" — we test it
four times. It is: why do four green lights coexist with a blocked user?**

Adding a fifth surface without answering that produces a fifth green light. This is the same
defect class as the four fixed this session: *a check that reports success about the wrong object.*

## 2. Findings so far

### F-1 — `install.sh` mutates the host it runs on

```
INSTALL_DIR="${INSTALL_DIR:-$HOME/.agentic-framework}"   # install.sh:16
git -C "$INSTALL_DIR" reset --hard "origin/$BRANCH"      # install.sh:162
```

On this host `/root/.agentic-framework` exists (at `dfb967473`) and `~/.local/bin/fw` +
`~/.local/bin/claude-fw` symlink into it. Running the README greenfield prompt verbatim here
would hard-reset the framework install the host runs on. A directory under `/opt` is the
*project*; the framework install is machine-wide.

Precision (L-158, T-528): the update path *does* dirty-check and warn
(`warn "Local modifications in $INSTALL_DIR will be overwritten"`, install.sh:150/160) before the
reset. So this is a warned destructive default, not a silent one. `--install-dir` / `INSTALL_DIR`
exist, so isolation is achievable. The residual hazard is that the *default* targets `$HOME`, and
an unattended agent worker will not read a warning and stop.

### F-2 — deleting the project directory does not reset the machine

Because the install lives in `$HOME`, `rm -rf /opt/test-N` leaves it behind. Run 2's STEP 2 hits
the *existing-install* branch (`install.sh:134`), a different code path from a first install.

**Consequence:** "repeat many times" as originally proposed yields **one greenfield run and N−1
upgrade runs, all labelled greenfield.** Same shape as T-2712 — the guard asks a question adjacent
to the one it needs. Containerisation fixes this incidentally: `~/.agentic-framework` lives inside
the container, so destroying it genuinely resets the machine.

### F-3 — the agent repairs what the user could not (deepest finding)

The README prompt instructs repair explicitly:

> If a step fails, try the self-heal in that step before stopping

So a run measures **"can a competent agent recover from our installer"**, not **"is our installer
correct"**. Both are legitimate questions; pass/fail collapses them into one signal. Mehdi could
not self-heal — that is the entire reason this arc exists.

**Proposed metric: repair count, not pass/fail.** A run that succeeds after nine self-heals is a
failing installer wearing a good agent as a disguise. Capture per run: every command, exit code,
each self-heal (what broke / what was tried), wall time, stop point.

### F-4 — oracle problem

If pass is "`fw doctor` exits 0", the judge is the component that has been lying: OBS-110 (doctor
mislabelled matcher entries as hooks, fixed in T-2714 the same day) and T-2713 (doctor fabricated
ahead/behind direction for 23 of 27 consumers). Doctor cannot be both system-under-test and judge.
Needs an independent behavioural oracle — something that fails when governance is *off*, not when
governance *says* it is on.

### F-5 — goals 2 and 3 may be the same object

The README prompt **is** the onboarding script: a program written in English, executed by an agent.
Separately a seeded onboarding scenario already exists (`T-001..T-006`, plus
`fw onboarding status|skip|reset`). The existence of a `skip` verb suggests it was expected to be
skipped. **Open empirical question:** has any user ever completed the seeded onboarding tasks, or
does everyone skip?

### F-7 — the onboarding scenario teaches the AGENT, not the human

`lib/seeds/tasks/greenfield/T-001-orientation-and-framework-health.md`:

```
owner: agent
### Agent
- [ ] Read CLAUDE.md — understand core principle, task system, enforcement tiers
- [ ] Run `fw doctor` — all checks pass
- [ ] Run `fw audit` — note current state
- [ ] Install git hooks: `fw git install-hooks`
```

**Four ACs, all `### Agent`. Zero `### Human` ACs in the orientation task.** The criterion that
carries the actual education — *understand core principle, task system, enforcement tiers* — is
assigned to the agent. The human's onboarding consists of watching an agent tick four boxes.

This is the likeliest explanation for the skip verb existing: if the human is taught nothing, then
skipping costs the human nothing. The scenario is not failing to teach well — it is not aimed at
the human at all. Same audience-axis error CLAUDE.md already codifies for AC routing (T-2143).

### F-8 — the bypass exists but is undiscoverable

`fw onboarding skip` is implemented (`bin/fw:6284`, writes `.onboarding-complete` with a reason)
but appears **nowhere** in `README.md`, `lib/init.sh`, or `docs/*.md`. So "add a hard bypass" may
be substantially a *discoverability* problem rather than a missing capability. Needs confirming
with the operator (what specifically is deficient — undiscoverable, not hard enough, or wrong
granularity?).

### F-9 — RETRACTED 2026-08-01: the existing-codebase path DOES have a scenario

**Original claim (false):** *"`lib/seeds/tasks/greenfield/` holds 5 tasks. `lib/seeds/tasks/existing/`
is empty. Option B users get no onboarding at all."*

**What is actually there:** the directory is `lib/seeds/tasks/existing-project/` — not `existing/` —
and it holds **6** tasks (orientation, first governed commit, register key components in fabric,
complete a task lifecycle, generate first handover, record first project learning).
`lib/init.sh:507` selects it by that name. The original check looked at a path that has never
existed, found nothing, and reported a capability gap.

**Same defect class as the inception's own thesis, fifth instance this session** — a check that
reports confidently about the wrong object. The four prior instances (the `crontab -l` false
drift finding, two wrong premises on IW-21, the lane-band checker that disagreed with
`corpus lint` on 9 of 11 projects) were all caught before shipping. This one was written INTO the
findings at confidence 3 and survived until IW-11's premise check. It is the strongest single piece
of evidence in this artifact that the scenario needs to exist: the mechanism under investigation
failed inside the investigation of it.

**What survives of the finding:** the two seed sets are not equivalent in *content* — greenfield's
T-002 is "define project goals" (`owner: human`), which existing-project has no analogue for,
and existing-project adds fabric registration + a learning-capture task. Whether option B needs a
separate *scenario* (as distinct from its already-existing seed tasks) is a real open question —
that is what IW-17 now asks, on corrected ground.

### F-6 — coverage limit that no isolation choice fixes

README STEP 1's self-heal targets **macOS bash 3.2**. Untestable on Linux, container or VM. If Mac
users are in scope, that path stays unverified regardless of what we build here.

## 3. Decisions

### D-1 (2026-08-01) — Two-tier isolation: Docker for the fast loop, VirtualBox for the release gate

- **Chose:** Tier 1 = Docker container (fast iterative loop, many runs).
  Tier 2 = VirtualBox VM (release gate, few runs, high fidelity).
- **Why:** Both fully isolate the thing that actually bit us — `$HOME`-level framework state.
  They differ ~60× in reset cost (~1s vs ~1min incl. boot, plus base-image build for the VM).
  The first deliverable is a *diagnosis* requiring many cheap runs, because prompt behaviour is
  non-deterministic and variance is invisible at small N. The VM earns its cost on the legs a
  container cannot honestly test: **cron** (framework writes `/etc/cron.d/`; L-365 —
  "deployed is not executable"), systemd, and reboot persistence.
- **Rejected:** VirtualBox-only — would cost the iteration speed the diagnosis needs most.
  Docker-only — would leave the cron/systemd/reboot legs permanently unverified and quietly
  reclassify them as "covered" (§ACD risk).
- **Continuity:** matches T-1635's own recorded intent ("a docker-container variant remains a
  release-gate follow-up for higher-confidence *true fresh machine* coverage") — with the
  stronger VM tier now available.
- **Host state (verified 2026-08-01):** bare metal, `/dev/kvm` present, Docker 29.6.2,
  VirtualBox 7.0.16 already installed with `vboxdrv` loaded alongside `kvm_amd` without conflict,
  no VMs defined (so no base image yet — that is Tier 2's setup cost), 1.1T free.
  `claude` CLI 2.1.220, `termlink` 0.11.693.

### D-2 (2026-08-01) — Run as a non-root user

- **Chose:** the test image runs the install as an unprivileged user.
- **Why:** this session runs as root; Mehdi does not. Root papers over the entire
  permissions/`$HOME`-layout defect class. Neither container nor VM gives this for free — it must
  be chosen deliberately.

### D-3 (2026-08-01) — Credentials are a fixture, framework state is contamination

- **Chose:** mount `~/.claude/.credentials.json` read-only into the clean machine; mount nothing
  else from `~/.claude` — explicitly **not** the host's `settings.json` (95KB, carries our hooks).
- **Why:** for fidelity the agent must run *inside* the machine being installed to (Mehdi's agent
  ran on Mehdi's machine). Every real user has credentials; no real user has our
  `~/.agentic-framework` or our hook config. Mounting settings.json would smuggle governance into
  a machine defined by not having any.
- **Known tradeoff, accepted knowingly:** places a live OAuth token inside a throwaway container.
  Local and ephemeral; flagged rather than discovered later.

### D-4 (2026-08-01) — Keep and improve the onboarding scenario; add a hard bypass AND deepen the education

- **Chose (operator):** do not throw out the current onboarding scenario. Test it, review it,
  reflect on it, improve it. Add a hard bypass option. Separately enrich it so it explains the
  workings of AEF step by step. Target properties: *frictionless onboarding* plus *gradual
  deepening discovery of capabilities, workings and functionality*.
- **Why (agent reading):** the two halves are complements, not a tradeoff. Friction only hurts
  when it is inescapable — a discoverable, honest bypass is precisely what makes richer education
  safe to add. That is why "bypass" and "more teaching" belong in the same decision.
- **Consequences not yet settled** (see IW-13..IW-16): whether the student is the human or the
  agent (F-7 says the current answer is "agent", which is likely wrong); whether the scenario stays
  a *prologue* or becomes a curriculum *interleaved* with real work — "gradual deepening" is
  structurally incompatible with a front-loaded block; whether education is *contained in* the
  scenario or *routed to* existing detail (operator's own T-2622 precedence decision says MD thins
  to principles + pointers, detail lives in the maps — embedding explanations here would create a
  second source of truth that drifts); and whether option B (existing codebase, F-9) gets a
  scenario too.
- **Supersedes:** the agent's earlier framing that the skip-rate data would decide keep-vs-replace.
  Keep is decided. The data now serves a different and better purpose — locating *where* the
  scenario loses people, as input to the improvement.

### D-5 (2026-08-01) — BVP-gated serial arc progression

- **Chose (operator):** three arcs worked **serially**. Work arc A until all **HV/HC and HV/LC**
  tasks are complete, then arc B on the same criterion, then arc C. Requires **arc-scoped value
  drivers created upfront**. Purpose: incremental delivery with a learn-and-iterate boundary
  between arcs.
- **Why this is better than the four options offered:** all four tied arc closure to a property of
  the *installer* (clean runs, findings dryness) or of the *instrument*. None used value. Gating on
  "all high-value work done, regardless of cost" is falsifiable, already instrumented, and does not
  couple arc A's closure to fix work it does not own (IW-9).
- **Machinery verified live 2026-08-01:** `fw arc approve-driver|remove-driver|set-scoped-weight|
  show-suggestions` (T-1926/T-1976/T-1977); global drivers D1 Antifragility 9, D2 Reliability 7,
  D3 Usability 5, D4 Portability 3, plus free drivers incl. F-RECALL 6, F-AUTONOMY 4,
  V_PROMPT_QUALITY 7, V_CONTEXT_FABRIC 7, V_COMPONENT_FABRIC 6.
- **Cost this introduces (IW-20):** `fw bvp rank` reports **zero tasks corpus-wide carry confirmed
  `bvp_scores:`**. Confirmation is a sovereignty boundary (`fw bvp confirm --i-am-human`, T-1924) —
  so arc progression now depends on per-task human scoring. The estimator (T-1922) proposes
  automatically, but fires at task *creation*, before the body is written: T-2715's proposal at
  10:03 was all-2s with "no-signal" on every driver because the body was still template at that
  moment. Confirming those would be rubber-stamping noise; proposals want re-running once bodies exist.
- **Residual risks:** (a) HV-complete is a *progress* criterion — G-062 still demands the headline
  mechanic fire with a demo artefact, and completing every HV task could be pure substrate (IW-18);
  (b) under file-and-continue the HV set *grows*, so "all HV complete" can recede indefinitely
  unless snapshotted (IW-19); (c) three arcs × up to 3 scoped drivers = up to 9 — R5 applies:
  *manufacturing drivers to look thorough is worse than proposing zero and recommending `--none`*.
- **Note:** the loader verbs `fw bvp driver suggest|create` are deferred (T-2245 IW-3); the
  arc-scoped driver protocol is invoked manually from `policy/prompts/bvp-driver-session.md`.

### D-6 (2026-08-01) — Arc exit is a recalc gate, not a snapshot lookup

**The risk, in the operator's words:** *"tasks are scored at a point in time, and their actual score
(now) vs recorded score (last calculation) can be different and land in a different quadrant — this
could lead to arc exit criteria checks"* being wrong. D-5 makes the quadrant the scope decision, so
a stale quadrant means an arc can read *"no HV tasks left"* when the truth is *"no HV tasks by
yesterday's arithmetic."* The arc closes green while carrying unfinished high-value work, and no
component reports an error, because each did its job correctly with the inputs it had. **Same defect
class as §1** — a check reporting success about the wrong object.

**Two premise corrections during the grill (agent had it wrong twice):**

1. The estimator is **already arc-aware** — T-2357 `_arc_scoped_drivers_for_task()`
   (`agents/termlink/bvp-estimator/estimator.py:125`) resolves `arc_id:` → arc YAML → **approved**
   `scoped_drivers:` (proposed ones deliberately do not fire). D-5's "scoped drivers upfront"
   already has a consumer.
2. Re-estimation **already exists and runs** — `bvp-estimator-sweep-15m` (T-1923), deployed at
   `/etc/cron.d/agentic-audit-999-*`, last fired 21:00 on 2026-08-01. The agent's first check used
   `crontab -l`, which shows nothing because the framework deploys to `/etc/cron.d`. **Wrong object,
   clean report, false drift finding narrowly avoided** — the inception's own thesis, self-inflicted.

**The actual gap:** the sweep triggers on **age** (`_proposed_is_stale`, >24h), not on arc
assignment. A task assigned to an arc while its score is fresh is *skipped* — arc-scoped scoring
arrives up to a day late. Two further holes: `if fm.get("bvp_scores"): continue` means a
human-confirmed task moved between arcs never re-scores; and `rubric_sha` hashes the rubric *file*
(module-cached, identical for every task), so nothing records **which drivers a proposal was
computed against** — there is no stored evidence of arc drift to detect.

**Decision — recompute at the decision point.** Adopted over all four agent-proposed trigger seams
(PreToolUse hook / `fw arc tag` / staleness-gate removal / close-gate-only). Rationale: it compares
**state** rather than subscribing to **events**, so it is indifferent to how `arc_id` was set — hook,
verb, or hand-edited frontmatter. Every event-based option had a bypass path.

```
on agent completion of an arc task:
    recalc all arc tasks (arc-scoped drivers included)
    pick next HV/HC or HV/LC
        found  -> work it
        empty  -> invoke arc exit workflow

arc exit workflow:
    1. recalc all arc tasks
    2. any task in HV/HC or HV/LC?
         yes -> RETURN TO ARC, do not close, report which + why
         no  -> proceed to G-062 close gates
```

- **`recalc-then-pick` is one primitive.** The pick must recalc first or it reads the same stale
  scores. Empty result *is* the exit condition — no close-readiness heuristic, no polling. It also
  subsumes the operator's proposed `/resume` recalc: session start is another *"what's next in this
  arc?"*.
- **Exit is a gate, not a formality.** Recalc can *promote* an LV task to HV, at which point the arc
  is not done. Re-entrant and convergent: a score only moves when the task body or the arc's drivers
  actually change, so it cannot oscillate.
- **The bounce-back must be explained** — which tasks re-surfaced, which driver moved them, from
  what. An unexplained refusal to close trains `--force`, which defeats the mechanism.
- **Named gap:** the completion trigger fires only on *agent* completion. A human closing the last HV
  task, or tasks re-scoped out of the arc, trigger nothing — so `fw arc close` must re-run the same
  check as backstop.

**Companion decision (IW-22) — the priority flag replaces confirmed scores.**

**Scope, stated precisely, because loose wording here reads as something far larger.** BVP scoring is
NOT being retired — it becomes *more* load-bearing, since under this decision the estimator's score is
the only score and is always fresh. Exactly one field is replaced: `bvp_scores:`, the **human-confirmed**
per-driver 0-5 map set by hand via `fw bvp confirm` (T-1924). Untouched: the estimator,
`bvp_scores_proposed:`, `cost_estimate:`, the value drivers, arc-scoped drivers, the quadrants,
`fw bvp rank`, auto-promote.

| Field | What it is | Tasks carrying it (2026-08-01, active+completed) |
|---|---|---|
| `bvp_scores_proposed:` | agent estimator output | **2519** |
| `bvp_scores:` | human hand-set 0-5 per driver | **0** |

Scoring becomes always agent-driven; the human raises a flag ("treat as high value / do this now")
instead of setting per-driver numbers. This removes the confirmed-score short-circuit entirely, and
moves sovereignty from *arithmetic* to *intent* — the axis humans are actually reliable on. The
replaced field is unused in practice, but not harmless: the moment anyone *did* set `bvp_scores:`,
`if fm.get("bvp_scores"): continue` would freeze that task's score permanently. The flag delivers the
same override without freezing anything. Two additions the flag needs: a **direction** (a push-*down*
too, or an over-scoring estimator holds an arc open forever with `--force` the only escape) and a
**rationale field** (so a blocked arc can say why).

**Placement (IW-23, open):** this is arc-*running* infrastructure — it applies to all three arcs and
every arc after them, so it does not belong inside the install-testing arc. Candidate shape: an
`aef-arc-exit` designer-corpus map plus a conformance rail against the implementing code, mirroring
`aef-task-lifecycle` (T-2624). Sequencing note: it gates the closure of the very arcs D-5 creates,
so it plausibly ships first.

## 4. Open questions

Filed as IW-1..IW-12 in the task file (disposition gate T-2190/G-067 tracks them).
Summary of what remains the operator's call:

| # | Question | Agent lean |
|---|---|---|
| IW-1 | Isolation mechanism | **answered** → D-1 |
| IW-2 | Greenfield only, or also upgrade-of-legacy-consumer? | both |
| IW-3 | Self-heal or halt-on-first-error? | both modes, halt first |
| IW-4 | Pass oracle | first governed commit + gate blocks ungoverned edit |
| IW-5 | One arc or two? | one, fenced paste → first governed commit |
| IW-6 | Run budget, serial/parallel | operator's |
| IW-7 | Who answers `[ASK]` in an unattended run? | open — operational blocker |
| IW-8 | Public mirror or local master? | mirror (what users hit) |
| IW-9 | Fix-or-file when a run finds a bug | file and continue |
| IW-10 | Definition of done | loop-until-dry |
| IW-11 | Persona — agent-assisted, or by-hand reader? | open |
| IW-12 | Failure taxonomy | needed before runs start |
| IW-21 | BVP wire-in at arc assignment | **answered** → D-6 (recalc-then-pick + exit gate) |
| IW-22 | Priority flag replaces confirmed scores | **answered** → D-6 companion (needs direction + rationale) |
| IW-23 | Where the arc-exit mechanism lives | open — agent lean: standalone, corpus map, ships first |

## 5. Proposed arc

**Headline mechanic (G-062 — must name the observable result):**

> A fresh operator pastes the README greenfield prompt into a clean agent on a clean machine and
> reaches their first governed commit without hand-repairing the framework.

**Demo artefact:** the worker's transcript + the resulting project's git log + repair count.
Wire-level and traceable.

**Proposed scope fence:** paste → first governed commit. Both tiers inside; installer fixes filed
as separate tasks (pending IW-9).

## 6. Dialogue log

### 2026-08-01 — Round 1: operator proposes the harness

**Operator:** first external user hit issues installing yesterday. Proposes: use TermLink to test
greenfield installation using the README prompt, in a throwaway `/opt` directory, repeatedly
(create → test → destroy). Three goals: (1) test the install script, catch and resolve errors,
(2) test the prompts, catch inefficiency/deficiency, improve them, (3) onboarding scenario/script —
asked the agent to reflect on whether goal 3 is well-formed. Suggested making an arc of it, and
explicitly asked to be grilled before settling.

**Agent response:** agreed on the arc, but reframed the first deliverable — four green surfaces
already exist (§1), so the opening question is why they were green, not whether to add a fifth.
Raised F-1 (host mutation), F-2 (the reset leak), F-3 (agent-as-repairer), F-4 (oracle), F-5
(goals 2 and 3 may be one object), F-6 (macOS untestable). Posed six questions.

### 2026-08-01 — Round 2: isolation

**Operator:** "then we should add a virtual machine to this machine and install in the virtual
machine, does that make sense?"

**Agent:** yes — isolation is right, but recommended container over VM on reset-cost grounds
(~60× per run), with non-root execution as a deliberate fidelity gain.

**Operator:** "maybe we should install virtualbox?"

**Agent:** verified VirtualBox 7.0.16 is *already* installed with `vboxdrv` loaded alongside
`kvm_amd` — nothing to install, and the earlier "installation risk" objection evaporates.
Revised position from "don't" to "not first": two tiers (D-1), with the operator's VM instinct
correctly placed as tier 2 rather than wrong. Named cron as the concrete leg a container cannot
honestly test.

**Operator:** "ok lets record that and include that in the arc planning and continue with the
grilling."

**Outcome:** D-1, D-2, D-3 recorded. C-002 exploratory-conversation guard fired (well past three
substantive exchanges on an untracked topic) → this inception task (T-2715) and artifact created,
IW-1..IW-12 filed. Grill continues at round 2 (IW-7..IW-12).

**Correction made during capture:** the agent's first statement of F-1 implied a silent
destructive reset. L-158 (T-528) surfaced during `work-on` and showed `install.sh` dirty-checks
and warns first. F-1 corrected — the hazard is the `$HOME` default plus an unattended worker that
will not stop for a warning, not silence.
