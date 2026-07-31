---
id: T-2692
name: "secret-scan blind to URL-embedded credentials (positional, not issuer-prefixed)"
description: >
  secret-scan blind to URL-embedded credentials (positional, not issuer-prefixed)

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
created: 2026-07-31T07:43:43Z
last_update: '2026-07-31T07:45:09Z'
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
  - ts: '2026-07-31T07:45:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-31T07:45:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2692: secret-scan blind to URL-embedded credentials (positional, not issuer-prefixed)

## Context

OBS-106 (T-2691) found a live OneDev token committed at `.agentic-framework/.upstream:8`
since 2026-06-08 — while `fw audit` reported **"Secret scan: tracked tree clean"** for the
whole 7 weeks.

The catalogue (`.secret-scan-patterns`) is **issuer-prefix indexed**: every one of its 11
patterns keys on a vendor marker the issuer stamps into the secret — `AKIA`, `ghp_`,
`sk-ant-`, `xox[abprs]-`, `AIza`, `eyJ`. Its own header codifies this as policy: *"prefer
specific (e.g. AKIA prefix) over generic"*.

A credential in URL userinfo (`scheme://<token>@host`) carries **no issuer marker at all**
— it is identifiable by *position within a URL*, not by shape. So this is not a missing
pattern; it is a class the catalogue's indexing strategy cannot reach. Sibling to T-2690's
skip hole and G-071: a detector reporting clean on a surface it never examined.

Scope of this task is **detection only**. Scrubbing the live credential from the working
tree and stopping the vendor write-path from re-introducing it are separate tasks
(one bug = one task); rotation is operator-owned (OBS-106).

## Acceptance Criteria

### Agent
- [x] `.secret-scan-patterns` gains a positional URL-credential class covering **both**
      userinfo forms — colon-separated (a user and a password before the `@`) and a bare
      opaque token as the whole userinfo
      <!-- Deliberately NOT written as a literal URL: the colon form would match the very
           pattern this AC specifies, tripping the scanner on its own acceptance criterion.
           That is the L-519 class the third AC below pins. -->

- [x] `secret-scan.sh scan-tree` exits non-zero on the live exposure and names
      `.agentic-framework/.upstream` in its output (the detector sees what audit missed)
- [x] The new pattern texts do **not** match their own definition lines in the catalogue
      (L-519: a text match must not be satisfied by prose describing the structure)
- [x] No false positives: the tracked-tree finding set for the new class is exactly the
      one known instance — the count is asserted, not just its non-emptiness
      ("a counted tolerance, not a suppression list")
- [x] Benign short userinfo (short `git@` / `user@` remotes) does not fire
- [x] A unit test pins all of the above and fails the day the class regresses
- [x] The audit-horizon consequence is established and stated before shipping: whether
      a secret-scan FAIL blocks `fw push` / pre-push, so the operator is not surprised
- [x] **Second cause found mid-build and closed:** the allowlist blanket
      `^\.agentic-framework/` is narrowed so vendor-time-**generated** files are scanned
      while copied payload stays exempt; a test pins both halves

## Evidence

**The pattern alone was not enough — this is the finding of the task.** After adding both
patterns, `scan-tree` still returned **exit 0**. `git grep` found the credential directly,
so the miss was between the two: the allowlist blanket-exempted the whole vendored tree.

```
# after patterns only
exit=0

# after narrowing the allowlist blanket
exit=1
  [URL Embedded Token] .agentic-framework/.upstream:8:https://<REDACTED>@onedev…/agentic-engineering-framework.git
finding count: 1
```

Exactly one finding, the known true positive, zero false positives across the tracked tree.

**Audit-horizon consequence (AC 7), established before shipping:** `agents/git/lib/hooks.sh:844`
maps audit exit 2 → **push blocked** (`ERROR: Push blocked - audit has FAILURES`), and the
secret scan runs in the pre-push structure section. So this change makes the repo unpushable
until the credential leaves the tracked tree. That is correct and intended — but it is why
the write-path fix + tree scrub (T-2693) lands in the same push rather than later.

## Verification

# Durable behaviour, pinned by fixtures — deliberately NOT asserting the live finding
# count, which becomes 0 once T-2693 scrubs the credential.
timeout 300 bats tests/unit/test_secret_scan.bats
out=$(grep -c '^URL ' .secret-scan-patterns); [ "$out" = "2" ]
# The blanket must not come back: an exact-match line would re-hide the class.
! grep -qE '^\^\\\.agentic-framework/\$?$' .secret-scan-allowlist

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

<!-- Verification lives above, next to the Evidence it rests on.

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
# stdin on. `echo "$out"` is small and immediate; grep scans the whole captured
# string anyway, so the tail-3 was cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.
-->

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

**Symptom:** `fw audit` reported `[PASS] Secret scan: tracked tree clean` on every run for
7 weeks (2026-06-08 → 2026-07-31) while a live OneDev token sat in a tracked file. The
false green is the defect; the credential is OBS-106 and is the operator's to rotate.

**Root cause — two independent causes, either alone sufficient.** This matters: I found
cause 1, fixed it, and the scan still returned exit 0. Had I stopped at the pattern and
trusted it, the task would have shipped a "fix" that changed nothing.

1. **Issuer-indexed catalogue.** All 11 patterns key on a marker the *issuer* stamps into
   the secret (`AKIA`, `ghp_`, `sk-ant-`, `xox…`, `AIza`, `eyJ`). A credential in URL
   userinfo carries no issuer marker; it is identified by *position within a URL*. No
   issuer prefix can reach that class — not a missing pattern, a class the indexing
   strategy excludes by construction. The catalogue header codified the exclusion as
   policy: *"prefer specific (e.g. AKIA prefix) over generic."*
2. **Blanket path allowlist.** `^\.agentic-framework/` exempted the entire vendored tree,
   on the rationale *"the parent project scans the real source files."* That holds for
   files the vendor step **copies**; it is false for files it **generates**. `.upstream`
   is written at vendor-time from the framework's git origin URL and exists nowhere else,
   so "scanned at its real source" resolves to *scanned nowhere*.

**Why structurally allowed:** both causes are the same shape — a *scope* decision made for
a good reason, then never re-examined as the scanned surface changed. The allowlist comment
argued correctly about duplicates and was simply never revisited when T-2232 started
generating a file into that directory. Neither cause is a coding error; both are unasked
questions. Same family as T-2690's skip hole and G-071: the detector reported on a surface
it had silently excluded, and present/absent output cannot distinguish *clean* from
*never looked*.

**Prevention (distinct from the fix):**
- `tests/unit/test_secret_scan.bats` gains 7 tests. The load-bearing one asserts that
  `.agentic-framework/.upstream` **is** scanned while `.agentic-framework/lib/…` is **not**
  — restoring the blanket fails that test rather than silently re-hiding the class.
- The self-match test (L-519) blocks the usual bad repair: when a pattern trips on its own
  catalogue, the reflex is to allowlist the catalogue, which re-creates a blind spot.
- The allowlist now enumerates the copied payload instead of blanketing the directory, so
  a **new** top-level vendored entry is scanned until someone deliberately exempts it —
  fail-loud is the right default for a secret scanner.
- Catalogue header rewritten to name both indexing axes, so the next author adding a
  positional-class secret is not steered by "prefer specific over generic" into omitting it.

**Not prevented here (named, not hand-waved):** the credential is still in git history and
still in the working tree until T-2693; rotation is operator-owned. A detector cannot
un-disclose a mirrored secret.

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

### 2026-07-31T07:43:43Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2692-secret-scan-blind-to-url-embedded-creden.md
- **Context:** Initial task creation
