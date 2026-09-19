---
id: T-3391
name: "Autonomous run 2026-09-19: top-down BVP selection, second pass — score-through-the-scorer"
description: >
  Autonomous run 2026-09-19: top-down BVP selection, second pass — score-through-the-scorer

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
created: 2026-09-19T15:59:56Z
last_update: 2026-09-19T15:59:56Z
date_finished: null
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
---

# T-3391: Autonomous run 2026-09-19: top-down BVP selection, second pass — score-through-the-scorer

## Context

Second autonomous run under the operator's mandate (top-down selection: project
objectives → arc → task by BVP quadrant → AC-required activities; verb gates
only; scored-before-started; Sovereign questions surfaced, not resolved). The
first run, T-3390, stopped on condition 3: SQ-1 — the quadrant view could not
classify any open task (zero confirmed scores; all 26 Q1/Q2 rows at the
no-signal default 108; signal-bearing tasks unquadrantable because cost needs
`components:`, resolved only at close — OBS-439). The operator reissued the
mandate unchanged. This run treats that as an instruction to proceed under the
mandate's own rules, so its first unit is to make the instrument produce scores
*through the scorer* (`fw bvp estimate` / `estimate-cost`), not to re-derive
the stop.

Run-start state (recorded checks): branch `bleeding-edge` level with origin at
`e41803af9`; focus null; arc focus `ewcr-arc0-contract-evidence`; Watchtower
running at :3002 (identity-verified via `fw watchtower status`); 242 pending
observations; T-3390's four Sovereign questions (SQ-1..SQ-4) unanswered.

## Acceptance Criteria

### Agent
- [ ] Every unit of work in `## Run log` states its selection (objective → arc → task → quadrant) and rationale BEFORE the execution entry, with the recorded check or verb output that closed it
- [ ] Every task this run scores or re-scores is scored through the scorer (`fw bvp estimate` / `fw bvp estimate-cost`), never by hand-written `bvp_scores*` or `cost_estimate` values — the run log names each such invocation and its output
- [ ] Every gate refusal encountered is recorded in `## Gate refusals` with the sanctioned route taken instead (no `--no-verify`, `--force`, `--skip-*`, Tier-2 env vars)
- [ ] Every Sovereign question raised is recorded in `## Sovereign questions` with options, and no such question is decided by this run
- [ ] `## Handback` covers the six mandated headings (objectives advanced / arc state / remaining Q1-Q2 per task / Sovereign questions in priority order / gate refusals / cost-vs-estimate deltas)

## Run log

### Unit 0 — bootstrap (this record)
- **Checks:** `git rev-list --count origin/bleeding-edge..HEAD` → 1 (e41803af9, pushed this session after the audit lock cleared: `8076e17d1..e41803af9`, audit fails=0); focus null; `fw watchtower status` → running :3002.
- **Gate:** `check-active-task` refused a read pipeline (`xargs … sh -c`) under null focus → filed this task via `fw work-on` first (verb), then re-ran the reads under it.
- **Instrument re-read (prior run's `fw bvp --include-proposed` output, 205 tasks):** 31 tasks carry a cost; of those **26 sit at exactly BVP 108 / norm 0.40 — the no-signal default — and 5 below it**. The quadrant medians are computed over those 31, so the BVP median *is* the default: `hv` ≡ "estimator found no signal", and `lc`/`hc` is a 3.6-vs-3.7 split on the effort term. All 26 Q1/Q2 rows are `workflow_type: inception`; the reason is structural — inceptions get a cost through the T-2189 `target_blast_radius` exception, builds get none until `components:` resolves at close (T-3068). Every signal-bearing open task (T-2667 111, T-2268 94, T-1820 87, T-2170 81 …) is therefore quadrant-less, and would read `lv` even if costed, because it scores below the default. Sharper form of OBS-439; recorded, not adjusted (producer-not-judge).

### Unit 1 — selection
- **Objective:** D2 Reliability / D1 Antifragility — a decision the project has since made elsewhere (arc-019 EWCR took up procedure-level enforcement) is still open as an inception in arc-014.
- **Arc:** arc-014 designer-corpus (rollup 86, in flight, not blocked). Skipped above it: arc-013 (SQ-2, hypervisor stack absent), arc-019 (SQ-3, operator review transfer / finalisation), arc-002 (no open agent work: T-1718/T-1719 are partial-complete, `owner: human`), arc-011 (only quadrant row T-2323 is DEFER'd by recorded decision — SQ-4).
- **Task:** T-2668 "guided-mode procedural enforcement (package Lock 6) inside mirror+rails" — **Q1 (hv-lc, 108 proposed)**. Tie-break over T-2669/T-2670 (same 108): T-2668's question has decisive existing evidence (EWCR architecture c9070637, Arc 0 contracts v1, T-3147), so its three Agent ACs close by read-only research; T-2669/T-2670 need design exploration with no such evidence base. T-2268 (94) and T-2170 (81) rejected: `owner: human`, T-2268 has only Human ACs left; both are below the instrument's value median anyway.
- **Activities (AC-required only):** problem statement validated; assumptions tested; recommendation written with rationale. Then `fw task review T-2668` — the go/no-go is Sovereign and is NOT taken here.
- **Execution mode:** self-executed (inception class — "dispatch the review, never the exploration"); TermLink not used for the research, recorded here as the reason. Research artefact first per C-001 (`docs/reports/T-2668-*.md`).

### Unit 1 — execution (T-2668)
- **Verb:** `fw work-on T-2668` (focus switched, status started-work). **Gate:** G-067 inception Open-Questions readiness refused a non-allowlisted read until an IW question was filed → filed IW-1..3 first (Edit), then researched with plain reads.
- **Checks recorded:** `fw assumption add` ×3 (A-054/A-055/A-056) → `invalidate A-054` (T-2663 GO "or park it as a named future arc"), `invalidate A-055` (git log windows on `agents/context/check-tier0.sh`: baseline 20/6, interim 1, post-rail 3/0 — unattributable), `validate A-056` (architecture §7.2/§7.3/§9/§11, contracts v1). `fw reviewer T-2668` → **Overall: PASS, Needs Human: no, Findings: none**. Mechanical: artefact present; 3 dispositions (2 answered, 1 dissolved), 0 open; Recommendation NO-GO.
- **Closed/parked:** three Agent ACs ticked as each landed; `fw task review T-2668` → http://192.168.10.107:3002/inception/T-2668 — go/no-go reserved to the operator. Commit c07504a05 (exploration commit 1/15).
- **What changed:** `docs/reports/T-2668-guided-mode-supersession-review.md` (new), T-2668 body filled (problem statement, assumptions, IW dispositions, plan, fence, criteria, NO-GO recommendation, decision record), `assumptions.yaml` +3. No source, no policy.
- **Cost vs estimate:** estimator `effort=6, tier=4, blast_radius=3` — all `(no-signal)`. Actual: read-only research, ~35 tool calls, 1 commit, zero components touched. The estimate carried no information either way; the cost driver that mattered (evidence already existing) is not something the heuristic reads.
- **Surfaced:** (a) P4's falsifiability test is confounded by maturity — transfers to arc-019's evidence design; (b) T-2670's subject appears in EWCR §8.3 → same supersession check warranted.

### Unit 2 — selection
- **Objective / arc:** unchanged (D2/D1; arc-014 designer-corpus, still the highest-ranked unblocked arc with Q1 rows).
- **Task:** T-2670 "workflow fabric: queryable cross-map index (package Lock 4 / SD-15)" — **Q1 (hv-lc, 108)**. Over T-2669 (same score): EWCR §8.3 "Workflow Fabric: the process-topology join" and roadmap Arc 4 ("Operator control and Workflow Fabric projection") / Arc 5 item 3 ("Workflow Fabric derived index, and impact query") name T-2670's deliverable directly, so the same read-only supersession research applies; T-2669 (audience lenses) has no supersession signal and would need design dialogue.
- **Activities:** the three Agent ACs; `fw task review T-2670`. Self-executed, same reason as Unit 1.

## Sovereign questions

## Gate refusals

## Handback

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
# ── Mutable-corpus anchor (T-3326) ────────────────────────────────────────────
# Do NOT anchor a verification line (or a unit test it runs) to MUTABLE corpus
# state — an exact live count, or a grep of live `fw audit`/`fw doctor` output
# for a specific corpus entity (a named arc, a task count, a census number).
# The corpus moves under the check, and the line rots: it goes red (or vanishes
# its pattern) for reasons unrelated to the code under test, blocking closes.
# Pin the INVARIANT (categories sum, count > 0, property holds) or run the code
# against a COMMITTED FIXTURE — never the live count or a live-audit line.
# Origin: T-2969 line grepping live audit for one arc's status; T-2871's census
# test pinning exact live counts (56→74 files) — both blocked closes (OBS-377).
#
# ── Pipefail/SIGPIPE: grepping a command's output (L-387, T-2090, T-2743, T-2738) ──
#
# THE DEFAULT — redirect to a file, then grep the file:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# Correct at any output size, and `&&` keeps the PRODUCING command's exit code in
# the verdict. Reach for this first; the alternative below is the special case.
#
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line with PIPEFAIL LIVE
# (errexit is not — see below). When grep matches it exits and closes stdin while cmd is still
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
# ── A SKIPPED BATS TEST REPORTS `ok` (T-3217) ─────────────────────────────────
#
# `! grep -q "^not ok"` does NOT mean the suite ran. Bats emits a skip as
#     ok 6 <name> # skip <reason>
# which is not a `not ok`, so the gate passes and the report says ok while the
# thing the test covers was measured NOWHERE. Origin: T-3213 guarded a test with
# `[ "$(id -u)" -eq 0 ] && skip` — the suite runs as root here and in CI, so it
# skipped on every run that mattered, for as long as it existed.
#
# Add a skip clause to any bats verification line. `# skip` is the marker bats
# writes; counting it is the whole check:
#     timeout 300 bats <file> > /tmp/.out 2>&1 && ! grep -q "^not ok" /tmp/.out
#     test "$(grep -c '# skip' /tmp/.out)" -eq 0
# Two lines, because they answer different questions — "did anything fail" and
# "did everything run". If some skips are legitimate on your host (an optional
# dependency is genuinely absent), assert the COUNT you expect rather than zero,
# and say in the task why that number is right.
#
# Corpus-wide, the same check runs from `bin/fw test lint`
# (tools/bats-silent-skip-lint.py): static mode flags guards that are fixed for
# a deployment rather than probing an optional dependency, and `--tap FILE`
# reports the skips a real run actually fired.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no pipefail. A line has returned 0 by hand and 141 under P-011, from
# the same directory, the same second. To rehearse for real:
#     bash -c 'set -o pipefail; <your verification line>'
#
# NOTE THE MISSING `-e` — it is not a typo (T-3203). This file used to prescribe
# `set -eo pipefail` here, which is NOT the gate: it adds errexit the gate does
# not have, so it FAILS lines the gate PASSES. Measured, 10 lines, 3 diverged:
#     line                            gate    set -eo (old)   set -o (this)
#     false; true                     PASS    FAIL  wrong     PASS  ok
#     cd /nonexistent; echo ok        PASS    FAIL  wrong     PASS  ok
#     grep -q MISS file; true         PASS    FAIL  wrong     PASS  ok
# The divergence is one-directional and that is the trap: the old rehearsal only
# ever fails lines the gate accepts, so it produces false REDS, and an author
# who "fixes" a line to satisfy it is fixing something that was never broken —
# while the line that actually is broken (`cmd1; cmd2` where cmd1 fails) passes
# both. Re-derive rather than trust this table — it is pinned, not asserted:
#     bats tests/unit/t3203_p011_gate_semantics.bats
#
# ── `cmd1; cmd2` IS JUDGED ONLY ON cmd2 (T-3203) ──────────────────────────────
#
# The gate runs each line as the CONDITION of an `if` (update-task.sh:1215), and
# POSIX suppresses errexit for a compound command in an `if` condition — through
# the subshell. So pipefail applies and `set -e` does not, and in a sequence only
# the LAST command's status reaches the verdict. `cd /nonexistent; echo ok` passes.
# 2,644 of 10,997 verification lines in this corpus contain `;` (re-derive with
# the query in docs/reports/T-3203-p011-gate-semantics.md).
#
# SAFE SHAPES — both verified biting, each against a passing control:
#   A. one command whose own status is the verdict (prefer this):
#        out=$(cmd 2>&1); echo "$out" | grep -q PAT && ! echo "$out" | grep -q BAD
#      the leading assignments are setup; the trailing `&&` chain is the verdict.
#   B. an explicit sub-shell, whose errexit the outer `if` cannot reach into:
#        bash -c 'set -eo pipefail; cmd1; cmd2'
#      use when you genuinely need every command in the sequence to count.
#
# The rule of thumb: put the assertion LAST, and make sure it is an assertion.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

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

### 2026-09-19T15:59:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3391-autonomous-run-2026-09-19-top-down-bvp-s.md
- **Context:** Initial task creation
