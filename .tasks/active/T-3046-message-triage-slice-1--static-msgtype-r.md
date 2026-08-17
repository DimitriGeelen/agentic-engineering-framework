---
id: T-3046
name: "Message triage slice 1 — static msg_type router for typed messages"
description: >
  Message triage slice 1 — static msg_type router for typed messages

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-08-16T19:47:40Z
last_update: '2026-08-17T12:36:11Z'
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── BVP scoring fields (T-1918, arc-006). See docs/reports/T-1915-bvp-inception.md for semantics. ──
# bvp_scores:                     # confirmed per-driver scores 0-5, set by `fw bvp confirm` (T-1924).
#                                 # Sovereignty boundary — only set after human or agent confirmation.
#                                 # Shape: {D1: <int 0-5>, D2: <int 0-5>, D3: <int 0-5>, D4: <int 0-5>, [<free-driver-id>: <int>]...}
# bvp_scores_proposed:            # estimator-proposed scores (T-1922 worker). Persists when ≥2 delta
#                                 # from bvp_scores: on any driver (M3 v2-delta). Shape: list of timestamped entries.
# cost_estimate:                  # F8 composite: 0.6×blast_radius + 0.3×tier + 0.1×effort.
#                                 # Q2 fallback: T-shirt S/M/L/XL mapped to 2/4/6/8 when blast_radius is not yet computable.
cost_estimate_proposed:
  - ts: '2026-08-16T20:00:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-17T12:36:11Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=432,acs=12)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-16T20:00:16Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 3
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=3 
      (body:component-silent-failure); D3=3 (body:component-discoverability); 
      D4=2 (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3046: Message triage slice 1 — static msg_type router for typed messages

## Context

First build slice under the T-3044 GO (decided by the operator 2026-08-16T19:43:36Z).
Inception artifact: `docs/reports/T-3044-message-triage-inception.md` §5.

**The T-3044 census is superseded — re-measured at build time, and it was wrong in a way
that changes the design.** Recorded here rather than quietly built around; the corrected
numbers are what the ACs below are written against.

| | T-3044 census | Measured 2026-08-16 (37 raw files) |
|---|---|---|
| Messages | 35,125 | **47,879** |
| Distinct `msg_type` | 16 | **79** |
| Telemetry | 79% | 72.2% (34,550 / 18 types) |
| Unstructured (`note`,`chat`) | ~4,100 | **12,697** (26.5%) |
| Actionable | "~12" | **632 messages / 59 types** |

Two of those gaps matter structurally, not cosmetically:

1. **There is no message id.** Not `id`, `msg_id`, `message_id`, nor `uuid` — the fields are
   `{artifact_ref, metadata?, msg_type, offset, payload_b64, sender_id, topic, ts}`. So an
   id-keyed dedupe (what this task originally specified) cannot be built. Measured
   alternatives: `(topic, offset)` collides **3,593 times**; `(source_file, topic, offset)`
   is unique **47,879/47,879**; content-hash is likewise unique 47,879/47,879. See §Decisions.

2. **59 actionable types, 43 of them singletons.** A literal 79-row table is unmaintainable
   and would go stale on the next new producer. But the types are *family-structured* —
   `learning-*` (15 types), `pickup*`/`framework:pickup`/`framework-pickup`/`upstream-pickup`
   (5), `fileshare-*` (4), `penelope.*`/`pen.*` (5), `*deploy*` (5), `cross-arc-*`, `gap-*`.
   So the table is **prefix-family rules + exact-match overrides**, which keeps the
   unknown-type refusal (A1) tractable: a new `learning-PL-099` matches its family silently,
   a genuinely new family fails loudly.

The machinery to act on the actionable bucket already exists — `fw pickup process`,
`fw note triage`, `fw bus` — and nothing routes to it. That is the whole defect: not a
missing classifier, a missing wire.

Slice 1 is therefore a **static `msg_type` → disposition table**, not a model. Scope fence
from the artifact: the 12,697 unstructured messages stay searchable and untouched; deciding
how to grind them is IW-4 and does not block this.

**The bar this slice has to clear:** it would have caught the `framework-pickup` bug report
on the day it arrived instead of three months later. That message is the regression fixture.

**Nothing is deleted.** Every message gets exactly one recorded disposition — including
`dropped`, which carries a reason and stays queryable. A silent drop is the failure mode
this slice exists to remove, so it must not introduce one (T-3044 IW-2, answered: zero
silent drops is a design constraint, not a goal).

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] A1 — `lib/message_router.py` classifies **all 79 measured `msg_type` values** via
      prefix-family rules plus exact-match overrides. A type matching no rule is a hard
      error, not a silent default: the router refuses rather than guessing, so a new producer
      surfaces as a failure instead of being swallowed. `assert_table_complete()` replays the
      live archive's full type list and fails on any unclassified type — the coverage check
      is against measured reality, not against a hand-copied list that can go stale (which is
      precisely how the T-3044 census became wrong).
- [x] A2 — `bin/fw triage route --dry-run` reads the archive, prints a per-type count with
      the disposition each would receive, exits 0, and writes nothing. Verified by asserting
      the ledger's byte size is unchanged across the run.
- [x] A3 — Every input message yields exactly one disposition row in
      `.context/triage-dispositions.jsonl`. Rows are
      `{key, locator, msg_type, disposition, reason, ts}` where `locator` is
      `{source_file, topic, offset}`; `disposition: dropped` REQUIRES a non-empty `reason`.
      Asserted as a count identity (rows written == messages read), not as a spot check.
- [x] A4 — Re-running `fw triage route` is idempotent: a second run over the same archive
      appends **zero** new rows. `key` is the **content hash** (sha256 of the canonicalised
      message), not a position cursor and not `msg_id` — there is no id field, and the
      content hash was measured unique 47,879/47,879. It survives the case
      `(source_file, topic, offset)` cannot: the same message re-recovered into tomorrow's
      dated archive file, which would otherwise route twice.
- [x] A5 — Ledger writes are serialised under `flock`, reusing the T-3042 mechanism rather
      than a second implementation. `.context/triage-dispositions.jsonl` is registered in
      `lib/write_set.py:IMPLICIT_WRITE_SET` with hazard `protected`.
- [x] A6 — Routing calls match the artifact §5, corrected for the measured type names:
      the pickup family — `pickup`, `framework:pickup`, `framework-pickup`, `upstream-pickup`
      (**four spellings, 12 messages**; the artifact named only one) → `fw pickup process`;
      `handoff` / `request` / `prod-deploy-approval` / `prod-deploy-withdraw` / `question` /
      `urgent` → surfaced to `/approvals`, **never** auto-filed as tasks; the 18 telemetry
      types → `dropped` with reason, never surfaced to a human.
- [x] A6b — `reflection.envelope.v1` (537 msgs — 85% of the actionable bucket by volume) gets
      an explicit disposition rather than falling through a family rule. It is machine-generated
      peer-reflection traffic (T-1271 cron), so surfacing it to `/approvals` would bury the
      other 95 actionable messages under it. Whichever way it routes, the choice is recorded
      in §Decisions with the count that motivated it.
- [x] A7 — `tests/unit/t3046_message_router.bats` covers: full-type-coverage refusal (A1),
      dry-run purity (A2), the count identity (A3), idempotency (A4), and drop-requires-reason.
      Each test asserts the failing state fails — a guard that has never been seen red is
      not a guard (this session's recurring finding).
- [x] A8 — Regression fixture: running the router over the real archive classifies the
      three-month-old bug report as **routed or surfaced**, never dropped. The measured type
      names for it are `pickup-bug-report` (10), `bug-report` (1),
      `pickup-bug-report-followup` (1) and `pickup-bug-fixed` (1) — the artifact's
      `framework-pickup` was the wrong handle for the origin case. This is the bar the slice
      exists to clear; if these do not route, the slice has not cleared it.

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.

     ── Prefix routing (T-1811, T-1878): default to [REVIEWER] if Expected is grep-able ──
     If your Expected clause is grep-able / file-exists / structural (a deterministic
     shell check), prefer [REVIEWER] — that AC should be an Agent AC with the reviewer
     command in `## Verification` instead of a Human AC here. Only keep [REVIEW] if
     verification genuinely needs human taste (tone, feel, layout rhythm).
     See CLAUDE.md §AC Classification Guidance for the conversion rule.

     [REVIEW] example (genuine human judgment):
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error

     [REVIEWER] example (static-scan-verifiable — convert to Agent AC + Verification):
       - [ ] [REVIEWER] Block message names both bypass mechanisms
         **Steps:**
         1. Run `bin/fw reviewer T-XXX`
         **Expected:** Verdict: PASS; no findings on `block-message-completeness`
         **If not:** Inspect hook block-message string and add missing mechanism
       Conversion: this AC should be moved to ### Agent and
       `bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"` added to ## Verification.
-->

- [ ] [REVIEW] The routing policy is the one you want — specifically, which message types
      are allowed to cause action without you.

  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw triage route --dry-run`
  2. Read the per-type table. Three dispositions exist: `routed` (acts automatically),
     `surfaced` (waits for you at `/approvals`), `dropped` (recorded, no action).
  3. Check the two boundaries that carry judgment, not correctness:
     - `framework-pickup` is the only type set to `routed`. It runs `fw pickup process`
       without asking you. Is that the right thing to let run unattended?
     - `handoff`, `request`, `prod-deploy-approval` are `surfaced`, never auto-filed.
       Confirm none of these should instead act automatically.

  **Expected:** you agree with each `routed` entry, or you name the ones to demote to
  `surfaced`. Demotion is a config change, not a redesign.

  **If not:** say which types are misrouted and in which direction; the table is a literal
  in `lib/message_router.py` and changing it is a one-line edit plus a test update.

  **Why this is yours and not mine:** A1–A8 prove the router does what the table says. They
  cannot prove the table says the right thing. "May this act without the operator" is a
  sovereignty question, and the agent deciding it is exactly the boundary the framework
  draws — initiative, not authority.

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# ── Pipefail/SIGPIPE: grepping a command's output (L-387, T-2090, T-2743, T-2738) ──
#
# THE DEFAULT — redirect to a file, then grep the file:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# Correct at any output size, and `&&` keeps the PRODUCING command's exit code in
# the verdict. Reach for this first; the alternative below is the special case.
#
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line under `set -eo
# pipefail`. When grep matches it exits and closes stdin while cmd is still
# writing, cmd takes SIGPIPE, the pipeline exits 141 — verification "fails" with
# the pattern present. Captured 4× (T-1716, T-1838, T-1862, T-1863).
#
# THE EXCEPTION — capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Valid ONLY while "$out" fits the 65536-byte pipe buffer, and it is on you to
# know that it does. Above that the form inverts and becomes the very failure
# L-387 describes: echo blocks on the full pipe, grep -q exits, echo takes
# SIGPIPE, rc=141 (T-2743 — measured on a 146,366-byte Watchtower page, 3/3 runs,
# deterministic not racy; rendered routes run 50-200KB, so anything that curls a
# page is over the line). It also discards cmd's exit code, so a 404 yields an
# empty capture that grep merely fails to match rather than a failed line.
# If you do use it: single pipe only, no intermediate tail/awk/sed stage between
# capture and grep (T-2090) — the middle stage is what `grep -q` slams its stdin
# on, and grep scans the whole captured string anyway, so the `tail -3` was
# cosmetic. `echo "$out" | grep -q PAT`, nothing between.
#
# TEST RUNNERS need a guard either way (T-2738). `set -e` is suppressed inside the
# `if` condition the gate runs each line in, so in `cmd1; cmd2` only cmd2 is the
# verdict — and the pass marker you grep for survives a partial failure: a suite
# printing "3 failed, 9 passed" satisfies `grep -q "9 passed"`, and generalising
# to `grep -qE "[0-9]+ passed"` matches the same output. Keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no `set -eo pipefail`. A line has returned 0 by hand and 141 under
# P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

# Suite must be judged, not merely run (T-2738): a partial failure still prints "ok 1".
out=$(bats tests/unit/t3046_message_router.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# Router parses and the routing table is importable without side effects.
python3 -c "import ast; ast.parse(open('lib/message_router.py').read())"
# A1 — every census msg_type has an explicit entry; the module asserts its own coverage.
python3 -c "import sys; sys.path.insert(0,'lib'); import message_router as m; m.assert_table_complete()"
# A2 — dry-run exits 0 and writes nothing. Redirect-then-grep (L-387/L-613), not a pipe.
bin/fw triage route --dry-run > /tmp/.t3046-dry.out 2>&1 && grep -qi 'dry-run' /tmp/.t3046-dry.out
# A3 — ledger is valid JSONL and every dropped row carries a non-empty reason.
python3 -c "import json,os; p='.context/triage-dispositions.jsonl'; rows=[json.loads(l) for l in open(p)] if os.path.exists(p) else []; bad=[r for r in rows if r.get('disposition')=='dropped' and not r.get('reason')]; assert not bad, f'{len(bad)} dropped rows with no reason'"
# A5 — the ledger is declared in the implicit write-set, so write-set check sees it.
python3 -c "import sys; sys.path.insert(0,'lib'); import write_set as w; assert '.context/triage-dispositions.jsonl' in w.implicit_paths()"
# Anti-pattern static scan.
out=$(bin/fw reviewer T-3046 2>&1); echo "$out" | grep -q "Overall:.*PASS"

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

## Evolution

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
-->

## Recommendation

<!-- T-2945: same shape as inception.md's block — the gate that reads it
     (audit_inception_recommendation, lib/task-audit.sh:117) is shared, so the
     shape is copied rather than reinvented.

     REQUIRED once this task reaches partial-complete: Agent ACs done, at least
     one `### Human` AC still unticked. `lib/review.sh:205-211` (T-2421) BLOCKS
     `fw task review` emission for build/refactor/test/decommission tasks in that
     state with no substantive block here — the operator would otherwise open
     /review/<id> to a blank Recommendation card and be asked to approve a form.

     Not required while every Human AC is ticked or the task has none: the gate
     only fires on the partial-complete transition. It is here from the start so
     you write it while you still have the evidence, not when the gate refuses.

     Format (the parser wants the `**Recommendation:**` line at the start of a
     line; a leading `-` or `*` bullet is also accepted):
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence — what shipped, what was proven, what remains)
     **Evidence:**
     - Finding 1
     - Finding 2

     DEFER is for evidence gaps, not confidence gaps (CLAUDE.md §Presenting Work
     for Human Review). If the artefact is complete and you still don't want to
     commit, that is a calibration failure — recommend GO or NO-GO.
-->

**Recommendation:** GO

**Rationale:** The slice clears the bar it was created to clear, and clears it against the
real archive rather than a fixture: all five origin-case types (`pickup-bug-report` ×10,
`bug-report`, `pickup-bug-report-followup`, `pickup-bug-fixed`, `gap-report`) classify as
`surfaced`, none as `dropped`. On the day that bug report arrived it would have appeared in
`/approvals` instead of sitting unread for three months.

What is left for you is one question the code cannot answer: **12 messages are set to
`routed`, meaning `fw pickup process` runs on them without asking you.** Everything else
either waits for you (27 `surfaced`) or does nothing (13,272 `deferred`, 34,568 `dropped`,
each with a recorded reason). I have deliberately **not** written the 47,879-row ledger or
executed any handler, because doing so before you approve the table would answer the
sovereignty question on your behalf.

One thing to weigh against this: **the T-3044 census I scoped from was wrong** — it
undercounted messages by 27% and types by 5×, and named the origin case by a type
(`framework-pickup`) that is not the type the bug report actually uses. I found that by
re-measuring at build time rather than trusting the artifact. The router's coverage check
now reads the live archive for exactly this reason, so the same staleness cannot recur
silently — but it is fair to treat the inception's other numbers with the same suspicion.

**Evidence:**
- 16/16 bats tests pass (`tests/unit/t3046_message_router.bats`); 7/7 Verification lines
  pass, each rehearsed under `set -eo pipefail` rather than in an interactive shell.
- **Mutation-tested, not just green:** breaking pickup routing kills only test 10; breaking
  the bug-report disposition kills only test 11; disabling dedupe kills tests 7–9. Each
  guard has been observed red, and each kills a discriminating set.
- Full coverage measured live: 79/79 `msg_type` values classify; an unmatched type raises
  rather than defaulting, so the next new producer fails loudly instead of being swallowed.
- Identity chosen on measurement: content-hash unique 47,879/47,879; `(topic, offset)` — the
  obvious choice — collides 3,593 times and would have silently merged distinct messages.
- Ledger writes reuse `keylock.guarding()` (the T-3042 mechanism), and the ledger is
  registered in `write_set.py:IMPLICIT_WRITE_SET` as `protected`.
- One reviewer CONCERN, overridden as `OV-d067b2d0` with reasoning, not by editing the AC.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

### 2026-08-16 — Message identity key for idempotency

- **Chose:** `key = sha256` of the canonicalised message dict; `(source_file, topic, offset)`
  retained alongside as a human-readable `locator`, not as the dedupe key.
- **Why:** the archive has **no id field at all** — measured across all 37 raw files, zero
  messages carry `id`, `msg_id`, `message_id` or `uuid`. Something had to be chosen, so it
  was chosen on measurement: content-hash is unique 47,879/47,879, and it is the only
  candidate that stays correct when the same message is re-recovered into a new dated
  archive file. That is not hypothetical — re-recovery into dated files is exactly how this
  archive is produced.
- **Rejected:** `(topic, offset)` — collides **3,593 times**, because offsets restart per hub
  and the same topic is recovered from `local`, `ring20-dashboard` and `ring20-management`.
  Would have silently deduped 3,593 distinct messages into each other: a silent drop, the
  one failure mode this slice exists to remove.
- **Rejected:** `(source_file, topic, offset)` — unique today (47,879/47,879) and cheaper,
  but it keys on *where the message was found* rather than *what it is*, so tomorrow's
  re-recovery re-routes everything. Kept as the locator because it is far more legible than
  a hash when reading the ledger by hand.

### 2026-08-16 — A fourth disposition, `deferred`, rather than stretching the other three

- **Chose:** `routed` / `surfaced` / `deferred` / `dropped`, where `deferred` means
  "genuinely actionable, handler out of slice 1's scope", and carries a mandatory reason.
- **Why:** `reflection.envelope.v1` alone is 537 messages — 85% of the actionable bucket by
  volume. Calling it `dropped` would be false, and `surfaced` would bury the 95 messages
  that actually need the operator underneath it. Neither existing label was true, and
  picking the less-wrong one is how a ledger stops being trustworthy. Same applies to the
  12,697 `note`/`chat` (IW-4) and the 22 `learning-*`.
- **Rejected:** forcing them into `dropped` — the ledger's whole value is that a drop is a
  recorded decision, so a drop that isn't one poisons the record.
- **Rejected:** surfacing them — 13,272 items in `/approvals` is the same as none.

### 2026-08-16 — Slice 1 records dispositions; it does not execute handlers

- **Chose:** `handler` is a *name* in the ledger row. Nothing is executed, and no task is
  auto-filed. The real 47,879-row ledger is deliberately **not written yet**.
- **Why:** the operator's Human AC on this task is precisely "may these types act without
  me". Writing 47,879 disposition records — or running `fw pickup process` — before that
  question is answered would answer it on their behalf. Recording is additive and
  reversible; executing is neither. The write path itself is proven on fixtures by the bats
  suite, so deferring the bulk run costs no confidence.
- **Rejected:** running the full route now for a more impressive-looking result. The count
  identity (A3) is a property of the code, and it is tested; running it over 47,879 real
  messages demonstrates nothing further while pre-empting a sovereignty decision.

### 2026-08-16 — Prefix families over a literal type table

- **Chose:** prefix-family rules + exact-match overrides, with an unknown-type hard error.
- **Why:** 79 distinct types, 43 of them singletons. A literal table is stale the moment a
  new producer appears, and staleness here is invisible — which is how the T-3044 census got
  its numbers wrong in the first place. Families let `learning-PL-099` classify itself while
  a genuinely new family still fails loudly.
- **Rejected:** a 79-row literal table (unmaintainable, silently staleable); a classifier
  model (T-3044 §5 scope fence — explicitly out of slice 1, and unnecessary at 59 types).

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-16T19:47:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3046-message-triage-slice-1--static-msgtype-r.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-260faceb
- **Timestamp:** 2026-08-16T19:59:25Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 1 (by override)
  - human-ac-mechanical-signal @ AC#3 (Human)
