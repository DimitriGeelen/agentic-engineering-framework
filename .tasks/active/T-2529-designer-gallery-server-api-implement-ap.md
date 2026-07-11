---
id: T-2529
name: "designer gallery-server API: implement /api/* endpoints 832 client already
  calls"
description: >
  designer gallery-server API: implement /api/* endpoints 832 client already calls

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
created: 2026-07-10T22:17:43Z
last_update: '2026-07-10T22:30:09Z'
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
  - ts: '2026-07-10T22:30:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-10T22:30:09Z'
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

# T-2529: designer gallery-server API: implement /api/* endpoints 832 client already calls

## Context

Build slice of the T-2528 GO (designer workflow persistence, decided GO by the operator via Watchtower,
commit `9bd09d43e`). Live Playwright inspection of the deployed 0.2.0 designer proved **832 already
shipped the entire persistence client** (open-project / save-to-project / versions + card browser),
progressive-enhancement-gated on `GET /api/health`. AEF serves `/designer` as a *static file*, so
`/api/health` 404s (the only console error on the page) and the client keeps its buttons hidden — that is
the operator's "cannot save to project." **This task implements the AEF-side gallery-server API the client
already calls.** Contract (recovered verbatim, full table in `docs/reports/T-2522-bpmn-aef-mapping-contract.md`
IW-8-CORRECTED entry): `/api/health`, `/api/list`, `/api/save`, `/api/versions`, `/api/version`, `/api/delete`,
plus `rendered/<id>.bpmn` (corpus, follow-up). When AEF answers `/api/health` ok, the client lights up unchanged.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `GET /api/health` returns 200 `{"ok":true}` (progressive-enhancement gate)
- [x] `POST /api/save {id,bpmn,png,note}` writes a versioned map to a file-backed store and returns `{"ok":true,"v":N}`; a second save of the same id returns `v:N+1`
- [x] `GET /api/list` returns `{"maps":[…]}` including a just-saved id
- [x] `GET /api/versions?id=<id>` returns a JSON array `[{"v":…}]`
- [x] `GET /api/version?id=<id>&v=<v>` returns the exact bpmn stored for that version
- [x] `POST /api/delete {id,scope:"version",v}` returns `{"ok":true}` and removes that version from `/api/versions`
- [x] id validation rejects ids not matching `^[a-z0-9][a-z0-9_-]*$` (400, no write)
- [x] blueprint registered (`web/blueprints/__init__.py`); `bin/fw vendor self` leaves no self-vendor drift (verified: `cmp` clean on app.py/__init__.py/designer_api.py)
- [x] Live browser: on `GET /designer` the save/open/versions buttons lose `display:none` (Playwright: all VISIBLE, zero console errors; client's own open-project browser lists a saved map "saved · v3" with a loaded `/api/thumb` image; real "investigate" diagram saved through the client → stored as valid BPMN 2.0)

### Human
- [ ] [REVIEW] Operator confirms the reported gap is closed: can save a workflow to a project and reopen it
  **Steps:**
  1. Open `http://192.168.10.107:3001/designer` in a browser
  2. Confirm a `⤓ Save to project` button is now visible in the toolbar (it was hidden before)
  3. Give the workflow an ID (lowercase), click `⤓ Save to project`, confirm the `✓ Saved v1` flash
  4. Reload the page, click `📂 Open project…`, confirm your saved workflow appears in the browser and opens
  **Expected:** the save/open round-trip works from the operator's seat — the "cannot save to project" gap is gone
  **If not:** note which step failed (button still hidden = /api/health not answering; save errors = check `/api/save` response)

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
# ── gallery-server API live E2E (server must be running with the new blueprint) ──
u=$(bin/fw watchtower url)
h=$(curl -sf "$u/api/health" 2>&1); echo "$h" | grep -q '"ok"'
s=$(curl -sf -X POST "$u/api/save" -H 'Content-Type: application/json' -d '{"id":"t2529-verify","bpmn":"<definitions id=\"x\"/>","png":"","note":"verify"}' 2>&1); echo "$s" | grep -q '"v"'
l=$(curl -sf "$u/api/list" 2>&1); echo "$l" | grep -q 't2529-verify'
v=$(curl -sf "$u/api/versions?id=t2529-verify" 2>&1); echo "$v" | grep -q '"v"'
b=$(curl -sf "$u/api/version?id=t2529-verify&v=1" 2>&1); echo "$b" | grep -q 'definitions'
bad=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$u/api/save" -H 'Content-Type: application/json' -d '{"id":"BAD ID","bpmn":"<x/>"}'); [ "$bad" = "400" ]

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

### 2026-07-11 — CSRF exemption for the gallery mutating endpoints
- **Chose:** exempt `designer_api.*` POSTs (`/api/save`, `/api/delete`) from AEF's CSRF layer (`web/app.py` `csrf_protect`), sibling to the existing `health` + `/search/` exemptions.
- **Why:** the vendored 832 client sends no CSRF token (verified — zero `csrf`/`credentials:` in its JS) and its gallery-server contract predates AEF's CSRF layer (T-1343); the build is read-only, we cannot inject a token. Same-origin fetches from the served `/designer` page, trusted-LAN dashboard, recoverable map data.
- **Rejected:** (a) require a token — impossible without editing the foreign build; (b) Origin/Referer same-origin check — more complex than the codebase's existing exemption pattern. Flagged to 832 (thread T-175) that their contract implies a CSRF-exempt zone; a future hardening could have their client read a cookie token.

### 2026-07-11 — store location: `.context/designer/projects/` (runtime data plane)
- **Chose:** file-backed store under `.context/designer/projects/<id>/` (meta.json + v<N>.bpmn + v<N>.png), atomic meta writes (L-493).
- **Why:** closes the operator's gap immediately with zero git-status churn from runtime saves; `.context/` is the conventional runtime home (sibling to `.context/bus/blobs/`).
- **Rejected:** repo-root `designer-projects/` tracked — the "workflows as first-class committed artifacts" aspiration is real but is a *promotion* follow-up (a `fw designer export` that lifts a saved map into a tracked path), not needed to close the gap. Confirm the tracked-vs-runtime call with the operator.

### 2026-07-11 — contract had 8 endpoints, not 6 (recovered live, not from spec)
- **Chose:** implement `/api/thumb` (`?id=&v=` → version PNG; `?id=` → latest/corpus tile) and the exact `/api/list` map shape (`latest:{v}`, `openTarget:{kind:"version",v}`) after the client's own open-project browser exercised them.
- **Why:** the initial JS grep found 6 endpoints; driving the *client's* UI surfaced a 7th (`/api/thumb`, a console 404) and revealed the map object needs `m.latest.v` + `m.openTarget` (my first scalar shape mis-classified saved maps as corpus-only). Verifying through the real UI — not curl — is what caught both.
- **Rejected:** shipping the 6-endpoint curl-green version — it passed every curl check but the client's browser still 404'd on thumbnails and mis-rendered cards. (Binding-rule instance: curl-green ≠ works.)

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-07-10T22:17:43Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2529-designer-gallery-server-api-implement-ap.md
- **Context:** Initial task creation
