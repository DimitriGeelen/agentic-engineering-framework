---
id: T-2932
name: "fw note count reports urgent from a whole-file grep — dismissed observations still counted"
description: >
  fw note count reports urgent from a whole-file grep — dismissed observations still counted

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
created: 2026-08-12T06:31:26Z
last_update: 2026-08-12T06:37:44Z
date_finished: 2026-08-12T06:37:44Z
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

# T-2932: fw note count reports urgent from a whole-file grep — dismissed observations still counted

## Context

`fw note count` reports the urgent figure from `grep -c 'urgent: true'` over the
**whole inbox file**, with no status filter. Every observation ever marked urgent
is counted forever — including ones dismissed months ago.

Measured 2026-08-12: **reported 8 urgent, true value 4.** The four phantoms are
`OBS-002`, `OBS-029`, `OBS-030`, `OBS-031`, all dismissed.

This is the headline number the handover prints and that CLAUDE.md's session-start
ritual points an agent at. It is also, structurally, the same defect T-2927 fixed
one line away: a figure composed from a proxy (a string anywhere in the file)
rather than from the thing being counted (pending observations that are urgent).

The direction is the interesting part. Over-reporting urgency looks like the safe
failure — loud rather than silent. It is not. An operator who opens the queue and
finds half the "urgent" items already dismissed learns the number is decorative,
and the next real one gets the same shrug. **An urgency signal dies by inflation,
not by silence.**

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `fw note count` reports urgent as *pending AND urgent*, matching a YAML-parsed count exactly
- [x] The pending figure is derived the same way, not by grepping a line that could appear inside an observation's text
- [x] Count and list agree: the number `fw note count` reports equals the number of urgent rows `fw note list` shows
- [x] The counter degrades loudly, not to zero, if the inbox cannot be parsed — a silent `0 pending` reads identically to a healthy empty inbox
- [x] A test drives the real script and pins the exact defect: an inbox with dismissed-urgent entries must not inflate the count
- [x] Anti-vacuity: the reconstructed pre-fix grep is shown to over-count on the same fixture

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

out=$(bats tests/unit/t2932_note_count_urgent_filter.bats 2>&1); echo "$out" | grep -q '^ok 12 ' && ! echo "$out" | grep -q '^not ok'
# The live count equals the parsed truth. Asserted on the shipped command's
# OUTPUT, not on the helper in isolation — the defect was in what the operator
# is shown. Single line: P-011 executes one command per line, and an embedded
# multi-line python heredoc is split into fragments that each fail on their own.
test "$(bin/fw note count)" = "$(python3 -c "import yaml; d=yaml.safe_load(open('.context/inbox.yaml')); p=[o for o in d['observations'] if o.get('status')=='pending']; u=sum(1 for o in p if o.get('urgent') is True); print(f'{len(p)} pending ({u} urgent)' if u else f'{len(p)} pending')")"
# No grep-based counter survives at ANY of the four sites (comments stripped
# first — all three files now quote the old form in explanatory comments).
test -z "$(sed 's/[[:space:]]*#.*$//' agents/observe/observe.sh agents/handover/handover.sh agents/audit/audit.sh | grep -E "grep -c '(status: pending|urgent: true)'")"
bash -n agents/observe/observe.sh
bash -n agents/handover/handover.sh
bash -n agents/audit/audit.sh

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

**Symptom:** `fw note count` reported **8 urgent** against a true value of **4**.
The handover and the session-start ritual both surface that figure.

**Root cause:** `urgent=$(grep -c 'urgent: true' "$INBOX_FILE")` — a whole-file
string count with no status filter, so every observation ever marked urgent stayed
in the total after being dismissed. `do_list`'s header had the same shape for
`pending`.

**Why structurally allowed:** the urgent count had already been converted to a
YAML parse **twice**, at the two other sites that compute it — T-2514 in
`audit.sh`, T-2927 in `handover.sh`. Neither sweep reached `observe.sh`, which is
the file that *owns* the inbox. And T-2317 converted `do_list`'s **listing** to
`yaml.safe_load` while leaving the header count one screen above it on the grep.
Three conversions of one class in one subsystem, and the site nearest the data was
missed by all of them. The reason is always the same: a sweep records which
instances it converted, never how many there were, so "the ones we found" and
"all of them" are indistinguishable afterwards.

It stayed invisible because the error direction *looks* safe. An inflated urgent
count reads as caution, and nobody audits a number that is too high. But it is the
worse direction here: an operator who opens the queue and finds half the urgent
items already dismissed stops trusting the figure, and the next real one gets the
same shrug. **An urgency signal dies by inflation, not by silence.**

**Prevention:** both counts now come from a single parsed helper (`_inbox_counts`)
that `do_count` and `do_list` share, so the header cannot disagree with the rows
under it. The helper refuses loudly on a parse failure instead of returning zero,
because `0 pending` from a corrupt inbox is indistinguishable from a healthy empty
one. Guarded by `tests/unit/t2932_note_count_urgent_filter.bats` (11 legs):
reconstructed pre-fix grep as anti-vacuity, count-vs-independent-parse equality,
header-vs-rows agreement, the loud-refusal path *and* a leg proving a genuinely
empty inbox still reports empty, an enumerating guard against a grep-based urgent
counter reappearing, and a leg pinning the two remaining latent `pending` greps
(`handover.sh:381`, `audit.sh:2663`) against the parsed truth — filed as OBS-233
rather than fixed here, one bug per task, but converted from latent to guarded.

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

### 2026-08-12 — deferred the sibling sites as latent, then reversed within the hour

- **Chose (first):** fix only the urgent counter in `observe.sh`; file the
  grep-based *pending* counters at `handover.sh:381` and `audit.sh:2663` as
  OBS-233 rather than fix them, on the grounds that they were measurably correct
  (grep 117 == parse 117) and "one bug, one task".
- **Chose (revised):** fix both, plus a fourth site, under this task.
- **Why the reversal:** OBS-233's own text quotes `status: pending` — the string
  the counters grep for. Filing the observation pushed grep to 119 against a true
  118. **The act of recording the latent case is what made it live**, inside the
  same hour, and the test leg written to guard the latency went red on its first
  full run. "Latent" was a statement about the corpus, and the corpus is something
  this session writes to.
- **Rejected:** leaving it filed and letting the guard carry it. The guard was
  already red; keeping a red leg to preserve a scoping rule would be tidiness at
  the expense of a live miscount in the handover and the audit.

### 2026-08-12 — the enumerating guard found a site I had already read past

- **Chose:** assert *no grep-based counter at any site*, rather than assert the
  four known sites are converted.
- **Why:** on its first run the leg failed on `observe.sh:384` — `do_triage`, in
  the same file as two conversions I had just made by hand, and the worst of the
  four: "Nothing to triage — inbox is clean" is an assertion *about the queue*,
  so a miscount there tells the operator the ritual is finished. I had read that
  function while editing the two above it and did not see it. A list of known
  sites would have gone green.
- **Rejected:** enumerating the four sites explicitly. Cheaper to write, and it
  encodes today's census as the answer — which is the exact failure L-533
  describes and that produced this bug in the first place (T-2514 and T-2317 and
  T-2927 each converted the instances they found).

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-12T06:31:26Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2932-fw-note-count-reports-urgent-from-a-whol.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d859c54f
- **Timestamp:** 2026-08-12T06:37:50Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-12T06:37:44Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
