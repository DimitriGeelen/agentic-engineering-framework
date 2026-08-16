---
id: T-2477
name: "harden BVP YAML-fallback timestamp round-trip (OBS-085 latent leg)"
description: >
  OBS-085 latent leg. lib/bvp.sh (~836-869) and agents/termlink/bvp-estimator/estimator.py
  (4 sites) round-trip task frontmatter via a ruamel-preferred path with a PyYAML
  safe_load->safe_dump FALLBACK. The fallback corrupts unquoted ISO ...Z timestamps
  (datetime reformat). Port the resolver-stripped SafeLoader from lib/integrate.py:_str_loader
  into the PyYAML fallback so it is correct regardless of whether ruamel is installed.
  Add a test exercising the fallback with ruamel forced absent, asserting last_update
  ...Z survives. See OBS-085, L-495.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/termlink/bvp-estimator/estimator.py, lib/bvp.sh]
related_tasks: [T-2473, T-2476]
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
created: 2026-06-24T07:39:31Z
last_update: '2026-08-16T22:25:07Z'
date_finished: 2026-06-24T11:11:11Z
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
  - ts: '2026-08-16T22:25:07Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=1 
      (body:episodic-only); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2477: harden BVP YAML-fallback timestamp round-trip (OBS-085 latent leg)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Status — COMPLETE (2026-06-24)

All four ACs done and verified live (the WIP handover from the prior budget-capped
session is resolved):
- `estimator.py`: `_str_safe_load` helper (:58) + 4 frontmatter fallback sites swapped (:2405/:2612/:2740/:2767). Read-only `safe_load(m.group(1))` (~:205) left untouched (not a round-trip).
- `lib/bvp.sh`: same helper in the `<<'PYEOF'` block (:65) + confirm fallback swapped (:852).
- Syntax: `bash -n lib/bvp.sh` OK; `py_compile estimator.py` OK; bvp.sh PYEOF block extracted+compiled OK.
- Regression test `tests/unit/t2477_bvp_yaml_timestamp_fallback.bats` — 3/3 green.
- OBS-085 → `resolved`; prevention names T-2477 + the pinning test.

## Acceptance Criteria

### Agent
- [x] A resolver-stripped SafeLoader (the `_str_loader` pattern from lib/integrate.py) is applied to the PyYAML `safe_load` fallback in lib/bvp.sh (the frontmatter round-trip ~line 836) so unquoted ISO `...Z` timestamps survive when ruamel is absent. — `_str_safe_load` at lib/bvp.sh:65 (PYEOF block), confirm fallback swapped at :852.
- [x] Same fix applied to the 4 PyYAML `safe_load` fallback sites in agents/termlink/bvp-estimator/estimator.py (frontmatter round-trips at ~2389/2596/2724/2751). — helper at estimator.py:58; 4 sites swapped at :2405/:2612/:2740/:2767 (the read-only `safe_load(m.group(1))` ~line 205 left untouched — not a round-trip).
- [x] A regression test exercises the PyYAML fallback path with ruamel forced unavailable and asserts `last_update: <ISO>Z` round-trips unchanged (not reformatted to a datetime). — tests/unit/t2477_bvp_yaml_timestamp_fallback.bats, 3/3 green (estimator helper + control + end-to-end `fw bvp confirm`).
- [x] py_compile / bash -n clean on every edited file; OBS-085 prevention line updated to point at this task as the closing fix. — `bash -n lib/bvp.sh` OK, `py_compile estimator.py` OK, PYEOF block extracted+compiled OK; OBS-085 `status: watching`→`resolved`, prevention names T-2477 + the pinning test.

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

bash -n lib/bvp.sh
python3 -m py_compile agents/termlink/bvp-estimator/estimator.py
grep -q "_str_safe_load" lib/bvp.sh
grep -q "_str_safe_load" agents/termlink/bvp-estimator/estimator.py
bats tests/unit/t2477_bvp_yaml_timestamp_fallback.bats

## RCA

**Symptom:** On hosts without `ruamel.yaml`, `fw bvp confirm` (and the BVP
estimator) silently rewrite a task's unquoted ISO timestamp `2026-06-02T00:00:00Z`
to `2026-06-02 00:00:00+00:00` whenever they round-trip frontmatter — churning
`created:`/`last_update:` and breaking `...Z`-expecting greps/readers.

**Root cause:** PyYAML's `SafeLoader` carries an implicit
`tag:yaml.org,2002:timestamp` resolver that auto-types unquoted ISO datetimes to
`datetime`; `safe_dump` then re-emits the datetime in its own format. The BVP code
prefers ruamel (which preserves the original string) but falls back to plain
`safe_load`/`safe_dump`. The fallback corrupts — masked wherever ruamel is present
(0.19.1 on this host), so it was latent here and only fires on ruamel-less hosts.

**Why structurally allowed:** the round-trip's correctness depended on an
environment-presence accident (ruamel installed) rather than on the code itself —
a Portability-directive violation. No test exercised the fallback path with ruamel
absent, so the latent leg never surfaced. The class was only caught because
lib/integrate.py used plain PyYAML with no ruamel guard at all (corrupted on every
host) → T-2473 found and fixed that leg, registering OBS-085 for the latent siblings.

**Prevention:** ported the resolver-stripped `_str_safe_load` loader into the
PyYAML fallback in both surfaces, so correctness no longer depends on ruamel being
installed. Pinned by `tests/unit/t2477_bvp_yaml_timestamp_fallback.bats`, which
forces ruamel absent (fake `ruamel` package raising ImportError) and includes a
control test asserting plain `safe_load` *would* corrupt — so the regression test
provably detects the bug, not just the absence of it. OBS-085 → resolved.

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

### 2026-06-24T07:39:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2477-harden-bvp-yaml-fallback-timestamp-round.md
- **Context:** Initial task creation

### 2026-06-24T10:10:49Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-85f3cc7e
- **Timestamp:** 2026-06-24T11:11:14Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `bats tests/unit/t2477_bvp_yaml_timestamp_fallback.bats`

### 2026-06-24T11:11:11Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
