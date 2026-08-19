---
id: T-3091
name: "Prune dead branch refs and produce a salvage manifest for the 15 stranded branches"
description: >
  Prune dead branch refs and produce a salvage manifest for the 15 stranded branches

status: started-work
workflow_type: decommission
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
created: 2026-08-19T22:50:45Z
last_update: '2026-08-19T23:00:16Z'
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
  - ts: '2026-08-19T23:00:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:decommission); effort=8 (lines=274,acs=9)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-19T23:00:16Z'
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
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-3091: Prune dead branch refs and produce a salvage manifest for the 15 stranded branches

## Context

Fifteen branches carry commits that never landed on master. Measured during the
`t2539-staging` land review: every one forked from a commit that WAS on master
(2026-03-01 … 2026-07-07), master then advanced to 2026-08-14, and none was ever
brought forward. The sanctioned landing path `fw integrate run master --push` is
fast-forward-only, so the moment master passes a branch's fork point the branch
becomes unlandable by the only sanctioned route — and nothing rebases it, blocks
the widening fork, or escalates. `t2353-audit-emit-tasks`, the branch CLAUDE.md
already names as the T-2428 five-week strand, is now **1761 commits behind**.

`lib/branch-hygiene.sh` already reports 7 of them (`behind-threshold`,
`diverged-fork`) at 1400–7100 commits over a threshold of 50. Detection works;
nothing acts on it. Separately, OBS-331: the scan has no class for a *remote* ref
carrying unlanded commits, so `origin/t2416-fw-safe-mode-hook-timing` (202
unlanded) is invisible while its landed local namesake reads `merged-undeleted`.

This task prunes what is provably dead and produces an evidence-backed salvage
manifest for what is not. It does **not** cherry-pick — that is a separate
deliverable once the manifest says what is worth carrying.

Operator authorised the prune in-thread (2026-08-20) after being shown the
per-branch evidence.

## Acceptance Criteria

### Agent
- [x] Recovery manifest written to `docs/reports/T-3091-branch-manifest.md` recording every branch name → tip SHA before any deletion, so any ref is restorable with `git branch <name> <sha>`
- [x] The 4 patch-id-identical refs are confirmed dead (`git cherry HEAD <ref>` shows 0 unlanded) and their objects are pinned by local `strand-backup/*` tags so deletion is reversible after gc
- [x] Every file changed by the 11 keep-branches is classified `NEW-FILE` / `SALVAGE` / `PARTIAL` / `LANDED` by comparing the branch's added lines against HEAD's copy, with the counts recorded per file
- [x] The manifest states the mechanism that stranded all 15 branches (FF-only landing + fork point passed by master) rather than only listing symptoms
- [x] The first-pass misclassification is recorded in the manifest, not silently corrected — three branches were called dead by a filter that excluded `docs/`, `CLAUDE.md` and `.fabric/`
- [x] No branch carrying a `NEW-FILE` or `SALVAGE` verdict is deleted by this task

**Out of scope — blocked, carried to a follow-up:** deleting the 4 dead remote refs. `git push
origin --delete` was refused by the permission classifier. Not worked around; surfaced to the
operator. The refs remain, tagged and documented.

### Human
- [ ] [REVIEW] The SALVAGE verdicts are the right call — this work is worth carrying forward rather than abandoning
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && cat docs/reports/T-3091-branch-manifest.md`
  2. Read the SALVAGE table. Each row names a file, the branch it is on, and what the change does.
  3. For each row, decide: carry it forward, or let the branch die with it.
  **Expected:** You agree with the carry/abandon split, or you name the rows you want flipped.
  **If not:** Reply with the file paths you want reclassified; the cherry-pick task is filed against the manifest, so flipping a row before that task starts costs nothing.

  Why this is yours and not mine: abandoning work is a strategic call with a blast radius I cannot measure — I can prove a change is absent from master, but not that it stopped mattering.

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

test -f docs/reports/T-3091-branch-manifest.md
grep -q "## Recovery manifest" docs/reports/T-3091-branch-manifest.md
grep -q "## Salvage verdicts" docs/reports/T-3091-branch-manifest.md
# every ref recorded with a restorable tip SHA
test "$(grep -cE '^\| `[^`]+` \| `[0-9a-f]{7,}`' docs/reports/T-3091-branch-manifest.md)" -ge 15
# the four dead refs are pinned by tags so their objects survive gc after deletion
for r in fix/T-002-governance-activation-gap fix/T-003-auto-onboarding-tasks main t100199-close; do git rev-parse --verify -q "refs/tags/strand-backup/$r" >/dev/null || exit 1; done; true
# each tag still resolves to the tip the manifest recorded
for r in fix/T-002-governance-activation-gap fix/T-003-auto-onboarding-tasks main t100199-close; do grep -q "$(git rev-parse --short refs/tags/strand-backup/$r)" docs/reports/T-3091-branch-manifest.md || exit 1; done; true
# no branch carrying absent content was deleted
for r in t2353-audit-emit-tasks t2417-fw-sessions worktree-rca-worktree-push-strand t2511-warn-remediation audit-remediation-t2416 worktree-inception-gov-payload-mediation learning/precompact-cleanup; do git rev-parse --verify -q "refs/heads/$r" >/dev/null || exit 1; done; true
git rev-parse --verify -q refs/remotes/origin/t2416-fw-safe-mode-hook-timing >/dev/null
# the manifest names the stranding mechanism, not just the symptom
grep -q "fast-forward-only" docs/reports/T-3091-branch-manifest.md
# the stranded inception artifact that diagnoses this very failure is listed as absent
grep -q "T-2505-worktree-usage-policy.md" docs/reports/T-3091-branch-manifest.md

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

**Recommendation:** GO — on the manifest. NO-GO on the framing that started this.

**Rationale:** The premise was pollution to be pruned. The evidence says otherwise: 4 of 15 refs
are dead, and the other 11 carry roughly 50 distinct files that do not exist on master — 13
research artifacts, a complete escalation-rules subsystem, `lib/audit_emit.sh` and its tests, 6
unprocessed `.pickup/` messages. Pruning on the original plan would have deleted an inception
artifact that diagnoses the very failure that stranded it. The manifest is the deliverable worth
keeping; the prune is a four-ref footnote that is currently blocked anyway.

The salvage/abandon call is yours — I can prove a change is absent from master, I cannot prove it
stopped mattering.

**Evidence:**
- All 15 refs recorded with tip SHA; the 4 dead ones additionally pinned by `strand-backup/*` tags
- Dead verdict rests on `git cherry` patch-id equality, not on the path heuristic that misfired
- 51 NEW-FILE and 19 SALVAGE rows enumerated per file with line counts; 147 PARTIAL rows flagged as needing a human read rather than given a verdict
- Mechanism identified: FF-only `fw integrate` + fork point overtaken by master, with `lib/branch-hygiene.sh` detecting 7 of them at 1400–7100 commits over a threshold of 50 and nothing consuming the finding
- OBS-331: the same scan has no class for a remote ref carrying unlanded commits, so `origin/t2416-fw-safe-mode-hook-timing` (202 unlanded) is invisible while its landed local namesake reads `merged-undeleted`

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

### 2026-08-20 — "no code commits" is not "no content"

- **Chose:** Reclassify all three "dead by zero code commits" branches as KEEP, and delete only refs proven dead by patch-id.
- **Why:** The first-pass filter asked whether any commit touched `lib/ bin/ agents/ web/ tests/ policy/`. It excluded `docs/`, `CLAUDE.md` and `.fabric/`. All three branches carried content absent from master under exactly those paths — `worktree-inception-gov-payload-mediation` holds `docs/reports/T-2505-worktree-usage-policy.md`, an inception artifact diagnosing this exact stranding failure, absent from master since 2026-07-01; `audit-remediation-t2416` holds the only CLAUDE.md Quick Reference entry for `fw integrate`, still missing on HEAD.
- **Rejected:** Deleting on the first-pass verdict. It was one grep away from destroying a research artifact about the problem being solved. The lesson is not "widen the glob" — it is that a deletion verdict must be evidence of *absence of content*, never absence of a path prefix I happened to enumerate.

### 2026-08-20 — patch-id equality is the only deletion-grade evidence used

- **Chose:** `git cherry HEAD <ref>` reporting zero unlanded commits is the sole criterion for calling a ref dead.
- **Why:** It compares the actual patch, not a path heuristic. All four dead refs still show `PARTIAL` file rows, because HEAD edited the same regions later — a file-level comparator would have called them live. Patch-id says the change itself was applied.
- **Rejected:** The added-line comparator as a deletion criterion. It is the right tool for *ranking salvage candidates* and the wrong one for authorising a delete: it cannot distinguish "this change landed and was then edited" from "this change never landed".

### 2026-08-20 — classifier method, recorded so the verdicts are reproducible

- **Chose:** For each file a branch changed since its fork point, take the branch's added non-blank lines and count how many appear verbatim in HEAD's copy. All present → LANDED; none → SALVAGE; some → PARTIAL; file missing on HEAD → NEW-FILE.
- **Why:** `git diff HEAD...<branch>` is useless here — HEAD is 354 commits ahead, so it reports our side's changes and drowns the branch's. Line-membership asks the only question that matters: is the branch's contribution present, whatever the surrounding file now looks like.
- **Rejected:** Treating PARTIAL as a verdict. 147 rows landed there and every one means "HEAD edited this region later" — that needs a human read, which is why the Human AC exists.

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

### 2026-08-19T22:50:45Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3091-prune-dead-branch-refs-and-produce-a-sal.md
- **Context:** Initial task creation
