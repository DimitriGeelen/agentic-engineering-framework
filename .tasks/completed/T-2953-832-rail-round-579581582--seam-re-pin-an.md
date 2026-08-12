---
id: T-2953
name: "832 rail round 579/581/582 — seam re-pin answers + .git-sweep exposure measure"
description: >
  832 rail round 579/581/582 — seam re-pin answers + .git-sweep exposure measure

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
created: 2026-08-12T20:32:40Z
last_update: 2026-08-12T20:41:30Z
date_finished: 2026-08-12T20:41:30Z
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

# T-2953: 832 rail round 579/581/582 — seam re-pin answers + .git-sweep exposure measure

## Context

### What this round established

Rail 579/581/582/583 in, 584 out (`docs/reports/832-rail/584-aef-to-832.md`).

**Seam answer — T-101 costs this side nothing.** 832 asked four questions about what a
coordinated re-pin of their BPMN corpus costs here. Measured rather than estimated:

- `source_bpmn_sha` is **not** a pin of 832's bytes here at all — it is a provenance field
  `tools/bpmn_promote.py` writes into our own corpus meta, keyed `(uid, source_bpmn_sha)`
  per their IW-2 contract. T-423's description asserts a coordination cost via a mechanism
  that does not exist on this side.
- What we actually pin: **six** artifacts by byte-digest — four constants in
  `tests/unit/test_bpmn_to_tasks.py` (`CANONICAL_SHA256`, `RESUME_STATUS_SHA256`,
  `SHA_832_TYPED`, `SHA_832_BOUNDARY`) plus two sidecars under `tests/fixtures/832/`.
- All six are **static vendored bytes**; no 832 exporter is present, so there is no
  regeneration path a change on their side could break.
- We hold **no** copy of `examples/aef-processes/rendered/` and no code resolves any
  832-side path — so T-101, which moves bytes on exactly those 24 maps, has zero blast
  radius here. Told them to ship it rather than hold it for us.

**832's `.git`-contamination hazard, measured here: exposure 0 over 40 recursive legs.**
The mechanism reproduces (`grep -c T-2921 .git/logs/HEAD` → 2 — commit messages are text,
so a leg counting its own subject counts the commit that fixes it). 38 of 40 legs are
rooted at a subdirectory, so `.git/` is a sibling not a descendant. Of the 2 rooted at `.`,
one excludes `.git` **by design**, one by the **accident** of an `--include=*.bpmn` filter.
Half the clean result is luck, and the reply says so.

**Generalisation the round produced** (needed 832's §4(b) — could not have been reached
from the `.git/` half alone): the hazard is not the VCS directory, it is *any recursive
root containing an artefact the act of making the change writes*. Three carriers —
`.git/` (the commit), `.tasks/` (the task file), and the leg's own explanatory comment.
T-1175's leg already excludes itself by name, so this was independently discovered three
times across two trees and generalised zero times. One rule covers all three: **a recursive
verification leg must exclude the artefacts that the act of verifying creates.**

**Both handed-back gaps reproduce and are filed** (one bug = one task): T-2954
(`check-human-ac-tick` direction-symmetric + comment-blind) and T-2955 (`fw arc tag`
writes the deprecated `arc:<slug>` form). T-2954's second leg is worse than 832 reported
— see RCA.

**Reciprocal check that found nothing, reported as nothing.** 832's closing class
("frontmatter is a cache with no invalidation") checked here: 0 drift instances, but over
a denominator of **3 of 337** active tasks. The zero asserts almost nothing and the reply
states the denominator rather than the result, because the result alone reads as a clean
bill of health for a hazard this tree barely has a surface for.

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] The complete set of 832-authored artifacts pinned by byte-digest on this side is enumerated with each pin's constant/sidecar and guarded path, measured not guessed
- [x] Whether those pins are held as static vendored bytes or regenerated from 832's exporter is stated with evidence (no 832 exporter present ⇒ static)
- [x] This tree's exposure to 832's `.git`-contamination hazard (recursive P-011 leg rooted at/above `.git/`) is measured over all task Verification blocks, with the count and the reason for each surviving root
- [x] 832's two handed-back defects are reproduced here from source before being accepted, each with the file:line that shows it
- [x] Each reproduced defect is filed as its own task/observation (one bug = one task), not folded into this one
- [x] Rail reply persisted under `docs/reports/832-rail/` so it outlives the rail retention window

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

# Reply persisted, and it names all six digest-pinned 832 artifacts (Q1 answer).
test -f docs/reports/832-rail/584-aef-to-832.md
test "$(grep -cE 'CANONICAL_SHA256|RESUME_STATUS_SHA256|SHA_832_TYPED|SHA_832_BOUNDARY|pair-draft-3\.sha256|s4-exemplar\.sha256' docs/reports/832-rail/584-aef-to-832.md)" -ge 6
# The six pins exist in source, so the table is not a claim about a tree that moved.
test "$(grep -cE '^(CANONICAL_SHA256|RESUME_STATUS_SHA256|SHA_832_TYPED|SHA_832_BOUNDARY) =' tests/unit/test_bpmn_to_tasks.py)" -eq 4
test -f tests/fixtures/832/pair-draft-3.sha256 && test -f tests/fixtures/832/s4-exemplar.sha256
# Q2: static, not regenerated — no 832 exporter is vendored here.
! find . -path ./.git -prune -o -name '*.py' -print 2>/dev/null | xargs grep -ln 'aef-processes/rendered' 2>/dev/null | grep -q .
# Both handed-back defects still present in source (the filed tasks are not born stale).
grep -q 'if a != b' agents/context/check-human-ac-tick.py
grep -q 'arc_tag="arc:' lib/arc.sh
# T-2954 leg 2: the guard reads the raw ### Human section with no comment stripping.
# Range end is the NEXT def, not /^def /, which would match the start line and collapse
# the range to one line — an expression producing plausible output while asserting nothing.
fn=$(awk '/^def get_checkbox_states/,/^def detect_toggle/' agents/context/check-human-ac-tick.py); test "$(printf '%s' "$fn" | wc -l)" -ge 3 && printf '%s' "$fn" | grep -q 're.findall' && ! printf '%s' "$fn" | grep -q '<!--'
# Each reproduced defect filed as its own task (one bug = one task).
ls .tasks/active/T-2954-*.md >/dev/null && ls .tasks/active/T-2955-*.md >/dev/null
# NON-VACUITY for the .git hazard claim: .git IS searchable here, so exposure 0 is a
# measurement and not an artefact of .git being absent or unreadable.
test "$(/usr/bin/grep -c 'T-2921' .git/logs/HEAD)" -ge 1
# ...and the two repo-root legs draw nothing from it (the measured exposure).
test "$(/usr/bin/grep -rho 'aef:uid value=' --include=*.bpmn .git 2>/dev/null | wc -l)" -eq 0

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

**Symptom.** 832 reported that `check-human-ac-tick` counts `- [ ] [REVIEW] …` example
lines living inside the `### Human` HTML comment block as real Human ACs. Confirmed here:
the task template ships exactly such a line, so every task created from it carries a
checkbox this guard counts and no other consumer reads.

**Root cause.** `get_checkbox_states()` regexes the raw `### Human` section
(`re.findall(r"^\s*-\s*\[([x ])\]", …)`) with no comment handling. `review.sh`'s
Human-AC counter was made comment-aware in T-2948. Two consumers of the same section now
disagree about what a Human AC is.

**Why structurally allowed.** T-2948 fixed the counter it was pointed at and never swept
for siblings reading the same section. That is precisely the T-2949 shape — one change,
several artefacts, parity assumed rather than constructed — recurring *inside the fix for
it*, and two rounds after it was sent to 832 as a lesson. The direction rule from
T-2921/T-2948 had two dispositions (span **discarded as prose** → strip; span **executed**
→ do not) and no entry for a third that was already live: span **counted**. Counted content
needs stripping for the same reason executed content does — the consumer acts on it.

**Prevention.** Belongs in T-2954 (the fix), not here. The generalised rule this round
produced — *strip iff the consumer does anything with the surviving text other than show
it to a human* — is the form that would have caught this at T-2948 authoring time, and is
stated in rail 584 §3 so both trees hold it.

**Secondary, caught in-flight rather than shipped.** A verification leg drafted here used
`awk '/^def get_checkbox_states/,/^def /'`. The start line also matches the end pattern, so
the range collapsed to a single line and the leg asserted nothing about the function body.
It went red rather than green only because it was written as a conjunction whose other
clause was substantive — the same class this whole thread has been trading, hit while
writing the message describing it. Fixed by ending the range at the *next* named def and
adding a `wc -l` floor so a collapsed range fails loudly.

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

### 2026-08-12T20:32:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2953-832-rail-round-579581582--seam-re-pin-an.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6e38743a
- **Timestamp:** 2026-08-12T20:41:32Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 17
     - evidence: `ls .tasks/active/T-2954-*.md >/dev/null && ls .tasks/active/T-2955-*.md >/dev/null`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 8
     - evidence: `! find . -path ./.git -prune -o -name '*.py' -print 2>/dev/null | xargs grep -ln 'aef-processes/rendered' 2>/dev/null | grep -q .`
  3. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 15
     - evidence: `fn=$(awk '/^def get_checkbox_states/,/^def detect_toggle/' agents/context/check-human-ac-tick.py); test "$(printf '%s' "$fn" | wc -l)" -ge 3 && printf '%s' "$fn" | grep -q 're.findall' && ! printf '%s`

### 2026-08-12T20:41:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
