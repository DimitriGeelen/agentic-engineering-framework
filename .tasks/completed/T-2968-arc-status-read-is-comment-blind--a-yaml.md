---
id: T-2968
name: "arc status read is comment-blind — a YAML comment on status: silently disables
  every status-gated arc verb"
description: >
  arc status read is comment-blind — a YAML comment on status: silently disables every
  status-gated arc verb

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
created: 2026-08-13T11:41:14Z
last_update: 2026-08-13T11:48:22Z
date_finished: 2026-08-13T11:48:22Z
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
  - ts: '2026-08-13T11:45:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-13T11:45:14Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2968: arc status read is comment-blind — a YAML comment on status: silently disables every status-gated arc verb

## Context

`_arc_get_status` (`lib/arc.sh:96-100`) reads `status:` with awk, then `tr -d ' "'`,
then `head -c 32`. An inline YAML comment on that line is valid YAML and invisible to
every YAML parser — but this reader keeps it, and having deleted all spaces, welds it
onto the value.

Measured live on arc-013 (`payload-mediation.yaml:7`):

    file line       status: in-progress  # T-2428 GO recorded 2026-06-18 — build arc authorized
    yaml.safe_load  'in-progress'
    _arc_get_status 'in-progress#T-2428GOrecorded2026'     <- truncated at 32 by head -c
    control arc-015 both readers agree: 'in-progress'

Consequence: every `_arc_require_status` caller refuses for that arc. `fw arc close
arc-013` returns *"currently 'in-progress#T-2428GOrecorded2026'. Expected one of:
in-progress"* — while `fw arc list`, the audit's stale-arc scan, and Watchtower all
render it `in-progress`, because those read YAML. The arc is structurally unclosable
and nothing except the refusal itself says so.

The refusal even prints the mangled value, which is the one thing that makes this
recoverable — but its "Allowed transitions" list offers no transition out of the state
it names, so a reader who does not spot the welding has no next move.

Found while measuring why arc-016 (`draft`, 2/2 constituents complete) cannot be
closed. That question is separate and still open; this is what the measurement turned up.

## Acceptance Criteria

### Agent
- [x] `_arc_get_status arc-013` returns exactly `in-progress` with the comment still in the file (the comment is the fixture — do not delete it to pass)
- [x] `fw arc close arc-013` no longer refuses on status; it reaches the T-1671 sovereignty gate instead
- [x] Comment stripping is YAML-faithful: `status: a#b` (no space before `#`) keeps `a#b`, since YAML only starts a comment after whitespace
- [x] Control preserved: arcs with no inline comment return the same value as before the change
- [x] bats regression test pins all four, and its counterfactual against pre-fix `lib/arc.sh` is measured and recorded in the file header

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

bash -n lib/arc.sh
out=$(bats tests/unit/t2968_arc_status_comment_blind.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bin/fw arc list 2>&1); echo "$out" | grep -qE '^ +arc-013 +in-progress +[0-9]+ '
out=$(bin/fw arc list 2>&1); ! echo "$out" | grep -E '^ +arc-013 ' | grep -q '#'
# `|| true` is load-bearing: this command SHOULD exit non-zero (it refuses at the
# T-1671 sovereignty gate). Without it, set -e kills the line on the exit code we
# are deliberately ignoring — we assert on WHICH refusal fired, not on success.
out=$(bin/fw arc close arc-013 --demo none --justification t2968 2>&1 || true); ! echo "$out" | grep -q 'is currently'
out=$(bin/fw arc close arc-013 --demo none --justification t2968 2>&1 || true); echo "$out" | grep -q 'agents must not invoke'
out=$(grep -cE "awk[^|]*/\^status:" lib/arc.sh); [ "$out" -eq 2 ]

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

## RCA

**Symptom:** `fw arc close arc-013` refused with *"arc 'payload-mediation' is currently
'in-progress#T-2428GOrecorded2026'"* — a status string that appears nowhere in the file,
against an arc every other surface renders `in-progress`.

**Root cause:** `status:` had **five** hand-rolled readers in `lib/arc.sh` and they
disagreed. On the same line they returned `in-progress#T-2428GOrecorded2026` (the gate),
the raw line including the comment (`fw arc list`), `in-progress` (one site, correct only
because it used awk's default field splitting), and a longer welded string (two more).
None of them knew that a `#` after whitespace opens a YAML comment.

**Why structurally allowed:** three compounding reasons.

1. *The idiom is house style.* The arc template itself writes inline comments on
   top-level keys — 11 of 18 arc YAMLs carry `scoped_drivers: []   # max 3, weight ≤6…`.
   A comment on `status:` is not exotic input; the framework taught the format.
2. *One site was correct by accident.* The `awk '/^status:[[:space:]]/ {print $2}'` form
   survives a comment because default field splitting stops at whitespace. Nobody chose
   that; it reads identically to the broken forms. Correct-by-accident produces no
   pressure to write the rule down, so the next copy is a coin flip — and four of five
   landed the other way.
3. *The two readers could not fail together.* Every YAML-reading surface (audit's
   stale-arc scan, Watchtower, `fw arc list`'s task count) showed the arc healthy and
   in-progress. Only the shell gate saw the mangled value, and only when someone tried
   to close the arc. This is 832's rail-604 rule from the other side: two instruments
   agreeing is corroboration only if they can fail independently — here they *did* fail
   independently, and the loud one was the one nobody ran.

**Prevention (distinct from the fix):** the fix is one parser; the prevention is that
`_arc_status_from_file` is now the *only* status reader, and the regression suite asserts
against `yaml.safe_load` as oracle rather than against hard-coded strings — so any future
divergence from YAML semantics goes red regardless of which direction it drifts. The
remaining raw `^status:` awk in `lib/arc.sh:579` reads *task* files (different schema),
and is out of scope by design rather than by oversight.

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

### 2026-08-13T11:41:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2968-arc-status-read-is-comment-blind--a-yaml.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2595a8e3
- **Timestamp:** 2026-08-13T11:48:51Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 4
     - evidence: `out=$(bin/fw arc list 2>&1); ! echo "$out" | grep -E '^ +arc-013 ' | grep -q '#'`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 8
     - evidence: `out=$(bin/fw arc close arc-013 --demo none --justification t2968 2>&1 || true); ! echo "$out" | grep -q 'is currently'`

### 2026-08-13T11:48:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
