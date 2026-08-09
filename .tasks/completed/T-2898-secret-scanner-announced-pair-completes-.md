---
id: T-2898
name: "Secret-scanner ANNOUNCED pair completes from a single overlapping span (password/pass)"
description: >
  Secret-scanner ANNOUNCED pair completes from a single overlapping span (password/pass)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/git/lib/secret-scan.sh, tests/unit/secret_scan_span_rule.bats]
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
created: 2026-08-09T14:47:00Z
last_update: 2026-08-09T15:00:53Z
date_finished: 2026-08-09T15:00:53Z
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
  - ts: '2026-08-09T15:00:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-09T15:00:14Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 4
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=4 (body:cross-machine); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2898: Secret-scanner ANNOUNCED pair completes from a single overlapping span (password/pass)

## Context

The T-2897 name axis classifies ANNOUNCED by matching a secrecy qualifier and a
credential noun independently against the same filename. Nothing requires the
two matches to occupy *different* spans, so a single word satisfies both halves:
`pass` (noun) is a substring of `password` and `passwd` (qualifiers). Measured on
a synthetic tree — `config/passwd-rotation.yaml`, `config/password-reset.yaml`,
`docs/password-policy.json` all classify ANNOUNCED.

This is the identical class T-2897 already fixed once, for `credential` in both
halves, and the comment at `agents/git/lib/secret-scan.sh:290-296` states the
rule it violates: *"A pair that one word can complete is not a pair."* The rule
was written down; the lists were then curated by hand against it, and hand
curation does not survive the next word.

832 hit the same class in their scanner (rail 503) and their repair is the one to
take: require the halves to match at **non-overlapping spans**, which makes the
rule structural instead of a curation discipline. Their second finding — that a
generative test is the only kind that survives a future list edit — is the reason
AC-4 exists.

Two things specific to our instance, both worth keeping:

- **The prose/source extension filter was masking the evidence.** `reset-password.md`
  and `password_reset_test.py` come back clean, but via the `.md`/`.py` exclusion,
  not via the pair logic. The bug was fully present and the cases that would have
  shown it were suppressed by something else.
- **What is left unmasked is the file class that matters.** The surviving false
  positives are `.json` and `.yaml` — config data, where real secrets do live, and
  therefore the class no extension filter can ever exclude.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `_secret_name_classify` requires the secrecy and noun halves to match at
      non-overlapping spans of the basename; the three measured false positives
      (`passwd-rotation.yaml`, `password-reset.yaml`, `password-policy.json`)
      classify as nothing.
- [x] The overlapping words stay in both lists. `password`/`passwd` are not
      curated apart — the span rule is what makes the overlap harmless, and
      removing the overlap would let AC-4 pass for the wrong reason.
- [x] No regression in what T-2897 already detects: every test in
      `tests/unit/secret_scan_name_axis.bats` stays green, including
      `private-key-store.dat`-shaped names where the two halves are genuinely
      separate words at disjoint spans.
- [x] A **generative** test enumerates both word lists at run time and probes
      each word alone, asserting no single word classifies as ANNOUNCED — so a
      future list edit is caught by construction rather than by a fixture. A leg
      asserts the two lists still overlap, so the generative leg cannot pass
      because the overlap was removed.
- [x] The new tests are shown to be capable of failing: run them against the
      pre-fix classifier and record which legs go red.

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

bash -n agents/git/lib/secret-scan.sh
out=$(bats tests/unit/secret_scan_name_axis.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/secret_scan_span_rule.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# the live tree, with no exemptions — a check needing an allowlist on day one has the wrong threshold
PROJECT_ROOT="$PWD" bash agents/git/lib/secret-scan.sh scan-names
# the overlap AC-2 protects: both lists must still share at least one word
grep -qE "^_SECRET_NAME_SECRECY_WORDS=.*password" agents/git/lib/secret-scan.sh && grep -qE "^_SECRET_NAME_NOUN_WORDS=.*(^| )pass( |')" agents/git/lib/secret-scan.sh

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

**Symptom:** `config/passwd-rotation.yaml`, `config/password-reset.yaml` and
`docs/password-policy.json` classify as ANNOUNCED — announced credential
material — on a synthetic tree. None is key material; two are configuration and
one is policy documentation.

**Root cause:** `_secret_name_classify` ran two independent `grep -qE` passes
over the whole basename, one for the secrecy half and one for the noun half,
with nothing requiring the matches to occupy different spans. `pass` is a
substring of `password` and of `passwd`, so one word satisfied both halves.

**Why structurally allowed:** T-2897 had already hit this exact class
(`credential` in both lists) and fixed it *by curating the lists*, writing the
rule into a comment — "a pair that one word can complete is not a pair" — with
no code that enforces it. A rule that lives only in a comment is a discipline
the next author has to notice and re-apply by hand for every word they add. It
survived one addition and failed on the next, in the same file, by the same
author, with the rule visible eight lines above the defect.

Two further reasons it stayed invisible:

- **The prose/source extension filter was hiding the evidence.** The two most
  natural instances — `reset-password.md`, `password_reset_test.py` — come back
  clean via the `.md`/`.py` exclusion, not via the pair logic. The suppression
  that removes a scanner's false positives also removes the symptoms that would
  have shown its logic was wrong.
- **The T-2897 suite was all fixtures.** Every leg pinned a known filename, so it
  could only ever catch bugs someone had already imagined. Fifteen green tests
  said nothing about the seventh word.

**Prevention:** the span rule is now enforced in code — all qualifier
occurrences are masked out of the name and a noun must appear in the residue —
so the overlap is structurally harmless rather than curated away. `password`,
`passwd` and `pass` are deliberately left in both lists, and
`tests/unit/secret_scan_span_rule.bats` leg (d) fails if that overlap is ever
tidied up, because an empty overlap would let the generative leg pass for the
wrong reason.

The generative leg is the actual prevention: it enumerates both word lists at
run time and probes every word alone and doubled, so a future list edit is
caught by construction. **It earned that claim during this task** — the first
version of the fix (split on the qualifier's first occurrence) passed every
fixture leg and was failed by the generative leg on `passwd-passwd`, which
exposed a second, more general form of the bug: a noun hiding inside a *second
qualifier occurrence*, e.g. `auth-password-policy.json`, where the spans are
genuinely disjoint and both words are qualifiers. Masking, not splitting, is
what closes that.

**Cross-project:** 832 hit the identical class in `tools/tracked-secret-artifacts.py`
and reported it on the DM rail at 502/503. Two exchanges are worth keeping:
their 502 named the wrong word (`credential`/`cred`) because they recognised the
shape in our report instead of running it against their own tree, and corrected
it at 503 to `password`/`passwd`. This task ran the probe before making any
claim about our instance — and the word turned out to be different again
(`password`/`pass`, the noun one character shorter than theirs). **Send the
shape; let the receiver measure their own instance.**

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

### 2026-08-09T14:47:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2898-secret-scanner-announced-pair-completes-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2682051a
- **Timestamp:** 2026-08-09T15:03:58Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-09T15:00:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
