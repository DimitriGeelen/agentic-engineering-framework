---
id: T-2693
name: "vendor-time upstream sentinel must not carry credentials"
description: >
  vendor-time upstream sentinel must not carry credentials

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
created: 2026-07-31T07:52:36Z
last_update: '2026-07-31T08:00:11Z'
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
  - ts: '2026-07-31T08:00:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-31T08:00:11Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2693: vendor-time upstream sentinel must not carry credentials

## Context

`bin/fw:479` writes the vendored upstream sentinel from `git remote get-url origin`
**verbatim**. When origin carries credentials in its userinfo, the vendor step copies them
into a tracked file — and `bin/fw:489` additionally echoes the full URL to stdout, so the
credential also lands in vendor logs and terminal scrollback.

That is the write path behind OBS-106. T-2692 made the credential *visible* to the scanner;
this task stops it being *written*, and clears the instance already in the tree.

The repair already exists in this codebase: `lib/consumer-recover.sh:47` strips URL
userinfo with `sed -E 's|^(https?://)[^/@]+@|\1|'` for exactly this shape. It was applied
on the recovery path and never on the vendor write path — a producer/consumer split of the
L-399 family: one side of a contract shipped, the other side left alone.

Stripping userinfo (rather than substituting a different host) is the deliberate choice —
it keeps the sentinel pointing at the same repository, and matches what the recovery path
already does, so the two agree instead of drifting.

**Sequencing note:** T-2692 makes `fw audit` FAIL while the credential is in the tree, and
`agents/git/lib/hooks.sh:844` turns an audit FAIL into a blocked push. So T-2692 and this
task land in one push. Rotation of the exposed token remains operator-owned (OBS-106) —
scrubbing the working tree does not un-disclose a value that has been mirrored publicly.

## Acceptance Criteria

### Agent
- [x] `bin/fw` redacts URL userinfo before writing `.upstream`, reusing the same
      transformation as `lib/consumer-recover.sh:47` rather than a second dialect of it
      — the implementation moved to `lib/url-credentials.sh` and both sides call it
- [x] The confirmation line printed at vendor-time shows the redacted URL, not the raw one
      (a credential echoed to a log is disclosed the same as one written to a file) —
      satisfied by construction: the variable it prints is now redacted at resolution
- [x] The live `.agentic-framework/.upstream` in this repo no longer contains a credential,
      and still names the same repository
- [x] `secret-scan.sh scan-tree` returns exit 0 with zero findings across the tracked tree
- [x] `fw audit` no longer reports a secret-scan failure, so the push gate clears
- [x] A test pins the redaction at the write path: a credentialed origin yields a
      credential-free sentinel, and a bare origin round-trips unchanged
- [x] The scrubbed sentinel is still functional for its one purpose — resolution
      precedence in `lib/upgrade.sh` reads it as a URL, and that read is unaffected
      (T-2232 suite 8/8, including the three precedence tests)

**Added during build** (see Evolution — these were not visible at filing):

- [x] Resolution **prefers the credential-free public mirror** over `origin`, matching the
      call `lib/consumer-recover.sh` already made under T-2232. Stripping alone would have
      left a private URL that no outside consumer can clone; preferring the mirror makes
      the sentinel both credential-free and *usable*
- [x] When the helper lib is absent the vendor step **refuses to write a sentinel** and says
      why, rather than falling back to a raw remote URL — fail-safe, not fail-open
- [x] `.secret-scan-allowlist` names the new fixture file individually rather than
      widening to a `tests/` blanket

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

timeout 300 bats tests/unit/test_url_credentials.bats
timeout 400 bats tests/unit/t2232_durable_in_consumer_upgrade.bats
timeout 300 bats tests/unit/test_secret_scan.bats
# fw vendor is consumer-facing (CLAUDE.md §Consumer-Facing Command Hygiene, T-1633).
timeout 600 bats tests/unit/upgrade_fresh_machine_simulation.bats
# The tracked tree carries no credential — the whole point of the task.
out=$(PROJECT_ROOT="$PWD" agents/git/lib/secret-scan.sh scan-tree 2>&1); [ -z "$out" ]
# The sentinel still names a repository (a scrub that emptied it would also pass a
# credential check, and would silently break consumer self-recovery).
grep -qE '^https?://[^[:space:]]+\.git$' .agentic-framework/.upstream

<!--
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

**Symptom:** a live OneDev token was committed to a tracked file (`.agentic-framework/.upstream:8`)
and mirrored to a public GitHub repo. OBS-106; disclosed since 2026-06-08.

**Root cause:** `bin/fw` recorded the vendor-time upstream by reading `git remote get-url
origin` **verbatim** into a tracked file, and echoing the same string to stdout. Nothing
in that path considered that a remote URL is a credential-bearing surface.

**Why structurally allowed — a producer/consumer split, L-399 family.** The framework
*already knew* about this exact hazard and had already solved it, twice, on the read side:
`lib/consumer-recover.sh` strips URL userinfo (`_cr_strip_credentials`) and prefers the
`github` remote over `origin` with the comment *"origin (often a private dev forge with
embedded PAT credentials)… prevents credentials from leaking into the dry-run recipe."*
That knowledge was applied where credentials were *displayed* and never where they were
*written*. One side of the contract shipped; the other was left alone — the same shape as
T-1890, where a bypass flag shipped on the hook side and was rejected by every consumer.

The deeper reason it survived: T-2232 introduced a **generated** file into a directory the
secret scanner blanket-exempted as "vendored duplicates". Writing the credential and hiding
it were introduced by different tasks months apart, and neither author could see the other
half. T-2692 fixed the hiding; this fixes the writing.

**Prevention (distinct from the fix):**
- The transformation now has **one implementation** (`lib/url-credentials.sh`) that both the
  read and write paths source, so the next fix to it cannot land on only one side. A test
  asserts `consumer-recover.sh` keeps no second `sed` dialect.
- `tests/unit/test_url_credentials.bats` (11 tests) pins strip, mirror-preference, SSH
  non-mangling, and — the regression guard for this specific bug — that `bin/fw` contains
  **zero** occurrences of `remote get-url origin`.
- Missing-helper behaviour is **fail-safe**: no sentinel plus a stderr reason, never a raw
  URL. A fail-open fallback would have re-created the bug silently on any stale payload.
- Preferring the public mirror means even a future strip failure records a URL that has no
  credential to leak.

**Not prevented here:** the token is in git history and public mirrors. Rotation is
operator-owned and is the only real remedy — a scrub is hygiene, not containment.

## Evolution

### 2026-07-31 — the fix already existed, on the wrong side

- **What changed:** filed expecting to add a redaction. Found the redaction already written
  and shipped in `lib/consumer-recover.sh`, along with the *reasoning* about PATs in origin
  URLs. The task turned from "write a fix" into "apply a decision the codebase had already
  made" — which is why the implementation moved to a shared lib rather than being copied.
- **Plan impact:** two ACs added mid-build (mirror-preference, fail-safe-on-missing-helper).
  Preference was not in the original plan; stripping alone would have produced a
  credential-free but *unusable* private URL, trading a security bug for a functional one.
- **Triggered:** `lib/url-credentials.sh` (new shared component, fabric-registered);
  fixture update to `t2232_durable_in_consumer_upgrade.bats`, whose synthetic framework
  tree had to grow the new dependency.

### 2026-07-31 — the fixture told me the failure mode

- **What changed:** three T-2232 tests went red because the synthetic framework lacks
  `lib/`. That was not just a fixture gap — it was the question "what does vendor do when
  the helper is missing?" asked by the test suite before I had asked it myself. The honest
  answer (refuse, loudly) is now the shipped behaviour.
- **Plan impact:** none to scope; it changed the implementation from a bare `source` to a
  guarded one.

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

### 2026-07-31T07:52:36Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2693-vendor-time-upstream-sentinel-must-not-c.md
- **Context:** Initial task creation
