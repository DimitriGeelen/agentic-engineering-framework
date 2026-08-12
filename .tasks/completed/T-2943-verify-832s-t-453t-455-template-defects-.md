---
id: T-2943
name: "Verify 832's T-453/T-455 template defects against our shipped default.md"
description: >
  Verify 832's T-453/T-455 template defects against our shipped default.md

status: work-completed
workflow_type: test
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
created: 2026-08-12T12:31:13Z
last_update: 2026-08-12T12:37:42Z
date_finished: 2026-08-12T12:37:42Z
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

# T-2943: Verify 832's T-453/T-455 template defects against our shipped default.md

## Context

832 reported two defects in **our** shipped `.tasks/templates/default.md` at rail 564 §4,
measured against the template as shipped rather than a fixture. Per L-518 — the habit that
has paid off three times on this rail — a peer's report about their own tree gets *measured*
here, not agreed with.

- **Their T-453:** G-020's real-AC count over `default.md` is 4, of which 2 are the
  placeholders it blocks on and 2 are commented `[REVIEW]`/`[REVIEWER]` examples inside the
  Human guidance block. Delete the two placeholders — the literal instruction in G-020's own
  block message — and the gate passes over **zero** acceptance criteria. Remedy is 56 lines
  up in the same file: the G-067 inception gate strips HTML comments before counting.
- **Their T-455:** `default.md` carries 0 `## Recommendation` sections while `inception.md`
  has one, so a queue guard demanding that section asks for something the build template
  never supplies.

This task only *measures*. Fixes are separate tasks — one bug, one task.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] T-453 reproduced or refuted against our shipped template with the gate's own
      predicate (`check-active-task.sh:756`), not a paraphrase of it
- [x] The decisive question answered: after deleting the placeholders as the block message
      instructs, does G-020 pass over zero ACs? Measured, not reasoned
- [x] T-455 reproduced or refuted: `## Recommendation` counts in `default.md` vs
      `inception.md`, and whether any live guard reads that section on build tasks
- [x] Each confirmed defect filed as its own task with the evidence attached; anything
      refuted is reported back to 832 as refuted, with the measurement

## Findings

**Both confirmed. Neither was a report about 832's tree that happened to rhyme — both are
live here, and one is a governance hole with a self-defeating remedy.**

### T-453 — G-020's own block message tells you how to bypass it (→ T-2944)

`check-active-task.sh:756` counts ACs with
`grep -cE '^\s*-\s*\[[ x]\]'` over the `## Acceptance Criteria` section — **with no HTML
comment stripping**, unlike the G-067 inception gate 56 lines above it at `:700`, which
strips comments before counting IW entries.

Over the shipped `.tasks/templates/default.md`:

    REAL_AC_COUNT (as the gate counts) : 4
    placeholders                       : 2
      - [ ] [First criterion]                                    ← placeholder
      - [ ] [Second criterion]                                   ← placeholder
      - [ ] [REVIEW] Dashboard renders correctly                 ← inside <!-- -->
      - [ ] [REVIEWER] Block message names both bypass mechanisms ← inside <!-- -->
    with G-067-style comment strip     : 2   (only the placeholders)

Two of the four "acceptance criteria" are illustrative examples inside the Human guidance
comment block. So the gate's two conditions —
`HAS_PLACEHOLDER > 0 || REAL_AC_COUNT == 0` — are both cleared by doing exactly what the
block message instructs: *"replace [First criterion] with real ACs"*, performed as a
deletion.

Verified end-to-end with the real hook in a sandbox `PROJECT_ROOT`, not by re-running the
predicate:

    placeholders present, template otherwise untouched   → BLOCKED   (positive control)
    placeholders deleted, nothing else added             → exit 0, WRITE ALLOWED

with the two commented examples standing as the task's entire AC set. **A build task with
zero acceptance criteria passes the build-readiness gate**, and the shortest path to that
state is compliance with the gate's own remediation text.

The positive control matters here: without it, exit 0 is equally consistent with "the
sandbox was never wired up". It blocked when it should block.

### T-455 — the review gate demands a section the build template never ships (→ T-2945)

    default.md   `## Recommendation` sections : 0
    inception.md `## Recommendation` sections : 1

`lib/review.sh:205-211` (T-2421) extends the empty-Recommendation **BLOCK** from inceptions
to partial-complete build-class tasks — `workflow_type ∈ {build, refactor, test,
decommission}` with `human_total > 0 AND human_checked < human_total`. That is precisely
the state every build task reaches when its Agent ACs pass and a `[REVIEW]` remains.

Blast radius, measured over `.tasks/active/`:

    partial-complete build-class tasks          : 294
    of those with NO ## Recommendation section  :  70   (24%)

Every one of those 70 refuses emission from `fw task review` — the command CLAUDE.md
mandates for human handoff (T-679) and forbids substituting raw CLI for. The agent's
recovery is to hand-author a section the template could have supplied, and the sibling
template already does.

### Why both stayed invisible — and it is the same reason twice

Neither defect is in a gate's *logic*; both are in the **denominator the gate reads**.
G-020 counts a template it did not author; the review gate demands a section a different
template supplies. Each is individually correct and the pair is inconsistent — which is
invisible to any test that exercises one side.

Same family as this session's other two findings: T-2941/OBS-235 (the curriculum routes to
a reader vendored nowhere it is read) and OBS-234 (scripts named like live hooks, wired to
nothing). In all four, *the artefact that certifies is not the artefact that runs.*

### Credit and direction

Both were reported by 832 as defects **in their own tree**, restated for the pair. I
measured our equivalents rather than agreeing — L-518, which has now paid off four times
on this rail. The measurement was not a formality: T-453's severity here is higher than
their report implied, because our block message's remediation text is the shortest path
into the hole, and I only found that by running the hook rather than the predicate.

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

# T-453 — the shipped template still exhibits the miscount this task measured.
# This asserts the DEFECT is still present, so it flips to red when T-2944 lands.
test "$(sed -n '/^## Acceptance Criteria/,/^## [^A]/p' .tasks/templates/default.md | sed '$d' | grep -cE '^\s*-\s*\[[ x]\]')" -eq 4

# T-455 — the asymmetry between the two shipped templates.
test "$(grep -c '^## Recommendation' .tasks/templates/default.md)" -eq 0
test "$(grep -c '^## Recommendation' .tasks/templates/inception.md)" -eq 1

# Both defects are filed as their own tasks, not left as prose in a task that archives.
ls .tasks/active/T-2944-*.md >/dev/null 2>&1 && ls .tasks/active/T-2945-*.md >/dev/null 2>&1

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

### 2026-08-12T12:31:13Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2943-verify-832s-t-453t-455-template-defects-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-195bc59a
- **Timestamp:** 2026-08-12T12:37:43Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 75
     - evidence: `ls .tasks/active/T-2944-*.md >/dev/null 2>&1 && ls .tasks/active/T-2945-*.md >/dev/null 2>&1`

### 2026-08-12T12:37:42Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
