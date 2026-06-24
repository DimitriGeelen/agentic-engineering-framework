---
id: T-2476
name: "investigate PyYAML timestamp round-trip corruption class — register concern, fix if systemic"
description: >
  investigate PyYAML timestamp round-trip corruption class — register concern, fix if systemic

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
created: 2026-06-24T07:34:55Z
last_update: 2026-06-24T07:40:41Z
date_finished: 2026-06-24T07:40:41Z
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

# T-2476: investigate PyYAML timestamp round-trip corruption class — register concern, fix if systemic

## Context

Surfaced while building T-2473 (union resolver): PyYAML's implicit timestamp
resolver parses unquoted ISO `2026-06-02T00:00:00Z` to a `datetime` on `safe_load`
and re-emits it as `2026-06-02 00:00:00+00:00` on `safe_dump` — different text,
breaks `...Z`-expecting readers and churns task frontmatter. T-2473 fixed its own
path with a custom loader; this task determines whether the SAME class exists at
other YAML round-trip sites in the framework, registers the flaw as a concern
(governance: register first), and files a fix task only if systemic. Governance
violation being remediated: T-2473 folded this flaw into a feature task and buried
it in the completion report instead of registering it. Sibling: L-385 (YAML
single-quoted-scalar writer hazard).

## Acceptance Criteria

### Agent
- [x] Every `yaml.safe_dump`/`yaml.dump` site in lib/ agents/ web/ bin/ is enumerated, and for each, classified: does it round-trip (load→dump) a file whose schema contains unquoted ISO `...Z` timestamps (task .md frontmatter, decisions.yaml, etc.)? Evidence: the grep + per-site verdict.
- [x] A concern is registered in `.context/concerns.yaml` for the timestamp-round-trip corruption class (or, if a matching entry already exists e.g. under L-385, cross-linked rather than duplicated).
- [x] A learning is captured (`fw context add-learning`) for the class: "PyYAML safe_load→safe_dump silently reformats unquoted ISO timestamps; use a resolver-stripped loader for any governance/task YAML round-trip."
- [x] Verdict recorded in this task's RCA: SYSTEMIC (other corrupting sites exist → fix task filed with id) or CONTAINED (only T-2473's path round-tripped these schemas, now fixed → no further task).

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

**Verdict: SYSTEMIC but LATENT.**

**Symptom:** PyYAML reformats unquoted ISO `2026-06-02T00:00:00Z` to `2026-06-02 00:00:00+00:00` on a `safe_load`→`safe_dump` round-trip, silently rewriting task-frontmatter / decisions timestamps.

**Enumeration (AC1):** ~60 `yaml.dump`/`safe_dump` sites across lib/ agents/ web/ bin/. Only round-trips of schemas with **unquoted ISO `...Z`** are at risk — task `.md` frontmatter and decisions.yaml. Most sites are safe: they dump *freshly-built* dicts (config, cron registry, bus envelopes, audit rollups, fabric cards) where timestamps are written as already-quoted strings or generated fresh, never re-loaded-then-redumped. The frontmatter round-trip sites are: **lib/bvp.sh:836→869** (BVP confirm) and **agents/termlink/bvp-estimator/estimator.py:2389/2596/2724/2751** (BVP estimator) — and **lib/integrate.py** (the union resolver, now fixed).

**Root cause:** PyYAML's SafeLoader carries an implicit `tag:yaml.org,2002:timestamp` resolver that auto-types unquoted ISO datetimes. The two BVP families use a ruamel-preferred path with a `yaml.safe_load`→`yaml.safe_dump` **fallback**; the fallback corrupts. ruamel round-trip (load+dump together) preserves the original string, so the corruption is **masked wherever ruamel is installed** (present 0.19.1 here) — latent, not firing on this host. integrate.py used plain PyYAML with **no** ruamel guard → it corrupted on every host, which is exactly how the class surfaced.

**Why structurally allowed:** no test exercises the BVP PyYAML fallback with ruamel forced absent; the corruption is invisible on any dev/CI host that happens to have ruamel. A latent env-presence dependency (Portability directive violation) that no gate checks.

**Prevention:** integrate.py leg fixed in T-2473 (`_str_loader` strips the timestamp resolver; pinned by t2473 field-merge `...Z`-survives assertion). Latent BVP legs → **fix task T-2477** filed (port the resolver-stripped loader into the fallback + a ruamel-absent regression test). Concern **OBS-085** registered; learning **L-495** captured. Meta-prevention for the *governance miss* itself: this task exists because T-2473 folded the flaw into a feature task instead of registering first — the remediation re-establishes register-first discipline.

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

### 2026-06-24T07:34:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2476-investigate-pyyaml-timestamp-round-trip-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-72e874df
- **Timestamp:** 2026-06-24T07:40:42Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#2 (Agent)** — A concern is registered in `.context/concerns.yaml` for the timestamp-round-trip corruption class (or, if a matching entry already exists e.g. under L-385, cross-linked rather than duplicated).
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/concerns.yaml in: A concern is registered in `.context/concerns.yaml` for the timestamp-round-trip corruption class (or, if a matching entry already exists e.g. under L`

### 2026-06-24T07:40:41Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
