---
id: T-2885
name: "Budget gauge takes the last usage entry regardless of model — foreign-model
  cache-priming poisons it (832 T-401)"
description: >
  budget-gate.sh and checkpoint.sh both take the LAST usage entry in the transcript
  as this conversation's context size. Four models write usage entries into our transcript;
  a cache-priming call from a foreign model can therefore report its own 300k+ prompt
  as ours, arming a critical block and the auto-restart signal on a healthy session.

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
created: 2026-08-09T09:46:14Z
last_update: 2026-08-09T10:10:17Z
date_finished: 2026-08-09T10:10:17Z
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
  - ts: '2026-08-09T09:55:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=1 (body:episodic-only); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-08-09T10:00:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2885: Budget gauge takes the last usage entry regardless of model — foreign-model cache-priming poisons it (832 T-401)

## Context

Reported by 832 (DM rail 488, their T-401) and **confirmed live in our tree** on
2026-08-09 before filing. Their instance blocked every non-allowlisted tool call in a
session with ~72% of its window free, immediately after a /compact — it scored 341880
tokens against a real size of 84629.

**The mechanism.** `agents/context/budget-gate.sh:343` and
`agents/context/checkpoint.sh:129` both do `t = input + cache_read + cache_creation`
inside the scan loop, unconditionally overwriting on every entry that carries usage. The
last entry wins. The arithmetic is right; the **entry selection** is wrong.

832's line is the one to keep: all three existing defences — the T-2322 compact_boundary
reset, the T-1088 `.session-start-ts` filter, and the `<synthetic>` skip — **filter by
position in the log**. Position tells you *when* a call happened; it cannot tell you
*whose conversation* it belonged to. Nothing had ever needed to ask, because until a
second writer appeared every entry belonged to the conversation by construction.

**Measured in our own transcript (2026-08-09), not inferred:**

| | |
|---|---|
| models writing usage entries | **4** — claude-opus-5 (session), claude-fable-5, claude-opus-4-8, claude-sonnet-4-5 |
| entries shaped like cache-priming (input_tokens<10, cache_creation>100k) | **303** |
| foreign-model entries in the *current* post-boundary segment | **2** (claude-opus-4-8, alongside 256 claude-opus-5) |
| example poisoning-shaped entry | `2026-07-05T10:12:01Z claude-opus-4-8 total=252178 input_tokens=2` |

The gauge is correct at this instant only because the newest entry happens to be ours.
Both foreign writers are active in the live segment, so the condition is present and
firing is a matter of ordering.

**Confirmed drift, exactly as 832 predicted.** `grep -c compact_boundary`:
budget-gate.sh **1**, checkpoint.sh **0**. The PostToolUse gauge has been a version
behind the PreToolUse gate it backs up since T-2322 — two hand-copied inline scans, and
the copy that does not fire is the copy that rots. Patching both copies leaves the class
alive; this is Level C, not Level A.

**Why it is worse than a wrong number.** Two aggravating properties, both measured by
832:

- *It erases its own evidence.* The poisoned `.budget-status` blocks only while <90s
  fresh; then the slow path re-reads, real turns have landed, and the gauge reads
  healthy. It strikes at session **resumption** and looks fine by the time anyone
  investigates. Our own L-556 and OBS-206 shape again — a control reads as comprehensive
  precisely because the escaping cases are silent.
- *It arms the auto-restart signal for real.* `.restart-requested`, reason
  `critical_budget_gate_block`. Under `claude-fw` that terminates and restarts a healthy
  session, and the foreign entry is still newest after the restart, so it re-arms —
  bounded only by max-5-consecutive-restarts. 832 was unsupervised so theirs was inert.
  **We run supervised.**

**The fix 832 built** (refs only per OBS-108, no bytes: their commits 86a256fd,
ee4d20f4 — one implementation, both callers):

1. Scope entries to the model with the **most entries since the last boundary**.
   Explicitly *not* "the newest entry's model" — in their incident the foreign entry WAS
   the newest, so a newest-keyed rule reproduces the bug exactly.
2. Below two in-scope entries, return **0** rather than guess. Deliberate fail-open: a
   session with under two turns since a boundary cannot have filled its context. This is
   the half that covers the measured instant, where there was no conversation volume to
   scope against at all.

**Deliberately NOT unified:** `lib/costs.sh` and `web/blueprints/costs.py` sum the same
three fields for **cost**, where that foreign call genuinely did cost money. Same
arithmetic, opposite correct answer. A future "consistency" refactor routing cost through
the gauge helper would be a regression — say so in the docstring.

## Acceptance Criteria

### Agent
- [x] One shared implementation of "how many tokens is THIS conversation holding",
      replacing the two hand-copied inline scans, so the two gauges cannot drift again
- [x] Both callers use it — the PreToolUse gate and the PostToolUse checkpoint — and
      checkpoint.sh gains the compact_boundary reset it never received
- [x] Entries are scoped to the dominant model since the last boundary, **not** to the
      newest entry's model (the newest-keyed rule reproduces the reported bug exactly)
- [x] Under two in-scope entries returns 0, not a guess
- [x] TEETH: a fixture built from a real poisoning-shaped entry, with one test asserting
      the **pre-fix** algorithm still returns the inflated number on it — so the fixture
      cannot quietly stop reproducing the bug (832's convention, and the leg that makes
      the others meaningful)
- [x] A genuinely oversized session still reads critical and still blocks — the fix must
      not be "stop blocking"; repaired, not removed
- [x] The wrap-up allowlist is intact at critical (git commit, fw handover, reads)
- [x] `lib/costs.sh` / `web/blueprints/costs.py` are left alone, with a docstring note
      saying why routing cost through this helper would be a regression

## Verification

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

bash -n agents/context/budget-gate.sh
bash -n agents/context/checkpoint.sh
python3 -c "import ast; ast.parse(open('lib/context_tokens.py').read())"
out=$(bats tests/unit/t2885_context_tokens_model_scope.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/integration/budget_gate.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/integration/budget_gauge_stdin_transcript.bats tests/integration/continuous_loop_critical_signal.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'

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

**Symptom:** `budget-gate.sh` / `checkpoint.sh` can score a healthy session as
critical (or vice versa) when a foreign model writes a usage entry into the
same transcript JSONL after our own last turn — reported by 832 (their T-401)
and confirmed live in this tree: 4 models write usage entries into one
transcript, and a cache-priming call from a foreign model reported a 300k+
prompt as ours.

**Root cause:** both scripts computed "current context size" by taking the
LAST usage entry in transcript order, unconditionally overwriting on every
entry that carried a `usage` block. Position in the log tells you WHEN an
entry was written, not WHOSE conversation it belongs to — that distinction
had never needed asking until a second writer appeared in the same file.

**Why structurally allowed:** the token scan was implemented twice
independently (budget-gate.sh's PreToolUse copy and checkpoint.sh's
PostToolUse copy), both hand-copied from the same origin with no shared
source. The two copies had already drifted — only budget-gate.sh received
the T-2322 compact_boundary reset; checkpoint.sh did not — and nothing
detected the drift because both copies "worked" whenever the newest entry
happened to be ours, which was true 100% of the time until Claude Code
started writing multi-model transcripts (opus-5, fable-5, opus-4-8, sonnet-4-5
observed in one live transcript).

**Prevention:** `lib/context_tokens.py` is now the single implementation both
callers invoke — a future compact_boundary-class fix lands once, not twice.
`tests/unit/t2885_context_tokens_model_scope.bats` pins the fix with a TEETH
fixture (`tests/fixtures/T-2885/poisoning-transcript.jsonl`) built from a real
poisoning-shaped entry, including a frozen copy of the pre-fix algorithm that
must keep reproducing the bug on that fixture — so the regression test cannot
silently stop testing anything if the fixture or module drift apart later.

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

### 2026-08-09 — Dominant-model scope vs. per-model separate readings

- **Chose:** scope entries to the model with the most usage entries since the
  last `compact_boundary` (the dominant writer), take its last entry, and
  return 0 below two in-scope entries.
- **Why:** matches 832's shipped fix and the exact failure mode reported —
  the poisoning entry in their incident WAS the newest, so a newest-model-keyed
  rule reproduces the bug. Dominant-by-count is robust because normal
  conversational turns from our own model vastly outnumber a single foreign
  cache-priming call.
- **Rejected:** (a) keying on the newest entry's model — reproduces the bug
  by definition; (b) always taking the max token reading across all models —
  would make a foreign 300k+ entry ARM critical even more reliably than
  before; (c) a session/thread-id filter — Claude Code transcripts don't
  carry a per-writer session id distinct from the shared transcript file.

### 2026-08-09 — Not sharing with lib/costs.sh / web/blueprints/costs.py

- **Chose:** leave both cost-reporting surfaces on their existing full-sum
  scan; added a docstring note in each explaining why.
- **Why:** cost and context-window occupancy are different questions over the
  same three usage fields. A foreign call is real spend (belongs in cost) but
  not real context (must be excluded from the gauge). Routing cost through
  `lib/context_tokens.py` would silently under-report spend for exactly the
  entries that make the cost dashboard worth running.
- **Rejected:** a single shared "usage total" helper with a mode flag —
  adds a branch two callers would need to get right rather than removing one.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-09T09:46:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2885-budget-gauge-takes-the-last-usage-entry-.md
- **Context:** Initial task creation

### 2026-08-09T09:55:10Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-38b36712
- **Timestamp:** 2026-08-09T10:10:18Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#8 (Agent)** — `lib/costs.sh` / `web/blueprints/costs.py` are left alone, with a docstring note
  - **AC-verify-mismatch** (narrow, heuristic) — `path=lib/costs.sh in: `lib/costs.sh` / `web/blueprints/costs.py` are left alone, with a docstring note`

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 29
     - evidence: ``bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"` added to ## Verification.`

### 2026-08-09T10:10:17Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
