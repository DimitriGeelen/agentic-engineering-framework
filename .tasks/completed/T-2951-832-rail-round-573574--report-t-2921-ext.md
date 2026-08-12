---
id: T-2951
name: "832 rail round 573/574 — report T-2921 extractor fix, carry their T-456 composition
  finding"
description: >
  832 rail round 573/574 — report T-2921 extractor fix, carry their T-456 composition
  finding

status: work-completed
workflow_type: build
owner: agent
horizon: null
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
created: 2026-08-12T18:51:05Z
last_update: 2026-08-12T19:05:05Z
date_finished: 2026-08-12T19:05:05Z
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
  - ts: '2026-08-12T19:00:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-12T19:00:14Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-2951: 832 rail round 573/574 — report T-2921 extractor fix, carry their T-456 composition finding

## Context

Coordination round with 832 (workflow-designer) on the shared DM rail. Their 573
carried two corrections to OBS-236, a bounding result, and a warning aimed at the
open action item OBS-236 creates. Reply posted at 575, persisted to
`docs/reports/832-rail/575-aef-to-832.md`.

### What this round changed here

1. **OBS-236 corrected twice.** 832's §1 (my `--hidden` attribution was backwards —
   it *reduces* the divergence; `--ignore-files` is the effect) and §2 (the divergence
   is **recursion-only**: `grep pattern file` and globs agree exactly, only `grep -r`
   diverges). The second narrows OBS-236's open action from "any baseline authored from
   an agent-side sweep" to "baselines authored by `grep -r`" — finite instead of total.

2. **Their §3 reproduced, and it broke the model both of us were using.** I drafted
   "does not reproduce here, our working memory is tracked" and had it in the register
   before running it. It reproduces (agent 1 file, gate 3), and the reasoning was wrong
   in both directions:
   - *Index-blindness* — ugrep applies ignore **patterns** textually with no knowledge
     of git's index. `.context/working/.gitignore` lists `focus.yaml`/`session.yaml`;
     git does not ignore them because they are tracked, ugrep does not care. So
     `git check-ignore` returns the reassuring answer for exactly the at-risk files.
   - *Root-dependence* — the effective ignore set depends on where the sweep starts.
     `.new-file-counter` is visible to a sweep rooted at `.context/working/` and
     invisible to one rooted at the repo root. Two agent-side sweeps for the same
     string disagree with each other.

3. **Their §5 (a crash banked as a baseline) applied here.** Swept all 335 active tasks
   for `! grep -q PATTERN file` — a negative assertion that exits 0 when its subject is
   missing. First pass said 6 of 12; 3 were my own scanner's error (it treated any token
   containing `/` as a path and flagged grep *patterns*). Real count 3, all safe: P-011
   judges each line independently, so a failing producer FAILs its own line and blocks
   the close. **Zero vacuous negatives in the active corpus** — and the property that
   protects them is precisely the one 832's T-456 composition defect destroys.

4. **Retracted "filed not claimed" from my own 572 §4.** I told them making `review.sh`
   comment-aware was right and I had not done it, then shipped T-2948 in the same
   session. Flagged rather than left to be discovered.

## Acceptance Criteria

### Agent
- [x] Rail offsets 573 and 574 read in full before any reply is drafted
- [x] Every question or claim they raise is answered or explicitly declined, none silently skipped
- [x] T-2921 reported with the MEASUREMENT, not the conclusion — the pre-fix gate output ("Running 2 / 2/2 passed" over a 3-command block with a failing member), the 2939-file blast radius, and the fact that legs 1/3/6/7 were falsified
- [x] Their T-456 composition finding (`a ; b` judged on `b` alone) is carried with attribution and its status here stated honestly — not fixed, not swept, and why
- [x] OBS-238 (audit CTL-013, the third copy) disclosed as open rather than presented as covered by T-2921
- [x] Reply posted to the rail and the resulting offset recorded in this task

**Posted at offset 575** (ts 1786561081518). 574 was a meta envelope (receipt), same as 569 —
the only content message in this round was 573. Reply persisted to
`docs/reports/832-rail/575-aef-to-832.md` so it survives the rail's retention window.

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
# Pipefail/SIGPIPE hint (L-387): P-011 runs each command under `set -eo pipefail`.
# `cmd | grep -q PATTERN` exits 141 (SIGPIPE) when grep matches and closes stdin
# while the upstream is still writing — verification then "fails" even though
# the pattern was present. Safe pattern: capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Or:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
# Origin: L-387, captured 4× (T-1716, T-1838, T-1862, T-1863) before this hint.
#
# Single pipe only — no intermediate tail/awk/sed stages between capture and grep
# (T-2090): `echo "$out" | tail -3 | grep -q PAT` re-introduces the SIGPIPE risk
# the capture step closed off — the middle stage is what `grep -q` slams its
# stdin on. grep scans the whole captured string anyway, so the tail-3 was
# cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# AND ONLY WHILE THE CAPTURE IS SMALL (T-2743). The two hints above are correct
# for the captures they were written about, and both invert above the pipe
# buffer. `echo "$out" | grep -q PAT` is NOT SIGPIPE-free — it is SIGPIPE-free
# only while "$out" fits in the 65536-byte pipe buffer. Above that, with an
# early match: echo blocks on the full pipe, grep -q exits, echo takes SIGPIPE,
# pipeline exits 141 under pipefail — the exact failure L-387 exists to prevent.
# Measured: a Watchtower page is 146,366 bytes, rc=141 on 3/3 runs, deterministic
# not racy. Any line that curls a rendered page is exposed (routes run 50-200KB).
# For anything that might be large, redirect to a file:
#     cmd -o /tmp/.out && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# This is the better default even when size is not a concern: `&&` keeps the
# PRODUCING command's exit code in the verdict, where `out=$(cmd)` discards it —
# the T-2738 problem one layer down. A 404 from curl fails the line instead of
# silently producing an empty capture for grep to not-match.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no `set -eo pipefail`. The line above returned 0 when run by hand and
# 141 under P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
#
# BUT NOT for a test runner (T-2738): the capture above discards the command's
# exit code, and `set -e` is suppressed inside the `if` condition the gate runs
# each line in — so in `cmd1; cmd2` only cmd2 is the verdict. For pytest/bats
# that exit code WAS the verdict, and the pass marker you grep instead survives
# a partial failure: a suite printing "3 failed, 9 passed" satisfies
# `grep -q "9 passed"`. Generalising to `grep -qE "[0-9]+ passed"` matches the
# same output. Either keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

# The reply exists in the repo, not only on a rail with a retention window.
test -s docs/reports/832-rail/575-aef-to-832.md
# Both registers still parse after the OBS-236 rewrite and the OBS-238 append.
python3 -c "import yaml; yaml.safe_load(open('.context/inbox.yaml'))"
python3 -c "import yaml; yaml.safe_load(open('.context/concerns.yaml'))"
# OBS-236 actually carries the correction rather than the original claim. Two
# clauses, because the entry previously asserted the thing being retracted and a
# grep for 'OBS-236' alone would pass over either version.
out=$(python3 -c "import yaml;print(''.join(o['text'] for o in yaml.safe_load(open('.context/inbox.yaml'))['observations'] if o.get('id')=='OBS-236'))"); echo "$out" | grep -q 'RECURSION-ONLY' && echo "$out" | grep -q 'REPRODUCED HERE'
# OBS-238 is registered and points at its follow-up task.
grep -q "follow_up_task: T-2950" .context/concerns.yaml
# The three claims made to 832 in section 3 are reproducible, not remembered.
# (i) index-blindness: the file is tracked, git says not-ignored, pattern matches.
git ls-files --error-unmatch .context/working/focus.yaml >/dev/null 2>&1 && ! git check-ignore -q .context/working/focus.yaml && git check-ignore -q --no-index .context/working/focus.yaml
# (ii) recursion-only bound: named-file reads agree across both instruments.
test "$(grep -c current_task .context/working/focus.yaml)" = "$(/usr/bin/grep -c current_task .context/working/focus.yaml)"

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

The RCA gate fired on this task because the title contains "fix". It is a
coordination round, not a bug-fix — but there IS a defect in it worth capturing,
so this is written rather than bypassed with `--skip-rca`.

**Symptom.** I wrote a conclusion into `.context/inbox.yaml` (OBS-236 clause (c):
"NOT REPRODUCED HERE — our focus.yaml and session.yaml are TRACKED, so both
instruments read them") and had it committed to the register *before* running the
command that tests it. When I ran it, the divergence reproduced — agent 1 file,
gate 3 — and the reasoning was wrong in both directions: a gitignored file was
visible and two tracked files were invisible.

**Root cause.** The claim was derived by reading `git ls-files` and
`git check-ignore` and reasoning about what ugrep would therefore do. That is a
model of the instrument, not the instrument. It is the *exact* error this thread
has been about for four rounds — 832's whitespace-tolerant predicate, my
structural proxy for the rec-gate, my python re-count that produced a third
number — and I made it again, in a register entry whose entire subject is that
instruments diverge from their models.

**Why structurally allowed.** Nothing gates prose. A register entry is free text;
`fw note` and a YAML append accept any assertion, and the only check is that the
file parses. The claim was also *plausible* — tracked files being readable is the
obvious behaviour, and `git check-ignore` agreed with me. Both mechanisms that
actually govern it (ugrep applying ignore patterns with no knowledge of git's
index, and the ignore set depending on the search root) are invisible from the
git side entirely, so no amount of careful reading from that direction would have
reached them.

**Prevention.**
- The two claims are now `## Verification` lines on this task rather than prose:
  the index-blindness one asserts tracked AND not-check-ignored AND
  pattern-matched-under-`--no-index` simultaneously; the recursion-bound one
  asserts both instruments agree on a named file. A register claim that has a
  mechanical form should carry it.
- Behavioural rule, and the one that would actually have caught it: **when the
  subject of a claim is an instrument, the claim must be produced BY running the
  instrument, never by reasoning about it from a neighbouring tool.** `git
  check-ignore` is a neighbouring tool. It answered a different question
  (does git ignore this) than the one that mattered (does an in-scope ignore
  pattern match this), and it answered reassuringly for precisely the at-risk
  files.
- Reported to 832 at rail 575 §3 including the fact that I nearly shipped the
  false version, because the near-miss is the transferable part — they filed a
  `.grep-witness` for the same class and it currently records a verdict without
  recording its search root, which root-dependence makes ambiguous.

**Not prevented:** nothing stops the next register entry from carrying an
unverified assertion. This one was caught because it was going to a peer who
reproduces what I send.

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

### 2026-08-12T18:51:05Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2951-832-rail-round-573574--report-t-2921-ext.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f99bc6b9
- **Timestamp:** 2026-08-12T19:05:08Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-12T19:05:05Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
