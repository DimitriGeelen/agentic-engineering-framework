---
id: T-2954
name: "check-human-ac-tick is direction-symmetric and comment-blind (832 OBS-037)"
description: >
  T-1731's guard flags any Human-AC checkbox state change (detect_toggle: 'if a !=
  b'), so un-ticking [x]->[ ] — the direction that RESTORES the invariant — needs
  the same Tier-2 FW_ALLOW_HUMAN_AC_TICK override as ticking. Second leg: get_checkbox_states
  regexes the raw '### Human' section with no comment stripping, so the template's
  own example '- [ ] [REVIEW] Dashboard renders correctly' inside an HTML comment
  counts as a Human AC. review.sh was made comment-aware in T-2948; this guard was
  not — a parity gap between two consumers of the same section. Handed back by 832
  as OBS-037 under gap-homing; reproduced here from source.

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
created: 2026-08-12T20:34:16Z
last_update: 2026-08-12T21:00:59Z
date_finished: 2026-08-12T21:00:59Z
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
bvp_scores_proposed:
  - ts: '2026-08-12T20:42:33Z'
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
cost_estimate_proposed:
  - ts: '2026-08-12T20:45:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2954: check-human-ac-tick is direction-symmetric and comment-blind (832 OBS-037)

## Context

Handed here by 832 as their OBS-037 under gap-homing (rail 579 §5(ii)) — their
report, our defect, our fix. Reproduced from source before being accepted.

### The harm, demonstrated rather than reasoned

**Comment-blindness is not a counting bug — it fabricates a toggle record.**
`detect_toggle` zips old and new checkbox lists *positionally*. Phantom boxes
from the commented template examples sit at indices 0-1, so any edit that
changes the comment block shifts every real AC's index and the zip misaligns.
Run against the real functions:

    old boxes: [' ', ' ', 'x', ' ']      # 2 commented examples + 2 real ACs
    new boxes: ['x', ' ']                # agent deleted the guidance comment
    detect_toggle -> toggles=[(0, ' ', 'x')]

The agent deleted a **comment** and the guard reported it as ticking a Human AC:
edit blocked, and under `FW_ALLOW_HUMAN_AC_TICK=1` a tick that never happened is
written into the Tier-2 bypass log. Corpus measurement before any change:
**1103 of 2942 task files carry 1-2 phantom boxes** (375 with one, 728 with two).

**Direction symmetry** was as 832 described — `if a != b`, no direction test
anywhere in the file. An agent that wrongly ticked a Human AC needed the same
Tier-2 override to restore the invariant as it had needed to violate it.

### Why it survived

`tests/unit/human_ac_tick_guard.bats` leg 2 asserted *"Agent unticks Human AC
([x] → [ ]) — also blocks (any toggle)"*. The symmetry was **pinned as intent**,
so nothing could drift into flagging it. That leg is now rewritten to assert the
corrected contract, with the reason stated inline.

### What shipped

- `lib/comment_strip.py` — the structural rule, in one place, with the
  three-disposition direction rule (discarded / counted / executed) and why it is
  not `re.sub(..., DOTALL)`. Usable as a stdin filter so shell callers get the
  same bytes.
- `check-human-ac-tick.py` imports it; `lib/verification-port.sh` calls it as a
  filter and **no longer restates the rule in a comment** — the previous comment
  asserted parity with `update-task.sh`'s copy and itself recorded that the claim
  had already been found false once (T-2949). Prose parity between two copies is
  not parity; a shared import is.
- `blocking_toggles()` — only `[ ]` → `[x]` blocks. Un-ticks are surfaced and
  still logged, so the audit trail keeps them; what changes is that correcting
  your own mistake no longer needs a bypass.

Refactor verified behaviour-preserving: 600 task files through the old inline
extractor vs the shared module, **0 byte-differences**.

### Left deliberately (one bug, one task)

Two non-Python sites still hold their own semantics, both registered: `audit.sh`
(OBS-238 / T-2950, drops any line *containing* `<!--`) and `lib/review.sh`
(**OBS-239**, opens a span on `<!--` anywhere rather than at line start). OBS-239's
blast radius was measured, not assumed — the entry's first draft asserted 0 live
instances and the command found **1** (T-2521 carries a ticked Human AC with a
trailing comment, which review.sh drops). Corrected before filing.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `detect_toggle` distinguishes direction: `[ ]` → `[x]` still BLOCKS under `$CLAUDECODE=1`; `[x]` → `[ ]` is ALLOWED without any override, because un-ticking cannot fabricate human approval
- [x] `get_checkbox_states` no longer counts checkbox-shaped lines inside HTML comments, using the same structural rule as `lib/verification-port.sh:extract_verification_block` (`<!--` opens a comment only as the first non-blank token on its line)
- [x] The comment-stripping logic lives in ONE Python module imported by both this guard and `lib/verification-port.sh:extract_verification_block` — parity by construction for the two Python-reachable sites, not a fourth copy asserting parity in a comment (T-2949 shape)
- [x] The two remaining non-Python variants are registered rather than silently left: `audit.sh` (already OBS-238/T-2950) and `lib/review.sh`, whose rule is `<!--` ANYWHERE on the line rather than opening the line — a distinct, conservatively-wrong divergence that under-counts a real AC carrying a trailing comment
- [x] Blast radius measured before the change: every task file's `### Human` section counted old-way vs new-way, with the diff enumerated and each difference shown to be a repair
- [x] Bats legs cover both directions and the comment case, and include a non-vacuity leg that runs the OLD expression inline and asserts it mis-counts the fixtures
- [x] The task template's own `- [ ] [REVIEW] Dashboard renders correctly` example line inside the `### Human` comment block is confirmed no longer counted

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

# Both behaviours, driven through the REAL hook (not the predicate) — L-533.
bin/fw test unit -- tests/unit/t2954_human_ac_tick_comment_aware.bats > /tmp/T-2954-new.log 2>&1
! grep -qE "^not ok" /tmp/T-2954-new.log
bin/fw test unit -- tests/unit/human_ac_tick_guard.bats > /tmp/T-2954-guard.log 2>&1
! grep -qE "^not ok" /tmp/T-2954-guard.log
# Siblings that share the comment rule must not regress (T-2921 P-011, T-2948 review.sh).
bin/fw test unit -- tests/unit/t2921_verification_comment_strip.bats tests/unit/t2948_review_human_ac_comment_aware.bats > /tmp/T-2954-sib.log 2>&1
! grep -qE "^not ok" /tmp/T-2954-sib.log
# Parity by construction: one module, imported by both Python-reachable sites.
test -f lib/comment_strip.py
grep -q 'from comment_strip import strip_html_comment_lines' agents/context/check-human-ac-tick.py
grep -q 'lib/comment_strip.py' lib/verification-port.sh
# ...and neither site keeps a copy of the rule.
! grep -q "in_comment" lib/verification-port.sh
! grep -qE "re\.sub\(r.<!--" agents/context/check-human-ac-tick.py
# Direction is asymmetric in code, not just in tests.
grep -q 't\[2\] in ("x", "X")' agents/context/check-human-ac-tick.py
# The two non-Python variants are registered, not silently left.
grep -q 'id: OBS-238' .context/concerns.yaml
grep -q 'id: OBS-239' .context/concerns.yaml
python3 -c "import yaml; yaml.safe_load(open('.context/concerns.yaml'))"
# The shipped template — the real-world instance — counts zero Human ACs.
python3 -c "import importlib.util as u; s=u.spec_from_file_location('g','agents/context/check-human-ac-tick.py'); m=u.module_from_spec(s); s.loader.exec_module(m); h=m.extract_human_section(open('.tasks/templates/default.md').read()); assert m.get_checkbox_states(h)==[], m.get_checkbox_states(h)"
# The shared refactor is behaviour-preserving on the P-011 extractor (600-file sample, 0 diffs at fix time).
bash -c 'source lib/verification-port.sh; extract_verification_block .tasks/completed/T-2921-p-011-verification-extractor-strips-html.md | grep -q extract_verification_block'

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

**Symptom.** Two, in one guard. (a) An agent that wrongly ticked a `### Human` AC
needed `FW_ALLOW_HUMAN_AC_TICK=1` — a logged Tier-2 bypass — to un-tick it again.
(b) Editing the `### Human` HTML comment block, touching no real AC, was reported
as a Human-AC tick and blocked.

**Root cause.** (a) `detect_toggle` is `if a != b`. The direction was never part
of the model; the guard was written as "detect any change" and the CLAUDE.md rule
it enforces ("only the human may verify and check these boxes") is directional.
(b) `get_checkbox_states` regexed the raw section, so commented example ACs were
counted, and because `detect_toggle` zips *positionally*, phantoms at indices 0-1
shifted every real AC's index — a comment edit misaligned the zip and produced a
spurious `(0, ' ', 'x')`.

**Why structurally allowed.** Three separate reasons, and the third is the one
worth keeping:

1. (a) was **pinned by a test**. `human_ac_tick_guard.bats` leg 2 asserted the
   un-tick blocks. Once a defect is encoded as intent, no amount of scanning
   finds it — the suite defends it.
2. (b) is the fourth site of the comment-boundary class and the framework had
   *three* different semantics for one rule at the time of the fix (structural in
   `verification-port.sh`, contains-anywhere in `review.sh`, drop-any-containing
   in `audit.sh`, none here). Each was fixed where it was found.
3. **T-2948 created this gap and I did not sweep for siblings.** Two rounds
   before this, `review.sh`'s counter was made comment-aware and the change was
   sent to 832 as a lesson about exactly this class. Making one consumer of the
   `### Human` section comment-aware and leaving the other means two consumers
   now disagree about what a Human AC *is*. That is the T-2949 shape — one
   change, several artefacts, parity assumed — recurring inside the fix for it.

**Prevention.** The rule now has one implementation (`lib/comment_strip.py`)
imported by both Python-reachable consumers, so their parity is by construction
rather than by three matching copies. `verification-port.sh` no longer restates
the rule in a comment — the comment it replaced asserted parity with another copy
and recorded that the claim had already been found false once, which is the
strongest available argument that prose parity is not parity. The two shell sites
that could not be collapsed are registered (OBS-238/T-2950, OBS-239) rather than
left to be rediscovered a fifth time. Non-vacuity leg 4 runs the pre-fix
expression inline and asserts it still mis-counts the fixture, so the suite
cannot go green while asserting nothing.

**Not prevented, and named rather than implied.** Nothing structurally stops the
next comment-boundary site from being written with a fourth semantics. The rule
is now importable and documented, which lowers the cost of doing it right; it does
not raise the cost of doing it wrong. A lint that flags any new `<!--` handling
outside `comment_strip.py` would close that, and is not built here.

**Method note.** OBS-239's blast-radius figure was written as "0 live instances"
before the command was run, and the command returned 1 — a ticked Human AC in
T-2521 that `review.sh` drops. Same near-miss recorded in T-2951's RCA (writing a
conclusion into the register before running the command), caught this time because
measuring before filing is now the habit rather than the correction.

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

### 2026-08-12T20:34:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2954-check-human-ac-tick-is-direction-symmetr.md
- **Context:** Initial task creation

### 2026-08-12T20:42:33Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c5c8cc88
- **Timestamp:** 2026-08-12T21:01:19Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 25
     - evidence: `bash -c 'source lib/verification-port.sh; extract_verification_block .tasks/completed/T-2921-p-011-verification-extractor-strips-html.md | grep -q extract_verification_block'`

### 2026-08-12T21:00:59Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
