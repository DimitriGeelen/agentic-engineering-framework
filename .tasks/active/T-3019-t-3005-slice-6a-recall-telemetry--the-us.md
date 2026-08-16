---
id: T-3019
name: "T-3005 slice 6a: recall telemetry — the Used signal"
description: >
  T-3005 slice 6a: recall telemetry — the Used signal

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [bin/fw, lib/config.sh, lib/recall-usage.sh, 
      web/blueprints/config.py, web/embeddings.py, web/recall_telemetry.py]
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
created: 2026-08-15T14:08:57Z
last_update: '2026-08-16T22:24:15Z'
date_finished: 2026-08-15T15:20:19Z
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
  - ts: '2026-08-15T14:15:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-15T14:15:14Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 3
      D4: 2
      F-RECALL: 3
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=3 (body:component-discoverability); 
      D4=2 (body:env-class-handled); F-RECALL=3 (body:fw-recall-or-memory-link);
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:15Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 3
      D4: 2
      F-RECALL: 5
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=3 (body:component-discoverability); 
      D4=2 (body:env-class-handled); F-RECALL=5 
      (body/components:retrieval-layer); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3019: T-3005 slice 6a: recall telemetry — the Used signal

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] One row is written per *outermost* recall — `hybrid_search` calling the semantic path internally emits one row, not two. Mutation-verified: removing the re-entrancy guard must turn a test red.
- [x] A recall that raises `EmbedUnavailable` still writes a row, carrying `outcome=unavailable` and the embed class. The diagnostic row is the one a naive implementation loses; a test asserts it survives.
- [x] Miss and unavailable rows carry the query text; hit rows carry only `query_hash`. Both directions asserted (text present on miss, absent on hit).
- [x] A telemetry write failure never propagates to the caller's search, and is counted in `recall_telemetry_state()` rather than swallowed silently (L-331). Test forces a write failure and asserts search still returns while the counter increments.
- [x] `fw doctor` emits a "recall usage" line: OK when rows exist in the window, WARN at zero rows (the G-064 zero-consumer signal).
- [x] The WARN is observed firing against an empty log, not inferred from reading the code — a positive control nobody has watched fail is a hypothesis (T-3005 constraint 3).
- [x] Malformed lines in the log are skipped rather than fatal, so one torn write cannot destroy the whole usage signal.

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

- [ ] [REVIEW] Approve recording raw query text on miss rows

  This is a data-retention decision, not a technical one, which is why the agent
  filed it rather than deciding it. The design writes the *actual query string*
  into `.context/working/recall-telemetry.jsonl` for rows where recall missed —
  because slice 6b (miss-driven reindex priority) needs to know what agents kept
  asking about and getting nothing, and a hash cannot tell you that. Hit rows
  store only a hash.

  The tradeoff: queries are written by agents and by you, they are about this
  project's own corpus, and the file is committed-adjacent (`.context/working/`
  is gitignored, but the host retains it and it is readable by anything that can
  read the repo). If any query might carry something you would not want durably
  logged, the answer is no and the agent will hash misses too — at the cost of
  making slice 6b substantially weaker.

  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw recall "something obscure that will miss" ; tail -3 .context/working/recall-telemetry.jsonl`
  2. Look at what the miss row actually contains — the `query` field is the thing under review.
  3. Decide whether that content, retained indefinitely on this host, is acceptable.

  **Expected:** You are comfortable with raw query text on miss rows, OR you say
  no and the agent switches misses to hash-only.

  **If not:** Say so on the task and the agent removes the `query` field from
  `_write_row`, replaces slice 6b's input with hash-frequency only, and records
  the capability loss in the slice 6b task so the weakening is visible rather
  than silently absorbed.

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

# The unit suite. No pinned pass-count: a whole-suite total is invalidated by any
# sibling task adding a test, and pytest already exits non-zero on real failure
# (T-3016 shipped with such a count and it broke at the next close).
python3 -m pytest tests/unit/test_recall_telemetry.py -q > /tmp/.t3019-tests.out 2>&1

# Doctor emits the Used signal at all. Separate from the two below, which pin the
# verdicts — this one only asserts the check has not silently dropped out of the
# doctor run, which is how a control stops firing without anyone noticing.
bin/fw doctor > /tmp/.t3019-doctor.out 2>&1 && grep -q "recall usage:" /tmp/.t3019-doctor.out

# The WARN fires against a log with no rows. This is the positive control: a
# zero-consumer alarm nobody has watched go red is a hypothesis, not a control
# (T-3005 constraint 3). Asserted on a path that does not exist, so the check
# cannot pass by accident on a populated log.
rm -f /tmp/.t3019-empty.jsonl && FW_RECALL_TELEMETRY_PATH=/tmp/.t3019-empty.jsonl bash -c 'source lib/config.sh; source lib/recall-usage.sh; recall_usage_verdict 7' > /tmp/.t3019-warn.out 2>&1 && grep -q "^WARN|recall usage: 0 queries" /tmp/.t3019-warn.out

# And the OK verdict on a log that has rows — the other direction. Without this,
# a check hard-wired to WARN would pass the line above and be useless.
printf '{"ts":"%s","surface":"semantic","query_hash":"x","n_hits":1,"top_score":0.5,"latency_ms":5,"outcome":"hit"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > /tmp/.t3019-rows.jsonl && FW_RECALL_TELEMETRY_PATH=/tmp/.t3019-rows.jsonl bash -c 'source lib/config.sh; source lib/recall-usage.sh; recall_usage_verdict 7' > /tmp/.t3019-ok.out 2>&1 && grep -q "^OK|recall usage: 1 query" /tmp/.t3019-ok.out

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

**Rationale:** The mechanism is done and both of its verdicts were watched
firing rather than reasoned about — WARN against an empty log, OK once real
queries landed. The one open item is not a technical gap, it is a data-retention
decision that is yours: miss rows record the raw query string, because slice 6b
(miss-driven reindex priority) needs to know *what* agents kept asking about and
a hash cannot tell you that. Hit rows carry only the hash.

I recommend GO on keeping the query text. The queries are agent- and
operator-written, about this project's own corpus, in a gitignored working file.
The alternative — hashing misses too — does not make slice 6b impossible, it
makes it substantially weaker: you would learn that *something* was asked 30
times and never learn what, which is close to useless for deciding what to
reindex. But this is a retention call about content neither of us has audited,
so it is yours to make and the fallback is one edit if you say no.

**Evidence:**

- 26 unit tests, `tests/unit/test_recall_telemetry.py`. Both verification
  directions asserted per guarantee, not just the happy path.
- Re-entrancy guard mutation-verified: deleting it makes one `hybrid_search`
  call write two rows (`semantic` + `hybrid`), and three tests go red.
  `_hybrid_search` deliberately reaches the semantic path through the *public*
  `search`, so the guard is load-bearing rather than decorative.
- The UTC timestamp test was wrong twice and the second version is the
  interesting one: pinning an absolute epoch does *not* catch a local-time
  misread, because under `TZ=UTC` `mktime` and `timegm` are the same function
  and there is no defect to detect. Verified by mutating and watching it stay
  green under `TZ=UTC`. The test now supplies its own non-UTC offset and is red
  under mutation on both CEST and UTC.
- `fw doctor` verdicts observed live: `WARN recall usage: 0 queries in 7d` on an
  empty log, `OK recall usage: 2 queries in 7d` after real `fw recall` calls.
- Write failures are guarded but counted (L-331) — `recall_telemetry_state()`
  keeps "no rows" and "rows we could not write" separable.
- Deliberately *not* shipped: a low-score miss threshold. Live top scores are
  0.16–0.22, which is low enough that any threshold I picked today would be a
  guess. Miss is defined as zero hits only, and the score-based definition waits
  for measurement against the now-populated index.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-15T14:08:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3019-t-3005-slice-6a-recall-telemetry--the-us.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0c49c503
- **Timestamp:** 2026-08-15T15:23:50Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **destructive-action** (high) — Destructive operation in verification or AC
     - matched: `rm -f`

### 2026-08-15T15:20:19Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
