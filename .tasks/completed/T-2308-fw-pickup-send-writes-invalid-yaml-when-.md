---
id: T-2308
name: "fw pickup send writes invalid YAML when --detail contains quotes or backslashes
  (cross-project bug P-002 from 100-Video-riper)"
description: >
  fw pickup send writes invalid YAML when --detail contains quotes or backslashes
  (cross-project bug P-002 from 100-Video-riper)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [lib/pickup.sh, tests/unit/lib_pickup.bats]
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
created: 2026-06-10T11:13:25Z
last_update: 2026-06-10T11:18:30Z
date_finished: 2026-06-10T11:18:30Z
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
  - ts: '2026-06-10T11:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-10T11:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 4
      F-RECALL: 1
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=4 (body:cross-machine); F-RECALL=1 
      (body:episodic-only); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2308: fw pickup send writes invalid YAML when --detail contains quotes or backslashes (cross-project bug P-002 from 100-Video-riper)

## Context

Cross-project pickup P-002 filed by `/opt/100-Video-riper-and-translation-app` agent
on 2026-06-09. `fw pickup send` writes the envelope at `lib/pickup.sh:564-578` using
a shell heredoc with YAML double-quoted scalars (`"$summary"`, `"$detail"`). YAML
double-quoted scalars treat `\` as escape lead-in and `"` as the scalar terminator —
so detail strings containing `"`, `\`, regex like `\d`/`\s`, or shell snippets produce
unparseable YAML. The receiving side's `fw pickup process` cannot load the envelope,
so the bug-reporting channel silently corrupts exactly the payloads that matter most
(stack traces, regex patterns, code snippets, file contents).

Source envelope (this very task's origin):
`.context/pickup/auto-deferred/P-002-bug-report.yaml`

Class match: L-005 (episodic YAML files breaking on regex content) — same YAML
double-quote scalar fragility surface, earlier instance in episodic generation.

## Acceptance Criteria

### Agent
- [x] `lib/pickup.sh:do_pickup_send` no longer uses shell heredoc YAML double-quoted scalars for user-controlled fields (`summary`, `detail`, `source_project`, `task_id`).
- [x] Envelope writer round-trips through a real YAML emitter (python3 yaml.safe_dump) — embedded `"`, `\`, newlines, and non-ASCII produce valid parseable YAML.
- [x] Post-write guard: after emitting the envelope, `do_pickup_send` re-reads it with `yaml.safe_load` and aborts non-zero if it fails to parse (P-002 fix recommendation #3 — never ship a corrupted envelope silently).
- [x] `tests/unit/pickup_send_yaml_safety.bats` ships, exercising: (a) `--detail` with embedded `"`, (b) `--detail` with `\d`/`\s` regex, (c) `--summary` with quote+backslash combination, (d) multi-line `--detail`. Each test asserts the resulting envelope `yaml.safe_load`s and the round-tripped `payload.detail` equals the input verbatim.
- [x] Existing `pickup_send_remote_session.bats` + `lib_pickup.bats` still pass (no regression on the canonical send path).
- [x] The two auto-deferred bugs (P-002, P-003) from `/opt/100-Video-riper-and-translation-app` move out of `auto-deferred/` once T-2308 ships — separate handoff (this task only fixes the YAML emitter; P-003 is a different bug filed as a separate task).

_(No Human ACs — deterministic bug fix with regression test.)_

<!-- removed Human header
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
bats tests/unit/pickup_send_yaml_safety.bats
bats tests/unit/pickup_send_remote_session.bats
bats tests/unit/lib_pickup.bats
bin/fw reviewer T-2308 2>&1 | grep -qE "Overall:.*PASS"

## RCA

**Symptom:** Cross-project agent at `/opt/100-Video-riper-and-translation-app` ran
`fw pickup send --type bug-report --summary x --detail '<text with " or \\>'` and
got an envelope written to `.context/pickup/inbox/P-NNN-bug-report.yaml` that fails
`yaml.safe_load` with `ScannerError: could not find expected ':'` (on embedded `"`)
or `ReaderError: unknown escape character 's'` (on `\s`). Receiving side's
`fw pickup process` cannot load the envelope; the channel silently corrupts any
report containing quotes, backslashes, code, or regexes.

**Root cause:** `lib/pickup.sh:do_pickup_send` lines 564-578 use a shell heredoc to
write YAML, with the user-controlled fields `$summary`, `$detail`, `$source_project`,
`$task_id` interpolated into YAML double-quoted scalars. YAML double-quoted scalars
treat `\` as an escape lead-in and `"` as the terminator — so any embedded `"` or
`\` produces unparseable YAML. The heredoc does shell expansion (correct) but does
NO YAML escaping (the bug).

**Why structurally allowed:** No post-write parse guard. The framework already has a
canonical pattern for this — episodic generation, audit YAML, fabric cards — but
the pickup writer was a 14-line heredoc that predated the convention. Three pre-emptive
layers were missing: (a) use a real YAML emitter, (b) post-write `yaml.safe_load`
sanity check, (c) test coverage exercising adversarial content. Sibling class L-005
(episodic YAML files breaking on regex content) had captured the same fragility
but the learning never propagated to other shell heredoc YAML writers.

**Prevention:**
1. **Direct fix** — replace the heredoc with a python yaml.safe_dump invocation;
   handles all special chars deterministically.
2. **Post-write guard** — every envelope re-loads through yaml.safe_load before
   `do_pickup_send` returns success. Silent corruption becomes a loud exit-non-zero.
3. **Test pin** — `pickup_send_yaml_safety.bats` exercises adversarial `"`, `\`,
   `\s`/`\d` regex, multi-line, and non-ASCII. Next instance of this class is caught
   at PR-time, not in production.
4. **Learning propagation** — file a learning that L-005's class extends to ANY
   shell-heredoc YAML writer, not just episodic generation. Suggested: cross-link
   to L-005 in this task's completion + audit any remaining shell-heredoc YAML
   writers in the codebase as a follow-on (`grep -rn 'cat.*<<.*EOF' lib/ agents/`).
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

### 2026-06-10T11:13:25Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2308-fw-pickup-send-writes-invalid-yaml-when-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-de27cc1c
- **Timestamp:** 2026-06-10T17:05:40Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 34
     - evidence: `bin/fw reviewer T-2308 2>&1 | grep -qE "Overall:.*PASS"`
### 2026-06-10T11:18:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
