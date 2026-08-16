---
id: T-3033
name: "832 rail: delivery works, the extract_recent_posts read family is blind — correct OBS-281"
description: >
  832 rail: delivery works, the extract_recent_posts read family is blind — correct OBS-281

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
created: 2026-08-16T11:59:50Z
last_update: 2026-08-16T11:59:50Z
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

# T-3033: 832 rail: delivery works, the extract_recent_posts read family is blind — correct OBS-281

## Context

OBS-281 concluded that posts to `agent-chat-arc` were of unverifiable delivery: the
write returned an offset, and `chat_arc_recent` returned 0 posts over 2h and 36h
windows. That conclusion was wrong. The writes landed, the peer (832) read them in
full, and 832 had replied four times (11973, 11975, 11978, 11979) into a topic this
session was reading with a blind instrument.

The real defect is a read-path split: verbs built on TermLink's `extract_recent_posts`
helper return 0 unconditionally, while verbs on other code paths (`digest`,
`state-since`, `quote`, `snippet`, `info`, `channel unread`) return the same topic's
data correctly. The fix site is TermLink's, not ours (Gap Homing, T-1333); what is
ours is the corrected observation, the workaround, and the reasoning error that let a
blind instrument stand as evidence of an empty rail.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] OBS-281 is corrected in `.context/inbox.yaml` — its text states that delivery
      succeeded, names the four peer replies received, and identifies the read path
      rather than the write path as the defect
- [x] The working read path is recorded so the next session does not repeat the
      error: a `## Findings` section in this task naming which verbs are blind and
      which work, with the single-hub measurement that eliminates hub selection
- [x] A reply is posted to 832 on `agent-chat-arc` confirming receipt, naming the
      call that worked, and carrying the single-hub evidence (verifiable by reading
      the returned offset back with `termlink agent quote <offset>`) — offset 11980,
      read back and confirmed on the topic
- [x] The three findings 832 raised (CTL-028 routing, duplicate CTL-029, gauge
      exit-code trap) are each filed as observations in this repo so they survive
      this session — OBS-282, OBS-283, OBS-284 (plus OBS-285, arc retention)

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

python3 -c "import yaml; yaml.safe_load(open('.context/inbox.yaml'))"
out=$(python3 -c "import yaml;d=yaml.safe_load(open('.context/inbox.yaml'));print([o['text'] for o in d['observations'] if o['id']=='OBS-281'][0])" 2>&1); echo "$out" | grep -q "CORRECTED"
out=$(timeout 60 termlink agent info 2>&1); echo "$out" | grep -q "agent-chat-arc"

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

## Findings

### The read-path split (measured 2026-08-16, local hub, same minute)

| blind — returns 0 | working — returns the data |
|---|---|
| `agent timeline` | `agent digest` |
| `agent stats` | `agent state-since --since <ms>` |
| `agent presence` | `agent quote` / `agent snippet` |
| `agent recent` / `who` / `on-thread` | `agent info` / `channel unread` |
| MCP `termlink_agent_chat_arc_recent` | |

Every verb on the left is documented as a wrapper over TermLink's
`extract_recent_posts`. Every verb on the right is on a different code path.
`agent info` reports `Posts: 2003, Senders: 4` on the same hub, in the same minute,
where `agent stats --window-secs 86400` reports `total=0`.

### Hub selection is eliminated as a cause

`chat_arc_recent(hub="127.0.0.1:9100", all_msg_types=true, since_hours=24,
timeout_secs=90)` → `hubs_scanned: 1, hubs_failed: 0, fallback_hubs: [],
total_posts: 0`.

Single hub, no merge, no fallback, msg_type filter disabled — on the same local hub
from which `agent quote 11979` returns the post in full. So it is not the fleet walk,
not fallback, not hub selection, and not the merge. This is stronger than the peer's
own diagnosis, which inferred a hub-merge source mismatch from a multi-hub result.

### The msg_type default is real but not sufficient

The MCP verb defaults to `filter_msg_type: 'chat'` while substantive posts are typed
`note` — so the default does drop real traffic. But it is not what produces the zero:
offset **11977 is `chat`-typed** (verified with `agent quote`) and ~2h old, inside
`agent stats --window-secs 86400`, which returns `total=0`; `agent digest` over 60
minutes returns that same 11977. Fixing the default alone leaves the rail blind while
looking fixed, because `all_msg_types: true` is the obvious next attempt and also
returns zero.

### Hypothesis offered to TermLink, not asserted here

Every call on the `extract_recent_posts` family returned exactly 0 — never a partial —
at windows of 3600 s, 86400 s, 604800 s, and 24 h / 72 h. A window-size bug degrades;
this does not. That fits a cutoff that always exceeds every timestamp (a seconds vs
milliseconds mismatch in the comparison; storage is ms, since `state-since --since
<ms>` works precisely). The peer's 5 rows from ring20-dashboard are the datum that
complicates it. Discriminating test: `channel digest` vs `agent timeline` over the
same window on any hub.

Two hypotheses were tested and refuted first: hub routing (refuted — `hubs.toml`
includes the local hub as `workstation-107-public` and `local-test`, and the pinned
single-hub call still returns 0) and a naive `now_ms - window_secs` cutoff (refuted —
post 11979 was 5–10 min old, inside a mis-scaled 604.8 s lookback, and still absent).

### Fix homing

The fix site is TermLink's `extract_recent_posts`, so per T-1333 (Gap Homing) it
belongs in TermLink's register, not ours. Our side keeps the workaround: read the arc
with `agent quote` / `snippet` / `state-since`, or `channel unread` + `channel
snippet`. The peer was given offsets 11970, 11973, 11974, 11975, 11978, 11979 as
fixtures — they are on-topic, timestamped, and provably invisible to that path.

## RCA

**Symptom:** OBS-281 reported that posts to `agent-chat-arc` were of unverifiable
delivery — the write returned an offset, `chat_arc_recent` returned `total_posts: 0`
over 2 h and 36 h windows, and the session reported to the operator that it had no
evidence the peer received anything.

**Root cause of the reported symptom:** a blind read verb. TermLink's
`extract_recent_posts` family returns 0 unconditionally on this hub; the write path,
the topic, and the peer were all healthy throughout. The peer had read offsets 11968
and 11974 in full and replied four times (11973, 11975, 11978, 11979) into the same
topic while it was being reported silent.

**Root cause of the reasoning error — the durable part:** a single-arm measurement was
treated as evidence about the world. The instrument returned `ok: true` with a
plausible zero, which is indistinguishable from a genuinely quiet rail. Two working
read paths (`agent quote`, `channel unread`) were available on the same host the whole
time and neither was used as a cross-check. The specific trap is that a zero is a
*plausible* reading — a red result gets investigated, a confident empty result gets
believed.

**Why structurally allowed:** nothing required a negative observability claim to be
corroborated on a second path before being filed or reported. OBS-281 was written
carefully — it named its measurement, its window, and its fleet state — and was still
wrong, because care about *how* the number was obtained does not test whether the
instrument can see anything at all. This is the same class the peer reported three
times in two days (`a stated property standing in for a checked one`) and matches
L-539 (*a rail can be correct, cheap, and blind — check the SET it runs over*),
applied here to our own tooling rather than a framework control.

**Prevention:** the rule adopted and recorded in OBS-281's correction — never report a
rail as quiet on a single read path. Concretely: before filing or reporting a negative
observability finding, run a second read path with a different code path and show it
returning *something*, so the instrument is proven sighted before its silence is
treated as data. The cheap generalisation is a positive control: a measurement that
can only ever return zero is not evidence of absence.

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

### 2026-08-16T11:59:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3033-832-rail-delivery-works-the-extractrecen.md
- **Context:** Initial task creation
