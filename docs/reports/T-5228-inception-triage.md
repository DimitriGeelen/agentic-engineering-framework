# T-5228 — Inception triage: placing each open inception on the lifecycle map

Task: T-5228 (operator choice B1, 2026-11-18). Date: 2026-11-18. Revisit date set everywhere: **2026-11-25** (today + 7).
No decision was recorded, no task status changed, no task was closed, and no `.tasks/completed/` file was edited.

## Truly ready for the operator's decision (short list)

| Task | Title | Recommendation | Why it is ready |
|------|-------|----------------|-----------------|
| T-3240 | The Stop-hook loop caps at ONE continuation | DEFER | The measurement is done (the cap is one continuation). What remains is the operator's call on the autonomy ceiling. |
| T-3496 | SOVEREIGN: voi_score is a constant on 98.6% of inceptions | DEFER | Sovereign: what the framework believes about value-of-information is the operator's call, and no evidence in the corpus can settle it. |
| T-3829 | Optional dialogue-log artefact for decision walkthroughs | DEFER | Needs only the operator's ruling on the default (on or off) and on the overlap with C-001. |
| T-4649 | Supported extension points for project-local hook additions | DEFER until v1.8.15 is released, then a scoped GO | Both questions are answered with a per-point analysis. The DEFER premise (release freeze) ended when v1.8.15 was released, so the scoped GO in its text applies now. |
| T-4992 | Harness login broker: per-host subscription login | DEFER | Ownership call: does AEF own a broker that touches subscription credentials? ring20's scripts become relevant after a yes. |
| T-5030 | Move the GitHub repo into an organisation | DEFER | The rationale records that the operator already deferred it. Only the DEFER needs recording. |

T-3682 also still sits on "awaiting the operator's decision", but it is **not** ready (see Exceptions).

## Method

1. For each of the 43 inceptions on `il_awaiting_decision`, I ran the one readiness predicate, `inception_handoff_blockers` (lib/inception-readiness.sh, with lib/task-audit.sh loaded).
2. I read every Open Questions and Recommendation section with HTML comments stripped. **Finding:** 31 of the 43 pass the predicate, but 29 of those 31 pass only because they have **no IW question filed at all**. Their `## Open Questions` holds only the template comment. Their DEFER rationales mostly name outstanding agent or peer work ("Evidence gap: attribution not established…"). Under T-5226 such an inception reads EXPLORING with "no Open Questions filed yet", so I counted these as not ready.
3. A predicate-passing inception was taken as **truly ready** only when nothing in its rationale is left for an agent or a peer to do, and the next step is the operator's decision. Six qualify.
4. Not ready: the `**Recommendation:**` value became `EXPLORING`. The earlier verdict is kept as the line `Earlier filing-time recommendation (before T-5226): <verdict> — rationale kept below.`, followed by one line naming the owner and the reason. The old rationale is untouched. Then `fw inception wait T-X <owner> --revisit 2026-11-25`.
5. Ready: verdict kept, then `fw inception wait T-X operator --revisit 2026-11-25`.

Owner rule: `agent` by default. `peer` only when the open item is another project's evidence, and the project is named. `operator` only when the open item is the operator's *input*, not a decision.

## Results — the 43 awaiting decision

Tally: 6 ready (operator); 37 not ready. Of the 37, 36 moved to EXPLORING (23 agent, 9 peer, 4 operator) and 1 is blocked (T-3682, agent).

| Task | Title | Verdict before | Predicate blockers | Ready? | waiting_on | Why |
|------|-------|----------------|--------------------|--------|------------|-----|
| T-2963 | Seam design: a pinned designer drops every extension it was not told a | DEFER | passes | not | agent | agent — measure what our own importer does with an unknown extension. |
| T-3240 | the Stop-hook loop caps at ONE continuation — stop_hook_active is ch | DEFER | passes | ready | operator | measurement done (cap is one continuation); what remains is the operator's call on the autonomy ceiling |
| T-3276 | Should continuous-driver carry a non-termlink transport leg for TUI ta | DEFER | passes | not | agent | agent — the revisit condition below is met (T-3275 and T-3256 are both completed), so the agent re-assesses. |
| T-3331 | External writer mutated an active task status mid-session with no noti | DEFER | passes | not | agent | agent — attribute the writer. |
| T-3332 | Filing a task is indistinguishable from starting it — sanction a fil | DEFER | passes | not | agent | agent — enumerate the filing paths and what each gate assumes. |
| T-3333 | focus.yaml stomped twice in one hour by machinery replaying stale sess | DEFER | passes | not | agent | agent — attribute the stale-replay writer. |
| T-3334 | Which process auto-created T-3215 in started-work with template ACs � | DEFER | passes | not | agent | agent — identify the creating process. |
| T-3496 | SOVEREIGN: voi_score is a validated, consumed field that is a constant | DEFER | passes | ready | operator | sovereign: what the framework believes about value-of-information is the operator's to decide; no evidence can settle it |
| T-3501 | ARC mechanism is faulty: gather the cross-agent proposals and decide w | DEFER | 4 undisposed-question | not | agent | agent — gather and read the cross-agent proposals. |
| T-3682 | Sidecar design-conformance audit: T-3396/T-3397 spec vs built slices � | DEFER | passes | not-blocked | agent | schema gate (T-2188) refuses the Edit: no target_blast_radius/voi_score; left at DEFER (see Exceptions) |
| T-3731 | Revise the configuration engine: auto-discover new config keys (framew | GO | 4 undisposed-question | not | agent | agent — dispose IW-1..IW-4. |
| T-3796 | Visual decision briefs: an 'Options at a glance' picture section in /d | DEFER | passes | not | agent | agent — read 055's report and build script; count our look/behaviour [REVIEW] rulings. |
| T-3826 | Default FW_SESSION_SCOPED_FOCUS=1 when TERMLINK_SESSION is set? (1409  | DEFER | passes | not | agent | agent — take the usage count from the dispatch ledger. |
| T-3829 | Optional dialogue-log artefact for decision walkthroughs, frontmatter- | DEFER | passes | ready | operator | needs only the operator's ruling on the default (on/off) and the overlap with C-001 |
| T-3895 | Continuous-run arc: does the loop actually work today? Establish with  | DEFER | passes | not | agent | agent — measure when the loop last completed a real iteration and why it stops. |
| T-3901 | Should fw runme bind the operator's go to the exact bytes that run? (8 | DEFER | passes | not | peer | peer (832) — their tools/runme-launcher.sh and 12-leg test, offered but not yet seen. |
| T-3932 | Cap on review rounds per task (ring20 T-2250 review F11) | DEFER | passes | not | operator | operator — input on whether a review-round cap is wanted and where it should live (it also depends on the unbuilt T-3555). |
| T-3945 | Pickup: Delivery telemetry: goal, accumulation, regression of quality/ | DEFER | passes | not | agent | agent — file the questions and gather the telemetry evidence. |
| T-4012 | Urgent message ladder: how an urgent peer message is retried, escalate | DEFER | 7 undisposed-question | not | operator | operator — the design questions (rung timing, escalate-to-operator-first, direct PTY inject, dead-letter) need the operator's input in dialogue. |
| T-4022 | runme job queue: one fixed operator command runs pending numbered jobs | DEFER | 2 undisposed-question | not | peer | peer (832) — their job-queue MANIFEST and files, not yet read. |
| T-4027 | 1409 pickup T-1815: no waiting without a wake-up (dispatch starts its  | DEFER | passes | not | agent | agent — check which parts AEF already has (fw runme watch, fw termlink wait, Choice Presentation). |
| T-4111 | Focus anchor: one operator-owned goal + parked list that handover, res | DEFER | passes | not | agent | agent — compare 1409's proposal with AEF's existing focus and arc mechanisms. |
| T-4168 | Decided episodics missing from the WORKING TREE (not only the index) o | DEFER | 2 undisposed-question | not | peer | peer (ring20) — their file timestamps and reflog. |
| T-4201 | External tool (TermLink fleet doctor, T-1051 Option D) appends PL-* le | DEFER | passes | not | peer | peer (TermLink) — confirmation of what writes PL-* entries and how often. |
| T-4299 | Standing greenfield orchestrator owned by AEF: scripted container smok | GO | 3 undisposed-question | not | agent | agent — dispose IW-1..IW-3. |
| T-4321 | Should the arc lifecycle make the agent file the close recommendation  | DEFER | passes | not | agent | agent — count the in-progress arcs whose tasks are all done. |
| T-4371 | Task owner decided by a creation-time risk assessment (agent by defaul | GO | 3 undisposed-question | not | agent | agent — dispose IW-1..IW-3. |
| T-4393 | Cross-branch task-ID collisions: termlink's August allocation-fix pick | DEFER | 3 undisposed-question | not | peer | peer (TermLink) — the August pickup text and their T-3476 ID-allocation design. |
| T-4649 | Supported extension points for project-local hook additions so consume | DEFER until v1.8.15 is release | passes | ready | operator | both questions answered with a per-point analysis; the DEFER premise (release freeze) ended with v1.8.15, so the scoped GO in its text applies now |
| T-4810 | Budget ladder in unattended runs: measurement, band markers across com | DEFER | passes | not | agent | agent — research the findings against budget-gate.sh and checkpoint.sh, then ask for the operator's view. |
| T-4834 | Decide: gate worktree creation behind an operator grant (055's T-649 c | DEFER | passes | not | agent | agent — T-4833 has shipped; review 055's hook against AEF's gates, then write GO or NO-GO. |
| T-4868 | Release branch model: release only field-confirmed fixes by cherry-pic | DEFER | 2 undisposed-question | not | agent | agent — do the release-branch research the operator asked for on 2026-10-28. |
| T-4877 | Worker credentials: provision, preflight, expiry and rotation for unat | DEFER | passes | not | agent | agent — the release freeze was lifted on 2026-10-29, so exploration can start. |
| T-4982 | BVP scoring findings from the estate (055 T-677): unknown is not 0, ev | DEFER | passes | not | peer | peer (055) — evidence excerpts for the six findings (then an agent design read of the estimator). |
| T-4991 | Workflow-design vocabulary for maps (832 T-1363): document state, key  | DEFER | passes | not | peer | peer (832) — their T-1363 decision and greenfield WT-01 evidence. |
| T-4992 | Harness login broker: per-host subscription login approved in the oper | DEFER | passes | ready | operator | ownership call: whether AEF owns a harness login broker touching subscription credentials; ring20's scripts are evidence for after a yes |
| T-4998 | Backlog triage in the framework: a fw verb and a Watchtower /backlog p | DEFER | passes | not | peer | peer (055, 010) — the results of their backlog-triage builds. |
| T-5000 | The claude review seat runs with the live project as its cwd: can it w | DEFER | passes | not | agent | agent — design read of how the claude review worker is confined. |
| T-5006 | Outside contributions through GitHub pull requests (Mehdi's proposal) | DEFER | 6 undisposed-question | not | operator | operator — the operator's T-5021 requirements sign-off, the first step of the role chain the operator set on 2026-11-12. |
| T-5007 | Move cross-project pickup requests from the sidecar to GitHub issues | DEFER | 3 undisposed-question | not | operator | operator — input in dialogue on which pickup traffic moves and what the sidecar keeps. |
| T-5030 | Weigh moving the GitHub repo into an organisation so AEF gets its own  | DEFER | passes | ready | operator | the rationale records that the operator already deferred it; only the DEFER needs recording |
| T-5037 | Batch verification and review: verify engine changes once per batch on | DEFER | passes | not | agent | agent — read the proposal against AEF's verification gate, review ledger and unit-suite audit. |
| T-5224 | Optional arc orchestrator: an arc can have an owner that holds the arc | DEFER | 6 undisposed-question | not | peer | peer (1409) — their measurements, especially the five-unit load test. |

## Results — every other open inception (fields only, nothing re-judged)

There are 23 active ones: 5 on `il_go_building` and 18 on `il_decided`. All got `waiting_on` and `revisit_at: 2026-11-25`. The other 63 on `il_go_building` are completed inceptions in `.tasks/completed/` with open build tasks. They were not touched (no edits to completed files, and `fw inception wait` only accepts active tasks).

The 5 GO inceptions have **no open build task** and are partial-complete with one Human criterion open. The next step is therefore the operator's review, not agent build work, so they are routed to `operator` and not to `agent` as the brief's default said. T-1611 and T-2062 are in the same partial-complete state.

| Task | waiting_on | Why |
|------|------------|-----|
| T-1265 | agent | DEFER: check whether export demand has materialised |
| T-1271 | agent | DEFER as self-pickup duplicate of T-1270: agent confirms and proposes closing |
| T-1309 | agent | DEFER superseded by T-1312: agent confirms and proposes closing |
| T-1611 | operator | partial-complete: one Human AC open |
| T-1685 | agent | recorded DEFER but recommendation text says NO-GO: agent reconciles |
| T-2062 | operator | NO-GO, partial-complete: one Human AC open |
| T-2063 | operator | GO, partial-complete: one Human AC open, no open build task |
| T-2064 | operator | GO, partial-complete: one Human AC open, no open build task |
| T-2065 | operator | GO, partial-complete: one Human AC open, no open build task |
| T-2066 | operator | GO, partial-complete: one Human AC open, no open build task |
| T-2137 | agent | DEFER: agent re-checks the multi-option AC gap |
| T-2321 | agent | DEFER pre-gate retrofit: agent re-surfaces or proposes closing |
| T-2323 | agent | DEFER scoping: yield-point spike is agent work |
| T-2428 | operator | GO, partial-complete: one Human AC open, no open build task |
| T-2770 | agent | DEFER whose evidence now exists: agent writes the re-recommendation |
| T-3935 | agent | DEFER: dispatched comparison of ring20 v0.3 against AEF gates (revisit 2026-10-10 passed) |
| T-3961 | agent | DEFER: measure lost approvals from the bypass log (revisit 2026-10-10 passed) |
| T-550 | agent | DEFER until a second adapter is needed: agent checks the trigger |
| T-558 | agent | DEFER no concrete gap: agent checks the trigger |
| T-682 | peer | DEFER pending TermLink upstream decision on --working-dir and MCP default |
| T-704 | agent | DEFER speculative: agent checks the trigger |
| T-705 | agent | DEFER too early for KCP: agent checks the trigger |
| T-844 | agent | DEFER research note: agent checks the trigger |

## `fw inception lifecycle` — before and after

Before (2026-11-18, before any edit):

```
Inception lifecycle (aef-inception-lifecycle) — 129 open, 0 overdue
  step                                     count  median days  overdue
  exploring, waiting on the agent              0            -        0
  exploring, waiting on a peer                 0            -        0
  exploring, waiting on the operator           0            -        0
  ready for a recommendation                   0            -        0
  awaiting the operator's decision            43         36.5        0
  decided GO, build tasks open                68        159.0        0
  decided NO-GO or DEFER                      18        186.2        0
  closed                                     488        209.2        0
```

After:

```
Inception lifecycle (aef-inception-lifecycle) — 129 open, 0 overdue
  step                                     count  median days  overdue
  exploring, waiting on the agent              5         -0.9        0
  exploring, waiting on a peer                 4         -0.9        0
  exploring, waiting on the operator           3         -0.9        0
  ready for a recommendation                  24         -0.9        0
  awaiting the operator's decision             7         -0.9        0
  decided GO, build tasks open                68        156.4        0
  decided NO-GO or DEFER                      18         -0.9        0
  closed                                     488        209.2        0
```

"Awaiting the operator's decision" went from 43 to 7: the 6 truly ready ones plus T-3682.

## Exceptions and findings (not fixed here)

1. **T-3682 could not be moved to EXPLORING.** The inception-schema gate (`check-inception-schema`, T-2188) refuses any Edit until `target_blast_radius` and `voi_score` exist in its frontmatter. Inventing those scores would manufacture data (cf. T-3496), and the bypass is operator-only. It keeps DEFER and has `waiting_on: agent` with a revisit date, but the map still shows it as awaiting decision. Next step: the agent scores it honestly, then applies the same EXPLORING edit.
2. **The predicate counts the template comment as a filed question.** When the verdict is EXPLORING, `inception_handoff_blockers` counts IW lines in `## Open Questions` *including the commented-out template example* `- **IW-1: <question text>**`. So an inception with zero real questions reports `ready-for-recommendation` instead of "no Open Questions filed yet". That is why 24 land on "ready for a recommendation". The same blind spot is what lets 29 question-less DEFER inceptions pass the predicate before EXPLORING. The owner is right (agent), but the label overstates readiness. Fix candidate: strip HTML comments before counting (lib/inception-readiness.sh, and the Python copy in web/shared.py). Not registered in concerns.yaml by this worker; the parent integrates.
3. **`il_ready` hides `waiting_on`.** Of the 24 on "ready for a recommendation", some wait on a peer (T-3901, T-4201, T-4982, T-4991, T-4998) or the operator (T-3932). The map places them on an agent-owned node anyway, because it keys `il_ready` on dispositions only. Finding 2 compounds this.
4. **"median days" reads −0.9 after the triage.** `days_in_step` is measured from midnight of today while `step_entered_at` is now, so a step entered today gets a negative age. This is cosmetic (lib/inception_lifecycle.py `instances`).
5. **`fw inception wait` rejects `--switch-focus`** ("Unknown option"). Only the env form `FW_SWITCH_FOCUS=1` works, a small L-399 parity gap.
6. **Three task files were untracked before this triage:** T-4810, T-5030 and T-5037. These were filings from 2026-10-27 and 2026-11-02 that had never been committed. Commit bc6dc4d40 adds them in full, together with the triage edit.
7. **T-3935 had uncommitted Context additions (2026-11-02) from earlier work.** Only the triage hunks were committed. The rest is left in the working tree.
8. **Revisit conditions already met:** T-3276 (T-3275 and T-3256 both completed), T-3935 and T-3961 (time-bound revisit 2026-10-10 passed), and T-4877 and T-4649 (release freeze lifted). They are flagged in their rows.
