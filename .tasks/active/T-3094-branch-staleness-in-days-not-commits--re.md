---
id: T-3094
name: "Branch staleness in days, not commits — recalibrate the hygiene trigger (T-3093
  slice 1)"
description: >
  Branch staleness in days, not commits — recalibrate the hygiene trigger (T-3093
  slice 1)

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
created: 2026-08-20T00:17:06Z
last_update: '2026-08-20T00:30:15Z'
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
  - ts: '2026-08-20T00:30:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=227,acs=11)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-20T00:30:15Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3094: Branch staleness in days, not commits — recalibrate the hygiene trigger (T-3093 slice 1)

## Context

Slice 1 of the T-3093 GO. **Must land before slice 2 (audit-cron promotion)** — the
sequence is the substance of the decision, not an ordering preference.

`FW_BRANCH_BEHIND_WARN` counts commits on the target since the fork. On this repo
`origin/master` moves at ~41 commits/day, so a 50-commit threshold is crossed in
**~1.2 days**: every healthy in-progress branch becomes a finding by the next morning.
And 88% of that movement (2266 of 2577 commits since 2026-06-01) touches nothing
outside `.context/` and `.tasks/` — the counter deciding whether *your* branch is
stale is driven almost entirely by other people's handovers.

That is why the section goes unread: it is mostly false positives by construction.
Promoting it to cron before fixing this would flood the daily audit and burn the
signal permanently.

The right unit already exists in this framework: `FW_STALE_ARC_DAYS` (default 30,
`lib/config.sh:245`, T-1855) WARNs an in-progress arc with no constituent-task commit
in N **days**. Branch staleness wants the same question — how long since anyone
touched this branch — not how much unrelated churn happened elsewhere.

Evidence: `docs/reports/T-3093-branch-hygiene-escalation.md` F3.

## Acceptance Criteria

### Agent
- [x] `FW_BRANCH_STALE_DAYS` exists in the `lib/config.sh` `FW_CONFIG_REGISTRY` with a default and a description, is mirrored in `web/blueprints/config.py`, and renders on Watchtower `/config` (CLAUDE.md §Configuration parity rule; `tests/lint/config-registry-parity.bats` green).
  **Note — the AC as first written was wrong about the surface.** `fw config list` and `fw config get` read `.framework.yaml` only (`lib/config-file.sh:185` `_config_get`), so they print *persisted overrides*, not the registry: `fw config get STALE_ARC_DAYS` — a key that has been in the registry since T-1855 — returns empty too. The registry's operator surfaces are Watchtower `/config` and `fw config` defaults resolution, and those are what is verified.
- [x] `fw_branch_hygiene` computes days-since-last-commit per branch and reports it on the finding line
- [x] A branch committed to recently is SILENT regardless of how far behind it is — this is the false-positive fix and the whole point of the slice
- [x] A branch untouched beyond the threshold still surfaces, and all four real strands (`t2353-audit-emit-tasks`, `t2417-fw-sessions`, `worktree-rca-worktree-push-strand`, `t2511-warn-remediation`) are among them on this repo
- [x] The commit-count is retained on the finding line — it is what tells the operator whether a strand is still landable, and the fix is to stop *triggering* on it, not to stop reporting it
- [x] `merged-undeleted`, `remote-contained` and `remote-unlanded` are unaffected (they are not staleness judgements) — regression-guarded
- [x] Bats coverage in `tests/unit/t100143_branch_hygiene.bats` for: fresh-but-far-behind (silent), stale-and-behind (fires), threshold boundary, and the finding-line format
- [x] Mutation check recorded in Decisions: disabling the recency guard turns the fresh-branch test red, and the pre-existing suite stays green throughout
- [x] The live scan's finding count is accounted for branch by branch — **not** assumed to drop. Measured before building: every judged branch here is 43–170 days untouched, so all seven staleness findings are TRUE and the count stays at seven. This slice prevents future false positives; it does not clean up present ones, and an AC that demanded a drop would have been satisfiable only by breaking the detector

### Human

- [ ] [REVIEW] The `BRANCH_STALE_DAYS` row on Watchtower `/config` reads correctly next to its siblings

  **Steps:**
  1. `bin/fw watchtower url` — open the printed URL and append `/config`
  2. Find `BRANCH_STALE_DAYS` (it sits directly under `STALE_ARC_DAYS`)
  3. Read the row and its description alongside `STALE_ARC_DAYS` and `BRANCH_BEHIND_WARN`

  **Expected:** the row renders in the same shape as its neighbours (key / default `30` /
  description, no wrap break, no truncated description, no stray markup), and the description
  makes it clear *without reading the code* that this setting gates `BRANCH_BEHIND_WARN` rather
  than replacing it.

  **If not:** note which of the two is wrong — layout (a rendering fix in
  `web/blueprints/config.py`) or wording (the description string, mirrored in
  `lib/config.sh:246` and `web/blueprints/config.py:46` — both must change together or
  `tests/lint/config-registry-parity.bats` goes red).

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

# ── T-3094 verification ──

out=$(bats tests/unit/t100143_branch_hygiene.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/lint/config-registry-parity.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
grep -q 'BRANCH_STALE_DAYS|30|' lib/config.sh
grep -q 'BRANCH_STALE_DAYS' web/blueprints/config.py
curl -sf "$(bin/fw watchtower url)/config" -o /tmp/.t3094-config.html && grep -q 'BRANCH_STALE_DAYS' /tmp/.t3094-config.html
# every staleness finding carries BOTH the day count (the new trigger) and the commit count (the landability signal)
bash -c 'source lib/branch-hygiene.sh; fw_branch_hygiene .' > /tmp/.t3094-scan.txt 2>&1 && awk '$1=="behind-threshold"||$1=="diverged-fork"{n++; if ($0 !~ /days=/ || $0 !~ /behind=/) bad++} END{exit (n>0 && bad==0)?0:1}' /tmp/.t3094-scan.txt
# the four real strands are still among the findings after the recalibration
awk '/ t2353-audit-emit-tasks /{a=1} / t2417-fw-sessions /{b=1} / worktree-rca-worktree-push-strand /{c=1} / t2511-warn-remediation /{d=1} END{exit (a&&b&&c&&d)?0:1}' /tmp/.t3094-scan.txt
# the non-staleness classes still fire (regression guard for AC 6)
awk '$1=="merged-undeleted"{a=1} $1=="remote-unlanded"{b=1} $1=="remote-contained"{c=1} END{exit (a&&b&&c)?0:1}' /tmp/.t3094-scan.txt
bin/fw reviewer T-3094 > /tmp/.t3094-rev.txt 2>&1 || true; grep -q 'Overall:.*PASS' /tmp/.t3094-rev.txt

## RCA

**Symptom.** The branch-hygiene section of `fw doctor` went unread (T-3093 F4), so four
genuinely stranded branches sat unlanded for 43–55 days with a live detector pointing
straight at them.

**Why (1)** — because the section was mostly noise. **Why (2)** — because every healthy
in-progress branch became a finding within ~1.2 days of being created. **Why (3)** —
because the trigger counted commits on `origin/master` since the fork point.
**Why (4)** — because that counter is a proxy for staleness that only holds when master
moves at the rate the threshold was chosen for; here it moves ~41 commits/day and 88% of
that is governance churn nobody's branch is behind on in any meaningful sense.
**Why (5)** — because the threshold was picked as a number (50) without pinning the unit
to the question being asked, and nothing re-checks a threshold against the repo's actual
commit rate.

**Class.** Proxy-metric drift: a gate measuring something correlated with the target at
authoring time, with no mechanism to notice when the correlation breaks. Same class as
T-1828. The counter-measure here is choosing a unit that is causally tied to the question
("days since anyone touched *this branch*") rather than one that merely correlated.


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

### D-1: staleness is measured in days on the branch, not commits on master

`FW_BRANCH_BEHIND_WARN` asks "how much has master moved since you forked?" — a question
whose answer is driven almost entirely by *other people's* work. On this repo master
moves ~41 commits/day and 88% of that (2266 of 2577 since 2026-06-01) touches only
`.context/` and `.tasks/`, so a 50-commit threshold is crossed in ~1.2 days by a branch
nobody has neglected. The unit was the defect, not the number.

`FW_BRANCH_STALE_DAYS` (default 30) asks the question the finding is actually named
after: how long since anyone committed **on this branch**. Deliberately the same unit
and the same default as `FW_STALE_ARC_DAYS` (T-1855) — the framework already had a
staleness idiom and this is that idiom, not a new one.

The commit count stays on the line. It is what tells the operator whether a strand is
still landable at all (FF-only integrate — see T-3091), and the fix was to stop
*triggering* on it, not to stop *reporting* it.

### D-2: the recency gate fails OPEN

`_bh_days_since_commit` returns empty when it cannot date a ref, and the gate is
`[ -n "$_days" ] && [ "$_days" -lt "$stale_days" ]` — an undateable branch is NOT
silenced. A hygiene detector that goes quiet when its own instrument fails is worse
than one that over-reports, because silence is indistinguishable from health.

### D-3: mutation results, including the one that survived

| # | Mutation | Result |
|---|----------|--------|
| F | `if false; then continue; fi` — recency guard never suppresses | **RED** — tests 16 and 19 |
| H | drop `$_dtag` from both finding lines | **RED** — tests 3, 17, 18 |
| G | flip fail-open to fail-closed (`[ -z "$_days" ] \|\| …`) | **GREEN — survives** |

G survives and I am not papering over it. The path is unreachable by construction, the
same mechanism T-3092 hit with its mutation B: the loop is fed by
`git for-each-ref refs/heads/`, which drops broken refs with a warning *before* the loop
can see them, so a local branch that `git log -1 --format=%ct` cannot date does not reach
the guard. The `-n` test is retained as a deliberate sentinel (D-2), documented as
unreachable rather than pinned by a test that could only pass by faking the condition.

### D-4: AC #1 was written against the wrong surface

The AC claimed `fw config list` would surface the new key. It does not, and never did for
any registry key: `_config_get` / `_config_list` (`lib/config-file.sh:185`) read
`.framework.yaml`, i.e. persisted *overrides*. `fw config get STALE_ARC_DAYS` — in the
registry since T-1855 — returns empty for the same reason. Corrected in place with the
reason recorded, rather than quietly re-pointed, because the next author will make the
same assumption.

### D-5: the finding count does not drop, and that is the correct outcome

Measured before building: all seven staleness findings on this repo are 43–170 days
untouched, so all seven are TRUE. This slice prevents the *next* false positive; it does
not clean up present ones. An AC demanding a count reduction would have been satisfiable
only by breaking the detector.


## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-20T00:17:06Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3094-branch-staleness-in-days-not-commits--re.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8c5270bd
- **Timestamp:** 2026-08-20T00:42:07Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
