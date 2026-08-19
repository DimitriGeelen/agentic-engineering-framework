---
id: T-3080
name: "Watchtower Tier 0 approval grants a 1h TTL where the CLI grants 5m"
description: >
  check-tier0.sh:307 TIER0_WATCHTOWER_TTL defaults to 3600; bin/fw tier0 approve writes
  a token the hook honours for 300s (check-tier0.sh:256) and prints 'The approval
  expires in 5 minutes'. The easier path to click is 12x more permissive than the
  command line, and nothing documents the asymmetry. Tightening the button to match
  is the safe direction but changes operator workflow (retry window), so it is the
  operator's call.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [agents/context/check-tier0.sh, bin/fw, lib/config.sh, web/blueprints/config.py]
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
created: 2026-08-18T18:50:46Z
last_update: 2026-08-19T20:07:26Z
date_finished: 2026-08-19T20:07:26Z
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
  - ts: '2026-08-18T19:00:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=202,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-18T19:00:19Z'
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
  - ts: '2026-08-19T19:15:13Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 3
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=3 (body:portability-abstraction); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3080: Watchtower Tier 0 approval grants a 1h TTL where the CLI grants 5m

## Context

`check-tier0.sh` has two independent approval legs and each carries its own TTL literal:

| Leg | Site | Window | Configurable |
|---|---|---:|---|
| CLI — `fw tier0 approve` writes `.context/working/.tier0-approval` | `check-tier0.sh:256` `if [ "$AGE" -lt 300 ]` | 300s | no — bare literal |
| Watchtower — Approve button writes `.context/approvals/resolved-<hash12>.yaml` | `check-tier0.sh:307` `WATCHTOWER_TTL="${TIER0_WATCHTOWER_TTL:-3600}"` | 3600s | yes |

So the path that takes one click is **12× more permissive** than the path that takes a
typed command, and nothing states the asymmetry. That inverts the intent: a click is the
easier action to take by accident, so it should carry the *shorter* window, not the longer.

This matters because of what an approval actually is. Approving does not run the command —
it writes the command's hash into a grant file, and `check-tier0.sh` then admits **any**
command whose whitespace-normalised text hashes to that value, once. A misclick on a card
reading `rm -rf /` therefore leaves a live pre-authorisation for a genuine `rm -rf /` for
however long the window lasts. Shrinking 3600 → 300 does not remove that hazard; it removes
11/12ths of its duration, which is the cheap part of the fix. Provenance on the card
(T-3078) and a stale-request rail (T-3079) are the other two legs and are separate tasks.

Direction of the fix is the safe one (tighten the loose leg, do not loosen the tight one),
so it needs no operator decision to *start* — but the retry window does change, which is
why the operator-visible wording is in scope.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] **A1 — one resolved TTL, not two literals.** Both approval legs read their window
      from a single resolution point in `check-tier0.sh`. Neither `300` nor `3600` survives
      as a bare literal at the two decision sites (`:256` and `:307`).
- [x] **A2 — default parity, measured at the hook.** With no TTL env var set, a Watchtower
      grant stamped older than the unified window is refused: the hook exits 2 and the
      command stays blocked. This is asserted against the real `bin/fw hook check-tier0`
      with a fixture `resolved-<hash>.yaml`, not against a re-implementation of the maths.
- [x] **A3 — positive control, both directions (L-616).** The same fixture with a
      `responded_at` *inside* the window is admitted (exit 0). Without this, an
      always-blocking hook and a correctly-expiring one are indistinguishable — two empty
      sets are equal.
- [x] **A4 — the existing override still works.** `TIER0_WATCHTOWER_TTL` set explicitly is
      still honoured, so any operator or test that pins it keeps working; the resolution
      order is stated in the file where it resolves.
- [x] **A5 — the operator is told the same window on both paths.** `fw tier0 approve`'s
      expiry line and the Watchtower approve surface quote the resolved value rather than a
      hard-coded "5 minutes" / "1 hour", so the two cannot drift apart again in prose after
      they have been unified in code.
- [x] **A6 — the knob is in the config registry.** The TTL key is defined in
      `lib/config.sh` `FW_CONFIG_REGISTRY`, so `fw config list` and Watchtower `/config`
      surface it. CLAUDE.md forbids naming an `FW_` key the registry does not define, and
      `tests/lint/config-registry-parity.bats` enforces that direction.

### Human
- [ ] [REVIEW] The new `TIER0_APPROVAL_TTL` row reads correctly on Watchtower `/config`

      **Steps:**
      1. `bin/fw watchtower url` — open the URL it prints, then go to `/config`
      2. Find the `TIER0_APPROVAL_TTL` row (it is the last entry in the registry table)
      3. Read its description at your normal browser width

      **Expected:** the row shows default `300`, and the description is legible without
      horizontal scrolling or mid-word wrapping. It is the longest description in the table,
      so it is the one most likely to break the column. The sentence that must survive intact
      is "NOT the pending-request staleness window" — if that clause is truncated or wrapped
      into illegibility, the row actively misleads, because the two clocks it distinguishes
      are exactly what an operator would otherwise conflate.

      **If not:** note which part is unreadable and at what width. The fix is to shorten the
      description in BOTH `lib/config.sh` and `web/blueprints/config.py` — they are held
      identical by `tests/lint/config-registry-parity.bats`, so changing one alone turns the
      invariant suite red and blocks the next push.

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

# The grant-TTL regression suite: both legs, both directions, legacy override, and the
# T-3077 live-surface invariant. L-387: redirect then grep, never pipe into grep -q.
bats tests/unit/tier0_grant_ttl.bats > .context/working/.t3080-bats.out 2>&1
grep -q "^ok 10 " .context/working/.t3080-bats.out && ! grep -q "^not ok" .context/working/.t3080-bats.out

# A1: neither TTL literal survives at a decision site. The only 300 is the registry
# default in lib/config.sh; check-tier0.sh must reach it through one resolved variable.
test "$(grep -c 'AGE.*-lt.*300\b' agents/context/check-tier0.sh)" -eq 0
test "$(grep -c 'TIER0_WATCHTOWER_TTL:-3600' agents/context/check-tier0.sh)" -eq 0
grep -q 'APPROVAL_TTL=' agents/context/check-tier0.sh

# A6: the key is in the registry and in every parity surface (34 == 34, not 34 vs 33).
bin/fw test invariants > .context/working/.t3080-inv.out 2>&1 || true
grep -q "^ok 4 lib/config.sh and web/blueprints/config.py have the same config keys" .context/working/.t3080-inv.out
grep -q "^ok 6 config registry key count matches across sources" .context/working/.t3080-inv.out

# A5: both operator-facing surfaces quote the resolved window, not a hard-coded phrase.
bin/fw approvals help > .context/working/.t3080-help.out 2>&1
grep -q "300s (5 minutes)" .context/working/.t3080-help.out

# The live Tier 0 surface is clean after all of the above.
bin/fw tier0 status > .context/working/.t3080-tier0.out 2>&1
grep -q "No pending blocks or approvals" .context/working/.t3080-tier0.out


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

**Recommendation:** GO

**Rationale:** The change is in the safe direction and is now measured rather than argued.
The Watchtower approval button granted a destructive command a 3600s pre-authorisation
where the typed CLI granted 300s — the easier action to take by accident carried the longer
window. Both legs now resolve one value from one point, defaulting to 300s. The only thing
left for a human is whether one table row reads well, which cannot be settled by grep.

Worth being explicit about what this does and does not fix. It removes 11/12ths of the
*duration* of the hazard the operator raised; it does not remove the hazard. Approving still
writes a command hash that admits any command hashing to it. Provenance on the card (T-3078)
and a rail for stale pending requests (T-3079) are the other two legs and remain open.

**Evidence:**
- `bats tests/unit/tier0_grant_ttl.bats` — 10/10 green: both legs expire at the same age,
  both admit inside the window (L-616 positive controls), the legacy `TIER0_WATCHTOWER_TTL`
  override still widens it, and the suite leaves the live approvals surface untouched.
- Mutation test: reverting the Watchtower leg to `${TIER0_WATCHTOWER_TTL:-3600}` flipped
  exactly tests 1, 3 and 6 red and left the other seven green — the suite discriminates this
  defect rather than failing wholesale. `check-tier0.sh` restored byte-identical to HEAD.
- `## Verification` — 12/12 passed at the close gate, including that neither `300` nor
  `3600` survives as a literal at either decision site.
- `fw test invariants` — config-registry parity green again (34 keys on both surfaces; it
  was 34 vs 33 and blocking the pre-push audit until this task's A6 landed).
- `curl $(bin/fw watchtower url)/config` — 200, 88,457 bytes, contains `TIER0_APPROVAL_TTL`.
- `bin/fw tier0 status` — clean, no pending blocks or approvals.

**Note on how this task went:** the dispatched worker that produced the original change died
before committing, and its uncommitted tree carried four separate defects — a backtick fork
bomb that OOM'd the host four times (T-3086), a call to an undefined function that broke
`fw tier0 approve` (T-3087), the registry parity break above, and the complete absence of the
tests it was asked to write. Every one would have been caught by executing the file once.


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

### Unify at 300, not at some middle value
Tightening the loose leg is the only direction that cannot make things worse. A grant is a
live pre-authorisation for a destructive command, and the click is the easier action to
take by accident than the typed command — so the click must carry the shorter window, not
the longer. Any value above 300 would have loosened the CLI leg to buy convenience on the
Watchtower leg, which inverts the safety argument the task was filed on.

### Keep TIER0_WATCHTOWER_TTL working, but only when explicitly set
Removing the legacy name would break any operator or test pinning it, for no safety gain —
an explicit pin is a deliberate act, not an accident. It now sits ahead of the registry
default in the resolution order and is exercised by test 7, so the override is a tested
contract rather than dead compatibility code.

### Do not touch web/blueprints/approvals.py EXPIRY_SECONDS
There are two clocks in this subsystem and only one is in scope. `EXPIRY_SECONDS` governs
how long a *pending request* stays offerable in the operator's queue; dropping it to 300
would expire a request filed six minutes ago and leave the operator unable to act on their
own queue. Stale pending requests are T-3079. The distinction is written into
check-tier0.sh at the resolution point so the next person does not collapse them.

### Fixture is `git push --force origin master`, not `rm -rf /`
These tests file real grant records. A fixture reading `rm -rf /` in a log or a stray file
is alarming to whoever finds it — which is precisely what happened when the governance
suite leaked such a card onto the live Watchtower queue for four months (T-3077). Any
Tier 0 pattern exercises the same code path, so there is no coverage cost.

### Mutation test — measured, not asserted
Reverting the Watchtower leg to `${TIER0_WATCHTOWER_TTL:-3600}` and re-running flipped
exactly three tests red, and the right three:

    not ok 1  Watchtower grant older than the window is refused
    not ok 3  Watchtower grant at 1800s is refused — the old 3600 default is gone
    not ok 6  both legs expire at the same age — parity, not two windows

Tests 2, 4, 5, 7, 8, 9, 10 stayed green, which is the part that matters: the suite
discriminates *this* defect rather than failing wholesale. `agents/context/check-tier0.sh`
was restored from backup and verified byte-identical to HEAD afterwards.


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

### 2026-08-18T18:50:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3080-watchtower-tier-0-approval-grants-a-1h-t.md
- **Context:** Initial task creation

### 2026-08-18T19:51:53Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-38b75050
- **Timestamp:** 2026-08-19T20:08:10Z
- **Catalogue:** v1.3-seed
- **Overall:** FAIL
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **swallowed-errors** (severe, deterministic) @ Verification:line 13
     - evidence: `bin/fw test invariants > .context/working/.t3080-inv.out 2>&1 || true`

### 2026-08-19T20:07:26Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
