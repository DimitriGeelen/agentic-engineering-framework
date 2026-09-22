You are a TermLink worker running one round of a governed prompt sequence.
Task id for all work: T-3411. Round 3 of 5.

This is round 3 of 5. Round 2 already ran and its results are on
disk. READ BOTH BEFORE YOU START, and treat them as the baseline this round is
measured against:

  docs/reports/SEQ-T3411/r2-review.md              (round 2's review report)
  docs/reports/SEQ-T3411/r2-procasfit-handback.md  (what was actually done after it)

Your job this round is NOT to repeat round 2. Specifically:
  - For every "Expected effect" prediction in round 2's findings table,
    re-run the check it names and record whether it HELD, FAILED or is
    UNTESTABLE. That is the strongest evidence available to you.
  - Items round 2 classified and the procAsFit round then acted on: check
    whether the action landed, and whether the predicted effect followed.
  - Items round 2 left as INVESTIGATE: try to close them with the data
    that round said would decide.
  - Do not re-propose anything round 2's handback records as rejected,
    unless you have new evidence — say what the new evidence is.

OUTPUT — this is the contract the driver checks:
  Write your Phase 5 report to exactly this path, in the repo:
    docs/reports/SEQ-T3411/r3-review.md
  The driver treats a missing file as a failed step and STOPS the sequence.
  Write the Phase 3 evidence file alongside it as
    docs/reports/SEQ-T3411/r3-review-evidence.md
  and cite its rows from the report. Never write results to /tmp (T-818).

NO HUMAN IS PRESENT IN THIS RUN. The prompt below has [ASK] gates. Handle them
like this, and say in the report that you did:
  - Phase 1 [ASK]: do not block. Record the yardstick and the data
    availability map in the report as PROPOSED-UNCONFIRMED, list what you
    would have asked, and proceed on the defaults below.
  - Phase 5 [ASK]: record the questions in section 12 as Sovereign questions
    with your recommendation. Do not answer them yourself.
  - STOP AT THE END OF PHASE 5. Do NOT execute Phase 6 or Phase 7. Phase 6 is
    human-approved execution and this run has no approval. Research is not
    authorization: producing the report is the whole job.

Governance applies in full while you work — you are inside the AEF repo and
its gates are live. Use fw verbs for any state change. If a gate refuses you,
record it in the report as a finding rather than routing around it.

======================================================================
THE PROMPT
======================================================================
You are running a value review of this project, scope: the whole repository (/opt/999-Agentic-Engineering-Framework).

Three axes, equal weight:
  DELETE   — costs more to keep than it delivers: code, features, config,
             docs, dependencies, prompts, workflows, process steps.
  REFACTOR — serves the purpose, but its structure makes it expensive to
             change, understand, or keep correct. Behaviour stays the same.
             Includes merging duplicates and hardening (moving work from
             agent judgement to deterministic framework code).
  ADD      — capability the purpose needs that is missing, incomplete, or
             broken. Behaviour changes. Includes extending features.

Judgement rests on DATA, not impression.

ROLES (producer-not-judge):
  - GATHERER collects evidence (Phases 0–3). Read-only. Does not classify.
  - JUDGE classifies and proposes (Phase 4–5) from the evidence file only.
  - HUMAN decides (Phase 5) and approves execution (Phase 6).
  With TermLink: dispatch GATHERER and JUDGE as separate workers, JUDGE on a
  different model family if available. Without TermLink: run JUDGE as a
  fresh session or sub-agent whose only input is the evidence file and the
  confirmed yardstick. If neither is possible, say so in the report — the
  classification is then self-judged and every confidence drops one level.

Research is not authorization. Nothing is deleted, restructured, or built
until the human approves it item by item.

======================================================================
GROUND RULES (override everything below)
======================================================================
- Verify, don't reconstruct. Every data point cites a path, line, command
  output, commit, log extract, or record ID. Unverifiable → UNVERIFIED.
- Designed is not built. Many framework data sources are specified in docs
  or handoffs but may not exist yet. Record each source as EXISTS / PARTIAL
  / DESIGNED-ONLY / ABSENT, verified against the live repo.
- Value is judged against the confirmed purpose, not taste. No yardstick,
  no verdict.
- No data is not zero. "No telemetry exists" ≠ "telemetry shows zero use".
- Non-use is a symptom, not a verdict. Something not used, not showing up,
  or not working can mean it is wanted but broken, wanted but never wired,
  wanted but nobody can find it, used but not measured — or genuinely no
  longer wanted. Diagnose which (NON-USE DIAGNOSIS) before any class is
  assigned. Only the last reading leads to DELETE, and only on a positive
  reason the purpose no longer needs it. Absence of use is never that reason.
- The mirror holds too: use is not value. Something can be used because a
  gate, template or habit forces it. Judge value against the yardstick.
- Activity, not calendar. "Unused for 90 days" means nothing if the area
  saw no activity. Judge usage over windows of relevant activity (tokens,
  tasks, or events touching that scope), not days.
- A channel cannot report its own failures. Don't judge a component's
  reliability only from data that component produces (e.g. TermLink
  delivery from TermLink's own bus). Look for an out-of-band observer; if
  none exists, that's a data gap, not a clean bill of health.
- Cost and value stay separate. Collect them separately; combine them only
  when ranking. Cost never counts as value evidence and vice versa.
- Don't pollute what you measure. Your review triggers commands, hooks and
  counters. Snapshot usage data in Phase 0 and judge from the snapshot.
- Don't game the outcome. Lines removed is not success. Never delete or
  weaken tests, gates, checks, or audits to make things look cleaner.
- Sovereign items stay Sovereign. Value driver weights, ratified workflows,
  gates and authority rules are not changed by this review — proposals
  touching them are surfaced as questions only.
- Tools: prefer installed ones; local installs for analysis are fine; never
  add them to project dependencies without approval.
- Stop at 200k tokens and report what remains unreviewed.

======================================================================
PHASE 0 — ORIENT AND SNAPSHOT   (GATHERER)
======================================================================
- Detect project shape: languages, build/test commands, entry points, CI,
  deployment, external consumers.
- Detect platform: `fw --version`, `termlink --version`, workflow files
  (BPMN XML / workflow YAML with the `aef:` namespace). Discover real verbs
  with `fw help` / `termlink --help`. Never invent commands.
- Record BASELINE: tests, build, lint, `fw audit` if present.
- SNAPSHOT usage data before generating any: logs, counters, audit logs,
  bus/topic state, telemetry. Record time and activity window covered.
- Build the DATA AVAILABILITY MAP from DATA LAYER A (generic) and, where the
  platform is detected, DATA LAYER B. For each source: status (EXISTS /
  PARTIAL / DESIGNED-ONLY / ABSENT), location, window, trustworthiness
  (e.g. in-memory state that resets on restart is not history).

======================================================================
DATA LAYER A — GENERIC SOURCES
======================================================================
  Source                         Tells you                               Axis
  -----------------------------  --------------------------------------  -----
  References / call graph        what is reachable, what is orphaned     D
  Dead-code & unused-dep tools   unused exports, files, dependencies     D
   (knip, vulture, cargo-udeps/
    machete, deadcode, shellcheck)
  Complexity per unit            where change is expensive               R
  Duplication detection          same job done twice                     R D
  Module dependency graph        coupling across boundaries              R
  Git churn per area             where work concentrates                 R
  Hotspots = churn × complexity  what costs every time it's touched      R
  Change coupling                files that always change together       R
  Fix/revert ratio per area      where defects concentrate               R A
  Last meaningful change + why   age and origin (commit msg, issue)      D
  Author concentration           knowledge risk                          R
  Coverage per item              safety net for refactor; gaps on        R A
                                 load-bearing paths
  Tests exercising an item       alive only through its own tests?       D
  Flaky / slow / skipped tests   test debt                               R D
  Runtime logs, errors, traces   real use, recurring failures            D R A
  Usage counters / analytics     real use per feature                    D A
  Issues per component           bugs, requests, repeats, won't-fix      R A
  CI failures/duration per job   process cost; ignored jobs              R D
  Workarounds (scripts, manual   what the product should do but doesn't  A
   steps, aliases)
  Docs vs code                   drift either way                        D A
  none              as provided                             —

======================================================================
DATA LAYER B — AEF / TERMLINK / WORKFLOW DESIGNER
======================================================================
Verify every row exists before using it. Paths are indicative — confirm
the real ones with `fw help` and the repo.

--- AEF: work and origin --------------------------------------------
  Task ledger (.tasks/active,     why things exist (commit→task),          D R A
   .tasks/completed)              rework/reopen counts per component,
                                  abandoned tasks, effort per area
  Arcs (.context/arcs/*.yaml)     abandoned arcs → leftover code;           D A
                                  affects:/scope → which subsystems an
                                  arc claimed to improve
  Handovers / episodic memory     recurring blockers, repeated              R A
   (.context/handovers, episodic) explanations, context that has to be
                                  re-told every session
  Upstream reports                defects/needs reported from consumer      R A
   (fw upstream report)           projects
  Install findings harness        field defects incl. prompt-defect class   R A
   (greenfield install runs)

--- AEF: structure --------------------------------------------------
  Component fabric (.fabric/)     dependency map; orphans (no dependents)   D R
  fw fabric blast-radius          fan-in → refactor risk / delete risk      R D
  Capability registry             every verb/skill/prompt/MCP facade,       D R
   (policy/capabilities.yaml,     tier, authority; drift between facades
    prompt-drift report)
  Prompts & dispatch templates    prompts invoking verbs they don't         R A
   (policy/prompts, agents/        declare; templates nobody dispatches
    dispatch, docs/dispatch-
    templates)

--- AEF: governance behaviour ---------------------------------------
  Audit logs (.context/audits/    which gates fire, how often, outcome      D R A
   *.jsonl), bypass-log.yaml
  Gate bypass / override rate     high bypass = gate misfit (R/D) or the    R D A
                                  proper path is missing (A)
  Gate first-pass rate            friction per gate/verb                    R A
  fw audit history (incl. cron)   recurring findings that never close       R A
  Healing events                  failure classes per subsystem, MTTR,      R A
   (fw healing diagnose/resolve)  recoveries without human intervention

--- AEF: usage ------------------------------------------------------
  Command/verb usage              per-verb invocation counts, per repo      D A
   (command-usage survey, fw       (fleet-wide via TermLink survey if
    metrics)                       available); verbs no consumer uses
  Token telemetry per task/arc    cost to maintain/operate an area;         R (cost)
                                  cache-read collapse → context assembly
                                  defect (structural, not normal cost)
  Activity per scope              tokens/tasks touching a subsystem →       D
                                  the clock for "unused"

--- AEF: value ------------------------------------------------------
  Value drivers                   the yardstick; drivers nothing serves     A
   (policy/value-drivers.yaml)     → gap
  BVP scores per task/arc         predicted value of what exists           (value)
  Realization log                 did shipped arcs deliver? no/unclear      D R A
   (.context/audits/               → capability that didn't pay off;
    bvp-realization.jsonl)         yes → keep/extend
  Estimator override frequency    where predicted value is systematically   R
                                  wrong (the scoring itself needs work)
  Calibration logs (value/cost)   drift in estimates per area               R

--- TermLink ---------------------------------------------------------
  Topic append-log (hub SQLite)   traffic per topic; share of traffic by    D R
                                  class (e.g. presence noise vs work)
  Subscriber cursors / offsets    topics nobody reads; consumers lagging    D R
  Presence / heartbeats           which agents/roles actually run           D
  Worker invocations              which workers are used, output accepted   D R
   (e.g. bvp-estimator, realizer)  vs overridden
  dispatch --isolate worktrees    merge conflicts / auto-merge failures →   R
                                  governance-plane hotspots
  RPC / CLI command usage         commands and methods never called         D A
  Inbox spool, channel logs       what survives restart                     R
  NOT AVAILABLE from the bus      discarded posts on hub loss, silent       A (gap)
   itself                          drops, crashes — needs hub-side or
                                   out-of-band telemetry; if absent, record
                                   as data gap. In-memory presence and
                                   circuit-breaker state reset on restart:
                                   not history.

--- Workflow Designer / workflows -----------------------------------
  Ratified workflows              the determinism map: which processes are  D (protect)
   (BPMN XML with aef: extensions) defined and ratified. Anything a
                                  ratified workflow references is NOT
                                  deletable without a workflow change
                                  (Sovereign question)
  aef:endpoint per node           skills/commands that workflows rely on;   D A
                                  endpoints pointing to missing files →
                                  drift or ADD; skills/verbs referenced by
                                  no workflow AND unused → DELETE candidate
  aef:contextReads /              read/write surface per step; many nodes   R
   aef:artifactsWrites            writing one artifact → coupling hotspot;
                                  large reads → context cost
  Lane + authority + tier         agent-lane steps with high rework,        R
                                  bypass, or variance → harden by moving
                                  to framework lane (lane migration =
                                  REFACTOR toward determinism)
  Processes without a workflow    processes with the worst consistency      A
                                  history (inception routing, exception
                                  handling, task creation, tier-0
                                  escalation) and no ratified workflow
  Schema gaps                     patterns the process needs but the        A
                                  schema can't express (e.g. call-with-
                                  return handback)
  Execution traces by node uid    per-step pass/fail/time/cost — the        D R A
   (when fw workflow run exists)   strongest process data; likely
                                  DESIGNED-ONLY today → record as gap

======================================================================
PHASE 1 — YARDSTICK AND DATA   [ASK]   (GATHERER)
======================================================================
Read README.md, CLAUDE.md, FRAMEWORK.md, docs/, .context/project/ (goals, concerns, decisions) and policy/value-drivers.yaml; if the purpose is not written down in any of these, record it as `unknown` rather than inventing one (if unknown: README, docs, value drivers, roadmap,
ratified workflows). Write, in max 10 lines: purpose (one sentence),
users/consumers, core capabilities, non-goals, value drivers and weights.
Flag contradictions between stated purpose and actual code.

[ASK] Show the human:
  1. the yardstick — confirm or correct
  2. the data availability map — especially DESIGNED-ONLY and ABSENT rows,
     and ask whether data exists that you can't see
Do not continue until both are confirmed.

======================================================================
PHASE 2 — INVENTORY   (GATHERER)
======================================================================
Map the scope into items at a sensible grain: feature, verb, skill, prompt,
workflow, module, subsystem, integration, config surface, doc set,
dependency, gate, worker, topic. For each: location, what it actually does
(verified), which capability or driver it serves — or "none found".

Map the reverse too: each core capability, value driver and ratified
workflow → which items serve it. Nothing serving it = ADD candidate.

Over budget → stop, propose slices ranked by likely review value
(hotspots, high-bypass areas, uncovered drivers first), [ASK].

======================================================================
PHASE 3 — EVIDENCE FILE   (GATHERER)
======================================================================
For each item, pull from every available source. Write the evidence file
to docs/reports/VALUE-REVIEW-<scope>-<date>-evidence.md:

  Item | Source | Status of source | Data point (with citation) |
  Window (activity) | Kind: usage / value / cost / structure / friction

Report facts only. No classification, no recommendations. Record
conflicting data points side by side.

NON-USE DIAGNOSIS — for every item with no or low observed use, also
collect the evidence that separates the readings below. Record what you
found for each reading; don't pick one (that's the JUDGE's job).

  Reading              Evidence that points to it
  -------------------  ----------------------------------------------------
  A  BROKEN            fails when exercised; failing/skipped tests; errors
     wanted, doesn't   or healing events on that path; issues/upstream
     work              reports; attempts followed by a workaround or bypass
  B  NEVER WIRED       works in isolation (tests pass, direct invocation
     wanted, works,    works) but no caller; origin task/arc intended it to
     nothing calls it  be wired; half-finished or abandoned-mid-way task;
                       workflow node or roadmap expecting it
  C  UNDISCOVERABLE    wired and working, but absent from help, docs,
     wanted, works,    README, CLAUDE.md, skills, prompts or dispatch
     nobody knows      templates; people/agents doing the same job by hand
  D  UNMEASURED        no instrumentation on that path; use can't show up
     used, invisible   in the data even if it happens
  E  NOT WANTED        positive reason the need is gone: purpose or non-goals
     any more          changed; superseded by something that IS used; arc or
                       direction abandoned by recorded decision; the problem
                       it solved no longer exists

  Intent evidence (independent of use): maps to a value driver or core
  capability; referenced by a ratified workflow; workarounds exist; requests
  exist; docs promise it. Any intent evidence rules out E until explained.

  Exercising an item to check A/B: only in a sandbox, dry-run or test
  context; never Tier-0 or anything with external side effects; after the
  Phase 0 snapshot; log what you ran.

======================================================================
PHASE 4 — CLASSIFY   (JUDGE)
======================================================================
Input: the confirmed yardstick + the evidence file. Nothing else.

Classes: KEEP · DELETE · REFACTOR · ADD · INVESTIGATE

--- NON-USE: RESOLVE THE READING FIRST ----------------------------
  For every low/no-use item, pick the reading from the diagnosis evidence:
    A BROKEN         → ADD (REPAIR)
    B NEVER WIRED    → ADD (WIRE)
    C UNDISCOVERABLE → ADD (SURFACE: docs, help, prompts, skills)
    D UNMEASURED     → INVESTIGATE + ADD (instrument), no verdict on value
    E NOT WANTED     → DELETE candidate, subject to DELETE CHECKS
    unclear          → INVESTIGATE, stating which evidence would decide
  Readings can stack (broken AND undiscoverable). Name all that apply.
  Wanted-but-broken is often worth MORE than it looks: the non-use is the
  cost of the defect. Say so when intent evidence is strong.

--- DELETE --------------------------------------------------------
  DELETE needs a positive reason, not absence. Non-use only supports
  DELETE once readings A–D have been ruled out.

  Signals for: purpose or non-goals changed; superseded by something that is
  used; origin in a direction abandoned by recorded decision; duplicated by
  something used; docs-only existence of something no one intends to build;
  gate routinely bypassed with no consequence AND no intent to enforce it;
  shipped arc realized no/unclear and the need it targeted is gone.
  Supporting (never sufficient alone): no references; zero use over a
  relevant-activity window; alive only through its own tests.
  Signals against: any intent evidence; low use but high consequence
  (security, recovery, compliance, rare critical paths); recently added;
  any or unknown external consumer; referenced by a ratified workflow;
  unresolved dynamic references.

  DELETE CHECKS — all must pass, else INVESTIGATE:
   1. Positive reason the purpose no longer needs it, cited (decision,
      changed non-goal, superseding item, abandoned arc)
   2. Readings A–D ruled out with evidence, not assumed
   3. No intent evidence left unexplained
   4. No references found, incl. strings, config, hooks, CI, prompts,
      workflow endpoints
   5. No external consumer (incl. consumer projects / fleet usage)
   6. Not referenced by a ratified workflow
   7. What breaks if wrong, and how to revert, is stated

--- REFACTOR ------------------------------------------------------
  Signals for: hotspot (churn × complexity); high fix/revert or rework
  ratio; change coupling across boundaries; duplication; recurring healing
  events or errors in one component; high gate bypass or low first-pass
  rate; merge conflicts concentrated in one area; agent-lane workflow step
  with high rework/variance (harden it); cache-read collapse traced to
  context assembly; knowledge concentrated in one author/session; estimator
  consistently overridden for one area.
  Signals against: complex but stable (rarely changed, rarely broken —
  leave it); no tests on the behaviour to preserve (→ propose tests first);
  already slated for DELETE or a major ADD.

  REFACTOR CHECKS:
   1. Cost shown in data (churn, rework, bypass, errors, tokens), not just
      complexity
   2. Behaviour to preserve is covered by tests, or tests come first
   3. Size: small (one session) / medium / needs its own design

--- ADD -----------------------------------------------------------
  Signals for: non-use readings A/B/C with intent evidence (repair, wire,
  surface); value driver or core capability nothing serves; repeated
  requests or upstream reports; workarounds; gates bypassed because the
  proper path doesn't exist; recurring handover blockers; docs promising
  unbuilt things; workflow endpoints pointing at nothing; processes with
  poor consistency and no ratified workflow; schema can't express a needed
  pattern; data gaps that block judgement (instrumentation is an ADD);
  load-bearing paths without tests.
  Signals against: single occurrence; in non-goals; previously rejected
  without new evidence; serves no confirmed capability or driver.

  ADD CHECKS:
   1. Traces to a core capability or value driver
   2. At least one observed or measured signal
   3. Type: REPAIR (broken) / WIRE (built, not connected) / SURFACE (works,
      not findable) / EXTEND (works, needs more) / NEW
   4. Size: small / medium / needs its own design

--- CONFIDENCE ----------------------------------------------------
  Evidence strength: measured (runtime, telemetry, audit logs) > observed
  (git, ledger, issues, CI, handovers) > inferred (static analysis) >
  claimed (docs, handoffs) > opinion.
  HIGH:   ≥2 independent sources agree, at least one measured or observed
  MEDIUM: one measured/observed source, or several inferred that agree
  LOW:    inferred/claimed only, or sources conflict
  Minus one level if JUDGE and GATHERER were not separated.

======================================================================
PHASE 5 — REPORT   [ASK]   (JUDGE → HUMAN)
======================================================================
Write docs/reports/VALUE-REVIEW-<scope>-<date>.md:

  1. Yardstick (confirmed)
  2. Data availability map (confirmed) + snapshot windows
  3. Role setup (separated? which models?)
  4. Baseline
  5. Summary: counts per class; top 3 per axis, one line each
  6. Findings table, one row per non-KEEP item:
       ID | Item | Location | Class | Non-use reading (A–E, if any) |
       Evidence (→ evidence file rows) |
       Counter-evidence | Confidence | Proposal | Size | Reversible? |
       Risk if wrong | Expected effect (metric, direction, activity window)
  7. KEEP list (names only)
  8. INVESTIGATE list + the data needed for each
  9. Data gaps that capped confidence + what closing them unlocks
     (these are ADD candidates in their own right)
 10. Contradictions (docs vs code, purpose vs reality, source vs source)
 11. Not reviewed
 12. Sovereign questions — anything touching weights, ratified workflows,
     gates or authority — each with a recommendation

"Expected effect" is a pre-registered prediction: what measurable change
this proposal should cause, so it can be checked after execution. On AEF,
map these to BVP predictions against the value drivers.

Rank within each axis by value per unit of cost and risk.
AEF: propose tasks under an arc (don't create them yet).

[ASK] Present summary and questions. Human approves / rejects / modifies
per item. Record decisions and reasons.

======================================================================
PHASE 6 — EXECUTE APPROVED ITEMS ONLY
======================================================================
One approved item per slice:
  - AEF: task per slice via `fw` before touching files
  - One commit per item, revertable
  - DELETE: deprecate-then-remove where a consumer might exist
  - REFACTOR: tests first if missing; identical behaviour before/after
  - ADD: small items only; "needs its own design" → inception proposal
  - Re-run baseline after every slice. Green → red: revert, record, move on.
    Never weaken the check
  - Unexpected consumer or real reason it exists → stop that item, [ASK]

======================================================================
PHASE 7 — CLOSE
======================================================================
Update the report:
  - executed items (commits / task IDs), reverted items and why
  - open items; rejected items with the human's reason (not re-proposed
    without new evidence)
  - baseline before vs after
  - expected-effect predictions registered and when to check them
    (AEF: realization windows)
  - instrumentation to add before the next review
  - what should change in how the next review runs
