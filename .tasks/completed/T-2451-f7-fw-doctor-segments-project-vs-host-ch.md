---
id: T-2451
name: "F7: fw doctor segments [project] vs [host] checks — project-health-first + one-line project verdict (T-2441 dogfood)"
description: >
  F7: fw doctor segments [project] vs [host] checks — project-health-first + one-line project verdict (T-2441 dogfood)

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
created: 2026-06-21T11:59:19Z
last_update: 2026-06-21T13:03:17Z
date_finished: 2026-06-21T13:03:17Z
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

# T-2451: F7: fw doctor segments [project] vs [host] checks — project-health-first + one-line project verdict (T-2441 dogfood)

## Context

T-2441 dogfood F7: from a fresh consumer (`/opt/505`), `fw doctor`'s 8 warnings were mostly **not about
that project** (`Cron registry edited but not generated: /opt/999-…`, `Mirror divergence origin↔github`,
`Global install … 261MB`, `~/.local/bin/fw symlinks to stale …`). A new user cannot tell whether
**their** project is healthy. Host-level checks already carry a `[host]` prefix (bin/fw:796-799) and
there's a scope breakdown (`($host_warnings host-level)`, bin/fw:2202) — the substrate exists; what's
missing is **visual segmentation + project-first ordering + a one-line project verdict**.

**Scope note:** `fw doctor` is a large function in bin/fw (~760-2210). Keep the change additive where
possible — a project-health summary line + clearer `[project]`/`[host]` grouping — rather than a risky
full reorder. Verify via `fw doctor` output (grep for the new verdict line + section markers). Run the
existing doctor bats green.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] AC1 — `fw doctor` output visually segments project-owned findings from `[host]`-tagged findings,
      with project health surfaced first. **Done:** a project-health verdict block renders BEFORE the
      total summary, followed by an explicit `↳ N host-level finding(s) excluded` line. Project-first
      ordering pinned in source (test "project verdict precedes the overall summary").
- [x] AC2 — a one-line project verdict is emitted so a fresh-consumer operator can read their project's
      health at a glance, independent of host noise. **Done:** live `bin/fw doctor` rendered
      `Project /opt/.../inception-gov-payload-mediation: 24 project warning(s), 0 failure(s)` (host noise
      excluded; 24 project + 4 host = 28 total). `project_warnings = warnings − host_warnings`; failures
      are all project-scope. See Decisions re: verdict format vs the literal "N ok / M warn / K fail".
- [x] AC3 — existing doctor tests stay green; a new assertion pins the verdict line + segmentation.
      **Done:** 6/6 existing source-level pins green + 4 new F7 pins green (verdict line, host-exclusion,
      project-first ordering, project_warnings computation). Edit is purely additive before the unchanged
      total summary; live run confirmed exit 0, `[host]` tags intact, total summary still last.

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

bash -n bin/fw
out=$(bats -f "F7" tests/unit/test_doctor_scope_tags.bats 2>&1); echo "$out" | grep -qE "^ok 4 " && ! echo "$out" | grep -q "^not ok"
grep -q 'project_warnings=$((warnings - host_warnings))' bin/fw
grep -q "host-level finding(s) excluded" bin/fw

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

### 2026-06-21 — Verdict format: warn/fail counts + healthy marker, not literal "N ok / M warn / K fail"
- **Chose:** `Project <root>: N project warning(s), K failure(s)` (or `healthy` when 0/0), plus a
  `↳ M host-level finding(s) excluded` line. Counts derive from existing `warnings`/`host_warnings`/`issues`.
- **Why:** the AC's "N ok / M warn / K fail" was illustrative ("e.g."). The actionable signal a fresh
  consumer needs is "are there warnings/failures about MY project, ignoring host noise" — the OK count
  adds no decision value. The healthy-marker form reads cleaner at a glance than a raw "24 ok".
- **Rejected:** literal OK-counting — `do_doctor` does not track an OK counter; capturing one would mean
  instrumenting 30+ inline `echo OK` sites, a high-blast change that violates the task's additive scope
  note ("keep the change additive... rather than a risky full reorder"). Not worth it for a cosmetic count.

### 2026-06-21 — Test at source level, not by running full `fw doctor`
- **Chose:** four fast source-grep pins (verdict line, host-exclusion line, project_warnings computation,
  project-first ordering) + a live `bin/fw doctor` capture recorded as the real-world proof.
- **Why:** `fw doctor` takes ~150s/run and is network-coupled (mirror/reachability probes) — running it
  in a unit test made the bats file exceed even a 400s timeout and is itself the F6 (T-2452) pain. Source
  pins are deterministic, CI-safe, and pin exactly the verdict-line + segmentation AC3 asks for.
- **Rejected:** behavioural bats that shell out to `fw doctor` (slow, flaky, network-dependent); a cached
  single-run helper via `BATS_FILE_TMPDIR` (still timed out — cache unreliable in this bats version).

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-06-21T11:59:19Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2451-f7-fw-doctor-segments-project-vs-host-ch.md
- **Context:** Initial task creation

### 2026-06-21T12:00:25Z — status-update [task-update-agent]
- **Change:** status: started-work → captured
- **Change:** horizon: now → next

### 2026-06-21T12:38:20Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d02416d5
- **Timestamp:** 2026-06-21T13:03:18Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-21T13:03:17Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
