---
id: T-2796
name: "fw --version reports a bare counter with no anchor, and warns on a string compare T-2713 already replaced"
description: >
  fw --version reports a bare counter with no anchor, and warns on a string compare T-2713 already replaced

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
created: 2026-08-04T19:46:20Z
last_update: 2026-08-04T19:46:20Z
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

# T-2796: fw --version reports a bare counter with no anchor, and warns on a string compare T-2713 already replaced

## Context

`fw --version` prints `fw v1.6.132` and nothing that anchors it. The number is
`major.minor.<commits-since-the-newest-tag-this-clone-knows>` — a distance, not a
version — so it resets at every tag and is not comparable between installs. On
2026-08-04 the operator's onboarding agent read a global install's `1.6.432` as
"current, skip the installer" and this session read the same number as "~130
commits behind, update it". The install was in fact **three commits behind**
master's `1.6.132`: the bigger number was the stale one, because that clone had
not fetched the recent tags and was measuring from an older anchor.

OBS-150 named this deriver bug three hours earlier. T-2792's RCA deliberately left
it unfixed, arguing T-2793 subsumed it: *"once the CLI is vendored,
`.agentic-framework/` has no `.git`, `_derive_version` falls back to the `VERSION`
file, and the split-brain disappears as a structural consequence."* That holds for
the **project** copy. The **global install** keeps its `.git` and keeps reporting a
distance — and the onboarding prompt's Step 2 reads the global. The fix shipped and
the confusing message survived, because they were about different objects.

Second defect at the same site: the `Pinned:` block compared `pinned != FW_VERSION`
as strings. T-2713 replaced exactly that shape at three sites (`bin/fw:2015`,
`lib/upgrade.sh:849`, `lib/upgrade.sh:1742`) with git-ancestry via
`fw_version_relation`, on the reasoning that *"a counter that resets does not
order, so every one of those three 'ahead' verdicts is a guess wearing the costume
of a comparison."* `show_version` was a fourth site, missed — and the most-read one,
since it fires on every `fw --version`.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `fw --version` prints the commit its counter is a distance from — SHA plus branch
      when the framework root is a git checkout. Verified live:
      `Commit:    74bade82e (t2539-staging)`.
- [x] A framework root with no `.git` (the vendored case) says so explicitly rather
      than omitting the line — `Commit:    (none — vendored copy; VERSION file is the
      only identity)`. An absent line and "no commit" are different facts.
- [x] The `Pinned:` comparison routes through `fw_version_relation` (git ancestry),
      not string inequality, and reports `behind` / `ahead` / `diverged` /
      `foreign-source` / `undetermined` with the module's reason line. Legacy pins
      with no `version_sha:` report **undetermined**, not drift.
- [x] Line 1 (`fw v<counter>`) is byte-identical to before, so the `.framework.yaml`
      pin, `fw version sync`, and self-audit's VERSION comparison are untouched. The
      counter is load-bearing; only its solitude was the defect.
- [x] `tests/unit/fw_version_output.bats` — 9 tests, all green — including a
      `set -e` regression pin for the `same` path (an `[ -n "$p" ] && echo` there
      returns 1 and kills the CLI on the most common path of all).
- [x] Negative control run: the same assertions against `git show HEAD:bin/fw` fail
      as expected (no `Commit:` line, no ancestry verdict, old wording present).
      Recorded in `## Updates`.

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

bash -n bin/fw
out=$(bats tests/unit/fw_version_output.bats 2>&1); echo "$out" | grep -q '^ok 9 ' && ! echo "$out" | grep -q '^not ok'
out=$(bin/fw --version 2>&1); echo "$out" | grep -q "^Commit:  *$(git rev-parse --short=9 HEAD)"
out=$(bin/fw --version 2>&1); echo "$out" | grep -qE '^fw v[0-9]+\.[0-9]+\.[0-9]+'

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

**Symptom:** `fw --version` reports a number that reads like a semver patch and
orders like noise. On 2026-08-04 a global install three commits behind master
reported `1.6.432` against master's `1.6.132`. Two independent readers — the
operator's onboarding agent and this session — drew opposite conclusions from it,
both wrong, and both acted on them (one skipped the installer, one recommended an
unnecessary update).

**Root cause:** `_derive_version` (`bin/fw:36-42`) parses `git describe` and
discards the tag's own patch, substituting the commit distance:

```bash
base="${desc%%-*}"            # 1.6.764
commits="${rest%%-*}"         # 132
major_minor="${base%.*}"      # 1.6      ← .764 deleted
echo "${major_minor}.${commits}"         # → 1.6.132
```

The output therefore encodes *distance from whichever tag this clone last
fetched*. Two clones of the same history with different tag knowledge produce
incomparable numbers, and a clone with older tags produces a **larger** one. The
string carries no anchor — no tag name, no SHA — so nothing next to it contradicts
the semver reading its shape invites.

**Why structurally allowed:** three separate reasons compounded.
1. T-2713 already established that this counter does not order, and built
   `fw_version_relation` to replace string comparison with git ancestry — but it
   enumerated three call sites and missed `show_version`, the one that runs on
   every `fw --version`. A correct diagnosis with an incomplete site list leaves
   the loudest surface untouched.
2. T-2792's RCA argued the deriver bug was *subsumed* by T-2793's CLI vendoring,
   because a vendored copy has no `.git` and falls back to the `VERSION` file. True
   for the project copy; false for the global install, which keeps its `.git`. The
   subsumption argument and the failing surface were about different objects, so
   the fix shipped and the symptom stayed.
3. Nothing ever compared two installs. Every test asserted a version string against
   *itself* — the single-install case, where a distance is indistinguishable from a
   version. The defect is only observable across two clones with different tags.

**Prevention:** `tests/unit/fw_version_output.bats` pins the anchor (SHA + branch,
asserted equal to `git rev-parse`), the no-`.git` disclosure, ancestry-based pin
relations for behind / undetermined / foreign-source, and line 1's stability. The
undecidable case is asserted to say **undetermined** rather than a direction —
L-536: a line that PRINTS a direction is a decision site. The counter itself is
deliberately unchanged; it is load-bearing for the pin, `fw version sync`, and
self-audit, and changing its format would trade a confusing message for a broken
upgrade check.

**Not fixed here:** the onboarding prompt's Step 2 still asks *"is fw installed?"*
and treats the answer as a freshness verdict. Presence was never the question. That
is a prompt-level fix, filed separately rather than smuggled into this one.

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

### 2026-08-04T19:46:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2796-fw---version-reports-a-bare-counter-with.md
- **Context:** Initial task creation
