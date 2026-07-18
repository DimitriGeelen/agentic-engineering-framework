---
id: T-2530
name: "align designer gallery API to 832 authoritative contract (sources, latest.ts/count,
  health.store)"
description: >
  align designer gallery API to 832 authoritative contract (sources, latest.ts/count,
  health.store)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [web/blueprints/designer_api.py]
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
created: 2026-07-11T12:09:37Z
last_update: 2026-07-11T17:05:14Z
date_finished: 2026-07-11T12:22:40Z
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
  - ts: '2026-07-11T12:15:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-11T12:15:08Z'
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

# T-2530: align designer gallery API to 832 authoritative contract (sources, latest.ts/count, health.store)

## Context

T-2529 built the gallery API by reverse-engineering the 832 client's JS. On 2026-07-11 (T-2523, DM
rail offset 12) 832 gave the **authoritative** contract from its reference server `tools/gallery-serve.py`
("B2 sidecar"), revealing four `/api/list` + `/api/health` shape mismatches. This task aligns
`web/blueprints/designer_api.py` to that authoritative contract. Captured in
`docs/reports/T-2522-bpmn-aef-mapping-contract.md` (2026-07-11 dialogue entry). Sibling to T-2529.

## Acceptance Criteria

### Agent
- [x] `/api/list` emits `sources: ["saved"]` (non-empty list) for each user-saved map — the field 832's card browser reads to distinguish canonical-corpus from user-saved
- [x] `/api/list` `latest` is an object `{v, ts, count}` (not scalar `{v}`): `count` = number of stored versions, `ts` = the latest version's timestamp
- [x] `/api/list` no longer emits `updated` or `versions` keys (timestamp moved to `latest.ts`; version list is served separately by `/api/versions`)
- [x] `/api/health` returns `store` key (`{"ok": true, "store": ".context/designer/projects"}`)
- [x] `/api/version?id=&v=` returns raw BPMN as `text/xml` (was `application/xml`; aligned to 832's exact contract — verified `Content-Type: text/xml; charset=utf-8`)
- [x] Live browser round-trip re-verified end-to-end (Playwright, real browser): fresh save `t2530-verify` round-trips → valid BPMN + a real 320×136 png thumbnail (`img.complete=true`, `/api/thumb` → 200 image/png), card renders "saved · v1" from the new `sources`+`latest.v` fields. The only console errors are pre-existing/unrelated — favicon 404, and the stale map `t2529-verify`'s missing-`v3`-png thumb rendering to a graceful `▦` placeholder (a data gap from earlier saves, NOT introduced by this change; the old shape pointed `latest` at v3 too)
- [x] Vendored copy refreshed: `.agentic-framework/web/blueprints/designer_api.py` byte-matches `web/blueprints/designer_api.py` (`cmp` clean)

### Human
- [ ] [REVIEW] Operator confirms the save→open round-trip still works in their own browser after the contract alignment
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw watchtower url` — note the URL
  2. Open `<url>/designer` in a browser; create or edit a diagram; Save-to-project (give it an id + note)
  3. Reload; open the project browser; confirm the saved map appears with a thumbnail and reopens
  **Expected:** saves without error, lists as "saved · vN" with thumbnail, reopens the diagram
  **If not:** open devtools console, note any `/api/*` error and report it

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
python3 -c "import ast; ast.parse(open('web/blueprints/designer_api.py').read())"
out=$(curl -sf "$(bin/fw watchtower url)/api/health"); echo "$out" | grep -q '"store"'
out=$(curl -sf "$(bin/fw watchtower url)/api/list"); echo "$out" | grep -q '"sources"'
out=$(curl -sf "$(bin/fw watchtower url)/api/list"); echo "$out" | grep -q '"count"'
out=$(curl -sf "$(bin/fw watchtower url)/api/list"); if echo "$out" | grep -q '"updated"'; then exit 1; fi
cmp -s web/blueprints/designer_api.py .agentic-framework/web/blueprints/designer_api.py

## Recommendation

**Recommendation:** GO (partial-complete — one [REVIEW] Human AC remains).

**Rationale:** The gallery API is aligned to 832's authoritative `tools/gallery-serve.py` contract
(delivered on the T-2523 DM rail, offset 12) and live-verified end-to-end in a real browser — not by
curl alone. A fresh save round-tripped through the client's own Save-to-project flow into valid BPMN 2.0
+ a real 320×136 png thumbnail, and the card browser rendered "saved · v1" from the new `sources` +
`latest.v` fields. All 7 Agent ACs pass.

**Evidence:**
- `/api/list` now `{id,title,sources:["saved"],latest:{v,ts,count},openTarget}` — verified via curl + client parse
- `/api/health` → `{"ok":true,"store":".context/designer/projects"}`; `/api/version` → `Content-Type: text/xml`
- Fresh save `t2530-verify`: `/api/thumb?id=t2530-verify&v=1` → 200 image/png; `img.complete=true`, 320×136
- Only console errors are pre-existing/unrelated (favicon; stale `t2529-verify` v3 missing-png → graceful ▦)
- Vendored copy `cmp`-clean; committed 8e977b66c
- **832 convergence bonus:** IW-1 keystone answered ((a) extensionElements `<aef:uid>`) → Child 2
  (diagram→tasks forward compiler) is unblocked and awaiting operator GO (arc-scale, not self-approved)

**Human AC pending:** operator confirms the save→open round-trip in their own browser.

## Decisions

### 2026-07-11 — gallery contract alignment choices
- **`sources` for saved-only store:** emit `sources:["saved"]` per map. **Why:** AEF's store holds only
  user-saved maps (no rendered corpus yet); 832's card browser keys corpus-vs-saved off this field.
  Confirmed the semantics with 832 on the rail (saved-only ⇒ `["saved"]`). When the rendered corpus
  lands, maps gain `["rendered"]`/both.
- **`/api/health` `store` value = own path, not 832's literal:** report `.context/designer/projects`
  (AEF's actual store) rather than echoing 832's `.editor-versions`. **Why:** the field is diagnostic;
  the client gates on `ok:true`. Reporting a false path would be misleading. **Rejected:** echoing
  `.editor-versions` verbatim (dishonest about AEF's real store).
- **`/api/version` `text/xml` not `application/xml`:** aligned to 832's exact reference MIME even though
  both parse identically client-side — this task's purpose is contract exactness.

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

### 2026-07-11T12:09:37Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2530-align-designer-gallery-api-to-832-author.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e20071f5
- **Timestamp:** 2026-07-11T12:22:42Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 35
     - evidence: `out=$(curl -sf "$(bin/fw watchtower url)/api/list"); if echo "$out" | grep -q '"updated"'; then exit 1; fi`

### 2026-07-11T12:22:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
