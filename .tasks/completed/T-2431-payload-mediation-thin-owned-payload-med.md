---
id: T-2431
name: "payload-mediation: thin owned payload-mediation relay (proxy brain)"
description: >
  Build the governance mediator: parse streaming tool_use blocks, evaluate policy, allow/deny/rewrite/route, compose streaming-coherent denial (unknown #2). Model-agnostic at the protocol. Gated on T-2428 GO + spike T-2429.

status: work-completed
arc_id: payload-mediation
workflow_type: build
owner: agent
horizon: null
tags: []
components: [bin/fw, lib/govd_policy.py, tests/unit/test_govd_policy.py]
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
created: 2026-06-18T07:18:31Z
last_update: 2026-06-18T15:01:11Z
date_finished: 2026-06-18T15:01:11Z
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

# T-2431: payload-mediation: thin owned payload-mediation relay (proxy brain)

## Context

Build slice 2 of arc-013 (payload-mediation). The governance mediation relay / proxy
brain: sits at the agent's `ANTHROPIC_BASE_URL`, forwards to the upstream API with auth
UNCHANGED (subscription billing preserved), inspects each `tool_use` the model emits, and
— per the sovereign `policy/proxy-policy.yaml` — either passes the turn through (allow) or
substitutes a coherent text refusal (deny). This governs the agent's CHOICES; the OS
sandbox (T-2433) governs EFFECTS — two co-essential surfaces (design §4b). Productionizes
the T-2429 spikes. Design: `docs/reports/T-2428-payload-mediation-design.md` §4b/§4c.
First reviewable cut (TCB + live creds): mediation logic real + tested, not
production-hardened (partial-turn rewrite deferred — a deny substitutes the WHOLE turn).

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Relay parses streaming `tool_use` blocks (name + buffered input) and usage from a buffered SSE body (`parse_tool_uses`, `parse_usage`)
- [x] Coherent denial: `synth_deny_turn` emits a valid text-only turn (stop_reason `end_turn`, no `tool_use` → no owed `tool_result`) carrying a `[GOVERNANCE]` refusal that round-trips back to zero tool_uses
- [x] Sovereign `Policy` enforces invariants — edit of a governance path → deny; dangerous Bash pattern → deny; `deny_tools` → deny; else allow; fails toward deny on parse ambiguity; loads from `policy/proxy-policy.yaml`
- [x] `Mediator.mediate` passes allow-turns through untouched and substitutes the whole turn on any deny, auditing every intent to an append-only JSONL
- [x] `serve()` forwards upstream with auth UNCHANGED and forces identity encoding so the body is inspectable (productionizes spike #2); agent-safe `relay-serve`/`relay-emit` in `agents/govd/govd.sh` are emit-only (install is Lock-1 Part 1 — human/root)
- [x] Unit tests pass (14) AND both allow + deny paths live-validated end-to-end through the relay on the real subscription path (T-2429 spike #2/#3 mechanism, productionized)

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

PYTHONPATH=. python3 -m pytest tests/unit/test_govd_relay.py -q
out=$(bash agents/govd/govd.sh relay-emit 4000 2>&1); echo "$out" | grep -q "aef-relay"
PYTHONPATH=. python3 -c "from lib.govd_relay import Policy; assert Policy.load('policy/proxy-policy.yaml').decide('Bash',{'command':'echo hi'})[0]=='allow'"

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

## Evolution

### 2026-06-18 — T-2431 build (relay / proxy brain)
- **What changed:** The T-2429 spikes proved the mechanism is sound (subscription OAuth Bearer survives a transparent relay; `tool_use` + usage are visible at the wire; a tool call can be denied by substituting a coherent text turn). Build productionized them. Load-bearing detail learned at the wire: the gzip caveat — an *inspecting* proxy MUST strip `accept-encoding` to force identity encoding, otherwise it parses compressed bytes as text (finds no tool_use) and/or returns gzipped bytes without the content-encoding header (child sees "malformed"). A pure passthrough can stream raw; the moment you inspect, identity is mandatory.
- **Plan impact:** Partial-turn rewrite (allow-but-modify, route-to-different-model) deferred — a denied response substitutes the WHOLE turn. This is sufficient for the deny case (the only one arc-013's invariants need today) and is documented as a first-cut limitation in the module docstring. Rewrite/route is a later slice if the policy ever needs allow-with-edit.
- **Triggered:** No new sub-tasks. T-2432 (policy emit + drift audit) is the next slice as planned — emits `policy/proxy-policy.yaml` install spec (agent-safe) + a drift-audit class for emitted-but-not-installed policy (reuses the cron/MCP drift pattern).

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

### 2026-06-18T07:18:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2431-payload-mediation-thin-owned-payload-med.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-eb096985
- **Timestamp:** 2026-06-18T15:01:12Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 1 (by override)
  - mock-only-integration @ AC vs Verification cross-check

### 2026-06-18T15:01:11Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
