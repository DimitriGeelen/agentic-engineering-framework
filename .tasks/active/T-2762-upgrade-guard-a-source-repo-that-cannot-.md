---
id: T-2762
name: "upgrade guard: a source repo that cannot resolve the consumer's sha is not
  a valid upgrade source"
description: >
  upgrade guard: a source repo that cannot resolve the consumer's sha is not a valid
  upgrade source

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
created: 2026-08-03T11:43:03Z
last_update: 2026-08-03T11:47:26Z
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
  - ts: '2026-08-03T11:45:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-03T11:45:11Z'
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

# T-2762: upgrade guard: a source repo that cannot resolve the consumer's sha is not a valid upgrade source

## Context

Build slice authorising from **T-2761** (GO, 2026-08-03). T-2761 framed the guard as
"compare the running `FRAMEWORK_ROOT` against the target's `.agentic-framework`, refuse
on mismatch", and explicitly left the mechanism open: *"The open question is
refuse-vs-warn-vs-reroute, not whether a guard is warranted."*

**The mechanism moved, and the reason is measured.** A path comparison is both wrong and
redundant here:

- **Wrong:** `FRAMEWORK_ROOT != target/.agentic-framework` is the *sanctioned* upgrade
  path — it is remediation option 3 in the existing T-1542 block message
  (`lib/upgrade.sh:775-776`, "Run from an upstream framework checkout with explicit
  target"). Refusing on mismatch would refuse every correct upgrade.
- **Redundant:** the equal case (source == the consumer's own vendored copy) is already
  handled by T-1542/T-1634 at `lib/upgrade.sh:707-712`, and genuine ahead/diverged is
  already refused by the T-1912 precheck at `lib/upgrade.sh:936-954`.

The actual hole is one level down, in how the relation is *computed*.
`fw_version_relation` resolves the consumer's commit **inside `$froot` — the framework
under suspicion** (`lib/version-relation.sh:86,89`). A stale or foreign source is
precisely the repo that does not contain the consumer's sha or its version tag, so
`cref` comes back empty, the relation is `undecidable`, and
`FW_UNDECIDABLE_VERSION_PROCEED` (default `1`) proceeds with a WARN.

Measured, this session, with 010-termlink's own numbers:

    consumer 1.6.295 / framework 1.6.121 / sha not in source repo
      relation:      undecidable
      should_refuse: NO — PROCEEDS

That is the downgrade. The consumer was genuinely ahead; the stale source simply could
not see far enough to know it, and "cannot see" was treated as "no reason to stop".

**The correction:** a recorded sha that the source cannot resolve is not *absent*
evidence, it is *positive* evidence — a repo that does not contain the consumer's
history cannot be its upgrade source. Today that case is indistinguishable from a legacy
pin with no sha at all, and both fall into the proceed bucket. Splitting them is the fix.

Second, smaller defect in the same path: when a sha **was** recorded but did not resolve,
the reason string still reads `no version_sha recorded and no tag v… in framework repo`.
That misattributes the cause and sends the reader to add a field that is already there.

## Acceptance Criteria

### Agent
- [x] `fw_version_relation` distinguishes *sha recorded but unresolvable in this source*
      from *no sha recorded at all* — two different relations, not one `undecidable`
- [x] The unresolvable-sha case refuses by default (it is evidence about the source, not
      an absence of evidence); the legacy no-sha case keeps today's
      `FW_UNDECIDABLE_VERSION_PROCEED` behaviour so legacy consumers are not bricked
- [x] The refusal is bypassable via a documented env var, logged Tier-2, mirroring the
      `--force-downgrade` contract (T-1890 producer/consumer parity: env var, because the
      gate must also be reachable from wrapper/non-flag invocations)
- [x] The reason string for the unresolvable-sha case states the real cause — that the
      source repo does not contain the consumer's commit — and never claims no sha was
      recorded when one was
- [x] `lib/upgrade.sh`'s T-1912 precheck refuses on the new relation without needing its
      own copy of the rule (it asks `fw_version_relation_should_refuse`, unchanged)
- [x] Regression test reproduces the field case end-to-end: consumer pinned ahead with a
      sha absent from the source repo → `fw upgrade` refuses and the pin is unchanged
- [x] Mutation check recorded in the task: reverting the guard turns the new tests red
- [x] Existing `t2755_upgrade_pin_line_direction.bats` and
      `t2759_upgrade_target_dir_shadowing.bats` stay green (the renderer must render the
      new relation, not fall through to "behind")

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

bats tests/unit/t2762_upgrade_foreign_source_sha.bats
bats tests/unit/t2755_upgrade_pin_line_direction.bats
bats tests/unit/t2759_upgrade_target_dir_shadowing.bats
bats tests/unit/lib_upgrade.bats
bash -n lib/version-relation.sh && bash -n lib/upgrade.sh && bash -n bin/fw
# Behavioural, not textual: a recorded-but-unresolvable sha must yield foreign-source AND refuse.
bash -c 'source lib/version-relation.sh; fw_version_relation 1.6.295 1.6.121 0000000000000000000000000000000000000000 . >/dev/null; [ "$FW_VERSION_RELATION" = foreign-source ] && fw_version_relation_should_refuse "$FW_VERSION_RELATION"'
# A legacy no-sha pin must still proceed — refusing here would strand every pre-T-2713 consumer.
bash -c 'source lib/version-relation.sh; fw_version_relation 1.6.295 1.6.121 "" . >/dev/null; [ "$FW_VERSION_RELATION" = undecidable ] && ! fw_version_relation_should_refuse "$FW_VERSION_RELATION"'
# The bypass must actually work at the predicate the guard consults (L-399 parity).
bash -c 'source lib/version-relation.sh; fw_version_relation 1.6.295 1.6.121 0000000000000000000000000000000000000000 . >/dev/null; FW_ALLOW_FOREIGN_SOURCE=1; ! fw_version_relation_should_refuse "$FW_VERSION_RELATION"'
# doctor must not tell the operator to run the command that is about to refuse.
grep -q 'foreign-source)' bin/fw

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

**Symptom:** `fw upgrade` run from a stale/foreign framework downgrades a consumer and
reports success. Field instance 2026-08-03 (010-termlink): vendored VERSION went
1.6.295 → 1.6.121.

**Root cause:** `fw_version_relation` resolves the consumer's commit *inside `$froot`*
— the framework doing the upgrading. A foreign source is by definition the repo that
does not contain the consumer's commit, so the lookup fails, the relation is
`undecidable`, and `FW_UNDECIDABLE_VERSION_PROCEED` (default `1`) proceeds on a WARN.
The guard asked the suspect whether the suspect was trustworthy, and read "I can't
tell" as "no objection".

**Why structurally allowed:** two states with opposite evidentiary weight shared one
return value. *No sha recorded* is genuine ignorance; *sha recorded, source can't
resolve it* is a positive finding about the source. Because both produced
`undecidable`, the safe default for the first (proceed, so legacy consumers aren't
bricked) silently became the default for the second. T-2713 built the comparator
correctly and even documented the undecidable case honestly — it just never
distinguished "no evidence" from "evidence of a foreign source".

Compounding it: the failure is a false green (L-534 direction). The consumer's pin
never advances, so it reads as permanently "behind" and every subsequent upgrade
reports success. Nothing surfaces a red.

**Prevention:**
- `foreign-source` is now its own relation and refuses by default
  (`lib/version-relation.sh`), bypass `FW_ALLOW_FOREIGN_SOURCE=1`.
- `tests/unit/t2762_upgrade_foreign_source_sha.bats` — 10 tests, incl. an
  end-to-end refusal, a no-mutation-before-refusal test, and a negative test pinning
  that the sanctioned upstream-checkout flow is still allowed.
- Mutation-verified: reverting `foreign-source` → `undecidable` reds tests 1, 2, 4, 7, 8;
  restore → 10/10 green.
- `fw doctor`'s fleet badge teaches the same remedy instead of recommending
  `fw upgrade` at a source that will refuse (`bin/fw:2088`, `:2099`).

**Test-integrity note (worth more than the fix).** The first draft of the two
end-to-end tests asserted on exit status. Both reported the *opposite* of the truth
before any fix existed: the "refuses" test passed and the "allows" test failed —
because on this host `fw upgrade` aborts at step 4c (`/root/.local/bin/fw` resolves
into a stale framework repo) and sets exit 1 regardless. The tests were measuring the
developer's global shim. They now control `HOME` and assert on the guard's own
message. A test whose green comes from an unrelated non-zero exit is the same false
green as the bug it is chasing.

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

### 2026-08-03 — guard mechanism: sha-resolvability, not path comparison

- **Chose:** refuse when the consumer records a `version_sha` this source cannot
  resolve (`foreign-source`).
- **Why:** it targets the actual failure, is host-independent, and leaves the
  sanctioned invocation untouched. The evidence is intrinsic — the consumer's own
  recorded commit — rather than a heuristic about paths.
- **Rejected:** T-2761's original "refuse when `FRAMEWORK_ROOT` != the target's
  `.agentic-framework`". It refuses the *documented correct* invocation (T-1542
  remediation option 3, `lib/upgrade.sh:775-776`), and the equal-path case it aims at
  is already covered by T-1542/T-1634. T-2761's GO explicitly left the mechanism open
  ("The open question is refuse-vs-warn-vs-reroute"), so this stays inside the
  authorised scope.

### 2026-08-03 — opposite defaults for two neighbouring relations

- **Chose:** `foreign-source` refuses by default; `undecidable` keeps proceeding by
  default.
- **Why:** they carry opposite evidentiary weight. Refusing on `undecidable` would
  strand every legacy consumer whose pin predates `version_sha` — the same stranding
  T-2713 was filed to end.
- **Rejected:** flipping `FW_UNDECIDABLE_VERSION_PROCEED` to `0`. Simpler, but it
  fixes the field case by breaking the legacy case.

### 2026-08-03 — known boundary, deliberately not expanded

- **Chose:** leave the equal-version case alone. `fw_version_relation` returns `same`
  at `lib/version-relation.sh:79` on a string match, before any sha lookup — so a
  foreign source that happens to carry the *same* VERSION string is not caught.
- **Why:** plausible given a resetting counter, but low harm (an upgrade to the same
  version is near-nop), and closing it means reordering the early-return, which
  changes behaviour for every consumer to catch a narrow case. Out of scope for the
  authorised slice; recorded here rather than silently widened.
- **Rejected:** moving the sha check ahead of the equality check in this task.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-03T11:43:03Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2762-upgrade-guard-a-source-repo-that-cannot-.md
- **Context:** Initial task creation
