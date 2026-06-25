---
id: T-2353
name: "audit.sh post-emit hook — convert WARN/FAIL to bugfix tasks (T-2352 S1)"
description: >
  audit.sh post-emit hook — convert WARN/FAIL to bugfix tasks (T-2352 S1)

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: [T-2352, T-1550]
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
created: 2026-06-12T12:22:42Z
last_update: 2026-06-25T22:30:47Z
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
  - ts: '2026-06-13T18:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-13T18:00:05Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal); F-AUTONOMY=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2353: audit.sh post-emit hook — convert WARN/FAIL to bugfix tasks (T-2352 S1)

## Context

Slice 1 of T-2352 (audit findings → RCA tasks). Implements the post-emit hook in `audit.sh` that parses its own WARN/FAIL output and creates one `workflow_type: bugfix` task per finding, deduplicated by sha1(normalized text). Reuses existing T-1550 RCA gate at close. Spec: `docs/reports/T-2352-audit-findings-to-tasks.md` §5.

Spike A from T-2352 §Exploration Plan validates the emit format BEFORE this slice's implementation (~30 min) — if the regex `^(WARN|FAIL):` doesn't cover real emits, the slice's parsing AC needs widening.

## Acceptance Criteria

### Agent
- [x] Spike A complete: audit.sh already maintains a structured `FINDINGS` array (`warn()`/`fail()` push `LEVEL|TEXT|MITIGATION`), so the emitter consumes that buffer (4th `|SECTION` field added) rather than regex-parsing stdout — the parse AC is *widened* from the `^(WARN|FAIL):` regex assumption (Spike A's purpose). Normalization stable across counts: `sha1`("14 stale tasks") == `sha1`("12 stale tasks") (smoke + bats)
- [x] Emit function `audit_emit_findings_as_tasks` added — factored into `lib/audit_emit.sh` (sourceable so bats fixture-tests it without the >5min real audit) and called from `agents/audit/audit.sh`; computes `sha1(normalized_text)` per WARN/FAIL
- [x] Dedupe scan: greps `^audit_finding_hash: <sha1>$` across `.tasks/{active,completed}/` and skips already-filed findings (bats cases d + e)
- [x] On new finding: invokes `bin/fw task create --type build` (⚠ `bugfix` is **not** a valid workflow_type — see §Decisions; build + bug-class title trips the T-1550 RCA gate, the spec's intent), then injects `audit_severity:`, `audit_finding_hash:`, `audit_run_ts:` frontmatter; `tags: [audit-finding, severity:<warn|fail>, section:<slug>]`, `horizon: now`, body carries finding + timestamp + section
- [x] `--emit-tasks` CLI flag on `bin/fw audit` controls emission (default OFF — opt-in until S3 digest calibration)
- [x] `--dry-run` flag shows would-create lines without writing (bats case f)
- [x] Bats test `tests/unit/test_audit_emit_tasks.bats` covers (a) 0 findings, (b) 1 FAIL→fail, (c) 1 WARN→warn, (d) dedupe re-run, (e) mixed 2 new + 1 hashed, (f) dry-run — 6/6 green
- [x] Documentation in `agents/audit/AGENT.md` §Emit-tasks mode describes opt-in flag + dedupe semantics

### Human
- [ ] [REVIEW] Real audit emission reads sanely — output of `bin/fw audit --emit-tasks --dry-run 2>&1 | head -30` is human-parseable and the would-create titles read clearly
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw audit --emit-tasks --dry-run 2>&1 | head -30`
  2. Read the "would create" lines for each WARN/FAIL
  3. Sample one and ask: would a future agent reading this task understand the finding without re-running audit?
  **Expected:** Each would-create line cites section + finding excerpt; titles are unambiguous
  **If not:** Adjust title template or include more section context in body

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
# stdin on. `echo "$out"` is small and immediate; grep scans the whole captured
# string anyway, so the tail-3 was cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.
# NOTE: real `bin/fw audit` takes >5min — verification uses the fixture-driven bats
# suite (which exercises the dry-run + create + dedupe paths) plus static greps. The
# emit logic is factored into lib/audit_emit.sh precisely so it is testable without
# running the full audit.
bats tests/unit/test_audit_emit_tasks.bats
bash -n agents/audit/audit.sh
grep -q "audit_emit_findings_as_tasks" lib/audit_emit.sh
grep -q "audit_emit_findings_as_tasks" agents/audit/audit.sh
grep -q "emit-tasks" agents/audit/audit.sh
grep -q "Emit-tasks mode" agents/audit/AGENT.md

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

## Decisions

### 2026-06-26 — workflow_type for emitted tasks (spec said `bugfix`)
- **Chose:** `--type build` + bug-class title (`audit <warn|fail>: …`) + `audit-finding` tags + `audit_severity:` frontmatter.
- **Why:** `bugfix` is **not** a valid workflow_type (`lib/enums.sh`: specification design build test refactor decommission inception). build + bug-class title/tags is exactly what the existing **T-1550 RCA gate** keys on, delivering the spec's stated intent ("reuses existing T-1550 RCA gate at close") without inventing a new enum.
- **Rejected:** adding `bugfix` to `VALID_TYPES` — cross-cutting enum change (blast radius across create-task, audit, render) for no behavioural gain; `bugfix` is not a lifecycle stage.

### 2026-06-26 — emit logic factored into `lib/audit_emit.sh` (not inlined in audit.sh)
- **Chose:** sourceable lib `audit_emit_findings_as_tasks <findings_file> <dry_run>`, consuming a findings file rather than audit.sh's in-memory `FINDINGS` array.
- **Why:** the real `fw audit` takes >5min — inlining the logic would force every test to run the full audit. A file-driven sourceable function is fixture-testable in milliseconds (6 bats cases). audit.sh writes its `FINDINGS` buffer to a temp file and calls it.
- **Rejected:** regex-parsing audit stdout (Spike A finding: the structured `FINDINGS` array already exists and is more reliable than `^(WARN|FAIL):`).

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

### 2026-06-12T12:22:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2353-auditsh-post-emit-hook--convert-warnfail.md
- **Context:** Initial task creation
