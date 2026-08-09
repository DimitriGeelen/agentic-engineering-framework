---
id: T-2897
name: "Secret scan is content-keyed so it cannot see self-generated secrets; nothing
  reads filenames"
description: >
  Secret scan is content-keyed so it cannot see self-generated secrets; nothing reads
  filenames

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/git/lib/secret-scan.sh]
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
created: 2026-08-09T11:45:21Z
last_update: 2026-08-09T12:09:00Z
date_finished: 2026-08-09T12:09:00Z
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
  - ts: '2026-08-09T12:00:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-09T12:00:14Z'
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

# T-2897: Secret scan is content-keyed so it cannot see self-generated secrets; nothing reads filenames

## Context

Split from T-2896 (one bug = one task). T-2896 stops the Watchtower signing key from being
committed. This one is about why nothing noticed for two months that it *was*.

`agents/git/lib/secret-scan.sh` matches file **content** against vendor-prefixed
credentials — `AKIA…`, `ghp_…`, `sk-ant-…`, `-----BEGIN`. Its header states that scope
deliberately, and for third-party credentials it is a good choice.

`secrets.token_hex(32)` produces 64 bare hex characters. No prefix, no vendor, no `key =`
assignment, nothing to anchor a pattern on. **The one class of secret the framework is
guaranteed to produce is the class a content scanner is structurally guaranteed to miss** —
"carries no third-party fingerprint" is precisely what self-generated means. Adding another
pattern cannot close this; only a second axis can.

The available axis is the one nothing reads: **filenames**. `.fw-secret-key` announced
exactly what it was, in its name, for the entire window. Detecting it needs no entropy
analysis, no gitleaks, no vendor catalogue — just `git ls-files`.

This is L-521 (*"a detector's indexing strategy, not its pattern count, determines what it
can see"*) in a new surface. The failure mode is a **false green**: `[PASS] Secret scan:
tracked tree clean` printed on every audit across 832's two-month exposure, which is why it
ran to two months rather than two days — a red line gets looked at, a green line that
asserts nothing looks identical to one that asserts everything.

832 has shipped their version at `321e76a6` (`tools/tracked-secret-artifacts.py`, 13/13
teeth, clean over 5562 files with an empty allowlist). Refs only, per OBS-108 — read the
shape, do not copy bytes.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] A name-axis check reads `git ls-files` and flags tracked files whose **name** marks
      them as credential material, independent of content
- [x] Two classes, and the weaker one is labelled as the heuristic it is:
      DEFINITIVE (exact name / extension — `.fw-secret-key`, `*.pem`, `id_rsa`) and
      ANNOUNCED (secrecy word × credential noun), so a maybe never reads as a certainty
- [x] `token` is **not** a standalone signal — 832 measured 17 matches on their tree, every
      one a false positive (token-budget reports, design tokens, a CSRF-token RCA). It
      survives only as the noun half of a pair that also carries a secrecy word
- [x] Teeth: a test asserts the check fires on `.context/working/.fw-secret-key` **at its
      real path**, and discriminates tracked from untracked — an untracked key is not a leak
- [x] False-positive control: the check stays silent on `agents/git/lib/secret-scan.sh` and
      on any `secrets_store`-style source file, so it cannot be reverted for crying wolf
- [x] Runs clean over this repo with an empty allowlist — a check that needs exemptions on
      day one has the wrong threshold
- [x] Wired where a false green was printed: the same surface that emitted
      `[PASS] Secret scan: tracked tree clean` reports the name axis too, so the PASS line
      means both axes passed rather than one
- [x] **Added during build, beyond the filed scope:** also wired into `scan_staged`, so the
      pre-commit hook *refuses* the commit that publishes a key rather than only reporting
      it afterwards. Gated on newly-**added** paths (`--diff-filter=A`), not on every touch
      of an already-accepted path — a gate that re-fires on each edit gets bypassed by habit

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
out=$(bats tests/unit/test_secret_scan.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
PROJECT_ROOT=$PWD bash agents/git/lib/secret-scan.sh scan-names

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

**Symptom:** `[PASS] Secret scan: tracked tree clean` on every audit across a two-month
window in which a signing key was tracked and pushed to a public mirror (832's tree, rail
498). Not a missed alert — an asserted all-clear.

**Root cause:** one axis. The scanner indexes file *content* against vendor-prefixed
credentials. `secrets.token_hex(32)` is 64 bare hex characters and carries no vendor
fingerprint by definition, so no addition to the pattern catalogue could ever have caught
it. The scanner was not misconfigured or incomplete; it was complete along an axis the
secret does not lie on.

**Why structurally allowed:** the check's own scope statement made it look handled. Its
header documents "vendor-prefixed credentials" as a deliberate choice, and that choice is
defensible — but a scope note reads as *coverage* to everyone downstream, and the PASS line
it emits does not say which axis passed. A green that asserts one axis is textually
identical to a green that asserts all of them, which is why this ran to two months instead
of two days: red lines get looked at, greens do not.

**Prevention:** the name axis (`scan_names`), wired into `scan_tree` — the exact function
whose verdict line was the false green — so that PASS now means both axes. Also wired into
`scan_staged`, so the pre-commit hook refuses the commit rather than reporting the leak
afterwards. `tests/unit/secret_scan_name_axis.bats` (15) pins it, with three properties
that matter more than the count: it fires on the real filename at its real path; it
discriminates tracked from untracked (an untracked key is the *correct* end state of
T-2896, and flagging it would train people to ignore the check); and it stays silent on
`secret-scan.sh` itself, which is what keeps a check from being reverted for crying wolf.

**Found during build, worth recording:** the first cut listed `credential` as both the
qualifier and the noun of the ANNOUNCED pair, so the single word "credentials" satisfied
the pair alone and the scan fired on three fabric cards describing credential-handling
*source*. A pair one word can complete is a single-word match wearing a pair's clothes —
the same shape as the bare-`token` noise 832 measured at 17/17. Caught by running it over
the live tree with an empty allowlist before writing any test, which is also the AC that
forced the run.

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

### 2026-08-09T11:45:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2897-secret-scan-is-content-keyed-so-it-canno.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-485cb0c6
- **Timestamp:** 2026-08-09T12:11:30Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-09T12:09:00Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
