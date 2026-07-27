---
id: T-2630
name: "overlay Slice B — wrapper page forwards aef:annotate on aef:ready"
description: >
  overlay Slice B — wrapper page forwards aef:annotate on aef:ready

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: []
related_tasks: []
arc_id: designer-corpus
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-07-27T18:38:55Z
last_update: 2026-07-27T18:46:57Z
date_finished: 2026-07-27T18:46:57Z
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
  - ts: '2026-07-27T18:45:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-27T18:45:08Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2630: overlay Slice B — wrapper page forwards aef:annotate on aef:ready

## Context

T-2620 GO cascade, Slice B. 832 ratified T-250 today (rail offset 216: GO, shape A
postMessage — designer emits `aef:ready` with uid list after EVERY render incl.
initial load; accepts `aef:annotate` keyed by node uid; read-only badge layer on
`g[data-id=uid]`; never serialized; dropped on doc switch; unknown uids ignored;
their build task T-258, lands in a future release cut). Our half: a wrapper page
that iframes the vendored editor bundle and forwards the Slice A payload
(`/api/overlay?id=<map>`, T-2629) verbatim via postMessage on every `aef:ready`.

Deliberately independent of 832's ship date: until we re-pin a bundle that emits
`aef:ready`, the wrapper is a harmless no-op (listener never fires) — both halves
land independently and the seam lights up on re-pin. Design: T-2620 research
artifact (docs/reports/T-2620-live-state-overlay-seam.md), rail 197/216.

## Acceptance Criteria

### Agent
- [x] `GET /designer/overlay?id=aef-task-lifecycle` returns 200 and renders a page
      that iframes `/designer/app?load=/api/version?id=<map>` (server-latest, nonce
      flow untouched) — unknown/invalid map ids 404 (same guard as /api/overlay)
- [x] Wrapper JS: `message` listener accepts only same-origin events with
      `data.type === "aef:ready"`, then fetches `/api/overlay?id=<map>` and
      postMessages the JSON verbatim into the iframe — on EVERY ready (216 re-ready
      contract), no caching, no payload mutation
- [x] Landing page card for a map with an overlay profile gains an "overlay" link to
      the wrapper; non-profiled maps get no link (live: only aef-task-lifecycle links)
- [x] Web tests pin: wrapper 200 + iframe src + listener/forward markers; 404 on
      unknown and traversal ids; landing overlay-link presence/absence
- [x] Full designer web test suite green (tests/web/ 129 passed; the one collision —
      nonce-minter counter matching the new link's class — fixed via compound class)

### Human
- [ ] [REVIEW] Wrapper page is a sensible operator surface (v0 chrome taste)
  **Steps:**
  1. Open http://192.168.10.107:3001/designer/overlay?id=aef-task-lifecycle
  2. Editor loads inside the wrapper at server-latest; page header/frame chrome reads clear
  3. Note: badges will NOT render yet — 832's aef:ready ships in their next release cut (T-258); until re-pin the wrapper is a documented no-op
  **Expected:** editor fully usable inside the frame; wrapper chrome minimal and self-explaining (title + map id + "live overlay" status note)
  **If not:** note what reads wrong — chrome wording and layout are v0 taste, adjust freely

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

python3 -m pytest tests/web/test_designer_overlay.py tests/web/test_api_overlay.py tests/web/test_api_version_latest.py -q
out=$(curl -sf "$(bin/fw watchtower url)/designer/overlay?id=aef-task-lifecycle"); echo "$out" | grep -q 'aef:ready' && echo "$out" | grep -q '/designer/app?load='
test "$(curl -s -o /dev/null -w '%{http_code}' "$(bin/fw watchtower url)/designer/overlay?id=no-such-map")" = "404"
# here-string, not echo|grep: the landing HTML exceeds the pipe buffer, so even
# the L-387 capture pattern SIGPIPEs (141) when grep -q matches early
out=$(curl -sf "$(bin/fw watchtower url)/designer"); grep -q '/designer/overlay?id=aef-task-lifecycle' <<<"$out"

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

## Recommendation

- **Recommendation:** GO
- **Rationale:** Both agent halves of the T-2620 overlay seam are now live and
  contract-locked — Slice A serves the payload, Slice B forwards it on every
  `aef:ready` per 832's ratified T-250 (rail 216). The wrapper is deliberately a
  no-op until we re-pin a bundle carrying 832's T-258; nothing here blocks on
  them. The only human question is v0 chrome taste on the wrapper page.
- **Evidence:**
  - Live: `GET /designer/overlay?id=aef-task-lifecycle` 200 on :3001 (editor at
    server-latest inside the frame, status note explains the pre-T-258 no-op)
  - Live: unknown/traversal ids 404; landing card shows "Live overlay →" only
    for the profiled map
  - Tests: tests/web/test_designer_overlay.py 3/3; overlay+version suites 10/10;
    full tests/web/ 129 passed
  - Contract: forward is verbatim (no cache, no mutation), same-origin +
    same-frame + typed-event guarded — pinned by test markers

## Evolution

### 2026-07-27 — Slice B built same-day as ratification
- **What changed:** 832 ratified T-250 (rail 216) hours after Slice A shipped —
  the contract landed exactly as advised at 197, so no wrapper design iteration
  was needed; the "both halves land independently, seam lights up on re-pin"
  decoupling from the T-2620 artifact held.
- **Plan impact:** none — Slice C (trigger landing surface) remains the only
  open cascade slice, still waiting the operator's surface decision.
- **Triggered:** re-pin follow-up (verify badges render end-to-end) becomes a
  natural part of the next designer release adoption task, not a separate slice.

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

### 2026-07-27T18:38:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2630-overlay-slice-b--wrapper-page-forwards-a.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-932030a7
- **Timestamp:** 2026-07-27T18:47:00Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-27T18:46:57Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
